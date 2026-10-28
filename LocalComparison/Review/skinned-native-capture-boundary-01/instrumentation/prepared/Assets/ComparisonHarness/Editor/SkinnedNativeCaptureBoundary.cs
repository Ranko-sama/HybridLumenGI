// One Editor batch, three native captures. No scene assets, Play mode or GI rendering.
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;
using HybridLumenGI;
public static class SkinnedNativeCaptureBoundary
{
    const float Epsilon=1e-6f;
    static readonly Vector3[] Positions={new Vector3(-.5f,0,0),new Vector3(.5f,0,0),new Vector3(-.5f,1,0),new Vector3(.5f,1,0)};
    static readonly Vector2[] Uvs={new Vector2(0,0),new Vector2(1,0),new Vector2(0,1),new Vector2(1,1)};
    static readonly int[] Indices={0,1,2,2,1,3};
    [Serializable] class Input
    {
        public Vector3[] positions=Positions;public Vector2[] uv=Uvs;public int[] indices=Indices,bonePerVertex={0,0,1,1};
        public float weightPerVertex=1,absolutePositionError=Epsilon;public Vector3 normal=Vector3.forward,translation=new Vector3(.25f,0,0),rendererScale=Vector3.one;
        public Vector4 tangent=new Vector4(1,0,0,1);public string transform="unit renderer and initial bone transforms/bindposes",topology="Triangles",fingerprintSourceSha256;
    }
    [Serializable] class Attribute {public string attribute,format;public int dimension,stream;}
    [Serializable] class Blob {public string file,sha256;public int bytes,stride;}
    [Serializable] class Submesh {public int indexStart,indexCount,baseVertex,firstVertex,vertexCount;public string topology;public Vector3 center,size;}
    [Serializable] class Weight {public int boneIndex;public float weight;}
    [Serializable] class Capture
    {
        public string name,fingerprint,indexFormat;public bool readable,qualified;public int vertexCount,blendShapeCount;
        public Vector3[] positions,normals;public Vector4[] tangents;public Vector2[] uv;public int[] indices,bonesPerVertex;
        public Matrix4x4[] bindposes;public Weight[] boneWeights;public Vector3 boundsCenter,boundsSize;
        public Attribute[] attributes;public Blob[] streams;public Blob index;public Submesh[] submeshes;
        public float maximumPositionError=-1,maximumNormalError=-1,maximumTangentError=-1,maximumUvError=-1;
    }
    [Serializable] class Result
    {
        public string status="started",error,unity,api,fingerprintSourceSha256,sourceFingerprintBefore,sourceFingerprintAfter,loadedAssemblySha256;
        public bool batchMode,samePoseFingerprintEqual,changedPoseFingerprintDifferent,cleanupCompleted;
        public bool candidateComponentNativeExecution=false,fullProductionAccepted=false;public int captures;public Capture[] samples;
    }
    static void Require(bool pass,string why){if(!pass)throw new InvalidOperationException(why);}
    static bool Finite(float x)=>!float.IsNaN(x)&&!float.IsInfinity(x);
    static void CheckFinite(Vector3 p){Require(Finite(p.x)&&Finite(p.y)&&Finite(p.z),"Nonfinite native data");}
    static float Error(Vector3 a,Vector3 b){CheckFinite(a);CheckFinite(b);return Mathf.Max(Mathf.Abs(a.x-b.x),Mathf.Max(Mathf.Abs(a.y-b.y),Mathf.Abs(a.z-b.z)));}
    static string Hash(byte[] bytes){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    static Blob WriteBlob(string folder,string name,Unity.Collections.NativeArray<byte> data,int stride)
    {
        byte[] bytes=new byte[data.Length];for(int i=0;i<bytes.Length;i++)bytes[i]=data[i];
        File.WriteAllBytes(Path.Combine(folder,name),bytes);return new Blob{file=name,bytes=bytes.Length,stride=stride,sha256=Hash(bytes)};
    }
    static Capture ReadCapture(string folder,string name,Mesh mesh)
    {
        var r=new Capture{name=name,readable=mesh.isReadable,vertexCount=mesh.vertexCount,positions=mesh.vertices,normals=mesh.normals,
            tangents=mesh.tangents,uv=mesh.uv,indices=mesh.triangles,indexFormat=mesh.indexFormat.ToString(),boundsCenter=mesh.bounds.center,boundsSize=mesh.bounds.size,
            bindposes=mesh.bindposes,blendShapeCount=mesh.blendShapeCount};
        r.fingerprint=HybridLumenGISurfaceCharts.ComputeContentFingerprint(mesh);
        r.attributes=mesh.GetVertexAttributes().Select(a=>new Attribute{attribute=a.attribute.ToString(),format=a.format.ToString(),dimension=a.dimension,stream=a.stream}).ToArray();
        using(var snapshot=Mesh.AcquireReadOnlyMeshData(mesh))
        {
            var data=snapshot[0];r.streams=new Blob[data.vertexBufferCount];r.submeshes=new Submesh[data.subMeshCount];
            for(int i=0;i<r.streams.Length;i++)r.streams[i]=WriteBlob(folder,name+"-stream-"+i+".bin",data.GetVertexData<byte>(i),mesh.GetVertexBufferStride(i));
            r.index=WriteBlob(folder,name+"-indices.bin",data.GetIndexData<byte>(),mesh.indexFormat==IndexFormat.UInt16?2:4);
            for(int i=0;i<r.submeshes.Length;i++){var s=data.GetSubMesh(i);r.submeshes[i]=new Submesh{indexStart=s.indexStart,indexCount=s.indexCount,baseVertex=s.baseVertex,
                firstVertex=s.firstVertex,vertexCount=s.vertexCount,topology=s.topology.ToString(),center=s.bounds.center,size=s.bounds.size};}
        }
        var counts=mesh.GetBonesPerVertex();r.bonesPerVertex=new int[counts.Length];for(int i=0;i<counts.Length;i++)r.bonesPerVertex[i]=counts[i];
        var weights=mesh.GetAllBoneWeights();r.boneWeights=new Weight[weights.Length];for(int i=0;i<weights.Length;i++)r.boneWeights[i]=new Weight{boneIndex=weights[i].boneIndex,weight=weights[i].weight};
        // Mesh-owned bone arrays are borrowed, as in the production fingerprint method.
        File.WriteAllText(Path.Combine(folder,name+"-capture.json"),JsonUtility.ToJson(r,true));return r;
    }
    static void Qualify(Capture r,bool moved)
    {
        Require(r.readable&&r.vertexCount==4&&r.positions.Length==4&&r.normals.Length==4&&r.tangents.Length==4&&r.uv.Length==4,"Native capture count/attribute/readability mismatch");
        Require(r.indices.SequenceEqual(Indices)&&r.submeshes.Length==1&&r.submeshes[0].topology=="Triangles","Native indices/topology changed");
        Require(r.attributes.Length>0&&r.streams.Length>0&&r.streams.All(s=>s.bytes>0)&&r.index.bytes>0,"Empty native raw data");
        CheckFinite(r.boundsCenter);CheckFinite(r.boundsSize);
        foreach(var sub in r.submeshes){CheckFinite(sub.center);CheckFinite(sub.size);}
        foreach(var matrix in r.bindposes)for(int i=0;i<16;i++)Require(Finite(matrix[i]),"Nonfinite bindpose");
        foreach(var weight in r.boneWeights)Require(Finite(weight.weight),"Nonfinite bone weight");
        r.maximumPositionError=r.maximumNormalError=r.maximumTangentError=r.maximumUvError=0;
        for(int i=0;i<4;i++)
        {
            Vector3 expected=Positions[i]+(moved&&i>=2?new Vector3(.25f,0,0):Vector3.zero);
            r.maximumPositionError=Mathf.Max(r.maximumPositionError,Error(r.positions[i],expected));
            r.maximumNormalError=Mathf.Max(r.maximumNormalError,Error(r.normals[i],Vector3.forward));
            var t=r.tangents[i];Require(Finite(t.w),"Nonfinite tangent w");
            r.maximumTangentError=Mathf.Max(r.maximumTangentError,Mathf.Max(Error(new Vector3(t.x,t.y,t.z),Vector3.right),Mathf.Abs(t.w-1)));
            var uv=r.uv[i];Require(Finite(uv.x)&&Finite(uv.y),"Nonfinite UV");
            r.maximumUvError=Mathf.Max(r.maximumUvError,Mathf.Max(Mathf.Abs(uv.x-Uvs[i].x),Mathf.Abs(uv.y-Uvs[i].y)));
        }
        Require(r.maximumPositionError<=Epsilon&&r.maximumNormalError<=Epsilon&&r.maximumTangentError<=Epsilon&&r.maximumUvError<=Epsilon,"Native geometry/unchanged attribute error exceeds predeclared1e-6");
        r.qualified=true;
    }
    public static void Run()
    {
        var args=Environment.GetCommandLineArgs();int arg=Array.IndexOf(args,"-skinnedNativeOutput");
        Require(arg>=0&&arg+1<args.Length,"New native output directory required");string folder=args[arg+1];
        Require(Path.IsPathRooted(folder)&&!Directory.Exists(folder),"Native output must be a new absolute directory");Directory.CreateDirectory(folder);
        var result=new Result{unity=Application.unityVersion,api=SystemInfo.graphicsDeviceType.ToString(),batchMode=Application.isBatchMode};
        var objects=new List<GameObject>();var meshes=new List<Mesh>();var samples=new List<Capture>();Scene preview=default;
        try
        {
            Require(Application.isEditor&&Application.isBatchMode&&!Application.isPlaying,"Editor-only batch required");
            result.fingerprintSourceSha256=Hash(File.ReadAllBytes(Path.Combine(Application.dataPath,"HybridLumenGI/Runtime/HybridLumenGISurfaceCharts.cs")));
            result.loadedAssemblySha256=Hash(File.ReadAllBytes(typeof(HybridLumenGISurfaceCharts).Assembly.Location));
            File.WriteAllText(Path.Combine(folder,"declared-input.json"),JsonUtility.ToJson(new Input{fingerprintSourceSha256=result.fingerprintSourceSha256},true));
            preview=EditorSceneManager.NewPreviewScene();
            GameObject NewObject(string name){var go=new GameObject(name);objects.Add(go);SceneManager.MoveGameObjectToScene(go,preview);return go;}
            Mesh NewMesh(string name){var mesh=new Mesh{name=name,indexFormat=IndexFormat.UInt16};meshes.Add(mesh);return mesh;}
            var rig=NewObject("Native skin capture boundary");var renderer=rig.AddComponent<SkinnedMeshRenderer>();
            var lower=NewObject("Lower bone").transform;lower.SetParent(rig.transform,false);
            var upper=NewObject("Upper bone").transform;upper.SetParent(lower,false);
            var source=NewMesh("Declared source");source.vertices=Positions;source.normals=Enumerable.Repeat(Vector3.forward,4).ToArray();
            source.tangents=Enumerable.Repeat(new Vector4(1,0,0,1),4).ToArray();source.uv=Uvs;source.subMeshCount=1;
            source.SetIndices(Indices,MeshTopology.Triangles,0,false);source.bounds=new Bounds(new Vector3(0,.5f,0),new Vector3(1,1,0));
            source.bindposes=new[]{lower.worldToLocalMatrix*renderer.localToWorldMatrix,upper.worldToLocalMatrix*renderer.localToWorldMatrix};
            source.boneWeights=Enumerable.Range(0,4).Select(i=>new BoneWeight{boneIndex0=i>=2?1:0,weight0=1}).ToArray();
            renderer.bones=new[]{lower,upper};renderer.rootBone=lower;renderer.sharedMesh=source;renderer.quality=SkinQuality.Bone1;renderer.updateWhenOffscreen=true;
            renderer.localBounds=new Bounds(new Vector3(0,.5f,0),new Vector3(2,2,1));
            Require(renderer.localToWorldMatrix==Matrix4x4.identity&&source.bindposes.All(x=>x==Matrix4x4.identity),"Declared unit transform/bindposes changed");
            result.sourceFingerprintBefore=HybridLumenGISurfaceCharts.ComputeContentFingerprint(source);
            foreach(string name in new[]{"A1","A2","B"})
            {
                if(name=="B")upper.localPosition=new Vector3(.25f,0,0);
                var destination=NewMesh(name);renderer.BakeMesh(destination,false);result.captures++;
                var sample=ReadCapture(folder,name,destination);samples.Add(sample);
            }
            // All three raw captures already exist before qualification; never normalize output.
            foreach(var sample in samples)Qualify(sample,sample.name=="B");
            result.sourceFingerprintAfter=HybridLumenGISurfaceCharts.ComputeContentFingerprint(source);
            Require(result.sourceFingerprintBefore==result.sourceFingerprintAfter,"Source mesh changed between captures");
            result.samePoseFingerprintEqual=samples[0].fingerprint==samples[1].fingerprint;
            result.changedPoseFingerprintDifferent=samples[0].fingerprint!=samples[2].fingerprint;
            Require(result.samePoseFingerprintEqual&&result.changedPoseFingerprintDifferent,"Native full-fingerprint premise failed");
            result.status="finite-native-capture-premise-established";
        }
        catch(Exception e){result.status="failed";result.error=e.ToString();}
        finally
        {
            try
            {
                foreach(var go in objects)if(go)UnityEngine.Object.DestroyImmediate(go);
                foreach(var mesh in meshes)if(mesh)UnityEngine.Object.DestroyImmediate(mesh);
                if(preview.IsValid())EditorSceneManager.ClosePreviewScene(preview);result.cleanupCompleted=true;
            }
            catch(Exception e){result.status="failed";result.error=(result.error??"")+"\nPrivate cleanup: "+e;}
            result.samples=samples.ToArray();File.WriteAllText(Path.Combine(folder,"native-result.json"),JsonUtility.ToJson(result,true));
        }
        if(result.status!="finite-native-capture-premise-established")throw new InvalidOperationException(result.error);
        Debug.Log("SKINNED_NATIVE_CAPTURE_BOUNDARY_COMPLETED "+folder);
    }
}
