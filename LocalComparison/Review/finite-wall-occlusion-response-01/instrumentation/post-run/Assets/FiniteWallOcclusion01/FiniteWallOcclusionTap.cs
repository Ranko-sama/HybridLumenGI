// Compact, input-preserving temporal observer; deployed only in the temporary test project.
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

public static class FiniteWallOcclusionTap
{
    public static Camera Camera;
    public static string Directory,Failure;
    public static int CompletedFrames,RecordedFrames;
    public static bool Completed=>CompletedFrames==56&&pending==0&&string.IsNullOrEmpty(Failure);
    public static int TargetWorkFrame=-1;
    static ComputeBuffer pixels,rows,centers,directions;
    static MeshRenderer[] sources;
    static int pending;
    static Pixel[] coordinates;
    static Selection[] selection;
    [StructLayout(LayoutKind.Sequential)] struct Pixel {public uint x,y;}
    [Serializable] public sealed class Selection {public string id;public int x,y,supportRadius=2;public int[] rows;}
    [Serializable] sealed class Coordinate {public int x,y;}
    [Serializable] sealed class SelectionReceipt {public int rowVectors=10,controlVectors=3;public Selection[] selection;public Coordinate[] coordinates;}
    [Serializable] sealed class Receipt
    {
        public int logicalFrame,workFrame,engineFrame,pixels,changeCount,width,height,lightCount,instanceCount,triangleCount,transformUpdates,sceneRebuilds;
        public ulong geometryVersion;
        public Source[] sources;
        public bool complete,historyValid,hasMotion;
        public string error,phase;
        public float[] invVP,vp,previousVP,previousInvVP,view,jitterDelta;
    }
    [Serializable] sealed class Source
    {public string name;public int stableId,revision,geometryRevision;public float[] matrix;public Vector4 shaderLinearColor;}
    static Source[] DescribeSources()
    {
        var result=new Source[sources.Length];
        for(int i=0;i<sources.Length;i++)
        {
            var source=sources[i];var proxy=source.GetComponent<HybridLumenGIProxy>();var block=new MaterialPropertyBlock();source.GetPropertyBlock(block);
            result[i]=new Source{name=source.name,stableId=proxy.StableId,revision=proxy.Revision,geometryRevision=proxy.GeometryContentRevision,matrix=Matrix(source.localToWorldMatrix),shaderLinearColor=block.GetVector("_BaseColor")};
        }
        return result;
    }
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}
    static float[] Matrix(Matrix4x4 m){var values=new float[16];for(int i=0;i<16;i++)values[i]=m[i];return values;}
    static T Field<T>(object value,string name)=>(T)value.GetType().GetField(name,BindingFlags.NonPublic|BindingFlags.Instance).GetValue(value);
    static void Write(string name,byte[] data)
    {using(var stream=new FileStream(Path.Combine(Directory,name),FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(data,0,data.Length);}
    public static void Reset(Camera camera,string directory,MeshRenderer[] renderers)
    {
        Require(pixels==null&&rows==null&&pending==0,"Previous occlusion observer was not disposed");
        Require(renderers!=null&&renderers.Length==3,"Three frozen source renderers required");sources=renderers;
        Camera=camera;Directory=directory;Failure=null;CompletedFrames=RecordedFrames=0;TargetWorkFrame=-1;coordinates=null;selection=null;
    }
    static void Select(Matrix4x4 vp,int width,int height)
    {
        var samples=new List<Pixel>();var selected=new List<Selection>();var lookup=new Dictionary<ulong,int>();
        var targets=new[]{new Vector3(.5f,0,0),new Vector3(1,0,0),new Vector3(2,0,0)};
        for(int group=0;group<targets.Length;group++)
        {
            Vector4 clip=vp*new Vector4(targets[group].x,0,0,1);Require(clip.w>0,"Authored receiver is behind the camera");
            Vector2 uv=new Vector2(clip.x/clip.w*.5f+.5f,1-(clip.y/clip.w*.5f+.5f));
            int centerX=Mathf.FloorToInt(uv.x*width),centerY=Mathf.FloorToInt(uv.y*height);
            foreach(int dy in new[]{-2,0,2})foreach(int dx in new[]{-2,0,2})
            {
                int x=centerX+dx,y=centerY+dy;Require(x>=3&&y>=3&&x<width-3&&y<height-3,"Receiver support leaves the texture");
                var indices=new List<int>();
                for(int sy=-2;sy<=2;sy++)for(int sx=-2;sx<=2;sx++)
                {
                    uint px=(uint)(x+sx),py=(uint)(y+sy);ulong key=((ulong)py<<32)|px;
                    if(!lookup.TryGetValue(key,out int index)){index=samples.Count;lookup.Add(key,index);samples.Add(new Pixel{x=px,y=py});}
                    indices.Add(index);
                }
                selected.Add(new Selection{id="receiver"+group+"_"+dx+"_"+dy,x=x,y=y,rows=indices.ToArray()});
            }
        }
        coordinates=samples.ToArray();selection=selected.ToArray();var exported=new Coordinate[coordinates.Length];
        for(int i=0;i<coordinates.Length;i++)exported[i]=new Coordinate{x=(int)coordinates[i].x,y=(int)coordinates[i].y};
        Write("selection.json",System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(new SelectionReceipt{selection=selection,coordinates=exported},true)));
        pixels=new ComputeBuffer(coordinates.Length,8);pixels.SetData(coordinates);rows=new ComputeBuffer(3+coordinates.Length*10,16);
        var centerPixels=new Pixel[selection.Length];for(int i=0;i<selection.Length;i++)centerPixels[i]=new Pixel{x=(uint)selection[i].x,y=(uint)selection[i].y};
        centers=new ComputeBuffer(centerPixels.Length,8);centers.SetData(centerPixels);directions=new ComputeBuffer(centerPixels.Length*8*6,16);
    }
    public static void Record(CommandBuffer cmd,ComputeShader shader,RenderTexture raw,RenderTexture history,RenderTexture moments,
        RenderTexture previousHistory,RenderTexture previousMoments,RenderTexture geometry,RenderTexture previousGeometry,
        RenderTexture material,RenderTexture previousMaterial,RenderTexture motion,RenderTexture depth,RenderTexture normals,HybridLumenGIChangeRegions changes,HybridLumenGIHardwareBackend backend,
        Camera camera,int workFrame,int lightCount,Matrix4x4 invVP,Matrix4x4 vp,Matrix4x4 previousVP,Matrix4x4 previousInvVP,
        Matrix4x4 view,Vector2 jitterDelta,bool historyValid,bool hasMotion)
    {
        if(camera!=Camera)return;
        try
        {
            Require(RecordedFrames<56,"Extra occlusion gather beyond the frozen 56 frames");
            Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&SystemInfo.graphicsUVStartsAtTop,"DX12 UV convention required");
            Require(raw.width==640&&raw.height==360,"Frozen full-resolution signal changed");
            var half=UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_SFloat;
            var full=UnityEngine.Experimental.Rendering.GraphicsFormat.R32G32B32A32_SFloat;
            Require(raw.graphicsFormat==half&&history.graphicsFormat==half&&previousHistory.graphicsFormat==half,"Raw/history must retain actual RGBA16F storage");
            Require(moments.graphicsFormat==full&&previousMoments.graphicsFormat==full&&geometry.graphicsFormat==full&&previousGeometry.graphicsFormat==full,"Moments/geometry must retain actual RGBA32F storage");
            Require(backend!=null&&backend.IsReady&&backend.CanDispatch&&backend.InstanceCount==3&&backend.TriangleCount==6,"Prepared exact three-plane geometry required");
            if(coordinates==null)Select(vp,raw.width,raw.height);
            int logical=RecordedFrames++;TargetWorkFrame=workFrame;
            var receipt=new Receipt{logicalFrame=logical,workFrame=workFrame,engineFrame=Time.frameCount,pixels=coordinates.Length,changeCount=changes.Count,
                width=raw.width,height=raw.height,lightCount=lightCount,historyValid=historyValid,hasMotion=hasMotion,phase=logical<32?"distant":logical<44?"covered":"restored",
                instanceCount=backend.InstanceCount,triangleCount=backend.TriangleCount,geometryVersion=backend.GeometryVersion,transformUpdates=backend.TransformUpdateCount,sceneRebuilds=backend.SceneRebuildCount,sources=DescribeSources(),
                invVP=Matrix(invVP),vp=Matrix(vp),previousVP=Matrix(previousVP),previousInvVP=Matrix(previousInvVP),view=Matrix(view),jitterDelta=new[]{jitterDelta.x,jitterDelta.y}};
            int kernel=shader.FindKernel("CSFiniteWallOcclusionCopy");
            cmd.SetComputeIntParam(shader,"_OcclusionPixelCount",coordinates.Length);cmd.SetComputeBufferParam(shader,kernel,"_OcclusionPixels",pixels);cmd.SetComputeBufferParam(shader,kernel,"_OcclusionRows",rows);
            string[] names={"_HLGI_Input","_HLGI_Output","_HLGI_MomentsOut","_HLGI_History","_HLGI_PreviousMoments","_HLGI_Geometry","_HLGI_PreviousGeometry","_HLGI_Material","_HLGI_PreviousMaterial","_HLGI_Motion"};
            var textures=new[]{raw,history,moments,previousHistory,previousMoments,geometry,previousGeometry,material,previousMaterial,motion};
            for(int i=0;i<names.Length;i++)cmd.SetComputeTextureParam(shader,kernel,names[i],textures[i]);
            // Global scalar parameters remain the actual immediately preceding temporal bindings.
            cmd.DispatchCompute(shader,kernel,(coordinates.Length+63)/64,1,1);
            int sampler=shader.FindKernel("CSFiniteWallOcclusionInputs");
            cmd.SetComputeIntParam(shader,"_OcclusionCenterCount",selection.Length);
            cmd.SetComputeBufferParam(shader,sampler,"_OcclusionCenters",centers);cmd.SetComputeBufferParam(shader,sampler,"_OcclusionDirections",directions);
            cmd.SetComputeTextureParam(shader,sampler,"_HLGI_Depth",depth);cmd.SetComputeTextureParam(shader,sampler,"_HLGI_Normals",normals);
            cmd.DispatchCompute(shader,sampler,(selection.Length+63)/64,1,1);
            string stem="frame-"+logical.ToString("D3");int framePending=receipt.changeCount>0?6:5;pending+=framePending;
            Action done=()=>{pending--;if(--framePending==0){receipt.complete=string.IsNullOrEmpty(receipt.error);Write(stem+".json",System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(receipt,true)));if(receipt.complete)CompletedFrames++;}};
            Action<ComputeBuffer,int,string> capture=(buffer,bytes,suffix)=>
            {
                Require(buffer!=null&&bytes>0&&buffer.count*buffer.stride>=bytes,"Observed geometry buffer ABI unavailable: "+suffix);
                cmd.RequestAsyncReadback(buffer,bytes,0,request=>
                {
                    try{Require(!request.hasError,"Readback failed: "+suffix);var data=request.GetData<byte>().ToArray();Require(data.Length==bytes,"Readback size differs: "+suffix);Write(stem+suffix,data);}
                    catch(Exception error){receipt.error=receipt.error??error.ToString();Failure=Failure??receipt.error;}
                    finally{done();}
                });
            };
            capture(rows,(3+receipt.pixels*10)*16,".bin");capture(directions,selection.Length*8*6*16,".directions");
            capture(Field<ComputeBuffer>(backend,"instancesBuffer"),backend.InstanceCount*128,".instances");
            capture(Field<ComputeBuffer>(backend,"objectToWorldBuffer"),backend.InstanceCount*64,".poses");
            capture(Field<ComputeBuffer>(backend,"surfaceBuffer"),backend.TriangleCount*96,".triangles");
            if(receipt.changeCount>0)capture(Field<ComputeBuffer>(changes,"buffer"),receipt.changeCount*48,".changes");
            else Write(stem+".changes",Array.Empty<byte>());
        }
        catch(Exception error){Failure=Failure??error.ToString();}
    }
    public static void Dispose()
    {
        AsyncGPUReadback.WaitAllRequests();
        try{Require(pending==0,"Occlusion readbacks did not drain");}
        finally{pixels?.Release();rows?.Release();centers?.Release();directions?.Release();pixels=rows=centers=directions=null;coordinates=null;selection=null;sources=null;}
    }
}
