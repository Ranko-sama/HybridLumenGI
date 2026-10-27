param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$source = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGISurfaceCache.cs") -Raw
$start = $source.IndexOf("        public uint GetGeneration(")
$end = $source.IndexOf("        public bool IsSlotSourceCurrent(", $start)
$sortStart = $source.IndexOf("        private int CompareResidency(")
$sortEnd = $source.IndexOf("        private int ComparePending(", $sortStart)
if ($start -lt 0 -or $end -le $start -or $sortStart -lt 0 -or $sortEnd -le $sortStart) { throw "Readiness/residency methods changed; update extraction." }
$methods = $source.Substring($start, $end - $start) + $source.Substring($sortStart, $sortEnd - $sortStart)
$harness = @'
using System;
using System.Collections.Generic;
public class SurfaceReadinessHarness
{
    public struct Vector4 { public float x,y,z,w; }
    public struct ProxyData { public Vector4 identity; }
    public struct FakeBounds { public float distance; public float SqrDistance(object unused) { return distance; } }
    public class FakeRenderer { public FakeBounds bounds; }
    public class FakeScene {
        public int Capacity; public ProxyData[] Data; public FakeRenderer[] renderers;
        public FakeRenderer GetRenderer(int slot) { return renderers[slot]; }
    }
    public class Owner { public uint stableId,revision,layoutGeneration; public int[] cardIndices; }
    public class Card { public int tile; }
    public struct CardMetadata { public uint stableId,revision,generation,ready,ownerSlot,layoutGeneration; }
    private FakeScene preparedScene;
    private Owner[] owners;
    private Card[] cards;
    private CardMetadata[] metadata;
    private bool[] ReadyMask;
    private int[] CardOwners;
    private object referencePosition = new object();
    private static FakeBounds CaptureBounds(FakeRenderer renderer) { return renderer.bounds; }
'@ + $methods + @'
    private static void Check(bool condition, string name) { if (!condition) throw new Exception(name); }
    public static string Run() {
        var h = new SurfaceReadinessHarness();
        h.preparedScene = new FakeScene { Capacity=1, Data=new ProxyData[1] };
        h.preparedScene.Data[0].identity = new Vector4 { x=13,y=7,w=2 };
        h.owners = new [] { new Owner { stableId=13,revision=7,layoutGeneration=5,cardIndices=new[]{7,2,5} } };
        h.cards = new Card[9]; h.metadata = new CardMetadata[9]; h.ReadyMask = new bool[9];h.CardOwners=new int[9];
        for(int i=0;i<9;i++) { h.cards[i]=new Card{tile=-1};h.CardOwners[i]=-1; }
        foreach(int i in h.owners[0].cardIndices) {
            h.cards[i] = new Card { tile=i };
            h.metadata[i] = new CardMetadata { stableId=13,revision=7,generation=9,ready=1,ownerSlot=0,layoutGeneration=5 };
            h.ReadyMask[i] = true;h.CardOwners[i]=0;
        }
        Check(h.IsSlotReady(0,13,7),"warming owner can become material-ready");
        h.preparedScene.Data[0].identity.w=1;
        Check(h.IsSlotReady(0,13,7),"published owner readiness");
        Check(!h.IsSlotReady(-1,13,7) && !h.IsSlotReady(1,13,7),"invalid slot");
        Check(!h.IsSlotReady(0,14,7) && !h.IsSlotReady(0,13,8),"stale caller identity");
        Check(h.GetGeneration(-1)==0 && h.GetGeneration(9)==0 && h.GetGeneration(1)==0,"invalid/absent generation lookup");
        foreach(int i in h.owners[0].cardIndices) {
            var good=h.metadata[i];
            h.metadata[i].ready=0; Check(!h.IsSlotReady(0,13,7),"partial capture"); h.metadata[i]=good;
            h.metadata[i].stableId=14; Check(!h.IsSlotReady(0,13,7),"reused page identity"); h.metadata[i]=good;
            h.metadata[i].revision=8; Check(!h.IsSlotReady(0,13,7),"changed page revision"); h.metadata[i]=good;
            h.metadata[i].generation=0; Check(!h.IsSlotReady(0,13,7),"uninitialized generation"); h.metadata[i]=good;
            h.metadata[i].layoutGeneration=6; Check(!h.IsSlotReady(0,13,7),"old layout metadata"); h.metadata[i]=good;
            h.metadata[i].ownerSlot=1; Check(!h.IsSlotReady(0,13,7),"GPU card assigned another owner"); h.metadata[i]=good;
            h.CardOwners[i]=1;Check(!h.IsSlotReady(0,13,7),"CPU card assigned another owner");h.CardOwners[i]=0;
            h.ReadyMask[i]=false; Check(!h.IsSlotReady(0,13,7),"pending CPU flag"); h.ReadyMask[i]=true;
            h.cards[i].tile=-1; Check(!h.IsSlotReady(0,13,7) && h.GetGeneration(i)==0,"evicted tile"); h.cards[i].tile=i;
            Check(h.GetGeneration(i)==9,"generation snapshot");
        }
        var retained=h.owners[0].cardIndices;h.owners[0].cardIndices=new int[0];Check(!h.IsSlotReady(0,13,7),"empty chart set is not ready");
        h.owners[0].cardIndices=new[]{-1};Check(!h.IsSlotReady(0,13,7),"invalid physical card index");h.owners[0].cardIndices=retained;
        h.owners[0].layoutGeneration=0;Check(!h.IsSlotReady(0,13,7),"absent layout version");h.owners[0].layoutGeneration=5;
        h.preparedScene.Data[0].identity.w=0; Check(!h.IsSlotReady(0,13,7),"scene retirement");
        h.preparedScene.Data[0].identity.w=2;
        h.owners[0].revision=8; Check(!h.IsSlotReady(0,13,7),"changed CPU owner");
        h.owners[0]=null; Check(!h.IsSlotReady(0,13,7),"missing CPU owner");
        // Run the actual residency comparator: arbitrarily close warming pages
        // may never displace farther published pages when the latter fit.
        var rng = new Random(607);
        for(int trial=0;trial<1000;trial++) {
            int count=rng.Next(2,40), published=rng.Next(1,count), capacity=rng.Next(1,count+1);
            h.preparedScene=new FakeScene { Capacity=count,Data=new ProxyData[count],renderers=new FakeRenderer[count] };
            h.owners=new Owner[count];
            var sorted=new List<int>();
            for(int i=0;i<count;i++) {
                h.preparedScene.Data[i].identity.w=i<published?1:2;
                h.preparedScene.renderers[i]=new FakeRenderer { bounds=new FakeBounds { distance=i<published?(float)rng.NextDouble()*100000+100:0.001f } };
                if(rng.NextDouble()<0.5) h.owners[i]=new Owner();
                sorted.Add(i);
            }
            sorted.Sort(h.CompareResidency);
            int residentPublished=0;
            for(int i=0;i<capacity;i++) if(sorted[i]<published) residentPublished++;
            Check(residentPublished==Math.Min(published,capacity),"published reservation");
        }
        return "Surface readiness: actual variable noncontiguous card methods passed identity, revision, layout/owner, partial-capture, eviction and generation cases; actual comparator passed 1000 published/warming capacity cases. No Unity/GPU execution.";
    }
}
'@
Add-Type -TypeDefinition $harness
[SurfaceReadinessHarness]::Run()
