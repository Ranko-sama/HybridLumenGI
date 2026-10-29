// Temporary observer. Geometry/scalar inputs and observed radiance use separate files.
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using HybridLumenGI;
using UnityEngine;
using UnityEngine.Rendering;

public static class CacheFeedbackFiniteTap
{
    public static int RecordedFrames {get;private set;}
    public static int TargetWorkFrame {get;private set;}
    public static string Failure {get;private set;}
    public static bool Completed
    {
        get
        {
            if(RecordedFrames!=34||Failure!=null||captures.Count!=3)return false;
            foreach(var capture in captures)if(!capture.receipt.complete)return false;
            return true;
        }
    }
    static Camera targetCamera;
    static string directory;
    static MeshRenderer[] sourceWalls;
    static ComputeShader sampler;
    static readonly List<ComputeBuffer> allocated=new List<ComputeBuffer>();
    static readonly List<Capture> captures=new List<Capture>();
    static Capture current;
    [StructLayout(LayoutKind.Sequential)] struct Pair {public uint x,y;}
    [Serializable] public sealed class Owner
    {
        public string id,renderer;public int slot,card;
        public uint generation,layoutGeneration,geometryRevision;
        public uint[] primitiveCards,primitiveCharts,primitiveLayouts,primitiveGeometry;
    }
    [Serializable] public sealed class Selection
    {public string id,receiverOwner;public int x,y,offsetX,offsetY;public float[] authoredTarget;}
    [Serializable] public sealed class Receipt
    {
        public int logicalFrame,workFrame,engineFrame,epoch,cacheReadIndex,cacheEntryCount,proxyCount,cardCount,changeCount,lightCount,cacheGrid,cacheRays;
        public int width,height,fullWidth,fullHeight,rays,groupCount;
        public float rayBias,feedback;
        public bool beforeRecorded,afterRecorded,gatherRecorded,complete,normalsOct;
        public string error,rawFormat,geometryFormat,materialFormat,depthFormat,normalsFormat;
        public float[] invVP,vp,view;
        public Owner[] owners;public Selection[] selection;
        public string scope="Actual Work cache snapshots; geometry-only shader inputs are distinct from raw/cache output observations";
    }
    sealed class Capture {public Receipt receipt;public int pending;public string prefix;}
    static void Require(bool value,string message){if(!value)throw new InvalidOperationException(message);}
    static float[] Matrix(Matrix4x4 matrix){var values=new float[16];for(int i=0;i<16;i++)values[i]=matrix[i];return values;}
    public static void Reset(Camera camera,string output,MeshRenderer wallA,MeshRenderer wallB)
    {
        Require(allocated.Count==0&&captures.Count==0,"Previous feedback capture not disposed");
        targetCamera=camera;directory=output;sourceWalls=new[]{wallA,wallB};RecordedFrames=0;TargetWorkFrame=-1;Failure=null;current=null;
    }
    static ComputeBuffer Buffer(int count,int stride)
    {var buffer=new ComputeBuffer(count,stride);allocated.Add(buffer);return buffer;}
    static void Save(Capture capture)
    {
        capture.receipt.complete=capture.receipt.beforeRecorded&&capture.receipt.afterRecorded&&capture.receipt.gatherRecorded&&capture.pending==0&&string.IsNullOrEmpty(capture.receipt.error);
        File.WriteAllText(Path.Combine(directory,capture.prefix+".json"),JsonUtility.ToJson(capture.receipt,true));
    }
    static void Fail(Capture capture,Exception error)
    {Failure=Failure??error.ToString();if(capture!=null){capture.receipt.error=error.ToString();Save(capture);}}
    static void WriteNew(string filename,byte[] data)
    {using(var file=new FileStream(Path.Combine(directory,filename),FileMode.CreateNew,FileAccess.Write,FileShare.Read))file.Write(data,0,data.Length);}
    static void ReadBuffer(CommandBuffer cmd,Capture capture,ComputeBuffer buffer,string suffix)
    {
        int expected=buffer.count*buffer.stride;capture.pending++;
        cmd.RequestAsyncReadback(buffer,request=>
        {
            try{Require(!request.hasError,suffix+" readback failed");var bytes=request.GetData<byte>();Require(bytes.Length==expected,suffix+" byte count");WriteNew(capture.prefix+"-"+suffix+".bin",bytes.ToArray());}
            catch(Exception error){Fail(capture,error);}
            finally{capture.pending--;Save(capture);}
        });
    }
    static void ReadTexture(CommandBuffer cmd,Capture capture,RenderTexture texture,string suffix)
    {
        int expected=texture.width*texture.height*16;capture.pending++;
        cmd.RequestAsyncReadback(texture,0,TextureFormat.RGBAFloat,request=>
        {
            try{Require(!request.hasError,suffix+" readback failed");var bytes=request.GetData<byte>();Require(bytes.Length==expected,suffix+" byte count");WriteNew(capture.prefix+"-"+suffix+".rgba32f",bytes.ToArray());}
            catch(Exception error){Fail(capture,error);}
            finally{capture.pending--;Save(capture);}
        });
    }
    static void Output(CommandBuffer cmd,Capture capture,int kernel,string binding,int count,int stride,string suffix)
    {
        var buffer=Buffer(count,stride);cmd.SetComputeBufferParam(sampler,kernel,binding,buffer);
        // All read requests are enqueued after the associated dispatch by the caller.
        pendingOutputs.Add(new OutputRow{buffer=buffer,suffix=suffix});
    }
    sealed class OutputRow {public ComputeBuffer buffer;public string suffix;}
    static readonly List<OutputRow> pendingOutputs=new List<OutputRow>();
    static void ReadOutputs(CommandBuffer cmd,Capture capture)
    {foreach(var row in pendingOutputs)ReadBuffer(cmd,capture,row.buffer,row.suffix);pendingOutputs.Clear();}
    static Owner[] Owners(HybridLumenGISurfaceCache surface,HybridLumenGIScene scene)
    {
        var result=new Owner[2];
        for(int owner=0;owner<2;owner++)
        {
            int slot=-1;
            for(int candidate=0;candidate<scene.Capacity;candidate++)if(scene.GetRenderer(candidate)==sourceWalls[owner]){Require(slot<0,"Duplicate source owner slot");slot=candidate;}
            Require(slot>=0&&scene.IsPublished(slot)&&surface.GetCardCount(slot)==1,"Source owner must have exactly one published real card");
            int card=surface.GetCardIndex(slot,0);var mesh=sourceWalls[owner].GetComponent<MeshFilter>().sharedMesh;
            Require(card>=0&&mesh.subMeshCount==1&&mesh.GetIndexCount(0)==6,"Source mesh/card shape differs");
            var row=new Owner{id=owner==0?"A":"B",renderer=sourceWalls[owner].name,slot=slot,card=card,generation=surface.GetGeneration(card),
                layoutGeneration=surface.GetLayoutGeneration(slot),geometryRevision=surface.GetGeometryRevision(slot),
                primitiveCards=new uint[2],primitiveCharts=new uint[2],primitiveLayouts=new uint[2],primitiveGeometry=new uint[2]};
            for(int primitive=0;primitive<2;primitive++)
            {
                Require(surface.TryGetTriangleBinding(slot,mesh,0,primitive,out var binding),"Source primitive chart binding unavailable");
                row.primitiveCards[primitive]=binding.cardIndex;row.primitiveCharts[primitive]=binding.chartId;
                row.primitiveLayouts[primitive]=binding.layoutGeneration;row.primitiveGeometry[primitive]=binding.geometryRevision;
                Require(binding.cardIndex==(uint)card,"One-wall primitive changed card");
            }
            result[owner]=row;
        }
        Require(result[0].slot!=result[1].slot&&result[0].card!=result[1].card,"Distinct walls must have distinct slots/cards");
        return result;
    }
    public static void RecordBeforeUpdate(CommandBuffer cmd,HybridLumenGISurfaceCache surface,HybridLumenGIScene scene,
        HybridLumenGIChangeRegions changes,ComputeBuffer updateMask,ComputeBuffer oldCache,ComputeBuffer newCache,
        Camera camera,int workFrame,int epoch,int cacheReadIndex,int cacheGrid,int cacheRays,float rayBias,float feedback,int lightCount)
    {
        if(camera!=targetCamera)return;
        try
        {
            Require(Failure==null,Failure);Require(current==null,"Previous logical capture not closed");
            if(RecordedFrames<31)return;
            Require(RecordedFrames<=33&&cacheGrid==1&&cacheRays==16&&rayBias==.03f&&feedback==1,"Frozen finite feedback settings differ");
            Require(oldCache!=newCache&&oldCache.stride==80&&newCache.stride==80&&oldCache.count==newCache.count,"Physical cache double buffers differ");
            Require(surface.CardCount==oldCache.count,"Grid-one cache/card capacity differs");
            if(sampler==null)sampler=Resources.Load<ComputeShader>("CacheFeedbackFiniteInputs");Require(sampler!=null,"Input-only sampler missing");
            var owners=Owners(surface,scene);current=new Capture{prefix="frame-"+RecordedFrames.ToString("D3"),receipt=new Receipt{
                logicalFrame=RecordedFrames,workFrame=workFrame,engineFrame=Time.frameCount,epoch=epoch,cacheReadIndex=cacheReadIndex,
                cacheEntryCount=oldCache.count,proxyCount=scene.Capacity,cardCount=surface.CardCount,changeCount=changes.Count,
                lightCount=lightCount,cacheGrid=cacheGrid,cacheRays=cacheRays,rayBias=rayBias,feedback=feedback,owners=owners}};
            captures.Add(current);Save(current);
            var active=Buffer(2,8);active.SetData(new[]{new Pair{x=(uint)owners[0].card,y=(uint)owners[0].slot},new Pair{x=(uint)owners[1].card,y=(uint)owners[1].slot}});
            cmd.SetComputeIntParam(sampler,"_HLGI_FrameIndex",workFrame);cmd.SetComputeIntParam(sampler,"_HLGI_Epoch",epoch);
            cmd.SetComputeIntParam(sampler,"_HLGI_CacheGrid",cacheGrid);cmd.SetComputeIntParam(sampler,"_HLGI_CacheRays",cacheRays);
            cmd.SetComputeFloatParam(sampler,"_HLGI_RayBias",rayBias);cmd.SetComputeFloatParam(sampler,"_HLGI_BounceFeedback",feedback);
            cmd.SetComputeIntParam(sampler,"_HLGI_LightCount",lightCount);cmd.SetComputeFloatParam(sampler,"_HLGI_GuideWeight",0);
            cmd.SetComputeIntParam(sampler,"_ReferenceLogical",RecordedFrames);cmd.SetComputeIntParam(sampler,"_ReferenceCacheReadIndex",cacheReadIndex);
            cmd.SetComputeIntParam(sampler,"_ReferenceActiveCount",2);cmd.SetComputeIntParam(sampler,"_ReferenceTileCapacity",1024);
            cmd.SetComputeIntParam(sampler,"_ReferenceChangeCapacity",1088);cmd.SetComputeIntParam(sampler,"_HLGI_ProxyCount",scene.Capacity);
            foreach(string name in new[]{"CSReferenceMetadata","CSReferenceChanges","CSReferenceCacheInputs","CSReferenceAtlas"})
            {
                int kernel=sampler.FindKernel(name);surface.BindCompute(cmd,sampler,kernel);changes.Bind(cmd,sampler,kernel);
                cmd.SetComputeBufferParam(sampler,kernel,"_ReferenceActiveCards",active);
                cmd.SetComputeBufferParam(sampler,kernel,"_HLGI_Proxies",scene.Buffer);
                cmd.SetComputeBufferParam(sampler,kernel,"_ReferenceCacheRead",oldCache);
                cmd.SetComputeBufferParam(sampler,kernel,"_HLGI_CacheUpdateMask",updateMask);
                Require(pendingOutputs.Count==0,"Previous diagnostic dispatch still unrecorded");
                if(name=="CSReferenceMetadata")
                {
                    Output(cmd,current,kernel,"_ReferenceCards",surface.CardCount,128,"cards");
                    Output(cmd,current,kernel,"_ReferenceOwnerRanges",scene.Capacity,16,"owner-ranges");
                    Output(cmd,current,kernel,"_ReferenceCardIndices",surface.CardCount,4,"card-indices");
                    Output(cmd,current,kernel,"_ReferenceAnchors",surface.CardCount,8,"anchors");
                    Output(cmd,current,kernel,"_ReferenceMask",surface.CardCount,4,"mask");
                    Output(cmd,current,kernel,"_ReferenceOwnerIdentities",scene.Capacity,16,"owner-identities");
                    Output(cmd,current,kernel,"_ReferenceCacheState",surface.CardCount*4,16,"cache-state-inputs");
                    Output(cmd,current,kernel,"_ReferenceGlobals",5,16,"globals");
                    cmd.DispatchCompute(sampler,kernel,(Mathf.Max(1088,Mathf.Max(surface.CardCount,scene.Capacity))+63)/64,1,1);
                }
                else if(name=="CSReferenceChanges")
                {Output(cmd,current,kernel,"_ReferenceChanges",1088,48,"changes");cmd.DispatchCompute(sampler,kernel,17,1,1);}
                else if(name=="CSReferenceCacheInputs")
                {Output(cmd,current,kernel,"_ReferenceCacheRows",2*16*8,16,"cache-inputs");cmd.DispatchCompute(sampler,kernel,1,1,1);}
                else
                {Output(cmd,current,kernel,"_ReferenceAtlasRows",2*1024*3,16,"atlas-inputs");cmd.DispatchCompute(sampler,kernel,32,1,1);}
                ReadOutputs(cmd,current);
            }
            ReadBuffer(cmd,current,oldCache,"cache-before");current.receipt.beforeRecorded=true;Save(current);
        }
        catch(Exception error){Fail(current,error);}
    }
    public static void RecordAfterUpdate(CommandBuffer cmd,ComputeBuffer oldCache,ComputeBuffer newCache,Camera camera,int workFrame)
    {
        if(camera!=targetCamera||RecordedFrames<31)return;
        try
        {
            Require(current!=null&&current.receipt.beforeRecorded&&current.receipt.workFrame==workFrame,"Cache update boundary lacks matching input observation");
            ReadBuffer(cmd,current,oldCache,"cache-old-after");ReadBuffer(cmd,current,newCache,"cache-new-after");
            current.receipt.afterRecorded=true;Save(current);
        }
        catch(Exception error){Fail(current,error);}
    }
    public static void RecordGather(CommandBuffer cmd,RenderTexture raw,RenderTexture geometry,RenderTexture depth,RenderTexture material,RenderTexture normals,
        Camera camera,int workFrame,Matrix4x4 invVP,Matrix4x4 vp,Matrix4x4 view,Vector2Int fullSize,float rayBias,int rays,bool normalsOct)
    {
        if(camera!=targetCamera)return;
        try
        {
            TargetWorkFrame=workFrame;Require(RecordedFrames<34,"Too many feedback render calls");
            if(RecordedFrames<31){Require(current==null,"Unexpected early capture");return;}
            Require(current!=null&&current.receipt.afterRecorded&&current.receipt.workFrame==workFrame,"Gather lacks matching completed cache dispatch");
            Require(raw.width==640&&raw.height==360&&fullSize==new Vector2Int(640,360)&&rays==8&&rayBias==.03f,"Frozen gather settings differ");
            Require(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&SystemInfo.graphicsUVStartsAtTop,"DX12 UV convention required");
            Require(raw.graphicsFormat==UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_SFloat,"Raw storage differs");
            var selections=new List<Selection>();var pixels=new List<Pair>();var unique=new HashSet<ulong>();
            var targets=new[]{new Vector3(0,.5f,.5f),new Vector3(.5f,.5f,0)};
            for(int owner=0;owner<2;owner++)
            {
                var target=targets[owner];var clip=vp*new Vector4(target.x,target.y,target.z,1);Require(clip.w>0,"Gather target behind camera");
                int centerX=Mathf.FloorToInt((clip.x/clip.w*.5f+.5f)*raw.width),centerY=Mathf.FloorToInt((1-(clip.y/clip.w*.5f+.5f))*raw.height);
                foreach(int dy in new[]{-2,0,2})foreach(int dx in new[]{-2,0,2})
                {
                    int x=centerX+dx,y=centerY+dy;Require(x>=2&&y>=2&&x<raw.width-2&&y<raw.height-2,"Gather target outside interior viewport");
                    Require(unique.Add(((ulong)(uint)y<<32)|(uint)x),"Gather selections overlap");
                    pixels.Add(new Pair{x=(uint)x,y=(uint)y});selections.Add(new Selection{id=(owner==0?"A":"B")+"_"+dx+"_"+dy,receiverOwner=owner==0?"A":"B",x=x,y=y,offsetX=dx,offsetY=dy,authoredTarget=new[]{target.x,target.y,target.z}});
                }
            }
            var receipt=current.receipt;receipt.width=raw.width;receipt.height=raw.height;receipt.fullWidth=fullSize.x;receipt.fullHeight=fullSize.y;
            receipt.rays=rays;receipt.groupCount=selections.Count;receipt.normalsOct=normalsOct;receipt.invVP=Matrix(invVP);receipt.vp=Matrix(vp);receipt.view=Matrix(view);
            receipt.rawFormat=raw.graphicsFormat.ToString();receipt.geometryFormat=geometry.graphicsFormat.ToString();receipt.materialFormat=material.graphicsFormat.ToString();
            receipt.depthFormat=depth.graphicsFormat.ToString();receipt.normalsFormat=normals.graphicsFormat.ToString();receipt.selection=selections.ToArray();
            int kernel=sampler.FindKernel("CSReferenceGatherInputs");var selected=Buffer(pixels.Count,8);selected.SetData(pixels.ToArray());var rows=Buffer(pixels.Count*8*6,16);
            cmd.SetComputeBufferParam(sampler,kernel,"_ReferencePixels",selected);cmd.SetComputeBufferParam(sampler,kernel,"_ReferenceGatherRows",rows);cmd.SetComputeIntParam(sampler,"_ReferencePixelCount",pixels.Count);
            cmd.SetComputeTextureParam(sampler,kernel,"_HLGI_Depth",depth);cmd.SetComputeTextureParam(sampler,kernel,"_HLGI_Normals",normals);
            cmd.SetComputeVectorParam(sampler,"_HLGI_Size",new Vector4(raw.width,raw.height,1f/raw.width,1f/raw.height));
            cmd.SetComputeVectorParam(sampler,"_HLGI_FullSize",new Vector4(fullSize.x,fullSize.y,1f/fullSize.x,1f/fullSize.y));
            cmd.SetComputeMatrixParam(sampler,"_HLGI_InvVP",invVP);cmd.SetComputeMatrixParam(sampler,"_HLGI_View",view);
            cmd.SetComputeIntParam(sampler,"_HLGI_NormalsOct",normalsOct?1:0);cmd.SetComputeIntParam(sampler,"_HLGI_FrameIndex",workFrame);cmd.SetComputeIntParam(sampler,"_HLGI_Rays",rays);
            cmd.SetComputeFloatParam(sampler,"_HLGI_RayBias",rayBias);cmd.SetComputeFloatParam(sampler,"_HLGI_GuideWeight",0);
            cmd.DispatchCompute(sampler,kernel,1,1,1);
            ReadBuffer(cmd,current,rows,"gather-inputs");ReadTexture(cmd,current,raw,"raw");ReadTexture(cmd,current,geometry,"geometry");ReadTexture(cmd,current,material,"material");
            receipt.gatherRecorded=true;Save(current);current=null;
        }
        catch(Exception error){Fail(current,error);}
        finally{RecordedFrames++;}
    }
    public static void Dispose()
    {
        AsyncGPUReadback.WaitAllRequests();foreach(var capture in captures)Require(capture.pending==0,"Feedback input readback did not drain");
        foreach(var buffer in allocated)buffer.Release();allocated.Clear();pendingOutputs.Clear();sampler=null;current=null;
        // Keep receipts and completion state available to the host's final result.
    }
}
