#define HLGI_AREA_CACHE_REUSE
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using HybridLumenGI;
using UnityEngine;
using A=HybridLumenGI.HybridLumenGIAreaEmission;
static class Program {
    static int checks;
    static void Check(bool value,string reason){checks++;if(!value)throw new Exception(reason);}
    sealed class Provider:A.ITriangleProvider {
        public readonly List<A.Triangle[]> Values=new List<A.Triangle[]>();public bool Throw;public int Calls;
        public int GetTriangleCount(int instance){if(Throw)throw new Exception("changed source");return Values[instance].Length;}
        public bool TryGetTriangle(int instance,int primitive,out A.Triangle t){Calls++;t=Values[instance][primitive];return true;}
    }
    static HybridLumenGIHitMaterialBatch.Source Source(int submesh=0,bool emission=true,float intensity=1,float extra=0,uint ownerRevision=3){return new HybridLumenGIHitMaterialBatch.Source(
        new HybridLumenGIMaterialSource.Snapshot{MaterialIndex=submesh,HitMaterial=new HybridLumenGIHitMaterialData{Emission=emission}},2,ownerRevision,4,(uint)submesh,
        new Vector4(1,1,1,1),new Vector4(extra,0,0,intensity));}
    static A.Triangle Triangle(int instance,int primitive,float scale=1,int submesh=0,uint ownerRevision=3){return new A.Triangle{
        P0=new Vector3(0,0,1),P1=new Vector3(scale,0,1),P2=new Vector3(0,scale,1),RawNg=new Vector3(0,0,-1),
        OwnerSlot=8,StableId=2,OwnerRevision=ownerRevision,GeometryRevision=4,Instance=(uint)instance,Submesh=(uint)submesh,Primitive=(uint)primitive,Cull=2};}
    static A.Layout Build(HybridLumenGIHitMaterialBatch.Source[] s,Provider p,int cap=100){Check(A.TryBuild(s,p,9,cap,out var l,out var reason),reason);return l;}
    static byte[] Bytes(A.Layout value)=>MemoryMarshal.AsBytes(new ReadOnlySpan<A.GpuRecord>(value.CopyRecords())).ToArray();
    static bool Same(byte[] a,byte[] b){if(a.Length!=b.Length)return false;for(int i=0;i<a.Length;i++)if(a[i]!=b[i])return false;return true;}
    static void ReuseSequence(){
        var p=new Provider();p.Values.Add(new[]{Triangle(0,0),Triangle(0,1,2),Triangle(0,2,3)});
        var sources=new[]{Source()};ulong version=1;
#if HLGI_AREA_CACHE_REUSE
        var cache=new A.Cache();
#endif
        bool Request(uint generation,int capacity,out A.Layout value,out string reason){
#if HLGI_AREA_CACHE_REUSE
            return cache.TryBuild(sources,p,version,generation,capacity,out value,out reason);
#else
            return A.TryBuild(sources,p,generation,capacity,out value,out reason);
#endif
        }
        A.Layout Verify(string phase,uint generation,int capacity,int reuseReads){
            int before=p.Calls;Check(Request(generation,capacity,out var value,out var reason),phase+": "+reason);
            int reads=p.Calls-before;
#if HLGI_AREA_CACHE_REUSE
            Check(reads==reuseReads,phase+": triangle evaluation count "+reads+" expected "+reuseReads);
#else
            if(phase=="stable-new-batch")Check(reads==3,"baseline must repeat triangle evaluation");
#endif
            var reference=new Provider();foreach(var triangles in p.Values)reference.Values.Add(triangles);
            Check(A.TryBuild(sources,reference,generation,capacity,out var fresh,out reason),phase+" reference: "+reason);
            Check(value.MaterialGeneration==generation&&value.CapacityLimited==fresh.CapacityLimited&&value.Count==fresh.Count&&value.ByteCount==fresh.ByteCount&&Same(Bytes(value),Bytes(fresh)),phase+": uncached equality");
            foreach(var record in value.Records)Check(record.geometry.w==generation,phase+": current material generation");
            Console.WriteLine("AREA_REUSE phase="+phase+" generation="+generation+" trianglesRead="+reads+" count="+value.Count+" limited="+value.CapacityLimited);
            return value;
        }
        var first=Verify("cold",9,100,3);byte[] original=Bytes(first);
        Verify("stable-new-batch",10,100,0);Check(first.MaterialGeneration==9&&Same(original,Bytes(first)),"old Work changed on rebind");
        sources[0]=Source(ownerRevision:4);
        for(int i=0;i<3;i++){var t=p.Values[0][i];t.OwnerRevision=4;p.Values[0][i]=t;}
        Verify("owner-with-same-geometry-version",11,100,3);
        p.Values[0][0]=Triangle(0,0,4,ownerRevision:4);version++;
        Verify("prepared-geometry",12,100,3);
        var replacement=new Provider();foreach(var triangles in p.Values)replacement.Values.Add((A.Triangle[])triangles.Clone());p=replacement;
        p.Values[0][0]=Triangle(0,0,5,ownerRevision:4);
        Verify("provider-with-same-version",13,100,3);
        Verify("capacity-subset",14,1,1);
        sources=new[]{sources[0],Source(1,emission:false)};p.Values.Add(new[]{Triangle(1,0,submesh:1)});
        Verify("added-excluded-source",15,1,1);
        sources[1]=Source(1);Verify("truncated-candidate-change",16,1,1);
        sources[0]=Source(emission:false,ownerRevision:4);Verify("candidate-selection",17,100,1);
        sources[1]=Source(1,emission:false);Verify("empty",18,100,0);
        sources[0]=Source(ownerRevision:4);Verify("restore-emitter",19,100,3);
        version++;p.Throw=true;
        Check(!Request(20,100,out var failed,out var failure)&&failed==null&&!string.IsNullOrEmpty(failure),"failure returned stale layout");
        Console.WriteLine("AREA_REUSE phase=deliberate-provider-failure rejected=True layoutNull=True");
        p.Throw=false;Verify("recover",21,100,3);
        Verify("disabled-capacity",22,0,0);
#if HLGI_AREA_CACHE_REUSE
        cache.Clear();
#endif
        Verify("after-clear",23,100,3);
        Check(first.MaterialGeneration==9&&Same(original,Bytes(first)),"old immutable output changed later");
        Console.WriteLine("AREA_REUSE finite directed sequence PASS; prepared provider/version/material inputs are adapters, no Backend or RenderGraph execution.");
    }
    static void Main(){
        Check(Marshal.SizeOf<A.GpuRecord>()==96,"GPU record ABI");
        Check(Marshal.OffsetOf<A.GpuRecord>("identity").ToInt32()==64&&Marshal.OffsetOf<A.GpuRecord>("geometry").ToInt32()==80,"identity offsets");
        var p=new Provider();p.Values.Add(new[]{Triangle(0,0),Triangle(0,1,2),Triangle(0,2,3)});var s=new[]{Source()};
        var l=Build(s,p);Check(l.Count==3&&!l.CapacityLimited&&l.MaterialGeneration==9,"3 triangles");
        double lower=0;for(int i=0;i<3;i++){var r=l.Records[i];Check(r.p0.w==(i+1)*(i+1)*.5f,"world area");Check(r.p1.w==lower,"contiguous CDF");Check(Math.Abs(r.p2.w-(i==0?1.0/14:i==1?5.0/14:1))<4e-8,"independent area sum");Check(r.rawNg.z==-1,"authored covector not mirrored cross");lower=r.p2.w;}
        var copy=l.CopyRecords();copy[0]=default;Check(l.Records[0].p0.w>.4f,"immutable upload copy");
        l=Build(s,p,1);Check(l.Count==1&&l.CapacityLimited&&l.Records[0].p2.w==1,"capacity subset has complete distribution");
        l=Build(s,p,0);Check(l.Count==0&&l.CapacityLimited&&l.ByteCount==96,"disabled dummy budget");
        Check(Build(new[]{Source(emission:false)},p).Count==0,"nonemitter excluded");
        Check(Build(new[]{Source(emission:false,extra:2)},p).Count==3,"proxy Le supported without keyword");
        Check(Build(new[]{Source(intensity:0)},p).Count==0,"zero total emission intensity");
        Check(Build(new[]{Source(intensity:float.NaN)},p).Count==0,"invalid emission cannot invent Le");
        var t=Triangle(0,0);t.GeometryRevision++;p.Values[0]=new[]{t};Check(Build(s,p).Count==0,"stale geometry rejected");
        t=Triangle(0,0);t.Submesh=1;p.Values[0]=new[]{t};Check(Build(s,p).Count==0,"wrong submesh rejected");
        t=Triangle(0,0);t.RawNg=new Vector3(1,0,0);p.Values[0]=new[]{t};Check(Build(s,p).Count==0,"nongemetric normal rejected");
        t=Triangle(0,0);t.P1=t.P0;p.Values[0]=new[]{t};Check(Build(s,p).Count==0,"degenerate rejected");
        t=Triangle(0,0);t.P2=new Vector3(float.PositiveInfinity,0,0);p.Values[0]=new[]{t};Check(Build(s,p).Count==0,"nonfinite rejected");
        p.Throw=true;Check(!A.TryBuild(s,p,9,10,out _,out _),"provider exception fails capture");p.Throw=false;
        Check(!A.TryBuild(s,p,0,10,out _,out _),"zero generation");
        Check(!A.TryBuild(s,p,9,A.MaxTriangles+1,out _,out _),"capacity hard cap");
        p.Values[0]=new[]{Triangle(0,0,1e10f),Triangle(0,1,1e-10f),Triangle(0,2,1e10f)};
        l=Build(s,p);Check(l.Count==2&&l.Records[0].p2.w==.5f&&l.Records[1].p1.w==.5f&&l.Records[1].geometry.z==2,"rounded zero PMF compacted without renumbering primitive");
        var random=new Random(7193);
        for(int run=0;run<60;run++){
            int count=1+random.Next(120);var values=new A.Triangle[count];double total=0;
            for(int i=0;i<count;i++){float x=(float)(.01+random.NextDouble()*30);values[i]=Triangle(0,i,x);total+=(double)x*x/2;}
            p.Values[0]=values;l=Build(s,p,150);Check(l.Count==count,"random nonempty intervals");double cumulative=0;
            for(int i=0;i<count;i++){cumulative+=(double)values[i].P1.x*values[i].P2.y/2;var r=l.Records[i];Check(Math.Abs(r.p2.w-cumulative/total)<1.3e-7,"random independent area oracle");Check(r.p2.w>r.p1.w,"positive represented PMF");Check(r.geometry.z==(uint)i,"stable primitive lookup");}
        }
        ReuseSequence();
        Console.WriteLine("AreaEmission actual C# builder: "+checks+" checks PASS; Unity/material capture replaced by explicit immutable input adapters, no rendering evidence.");
    }
}
