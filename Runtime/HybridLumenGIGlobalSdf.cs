using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>
    /// Per-camera toroidal global distance lower bounds, used only for empty-space skipping.
    /// Missing pages are unknown. RecordUpdate must execute before Bind consumers on the same
    /// graphics queue. This represents already-published scene instances, not asset/scene IO.
    /// </summary>
    public sealed class HybridLumenGIGlobalSdf : IDisposable
    {
        public const int VoxelsPerBrickAxis = 4;
        public const int VoxelsPerBrick = 64;
        public const int ValuesPerBrick = 65; // final word stores the GPU-published generation bits
        public const int PageStride = 32, LevelStride = 32, JobStride = 32, ObjectBoundsStride = 32;

        [Serializable]
        public struct Configuration
        {
            public int LevelCount, BricksPerAxis, UpdateBrickBudget;
            public float BaseVoxelSize, MaxDistanceInBricks;
            public static Configuration Default => new Configuration
            {
                LevelCount = 3, BricksPerAxis = 8, UpdateBrickBudget = 16,
                BaseVoxelSize = 0.5f, MaxDistanceInBricks = 2f
            };
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct Page
        {
            public int x, y, z;
            public uint generation, ready, level, reserved0, reserved1;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct Level
        {
            public int x, y, z, reserved;
            public Vector4 metric; // voxel size, brick world size, maximum stored lower bound, unused
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct Job
        {
            public int x, y, z, page;
            public uint generation, level, reserved0, reserved1;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct ObjectBounds
        {
            public Vector4 minimum; // w: clamp to this enclosing box for real renderer safety
            public Vector4 maximum; // w: published
        }
        private struct Pending
        {
            public int page, age, level;
            public double distanceSquared;
        }

        private readonly ComputeShader updateShader;
        private readonly int mergeKernel, publishKernel;
        private readonly List<Pending> pending = new List<Pending>();
        private readonly List<Bounds> dirtyBounds = new List<Bounds>();
        private Page[] pages = Array.Empty<Page>();
        private Level[] levels = Array.Empty<Level>();
        private Job[] jobs = Array.Empty<Job>();
        private ObjectBounds[] objectBounds = Array.Empty<ObjectBounds>();
        private int[] ages = Array.Empty<int>();
        private int[] dirtyRows = Array.Empty<int>();
        private Configuration configuration;
        private HybridLumenGIScene scene;
        private HybridLumenGISdfAtlas sdf;
        private ComputeBuffer disabledDistances, disabledPages, disabledLevels;
        private long retiringBytes;
        private bool prepared, recorded;
        private int jobCount;

        public ComputeBuffer DistancesBuffer { get; private set; }
        public ComputeBuffer PagesBuffer { get; private set; }
        public ComputeBuffer LevelsBuffer { get; private set; }
        public ComputeBuffer UpdateJobsBuffer { get; private set; }
        public ComputeBuffer ObjectBoundsBuffer { get; private set; }
        /// <summary>At least one page is scheduled ready on the current queue; not a GPU fence.</summary>
        public bool IsReady => prepared && recorded && ReadyBrickCount > 0;
        public int ReadyBrickCount { get; private set; }
        public int PendingBrickCount { get; private set; }
        public int UpdatedBrickCount { get; private set; }
        public int InvalidatedBrickCount { get; private set; }
        public int LevelCount => levels.Length;
        public int BricksPerAxis => configuration.BricksPerAxis;
        private static long Bytes(ComputeBuffer buffer) => buffer == null ? 0 : (long)buffer.count * buffer.stride;
        private long ClipmapBytes => Bytes(DistancesBuffer) + Bytes(PagesBuffer) + Bytes(LevelsBuffer) +
            Bytes(UpdateJobsBuffer) + Bytes(ObjectBoundsBuffer);
        public long AllocatedBytes => ClipmapBytes + retiringBytes + Bytes(disabledDistances) + Bytes(disabledPages) + Bytes(disabledLevels);

        public HybridLumenGIGlobalSdf(ComputeShader shader = null)
        {
            updateShader = shader != null ? shader : Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGIGlobalSdf");
            if (updateShader == null) throw new InvalidOperationException("HybridLumenGI global SDF compute shader is missing.");
            mergeKernel = updateShader.FindKernel("CSMergeBricks");
            publishKernel = updateShader.FindKernel("CSPublishBricks");
        }

        /// <summary>
        /// Call after scene and object SDF Prepare. Invalidations are unbudgeted; only voxel
        /// recomposition consumes UpdateBrickBudget. bool reports whether any pages need work.
        /// </summary>
        public bool Prepare(HybridLumenGIScene sourceScene, HybridLumenGISdfAtlas sourceSdf,
            Vector3 cameraPosition, Configuration settings)
        {
            if (sourceScene == null || sourceSdf == null) throw new ArgumentNullException();
            if (!Finite(cameraPosition)) throw new ArgumentException("Camera position must be finite.", nameof(cameraPosition));
            settings = Sanitize(settings);
            bool reset = EnsureStorage(settings, sourceScene.Capacity);
            configuration = settings;
            scene = sourceScene; sdf = sourceSdf;
            prepared = true; recorded = false;
            jobCount = ReadyBrickCount = PendingBrickCount = UpdatedBrickCount = InvalidatedBrickCount = 0;
            dirtyBounds.Clear(); pending.Clear();
            const HybridLumenGIScene.ChangeKind nonGeometric=HybridLumenGIScene.ChangeKind.Material|HybridLumenGIScene.ChangeKind.Lighting;
            foreach (var region in scene.DirtyRegions)
            {
                // Shared transport events remain intact; this field stores geometry only.
                if(region.Kind!=0 && (region.Kind&~nonGeometric)==0) continue;
                if (region.HasPrevious) dirtyBounds.Add(region.PreviousBounds);
                if (region.HasCurrent) dirtyBounds.Add(region.CurrentBounds);
            }
            foreach (Bounds bounds in sdf.RepresentationChangedBounds) dirtyBounds.Add(bounds);
            UpdateObjectBounds();

            int axis = settings.BricksPerAxis, perLevel = axis * axis * axis;
            bool invalidateAll = reset || scene.RequiresFullInvalidation;
            bool hasLocalChanges = !invalidateAll && dirtyBounds.Count > 0;
            for (int level = 0; level < settings.LevelCount; level++)
            {
                float voxelSize = settings.BaseVoxelSize * (1 << level);
                float brickSize = voxelSize * VoxelsPerBrickAxis;
                int centerX = WorldKey(cameraPosition.x, brickSize), centerY = WorldKey(cameraPosition.y, brickSize), centerZ = WorldKey(cameraPosition.z, brickSize);
                Level data = new Level
                {
                    x = centerX - axis / 2, y = centerY - axis / 2, z = centerZ - axis / 2,
                    metric = new Vector4(voxelSize, brickSize, brickSize * settings.MaxDistanceInBricks, 0)
                };
                levels[level] = data;
                if (hasLocalChanges) MarkDirtyRows(data, axis);
                for (int z = 0; z < axis; z++) for (int y = 0; y < axis; y++) for (int x = 0; x < axis; x++)
                {
                    int wx = data.x + x, wy = data.y + y, wz = data.z + z;
                    int index = level * perLevel + PhysicalPage(wx, wy, wz, axis);
                    Page page = pages[index];
                    bool differentKey = page.generation == 0 || page.x != wx || page.y != wy || page.z != wz;
                    bool invalid = invalidateAll || differentKey || (hasLocalChanges && (dirtyRows[z * axis + y] & (1 << x)) != 0);
                    if (invalid)
                    {
                        if (page.ready != 0 || differentKey) InvalidatedBrickCount++;
                        page.generation = NextGeneration(page.generation);
                        page.ready = 0;
                        if (differentKey) ages[index] = 0;
                    }
                    page.x = wx; page.y = wy; page.z = wz; page.level = (uint)level;
                    pages[index] = page;
                    if (page.ready != 0) { ReadyBrickCount++; ages[index] = 0; continue; }
                    ages[index] = Math.Min(ages[index] + 1, 1000000);
                    double dx = (wx + 0.5) * brickSize - cameraPosition.x;
                    double dy = (wy + 0.5) * brickSize - cameraPosition.y;
                    double dz = (wz + 0.5) * brickSize - cameraPosition.z;
                    pending.Add(new Pending { page = index, age = ages[index], level = level, distanceSquared = dx * dx + dy * dy + dz * dz });
                }
            }
            pending.Sort(ComparePending);
            PendingBrickCount = pending.Count;
            jobCount = Math.Min(settings.UpdateBrickBudget, pending.Count);
            for (int i = 0; i < jobCount; i++)
            {
                int index = pending[i].page;
                Page page = pages[index];
                jobs[i] = new Job { x = page.x, y = page.y, z = page.z, page = index, generation = page.generation, level = page.level };
            }
            return PendingBrickCount > 0;
        }

        internal void PrepareDisabled()
        {
            if (disabledDistances == null)
            {
                // The same compute kernels require typed SRVs even with queries disabled.
                try
                {
                    disabledDistances = Buffer(1, 4, "HLGI disabled global SDF distance");
                    disabledPages = Buffer(1, PageStride, "HLGI disabled global SDF page");
                    disabledLevels = Buffer(1, LevelStride, "HLGI disabled global SDF level");
                }
                catch
                {
                    ReleaseDisabledBuffers();
                    throw;
                }
            }
            if (DistancesBuffer != null)
            {
                var buffers = new[] { DistancesBuffer, PagesBuffer, LevelsBuffer, UpdateJobsBuffer, ObjectBoundsBuffer };
                long bytes = ClipmapBytes;
                ClearClipmap();
                retiringBytes += bytes;
                HybridLumenGIResourceRetirement.Retire(() =>
                {
                    foreach (var buffer in buffers) buffer?.Release();
                    retiringBytes -= bytes;
                });
            }
            prepared = true;
        }

        /// <summary>Record invalidation, merge and then ready publication on one graphics queue.</summary>
        public int RecordUpdate(CommandBuffer command)
        {
            if (!prepared) throw new InvalidOperationException("Prepare the global SDF first.");
            if (command == null) throw new ArgumentNullException(nameof(command));
            if (recorded || levels.Length == 0) return 0;
            // SetBufferData records snapshots in the command stream; do not publish CPU-ready bits
            // before this copy. The caller must execute this stream before another Prepare;
            // on cancellation call InvalidateAll so these scheduled pages will be retried.
            command.SetBufferData(PagesBuffer, pages);
            command.SetBufferData(LevelsBuffer, levels);
            command.SetBufferData(ObjectBoundsBuffer, objectBounds);
            if (jobCount > 0)
            {
                command.SetBufferData(UpdateJobsBuffer, jobs, 0, 0, jobCount);
                BindUpdate(command, mergeKernel);
                sdf.Bind(command, updateShader, mergeKernel);
                command.SetComputeBufferParam(updateShader, mergeKernel, "_HLGI_Proxies", scene.Buffer);
                command.SetComputeIntParam(updateShader, "_HLGI_ProxyCount", scene.Capacity);
                command.DispatchCompute(updateShader, mergeKernel, jobCount, 1, 1);
                // Separate dispatch is the global UAV ordering point: never publish a page from
                // one thread while other groups still write its voxel samples.
                BindUpdate(command, publishKernel);
                command.DispatchCompute(updateShader, publishKernel, (jobCount + 63) / 64, 1, 1);
                for (int i = 0; i < jobCount; i++) { int index = jobs[i].page; Page page = pages[index]; page.ready = 1; pages[index] = page; ages[index] = 0; }
                ReadyBrickCount += jobCount;
                PendingBrickCount -= jobCount;
                UpdatedBrickCount = jobCount;
            }
            recorded = true;
            return jobCount;
        }

        private void BindUpdate(CommandBuffer command, int kernel)
        {
            command.SetComputeBufferParam(updateShader, kernel, "_HLGI_GlobalSdfDistancesWrite", DistancesBuffer);
            command.SetComputeBufferParam(updateShader, kernel, "_HLGI_GlobalSdfPagesWrite", PagesBuffer);
            command.SetComputeBufferParam(updateShader, kernel, "_HLGI_GlobalSdfLevels", LevelsBuffer);
            command.SetComputeBufferParam(updateShader, kernel, "_HLGI_GlobalSdfJobs", UpdateJobsBuffer);
            command.SetComputeBufferParam(updateShader, kernel, "_HLGI_GlobalSdfObjectBounds", ObjectBoundsBuffer);
            command.SetComputeIntParam(updateShader, "_HLGI_GlobalSdfJobCount", jobCount);
        }

        /// <summary>Shader query returns false for every missing, dirty or mismatched page.</summary>
        public void Bind(CommandBuffer command, ComputeShader compute, int kernel)
        {
            if (!prepared) throw new InvalidOperationException("Prepare the global SDF first.");
            command.SetComputeBufferParam(compute, kernel, "_HLGI_GlobalSdfDistances", DistancesBuffer ?? disabledDistances);
            command.SetComputeBufferParam(compute, kernel, "_HLGI_GlobalSdfPages", PagesBuffer ?? disabledPages);
            command.SetComputeBufferParam(compute, kernel, "_HLGI_GlobalSdfLevels", LevelsBuffer ?? disabledLevels);
            command.SetComputeIntParam(compute, "_HLGI_GlobalSdfLevelCount", recorded ? levels.Length : 0);
            command.SetComputeIntParam(compute, "_HLGI_GlobalSdfBrickAxis", configuration.BricksPerAxis);
        }

        /// <summary>CPU scheduling diagnostics only; does not read GPU distance values or a fence.</summary>
        public bool TryGetPage(int level, int worldX, int worldY, int worldZ, out int physicalIndex, out uint generation, out bool ready)
        {
            physicalIndex = -1; generation = 0; ready = false;
            if (!prepared || level < 0 || level >= levels.Length) return false;
            Level data = levels[level]; int axis = configuration.BricksPerAxis;
            if ((long)worldX - data.x < 0 || (long)worldX - data.x >= axis || (long)worldY - data.y < 0 || (long)worldY - data.y >= axis || (long)worldZ - data.z < 0 || (long)worldZ - data.z >= axis) return false;
            physicalIndex = level * axis * axis * axis + PhysicalPage(worldX, worldY, worldZ, axis);
            Page page = pages[physicalIndex]; generation = page.generation;
            ready = recorded && page.ready != 0 && page.x == worldX && page.y == worldY && page.z == worldZ;
            return page.x == worldX && page.y == worldY && page.z == worldZ && page.generation != 0;
        }

        private void UpdateObjectBounds()
        {
            for (int slot = 0; slot < objectBounds.Length; slot++)
            {
                ObjectBounds prior = objectBounds[slot], next = default;
                if (slot < scene.Capacity)
                {
                    var data = scene.Data[slot];
                    if (data.identity.w > 0.5f && data.identity.w < 1.5f)
                    {
                        Vector3 center = new Vector3(data.centerShape.x, data.centerShape.y, data.centerShape.z);
                        Vector3 extent = new Vector3(data.extentsRoughness.x, data.extentsRoughness.y, data.extentsRoughness.z);
                        if (data.centerShape.w > 0.5f) extent = Vector3.one * Mathf.Max(extent.x, Mathf.Max(extent.y, extent.z));
                        Bounds bounds = new Bounds(center, extent * 2);
                        HybridLumenGIProxy proxy = scene.GetProxy(slot);
                        Renderer renderer = scene.GetRenderer(slot);
                        if (renderer != null) { bounds.Encapsulate(renderer.bounds.min); bounds.Encapsulate(renderer.bounds.max); }
                        if (proxy != null && proxy.MeshSdf != null)
                        {
                            Bounds local = proxy.MeshSdf.LocalBounds;
                            Vector3 lo = local.min, hi = local.max;
                            for (int corner = 0; corner < 8; corner++) bounds.Encapsulate(proxy.SdfLocalToWorld.MultiplyPoint3x4(new Vector3(
                                (corner & 1) == 0 ? lo.x : hi.x, (corner & 2) == 0 ? lo.y : hi.y, (corner & 4) == 0 ? lo.z : hi.z)));
                        }
                        Vector3 minimum = bounds.min, maximum = bounds.max;
                        float roundoff = 1e-4f + Mathf.Max(MaxAbs(minimum), MaxAbs(maximum)) * 2e-6f;
                        minimum -= Vector3.one * roundoff; maximum += Vector3.one * roundoff;
                        next.minimum = new Vector4(minimum.x, minimum.y, minimum.z, renderer != null ? 1 : 0);
                        next.maximum = new Vector4(maximum.x, maximum.y, maximum.z, 1);
                    }
                }
                if (!prior.minimum.Equals(next.minimum) || !prior.maximum.Equals(next.maximum))
                {
                    if (prior.maximum.w > 0) dirtyBounds.Add(ToBounds(prior));
                    if (next.maximum.w > 0) dirtyBounds.Add(ToBounds(next));
                }
                objectBounds[slot] = next;
            }
        }

        private bool EnsureStorage(Configuration settings, int objectCount)
        {
            bool reset = DistancesBuffer == null || configuration.LevelCount != settings.LevelCount ||
                configuration.BricksPerAxis != settings.BricksPerAxis || configuration.BaseVoxelSize != settings.BaseVoxelSize ||
                configuration.MaxDistanceInBricks != settings.MaxDistanceInBricks;
            if (reset)
            {
                DistancesBuffer?.Release(); PagesBuffer?.Release(); LevelsBuffer?.Release(); UpdateJobsBuffer?.Release();
                int count = settings.LevelCount * settings.BricksPerAxis * settings.BricksPerAxis * settings.BricksPerAxis;
                pages = new Page[count]; ages = new int[count]; levels = new Level[settings.LevelCount]; jobs = new Job[count];
                dirtyRows = new int[settings.BricksPerAxis * settings.BricksPerAxis];
                DistancesBuffer = Buffer(count * ValuesPerBrick, 4, "HLGI global SDF distances");
                // Initialize generation words to zero. Unwritten voxel payload must never become
                // readable if a recorded update is cancelled before its GPU publish dispatch.
                DistancesBuffer.SetData(new float[count * ValuesPerBrick]);
                PagesBuffer = Buffer(count, PageStride, "HLGI global SDF pages");
                LevelsBuffer = Buffer(levels.Length, LevelStride, "HLGI global SDF levels");
                UpdateJobsBuffer = Buffer(count, JobStride, "HLGI global SDF update jobs");
            }
            objectCount = Math.Max(1, objectCount);
            if (ObjectBoundsBuffer == null || objectBounds.Length != objectCount)
            {
                ObjectBoundsBuffer?.Release();
                objectBounds = new ObjectBounds[objectCount];
                ObjectBoundsBuffer = Buffer(objectCount, ObjectBoundsStride, "HLGI global SDF renderer bounds");
                reset = true;
            }
            return reset;
        }
        private static ComputeBuffer Buffer(int count, int stride, string name) => new ComputeBuffer(count, stride, ComputeBufferType.Structured) { name = name };
        private static Configuration Sanitize(Configuration value)
        {
            value.LevelCount = Mathf.Clamp(value.LevelCount, 2, 4);
            value.BricksPerAxis = value.BricksPerAxis <= 4 ? 4 : value.BricksPerAxis <= 8 ? 8 : 16;
            value.UpdateBrickBudget = Mathf.Clamp(value.UpdateBrickBudget, 0, 1024);
            value.BaseVoxelSize = Finite(value.BaseVoxelSize) ? Mathf.Clamp(value.BaseVoxelSize, 0.01f, 64f) : 0.5f;
            value.MaxDistanceInBricks = Finite(value.MaxDistanceInBricks) ? Mathf.Clamp(value.MaxDistanceInBricks, 0.5f, 4f) : 2f;
            return value;
        }
        private static int WorldKey(float position, float brickSize)
        {
            double key = Math.Floor((double)position / brickSize);
            if (key < int.MinValue + 32.0 || key > int.MaxValue - 32.0) throw new ArgumentOutOfRangeException(nameof(position), "Position exceeds the integer clipmap address range.");
            return (int)key;
        }
        public static int PhysicalPage(int x, int y, int z, int axis)
        {
            int px = ((x % axis) + axis) % axis, py = ((y % axis) + axis) % axis, pz = ((z % axis) + axis) % axis;
            return px + axis * (py + axis * pz);
        }
        private static uint NextGeneration(uint value) => value == uint.MaxValue ? 1 : value + 1;
        private static int ComparePending(Pending a, Pending b)
        {
            int age = b.age.CompareTo(a.age); if (age != 0) return age;
            int level = a.level.CompareTo(b.level); if (level != 0) return level;
            int distance = a.distanceSquared.CompareTo(b.distanceSquared); return distance != 0 ? distance : a.page.CompareTo(b.page);
        }
        private void MarkDirtyRows(Level level, int axis)
        {
            Array.Clear(dirtyRows, 0, dirtyRows.Length);
            // Expand once per region and level. A changed object can lower cached
            // distances outside its own brick, up to the cap plus a voxel diagonal.
            Vector3 padding = Vector3.one * (level.metric.z + level.metric.x * 1.733f);
            float brickSize = level.metric.y;
            int fullRow = (1 << axis) - 1;
            int incompleteRows = dirtyRows.Length;
            foreach (Bounds region in dirtyBounds)
            {
                Vector3 lo = region.min - padding, hi = region.max + padding;
                if (!TryOverlapRange(level.x, axis, brickSize, lo.x, hi.x, out int firstX, out int endX) ||
                    !TryOverlapRange(level.y, axis, brickSize, lo.y, hi.y, out int firstY, out int endY) ||
                    !TryOverlapRange(level.z, axis, brickSize, lo.z, hi.z, out int firstZ, out int endZ)) continue;

                // One bit per logical x coordinate. Physical addressing is handled separately.
                int xMask = ((1 << (endX - firstX)) - 1) << firstX;
                for (int z = firstZ; z < endZ; z++)
                for (int y = firstY; y < endY; y++)
                {
                    int row = z * axis + y;
                    int previous = dirtyRows[row];
                    if (previous == fullRow) continue;
                    int combined = previous | xMask;
                    dirtyRows[row] = combined;
                    if (combined == fullRow) incompleteRows--;
                }
                if (incompleteRows == 0) break;
            }
        }

        private static bool TryOverlapRange(int origin, int axis, float size, float lo, float hi, out int first, out int end)
        {
            // The brick bounds are monotone. Use the same rounded float endpoints
            // and inclusive comparisons as the page intersection, even at a seam.
            first = 0;
            end = axis;
            while (first < end && !((origin + first) * size + size >= lo)) first++;
            while (end > first && !((origin + end - 1) * size <= hi)) end--;
            return first < end;
        }
        private static Bounds ToBounds(ObjectBounds value)
        {
            Vector3 lo = new Vector3(value.minimum.x, value.minimum.y, value.minimum.z), hi = new Vector3(value.maximum.x, value.maximum.y, value.maximum.z);
            return new Bounds((lo + hi) * 0.5f, hi - lo);
        }
        private static float MaxAbs(Vector3 v) => Mathf.Max(Mathf.Abs(v.x), Mathf.Max(Mathf.Abs(v.y), Mathf.Abs(v.z)));
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static bool Finite(Vector3 value) => Finite(value.x) && Finite(value.y) && Finite(value.z);

        /// <summary>Call when a previously recorded update command stream was discarded.</summary>
        public void InvalidateAll()
        {
            for (int i = 0; i < pages.Length; i++)
            {
                Page page = pages[i]; page.ready = 0; page.generation = NextGeneration(page.generation); pages[i] = page;
            }
            prepared = recorded = false; ReadyBrickCount = UpdatedBrickCount = 0;
        }

        public void Dispose()
        {
            DistancesBuffer?.Release(); PagesBuffer?.Release(); LevelsBuffer?.Release(); UpdateJobsBuffer?.Release(); ObjectBoundsBuffer?.Release();
            ClearClipmap();
            ReleaseDisabledBuffers();
        }

        private void ClearClipmap()
        {
            DistancesBuffer = PagesBuffer = LevelsBuffer = UpdateJobsBuffer = ObjectBoundsBuffer = null;
            pages = Array.Empty<Page>(); levels = Array.Empty<Level>(); jobs = Array.Empty<Job>(); objectBounds = Array.Empty<ObjectBounds>(); ages = Array.Empty<int>();
            dirtyRows = Array.Empty<int>();
            configuration = default;
            pending.Clear(); dirtyBounds.Clear(); scene = null; sdf = null; prepared = recorded = false;
            jobCount = ReadyBrickCount = PendingBrickCount = UpdatedBrickCount = InvalidatedBrickCount = 0;
        }

        private void ReleaseDisabledBuffers()
        {
            disabledDistances?.Release(); disabledPages?.Release(); disabledLevels?.Release();
            disabledDistances = disabledPages = disabledLevels = null;
        }
    }
}
