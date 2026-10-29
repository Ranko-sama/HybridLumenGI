// Temporary test-project observer. This file is never part of product Runtime.
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

public static class FiniteWallReferenceTap
{
    public static Camera Camera;
    public static string Directory;
    public static int TargetWorkFrame=-1;
    public static bool Completed;
    public static string Failure;
    static bool recorded;
    static int pending;
    static ComputeBuffer pixels,rows;
    static ComputeShader sampler;
    static Receipt receipt;
    [StructLayout(LayoutKind.Sequential)] struct Pixel {public uint x,y;}
    [Serializable] public sealed class Selection
    {public string id;public int x,y,offsetX,offsetY;public float[] authoredTarget;}
    [Serializable] public sealed class Receipt
    {
        public int workFrame,engineFrame,width,height,fullWidth,fullHeight,rays,groupCount;
        public bool complete;
        public string error,rawFormat,geometryFormat,materialFormat,normalsFormat,depthFormat;
        public float rayBias;
        public bool normalsOct;
        public float[] invVP,vp,view;
        public Selection[] selection;
        public string scope="Actual gather command boundary; only input directions replayed. Product raw colors are saved separately and never enter the reference sampler.";
    }
    public static void Reset(Camera camera,string directory)
    {
        if(pending!=0||pixels!=null||rows!=null)throw new InvalidOperationException("Previous reference tap is not disposed");
        Camera=camera;Directory=directory;TargetWorkFrame=-1;Completed=false;Failure=null;recorded=false;receipt=null;
    }
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}
    static float[] Matrix(Matrix4x4 m){var v=new float[16];for(int i=0;i<16;i++)v[i]=m[i];return v;}
    static void WriteNew(string name,byte[] data)
    {using(var stream=new FileStream(Path.Combine(Directory,name),FileMode.CreateNew,FileAccess.Write,FileShare.Read))stream.Write(data,0,data.Length);}
    static void Save()
    {if(receipt!=null)File.WriteAllText(Path.Combine(Directory,"tap-receipt.json"),JsonUtility.ToJson(receipt,true));}
    static void EndRequest()
    {
        pending--;
        if(pending!=0)return;
        receipt.complete=string.IsNullOrEmpty(Failure);receipt.error=Failure;Save();Completed=receipt.complete;
    }
    static void ReadTexture(CommandBuffer cmd,RenderTexture texture,string name)
    {
        cmd.RequestAsyncReadback(texture,0,TextureFormat.RGBAFloat,request=>
        {
            try
            {
                Require(!request.hasError,name+" readback failed");
                var data=request.GetData<float>();Require(data.Length==receipt.width*receipt.height*4,name+" readback shape");
                for(int i=0;i<data.Length;i++)Require(!float.IsNaN(data[i])&&!float.IsInfinity(data[i]),name+" nonfinite component");
                WriteNew(name+".rgba32f",request.GetData<byte>().ToArray());
            }
            catch(Exception error){Failure=error.ToString();}
            finally{EndRequest();}
        });
    }
    public static void Record(CommandBuffer cmd,RenderTexture raw,RenderTexture geometry,RenderTexture depth,
        RenderTexture material,RenderTexture normals,Camera camera,int workFrame,Matrix4x4 invVP,Matrix4x4 vp,Matrix4x4 view,
        Vector2Int fullSize,float rayBias,int rays,bool normalsOct)
    {
        if(camera!=Camera||TargetWorkFrame<0||workFrame!=TargetWorkFrame)return;
        try
        {
            Require(!recorded,"Duplicate reference dispatch");recorded=true;
            Require(System.IO.Directory.Exists(Directory),"Reference output directory missing");
            Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&SystemInfo.graphicsUVStartsAtTop,"Frozen DX12 UV convention required");
            Require(rays==8&&rayBias==.03f,"Frozen ray configuration differs");
            Require(raw.graphicsFormat==UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_SFloat,"Raw signal is not RGBA16F");
            sampler=Resources.Load<ComputeShader>("FiniteWallReferenceInputs");Require(sampler!=null,"Reference sampler missing");
            int kernel=sampler.FindKernel("CSReferenceInputs");
            var selected=new List<Selection>();var coordinates=new List<Pixel>();var unique=new HashSet<ulong>();
            var targets=new[]{new Vector3(.5f,0,0),new Vector3(1,0,0),new Vector3(2,0,0)};
            for(int target=0;target<targets.Length;target++)
            {
                Vector4 clip=vp*new Vector4(targets[target].x,0,0,1);Require(clip.w>0,"Reference target behind camera");
                Vector2 uv=new Vector2(clip.x/clip.w*.5f+.5f,1-(clip.y/clip.w*.5f+.5f));
                int centerX=Mathf.FloorToInt(uv.x*raw.width),centerY=Mathf.FloorToInt(uv.y*raw.height);
                foreach(int dy in new[]{-2,0,2})foreach(int dx in new[]{-2,0,2})
                {
                    int x=centerX+dx,y=centerY+dy;
                    Require(x>=2&&y>=2&&x<raw.width-2&&y<raw.height-2,"Reference pixels outside interior viewport");
                    Require(unique.Add(((ulong)(uint)y<<32)|(uint)x),"Duplicate reference pixel");
                    coordinates.Add(new Pixel{x=(uint)x,y=(uint)y});
                    selected.Add(new Selection{id="receiver"+target+"_"+dx+"_"+dy,x=x,y=y,offsetX=dx,offsetY=dy,
                        authoredTarget=new[]{targets[target].x,0f,0f}});
                }
            }
            receipt=new Receipt{workFrame=workFrame,engineFrame=Time.frameCount,width=raw.width,height=raw.height,
                fullWidth=fullSize.x,fullHeight=fullSize.y,rays=rays,groupCount=selected.Count,rayBias=rayBias,normalsOct=normalsOct,
                rawFormat=raw.graphicsFormat.ToString(),geometryFormat=geometry.graphicsFormat.ToString(),materialFormat=material.graphicsFormat.ToString(),
                normalsFormat=normals.graphicsFormat.ToString(),depthFormat=depth.graphicsFormat.ToString(),invVP=Matrix(invVP),vp=Matrix(vp),view=Matrix(view),selection=selected.ToArray()};
            Save();
            pixels=new ComputeBuffer(selected.Count,8);pixels.SetData(coordinates.ToArray());
            rows=new ComputeBuffer(selected.Count*8*6,16);
            cmd.SetComputeBufferParam(sampler,kernel,"_ReferencePixels",pixels);cmd.SetComputeBufferParam(sampler,kernel,"_ReferenceRows",rows);
            cmd.SetComputeIntParam(sampler,"_ReferencePixelCount",selected.Count);
            cmd.SetComputeTextureParam(sampler,kernel,"_HLGI_Depth",depth);cmd.SetComputeTextureParam(sampler,kernel,"_HLGI_Normals",normals);
            cmd.SetComputeVectorParam(sampler,"_HLGI_Size",new Vector4(raw.width,raw.height,1f/raw.width,1f/raw.height));
            cmd.SetComputeVectorParam(sampler,"_HLGI_FullSize",new Vector4(fullSize.x,fullSize.y,1f/fullSize.x,1f/fullSize.y));
            cmd.SetComputeMatrixParam(sampler,"_HLGI_InvVP",invVP);cmd.SetComputeMatrixParam(sampler,"_HLGI_View",view);
            cmd.SetComputeIntParam(sampler,"_HLGI_NormalsOct",normalsOct?1:0);cmd.SetComputeIntParam(sampler,"_HLGI_FrameIndex",workFrame);
            cmd.SetComputeIntParam(sampler,"_HLGI_Rays",rays);cmd.SetComputeFloatParam(sampler,"_HLGI_RayBias",rayBias);cmd.SetComputeFloatParam(sampler,"_HLGI_GuideWeight",0);
            cmd.DispatchCompute(sampler,kernel,(selected.Count+63)/64,1,1);
            pending=4;
            ReadTexture(cmd,raw,"raw");ReadTexture(cmd,geometry,"geometry");ReadTexture(cmd,material,"material");
            cmd.RequestAsyncReadback(rows,request=>
            {
                try{Require(!request.hasError,"Reference input readback failed");Require(request.GetData<byte>().Length==selected.Count*8*96,"Input byte count");WriteNew("sampler-inputs.bin",request.GetData<byte>().ToArray());}
                catch(Exception error){Failure=error.ToString();}
                finally{EndRequest();}
            });
        }
        catch(Exception error){Failure=error.ToString();if(receipt!=null){receipt.error=Failure;Save();}}
    }
    public static void Dispose()
    {
        AsyncGPUReadback.WaitAllRequests();
        pixels?.Release();rows?.Release();pixels=null;rows=null;sampler=null;
        Require(pending==0,"Reference readback still pending after wait");
    }
}
