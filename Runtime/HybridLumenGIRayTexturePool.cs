using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;
using Stopwatch = System.Diagnostics.Stopwatch;

namespace HybridLumenGI
{
    /// <summary>
    /// Main-thread texture pages in bounded shared GPU arenas. Consumers lease immutable pages;
    /// replacing one texture does not upload other resident pages. Reuse of ordinary Texture2D
    /// requires an exact frozen observation, completed consumer fence and GPU metadata readback.
    /// GPU/native producers must IncrementUpdateCount. InvalidateSource revokes before write/unload.
    /// RTs never reuse. Active, idle, readback and quarantined arena capacity is globally budgeted.
    /// </summary>
    public sealed class HybridLumenGIRayTexturePool : IDisposable
    {
        public const int MetadataStride=64,MaxRequests=1024,MaxBatchesPerPool=32,MaxResidentBatches=128;
        private static readonly int MetadataId=Shader.PropertyToID("_HLGI_RayTextureMetadata");
        private static readonly int TexelsId=Shader.PropertyToID("_HLGI_RayTextureTexels");
        private static readonly List<Lease> Resident=new List<Lease>();
        private static readonly List<Allocation> Allocations=new List<Allocation>();
        private sealed class SourceState
        {
            internal ulong Epoch;
            internal UploadTurn SharedTurn;
            internal ConditionalWeakTable<object, UploadTurn> ConsumerTurns;
        }
        private sealed class TextureViewComparer : IEqualityComparer<HybridLumenGIFrozenTextureView>
        {
            internal static readonly TextureViewComparer Instance = new TextureViewComparer();
            public bool Equals(HybridLumenGIFrozenTextureView a, HybridLumenGIFrozenTextureView b) => a.Equals(b);
            public int GetHashCode(HybridLumenGIFrozenTextureView view)
                => unchecked((RuntimeHelpers.GetHashCode(view.Texture) * 397 ^ view.GetHashCode()) * 397 ^ (int)view.UpdateCount);
        }
        private sealed class UploadTurn
        {
            internal readonly SourceState Source;
            internal ulong Order;
            internal UploadTurn(SourceState source) { Source = source; }
        }
        private struct UploadDemand
        {
            internal UploadTurn Turn;
            internal long Bytes, ReservedFrame;
        }
        private sealed class ConsumerCadence
        {
            internal int Frame = -1;
            internal long Interval = 1;
        }
        private static readonly ConditionalWeakTable<Texture,SourceState> Sources=new ConditionalWeakTable<Texture,SourceState>();
        private static ConditionalWeakTable<object,ConsumerCadence> consumerCadences = new();
        private static UploadDemand uploadWaiter, nextUploadWaiter;
        private static readonly List<UploadDemand> laterUploadWaiters = new();
        private static uint lastGeneration;
        private static ulong lastSourceEpoch, lastUploadOrder;
        private static int uploadFrame=-1;
        private static long uploadBudget=long.MaxValue,uploadUsed;
        public static int UploadFrame=>uploadFrame;
        public static long UploadBytesUsed=>uploadUsed;
        public static long UploadBudgetBytes=>uploadBudget;
        internal static void ResetFrameAdmission()
        {
            uploadFrame = -1;
            uploadBudget = long.MaxValue;
            uploadUsed = 0;
            uploadWaiter = nextUploadWaiter = default;
            laterUploadWaiters.Clear();
            consumerCadences = new();
        }
        /// <summary>Call on the main thread for every camera. Same-frame calls never replenish the global allowance.</summary>
        public static void BeginFrame(int engineFrame,long maxUploadBytes)
        {
            if(engineFrame<0||engineFrame<uploadFrame||maxUploadBytes<80)throw new ArgumentOutOfRangeException(nameof(maxUploadBytes));
            if (engineFrame == uploadFrame)
            {
                // A later camera tightens this frame. Earlier requests can still take
                // their turn when the next frame starts with a larger allowance.
                uploadBudget = Math.Min(uploadBudget, maxUploadBytes);
                return;
            }
            if (uploadWaiter.Bytes > maxUploadBytes || uploadWaiter.ReservedFrame != engineFrame)
                uploadWaiter = default;
            PromoteUploadWaiter(nextUploadWaiter, engineFrame, maxUploadBytes);
            nextUploadWaiter = default;
            for (int i = laterUploadWaiters.Count - 1; i >= 0; i--)
            {
                var demand = laterUploadWaiters[i];
                if (demand.ReservedFrame > engineFrame) continue;
                PromoteUploadWaiter(demand, engineFrame, maxUploadBytes);
                laterUploadWaiters.RemoveAt(i);
            }
            uploadFrame = engineFrame;
            uploadUsed = 0;
            uploadBudget = maxUploadBytes;
        }

        private static void PromoteUploadWaiter(UploadDemand demand, int frame, long budget)
        {
            if (demand.Turn != null && demand.ReservedFrame == frame && demand.Bytes <= budget &&
                (uploadWaiter.Turn == null || demand.Turn.Order < uploadWaiter.Turn.Order))
                uploadWaiter = demand;
        }

        private static long ObserveUploadConsumer(object consumer)
        {
            if (consumer == null) return 1;
            var cadence = consumerCadences.GetValue(consumer, static _ => new ConsumerCadence());
            if (cadence.Frame != uploadFrame)
            {
                cadence.Interval = cadence.Frame < 0 ? 1 : (long)uploadFrame - cadence.Frame;
                cadence.Frame = uploadFrame;
            }
            return cadence.Interval;
        }
        public static long TotalAllocatedBytes {get;private set;}
        public static int ResidentBatchCount=>Allocations.Count;
        private readonly List<Lease> leases=new List<Lease>();
        private bool disposed;
        // Attribution can overlap; global bytes count physical arena capacity exactly once.
        public long AllocatedBytes {get;private set;}
        public int BatchCount=>leases.Count;
        public enum LeaseState {Prepared,Recording,Recorded,Submitted,Quarantined,ReleasePending,Released}
        public readonly struct Handle
        {
            public readonly uint Index,Generation;
            public bool IsValid=>Generation!=0;
            internal Handle(uint index,uint generation){Index=index;Generation=generation;}
        }
        public readonly struct Request
        {
            public readonly HybridLumenGIFrozenTextureView View;
            public readonly bool RequireFloat32;
            public Request(HybridLumenGIFrozenTextureView view,bool requireFloat32=false)
            {View=view;RequireFloat32=requireFloat32;}
        }
        public readonly struct Upload
        {
            public readonly HybridLumenGIFrozenTextureView View;
            public readonly HybridLumenGIRayTextureLayout Layout;
            public readonly int MetadataIndex,TexelOffset;
            public readonly uint Generation;
            public readonly bool Progressive,Begin,Finish;
            public readonly int RangeStart,RangeCount;
            internal Upload(HybridLumenGIFrozenTextureView view,HybridLumenGIRayTextureLayout layout,int index,int offset,uint generation)
            {View=view;Layout=layout;MetadataIndex=index;TexelOffset=offset;Generation=generation;Progressive=Begin=Finish=false;RangeStart=RangeCount=0;}
            internal Upload(Upload source,int start,int count)
            {View=source.View;Layout=source.Layout;MetadataIndex=source.MetadataIndex;TexelOffset=source.TexelOffset;Generation=source.Generation;
             Progressive=true;RangeStart=start;RangeCount=count;Begin=start==0;Finish=start+count==source.Layout.StorageElementCount;}
        }
        internal sealed class Page
        {
            internal readonly Upload Upload;
            internal readonly HybridLumenGIRayTextureMetadata Initial;
            internal readonly ulong Epoch;
            internal int Readers;
            internal bool Reusable,Ready,ReadbackPending,ReadbackStarted;
            internal bool MetadataInitialized,UploadComplete,UploadRejected;
            internal int UploadedElements;
            internal Page(Upload upload,HybridLumenGIRayTextureMetadata initial,ulong epoch,bool reusable)
            {Upload=upload;Initial=initial;Epoch=epoch;Reusable=reusable;}
        }
        internal sealed class Allocation
        {
            internal readonly uint Generation;
            internal readonly long Bytes;
            internal readonly int Capacity;
            internal readonly Page[] Pages;
            internal readonly bool Shareable;
            internal GraphicsBuffer Metadata,Texels;
            internal int Readers;
            internal bool Initialized,Established,Retiring;
            internal Allocation(uint generation,int capacity,int metadataCount,bool shareable)
            {Generation=generation;Capacity=capacity;Pages=new Page[metadataCount];Bytes=(long)capacity*16+(long)metadataCount*64;Shareable=shareable;}
        }
        public sealed class Lease
        {
            internal readonly HybridLumenGIRayTexturePool Owner;
            internal readonly Allocation allocation;
            internal readonly Page[] Pages,Uploads;
            internal readonly Handle[] Handles;
            private readonly ulong[] borrowedPageSlots;
            internal readonly List<ulong> DeferredWaitOrders;
            internal GraphicsFence Fence;
            public uint Generation=>allocation.Generation;
            public long ByteCount=>allocation.Bytes;
            public int TexelCapacity=>allocation.Capacity;
            /// <summary>The arena is borrowed; some new pages may still require upload.</summary>
            public bool IsReused {get;}
            public long UploadByteCount {get;}
            public int UploadCount=>Uploads.Length;
            public int RequestCount=>Handles.Length;
            public LeaseState State {get;internal set;}
            public Upload GetUpload(int index)=>Uploads[index].Upload;
            public Handle GetHandle(int index)=>Handles[index];
            internal Lease(HybridLumenGIRayTexturePool owner,Allocation allocation,Page[] pages,Page[] uploads,Handle[] handles,bool reused,List<ulong> deferredWaitOrders)
            {
                Owner=owner;this.allocation=allocation;Pages=pages;Uploads=uploads;Handles=handles;IsReused=reused;State=LeaseState.Prepared;
                DeferredWaitOrders=deferredWaitOrders;
                borrowedPageSlots = new ulong[(allocation.Pages.Length + 63) / 64];
                foreach (var page in pages)
                {
                    int slot = page.Upload.MetadataIndex;
                    borrowedPageSlots[slot / 64] |= 1ul << (slot % 64);
                }
                foreach(var page in uploads)UploadByteCount+=page.Upload.Layout.ByteCount+64;
            }

            internal Page GetBorrowedPage(uint slot)
            {
                if (slot >= allocation.Pages.Length || (borrowedPageSlots[slot / 64] & (1ul << (int)(slot % 64))) == 0) return null;
                // The lease's reader count pins the borrowed slot until this lease retires.
                return allocation.Pages[slot];
            }
        }
        private static SourceState GetSourceState(Texture texture)=>Sources.GetValue(texture,_=>new SourceState());
        private static UploadTurn GetUploadTurn(Page page, object uploadConsumer)
        {
            var source = GetSourceState(page.Upload.View.Texture);
            UploadTurn turn;
            // An unshareable page needs its own copy for each camera, even for the same texture.
            if (page.Reusable || uploadConsumer == null) turn = source.SharedTurn ??= new UploadTurn(source);
            else
            {
                var consumers = source.ConsumerTurns ??= new ConditionalWeakTable<object, UploadTurn>();
                if (!consumers.TryGetValue(uploadConsumer, out turn))
                {
                    turn = new UploadTurn(source);
                    consumers.Add(uploadConsumer, turn);
                }
            }
            return turn;
        }
        private static ulong Epoch(Texture texture)=>Sources.TryGetValue(texture,out var state)?state.Epoch:0;
        public static void InvalidateSource(Texture texture)
        {
            if(ReferenceEquals(texture,null))return;
            if(lastSourceEpoch==ulong.MaxValue)throw new InvalidOperationException("Source epochs exhausted; cannot wrap.");
            var source = GetSourceState(texture);
            source.Epoch = ++lastSourceEpoch;
            if (ReferenceEquals(uploadWaiter.Turn?.Source, source)) uploadWaiter = default;
            if (ReferenceEquals(nextUploadWaiter.Turn?.Source, source)) nextUploadWaiter = default;
            laterUploadWaiters.RemoveAll(demand => ReferenceEquals(demand.Turn.Source, source));
            foreach(var allocation in Allocations)foreach(var page in allocation.Pages)
                if(page!=null&&ReferenceEquals(page.Upload.View.Texture,texture))page.Reusable=false;
            PollRetired();
        }
        /// <summary>Invalidate and stop new requests first; false then authorizes source asset unload.</summary>
        public static bool IsSourceReferenced(Texture texture)
        {
            if(ReferenceEquals(texture,null))return false;
            foreach(var allocation in Allocations)foreach(var page in allocation.Pages)
                if(page!=null&&ReferenceEquals(page.Upload.View.Texture,texture))return true;
            return false;
        }
        public static void ClearReusable()
        {foreach(var allocation in Allocations)foreach(var page in allocation.Pages)if(page!=null)page.Reusable=false;PollRetired();}
        private static bool Current(Page page)
        {
            try{return page.Epoch==Epoch(page.Upload.View.Texture)&&HybridLumenGIRayTextureImporter.SourceStillMatches(page.Upload.View);}
            catch{return false;}
        }
        private static bool Reusable(HybridLumenGIFrozenTextureView view)=>SystemInfo.supportsAsyncGPUReadback&&view.HasTexture2DMipState&&!view.IsRenderTexture;
        private static bool Trim(long budget,Allocation keep=null,int arenaLimit=int.MaxValue)
        {
            for(int i=0;i<Allocations.Count&&(TotalAllocatedBytes>budget||Allocations.Count>arenaLimit);)
            {
                var allocation=Allocations[i];bool pending=false;
                foreach(var page in allocation.Pages)pending|=page!=null&&page.ReadbackPending;
                if(!ReferenceEquals(keep,allocation)&&allocation.Readers==0&&!pending&&TryFree(allocation))continue;
                i++;
            }
            return TotalAllocatedBytes<=budget&&Allocations.Count<=arenaLimit;
        }
        // Best-fit holes are derived from live pages. Old-reader and readback pages stay occupied.
        private static bool Plan(Allocation arena,List<HybridLumenGIRayTextureLayout> layouts,
            Dictionary<HybridLumenGIFrozenTextureView,int> viewIndices,out Page[] pages,out int[] slots,out int[] offsets,bool[] pendingViews)
        {
            pages=new Page[layouts.Count];slots=new int[layouts.Count];offsets=new int[layouts.Count];
            // Match in physical slot order to retain the first eligible copy of each view.
            foreach (var page in arena.Pages)
            {
                if (page == null || !page.Reusable) continue;
                var view = page.Upload.View;
                if (!viewIndices.TryGetValue(view, out int index) || pages[index] != null || !Reusable(view) || page.Epoch != Epoch(view.Texture) ||
                    (!layouts[index].PackedHalf && page.Upload.Layout.PackedHalf) ||
                    (!page.Ready && (pendingViews?[index] == true || page.UploadComplete || page.Readers != 0 || page.ReadbackPending))) continue;
                pages[index] = page;
            }

            List<(int Start,int End)> occupied = null;
            bool[] used = null;
            for(int i=0;i<layouts.Count;i++)
            {
                slots[i]=-1;
                if(pages[i]!=null)continue;
                // A matching upload in another arena prevents a new copy, but not reuse of a ready page.
                if (pendingViews?[i] == true) return false;
                if (used == null)
                {
                    used = new bool[arena.Pages.Length];
                    occupied = new List<(int Start,int End)>();
                    for (int slotIndex = 0; slotIndex < arena.Pages.Length; slotIndex++)
                    {
                        var page = arena.Pages[slotIndex];
                        if (page == null) continue;
                        used[slotIndex] = true;
                        occupied.Add((page.Upload.TexelOffset, page.Upload.TexelOffset + page.Upload.Layout.StorageElementCount));
                    }
                }
                int slot=Array.FindIndex(used,value=>!value);if(slot<0)return false;
                occupied.Sort((a,b)=>a.Start.CompareTo(b.Start));int start=0,best=-1,bestSize=int.MaxValue;
                foreach(var region in occupied)
                {int gap=region.Start-start;if(gap>=layouts[i].StorageElementCount&&gap<bestSize){best=start;bestSize=gap;}start=Math.Max(start,region.End);}
                int tail=arena.Capacity-start;if(tail>=layouts[i].StorageElementCount&&tail<bestSize)best=start;
                if(best<0)return false;
                used[slot]=true;slots[i]=slot;offsets[i]=best;occupied.Add((best,best+layouts[i].StorageElementCount));
            }
            return true;
        }

        private static Allocation FindArena(List<HybridLumenGIRayTextureLayout> layouts,
            Dictionary<HybridLumenGIFrozenTextureView,int> viewIndices,bool[] pendingViews,
            out Page[] chosenPages, out int[] chosenSlots, out int[] chosenOffsets)
        {
            Allocation chosen = null;
            chosenPages = null;
            chosenSlots = chosenOffsets = null;
            int bestReused = -1;
            foreach (var arena in Allocations)
            {
                if (!arena.Shareable || !arena.Established || arena.Retiring) continue;
                if (!Plan(arena, layouts, viewIndices, out var pages, out var slots, out var offsets, pendingViews)) continue;
                int reused = 0;
                foreach (var page in pages)
                    if (page != null) reused++;
                if (reused <= bestReused) continue;
                chosen = arena;
                chosenPages = pages;
                chosenSlots = slots;
                chosenOffsets = offsets;
                bestReused = reused;
            }
            return chosen;
        }

        private Lease Borrow(Allocation arena,Page[] pages,Page[] uploads,int[] indices,bool reused,List<ulong> deferredWaitOrders)
        {
            var handles=new Handle[indices.Length];
            for(int i=0;i<indices.Length;i++)if(indices[i]>=0)
            {var p=pages[indices[i]];handles[i]=new Handle((uint)p.Upload.MetadataIndex,p.Upload.Generation);}
            var lease=new Lease(this,arena,pages,uploads,handles,reused,deferredWaitOrders);arena.Readers++;
            foreach(var page in pages)page.Readers++;
            Resident.Add(lease);leases.Add(lease);AllocatedBytes+=arena.Bytes;return lease;
        }
        public bool TryPrepare(IReadOnlyList<HybridLumenGIFrozenTextureView> requests,long budgetBytes,out Lease lease,out string reason)
        {
            lease=null;reason=null;
            if(requests==null||requests.Count<1||requests.Count>MaxRequests){reason="Invalid texture requests.";return false;}
            var converted=new Request[requests.Count];
            try{for(int i=0;i<converted.Length;i++)converted[i]=new Request(requests[i]);}
            catch(Exception ex){reason="Frozen request enumeration failed: "+ex.GetType().Name;return false;}
            return TryPrepareRequests(converted,budgetBytes,out lease,out reason);
        }
        /// <summary>Precision is part of the page contract. A resident wide page can satisfy a narrow request, never the reverse.</summary>
        public bool TryPrepareRequests(IReadOnlyList<Request> requests,long budgetBytes,out Lease lease,out string reason)
            => TryPrepareRequests(requests,budgetBytes,out lease,out reason,omitPendingPages:false);

        internal bool TryPrepareRequests(IReadOnlyList<Request> requests,long budgetBytes,out Lease lease,out string reason,
            bool omitPendingPages)
        {
            lease=null;reason=null;PollRetired();
            if(HybridLumenGIResourceRetirement.AdmissionClosed){reason="GI session admission is closed.";return false;}
            if(disposed||!SystemInfo.supportsGraphicsFence||requests==null||requests.Count<1||requests.Count>MaxRequests||budgetBytes<0)
            {reason="Disposed pool or invalid request count/budget.";return false;}
            if(leases.Count>=MaxBatchesPerPool||Resident.Count>=MaxResidentBatches)
            {reason="Outstanding consumer lease capacity reached.";return false;}
            var views=new List<HybridLumenGIFrozenTextureView>();var layouts=new List<HybridLumenGIRayTextureLayout>();
            var viewIndices = new Dictionary<HybridLumenGIFrozenTextureView,int>(TextureViewComparer.Instance);
            int[] indices=new int[requests.Count];long capacity=0;int largest=0;bool shareable=SystemInfo.supportsAsyncGPUReadback;
            try
            {
                for(int i=0;i<indices.Length;i++)
                {
                    var request=requests[i];var view=request.View;indices[i]=-1;if(ReferenceEquals(view.Texture,null))continue;
                    if(view.Dimension!=2||!HybridLumenGIRayTextureLayout.TryCreate(view.Width,view.Height,view.MipmapCount,0,out var layout,
                        !request.RequireFloat32&&HybridLumenGIRayTextureLayout.CanPackHalf(view.GraphicsFormat))||
                        !layout.TryMakeMetadata(0,layout.StorageElementCount,1,view.FilterMode,view.WrapModeU,view.WrapModeV,view.MipMapBias,view.AnisoLevel,out _))
                    {reason="Unsupported frozen texture layout or sampler.";return false;}
                    if(viewIndices.TryGetValue(view,out int existing))
                    {
                        indices[i]=existing;
                        if(layouts[existing].PackedHalf&&!layout.PackedHalf)
                        {capacity+=layout.StorageElementCount-layouts[existing].StorageElementCount;layouts[existing]=layout;largest=Math.Max(largest,layout.StorageElementCount);}
                        if(capacity>int.MaxValue){reason="Combined texture capacity exceeds int range.";return false;}
                        continue;
                    }
                    indices[i]=views.Count;viewIndices.Add(view,views.Count);views.Add(view);layouts.Add(layout);capacity+=layout.StorageElementCount;largest=Math.Max(largest,layout.StorageElementCount);
                    if(capacity>int.MaxValue){reason="Combined texture capacity exceeds int range.";return false;}
                }
            }
            catch(Exception ex){reason="Frozen request enumeration failed: "+ex.GetType().Name;return false;}
            shareable &= views.Count>0;
            Allocation chosen=null;Page[] chosenPages=null;int[] chosenSlots=null,chosenOffsets=null;
            List<ulong> deferredWaitOrders = null;
            if(shareable)
            {
                const string arenaBudgetExceeded = "Global budget includes all resident and pending texture arenas.";
                bool[] pendingViews = null;
                foreach (var arena in Allocations)
                foreach (var page in arena.Pages)
                {
                    if (page == null || !page.Reusable || page.Ready || page.Epoch != Epoch(page.Upload.View.Texture)) continue;
                    if (arena.Established && !page.UploadComplete && page.Readers == 0 && !page.ReadbackPending) continue;
                    if (!viewIndices.TryGetValue(page.Upload.View,out int index) || (!layouts[index].PackedHalf && page.Upload.Layout.PackedHalf)) continue;
                    pendingViews ??= new bool[views.Count];
                    pendingViews[index] = true;
                }

                // Try the complete batch first. It may borrow a current ready copy while
                // a different arena's copy is still waiting for completion.
                chosen = FindArena(layouts, viewIndices, pendingViews, out chosenPages, out chosenSlots, out chosenOffsets);
                if (chosen != null && !Trim(budgetBytes, chosen))
                {
                    if (pendingViews == null || !omitPendingPages)
                    {
                        reason = arenaBudgetExceeded;
                        return false;
                    }
                    chosen = null;
                }
                if (chosen == null && pendingViews != null)
                {
                    if (!omitPendingPages)
                    {
                        reason = "Matching source upload/readback is pending; no duplicate large allocation.";
                        return false;
                    }
                    // Material records keep their original request slots. A specified map with a
                    // zero-generation handle evaluates as unknown, including alpha coverage.
                    var remap = new int[views.Count];
                    int kept = 0;
                    viewIndices.Clear();
                    capacity = 0;
                    largest = 0;
                    for (int i = 0; i < remap.Length; i++)
                    {
                        if (pendingViews[i])
                        {
                            // The active turn can change before recording, so capture each omitted turn's order.
                            if (Sources.TryGetValue(views[i].Texture, out var source) && source.SharedTurn is UploadTurn turn &&
                                HasUploadDemand(turn))
                                (deferredWaitOrders ??= new List<ulong>()).Add(turn.Order);
                            remap[i] = -1;
                            continue;
                        }
                        var layout = layouts[i];
                        remap[i] = kept;
                        viewIndices.Add(views[i], kept);
                        views[kept] = views[i];
                        layouts[kept] = layout;
                        kept++;
                        capacity += layout.StorageElementCount;
                        largest = Math.Max(largest, layout.StorageElementCount);
                    }
                    views.RemoveRange(kept, views.Count - kept);
                    layouts.RemoveRange(kept, layouts.Count - kept);
                    for (int i = 0; i < indices.Length; i++)
                        if (indices[i] >= 0) indices[i] = remap[indices[i]];
                    shareable = kept > 0;
                    if (shareable)
                        chosen = FindArena(layouts, viewIndices, null, out chosenPages, out chosenSlots, out chosenOffsets);
                    if (chosen != null && !Trim(budgetBytes, chosen))
                    {
                        reason = arenaBudgetExceeded;
                        return false;
                    }
                }
            }
            bool fresh=chosen==null;
            if(fresh)
            {
                int metadataCount=Math.Max(1,views.Count);capacity=Math.Max(1,capacity);
                long minimum=capacity*16+(long)metadataCount*64;
                if(lastGeneration==uint.MaxValue)
                {reason="Arena generation space exhausted.";return false;}
                // Retained reusable pages can fill the physical arena limit well before the byte budget.
                if(minimum>budgetBytes||!Trim(budgetBytes-minimum,arenaLimit:MaxResidentBatches-1))
                {reason="Global texture arena count or byte budget reached.";return false;}
                // Reserve one largest-page replacement, within this same global budget.
                // Reserved space is real allocated capacity, never excluded from accounting.
                if(shareable)
                {
                    long spare=budgetBytes-TotalAllocatedBytes-minimum;
                    int extraSlots=(int)Math.Min(Math.Min(MaxRequests-metadataCount,views.Count+8),spare/64);
                    metadataCount+=extraSlots;spare-=extraSlots*64;
                    capacity+=Math.Min(largest,Math.Min(int.MaxValue-capacity,spare/16));
                }
                chosen=new Allocation(++lastGeneration,(int)capacity,metadataCount,shareable);
                Allocations.Add(chosen);TotalAllocatedBytes+=chosen.Bytes;
                try
                {
                    chosen.Texels=new GraphicsBuffer(GraphicsBuffer.Target.Structured,(int)capacity,16);
                    chosen.Metadata=new GraphicsBuffer(GraphicsBuffer.Target.Structured,metadataCount,64);
                }
                catch(Exception ex){TryFree(chosen);reason="GPU allocation failed: "+ex.GetType().Name;return false;}
                if(!Plan(chosen,layouts,viewIndices,out chosenPages,out chosenSlots,out chosenOffsets,null))
                {TryFree(chosen);reason="Arena layout planning failed.";return false;}
            }
            uint generation=chosen.Generation;bool hasNew=false;foreach(var page in chosenPages)hasNew|=page==null;
            if(!fresh&&hasNew)
            {
                if(lastGeneration==uint.MaxValue){reason="Page generation space exhausted.";return false;}
                generation=++lastGeneration;
            }
            var uploads=new List<Page>();
            for(int i=0;i<views.Count;i++)if(chosenPages[i]==null)
            {
                var view=views[i];var layout=layouts[i];int slot=chosenSlots[i],offset=chosenOffsets[i];
                layout.TryMakeMetadata(offset,chosen.Capacity,generation,view.FilterMode,view.WrapModeU,view.WrapModeV,view.MipMapBias,view.AnisoLevel,out var initial);
                var page=new Page(new Upload(view,layout,slot,offset,generation),initial,Epoch(view.Texture),Reusable(view));
                chosen.Pages[slot]=page;chosenPages[i]=page;uploads.Add(page);
            }
            else if(!chosenPages[i].Ready)uploads.Add(chosenPages[i]);
            lease=Borrow(chosen,chosenPages,uploads.ToArray(),indices,!fresh,deferredWaitOrders);return true;
        }

        private static int FindLaterDemand(UploadTurn turn)
        {
            for (int i = 0; i < laterUploadWaiters.Count; i++)
                if (ReferenceEquals(laterUploadWaiters[i].Turn, turn)) return i;
            return -1;
        }

        private static bool HasUploadDemand(UploadTurn turn) => ReferenceEquals(uploadWaiter.Turn, turn) ||
            ReferenceEquals(nextUploadWaiter.Turn, turn) || FindLaterDemand(turn) >= 0;

        private static void KeepLaterDemand(UploadDemand demand)
        {
            // Keep the oldest turn for each expected visit. Future turns do not reserve this frame.
            for (int i = 0; i < laterUploadWaiters.Count; i++)
            {
                if (laterUploadWaiters[i].ReservedFrame != demand.ReservedFrame) continue;
                if (demand.Turn.Order < laterUploadWaiters[i].Turn.Order) laterUploadWaiters[i] = demand;
                return;
            }
            laterUploadWaiters.Add(demand);
        }

        private static void RememberBlockedUpload(Page page, UploadTurn turn, long earlierBatchBytes, long interval)
        {
            int remaining = page.Upload.Layout.StorageElementCount - page.UploadedElements;
            if (remaining == 0) return;
            long initialBytes = page.MetadataInitialized ? 0 : MetadataStride;
            long minimum = initialBytes + (page.Reusable ? 1L : remaining) * HybridLumenGIRayTextureLayout.TexelStride;
            // This turn is for a source which would fit but for earlier batches, not for
            // an over-cap source or contention already handled by the within-batch order.
            if (minimum > uploadBudget || minimum <= uploadBudget - earlierBatchBytes) return;
            if (turn.Order == 0) turn.Order = ++lastUploadOrder;
            var demand = new UploadDemand { Turn = turn, Bytes = minimum, ReservedFrame = uploadFrame + interval };
            CancelUploadDemand(turn);
            if (interval > 1) KeepLaterDemand(demand);
            else if (nextUploadWaiter.Turn == null || turn.Order < nextUploadWaiter.Turn.Order)
                nextUploadWaiter = demand;
        }

        private static void CancelUploadDemand(UploadTurn turn)
        {
            if (ReferenceEquals(uploadWaiter.Turn, turn)) uploadWaiter = default;
            if (ReferenceEquals(nextUploadWaiter.Turn, turn)) nextUploadWaiter = default;
            int index = FindLaterDemand(turn);
            if (index >= 0) laterUploadWaiters.RemoveAt(index);
        }

        private static void KeepActiveUploadDemand(long interval)
        {
            int index = FindLaterDemand(uploadWaiter.Turn);
            if (index >= 0) laterUploadWaiters.RemoveAt(index);
            var demand = uploadWaiter;
            demand.ReservedFrame = uploadFrame + interval;
            if (interval > 1)
            {
                uploadWaiter.ReservedFrame = uploadFrame;
                KeepLaterDemand(demand);
            }
            else uploadWaiter = demand;
        }

        private static int AdmittedUploadElements(Page page, UploadTurn turn)
        {
            long initialBytes = page.MetadataInitialized ? 0 : MetadataStride;
            long availableBytes = uploadBudget - uploadUsed;
            if (uploadWaiter.Turn != null && uploadWaiter.Bytes <= uploadBudget && !ReferenceEquals(turn, uploadWaiter.Turn))
                availableBytes -= uploadWaiter.Bytes;
            if (availableBytes <= initialBytes) return 0;
            long availableElements = (availableBytes - initialBytes) / HybridLumenGIRayTextureLayout.TexelStride;
            int remaining = page.Upload.Layout.StorageElementCount - page.UploadedElements;
            // Unversioned sources require a complete current capture in a single frame.
            if (!page.Reusable && availableElements < remaining) return 0;
            return (int)Math.Min(remaining, availableElements);
        }

        private static int FirstUploadIndex(Page[] uploads, object uploadConsumer)
        {
            int first = 0;
            ulong oldest = ulong.MaxValue;
            for (int index = 0; index < uploads.Length; index++)
            {
                var page = uploads[index];
                var turn = GetUploadTurn(page, uploadConsumer);
                if (AdmittedUploadElements(page, turn) == 0) continue;
                if (turn.Order == 0) turn.Order = ++lastUploadOrder;
                if (turn.Order >= oldest) continue;
                oldest = turn.Order;
                first = index;
            }
            return first;
        }

        public bool RecordUploads(CommandBuffer cmd,Lease lease,Action<CommandBuffer,Upload,GraphicsBuffer,GraphicsBuffer> importer,out string reason)
            => RecordUploads(cmd, lease, importer == null ? null : (command, upload, metadata, texels) =>
            {
                importer(command, upload, metadata, texels);
                return true;
            }, null, out reason);

        internal bool RecordUploads(CommandBuffer cmd,Lease lease,Func<CommandBuffer,Upload,GraphicsBuffer,GraphicsBuffer,bool> importer,
            object uploadConsumer,out string reason,float recordingBudgetMilliseconds=0f)
        {
            reason=null;
            if(disposed||cmd==null||importer==null||!Owns(lease)||lease.State!=LeaseState.Prepared)
            {reason="Invalid or already recorded upload lease.";return false;}
            foreach(var page in lease.Pages)if(page.Epoch!=Epoch(page.Upload.View.Texture)||
                (Array.IndexOf(lease.Uploads,page)<0&&(!page.Ready||!page.Reusable||!Current(page))))
            {page.Reusable=false;reason="Reusable texture observation invalidated before consumption.";return false;}
            lease.State=LeaseState.Recording;var arena=lease.allocation;
            try
            {
                if(uploadFrame>=0)
                {
                    long interval = ObserveUploadConsumer(uploadConsumer);
                    long earlierBatchBytes = uploadUsed;
                    var uploads = lease.Uploads;
                    int first = FirstUploadIndex(uploads, uploadConsumer);
                    double recordingBudgetTicks = recordingBudgetMilliseconds > 0f && !float.IsInfinity(recordingBudgetMilliseconds)
                        ? recordingBudgetMilliseconds * (Stopwatch.Frequency / 1000d) : 0d;
                    long? firstRecording = null;
                    for (int index = 0; index < uploads.Length; index++)
                    {
                        var page = uploads[(first + index) % uploads.Length];
                        var turn = GetUploadTurn(page, uploadConsumer);
                        int count = AdmittedUploadElements(page, turn);
                        if (count == 0)
                        {
                            if (earlierBatchBytes > 0) RememberBlockedUpload(page, turn, earlierBatchBytes, interval);
                            continue;
                        }
                        if (recordingBudgetTicks > 0)
                        {
                            long now = Stopwatch.GetTimestamp();
                            if (firstRecording.HasValue && now - firstRecording.Value >= recordingBudgetTicks)
                            {
                                // A time deferral keeps the existing byte reservation and order.
                                if (ReferenceEquals(uploadWaiter.Turn, turn)) KeepActiveUploadDemand(interval);
                                continue;
                            }
                            firstRecording ??= now;
                        }
                        long initialBytes = page.MetadataInitialized ? 0 : MetadataStride;
                        // A recording attempt may partially succeed. Charge it and move the turn to the back.
                        uploadUsed += initialBytes + (long)count * HybridLumenGIRayTextureLayout.TexelStride;
                        CancelUploadDemand(turn);
                        turn.Order = ++lastUploadOrder;
                        if(!page.MetadataInitialized)
                        {cmd.SetBufferData(arena.Metadata,new[]{page.Initial},0,page.Upload.MetadataIndex,1);page.MetadataInitialized=true;arena.Initialized=true;}
                        if(!importer(cmd,new Upload(page.Upload,page.UploadedElements,count),arena.Metadata,arena.Texels))
                            page.UploadRejected=true;
                        if(disposed||lease.State!=LeaseState.Recording)throw new InvalidOperationException("Progressive upload canceled during recording.");
                        page.UploadedElements+=count;page.UploadComplete=page.UploadedElements==page.Upload.Layout.StorageElementCount;
                    }
                    if (uploadWaiter.Turn != null && lease.DeferredWaitOrders != null &&
                        lease.DeferredWaitOrders.Contains(uploadWaiter.Turn.Order))
                        KeepActiveUploadDemand(interval);
                    lease.State=LeaseState.Recorded;return true;
                }
                if(!arena.Initialized)
                {
                    var initial=new HybridLumenGIRayTextureMetadata[arena.Pages.Length];
                    foreach(var page in lease.Uploads)initial[page.Upload.MetadataIndex]=page.Initial;
                    cmd.SetBufferData(arena.Metadata,initial);arena.Initialized=true;
                }
                else foreach(var page in lease.Uploads)
                    cmd.SetBufferData(arena.Metadata,new[]{page.Initial},0,page.Upload.MetadataIndex,1);
                foreach(var page in lease.Uploads)
                {
                    page.MetadataInitialized=true;
                    if(!importer(cmd,page.Upload,arena.Metadata,arena.Texels))page.UploadRejected=true;
                    if(disposed||lease.State!=LeaseState.Recording)throw new InvalidOperationException("Upload canceled during recording.");
                    page.UploadedElements=page.Upload.Layout.StorageElementCount;page.UploadComplete=true;
                }
                lease.State=LeaseState.Recorded;return true;
            }
            catch(Exception ex){Quarantine(lease);reason="Upload recording unproven: "+ex.GetType().Name;return false;}
        }
        public bool IsHandleCurrent(Lease lease,Handle handle)
            => IsHandleCurrent(lease,handle,out _);

        internal bool IsHandleCurrent(Lease lease,Handle handle,out bool uploadRecorded)
        {
            uploadRecorded=false;
            if(!Owns(lease)||disposed||lease.State!=LeaseState.Recorded||!handle.IsValid)return false;
            var page = lease.GetBorrowedPage(handle.Index);
            if (page == null || !page.MetadataInitialized || page.Upload.Generation != handle.Generation) return false;
            // The copy commands precede consumers. The shader still decides whether the data is valid.
            uploadRecorded=page.UploadComplete&&!page.UploadRejected;
            return true;
        }
        /// <summary>Borrow for RenderGraph declarations only, not disposal/consumption authority.</summary>
        public bool GetResources(Lease lease,out GraphicsBuffer metadata,out GraphicsBuffer texels)
        {
            metadata=texels=null;if(disposed||!Owns(lease)||(lease.State!=LeaseState.Prepared&&lease.State!=LeaseState.Recorded))return false;
            metadata=lease.allocation.Metadata;texels=lease.allocation.Texels;return true;
        }
        public bool Bind(CommandBuffer cmd,ComputeShader shader,int kernel,Lease lease,out string reason)
        {
            reason=null;if(disposed||cmd==null||shader==null||kernel<0||!Owns(lease)||lease.State!=LeaseState.Recorded)
            {reason="Texture lease is not recordable for consumption.";return false;}
            try
            {
                foreach(var page in lease.Pages)if(page.Epoch!=Epoch(page.Upload.View.Texture)||
                    (Array.IndexOf(lease.Uploads,page)<0&&(!page.Reusable||!Current(page))))
                    throw new InvalidOperationException("Source changed before reused binding.");
                cmd.SetComputeBufferParam(shader,kernel,MetadataId,lease.allocation.Metadata);
                cmd.SetComputeBufferParam(shader,kernel,TexelsId,lease.allocation.Texels);return true;
            }
            catch(Exception ex){Quarantine(lease);reason="Consumer binding unproven: "+ex.GetType().Name;return false;}
        }
        /// <summary>Fence follows every consumer after required producer/queue waits; no age inference.</summary>
        public bool MarkSubmitted(Lease lease,GraphicsFence lastConsumerFence,out string reason)
        {
            reason=null;if(!Owns(lease)||(lease.State!=LeaseState.Recorded&&lease.State!=LeaseState.Quarantined))
            {reason="Lease cannot accept submission evidence.";return false;}
            if(!SystemInfo.supportsGraphicsFence){Quarantine(lease);reason="Graphics fence support unavailable.";return false;}
            try{bool observed=lastConsumerFence.passed;}
            catch(Exception ex){Quarantine(lease);reason="Consumer fence invalid: "+ex.GetType().Name;return false;}
            lease.Fence=lastConsumerFence;lease.State=LeaseState.Submitted;return true;
        }
        public void Quarantine(Lease lease)
        {
            if(Owns(lease)&&lease.State!=LeaseState.Prepared&&lease.State!=LeaseState.ReleasePending)
            {lease.State=LeaseState.Quarantined;foreach(var page in lease.Pages)page.Reusable=false;}
        }
        public bool ReleaseUnrecorded(Lease lease)
        {
            if(!Owns(lease)||lease.State!=LeaseState.Prepared)return false;
            foreach(var page in lease.Uploads)if(!page.MetadataInitialized)page.Reusable=false;
            lease.State=LeaseState.ReleasePending;return TryReleaseLease(lease);
        }
        private static void BeginReadback(Lease lease)
        {
            var pending=new List<Page>();
            foreach(var page in lease.Uploads)if(page.UploadComplete&&!page.ReadbackStarted&&page.Reusable)
            {
                if(!SystemInfo.supportsAsyncGPUReadback){page.Reusable=false;continue;}
                page.ReadbackStarted=page.ReadbackPending=true;pending.Add(page);
            }
            if(pending.Count==0)return;var arena=lease.allocation;
            try
            {
                AsyncGPUReadback.Request(arena.Metadata,request=>
                {
                    foreach(var page in pending)
                    {
                        bool valid=false;
                        try
                        {
                            if(!request.hasError&&page.Reusable&&Current(page))
                            {var data=request.GetData<HybridLumenGIRayTextureMetadata>();valid=data.Length==arena.Pages.Length&&Published(data[page.Upload.MetadataIndex],page.Upload,arena.Capacity);}
                        }
                        catch{valid=false;}
                        page.Ready=valid;page.Reusable&=valid;page.ReadbackPending=false;
                    }
                });
            }
            catch{foreach(var page in pending)page.Reusable=false;} // Only a callback retires an ambiguous queued readback.
        }
        private static bool Published(HybridLumenGIRayTextureMetadata value,Upload upload,int capacity)
        {
            if(value.flags!=1||value.generation!=upload.Generation||value.offset!=(uint)upload.TexelOffset||
                value.width!=(uint)upload.Layout.Width||value.height!=(uint)upload.Layout.Height||value.mipCount!=(uint)upload.Layout.MipCount||
                value.firstMip>=value.mipCount||value.reserved0!=0||value.reserved1!=0||value.reserved2!=0||value.reserved3!=0||value.reserved4!=0)return false;
            if(!HybridLumenGIRayTextureLayout.TryCreate((int)value.width,(int)value.height,(int)value.mipCount,(int)value.firstMip,out var stored,upload.Layout.PackedHalf)||
                value.texelCount!=(uint)stored.TexelCount||!stored.Fits((int)value.offset,capacity))return false;
            var view=upload.View;
            return HybridLumenGIRayTextureLayout.TryPackSampler(view.FilterMode,view.WrapModeU,view.WrapModeV,out uint sampler)&&
                value.sampler==(sampler|(upload.Layout.PackedHalf?HybridLumenGIRayTextureLayout.HalfPairsBit:0))&&
                BitConverter.SingleToInt32Bits(value.lodBias)==BitConverter.SingleToInt32Bits(view.MipMapBias)&&value.anisoLevel==view.AnisoLevel;
        }
        public static void PollRetired()
        {
            for(int i=Resident.Count-1;i>=0;i--)
            {
                var lease=Resident[i];
                if(lease.State==LeaseState.Submitted)
                {
                    try
                    {
                        if(!SystemInfo.supportsGraphicsFence)lease.Owner.Quarantine(lease);
                        else if(lease.Fence.passed){lease.allocation.Established=true;BeginReadback(lease);lease.State=LeaseState.ReleasePending;}
                    }
                    catch{lease.Owner.Quarantine(lease);}
                }
                if(lease.State==LeaseState.ReleasePending)TryReleaseLease(lease);
            }
            for(int i=Allocations.Count-1;i>=0;i--)
            {
                var arena=Allocations[i];bool live=false;
                for(int j=0;j<arena.Pages.Length;j++)
                {
                    var page=arena.Pages[j];if(page==null)continue;
                    if(page.Reusable&&!Current(page))page.Reusable=false;
                    if(page.Readers==0&&!page.ReadbackPending&&!page.Reusable)arena.Pages[j]=null;else live=true;
                }
                if(!live&&arena.Readers==0)TryFree(arena);
            }
        }
        private bool Owns(Lease lease)=>lease!=null&&ReferenceEquals(lease.Owner,this)&&lease.State!=LeaseState.Released;
        private static bool TryReleaseLease(Lease lease)
        {
            var arena=lease.allocation;bool retained=false;
            foreach(var page in arena.Pages)if(page!=null&&(page.Reusable||page.ReadbackPending))retained=true;
            if(arena.Readers==1&&!retained&&!TryFree(arena))return false;
            arena.Readers--;foreach(var page in lease.Pages)page.Readers--;
            lease.State=LeaseState.Released;Resident.Remove(lease);lease.Owner.leases.Remove(lease);lease.Owner.AllocatedBytes-=arena.Bytes;return true;
        }
        private static bool TryFree(Allocation arena)
        {
            foreach(var page in arena.Pages)if(page!=null&&page.ReadbackPending)return false;
            // Native Dispose may partially succeed. Such an arena must never be borrowed again.
            arena.Retiring=true;
            try
            {
                if(arena.Texels!=null){arena.Texels.Dispose();arena.Texels=null;}
                if(arena.Metadata!=null){arena.Metadata.Dispose();arena.Metadata=null;}
            }
            catch{return false;}
            Allocations.Remove(arena);TotalAllocatedBytes-=arena.Bytes;return true;
        }
        public void Dispose()
        {
            if(disposed)return;disposed=true;
            foreach(var lease in leases)
            {
                if(lease.State==LeaseState.Prepared){foreach(var page in lease.Uploads)if(!page.MetadataInitialized)page.Reusable=false;lease.State=LeaseState.ReleasePending;}
                else if(lease.State==LeaseState.Recording||lease.State==LeaseState.Recorded)Quarantine(lease);
            }
            PollRetired();
        }
    }
}
