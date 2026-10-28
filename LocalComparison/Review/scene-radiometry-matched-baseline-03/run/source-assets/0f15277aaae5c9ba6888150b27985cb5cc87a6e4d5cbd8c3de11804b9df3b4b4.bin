using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using HybridLumenGI;

public static class GatherCacheEditor
{
    [Serializable] class MaterialRow {public int submesh,cull;public string name,shader,baseTexture,topology;public bool alphaKeyword,propertyBlock;public float alphaClip,surface,cutoff,baseAlpha;public int[] indices;}
    [Serializable] class MeshRow {public string name,rendererType,mesh;public Matrix4x4 localToWorld,normalToWorld;public Vector3[] vertices;public MaterialRow[] submeshes;}
    [Serializable] class Geometry {public string purpose="Independent ordinary visibility; original triangle mesh and Cull/alpha support, not shadow-caster policy";public MeshRow[] meshes;}
    static string Arg(string key){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,key);return i>=0&&i+1<a.Length?a[i+1]:"";}
    static float Get(Material m,string n,float fallback)=>m.HasProperty(n)?m.GetFloat(n):fallback;
    public static void Play()
    {
        if(Arg("-thinWallConfig")!="A")throw new Exception("Gather package freezes configuration A");
        ThinWallEditor.Prepare();
        var rows=UnityEngine.Object.FindObjectsByType<HybridLumenGIProxy>(FindObjectsSortMode.InstanceID).Select(proxy=>{
            var renderer=proxy.SourceRenderer;var filter=renderer.GetComponent<MeshFilter>();var mesh=filter?filter.sharedMesh:null;
            if(!mesh)throw new Exception("Independent geometry snapshot requires a readable static mesh: "+proxy.name);
            var mats=renderer.sharedMaterials;
            return new MeshRow{name=proxy.name,rendererType=renderer.GetType().Name,mesh=mesh.name,localToWorld=renderer.localToWorldMatrix,
                normalToWorld=renderer.localToWorldMatrix.inverse.transpose,vertices=mesh.vertices,
                submeshes=Enumerable.Range(0,mesh.subMeshCount).Select(i=>{
                    var m=mats[Math.Min(i,mats.Length-1)];return new MaterialRow{submesh=i,name=m.name,shader=m.shader.name,cull=(int)Get(m,"_Cull",2),
                        alphaKeyword=m.IsKeywordEnabled("_ALPHATEST_ON"),propertyBlock=renderer.HasPropertyBlock(),alphaClip=Get(m,"_AlphaClip",0),surface=Get(m,"_Surface",0),cutoff=Get(m,"_Cutoff",.5f),
                        baseAlpha=m.HasProperty("_BaseColor")?m.GetColor("_BaseColor").a:1,baseTexture=m.HasProperty("_BaseMap")&&m.GetTexture("_BaseMap")?m.GetTexture("_BaseMap").name:"none",
                        topology=mesh.GetTopology(i).ToString(),indices=mesh.GetIndices(i)};
                }).ToArray()};
        }).ToArray();
        File.WriteAllText(Path.Combine(Arg("-comparisonOutput"),"gather-geometry.json"),JsonUtility.ToJson(new Geometry{meshes=rows},true));
        Debug.Log("GATHER_CACHE_PREPARED A / fixed pixels / nine samples / maximum 120 logical frames");
        EditorApplication.EnterPlaymode();
    }
}
