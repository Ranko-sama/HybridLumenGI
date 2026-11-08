param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$actual = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGILitQualification.cs") -Raw
$discovery = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIReceiverDiscovery.cs") -Raw
$stubs = @'
using System;
using System.Collections.Generic;
namespace UnityEngine {
    public struct LayerMask { public int value; public static implicit operator LayerMask(int v) { return new LayerMask { value=v }; } }
    public struct Vector3 { public float x,y,z; public float sqrMagnitude { get { return x*x+y*y+z*z; } } }
    public struct Matrix4x4 {
        public bool invalid,singular,inverseInvalid; public float offset;
        public float this[int i] { get { return invalid?float.NaN:(i==12?offset:(i%5==0?1:0)); } }
        public float determinant { get { return singular?0:1; } }
        public Matrix4x4 inverse { get { return new Matrix4x4 {invalid=inverseInvalid,offset=-offset}; } }
    }
    public struct Plane { public Vector3 normal; public float distance; }
    public struct Bounds { public Vector3 center,extents; public bool outside; }
    public struct Scene { public bool valid,isLoaded; public bool IsValid() { return valid; } }
    [Flags] public enum HideFlags { None=0,HideInHierarchy=1,DontSave=52 }
    public class GameObject { public bool activeInHierarchy=true; public int layer; public HideFlags hideFlags; public Scene scene=new Scene {valid=true,isLoaded=true}; }
    public class Camera { public int cullingMask=-1; public Matrix4x4 cullingMatrix; }
    public class Shader { public string name; public int renderQueue=2000; }
    public class Material { public string name="material"; public Shader shader; public int renderQueue=2000; }
    public class Renderer {
        public string name="renderer"; public bool enabled=true,forceRenderingOff; public GameObject gameObject=new GameObject();
        public Bounds bounds=new Bounds {extents=new Vector3 {x=1,y=1,z=1}};
        public Material[] shared=new Material[0]; public bool isPartOfStaticBatch,throwMaterials;
        public Matrix4x4 localToWorldMatrix; public MeshFilter filter=new MeshFilter {sharedMesh=new Mesh()};
        public int mutationCount,materialReads,identityCode;
        public void GetSharedMaterials(List<Material> materials) { materialReads++; if(throwMaterials) throw new InvalidOperationException("injected renderer read failure"); materials.AddRange(shared); }
        public T GetComponent<T>() where T:class { return filter as T; }
        public void SetPropertyBlock(object block) { mutationCount++;throw new Exception("Source MPB mutation forbidden"); }
        public Material[] sharedMaterials { get { return shared; } set { mutationCount++;throw new Exception("Source material mutation forbidden"); } }
        public override bool Equals(object other) { var r=other as Renderer; return r!=null&&(identityCode!=0&&identityCode==r.identityCode||ReferenceEquals(this,r)); }
        public override int GetHashCode() { return identityCode; }
    }
    public class MeshRenderer:Renderer { public Mesh additionalVertexStreams,enlightenVertexStream; }
    public class SkinnedMeshRenderer:Renderer { public Mesh sharedMesh; }
    public enum MeshTopology { Triangles,Lines }
    public class Mesh {
        public int subMeshCount=1; public MeshTopology topology=MeshTopology.Triangles; public bool throwTopology;
        public Action onTopology;
        public MeshTopology GetTopology(int index) {
            if(throwTopology) throw new Exception("injected topology read failure");
            onTopology?.Invoke(); return topology;
        }
    }
    public class MeshFilter { public Mesh sharedMesh; }
    public struct LOD { public Renderer[] renderers; }
    public class LODGroup {
        public GameObject gameObject=new GameObject(); public bool enabled=true,throwLods; public LOD[] lods=new LOD[0];
        public LOD[] GetLODs() { if(throwLods) throw new Exception("injected LOD read failure"); return lods; }
    }
    public static class Resources {
        public static Renderer[] current=new Renderer[0]; public static LODGroup[] lods=new LODGroup[0]; public static int scans,rendererScans,lodScans;
        public static bool throwRenderers,throwLods;
        public static T[] FindObjectsOfTypeAll<T>() {
            scans++;
            if(typeof(T)==typeof(Renderer)) { rendererScans++;if(throwRenderers) throw new Exception("injected census failure");return (T[])(object)current; }
            if(typeof(T)==typeof(LODGroup)) { lodScans++;if(throwLods) throw new Exception("injected LOD census failure");return (T[])(object)lods; }
            throw new Exception("Unexpected resource query");
        }
    }
    public static class GeometryUtility {
        public static bool badPlanes,throwPlanes;
        public static void CalculateFrustumPlanes(Matrix4x4 matrix,Plane[] planes) { if(throwPlanes) throw new Exception("injected culling failure"); for(int i=0;i<6;i++) planes[i]=new Plane {normal=new Vector3 {x=badPlanes?0:1}}; }
        public static bool TestPlanesAABB(Plane[] planes,Bounds bounds) { return !bounds.outside; }
    }
}
namespace UnityEngine.Rendering {
    public struct RenderQueueRange { public int lowerBound,upperBound; public static RenderQueueRange opaque { get { return new RenderQueueRange {lowerBound=0,upperBound=2500}; } } }
}
public static class LitQualificationCases {
    private const string Lit="Universal Render Pipeline/Lit";
    private static int assertions;
    private static void Check(bool condition,string message) { assertions++; if(!condition) throw new Exception(message); }
    private static UnityEngine.Renderer R(string shader,int queue=2000) {
        return new UnityEngine.MeshRenderer {shared=new [] {new UnityEngine.Material {renderQueue=queue,shader=new UnityEngine.Shader {name=shader}}}};
    }
    public static string Run() {
        var q=new HybridLumenGI.HybridLumenGILitQualification(); var camera=new UnityEngine.Camera(); string reason;
        UnityEngine.Resources.current=new [] {R(Lit)};
        Check(q.Validate(camera,-1,out reason) && reason==null,"ordinary Lit passes");
        var lit=UnityEngine.Resources.current[0];
        lit.shared[0].shader.name="Universal Render Pipeline/Unlit";
        Check(!q.Validate(camera,-1,out reason) && reason.Contains("Unlit"),"same-instance shader swap detected immediately");
        lit.shared[0].shader.name=Lit;
        UnityEngine.Resources.current=new [] {lit,R("Shader Graphs/Custom Lit")};
        Check(!q.Validate(camera,-1,out reason),"new renderer detected immediately");
        var other=UnityEngine.Resources.current[1];
        other.enabled=false; Check(q.Validate(camera,-1,out reason),"disabled receiver excluded"); other.enabled=true;
        other.forceRenderingOff=true; Check(q.Validate(camera,-1,out reason),"forceRenderingOff excluded"); other.forceRenderingOff=false;
        other.gameObject.activeInHierarchy=false; Check(q.Validate(camera,-1,out reason),"inactive excluded"); other.gameObject.activeInHierarchy=true;
        other.gameObject.scene.valid=false; Check(q.Validate(camera,-1,out reason),"asset renderer excluded"); other.gameObject.scene.valid=true;
        other.gameObject.scene.isLoaded=false; Check(q.Validate(camera,-1,out reason),"unloaded scene excluded"); other.gameObject.scene.isLoaded=true;
        other.bounds.outside=true; Check(q.Validate(camera,-1,out reason),"outside culling frustum excluded"); other.bounds.outside=false;
        other.gameObject.layer=3; Check(q.Validate(camera,1,out reason),"selection mask excludes other layer");
        camera.cullingMask=1; Check(q.Validate(camera,-1,out reason),"camera mask intersected"); camera.cullingMask=-1; other.gameObject.layer=0;
        other.shared[0].renderQueue=2501; Check(q.Validate(camera,-1,out reason),"transparent queue excluded");
        other.shared[0].renderQueue=2500; Check(!q.Validate(camera,-1,out reason),"opaque upper boundary checked");
        other.shared[0].renderQueue=-1; other.shared[0].shader.renderQueue=2000; Check(!q.Validate(camera,-1,out reason),"shader default queue resolved");
        other.shared=new UnityEngine.Material[] {null}; Check(!q.Validate(camera,-1,out reason),"missing material fails closed");
        other.shared=new [] {new UnityEngine.Material()}; Check(!q.Validate(camera,-1,out reason),"missing shader fails closed");
        other.shared=new [] {new UnityEngine.Material {shader=new UnityEngine.Shader {name=Lit.ToLowerInvariant()}}};
        Check(!q.Validate(camera,-1,out reason),"shader name is exact case-sensitive identity");
        other.shared=new [] {new UnityEngine.Material {shader=new UnityEngine.Shader {name=Lit}},new UnityEngine.Material {shader=new UnityEngine.Shader {name="Custom"}}};
        Check(!q.Validate(camera,-1,out reason),"all material slots checked");
        other.bounds.center.x=float.NaN; Check(!q.Validate(camera,-1,out reason) && reason.Contains("bounds"),"invalid bounds do not cull away an unsupported renderer");
        Check(!q.Validate(null,-1,out reason),"null camera fails closed");
        camera.cullingMatrix=new UnityEngine.Matrix4x4 {invalid=true}; Check(!q.Validate(camera,-1,out reason),"invalid camera matrix fails closed");
        Check(UnityEngine.Resources.scans>=19,"each eligible validation rescans live renderer set");
        RunDiscovery();
        RunBudgetedDiscovery();
        return "Lit qualification and receiver discovery: "+assertions+" assertions passed against both actual runtime classes with minimal Unity API stubs. Shared CPU admission stops the next check, rejects partial native qualification and allows fresh discovery. Unity culling, RendererList contents, pixel identity and GPU rendering are outside this harness.";
    }
    private static bool Has(HybridLumenGI.HybridLumenGIReceiverDiscovery.Candidate c,HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues issue) { return (c.IdentityIssues&issue)!=0; }
    private static void RunDiscovery() {
        var d=new HybridLumenGI.HybridLumenGIReceiverDiscovery();
        var q=new HybridLumenGI.HybridLumenGILitQualification();var camera=new UnityEngine.Camera();string reason;
        var good=R(Lit);var bad=R("Custom");
        UnityEngine.Resources.current=new [] {bad,good};
        var first=d.Scan(camera,-1);
        Check(first.ScanComplete&&!first.NativeDiffuseCompatible&&first.HasUnknownSources,"bad material is complete but not native-compatible");
        Check(first.ScannedRenderers==2&&first.CandidateRenderers==2&&first.CheckedMaterials==2,"bad first item cannot stop full census");
        Check(ReferenceEquals(first.Candidates[1].Renderer,good)&&first.Candidates[1].IdentityIssues==0,"later ordinary Lit without Proxy remains eligible");
        Check(Has(first.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.UnsupportedMaterial),"unsupported material reason retained");
        int scanCount=UnityEngine.Resources.scans;
        Check(!q.Validate(first,out reason)&&reason.Contains("Custom")&&UnityEngine.Resources.scans==scanCount,"snapshot qualification does not rescan");
        Check(q.ScannedRenderers==2&&q.CheckedMaterials==2,"qualification propagates complete counters");
        Check(!q.Validate((HybridLumenGI.HybridLumenGIReceiverDiscovery.Snapshot)null,out reason),"null snapshot rejected");

        var slots=R(Lit);slots.shared=new [] {null,good.shared[0],bad.shared[0]};slots.filter.sharedMesh.subMeshCount=3;
        UnityEngine.Resources.current=new [] {slots,good};var allSlots=d.Scan(camera,-1);
        Check(allSlots.Candidates.Count==2&&allSlots.CheckedMaterials==3,"null material does not stop later slots or renderers");
        Check(Has(allSlots.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.MissingMaterial)&&Has(allSlots.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.UnsupportedMaterial),"all slot restrictions accumulated");

        var layer31=R(Lit);layer31.gameObject.layer=31;
        good.gameObject.hideFlags=UnityEngine.HideFlags.DontSave|UnityEngine.HideFlags.HideInHierarchy;
        UnityEngine.Resources.current=new [] {good,layer31};camera.cullingMatrix=new UnityEngine.Matrix4x4 {offset=5};
        var a=d.Scan(camera,1);var secondCamera=new UnityEngine.Camera {cullingMask=unchecked((int)0x80000000)};
        var b=d.Scan(secondCamera,-1);
        Check(a.Candidates.Count==1&&ReferenceEquals(a.Candidates[0].Renderer,good),"DontSave in loaded scene is retained");
        Check(b.Candidates.Count==1&&ReferenceEquals(b.Candidates[0].Renderer,layer31),"bit31 culling and selection remain exact");
        Check(ReferenceEquals(a.Camera,camera)&&a.SelectedLayers.value==1&&a.CameraCullingMask==-1&&a.EffectiveLayerMask==1&&a.CullingMatrix.offset==5,"camera context captured by value where applicable");
        Check(ReferenceEquals(b.Camera,secondCamera)&&b.CameraCullingMask==unchecked((int)0x80000000),"second camera context independent");
        camera.cullingMask=0;camera.cullingMatrix=new UnityEngine.Matrix4x4 {offset=9};
        var empty=d.Scan(camera,-1);
        Check(empty.ScanComplete&&empty.Candidates.Count==0&&empty.NativeDiffuseCompatible,"empty effective mask yields complete empty result");
        Check(a.CullingMatrix.offset==5&&a.CameraCullingMask==-1&&a.Candidates.Count==1,"later camera mutation and scan do not rewrite previous values");
        camera.cullingMask=-1;camera.cullingMatrix=default(UnityEngine.Matrix4x4);
        good.localToWorldMatrix=new UnityEngine.Matrix4x4 {offset=7};UnityEngine.Resources.current=new [] {good};var owned=d.Scan(camera,-1);
        UnityEngine.Material oldMaterial=good.shared[0];good.shared=new [] {new UnityEngine.Material {shader=new UnityEngine.Shader {name="AfterScan"}}};good.localToWorldMatrix=new UnityEngine.Matrix4x4 {offset=11};
        Check(ReferenceEquals(owned.Candidates[0].Materials[0],oldMaterial)&&owned.Candidates[0].LocalToWorld.offset==7,"material slot array and matrix are owned snapshot values");
        bool readOnly=false;try { ((IList<HybridLumenGI.HybridLumenGIReceiverDiscovery.Candidate>)owned.Candidates).Clear(); } catch(NotSupportedException) {readOnly=true;}Check(readOnly,"candidate collection immutable");
        readOnly=false;try { ((IList<UnityEngine.Material>)owned.Candidates[0].Materials)[0]=null; } catch(NotSupportedException) {readOnly=true;}Check(readOnly,"material slot collection immutable");
        good.shared=new [] {oldMaterial};

        var unknownBounds=R(Lit);unknownBounds.bounds.center.x=float.NaN;unknownBounds.bounds.outside=true;
        UnityEngine.Resources.current=new [] {unknownBounds,good};var boundsResult=d.Scan(camera,-1);
        Check(boundsResult.Candidates.Count==2&&Has(boundsResult.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.InvalidBounds),"unknown bounds retained, not culled");
        Check(!boundsResult.NativeDiffuseCompatible&&boundsResult.NativeDiffuseReason.Contains("bounds")&&boundsResult.HasUnknownSources,"bounds failure preserves conservative native rejection");
        unknownBounds.bounds.center.x=0;unknownBounds.bounds.extents.x=-1;
        Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.InvalidBounds),"negative bounds extent unknown");

        var transparent=R("NotLit",3000);UnityEngine.Resources.current=new [] {transparent,good};var transparentResult=d.Scan(camera,-1);
        Check(transparentResult.Candidates.Count==1&&transparentResult.NativeDiffuseCompatible&&transparentResult.CheckedMaterials==1,"transparent-only omitted without failing native qualification");
        var missing=R(Lit);missing.shared=new UnityEngine.Material[] {null};UnityEngine.Resources.current=new [] {missing,good};
        var missingResult=d.Scan(camera,-1);Check(!missingResult.NativeDiffuseCompatible&&!missingResult.Candidates[0].HasOpaqueMaterials&&missingResult.Candidates.Count==2,"unknown material retained even without known opaque slot");

        var special=(UnityEngine.MeshRenderer)R(Lit);UnityEngine.Resources.current=new UnityEngine.Renderer[] {special};
        Check(d.Scan(camera,-1).Candidates[0].IdentityIssues==0,"ordinary mesh starts with no identity restrictions");
        special.isPartOfStaticBatch=true;var restrictions=d.Scan(camera,-1);
        Check(restrictions.NativeDiffuseCompatible&&Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.StaticBatch),"static batch restricts identity only");special.isPartOfStaticBatch=false;
        special.additionalVertexStreams=new UnityEngine.Mesh();restrictions=d.Scan(camera,-1);
        Check(restrictions.NativeDiffuseCompatible&&Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.AdditionalVertexStreams),"additional stream restricts identity only");special.additionalVertexStreams=null;
        special.enlightenVertexStream=new UnityEngine.Mesh();restrictions=d.Scan(camera,-1);
        Check(restrictions.NativeDiffuseCompatible&&Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.EnlightenVertexStream),"enlighten stream explicit");special.enlightenVertexStream=null;
        var group=new UnityEngine.LODGroup {lods=new [] {new UnityEngine.LOD {renderers=new UnityEngine.Renderer[] {special}}}};
        UnityEngine.Resources.lods=new [] {group};restrictions=d.Scan(camera,-1);
        Check(restrictions.NativeDiffuseCompatible&&Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.LodMembership),"explicit non-parent LOD reference detected without rejecting native Lit");
        group.gameObject.scene.valid=false;Check(d.Scan(camera,-1).Candidates[0].IdentityIssues==0,"asset LOD group ignored");group.gameObject.scene.valid=true;
        group.gameObject.scene.isLoaded=false;Check(d.Scan(camera,-1).Candidates[0].IdentityIssues==0,"unloaded LOD group ignored");group.gameObject.scene.isLoaded=true;
        group.enabled=false;Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.LodMembership),"disabled group does not manufacture known LOD selection");
        UnityEngine.Resources.lods=new UnityEngine.LODGroup[0];
        special.filter.sharedMesh.subMeshCount=2;Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.MeshSubmeshMismatch),"submesh/material mismatch explicit");special.filter.sharedMesh.subMeshCount=1;
        special.filter.sharedMesh.topology=UnityEngine.MeshTopology.Lines;Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.NonTriangleTopology),"nontriangle submesh explicit");special.filter.sharedMesh.topology=UnityEngine.MeshTopology.Triangles;
        var originalMesh=special.filter.sharedMesh;special.filter.sharedMesh=null;Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.MissingMesh),"missing mesh explicit");special.filter.sharedMesh=originalMesh;
        special.localToWorldMatrix=new UnityEngine.Matrix4x4 {singular=true};restrictions=d.Scan(camera,-1);Check(Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.InvalidTransform)&&restrictions.NativeDiffuseCompatible,"singular identity matrix does not change old native shader qualification");
        special.localToWorldMatrix=new UnityEngine.Matrix4x4 {invalid=true};Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.InvalidTransform),"nonfinite matrix explicit");
        special.localToWorldMatrix=new UnityEngine.Matrix4x4 {inverseInvalid=true};Check(Has(d.Scan(camera,-1).Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.InvalidTransform),"nonfinite inverse explicit");special.localToWorldMatrix=default(UnityEngine.Matrix4x4);
        var nonMesh=new UnityEngine.Renderer {shared=special.shared};UnityEngine.Resources.current=new [] {nonMesh};restrictions=d.Scan(camera,-1);
        Check(restrictions.NativeDiffuseCompatible&&Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.NonMeshRenderer),"nonMeshRenderer restriction does not change old native shader eligibility");
        special.shared=new UnityEngine.Material[0];UnityEngine.Resources.current=new UnityEngine.Renderer[] {special};restrictions=d.Scan(camera,-1);
        Check(restrictions.NativeDiffuseCompatible&&restrictions.Candidates.Count==1&&Has(restrictions.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.MeshSubmeshMismatch),"empty slot array preserves old native result but cannot prove identity mapping");special.shared=good.shared;

        var fail=R(Lit);fail.throwMaterials=true;UnityEngine.Resources.current=new [] {fail,good};var failed=d.Scan(camera,-1);
        Check(!failed.ScanComplete&&failed.HasUnknownSources&&failed.Candidates.Count==2&&Has(failed.Candidates[0],HybridLumenGI.HybridLumenGIReceiverDiscovery.IdentityIssues.SourceReadFailure),"renderer read failure retains unknown and scans later receiver");
        special.filter.sharedMesh.throwTopology=true;UnityEngine.Resources.current=new UnityEngine.Renderer[] {special,good};failed=d.Scan(camera,-1);
        Check(!failed.ScanComplete&&failed.Candidates.Count==2,"mesh metadata read failure continues");special.filter.sharedMesh.throwTopology=false;
        UnityEngine.Resources.current=new [] {good};UnityEngine.Resources.throwLods=true;failed=d.Scan(camera,-1);
        Check(!failed.ScanComplete&&failed.Candidates.Count==1&&failed.HasUnknownSources,"LOD census failure preserves ordinary source row but revokes completeness");UnityEngine.Resources.throwLods=false;
        UnityEngine.Resources.throwRenderers=true;failed=d.Scan(camera,-1);Check(!failed.ScanComplete&&!failed.NativeDiffuseCompatible&&failed.HasUnknownSources,"renderer census failure cannot claim completeness");UnityEngine.Resources.throwRenderers=false;
        camera.cullingMatrix=new UnityEngine.Matrix4x4 {invalid=true};UnityEngine.Resources.current=new [] {bad,good};failed=d.Scan(camera,-1);
        Check(!failed.ScanComplete&&failed.Candidates.Count==2,"invalid culling context still scans sources conservatively");camera.cullingMatrix=default(UnityEngine.Matrix4x4);
        UnityEngine.GeometryUtility.badPlanes=true;Check(!d.Scan(camera,-1).ScanComplete,"degenerate frustum rejected");UnityEngine.GeometryUtility.badPlanes=false;
        UnityEngine.GeometryUtility.throwPlanes=true;Check(!d.Scan(camera,-1).ScanComplete,"frustum exception rejected without abandoning source traversal");UnityEngine.GeometryUtility.throwPlanes=false;

        var idA=R(Lit);var idB=R(Lit);idA.identityCode=idB.identityCode=123;
        UnityEngine.Resources.current=new [] {idA,idB,idA};var ids=d.Scan(camera,-1);
        Check(ids.ScannedRenderers==3&&ids.Candidates.Count==2&&ReferenceEquals(ids.Candidates[0].Renderer,idA)&&ReferenceEquals(ids.Candidates[1].Renderer,idB),"reference census distinguishes numeric identity collision and deduplicates same reference");
        UnityEngine.Material[] sourceSlots=idA.shared;UnityEngine.Mesh sourceMesh=idA.filter.sharedMesh;
        idA.gameObject.layer=4;idA.localToWorldMatrix=new UnityEngine.Matrix4x4 {offset=17};UnityEngine.Resources.current=new [] {idA};var noWrites=d.Scan(camera,-1);
        Check(idA.mutationCount==0&&ReferenceEquals(idA.shared,sourceSlots)&&ReferenceEquals(idA.filter.sharedMesh,sourceMesh)&&idA.gameObject.layer==4&&idA.localToWorldMatrix.offset==17&&idA.enabled&&!idA.forceRenderingOff,"scan leaves source materials, mesh, layer and transform unchanged");
        Check(noWrites.Candidates[0].HasOpaqueMaterials&&!noWrites.HasUnknownSources,"unproxied plain Lit is discoverable without GPU scene");
        Check(d.Scan(null,-1).Candidates.Count==0,"null camera yields explicit empty invalid context");
    }

    private static void RunBudgetedDiscovery() {
        var discovery = new HybridLumenGI.HybridLumenGIReceiverDiscovery();
        var qualification = new HybridLumenGI.HybridLumenGILitQualification();
        var camera = new UnityEngine.Camera();
        var first = R(Lit);
        var second = R(Lit);
        UnityEngine.Resources.current = new[] { first, second };
        UnityEngine.Resources.lods = Array.Empty<UnityEngine.LODGroup>();
        long ticks = 0;
        first.filter.sharedMesh.onTopology = () => ticks += 40;
        second.filter.sharedMesh.onTopology = () => ticks += 20;
        var allowance = new HybridLumenGI.HybridLumenGIReceiverDiscovery.ScanBudget(100, () => ticks);
        var initial = discovery.Scan(camera, -1, allowance);
        Check(initial.ScanComplete && initial.Candidates.Count == 2 && qualification.Validate(initial, out _),
            "the first discovery spends 60 ticks and qualifies both Lit sources");

        ticks += 500; // Work between discovery calls does not spend this allowance.
        int secondReads = second.materialReads;
        var partial = discovery.Scan(camera, -1, allowance);
        Check(!partial.ScanComplete && partial.HasUnknownSources && partial.ScannedRenderers == 1 &&
            partial.Candidates.Count == 1 && ReferenceEquals(partial.Candidates[0].Renderer, first) && second.materialReads == secondReads,
            "revalidation spends the remaining 40 ticks and never starts the second renderer");
        Check(!qualification.Validate(partial, out var reason) && reason.Contains("CPU allowance exhausted"),
            "actual Lit qualification rejects incomplete current sources");

        int scans = UnityEngine.Resources.scans;
        var exhausted = discovery.Scan(camera, -1, allowance);
        Check(!exhausted.ScanComplete && exhausted.ScannedRenderers == 0 && UnityEngine.Resources.scans == scans,
            "another recheck with the same exhausted allowance does not enumerate loaded objects again");
        var next = HybridLumenGI.HybridLumenGIReceiverDiscovery.ScanBudget.FromMilliseconds(60000);
        Check(next != null && discovery.Scan(camera, -1, next).ScanComplete && second.materialReads == secondReads + 1,
            "a fresh adequate real Stopwatch allowance restores full discovery");
        Check(HybridLumenGI.HybridLumenGIReceiverDiscovery.ScanBudget.FromMilliseconds(0) == null &&
            discovery.Scan(camera, -1).ScanComplete, "default zero retains the complete discovery entry");
    }
}
'@
$entry = @'
using System;
internal static class HarnessEntry
{
    private static int Main()
    {
        try { Console.WriteLine(LitQualificationCases.Run()); return 0; }
        catch (Exception error) { Console.Error.WriteLine(error); return 1; }
    }
}
'@
# Compile the complete runtime file unchanged, alongside the explicit API stubs.
& (Join-Path $PSScriptRoot "Invoke-CSharpHarness.ps1") -Name "lit-qualification" -Sources @{
    "HybridLumenGILitQualification.cs" = $actual
    "HybridLumenGIReceiverDiscovery.cs" = $discovery
    "UnityStubsAndCases.cs" = $stubs
    "Program.cs" = $entry
}
