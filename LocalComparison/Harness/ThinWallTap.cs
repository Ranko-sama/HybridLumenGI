// Test-project-only stage/readback observer. No product parameter or resource-state writes.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using HybridLumenGI;

public static class ThinWallTap
{
    static readonly bool requested=Array.IndexOf(Environment.GetCommandLineArgs(),"-thinWallProbe")>=0;
    public static bool Enabled=>requested&&!finished;
    static readonly int[] Samples={0,1,3,7,15,31,63,95,119};
    static readonly string[] Stages={"raw","geometry","material","depth","diffuse","emission","history","moments","filtered","native","lights-packed","scene-packed","policy-packed","cache"};
    static readonly HashSet<string> completed=new HashSet<string>();
    static readonly HashSet<int> unavailable=new HashSet<int>();
    static readonly object gate=new object();
    static ComparisonCapture capture;static GraphicsBuffer queries,depthValues;static int pending,errors,skippedQueries;static bool finished;
    const BindingFlags Fields=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static object Field(object value,string name)=>value.GetType().GetField(name,Fields).GetValue(value);
    [Serializable] class Receipt {public int logicalFrame,giFrame,engineFrame,width,height,channels,bytes;public string stage,actualFormat;}
    [Serializable] class Owner {public int slot,stableId,revision;public string name;public bool published,ready;public Vector3 center,size;}
    [Serializable] class Sources {public int logicalFrame,giFrame,engineFrame,lightCount,cacheEntries;public Matrix4x4 invVP;public Owner[] owners;public HybridLumenGIRendererFeature.CameraDiagnostics diagnostics;}
    [Serializable] class Summary {public int expectedSamples=9,completedFiles,pending,errors,skippedQueries;public bool passed,stageCollectionComplete,queryCoverageComplete;public string[] missingStages,missingQueries;public string cReferenceCheck="external analysis required; not certified by collection",scope="Stage copies/receiver probes only; not a whole-image reference or performance capture";}
    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    struct QuerySeed {public Vector4 a,b,c,d,e,f,g,h,i,j;}
    public static bool Wants(int frame)=>Enabled&&Array.IndexOf(Samples,frame)>=0;
    static bool Target(Camera camera,out int logical,out string directory)
    {
        logical=-1;directory=null;if(!Enabled)return false;
        if(!capture)capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        if(!capture||capture.camera!=camera)return false;
        logical=(int)Field(capture,"logicalFrame");directory=(string)Field(capture,"directory");return Wants(logical)&&!string.IsNullOrEmpty(directory);
    }
    public static GraphicsBuffer QueryBuffer
    {
        get{if(!Enabled)throw new InvalidOperationException("Thin-wall query admission closed");if(queries==null){queries=new GraphicsBuffer(GraphicsBuffer.Target.Structured,6,160);queries.SetData(new QuerySeed[6]);}return queries;}
    }
    public static GraphicsBuffer DepthBuffer
    {
        get{if(!Enabled)throw new InvalidOperationException("Thin-wall depth admission closed");if(depthValues==null){depthValues=new GraphicsBuffer(GraphicsBuffer.Target.Structured,640*360+1,4);depthValues.SetData(Enumerable.Repeat(float.NaN,640*360+1).ToArray());}return depthValues;}
    }
    static void Save(string directory,Receipt receipt,byte[] bytes)
    {
        string key=receipt.logicalFrame.ToString("D4")+"-"+receipt.stage;receipt.bytes=bytes.Length;
        lock(gate)
        {
            if(!completed.Add(key))throw new Exception("Duplicate thin-wall stage: "+key);
            File.WriteAllBytes(Path.Combine(directory,"thin-"+key+".bin"),bytes);
            File.AppendAllText(Path.Combine(directory,"thin-receipts.jsonl"),JsonUtility.ToJson(receipt)+"\n");
        }
    }
    public static void Texture(CommandBuffer cmd,RenderTexture texture,Camera camera,int giFrame,string stage,bool scalar=false)
    {
        if(!Target(camera,out int frame,out string directory))return;
        if(!texture)throw new Exception("Missing thin-wall source texture: "+stage);
        if(scalar){Depth(cmd,texture,camera,giFrame);return;}
        var receipt=new Receipt{logicalFrame=frame,giFrame=giFrame,engineFrame=Time.frameCount,width=texture.width,height=texture.height,
            channels=scalar?1:4,stage=stage,actualFormat=texture.graphicsFormat.ToString()};
        pending++;
        cmd.RequestAsyncReadback(texture,0,scalar?TextureFormat.RFloat:TextureFormat.RGBAFloat,request=>
        {
            try
            {
                if(request.hasError)throw new Exception("Thin-wall stage readback failed: "+stage);
                var data=request.GetData<float>();if(data.Length!=receipt.width*receipt.height*receipt.channels)throw new Exception("Thin-wall stage size changed");
                for(int i=0;i<data.Length;i++)if(float.IsNaN(data[i])||float.IsInfinity(data[i]))throw new Exception("Nonfinite thin-wall stage: "+stage);
                Save(directory,receipt,request.GetData<byte>().ToArray());
            }
            catch(Exception error){errors++;Debug.LogError(error);}
            finally{pending--;}
        });
    }
    static void Depth(CommandBuffer cmd,RenderTexture texture,Camera camera,int giFrame)
    {
        if(!Target(camera,out int frame,out string directory))return;
        if(texture.width!=640||texture.height!=360)throw new Exception("Thin-wall depth dimensions differ from fixed contract");
        var shader=Resources.Load<ComputeShader>("ThinWallDepthCopy");if(!shader)throw new Exception("Missing depth copy shader");
        int kernel=shader.FindKernel("CopyDepth");cmd.SetComputeIntParams(shader,"_Size",640,360);
        cmd.SetComputeFloatParam(shader,"_FrameStamp",giFrame+100001);
        cmd.SetComputeTextureParam(shader,kernel,"_Source",texture,0,RenderTextureSubElement.Depth);cmd.SetComputeBufferParam(shader,kernel,"_DepthValues",DepthBuffer);
        cmd.DispatchCompute(shader,kernel,80,45,1);
        var receipt=new Receipt{logicalFrame=frame,giFrame=giFrame,engineFrame=Time.frameCount,width=640,height=360,channels=1,stage="depth",actualFormat=texture.graphicsFormat+" sampled by Load into float32 buffer"};
        pending++;cmd.RequestAsyncReadback(DepthBuffer,request=>
        {
            try
            {
                if(request.hasError)throw new Exception("Thin-wall copied-depth readback failed");
                var values=request.GetData<float>();if(values.Length!=640*360+1||values[640*360]!=giFrame+100001)throw new Exception("Copied-depth size/write stamp mismatch");
                float minimum=1,maximum=0;
                for(int i=0;i<640*360;i++){if(float.IsNaN(values[i])||float.IsInfinity(values[i])||values[i]<0||values[i]>1)throw new Exception("Invalid copied raw depth");minimum=Mathf.Min(minimum,values[i]);maximum=Mathf.Max(maximum,values[i]);}
                if(maximum<=minimum)throw new Exception("Copied depth is uniform; receiver coverage unproven");
                Save(directory,receipt,request.GetData<byte>().GetSubArray(0,640*360*4).ToArray());
            }
            catch(Exception error){errors++;Debug.LogError(error);}
            finally{pending--;}
        });
    }
    static void Buffer(CommandBuffer cmd,ComputeBuffer buffer,Camera camera,int giFrame,string stage,int activeCount=-1)
    {
        if(!Target(camera,out int frame,out string directory))return;
        var receipt=new Receipt{logicalFrame=frame,giFrame=giFrame,engineFrame=Time.frameCount,width=buffer.count,height=1,channels=buffer.stride/4,stage=stage,actualFormat="structured bytes"};
        int stride=buffer.stride,count=buffer.count,validCount=activeCount<0?count:activeCount;
        int expectedStride=stage=="policy-packed"?16:80;
        if(stride!=expectedStride||validCount<0||validCount>count)throw new Exception("Thin-wall buffer layout mismatch: "+stage);
        pending++;cmd.RequestAsyncReadback(buffer,request=>
        {try{
            if(request.hasError)throw new Exception("Thin-wall buffer readback failed: "+stage);
            byte[] bytes=request.GetData<byte>().ToArray();if(bytes.Length!=count*stride)throw new Exception("Thin-wall buffer size mismatch: "+stage);
            int floatBytes=stage=="policy-packed"?0:stage=="lights-packed"?64:80;
            for(int record=0;record<validCount;record++)for(int offset=0;offset<floatBytes;offset+=4){float value=BitConverter.ToSingle(bytes,record*stride+offset);if(float.IsNaN(value)||float.IsInfinity(value))throw new Exception("Nonfinite valid buffer field: "+stage);}
            Save(directory,receipt,bytes);
        }catch(Exception error){errors++;Debug.LogError(error);}finally{pending--;}});
    }
    public static void Query(CommandBuffer cmd,ComputeShader shader,int kernel,Camera camera,int giFrame)
    {
        if(!Target(camera,out int frame,out string directory))return;
        var light=GameObject.Find("Behind thin wall").transform;
        cmd.SetComputeVectorParam(shader,"_TW_Camera",camera.transform.position);cmd.SetComputeVectorParam(shader,"_TW_Light",light.position);
        cmd.SetComputeFloatParam(shader,"_TW_FrameStamp",giFrame+100001);
        cmd.SetComputeBufferParam(shader,kernel,"_TW_Results",QueryBuffer);cmd.DispatchCompute(shader,kernel,1,1,1);
        var receipt=new Receipt{logicalFrame=frame,giFrame=giFrame,engineFrame=Time.frameCount,width=6,height=1,channels=40,stage="queries",actualFormat="ThinWallResult 160-byte mixed float/uint record"};
        pending++;cmd.RequestAsyncReadback(QueryBuffer,request=>
        {try{
            if(request.hasError)throw new Exception("Thin-wall query readback failed");
            byte[] bytes=request.GetData<byte>().ToArray();if(bytes.Length!=960)throw new Exception("Thin-wall query size mismatch");
            for(int record=0;record<6;record++){
                int start=record*160;
                for(int offset=0;offset<160;offset+=4){if(offset>=112&&offset<144)continue;float value=BitConverter.ToSingle(bytes,start+offset);if(float.IsNaN(value)||float.IsInfinity(value))throw new Exception("Nonfinite query float field");}
                if(BitConverter.ToSingle(bytes,start+44)!=giFrame+100001)throw new Exception("Missing/stale query write stamp");
                foreach(int offset in new[]{60,92,108}){float flag=BitConverter.ToSingle(bytes,start+offset);if(flag!=0&&flag!=1)throw new Exception("Invalid query boolean field");}
                if(record<2)foreach(int offset in new[]{144,148}){float flag=BitConverter.ToSingle(bytes,start+offset);if(flag!=0&&flag!=1)throw new Exception("Invalid shadow boolean field");}
            }
            Save(directory,receipt,bytes);
        }catch(Exception error){errors++;Debug.LogError(error);}finally{pending--;}});
    }
    public static void QueryUnavailable(Camera camera,int giFrame,bool exact)
    {
        if(!Target(camera,out int frame,out string directory))return;
        if(exact)throw new Exception("Exact software active but observer query kernel is missing");
        if(!unavailable.Add(frame))throw new Exception("Duplicate unavailable query receipt");skippedQueries++;
        File.AppendAllText(Path.Combine(directory,"thin-query-unavailable.jsonl"),JsonUtility.ToJson(new Receipt{logicalFrame=frame,giFrame=giFrame,engineFrame=Time.frameCount,stage="query-unavailable-startup-nonexact"})+"\n");
    }
    public static void State(CommandBuffer cmd,object state,Camera camera,int giFrame,int cacheRead,int lightCount,Matrix4x4 invVP)
    {
        if(!Target(camera,out int frame,out string directory))return;
        var scene=(HybridLumenGIScene)Field(state,"scene");var surface=(HybridLumenGISurfaceCache)Field(state,"surfaceCache");
        var owners=new List<Owner>();
        for(int slot=0;slot<scene.Capacity;slot++)
        {
            var proxy=scene.GetProxy(slot);if(!proxy)continue;var gpu=scene.Data[slot];var renderer=proxy.SourceRenderer;
            owners.Add(new Owner{slot=slot,stableId=(int)gpu.identity.x,revision=(int)gpu.identity.y,name=proxy.name,published=scene.IsPublished(slot),
                ready=surface.IsSlotReady(slot,(int)gpu.identity.x,(int)gpu.identity.y),center=renderer.bounds.center,size=renderer.bounds.size});
        }
        var feature=(HybridLumenGIRendererFeature)capture.feature;
        var source=new Sources{logicalFrame=frame,giFrame=giFrame,engineFrame=Time.frameCount,lightCount=lightCount,cacheEntries=(int)Field(state,"cacheEntryCount"),
            invVP=invVP,owners=owners.ToArray(),diagnostics=feature.GetDiagnostics().First(d=>d.camera==camera.name)};
        File.WriteAllText(Path.Combine(directory,"thin-"+frame.ToString("D4")+"-sources.json"),JsonUtility.ToJson(source,true));
        Buffer(cmd,(ComputeBuffer)Field(state,"lights"),camera,giFrame,"lights-packed",lightCount);
        Buffer(cmd,scene.Buffer,camera,giFrame,"scene-packed");Buffer(cmd,scene.LightingPolicyBuffer,camera,giFrame,"policy-packed");
        Buffer(cmd,((ComputeBuffer[])Field(state,"cache"))[cacheRead],camera,giFrame,"cache");
    }
    sealed class NativeData {public TextureHandle texture;public Camera camera;public int frame;}
    public static void Native(RenderGraph graph,TextureHandle color,Camera camera,int giFrame)
    {
        if(!Target(camera,out _,out _))return;
        using(var builder=graph.AddUnsafePass<NativeData>("Thin-wall pre-GI color readback",out var data))
        {
            data.texture=color;data.camera=camera;data.frame=giFrame;builder.UseTexture(color,AccessFlags.Read);builder.AllowPassCulling(false);
            builder.SetRenderFunc(static(NativeData d,UnsafeGraphContext context)=>Texture(CommandBufferHelpers.GetNativeCommandBuffer(context.cmd),((RTHandle)d.texture).rt,d.camera,d.frame,"native"));
        }
    }
    public static void Finish(bool collected)
    {
        if(!requested||finished)return;finished=true;
        try
        {
        AsyncGPUReadback.WaitAllRequests();
        // Ten textures, four buffers and one query buffer per predeclared sample.
        var missingStages=Samples.SelectMany(frame=>Stages.Select(stage=>frame.ToString("D4")+"-"+stage)).Where(key=>!completed.Contains(key)).ToArray();
        var missingQueries=Samples.Select(frame=>frame.ToString("D4")+"-queries").Where(key=>!completed.Contains(key)).ToArray();
        var summary=new Summary{completedFiles=completed.Count,pending=pending,errors=errors,skippedQueries=skippedQueries,missingStages=missingStages,missingQueries=missingQueries,
            stageCollectionComplete=missingStages.Length==0,queryCoverageComplete=missingQueries.Length==0,
            passed=missingStages.Length==0&&missingQueries.Length==0&&completed.Count==9*15&&pending==0&&errors==0};
        string directory=capture?(string)Field(capture,"directory"):null;
        if(!string.IsNullOrEmpty(directory))File.WriteAllText(Path.Combine(directory,"thin-summary.json"),JsonUtility.ToJson(summary,true));
        if(collected&&!summary.passed)throw new Exception("Thin-wall stage evidence incomplete");
        }
        finally
        {
            // Closed admission; every accepted query/depth copy must complete before release.
            if(pending==0)
            {
                try{queries?.Dispose();queries=null;}catch(Exception error){errors++;Debug.LogError(error);}
                try{depthValues?.Dispose();depthValues=null;}catch(Exception error){errors++;Debug.LogError(error);}
            }
        }
    }
}
