using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace HybridLumenGI
{
    /// <summary>Validates initialization on GPU before issuing a staging representation's readiness ticket.</summary>
    public sealed class HybridLumenGIHlodReadback : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct CacheEntry { public Vector4 irradiance,tag,anchor,normal,guide,nonAnalyticIrradiance; }
        [Serializable]
        public struct CoverageBlock
        {
            public bool observed, requiresEachChart;
            public int sourceWorkFrame, ownerId, ownerRevision, cardOrdinal, physicalCard, patch;
            public string ownerName, reason;
        }
        /// <summary>First coverage blocker in the most recent usable callback, at its recorded work frame.</summary>
        public CoverageBlock LastCoverageBlock { get; private set; }
        private sealed class Snapshot
        {
            internal int slot,id,revision;
            internal int[] cards;
            internal uint[] generations;
            internal uint layout;
            internal bool requireEachCard;
            internal HybridLumenGIMeshSdf sdfAsset;
            internal Texture3D sdfTexture;
            internal Mesh sdfMesh;
            internal uint sdfTextureVersion;
            internal Bounds sdfBounds;
            internal Matrix4x4 sdfTransform;
            internal int sdfResolution;
            internal bool sdfWatertight;
            internal float sdfError;
        }
        private bool pending,disposed;
        private int invalidationSerial,lastRequestFrame=-1000,currentEpoch,currentGrid;
        public bool Pending => pending;
        public int CompletedReadbacks { get; private set; }
        public int FailedReadbacks { get; private set; }
        public int AcceptedTickets { get; private set; }
        public void Invalidate() { invalidationSerial++; LastCoverageBlock=default; }

        public void Record(CommandBuffer command,HybridLumenGIScene scene,HybridLumenGISdfAtlas sdf,
            HybridLumenGISurfaceCache surface,ComputeBuffer cache,int grid,int epoch,int frame,int requiredSamples=2)
            => Record(command,scene,sdf,surface,cache,grid,epoch,frame,null,requiredSamples);

        internal void Record(CommandBuffer command,HybridLumenGIScene scene,HybridLumenGISdfAtlas sdf,
            HybridLumenGISurfaceCache surface,ComputeBuffer cache,int grid,int epoch,int frame,
            HybridLumenGICacheScheduler scheduler,int requiredSamples=2)
        {
            if(scene==null || sdf==null || surface==null || cache==null || command==null) throw new ArgumentNullException();
            if(grid<1 || grid>4) throw new ArgumentOutOfRangeException(nameof(grid));
            if(currentEpoch!=epoch || currentGrid!=grid || scene.WarmingCount==0 || !SystemInfo.supportsAsyncGPUReadback)
                LastCoverageBlock=default;
            currentEpoch=epoch;currentGrid=grid;
            if(disposed || pending || scene.WarmingCount==0 || frame-lastRequestFrame<4 || !SystemInfo.supportsAsyncGPUReadback) return;
            var snapshots=new List<Snapshot>();
            for(int slot=0;slot<scene.Capacity;slot++)
            {
                if(!scene.IsWarming(slot)) continue;
                var identity=scene.Data[slot].identity;int id=(int)identity.x,revision=(int)identity.y;
                bool geometryReady=GeometryReady(scene,sdf,slot,id,revision);
                bool materialReady=surface.IsSlotReady(slot,id,revision) && surface.IsSlotSourceCurrent(slot,id,revision);
                if(!geometryReady || !materialReady)
                {
                    scene.ReportReadiness(id,revision,geometryReady,materialReady,false);continue;
                }
                int count=surface.GetCardCount(slot);
                uint layout=surface.GetLayoutGeneration(slot);
                if(count<=0 || count>surface.CardCount || layout==0)
                { scene.ReportReadiness(id,revision,geometryReady,false,false);continue; }
                var snapshot=new Snapshot{slot=slot,id=id,revision=revision,layout=layout,
                    cards=new int[count],generations=new uint[count],requireEachCard=surface.RequiresCardCoverage(slot)};
                CaptureGeometrySource(snapshot,scene.GetProxy(slot));
                var seen=new HashSet<int>();bool valid=true;
                for(int ordinal=0;ordinal<count;ordinal++)
                {
                    int card=surface.GetCardIndex(slot,ordinal);
                    if(!ValidCardOwner(surface,card,slot) || !seen.Add(card)) { valid=false;break; }
                    uint generation=surface.GetGeneration(card);
                    if(generation==0) { valid=false;break; }
                    snapshot.cards[ordinal]=card;snapshot.generations[ordinal]=generation;
                }
                if(!valid) { scene.ReportReadiness(id,revision,geometryReady,false,false);continue; }
                snapshots.Add(snapshot);
            }
            if(snapshots.Count==0) { LastCoverageBlock=default;return; }
            int firstCard=surface.CardCount,lastCard=-1;
            foreach(Snapshot snapshot in snapshots)
            foreach(int card in snapshot.cards)
            {
                firstCard=Math.Min(firstCard,card);
                lastCard=Math.Max(lastCard,card);
            }
            uint atlasGeneration=surface.AtlasGeneration;int serial=invalidationSerial;
            int perCard=grid*grid;
            pending=true;lastRequestFrame=frame;
            // Command order places the copy after CSUpdateCache. The callback sees completed GPU
            // data, unlike a CPU mask that merely says a dispatch has been scheduled.
            try
            {
            int entryCount=checked((lastCard-firstCard+1)*perCard);
            int byteOffset=checked(firstCard*perCard*cache.stride);
            int byteCount=checked(entryCount*cache.stride);
            command.RequestAsyncReadback(cache,byteCount,byteOffset,request=>
            {
                pending=false;
                LastCoverageBlock=default;
                // Cache buffers normally alternate every frame. Their replacement/disposal must
                // invalidate this coordinator or advance the epoch; buffer identity is not a version.
                if(disposed || serial!=invalidationSerial || currentEpoch!=epoch || currentGrid!=grid ||
                    surface.AtlasGeneration!=atlasGeneration) return;
                if(request.hasError) { FailedReadbacks++;return; }
                CompletedReadbacks++;
                var data=request.GetData<CacheEntry>();
                bool completeRange = scheduler != null && data.Length == entryCount;
                foreach(Snapshot snapshot in snapshots)
                {
                    if(!CurrentSnapshot(scene,surface,snapshot)) continue;
                    bool ready=true,anyCovered=false;
                    string reason=null;
                    int blockedOrdinal=-1,blockedPatch=-1;
                    for(int ordinal=0;ordinal<snapshot.cards.Length;ordinal++)
                    {
                        int card=snapshot.cards[ordinal];bool cardCovered=false;
                        bool coverageEvidence = completeRange && scheduler.NeedsPatchCoverage(card, grid, snapshot.generations[ordinal], atlasGeneration);
                        if (!ready && !coverageEvidence) continue;
                        ushort emptyPatches = 0;
                        for(int local=0;local<perCard;local++)
                        {
                            long index=(long)(card-firstCard)*perCard+local;
                            if(index>=data.Length)
                            {
                                if (ready) { reason="Missing cache entry";blockedOrdinal=ordinal;blockedPatch=local; }
                                ready=false;coverageEvidence=false;break;
                            }
                            var entry = data[(int)index];
                            bool patchReady = ValidatePatch(entry,snapshot.id,snapshot.revision,epoch,snapshot.generations[ordinal],requiredSamples,out bool covered);
                            if (!patchReady && ready)
                            {
                                ready=false;blockedOrdinal=ordinal;blockedPatch=local;
                                reason=covered?"Covered patch below required sample age":"Invalid cache entry or tag mismatch";
                            }
                            cardCovered|=covered;
                            if (coverageEvidence && !covered)
                            {
                                // Require the explicit all-zero output, separate from the
                                // existing (looser) readiness treatment of empty cells.
                                coverageEvidence = patchReady && entry.anchor.Equals(Vector4.zero) &&
                                    entry.normal.Equals(Vector4.zero) && entry.guide.Equals(Vector4.zero) &&
                                    entry.nonAnalyticIrradiance.Equals(Vector4.zero);
                                if (coverageEvidence) emptyPatches |= (ushort)(1 << local);
                            }
                            if (!ready && !coverageEvidence) break;
                        }
                        // A current covered tag proves this card was evaluated. An
                        // entirely zero card alone cannot exclude any future work.
                        if (coverageEvidence && cardCovered) scheduler.RecordPatchCoverage(card, emptyPatches);
                        anyCovered|=cardCovered;
                        // Authored charts are required surface domains: every chart needs a real
                        // covered patch. Legacy six-view fallback only promises object-level coverage.
                        if(ready && snapshot.requireEachCard && !cardCovered)
                        { ready=false;reason="Required chart has no covered cache patch";blockedOrdinal=ordinal; }
                    }
                    bool geometryReady=GeometryReady(scene,sdf,snapshot.slot,snapshot.id,snapshot.revision) &&
                        SameGeometrySource(snapshot,scene.GetProxy(snapshot.slot));
                    // An entirely empty card set is not evidence of initialized lighting.
                    if(!scene.ReportReadiness(snapshot.id,snapshot.revision,geometryReady,true,ready&&anyCovered) || !geometryReady) continue;
                    if(ready && anyCovered) AcceptedTickets++;
                    else if(!LastCoverageBlock.observed)
                    {
                        LastCoverageBlock=new CoverageBlock
                        {
                            observed=true,sourceWorkFrame=frame,ownerId=snapshot.id,ownerRevision=snapshot.revision,
                            ownerName=scene.GetProxy(snapshot.slot).name,requiresEachChart=snapshot.requireEachCard,
                            cardOrdinal=blockedOrdinal,physicalCard=blockedOrdinal<0?-1:snapshot.cards[blockedOrdinal],
                            patch=blockedPatch,reason=reason??"Fallback owner has no covered cache patch"
                        };
                    }
                }
            });
            }
            catch(Exception) { pending=false;LastCoverageBlock=default;FailedReadbacks++; }
        }

        private static bool ValidCardOwner(HybridLumenGISurfaceCache surface,int card,int slot)
        {
            int[] owners=surface.CardOwners;
            return card>=0 && card<surface.CardCount && owners!=null && card<owners.Length && owners[card]==slot;
        }
        private static bool CurrentSnapshot(HybridLumenGIScene scene,HybridLumenGISurfaceCache surface,Snapshot snapshot)
        {
            if(!scene.IsWarming(snapshot.slot)) return false;
            Vector4 identity=scene.Data[snapshot.slot].identity;
            if((int)identity.x!=snapshot.id || (int)identity.y!=snapshot.revision ||
                !surface.IsSlotReady(snapshot.slot,snapshot.id,snapshot.revision) ||
                !surface.IsSlotSourceCurrent(snapshot.slot,snapshot.id,snapshot.revision) ||
                surface.GetLayoutGeneration(snapshot.slot)!=snapshot.layout ||
                surface.GetCardCount(snapshot.slot)!=snapshot.cards.Length ||
                surface.RequiresCardCoverage(snapshot.slot)!=snapshot.requireEachCard) return false;
            for(int ordinal=0;ordinal<snapshot.cards.Length;ordinal++)
            {
                int card=snapshot.cards[ordinal];
                if(surface.GetCardIndex(snapshot.slot,ordinal)!=card || !ValidCardOwner(surface,card,snapshot.slot) ||
                    surface.GetGeneration(card)!=snapshot.generations[ordinal]) return false;
            }
            return true;
        }
        private static bool GeometryReady(HybridLumenGIScene scene,HybridLumenGISdfAtlas sdf,int slot,int id,int revision)
        {
            var proxy=scene.GetProxy(slot);
            return proxy!=null && proxy.StableId==id && proxy.Revision==revision &&
                (proxy.MeshSdf==null || (sdf.IsReady(slot,id,revision) && sdf.IsSourceCurrent(slot,proxy,id,revision)));
        }
        private static void CaptureGeometrySource(Snapshot snapshot,HybridLumenGIProxy proxy)
        {
            var asset=proxy.MeshSdf;snapshot.sdfAsset=asset;
            if(asset==null) return;
            snapshot.sdfTexture=asset.DistanceTexture;snapshot.sdfTextureVersion=asset.DistanceTexture.updateCount;
            snapshot.sdfMesh=asset.SourceMesh;snapshot.sdfBounds=asset.LocalBounds;snapshot.sdfResolution=asset.Resolution;
            snapshot.sdfWatertight=asset.Watertight;snapshot.sdfError=asset.InterpolationError;snapshot.sdfTransform=proxy.SdfLocalToWorld;
        }
        private static bool SameGeometrySource(Snapshot snapshot,HybridLumenGIProxy proxy)
        {
            var asset=proxy.MeshSdf;
            if(!ReferenceEquals(asset,snapshot.sdfAsset)) return false;
            if(asset==null) return ReferenceEquals(asset,null); // Reject destroyed Unity assets too.
            var texture=asset.DistanceTexture;
            return texture!=null && ReferenceEquals(texture,snapshot.sdfTexture) && texture.updateCount==snapshot.sdfTextureVersion &&
                ReferenceEquals(asset.SourceMesh,snapshot.sdfMesh) && asset.LocalBounds.Equals(snapshot.sdfBounds) &&
                asset.Resolution==snapshot.sdfResolution && asset.Watertight==snapshot.sdfWatertight &&
                asset.InterpolationError==snapshot.sdfError && proxy.SdfLocalToWorld.Equals(snapshot.sdfTransform);
        }

        public static bool ValidatePatch(CacheEntry entry,int id,int revision,int epoch,uint cardGeneration,int requiredSamples,out bool covered)
        {
            covered=false;
            if(!Finite(entry.irradiance.x) || !Finite(entry.irradiance.y) || !Finite(entry.irradiance.z) || !Finite(entry.irradiance.w)) return false;
            if(!Finite(entry.nonAnalyticIrradiance.x) || !Finite(entry.nonAnalyticIrradiance.y) ||
                !Finite(entry.nonAnalyticIrradiance.z) || !Finite(entry.nonAnalyticIrradiance.w)) return false;
            if(entry.tag.Equals(Vector4.zero) && entry.irradiance.Equals(Vector4.zero)) return true; // Explicitly cleared uncovered cell.
            if(entry.tag.x!=id || entry.tag.y!=revision || entry.tag.z!=epoch || entry.tag.w!=cardGeneration) return false;
            covered=true;
            return entry.irradiance.w>=Mathf.Max(1,requiredSamples);
        }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        public void Dispose() { disposed=true;Invalidate(); }
    }
}
