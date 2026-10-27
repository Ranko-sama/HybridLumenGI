param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$source = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGISurfaceCache.cs") -Raw
function Extract([string]$begin,[string]$after) {
    $a=$source.IndexOf($begin); $b=$source.IndexOf($after,$a)
    if($a -lt 0 -or $b -le $a) { throw "Surface source methods changed; update extraction: $begin" }
    return $source.Substring($a,$b-$a)
}
$methods = (Extract '        public bool IsSlotSourceCurrent(' '        public bool Prepare(') +
    (Extract '        private static bool CanCaptureRegisteredRenderer(' '        private static bool Supported(') +
    (Extract '        private static bool Finite(float value)' '        private static bool Finite(Vector4 value)') +
    (Extract '        private static int GeometrySignature(' '        private void AddChangedBounds(')
$harness = @'
using System;
using System.Collections.Generic;
public class SurfaceSourceHarness {
    public static class HybridLumenGIDeformedMesh {
        public static bool HasSnapshot(Renderer renderer) {return false;}
        public static Mesh GetSourceMesh(Renderer renderer) {
            var skin=renderer as SkinnedMeshRenderer;
            if(skin!=null)return skin.sharedMesh;
            var filter=renderer!=null?renderer.GetComponent<MeshFilter>():null;
            return filter!=null?filter.sharedMesh:null;
        }
    }
    public struct Vector3 {
        public float x,y,z;
        public Vector3(float a,float b,float c) {x=a;y=b;z=c;}
        public static Vector3 operator*(Vector3 a,float b) {return new Vector3(a.x*b,a.y*b,a.z*b);}
    }
    public struct Bounds {
        public Vector3 center,extents;
        public Bounds(Vector3 c,Vector3 size) {center=c;extents=size*0.5f;}
    }
    public struct Matrix4x4 {
        public float a,b,c,d,e,f,g,h,i,tx,ty,tz;
        private System.Numerics.Matrix4x4 Numerics {get{return new System.Numerics.Matrix4x4(a,d,g,0,b,e,h,0,c,f,i,0,tx,ty,tz,1);}}
        public float determinant {get{return Numerics.GetDeterminant();}}
        public Matrix4x4 inverse {get{System.Numerics.Matrix4x4 m;System.Numerics.Matrix4x4.Invert(Numerics,out m);return new Matrix4x4 {a=m.M11,b=m.M21,c=m.M31,d=m.M12,e=m.M22,f=m.M32,g=m.M13,h=m.M23,i=m.M33,tx=m.M41,ty=m.M42,tz=m.M43};}}
        public float this[int n] {get {switch(n){case 0:return a;case 1:return d;case 2:return g;case 4:return b;case 5:return e;case 6:return h;case 8:return c;case 9:return f;case 10:return i;case 12:return tx;case 13:return ty;case 14:return tz;case 15:return 1;default:return 0;}}}
        public Vector3 MultiplyVector(Vector3 v) {return new Vector3(a*v.x+b*v.y+c*v.z,d*v.x+e*v.y+f*v.z,g*v.x+h*v.y+i*v.z);}
        public Vector3 MultiplyPoint3x4(Vector3 v) {var p=MultiplyVector(v);p.x+=tx;p.y+=ty;p.z+=tz;return p;}
    }
    public static class Mathf { public static float Abs(float value) {return Math.Abs(value);} }
    public static class Time {public static int frameCount=1;}
    public class Mesh {
        public Bounds bounds=new Bounds(new Vector3(0,0,0),new Vector3(2,2,2));
        public int vertexCount=8,subMeshCount=1; public int GetInstanceID() {return 14;}
    }
    public class MeshFilter {public Mesh sharedMesh;}
    public class GameObject {public bool activeInHierarchy=true;}
    public class Material {}
    public class Renderer {
        public GameObject gameObject=new GameObject();public bool enabled=true,forceRenderingOff;
        public Mesh mesh=new Mesh();public int sourceSignature=5;
        public Matrix4x4 localToWorldMatrix=new Matrix4x4 {a=1,e=1,i=1};public Bounds bounds;
        public T GetComponent<T>() where T:class {return new MeshFilter {sharedMesh=mesh} as T;}
        public void GetSharedMaterials(List<Material> list) {list.Clear();}
        public void GetPropertyBlock(object block) {}
    }
    public class MeshRenderer:Renderer {}
    public class SkinnedMeshRenderer:Renderer {public Mesh sharedMesh {get {return mesh;}}}
    public class Charts {public bool IsValid=true;public uint ContentVersion=1;public Mesh CaptureMesh=new Mesh();}
    public class Proxy {public bool isActiveAndEnabled=true;public int StableId=13,Revision=7,GeometryContentRevision=1;public Renderer SourceRenderer;public Charts SurfaceCharts;}
    public class Owner {public Proxy proxy;public Renderer renderer;public int signature,geometrySignature,sourceGeometryRevision=1;public Charts charts;public uint chartVersion;public Mesh captureMesh,sourceMesh;}
    private Owner[] owners=new Owner[1];private bool ready=true;
    private List<Material> sourceMaterials=new List<Material>();private object rendererBlock=new object();
    // Separate Validate-SurfaceReadiness tests the actual page/scene identity method.
    private bool IsSlotReady(int slot,int id,int revision) {return ready && slot==0 && id==13 && revision==7;}
    // This models native CRC/texture/MPB reads; those Unity APIs are not emulated here.
    private int SourceSignature(Renderer renderer,List<Material> materials) {return renderer.sourceSignature;}
    private bool SourceMaterialsCurrent(Owner owner) {return exactSourceCurrent;}
    private bool exactSourceCurrent=true;
'@ + $methods + @'
    private static int assertions;
    private static void Check(bool value,string name) {assertions++;if(!value)throw new Exception(name);}
    private static void Near(float a,float b,string name) {Check(Math.Abs(a-b)<0.0002f,name);}
    public static string Run() {
        var h=new SurfaceSourceHarness();var mesh=new MeshRenderer {enabled=false};
        h.owners[0]=new Owner {renderer=mesh,proxy=new Proxy {SourceRenderer=mesh},signature=5,geometrySignature=GeometrySignature(mesh)};
        Check(CanCaptureRegisteredRenderer(mesh),"disabled static source supports explicit DrawMesh");
        Check(h.IsSlotSourceCurrent(0,13,7),"unchanged disabled source current");
        mesh.forceRenderingOff=true;Check(CanCaptureRegisteredRenderer(mesh),"force-hidden static source supports explicit DrawMesh");mesh.forceRenderingOff=false;
        mesh.sourceSignature=6;Check(!h.IsSlotSourceCurrent(0,13,7),"material/texture/MPB signature change invalidates old publication ticket");
        Check(h.owners[0].signature==5,"pure check does not advance material signature");mesh.sourceSignature=5;
        h.exactSourceCurrent=false;Check(!h.IsSlotSourceCurrent(0,13,7),"same compact hash cannot override a failed exact material observation");h.exactSourceCurrent=true;
        mesh.localToWorldMatrix.tx=3;Check(!h.IsSlotSourceCurrent(0,13,7),"source transform change invalidates ticket");mesh.localToWorldMatrix.tx=0;
        mesh.mesh.bounds.center.x=2;Check(!h.IsSlotSourceCurrent(0,13,7),"shared mesh bounds change invalidates ticket");mesh.mesh.bounds.center.x=0;
        h.owners[0].proxy.Revision=8;Check(!h.IsSlotSourceCurrent(0,13,7),"live proxy revision checked before scene prepare");h.owners[0].proxy.Revision=7;
        h.owners[0].proxy.SourceRenderer=new MeshRenderer();Check(!h.IsSlotSourceCurrent(0,13,7),"source renderer replacement invalidates ticket");h.owners[0].proxy.SourceRenderer=mesh;
        h.owners[0].proxy.isActiveAndEnabled=false;Check(!h.IsSlotSourceCurrent(0,13,7),"disabled proxy fails");h.owners[0].proxy.isActiveAndEnabled=true;
        mesh.gameObject.activeInHierarchy=false;Check(!CanCaptureRegisteredRenderer(mesh) && !h.IsSlotSourceCurrent(0,13,7),"inactive source object fails");mesh.gameObject.activeInHierarchy=true;
        h.ready=false;Check(!h.IsSlotSourceCurrent(0,13,7),"partial material pages fail before source comparison");h.ready=true;
        var skin=new SkinnedMeshRenderer {enabled=false};Check(!CanCaptureRegisteredRenderer(skin),"disabled skin rejected");
        skin.enabled=true;Check(CanCaptureRegisteredRenderer(skin),"enabled skin admitted");
        skin.forceRenderingOff=true;Check(!CanCaptureRegisteredRenderer(skin),"force-hidden skin rejected");
        mesh.mesh=null;Check(!CanCaptureRegisteredRenderer(mesh),"missing mesh fails");mesh.mesh=new Mesh();
        Check(!CanCaptureRegisteredRenderer(new Renderer()),"unsupported renderer type fails");
        mesh.localToWorldMatrix.a=0;Check(!CanCaptureRegisteredRenderer(mesh),"singular capture matrix rejected");mesh.localToWorldMatrix.a=1;
        mesh.localToWorldMatrix.tx=float.NaN;Check(!CanCaptureRegisteredRenderer(mesh),"nonfinite transform rejected");mesh.localToWorldMatrix.tx=0;
        var chartAsset=new Charts();h.owners[0].proxy.SurfaceCharts=chartAsset;
        Check(!h.IsSlotSourceCurrent(0,13,7),"new chart asset invalidates prior fallback readiness");
        h.owners[0].charts=chartAsset;h.owners[0].chartVersion=1;h.owners[0].captureMesh=chartAsset.CaptureMesh;h.owners[0].sourceMesh=mesh.mesh;
        Check(h.IsSlotSourceCurrent(0,13,7),"matching chart source and layout version");
        chartAsset.ContentVersion=2;Check(!h.IsSlotSourceCurrent(0,13,7),"rebaked charts revoke readiness");chartAsset.ContentVersion=1;
        h.owners[0].proxy.GeometryContentRevision++;Check(!h.IsSlotSourceCurrent(0,13,7),"explicit mesh content dirty revokes readiness");h.owners[0].proxy.GeometryContentRevision--;
        chartAsset.IsValid=false;Check(!h.IsSlotSourceCurrent(0,13,7),"invalid chart asset rejected");chartAsset.IsValid=true;
        chartAsset.CaptureMesh=new Mesh();Check(!h.IsSlotSourceCurrent(0,13,7),"capture mesh replacement rejected");chartAsset.CaptureMesh=h.owners[0].captureMesh;
        h.owners[0].sourceMesh=new Mesh();Check(!h.IsSlotSourceCurrent(0,13,7),"source mesh replacement rejected");
        h.owners[0].charts=null;h.owners[0].proxy.SurfaceCharts=null;
        // Compare the actual affine bounds helper with all eight transformed
        // corners, including negative scale, shear, rotation and translation.
        var rng=new Random(932);
        for(int trial=0;trial<1000;trial++) {
            Func<float> r=()=> (float)(rng.NextDouble()*6-3);
            mesh.localToWorldMatrix=new Matrix4x4 {a=r(),b=r(),c=r(),d=r(),e=r(),f=r(),g=r(),h=r(),i=r(),tx=r()*10,ty=r()*10,tz=r()*10};
            mesh.mesh.bounds=new Bounds(new Vector3(r(),r(),r()),new Vector3(Math.Abs(r())+0.1f,Math.Abs(r())+0.1f,Math.Abs(r())+0.1f));
            var calculated=CaptureBounds(mesh);var local=mesh.mesh.bounds;
            var lo=new Vector3(float.PositiveInfinity,float.PositiveInfinity,float.PositiveInfinity);
            var hi=new Vector3(float.NegativeInfinity,float.NegativeInfinity,float.NegativeInfinity);
            for(int c=0;c<8;c++) {
                var p=mesh.localToWorldMatrix.MultiplyPoint3x4(new Vector3(local.center.x+((c&1)==0?-1:1)*local.extents.x,local.center.y+((c&2)==0?-1:1)*local.extents.y,local.center.z+((c&4)==0?-1:1)*local.extents.z));
                lo.x=Math.Min(lo.x,p.x);lo.y=Math.Min(lo.y,p.y);lo.z=Math.Min(lo.z,p.z);hi.x=Math.Max(hi.x,p.x);hi.y=Math.Max(hi.y,p.y);hi.z=Math.Max(hi.z,p.z);
            }
            Near(calculated.center.x-calculated.extents.x,lo.x,"bounds min x");Near(calculated.center.y-calculated.extents.y,lo.y,"bounds min y");Near(calculated.center.z-calculated.extents.z,lo.z,"bounds min z");
            Near(calculated.center.x+calculated.extents.x,hi.x,"bounds max x");Near(calculated.center.y+calculated.extents.y,hi.y,"bounds max y");Near(calculated.center.z+calculated.extents.z,hi.z,"bounds max z");
        }
        return "Surface source: "+assertions+" actual guard/eligibility/affine-bounds assertions passed (1000 corner-oracle cases). Unity CRC/MPB APIs and GPU DrawMesh execution are not run.";
    }
}
'@
$entry = @'
using System;
internal static class HarnessEntry
{
    private static int Main()
    {
        try { Console.WriteLine(SurfaceSourceHarness.Run()); return 0; }
        catch (Exception error) { Console.Error.WriteLine(error); return 1; }
    }
}
'@
& (Join-Path $PSScriptRoot "Invoke-CSharpHarness.ps1") -Name "surface-source" -Sources @{
    "SurfaceSourceHarness.cs" = $harness
    "Program.cs" = $entry
}
