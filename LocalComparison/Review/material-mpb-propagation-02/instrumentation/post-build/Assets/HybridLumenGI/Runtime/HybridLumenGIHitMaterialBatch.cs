using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    [StructLayout(LayoutKind.Sequential,Pack=4)]
    public struct HybridLumenGIHitMaterialBinding
    {
        public HybridLumenGIHitMaterialUInt4 table;  // record index, material generation, zeros
        public HybridLumenGIHitMaterialUInt4 source; // stable ID, owner revision, geometry revision, submesh
    }

    /// <summary>
    /// Main-thread coordinator for one immutable hardware-instance material table and texture upload
    /// lease. Source order is hardware instance order. Record/Bind/Seal must use the same command
    /// buffer, executed once after its producers. Recorded is not GPU ready or submitted evidence.
    /// PollRetired must be called regularly. Unproven references remain strongly held and budgeted.
    /// </summary>
    public sealed class HybridLumenGIHitMaterialBatch : IDisposable
    {
        public const int MaxMaterials=4096,BindingStride=32,MaxResidentBatches=128;
        private static readonly int RecordsId=Shader.PropertyToID("_HLGI_HitMaterials");
        private static readonly int BindingsId=Shader.PropertyToID("_HLGI_HardwareMaterialBindings");
        private static readonly List<HybridLumenGIHitMaterialBatch> Resident=new List<HybridLumenGIHitMaterialBatch>();
        private static uint lastMaterialGeneration;
        public static long TotalMaterialBytes { get; private set; }
        public static long TotalAllocatedBytes => TotalMaterialBytes+HybridLumenGIRayTexturePool.TotalAllocatedBytes;
        public static int ResidentBatchCount => Resident.Count;

        public readonly struct Source
        {
            public readonly HybridLumenGIMaterialSource.Snapshot Snapshot;
            public readonly uint StableId,OwnerRevision,GeometryRevision,Submesh;
            public readonly Vector4 LinearProxyTint,LinearProxyEmission;
            public Source(HybridLumenGIMaterialSource.Snapshot snapshot,uint stableId,uint ownerRevision,
                uint geometryRevision,uint submesh,Vector4 linearProxyTint,Vector4 linearProxyEmission)
            {
                Snapshot=snapshot;StableId=stableId;OwnerRevision=ownerRevision;GeometryRevision=geometryRevision;
                Submesh=submesh;LinearProxyTint=linearProxyTint;LinearProxyEmission=linearProxyEmission;
            }
        }
        public enum BatchState { Prepared,Recording,Recorded,Quarantined,SealedAwaitingFence,ReleasePending,Released }
        private readonly Source[] sources;
        private readonly HybridLumenGIHitMaterialRecord[] encoded;
        private readonly HybridLumenGIMaterialSource validator;
        private readonly HybridLumenGIRayTextureImporter importer;
        private readonly HybridLumenGIRayTexturePool pool;
        private readonly HybridLumenGIRayTexturePool.Lease textureLease;
        private GraphicsBuffer records,bindings;
        private CommandBuffer command;
        private GraphicsFence fence;
        private bool disposed;
        public BatchState State { get; private set; }
        public uint Generation { get; }
        public uint TextureGeneration => textureLease.Generation;
        public int Count => sources.Length;
        public int UnknownRecords { get; private set; }
        public long MaterialByteCount { get; }
        public long ByteCount => MaterialByteCount+textureLease.ByteCount;
        public bool ReusesTextureResidency => textureLease.IsReused;
        public long TextureUploadByteCount => textureLease.UploadByteCount;
        public int TextureUploadCount => textureLease.UploadCount;
        public Texture GetUploadSource(int index) => textureLease.GetUpload(index).View.Texture;
        public Source GetSource(int index) => sources[index];

        private HybridLumenGIHitMaterialBatch(Source[] sources,HybridLumenGIHitMaterialRecord[] encoded,
            uint generation,HybridLumenGIMaterialSource validator,HybridLumenGIRayTextureImporter importer,
            HybridLumenGIRayTexturePool pool,HybridLumenGIRayTexturePool.Lease textureLease)
        {
            this.sources=sources;this.encoded=encoded;Generation=generation;this.validator=validator;this.importer=importer;
            this.pool=pool;this.textureLease=textureLease;MaterialByteCount=(long)sources.Length*(HybridLumenGIHitMaterialLayout.Stride+BindingStride);
            State=BatchState.Prepared;
        }

        private sealed class TextureReferences : IEqualityComparer<Texture>
        {
            internal static readonly TextureReferences Instance=new TextureReferences();
            public bool Equals(Texture a,Texture b) => ReferenceEquals(a,b);
            public int GetHashCode(Texture value) => RuntimeHelpers.GetHashCode(value);
        }

        /// <summary>
        /// Allocates one table and an immutable source-texel lease under a shared global byte limit.
        /// Unsupported source encodings become zero/unknown records. Invalid source collections,
        /// unique texture count, layouts or total budget reject the batch explicitly.
        /// </summary>
        public static bool TryCreate(IReadOnlyList<Source> input,long globalBudgetBytes,
            out HybridLumenGIHitMaterialBatch batch,out string reason,
            HybridLumenGIMaterialSource validator=null,HybridLumenGIRayTextureImporter importer=null)
        {
            batch=null;reason=null;PollRetired();
            if(HybridLumenGIResourceRetirement.AdmissionClosed){reason="GI session admission is closed.";return false;}
            int count;
            try { count=input==null?0:input.Count; }
            catch(Exception ex){reason="Source collection count failed: "+ex.GetType().Name;return false;}
            if(!SystemInfo.supportsGraphicsFence || count<1 || count>MaxMaterials || globalBudgetBytes<0)
            { reason="Missing fence support, invalid material count or budget.";return false; }
            if(Resident.Count>=MaxResidentBatches || lastMaterialGeneration==uint.MaxValue)
            { reason="Outstanding material capacity or non-reusable generation space exhausted.";return false; }
            long materialBytes=(long)count*(HybridLumenGIHitMaterialLayout.Stride+BindingStride);
            // The pool may borrow an existing allocation or evict completion-proven idle
            // storage. Do not reject against its pre-trim total before it sees this request.
            if(materialBytes>globalBudgetBytes || TotalMaterialBytes>globalBudgetBytes-materialBytes)
            { reason="Global budget includes all material and texture resources awaiting completion.";return false; }
            var frozen=new Source[count];var usable=new bool[frozen.Length];
            var mapping=new int[frozen.Length*HybridLumenGIHitMaterialLayout.TextureCount];
            for(int i=0;i<mapping.Length;i++)mapping[i]=-1;
            var views=new List<HybridLumenGIFrozenTextureView>();
            var precision=new List<bool>();
            var byTexture=new Dictionary<Texture,List<int>>(TextureReferences.Instance);
            var emptyHandles=new HybridLumenGIRayTexturePool.Handle[HybridLumenGIHitMaterialLayout.TextureCount];
            try
            {
                for(int index=0;index<frozen.Length;index++)
                {
                    Source source=input[index];frozen[index]=source;
                    if(!SourceIdentityValid(source) || !HybridLumenGIHitMaterialLayout.TryEncode(source.Snapshot.HitMaterial,1,
                        emptyHandles,source.LinearProxyTint,source.LinearProxyEmission,out _,out _)) continue;
                    usable[index]=true;var material=source.Snapshot.HitMaterial;
                    uint flags=HybridLumenGIHitMaterialLayout.KeywordFlags(material);
                    for(int map=0;map<HybridLumenGIHitMaterialLayout.TextureCount;map++)
                    {
                        if(!HybridLumenGIHitMaterialLayout.UsesTexture(flags,map)) continue;
                        var view=HybridLumenGIHitMaterialLayout.GetTexture(material,map);
                        if(ReferenceEquals(view.Texture,null)) continue;
                        // Coverage inputs must not acquire new binary16 rounding at the cutoff
                        // or in the height value which shifts the alpha lookup coordinate.
                        bool coverageWide=(flags&HybridLumenGIHitMaterialLayout.AlphaTest)!=0&&(map==0||map==9);
                        if(!byTexture.TryGetValue(view.Texture,out var candidates))
                        { candidates=new List<int>();byTexture.Add(view.Texture,candidates); }
                        int request=-1;
                        foreach(int candidate in candidates)if(views[candidate].Equals(view)){request=candidate;break;}
                        if(request<0)
                        {
                            if(views.Count>=HybridLumenGIRayTexturePool.MaxRequests)
                            { reason="Unique used texture observations exceed the pool request capacity.";return false; }
                            request=views.Count;views.Add(view);precision.Add(coverageWide);candidates.Add(request);
                        }
                        else precision[request]|=coverageWide;
                        mapping[index*HybridLumenGIHitMaterialLayout.TextureCount+map]=request;
                    }
                }
            }
            catch(Exception ex){reason="Source collection or frozen material invalid: "+ex.GetType().Name;return false;}
            // The pool's real 80-byte dummy binds valid descriptors for all-constant materials.
            if(views.Count==0){views.Add(default);precision.Add(false);}
            var textureRequests=new HybridLumenGIRayTexturePool.Request[views.Count];
            for(int i=0;i<views.Count;i++)textureRequests[i]=new HybridLumenGIRayTexturePool.Request(views[i],precision[i]);
            var pool=new HybridLumenGIRayTexturePool();
            long textureBudget=globalBudgetBytes-TotalMaterialBytes-materialBytes;
            if(!pool.TryPrepareRequests(textureRequests,textureBudget,out var lease,out reason)){pool.Dispose();return false;}
            uint generation=++lastMaterialGeneration;
            var encoded=new HybridLumenGIHitMaterialRecord[frozen.Length];
            try
            {
                for(int index=0;index<encoded.Length;index++)
                {
                    if(!usable[index]) continue;
                    var handles=new HybridLumenGIRayTexturePool.Handle[HybridLumenGIHitMaterialLayout.TextureCount];
                    for(int map=0;map<handles.Length;map++)
                    { int request=mapping[index*handles.Length+map];if(request>=0)handles[map]=lease.GetHandle(request); }
                    var source=frozen[index];
                    HybridLumenGIHitMaterialLayout.TryEncode(source.Snapshot.HitMaterial,generation,handles,
                        source.LinearProxyTint,source.LinearProxyEmission,out encoded[index],out _);
                }
            }
            catch(Exception ex){pool.ReleaseUnrecorded(lease);pool.Dispose();reason="Material encoding failed: "+ex.GetType().Name;return false;}
            var next=new HybridLumenGIHitMaterialBatch(frozen,encoded,generation,validator??new HybridLumenGIMaterialSource(),
                importer??new HybridLumenGIRayTextureImporter(),pool,lease);
            // Account before native allocation. A partial disposal failure remains budgeted.
            Resident.Add(next);TotalMaterialBytes+=materialBytes;
            try
            {
                next.records=new GraphicsBuffer(GraphicsBuffer.Target.Structured,frozen.Length,HybridLumenGIHitMaterialLayout.Stride);
                next.bindings=new GraphicsBuffer(GraphicsBuffer.Target.Structured,frozen.Length,BindingStride);
                batch=next;return true;
            }
            catch(Exception ex){next.Dispose();reason="Material buffer allocation failed: "+ex.GetType().Name;return false;}
        }

        private static bool SourceIdentityValid(Source source) => source.Snapshot!=null && source.StableId!=0 &&
            source.OwnerRevision!=0 && source.GeometryRevision!=0 && source.Snapshot.MaterialIndex>=0 &&
            (uint)source.Snapshot.MaterialIndex==source.Submesh;

        private bool SourceStillMatches(Source source)
        {
            if(!SourceIdentityValid(source))return false;
            try
            {
                var snapshot=source.Snapshot;
                // Do not call IsCurrent: RenderTexture disallows historical reuse but can
                // still be captured this frame after its explicitly ordered producer.
                return validator.TryCapture(snapshot.SourceRenderer,snapshot.MaterialIndex,snapshot.SourceMaterial,out var current,out _) &&
                    snapshot.Equals(current);
            }
            catch{return false;}
        }

        /// <summary>
        /// Revalidates frozen material sources, records source uploads and then immutable tables.
        /// A changed source is zero/unknown, never re-encoded from live replacement values. The
        /// importer and shader alone establish texture ready. Same command buffer executes once.
        /// </summary>
        public bool Record(CommandBuffer cmd,out string reason)
        {
            reason=null;
            if(disposed || cmd==null || State!=BatchState.Prepared){reason="Batch is canceled, invalid or already recorded.";return false;}
            var materialRecords=(HybridLumenGIHitMaterialRecord[])encoded.Clone();
            var materialBindings=new HybridLumenGIHitMaterialBinding[Count];
            for(int i=0;i<Count;i++)if(materialRecords[i].identity.x==0 || !SourceStillMatches(sources[i]))materialRecords[i]=default;
            // Source APIs may invoke user code. A pristine cancellation must not be resurrected.
            if(disposed || State!=BatchState.Prepared){reason="Batch canceled during source validation.";return false;}
            command=cmd;State=BatchState.Recording;
            try
            {
                if(!pool.RecordUploads(cmd,textureLease,importer.Record,out reason))
                { Quarantine();return false; }
                if(disposed || State!=BatchState.Recording)throw new InvalidOperationException("Batch canceled during upload recording.");
                UnknownRecords=0;
                for(int i=0;i<Count;i++)
                {
                    // Catch a material/source change made by a producer/import callback.
                    // An earlier rejection never becomes valid again during this recording.
                    if(materialRecords[i].identity.x==0 || !SourceStillMatches(sources[i]) || !HandlesInitialized(materialRecords[i]))
                    { materialRecords[i]=default;UnknownRecords++;continue; }
                    Source source=sources[i];
                    materialBindings[i]=new HybridLumenGIHitMaterialBinding
                    {
                        table=new HybridLumenGIHitMaterialUInt4((uint)i,Generation,0,0),
                        source=new HybridLumenGIHitMaterialUInt4(source.StableId,source.OwnerRevision,source.GeometryRevision,source.Submesh)
                    };
                }
                if(disposed || State!=BatchState.Recording)throw new InvalidOperationException("Batch canceled during source revalidation.");
                MaterialEventTap.MaterialUpload(Generation,sources,materialRecords,materialBindings);
                cmd.SetBufferData(records,materialRecords);
                cmd.SetBufferData(bindings,materialBindings);
                if(disposed || State!=BatchState.Recording)throw new InvalidOperationException("Batch canceled during table recording.");
                State=BatchState.Recorded;return true;
            }
            catch(Exception ex){Quarantine();reason="Material recording unproven: "+ex.GetType().Name;return false;}
        }

        private bool HandlesInitialized(HybridLumenGIHitMaterialRecord record)
        {
            // A frame quota may defer even the first ready=0 metadata write. Such
            // rows are unknown and must not expose an uninitialized descriptor.
            foreach(var pair in new[]{record.textures0,record.textures1,record.textures2,record.textures3,record.textures4})
            {
                if(pair.y!=0&&!pool.IsHandleCurrent(textureLease,new HybridLumenGIRayTexturePool.Handle(pair.x,pair.y)))return false;
                if(pair.w!=0&&!pool.IsHandleCurrent(textureLease,new HybridLumenGIRayTexturePool.Handle(pair.z,pair.w)))return false;
            }
            return true;
        }

        /// <summary>Borrow only for RenderGraph declarations; no mutation, disposal or consumption authority.</summary>
        public bool GetResources(out GraphicsBuffer materialRecords,out GraphicsBuffer materialBindings,
            out GraphicsBuffer textureMetadata,out GraphicsBuffer textureTexels)
        {
            materialRecords=materialBindings=textureMetadata=textureTexels=null;
            if(disposed || (State!=BatchState.Prepared && State!=BatchState.Recorded) ||
                !pool.GetResources(textureLease,out textureMetadata,out textureTexels))return false;
            materialRecords=records;materialBindings=bindings;return true;
        }

        public bool Bind(CommandBuffer cmd,ComputeShader shader,int kernel,out string reason)
        {
            reason=null;
            if(disposed || State!=BatchState.Recorded || !ReferenceEquals(command,cmd) || shader==null || kernel<0)
            { reason="Only this recorded batch's command buffer may bind before sealing.";return false; }
            try
            {
                if(!pool.Bind(cmd,shader,kernel,textureLease,out reason)){Quarantine();return false;}
                if(disposed || State!=BatchState.Recorded)throw new InvalidOperationException("Batch canceled during texture binding.");
                cmd.SetComputeBufferParam(shader,kernel,RecordsId,records);
                cmd.SetComputeBufferParam(shader,kernel,BindingsId,bindings);
                if(disposed || State!=BatchState.Recorded)throw new InvalidOperationException("Batch canceled during material binding.");
                return true;
            }
            catch(Exception ex){Quarantine();reason="Material consumer binding unproven: "+ex.GetType().Name;return false;}
        }

        /// <summary>
        /// Append after every consumer on the same command buffer. This seals further use; it does
        /// not claim CPU submission or GPU completion. Caller must execute once after producers.
        /// A canceled/quarantined batch can accept this evidence solely for eventual retirement.
        /// Without a valid final-consumer fence its resources remain retained indefinitely.
        /// </summary>
        public bool SealAfterConsumers(CommandBuffer cmd,out string reason)
        {
            reason=null;
            if(cmd==null || !ReferenceEquals(command,cmd) ||
                (State!=BatchState.Recorded && State!=BatchState.Quarantined))
            { reason="Batch has no compatible unsealed command recording.";return false; }
            if(!SystemInfo.supportsGraphicsFence){Quarantine();reason="Graphics fence support unavailable.";return false;}
            try
            {
                var finalFence=cmd.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation,SynchronisationStageFlags.AllGPUOperations);
                if(!pool.MarkSubmitted(textureLease,finalFence,out reason)){Quarantine();return false;}
                fence=finalFence;State=BatchState.SealedAwaitingFence;return true;
            }
            catch(Exception ex){Quarantine();reason="Final-consumer fence unproven: "+ex.GetType().Name;return false;}
        }

        private void Quarantine()
        {
            if(State==BatchState.Released || State==BatchState.ReleasePending)return;
            State=BatchState.Quarantined;pool.Quarantine(textureLease);
        }
        public static void PollRetired()
        {
            HybridLumenGIRayTexturePool.PollRetired();
            for(int i=Resident.Count-1;i>=0;i--)
            {
                var batch=Resident[i];
                if(batch.State==BatchState.SealedAwaitingFence)
                {
                    try
                    {
                        // The pool may already have proved completion in its poll above. A
                        // failed disposal does not revoke that completion proof.
                        if(batch.textureLease.State==HybridLumenGIRayTexturePool.LeaseState.Released ||
                            batch.textureLease.State==HybridLumenGIRayTexturePool.LeaseState.ReleasePending)
                            batch.State=BatchState.ReleasePending;
                        else if(!SystemInfo.supportsGraphicsFence)batch.Quarantine();
                        else if(batch.fence.passed)
                        {
                            // A transient failure in the pool's earlier fence read must not
                            // strand its resources after we release the only coordinator.
                            // Re-submit only this same actual fence, never a synthesized bool.
                            if(batch.textureLease.State==HybridLumenGIRayTexturePool.LeaseState.Quarantined &&
                                !batch.pool.MarkSubmitted(batch.textureLease,batch.fence,out _))
                            { batch.Quarantine();continue; }
                            HybridLumenGIRayTexturePool.PollRetired();
                            if(batch.textureLease.State==HybridLumenGIRayTexturePool.LeaseState.Released ||
                                batch.textureLease.State==HybridLumenGIRayTexturePool.LeaseState.ReleasePending)
                                batch.State=BatchState.ReleasePending;
                            else if(batch.textureLease.State==HybridLumenGIRayTexturePool.LeaseState.Quarantined)
                                batch.Quarantine();
                        }
                    }
                    catch{batch.Quarantine();}
                }
                if(batch.State==BatchState.ReleasePending)batch.TryRelease();
            }
        }
        private void TryRelease()
        {
            try
            {
                if(records!=null){records.Dispose();records=null;}
                if(bindings!=null){bindings.Dispose();bindings=null;}
            }
            catch{return;}
            // The texture pool independently applies the same fence or pristine proof.
            pool.Dispose();State=BatchState.Released;Resident.Remove(this);TotalMaterialBytes-=MaterialByteCount;
        }
        public void Dispose()
        {
            if(disposed)return;disposed=true;
            if(State==BatchState.Prepared)
            { pool.ReleaseUnrecorded(textureLease);State=BatchState.ReleasePending; }
            else if(State==BatchState.Recording || State==BatchState.Recorded)Quarantine();
            pool.Dispose();PollRetired();
        }
    }
}
