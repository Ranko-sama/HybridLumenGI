"""Small CPU controls for the source loader and geometry/coordinate interface."""
import json
import pathlib
import tempfile
import unittest
import numpy as np
from loader import load, digest, InputError
from geometry import Camera, Scene, render_primary, trace, RECEIVER, SKY, BOUNDARY, UNSUPPORTED


def camera():
    n, f = .1, 10.
    return dict(matrixOrder="row-major", rowOrder="top-to-bottom", uvOrigin="top-left",
                clipDepth="zero-to-one", pixelCenter="half-integer", reversedZ=True,
                view=np.eye(4).reshape(-1).tolist(), projection=[1,0,0,0, 0,-1,0,0, 0,0,n/(f-n),n*f/(f-n), 0,0,-1,0],
                viewport=[0,0,16,16], jitter=[0,0])


def material(key, st=(1,1,0,0)):
    return dict(key=key, shader="Universal Render Pipeline/Lit", renderQueue=2000, keywords=[],
                passes=["ForwardLit","DepthOnly","DepthNormals"],passEnabled=[True,True,True],properties=[
        dict(name="_Cull",value=[2]), dict(name="_Surface",value=[0]),dict(name="_AlphaClip",value=[0]),
        dict(name="_BaseMap",textureScaleOffset=list(st))])


def geometry():
    v=[(-2,-2,0),(2,-2,0),(2,2,0),(-2,-2,0),(2,2,0),(-2,2,0)]
    return dict(key="scene/quad",name="quad",rendererType="UnityEngine.MeshRenderer",enabled=True,active=True,
                forceRenderingOff=False,staticBatch=False,layer=0,
                localToWorld=[1,0,0,0,0,1,0,0,0,0,1,-2,0,0,0,1],materialKeys=["m0","m1"],
                mesh=dict(vertices=[dict(zip("xyz",x)) for x in v],normals=[dict(x=0,y=0,z=1)]*6,
                          uv=[dict(channel=0,values=[dict(x=x,y=y,z=0,w=0) for x,y in [(0,0),(1,0),(1,1),(0,0),(1,1),(0,1)]])],
                          submeshes=[dict(topology="Triangles",baseVertex=0,indices=[0,1,2]),dict(topology="Triangles",baseVertex=3,indices=[0,1,2])]))


def snapshot():
    return dict(geometry=[geometry()],materials=[material("m0"),material("m1",(2,3,.1,.2))],lights=[],
                environment={},rendering=dict(cameraCullingMask=-1,urp=dict(renderer=[dict(name="renderingMode",value="Forward"),dict(name="opaqueLayerMask",value="-1")],otherActiveFeatures=[])),assets=[],unsupported=[])


class Tests(unittest.TestCase):
    def test_gpu_projection_and_roundtrip(self):
        c=Camera(camera());uv=np.array([[.5,.75],[.25,.25]])
        a,b,length=c.rays(uv)
        self.assertGreater(b[0,1],0)  # actual GPU negative m11: world up is lower raw row
        p=a+b*2
        projected,_,_=c.project(p)
        np.testing.assert_allclose(projected,uv,atol=3e-15,rtol=0)
        self.assertGreater(np.max(np.abs(projected[:,1]-(1-uv[:,1]))),.4)

    def test_grid_exact_representative(self):
        c=Camera(camera());pixels,uv=c.uv_for_grid(8,8)
        np.testing.assert_array_equal(pixels[:8,0],np.arange(1,16,2))
        self.assertEqual(uv[0,0],1.5/16)
        desc=camera();desc["rowOrder"]="bottom-to-top"
        other=Camera(desc);_,u=other.uv_for_grid(16,16)
        self.assertEqual(u[0,1],15.5/16)

    def test_submesh_basevertex_transform_uv_and_boundary(self):
        scene=Scene(snapshot()); c=Camera(camera());r=render_primary(scene,c,16,16)
        self.assertEqual(len(scene.records),2)
        self.assertEqual(scene.records[1]["materialKey"],"m1")
        self.assertTrue(np.any(r["classification"]==RECEIVER));self.assertTrue(np.any(r["classification"]==BOUNDARY))
        hit=r["triangle"]>=0
        np.testing.assert_allclose(r["position"][hit,2],-2,atol=1e-14)
        m1=r["triangle"]==1
        np.testing.assert_allclose(r["baseUV"][m1],r["uv0"][m1]*[2,3]+[.1,.2],atol=1e-14)

    def test_culling_and_sky(self):
        s=snapshot();s["geometry"][0]["enabled"]=False
        r=render_primary(Scene(s),Camera(camera()),16,16)
        self.assertTrue(np.all(r["classification"]==SKY))
        scene=Scene(snapshot());scene.culls[:]=1
        origin=np.array([[.3,0,-.1]]);direction=np.array([[0,0,-1.]])
        ids,*_=trace(scene,origin,direction,np.array([10.]))
        self.assertEqual(ids[0],-1)

    def test_unsupported_not_discarded(self):
        s=snapshot();s["materials"][0]["shader"]="Unmodeled/VertexDisplacement"
        r=render_primary(Scene(s),Camera(camera()),16,16)
        self.assertTrue(np.all(r["classification"]==UNSUPPORTED))
        s=snapshot();s["materials"][0]["passEnabled"][0]=False
        self.assertTrue(Scene(s).unsupported)

    def test_loader_hash_paths_and_no_candidate_access(self):
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d); (p/"physical.bin").write_bytes(b"source")
            source=snapshot();source.update(schema="hlgi-validation-source-v2",sceneId="scene",coordinateSystem="Unity-left-handed-y-up",lengthUnit="metre")
            source["assets"]=[dict(path="physical.bin",sha256=digest(b"source"),role="mesh",bytes=6)]
            sb=json.dumps(source).encode();(p/"source.json").write_bytes(sb)
            state=dict(schema="hlgi-validation-frame-state-v2",sourceSha256=digest(sb),logicalFrame=0,camera=camera(),dynamicState=snapshot(),unsupported=[])
            (p/"state.json").write_text(json.dumps(state));(p/"candidate.rgba32f").write_bytes(b"must-not-read")
            loaded=load(p/"source.json",p/"state.json")
            self.assertEqual({x["relative"] for x in loaded["accesses"]},{"source.json","state.json","physical.bin"})
            (p/"physical.bin").write_bytes(b"tamper")
            with self.assertRaises(InputError):load(p/"source.json",p/"state.json")
            source["assets"][0]["path"]="../escape";sb=json.dumps(source).encode();(p/"source.json").write_bytes(sb)
            state["sourceSha256"]=digest(sb);(p/"state.json").write_text(json.dumps(state))
            with self.assertRaises(InputError):load(p/"source.json",p/"state.json")


if __name__ == "__main__":unittest.main()
