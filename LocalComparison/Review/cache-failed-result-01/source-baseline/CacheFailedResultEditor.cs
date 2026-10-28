using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static class CacheFailedResultEditor
{
    [StructLayout(LayoutKind.Sequential)] struct Proxy {public Vector4 centerShape,extentsRoughness,albedo,emission,identity;}
    [Serializable,StructLayout(LayoutKind.Sequential)] struct Entry {public Vector4 irradiance,tag,anchor,normal,guide;}
    [StructLayout(LayoutKind.Sequential)] struct Card {public Matrix4x4 worldToCard;public Vector4 atlasRect,directionTolerance;public uint stableId,revision,generation,ready,ownerSlot,chartId,layoutGeneration,flags;}
    [StructLayout(LayoutKind.Sequential)] struct UInt4 {public uint x,y,z,w;public UInt4(uint a,uint b,uint c,uint d){x=a;y=b;z=c;w=d;}}
    [StructLayout(LayoutKind.Sequential)] struct Proposal {public Vector4 sphere,data;}
    [Serializable] class CaseInput {public string name;public Vector4 position,direct,diffuse,emission;public float weight;public Entry[] cache;}
    [Serializable] class Report {public string unity,gpu,api,error;public bool collectionComplete;public int cases,pending;public CaseInput[] inputs;}
    static string Arg(string name){var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,name);return i>=0&&i+1<args.Length?args[i+1]:"";}
    static ComputeBuffer Own(List<ComputeBuffer> owners,int count,int stride){var buffer=new ComputeBuffer(count,stride);owners.Add(buffer);return buffer;}
    public static void Run()
    {
        string directory=Arg("-cacheFailedOutput");if(string.IsNullOrEmpty(directory))throw new Exception("Missing explicit cache fixture output");
        Directory.CreateDirectory(directory);var report=new Report{unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString(),error=""};
        var inputs=new List<CaseInput>();var errors=new List<string>();
        Application.LogCallback onLog=(message,stack,type)=>{if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)errors.Add(message);};
        Application.logMessageReceived+=onLog;
        try
        {
            var shader=Resources.Load<ComputeShader>("CacheFailedResult");if(!shader||!shader.HasKernel("CSTestCacheFailedResult"))throw new Exception("Fixture kernel missing");
            int kernel=shader.FindKernel("CSTestCacheFailedResult");
            var owners=new List<ComputeBuffer>();
            try
            {
                var proxies=Own(owners,1,80);var cache=Own(owners,4,80);var cards=Own(owners,1,128);var ranges=Own(owners,1,16);
                var policies=Own(owners,1,16);var proposals=Own(owners,1,32);var output=Own(owners,1,14*16);
                proxies.SetData(new[]{new Proxy{identity=new Vector4(1,2,0,1)}});
                cards.SetData(new[]{new Card{worldToCard=Matrix4x4.identity,atlasRect=new Vector4(0,0,1,1),directionTolerance=new Vector4(0,0,1,1),stableId=1,revision=2,generation=4,ready=1,ownerSlot=0,chartId=1,layoutGeneration=7,flags=1}});
                ranges.SetData(new[]{new UInt4(0,1,7,1)});policies.SetData(new[]{new UInt4(1,1,1,1)});
                proposals.SetData(new[]{new Proposal()}); // Actual PDF reads this legal count=0 header.
                shader.SetBuffer(kernel,"_HLGI_Proxies",proxies);shader.SetBuffer(kernel,"_HLGI_CacheRead",cache);shader.SetBuffer(kernel,"_HLGI_SurfaceCards",cards);
                shader.SetBuffer(kernel,"_HLGI_SurfaceOwnerRanges",ranges);shader.SetBuffer(kernel,"_HLGI_LightingPolicies",policies);shader.SetBuffer(kernel,"_HLGI_EmissiveProposals",proposals);shader.SetBuffer(kernel,"_TestOutput",output);
                shader.SetInt("_HLGI_ProxyCount",1);shader.SetInt("_HLGI_SurfaceCardCount",1);shader.SetInt("_HLGI_CacheGrid",2);shader.SetInt("_HLGI_Epoch",3);
                shader.SetFloat("_HLGI_RayBias",.0625f);shader.SetFloat("_HLGI_BounceFeedback",1);shader.SetFloat("_HLGI_GuideWeight",.5f);shader.SetFloat("_HLGI_EmissiveWeight",0);
                string[] names={"tiny-positive","above-threshold","no-measurement","stale-identity","stale-generation","measured-black"};
                for(int index=0;index<names.Length;index++)
                {
                    float weight=index==0?1f/262144:1f/65536;
                    var row=new CaseInput{name=names[index],weight=weight,position=new Vector4((.5f+weight)/2,.25f,.5f,1),
                        direct=new Vector4(.25f,.5f,.75f,1),diffuse=new Vector4(.5f,.25f,.75f,.5f),emission=new Vector4(.125f,.25f,.5f,1),cache=new Entry[4]};
                    for(int cell=0;cell<4;cell++)row.cache[cell]=new Entry{irradiance=new Vector4(1024,512,256,2),tag=new Vector4(cell==1?1:99,2,3,4),
                        anchor=new Vector4((cell%2+.5f)/2,(cell/2+.5f)/2,.5f,0),normal=new Vector4(0,0,1,0),guide=new Vector4(1,0,0,2)};
                    if(index==2)row.cache[1].irradiance.w=0;
                    if(index==3)row.cache[1].tag.x=99;
                    if(index==4)row.cache[1].tag.w=99;
                    if(index==5){row.cache[1].irradiance=new Vector4(0,0,0,2);row.cache[1].guide=new Vector4(0,0,1,0);}
                    inputs.Add(row);cache.SetData(row.cache);shader.SetInt("_TestCase",index);shader.SetVector("_TestPosition",row.position);shader.SetVector("_TestDirect",row.direct);shader.SetVector("_TestDiffuse",row.diffuse);shader.SetVector("_TestEmission",row.emission);
                    shader.Dispatch(kernel,1,1,1);report.pending++;
                    var readback=AsyncGPUReadback.Request(output);readback.WaitForCompletion();
                    if(!readback.done)AsyncGPUReadback.WaitAllRequests();
                    if(readback.done)report.pending--;
                    if(!readback.done||readback.hasError)throw new Exception("CACHE_FAILED_RESULT_OBSERVER_FAILED: readback completion unproven");
                    var bytes=readback.GetData<byte>().ToArray();File.WriteAllBytes(Path.Combine(directory,names[index]+".bin"),bytes);
                    if(bytes.Length!=14*16)throw new Exception("CACHE_FAILED_RESULT_OBSERVER_FAILED: output size mismatch");
                    for(int offset=0;offset<bytes.Length;offset+=4){float value=BitConverter.ToSingle(bytes,offset);if(float.IsNaN(value)||float.IsInfinity(value))throw new Exception("CACHE_FAILED_RESULT_OBSERVER_FAILED: nonfinite output");}
                    report.cases++;if(errors.Count>0)throw new Exception(string.Join("\n",errors));
                }
            }
            finally
            {
                if(report.pending==0)foreach(var owner in owners)owner.Dispose();
                else Debug.LogError("CACHE_FAILED_RESULT_OBSERVER_FAILED: completion unproven; retaining buffers until process exit");
            }
            report.collectionComplete=report.cases==6&&report.pending==0&&errors.Count==0;
        }
        catch(Exception error){report.error=error.ToString();Debug.LogError("CACHE_FAILED_RESULT_OBSERVER_FAILED: "+error);}
        finally{Application.logMessageReceived-=onLog;report.inputs=inputs.ToArray();File.WriteAllText(Path.Combine(directory,"collection.json"),JsonUtility.ToJson(report,true));}
        Debug.Log("CACHE_FAILED_RESULT_COLLECTION cases="+report.cases+" complete="+report.collectionComplete+"; contract assertions are external, not implied by collection");
        EditorApplication.Exit(report.collectionComplete?0:1);
    }
}
