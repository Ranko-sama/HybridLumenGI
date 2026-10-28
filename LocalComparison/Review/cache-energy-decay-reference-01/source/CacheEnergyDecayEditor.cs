using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static class CacheEnergyDecayEditor
{
    [StructLayout(LayoutKind.Sequential)] struct Proxy {public Vector4 centerShape,extentsRoughness,albedo,emission,identity;}
    [StructLayout(LayoutKind.Sequential)] struct Entry {public Vector4 irradiance,tag,anchor,normal,guide;}
    [StructLayout(LayoutKind.Sequential)] struct Card {public Matrix4x4 worldToCard;public Vector4 atlasRect,directionTolerance;public uint stableId,revision,generation,ready,ownerSlot,chartId,layoutGeneration,flags;}
    [StructLayout(LayoutKind.Sequential)] struct UInt4 {public uint x,y,z,w;public UInt4(uint a,uint b,uint c,uint d){x=a;y=b;z=c;w=d;}}
    [StructLayout(LayoutKind.Sequential)] struct Light {public Vector4 positionType,directionRange,color,spot;public UInt4 masks;}
    [StructLayout(LayoutKind.Sequential)] struct Change {public Vector4 minimum,maximum,receiver;}
    [StructLayout(LayoutKind.Sequential)] struct Proposal {public Vector4 sphere,data;}
    [StructLayout(LayoutKind.Sequential)] struct Area {public Vector4 p0,p1,p2,rawNg;public UInt4 identity,geometry;}
    [Serializable] class Step {public int round,readBuffer,writeBuffer,changeCount;public bool sourceOn,distinctBuffers;public Vector4 sourceColor;public int[] mask;}
    [Serializable] class Report
    {
        public string unity,gpu,api,error;
        public bool collectionComplete;
        public int rounds,pending,observationStride=416,cacheStride=80,rayCount=1;
        public Vector4[] rho;
        public Step[] steps;
    }
    static string Arg(string name){var args=Environment.GetCommandLineArgs();int i=Array.IndexOf(args,name);return i>=0&&i+1<args.Length?args[i+1]:"";}
    static ComputeBuffer Own(List<ComputeBuffer> owners,int count,int stride){var b=new ComputeBuffer(count,stride);owners.Add(b);return b;}
    static void Finite(byte[] bytes){for(int i=0;i<bytes.Length;i+=4){float v=BitConverter.ToSingle(bytes,i);if(float.IsNaN(v)||float.IsInfinity(v))throw new Exception("nonfinite output");}}
    public static void Run()
    {
        string directory=Arg("-cacheEnergyOutput");if(string.IsNullOrEmpty(directory)||Directory.Exists(directory))throw new Exception("Explicit new cache energy output directory required");
        Directory.CreateDirectory(directory);
        var report=new Report{unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString(),error="",
            rho=new[]{new Vector4(.5f,.25f,.5f,1),new Vector4(.25f,.5f,.5f,1)}};
        var steps=new List<Step>();var errors=new List<string>();var owners=new List<ComputeBuffer>();
        Application.LogCallback onLog=(message,stack,type)=>{if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)errors.Add(message);};
        Application.logMessageReceived+=onLog;
        try
        {
            var shader=Resources.Load<ComputeShader>("CacheEnergyDecay");if(!shader||!shader.HasKernel("CSUpdateCache"))throw new Exception("Actual update kernel missing");
            int kernel=shader.FindKernel("CSUpdateCache");
            var proxies=Own(owners,2,80);var cache=new[]{Own(owners,2,80),Own(owners,2,80)};
            var cards=Own(owners,2,128);var ranges=Own(owners,2,16);var policies=Own(owners,2,16);
            var proposals=Own(owners,1,32);var area=Own(owners,1,96);var lights=Own(owners,1,80);var changes=Own(owners,1,48);
            var mask=Own(owners,2,4);var output=Own(owners,2,416);
            proxies.SetData(new[]{new Proxy{albedo=report.rho[0],identity=new Vector4(1,2,0,1)},new Proxy{albedo=report.rho[1],identity=new Vector4(2,2,0,1)}});
            // Both start empty. There is no later SetData/clear of either cache.
            cache[0].SetData(new Entry[2]);cache[1].SetData(new Entry[2]);
            var matrixB=Matrix4x4.identity;matrixB.m23=-2;
            cards.SetData(new[]{
                new Card{worldToCard=Matrix4x4.identity,atlasRect=new Vector4(0,0,.5f,1),directionTolerance=new Vector4(0,0,1,1),stableId=1,revision=2,generation=4,ready=1,ownerSlot=0,chartId=1,layoutGeneration=7,flags=1},
                new Card{worldToCard=matrixB,atlasRect=new Vector4(.5f,0,.5f,1),directionTolerance=new Vector4(0,0,1,1),stableId=2,revision=2,generation=5,ready=1,ownerSlot=1,chartId=2,layoutGeneration=7,flags=1}});
            ranges.SetData(new[]{new UInt4(0,1,7,1),new UInt4(1,1,7,1)});
            policies.SetData(new[]{new UInt4(1,1,1,0),new UInt4(2,2,1,0)});
            proposals.SetData(new[]{new Proposal()});area.SetData(new[]{new Area()});mask.SetData(new uint[]{1,1});
            // Lighting region (minimum.w=0), enclosing both nodes, soft history only.
            changes.SetData(new[]{new Change{minimum=new Vector4(-1,-1,-1,0),maximum=new Vector4(2,2,4,4),receiver=Vector4.zero}});
            var light=new Light{positionType=Vector4.zero,directionRange=new Vector4(0,0,1,0),spot=Vector4.zero,masks=new UInt4(1,1,1,1)};
            shader.SetBuffer(kernel,"_HLGI_Proxies",proxies);shader.SetBuffer(kernel,"_HLGI_SurfaceCards",cards);shader.SetBuffer(kernel,"_HLGI_SurfaceOwnerRanges",ranges);
            shader.SetBuffer(kernel,"_HLGI_LightingPolicies",policies);shader.SetBuffer(kernel,"_HLGI_EmissiveProposals",proposals);shader.SetBuffer(kernel,"_HLGI_AreaEmitters",area);
            shader.SetBuffer(kernel,"_HLGI_Lights",lights);shader.SetBuffer(kernel,"_HLGI_ChangeRegions",changes);shader.SetBuffer(kernel,"_HLGI_CacheUpdateMask",mask);shader.SetBuffer(kernel,"_EnergyOutput",output);
            shader.SetInt("_HLGI_ProxyCount",2);shader.SetInt("_HLGI_SurfaceCardCount",2);shader.SetInt("_HLGI_CacheGrid",1);shader.SetInt("_HLGI_CacheRays",1);shader.SetInt("_HLGI_Epoch",3);
            shader.SetInt("_HLGI_LightCount",1);shader.SetInt("_HLGI_AreaEmitterCount",0);shader.SetInt("_HLGI_AreaMaterialGeneration",1);
            shader.SetFloat("_HLGI_GuideWeight",0);shader.SetFloat("_HLGI_EmissiveWeight",0);shader.SetFloat("_HLGI_BounceFeedback",1);shader.SetVector("_HLGI_Environment",Vector4.zero);
            shader.SetFloat("_HLGI_RayBias",.0625f);shader.SetFloat("_HLGI_MaxDistance",10);shader.SetFloat("_HLGI_ShadowDistance",10);
            shader.SetFloat("_HLGI_GlobalReactive",0);shader.SetFloat("_HLGI_GlobalGeometryChange",0);shader.SetVector("_HLGI_SurfaceAtlasSize",new Vector4(8,4,.125f,.25f));
            using(var observationFile=new FileStream(Path.Combine(directory,"observations.bin"),FileMode.CreateNew))
            using(var cacheFile=new FileStream(Path.Combine(directory,"cache.bin"),FileMode.CreateNew))
            {
                for(int round=0;round<512;round++)
                {
                    int read=round%2,write=1-read;
                    var step=new Step{round=round,readBuffer=read,writeBuffer=write,distinctBuffers=!ReferenceEquals(cache[read],cache[write]),
                        sourceOn=round<256,sourceColor=round<256?new Vector4(1,.5f,.25f,0):Vector4.zero,changeCount=round==256?1:0,mask=new[]{1,1}};
                    if(!step.distinctBuffers)throw new Exception("Jacobi buffers alias");steps.Add(step);
                    light.color=step.sourceColor;lights.SetData(new[]{light});shader.SetInt("_HLGI_ChangeCount",step.changeCount);
                    shader.SetInt("_HLGI_FrameIndex",round);shader.SetInt("_ReadIdentity",read);shader.SetInt("_WriteIdentity",write);
                    shader.SetBuffer(kernel,"_HLGI_CacheRead",cache[read]);shader.SetBuffer(kernel,"_HLGI_CacheWrite",cache[write]);
                    // Mark both completions unproven BEFORE submission/request:
                    // even a throwing Dispatch/Request must retain GPU ownership.
                    report.pending+=2;
                    shader.Dispatch(kernel,1,1,1);
                    var observation=AsyncGPUReadback.Request(output);
                    var values=AsyncGPUReadback.Request(cache[write]);
                    observation.WaitForCompletion();values.WaitForCompletion();
                    if(!observation.done||!values.done)AsyncGPUReadback.WaitAllRequests();
                    if(observation.done)report.pending--;if(values.done)report.pending--;
                    if(!observation.done||!values.done||observation.hasError||values.hasError)throw new Exception("readback completion unproven");
                    var obsBytes=observation.GetData<byte>().ToArray();var cacheBytes=values.GetData<byte>().ToArray();
                    observationFile.Write(obsBytes,0,obsBytes.Length);cacheFile.Write(cacheBytes,0,cacheBytes.Length);
                    observationFile.Flush();cacheFile.Flush();
                    if(obsBytes.Length!=832||cacheBytes.Length!=160)throw new Exception("readback size mismatch");Finite(obsBytes);Finite(cacheBytes);
                    for(int node=0;node<2;node++)
                    {
                        int start=node*416;
                        // Required target execution and known-measurement flags; numerical oracle is external.
                        for(int field=0;field<4;field++)if(BitConverter.ToSingle(obsBytes,start+21*16+field*4)!=1)throw new Exception("update/measurement/mask/patch execution mismatch at round "+round);
                        if(BitConverter.ToSingle(obsBytes,start+25*16+12)!=0)throw new Exception("reference environment adapter rejected a ray at round "+round);
                    }
                    report.rounds++;if(errors.Count>0)throw new Exception(string.Join("\n",errors));
                }
            }
            report.collectionComplete=report.rounds==512&&report.pending==0&&errors.Count==0;
        }
        catch(Exception error){report.error=error.ToString();Debug.LogError("CACHE_ENERGY_OBSERVER_FAILED: "+error);}
        finally
        {
            if(report.pending==0)foreach(var owner in owners)owner.Dispose();
            else Debug.LogError("CACHE_ENERGY_OBSERVER_FAILED: completion unproven; retaining buffers until process exit");
            Application.logMessageReceived-=onLog;report.steps=steps.ToArray();File.WriteAllText(Path.Combine(directory,"collection.json"),JsonUtility.ToJson(report,true));
        }
        Debug.Log("CACHE_ENERGY_COLLECTION rounds="+report.rounds+" complete="+report.collectionComplete+"; independent energy assertions not implied");
        EditorApplication.Exit(report.collectionComplete?0:1);
    }
}
