using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Rendering;

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
        private sealed class SourceEpoch { internal ulong Value; }
        private static readonly ConditionalWeakTable<Texture,SourceEpoch> SourceEpochs=new ConditionalWeakTable<Texture,SourceEpoch>();
        private static uint lastGeneration;
        private static ulong lastSourceEpoch;
        private static int uploadFrame=-1;
        private static long uploadBudget=long.MaxValue,uploadUsed;
        public static int UploadFrame=>uploadFrame;
        public static long UploadBytesUsed=>uploadUsed;
        public static long UploadBudgetBytes=>uploadBudget;
        /// <summary>Call on the main thread for every camera. Same-frame calls never replenish the global allowance.</summary>
        public static void BeginFrame(int engineFrame,long maxUploadBytes)
        {
            if(engineFrame<0||engineFrame<uploadFrame||maxUploadBytes<80)throw new ArgumentOutOfRangeException(nameof(maxUploadBytes));
            if(engineFrame>uploadFrame){uploadFrame=engineFrame;uploadUsed=0;uploadBudget=maxUploadBytes;}
            else uploadBudget=Math.Min(uploadBudget,maxUploadBytes);
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
            internal bool MetadataInitialized,UploadComplete;
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
            internal Lease(HybridLumenGIRayTexturePool owner,Allocation allocation,Page[] pages,Page[] uploads,Handle[] handles,bool reused)
            {
                Owner=owner;this.allocation=allocation;Pages=pages;Uploads=uploads;Handles=handles;IsReused=reused;State=LeaseState.Prepared;
                foreach(var page in uploads)UploadByteCount+=page.Upload.Layout.ByteCount+64;
            }
        }
        private static ulong Epoch(Texture texture)=>SourceEpochs.TryGetValue(texture,out var epoch)?epoch.Value:0;
        public static void InvalidateSource(Texture texture)
        {
            if(ReferenceEquals(texture,null))return;
            if(lastSourceEpoch==ulong.MaxValue)throw new InvalidOperationException("Source epochs exhausted; cannot wrap.");
            SourceEpochs.GetValue(texture,_=>new SourceEpoch()).Value=++lastSourceEpoch;
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
        private static bool Trim(long budget,Allocation keep=null)
        {
            for(int i=0;i<Allocations.Count&&TotalAllocatedBytes>budget;)
            {
                var allocation=Allocations[i];bool pending=false;
                foreach(var page in allocation.Pages)pending|=page!=null&&page.ReadbackPending;
                if(!ReferenceEquals(keep,allocation)&&allocation.Readers==0&&!pending&&TryFree(allocation))continue;
                i++;
            }
            return TotalAllocatedBytes<=budget;
        }
        // Best-fit holes are derived from live pages. Old-reader and readback pages stay occupied.
        private static bool Plan(Allocation arena,List<HybridLumenGIFrozenTextureView> views,List<HybridLumenGIRayTextureLayout> layouts,
            out Page[] pages,out int[] slots,out int[] offsets)
        {
            pages=new Page[views.Count];slots=new int[views.Count];offsets=new int[views.Count];
            var occupied=new List<(int Start,int End)>();var used=new bool[arena.Pages.Length];
            for(int i=0;i<arena.Pages.Length;i++)if(arena.Pages[i]!=null)
            {var p=arena.Pages[i];used[i]=true;occupied.Add((p.Upload.TexelOffset,p.Upload.TexelOffset+p.Upload.Layout.StorageElementCount));}
            for(int i=0;i<views.Count;i++)
            {
                slots[i]=-1;
                if(Reusable(views[i]))foreach(var page in arena.Pages)
                {
                    if(page==null||!page.Reusable||(!page.Ready&&(page.UploadComplete||page.Readers!=0||page.ReadbackPending))||page.Epoch!=Epoch(views[i].Texture)||!page.Upload.View.Equals(views[i])||
                        (!layouts[i].PackedHalf&&page.Upload.Layout.PackedHalf))continue;
                    pages[i]=page;break;
                }
                if(pages[i]!=null)continue;
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
        private Lease Borrow(Allocation arena,Page[] pages,Page[] uploads,int[] indices,bool reused)
        {
            var handles=new Handle[indices.Length];
            for(int i=0;i<indices.Length;i++)if(indices[i]>=0)
            {var p=pages[indices[i]];handles[i]=new Handle((uint)p.Upload.MetadataIndex,p.Upload.Generation);}
            var lease=new Lease(this,arena,pages,uploads,handles,reused);arena.Readers++;
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
                    int existing=views.FindIndex(value=>value.Equals(view));
                    if(existing>=0)
                    {
                        indices[i]=existing;
                        if(layouts[existing].PackedHalf&&!layout.PackedHalf)
                        {capacity+=layout.StorageElementCount-layouts[existing].StorageElementCount;layouts[existing]=layout;largest=Math.Max(largest,layout.StorageElementCount);}
                        if(capacity>int.MaxValue){reason="Combined texture capacity exceeds int range.";return false;}
                        continue;
                    }
                    indices[i]=views.Count;views.Add(view);layouts.Add(layout);capacity+=layout.StorageElementCount;largest=Math.Max(largest,layout.StorageElementCount);
                    if(capacity>int.MaxValue){reason="Combined texture capacity exceeds int range.";return false;}
                }
            }
            catch(Exception ex){reason="Frozen request enumeration failed: "+ex.GetType().Name;return false;}
            shareable &= views.Count>0;
            Allocation chosen=null;Page[] chosenPages=null;int[] chosenSlots=null,chosenOffsets=null;int bestReused=-1;
            if(shareable)
            {
                // Do not borrow a pending page or start a duplicate upload, even in another arena.
                int[] remap = null;
                foreach (var arena in Allocations)
                foreach (var page in arena.Pages)
                {
                    if (page == null || !page.Reusable || page.Ready || page.Epoch != Epoch(page.Upload.View.Texture)) continue;
                    if (arena.Established && !page.UploadComplete && page.Readers == 0 && !page.ReadbackPending) continue;
                    int index = views.IndexOf(page.Upload.View);
                    if (index < 0 || (!layouts[index].PackedHalf && page.Upload.Layout.PackedHalf)) continue;
                    if (!omitPendingPages)
                    {
                        reason = "Matching source upload/readback is pending; no duplicate large allocation.";
                        return false;
                    }
                    remap ??= new int[views.Count];
                    remap[index] = -1;
                }
                if (remap != null)
                {
                    // Material records keep their original request slots. A specified map with a
                    // zero-generation handle evaluates as unknown, including alpha coverage.
                    int kept = 0;
                    capacity = 0;
                    largest = 0;
                    for (int i = 0; i < remap.Length; i++)
                    {
                        if (remap[i] < 0) continue;
                        var layout = layouts[i];
                        remap[i] = kept;
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
                }
                foreach(var arena in Allocations)
                {
                    if(!shareable||!arena.Shareable||!arena.Established||arena.Retiring)continue;
                    if(!Plan(arena,views,layouts,out var pages,out var slots,out var offsets))continue;
                    int reused=0;foreach(var page in pages)if(page!=null)reused++;
                    if(reused>bestReused){chosen=arena;chosenPages=pages;chosenSlots=slots;chosenOffsets=offsets;bestReused=reused;}
                }
                if(chosen!=null&&!Trim(budgetBytes,chosen))
                {reason="Global budget includes all resident and pending texture arenas.";return false;}
            }
            bool fresh=chosen==null;
            if(fresh)
            {
                int metadataCount=Math.Max(1,views.Count);capacity=Math.Max(1,capacity);
                long minimum=capacity*16+(long)metadataCount*64;
                if(minimum>budgetBytes||!Trim(budgetBytes-minimum))
                {reason="Global texture budget includes active, idle, readback and quarantined arenas.";return false;}
                if(Allocations.Count>=MaxResidentBatches||lastGeneration==uint.MaxValue)
                {reason="Arena capacity or generation space exhausted.";return false;}
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
                if(!Plan(chosen,views,layouts,out chosenPages,out chosenSlots,out chosenOffsets))
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
            lease=Borrow(chosen,chosenPages,uploads.ToArray(),indices,!fresh);return true;
        }
        public bool RecordUploads(CommandBuffer cmd,Lease lease,Action<CommandBuffer,Upload,GraphicsBuffer,GraphicsBuffer> importer,out string reason)
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
                    foreach(var page in lease.Uploads)
                    {
                        long available=Math.Max(0,uploadBudget-uploadUsed),initial=page.MetadataInitialized?0:64;
                        long remaining=page.Upload.Layout.StorageElementCount-page.UploadedElements;
                        // Unversioned dynamic sources may not be stitched across frames.
                        // They remain unknown unless this entire current capture fits.
                        if(!page.Reusable&&available<initial+remaining*16)continue;
                        int count=(int)Math.Min(remaining,Math.Max(0,(available-initial)/16));
                        if(count<=0)continue;
                        uploadUsed+=initial+(long)count*16; // recording may partially succeed; never refund ambiguous commands.
                        if(!page.MetadataInitialized)
                        {cmd.SetBufferData(arena.Metadata,new[]{page.Initial},0,page.Upload.MetadataIndex,1);page.MetadataInitialized=true;arena.Initialized=true;}
                        importer(cmd,new Upload(page.Upload,page.UploadedElements,count),arena.Metadata,arena.Texels);
                        if(disposed||lease.State!=LeaseState.Recording)throw new InvalidOperationException("Progressive upload canceled during recording.");
                        page.UploadedElements+=count;page.UploadComplete=page.UploadedElements==page.Upload.Layout.StorageElementCount;
                    }
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
                    importer(cmd,page.Upload,arena.Metadata,arena.Texels);
                    if(disposed||lease.State!=LeaseState.Recording)throw new InvalidOperationException("Upload canceled during recording.");
                    page.UploadedElements=page.Upload.Layout.StorageElementCount;page.UploadComplete=true;
                }
                lease.State=LeaseState.Recorded;return true;
            }
            catch(Exception ex){Quarantine(lease);reason="Upload recording unproven: "+ex.GetType().Name;return false;}
        }
        public bool IsHandleCurrent(Lease lease,Handle handle)
        {
            if(!Owns(lease)||disposed||lease.State!=LeaseState.Recorded||!handle.IsValid)return false;
            foreach(var page in lease.Pages)if(page.MetadataInitialized&&page.Upload.MetadataIndex==handle.Index&&page.Upload.Generation==handle.Generation)return true;
            return false;
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
