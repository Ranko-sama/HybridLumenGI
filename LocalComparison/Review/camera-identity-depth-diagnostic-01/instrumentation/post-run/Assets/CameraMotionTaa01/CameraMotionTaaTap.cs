// Isolated input-preserving observer. The independent analyzer decides all cohorts.
using System;
using System.IO;
using System.Runtime.InteropServices;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class CameraMotionTaaTap
{
    public static Camera Camera;
    public static string Directory,Failure;
    public static int RecordedFrames,CompletedFrames,TargetWorkFrame=-1;
    public static bool Completed=>CompletedFrames==48&&pending==0&&string.IsNullOrEmpty(Failure);
    static ComputeBuffer pixels,rows;
    static MeshRenderer[] sources;
    static int pending;
    const int Count=264,Stride=45,Controls=12;
    [StructLayout(LayoutKind.Sequential)]struct Pixel{public uint x,y;}
    [Serializable]sealed class Source{public string name;public int stableId,revision,geometryRevision;public float[] matrix;public Vector4 shaderLinearColor;}
    [Serializable]sealed class Selection{public int index,x,y;public bool projected;public string cohort;public Vector3 worldTarget;}
    [Serializable]sealed class Receipt
    {
        public int logicalFrame,workFrame,engineFrame,pixels=Count,rowVectors=Stride,controlVectors=Controls,width,height,lightCount,changeCount;
        public int instanceCount,triangleCount,transformUpdates,sceneRebuilds;
        public ulong geometryVersion;
        public bool complete,historyValid,hasMotion,useIdentity,postProcessing;
        public string error,phase,antialiasing,motionFormat,taaQuality;
        public float jitterScale;
        public Vector3 cameraPosition;public Quaternion cameraRotation;
        public Source[] sources;public Selection[] selection;
        public float[] invVP,vp,previousVP,previousInvVP,view,jitterDelta,cameraProjection,unjitteredGpuVP;
    }
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}
    static float[] Matrix(Matrix4x4 m){var result=new float[16];for(int i=0;i<16;i++)result[i]=m[i];return result;}
    static void Write(string name,byte[] data){using(var stream=new FileStream(Path.Combine(Directory,name),FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(data,0,data.Length);}
    static Source[] DescribeSources()
    {
        var result=new Source[sources.Length];
        for(int i=0;i<sources.Length;i++)
        {
            var renderer=sources[i];var proxy=renderer.GetComponent<HybridLumenGIProxy>();var block=new MaterialPropertyBlock();renderer.GetPropertyBlock(block);
            result[i]=new Source{name=renderer.name,stableId=proxy.StableId,revision=proxy.Revision,geometryRevision=proxy.GeometryContentRevision,matrix=Matrix(renderer.localToWorldMatrix),shaderLinearColor=block.GetVector("_BaseColor")};
        }
        return result;
    }
    public static void Reset(Camera camera,string directory,MeshRenderer[] renderers)
    {
        Require(pixels==null&&rows==null&&pending==0,"Previous camera observer not disposed");
        Require(renderers!=null&&renderers.Length==3,"Three static source renderers required");
        Camera=camera;Directory=directory;sources=renderers;Failure=null;RecordedFrames=CompletedFrames=0;TargetWorkFrame=-1;
        pixels=new ComputeBuffer(Count,8);rows=new ComputeBuffer(Controls+Count*Stride,16);
    }
    static Selection[] Select(Matrix4x4 vp,out Pixel[] coordinates)
    {
        var result=new Selection[Count];coordinates=new Pixel[Count];int index=0;
        for(int group=0;group<2;group++)for(int j=0;j<11;j++)for(int i=0;i<(group==0?21:3);i++)
        {
            var target=new Vector3(group==0?.8f+.05f*i:2f+.2f*i,0,.5f+.1f*j);
            Vector4 clip=vp*new Vector4(target.x,target.y,target.z,1);
            bool valid=clip.w>0&&!float.IsNaN(clip.w)&&!float.IsInfinity(clip.w);
            Vector2 uv=valid?new Vector2(clip.x/clip.w*.5f+.5f,1-(clip.y/clip.w*.5f+.5f)):new Vector2(-1,-1);
            valid=valid&&uv.x>0&&uv.x<1&&uv.y>0&&uv.y<1;
            int x=valid?Mathf.FloorToInt(uv.x*640):-1,y=valid?Mathf.FloorToInt(uv.y*360):-1;
            result[index]=new Selection{index=index,x=x,y=y,projected=valid,cohort=group==0?"event":"continued",worldTarget=target};
            coordinates[index]=new Pixel{x=valid?(uint)x:uint.MaxValue,y=valid?(uint)y:uint.MaxValue};index++;
        }
        Require(index==Count,"Authored selection count changed");return result;
    }
    public static void Record(CommandBuffer cmd,ComputeShader shader,RenderTexture raw,RenderTexture history,RenderTexture moments,
        RenderTexture previousHistory,RenderTexture previousMoments,RenderTexture geometry,RenderTexture previousGeometry,
        RenderTexture material,RenderTexture previousMaterial,RenderTexture motion,RenderTexture identity,RenderTexture previousIdentity,
        GraphicsBuffer candidates,GraphicsBuffer objects,int objectCount,bool useIdentity,HybridLumenGIChangeRegions changes,
        HybridLumenGIHardwareBackend backend,Camera camera,int workFrame,int lightCount,Matrix4x4 invVP,Matrix4x4 vp,
        Matrix4x4 previousVP,Matrix4x4 previousInvVP,Matrix4x4 view,Vector2 jitterDelta,bool historyValid,bool hasMotion)
    {
        if(camera!=Camera)return;
        try
        {
            Require(RecordedFrames<48&&pixels!=null,"Unexpected camera gather");
            Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&SystemInfo.graphicsUVStartsAtTop,"DX12 UV convention required");
            Require(raw.width==640&&raw.height==360&&useIdentity&&identity&&previousIdentity&&candidates!=null&&objects!=null&&objectCount==3,"Frozen resolution/identity inputs unavailable");
            var half=UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_SFloat;
            var full=UnityEngine.Experimental.Rendering.GraphicsFormat.R32G32B32A32_SFloat;
            var uint4=UnityEngine.Experimental.Rendering.GraphicsFormat.R32G32B32A32_UInt;
            Require(raw.graphicsFormat==half&&history.graphicsFormat==half&&previousHistory.graphicsFormat==half,"Actual RGBA16F history/raw required");
            Require(geometry.graphicsFormat==full&&previousGeometry.graphicsFormat==full&&moments.graphicsFormat==full&&previousMoments.graphicsFormat==full,"Actual RGBA32F geometry/moments required");
            Require(identity.graphicsFormat==uint4&&previousIdentity.graphicsFormat==uint4,"Actual uint4 receiver identity required");
            Require(backend!=null&&backend.IsReady&&backend.CanDispatch&&backend.InstanceCount==3&&backend.TriangleCount==6,"Three exact static source meshes required");
            int logical=RecordedFrames++;TargetWorkFrame=workFrame;var additional=camera.GetUniversalAdditionalCameraData();
            var selection=Select(vp,out Pixel[] coordinates);cmd.SetBufferData(pixels,coordinates);
            var receipt=new Receipt{logicalFrame=logical,workFrame=workFrame,engineFrame=Time.frameCount,width=640,height=360,lightCount=lightCount,changeCount=changes.Count,
                historyValid=historyValid,hasMotion=hasMotion,useIdentity=useIdentity,phase=logical<32?"warm":logical<40?"moving":"hold",motionFormat=motion.graphicsFormat.ToString(),
                instanceCount=backend.InstanceCount,triangleCount=backend.TriangleCount,geometryVersion=backend.GeometryVersion,transformUpdates=backend.TransformUpdateCount,sceneRebuilds=backend.SceneRebuildCount,
                sources=DescribeSources(),selection=selection,cameraPosition=camera.transform.position,cameraRotation=camera.transform.rotation,
                antialiasing=additional.antialiasing.ToString(),taaQuality=additional.taaSettings.quality.ToString(),postProcessing=additional.renderPostProcessing,jitterScale=additional.taaSettings.jitterScale,
                invVP=Matrix(invVP),vp=Matrix(vp),previousVP=Matrix(previousVP),previousInvVP=Matrix(previousInvVP),view=Matrix(view),jitterDelta=new[]{jitterDelta.x,jitterDelta.y},
                cameraProjection=Matrix(camera.projectionMatrix),unjitteredGpuVP=Matrix(GL.GetGPUProjectionMatrix(camera.projectionMatrix,true)*view)};
            int kernel=shader.FindKernel("CSCameraMotionTaaCopy");
            cmd.SetComputeIntParam(shader,"_CameraTaaPixelCount",Count);cmd.SetComputeBufferParam(shader,kernel,"_CameraTaaPixels",pixels);cmd.SetComputeBufferParam(shader,kernel,"_CameraTaaRows",rows);
            string[] names={"_HLGI_Input","_HLGI_Output","_HLGI_MomentsOut","_HLGI_History","_HLGI_PreviousMoments","_HLGI_Geometry","_HLGI_PreviousGeometry","_HLGI_Material","_HLGI_PreviousMaterial","_HLGI_Motion","_HLGI_IdentityCurrent","_HLGI_IdentityPrevious"};
            var textures=new[]{raw,history,moments,previousHistory,previousMoments,geometry,previousGeometry,material,previousMaterial,motion,identity,previousIdentity};
            for(int i=0;i<names.Length;i++)cmd.SetComputeTextureParam(shader,kernel,names[i],textures[i]);
            cmd.SetComputeBufferParam(shader,kernel,"_HLGI_IdentityCandidates",candidates);cmd.SetComputeBufferParam(shader,kernel,"_HLGI_IdentityObjects",objects);cmd.SetComputeIntParam(shader,"_HLGI_IdentityObjectCount",objectCount);
            cmd.DispatchCompute(shader,kernel,(Count+63)/64,1,1);
            string stem="frame-"+logical.ToString("D3");pending++;
            cmd.RequestAsyncReadback(rows,request=>
            {
                try{Require(!request.hasError,"Compact camera input readback failed");byte[] data=request.GetData<byte>().ToArray();Require(data.Length==(Controls+Count*Stride)*16,"Camera input ABI differs");Write(stem+".bin",data);receipt.complete=true;CompletedFrames++;}
                catch(Exception error){receipt.error=error.ToString();Failure=Failure??receipt.error;}
                finally{pending--;Write(stem+".json",System.Text.Encoding.UTF8.GetBytes(JsonUtility.ToJson(receipt,true)));}
            });
        }
        catch(Exception error){Failure=Failure??error.ToString();}
    }
    public static void Dispose()
    {
        AsyncGPUReadback.WaitAllRequests();
        try{Require(pending==0,"Camera readbacks did not drain");}
        finally{pixels?.Release();rows?.Release();pixels=rows=null;sources=null;}
    }
}
