// Local GPU regression for the shipped temporal/filter/composite shaders; not runtime code.
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using System.Runtime.InteropServices;

public static partial class DenoiseRegressionEditor
{
    [Serializable] class Row { public string name; public float historyLength, spatialVariance, confidence, luminance; public bool passed; }
    [Serializable] class Report { public string unity, gpu, api; public bool passed; public Row[] cases; }
    static string Arg(string name,string fallback)
    { var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,name);return i>=0&&i+1<a.Length?a[i+1]:fallback; }
    static Texture2D Texture(Color value)
    {
        var t=new Texture2D(3,3,TextureFormat.RGBAFloat,false,true);
        var pixels=new Color[9];for(int i=0;i<9;i++)pixels[i]=value;
        t.SetPixels(pixels);t.Apply();return t;
    }
    static RenderTexture Target()
    { var t=new RenderTexture(3,3,0,RenderTextureFormat.ARGBHalf,RenderTextureReadWrite.Linear){enableRandomWrite=true};t.Create();return t; }
    static float[] Read(RenderTexture texture)
    {
        var request=AsyncGPUReadback.Request(texture,0,TextureFormat.RGBAFloat);request.WaitForCompletion();
        if(request.hasError)throw new Exception("Denoise regression readback failed");return request.GetData<float>().ToArray();
    }
    public static void RunLegacy()
    {
        var shader=Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
        int kernel=shader.FindKernel("CSTemporal");var input=Texture(new Color(0,0,0,1));
        // Oct(0,0), quantized geometric +Z, reversed-Z depth .5.
        var packed=new Color(0,0,8390657,.5f);var geometry=Texture(packed);
        var material=Texture(new Color(.5f,.5f,.5f,1));var zero=Texture(Color.clear);
        var output=Target();var moments=new RenderTexture(3,3,0,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear){enableRandomWrite=true};moments.Create();var rows=new List<Row>();
        using(var changes=new ComputeBuffer(1,48))
        try
        {
            changes.SetData(new float[12]);shader.SetBuffer(kernel,"_HLGI_ChangeRegions",changes);
            shader.SetInt("_HLGI_ChangeCount",0);shader.SetFloat("_HLGI_GlobalReactive",0);shader.SetFloat("_HLGI_GlobalGeometryChange",0);
            shader.SetVector("_HLGI_Size",new Vector4(3,3,1f/3,1f/3));shader.SetVector("_HLGI_FullSize",new Vector4(3,3,1f/3,1f/3));
            shader.SetMatrix("_HLGI_InvVP",Matrix4x4.identity);shader.SetMatrix("_HLGI_PreviousVP",Matrix4x4.identity);
            shader.SetMatrix("_HLGI_PreviousInvVP",Matrix4x4.identity);shader.SetMatrix("_HLGI_View",Matrix4x4.identity);
            shader.SetInt("_HLGI_HistoryValid",0);shader.SetInt("_HLGI_HasMotion",0);shader.SetInt("_HLGI_MaxHistory",32);
            shader.SetFloat("_HLGI_DepthThreshold",.015f);shader.SetFloat("_HLGI_NormalThreshold",.9f);shader.SetFloat("_HLGI_CurrentWeight",.25f);
            shader.SetTexture(kernel,"_HLGI_Input",input);shader.SetTexture(kernel,"_HLGI_Geometry",geometry);shader.SetTexture(kernel,"_HLGI_Material",material);
            shader.SetTexture(kernel,"_HLGI_History",zero);shader.SetTexture(kernel,"_HLGI_PreviousMoments",zero);
            shader.SetTexture(kernel,"_HLGI_PreviousGeometry",geometry);shader.SetTexture(kernel,"_HLGI_PreviousMaterial",material);
            shader.SetTexture(kernel,"_HLGI_Motion",zero);shader.SetTexture(kernel,"_HLGI_Output",output);shader.SetTexture(kernel,"_HLGI_MomentsOut",moments);
            foreach(string name in new[]{"measured-black","short-history-noise","bright-neighbor-half-storage","separate-plane","unknown-center"})
            {
                var pixels=new Color[9];var surfaces=new Color[9];
                for(int i=0;i<9;i++){pixels[i]=new Color(0,0,0,1);surfaces[i]=packed;}
                if(name!="measured-black")
                {
                    float value=name=="bright-neighbor-half-storage"?1000:1;
                    pixels[5]=new Color(value,value,value,1);
                }
                if(name=="separate-plane")surfaces[5].a=.8f;
                if(name=="unknown-center")pixels[4]=new Color(0,0,0,-1);
                input.SetPixels(pixels);input.Apply();geometry.SetPixels(surfaces);geometry.Apply();
                shader.Dispatch(kernel,1,1,1);var o=Read(output);var m=Read(moments);
                var row=new Row{name=name,luminance=o[16],confidence=o[19],historyLength=m[18],spatialVariance=m[19]};
                bool finite=Finite(o)&&Finite(m);
                row.passed=finite && row.luminance==0 && (name=="unknown-center"?
                    row.confidence==0&&row.historyLength==0&&row.spatialVariance==0:
                    row.confidence==1&&row.historyLength==1&&
                    (name=="bright-neighbor-half-storage"?row.spatialVariance==65504:
                     name=="short-history-noise"?row.spatialVariance>.09f&&row.spatialVariance<.11f:row.spatialVariance==0));
                rows.Add(row);
            }
        }
        finally
        {
            foreach(var t in new UnityEngine.Object[]{input,geometry,material,zero,output,moments})UnityEngine.Object.DestroyImmediate(t);
        }
        var report=new Report{unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString(),cases=rows.ToArray(),passed=rows.TrueForAll(r=>r.passed)};
        string path=Arg("-denoiseLegacyReport","I:/Unity test/Comparison/Evidence/local-denoise-02/legacy-regression.json");
        Directory.CreateDirectory(Path.GetDirectoryName(path));File.WriteAllText(path,JsonUtility.ToJson(report,true));
        if(!report.passed)throw new Exception("Denoise GPU regression failed: "+path);
        Debug.Log("DENOISE_GPU_REGRESSION_PASSED cases="+rows.Count);
    }
    [StructLayout(LayoutKind.Sequential)] struct IdentityRow
    { public Matrix4x4 pose; public uint keyLow,keyHigh,flags,group; }
    [StructLayout(LayoutKind.Sequential)] struct Candidate
    { public uint owner,flags,primitive; }
    [Serializable] class ContractRow
    {
        public string name,kernel,stage,rawOutput;
        public int frame;
        public bool passed;
        public float[] center,centerMoments;
        public float maximumError,meanLuminance,minimumHistory,maximumHistory;
        public float temporalVariance,spatialVariance,effectiveSigma;
    }
    [Serializable] class ContractReport
    {
        public string unity,gpu,api,error;
        public string scope="Synthetic shipped-kernel/storage contracts; R1/R2 are diagnostics, not real-scene acceptance.";
        public string radianceFormat,momentsFormat;
        public bool passed;
        public int size=17;
        public ContractRow[] cases;
    }
    // The fixture mirrors runtime storage and feedback: only unfiltered history
    // feeds the next frame; every filter iteration reads the same temporal moments.
    sealed class Fixture : IDisposable
    {
        internal const int Size=17,Count=Size*Size,Center=(8*Size+8)*4;
        internal readonly ComputeShader shader;
        internal readonly int kernel,filter;
        internal readonly bool identity;
        internal Texture2D input,geometry,material,zero,poison;
        internal RenderTexture identityNow,identityOld;
        internal RenderTexture[] history=new RenderTexture[2],moments=new RenderTexture[2],filtered=new RenderTexture[2];
        readonly List<UnityEngine.Object> owned=new List<UnityEngine.Object>();
        readonly ComputeBuffer changes,candidates,objects;
        internal int read;
        internal float[] last,lastMoments;
        internal static Color Gray(float x,float a=1) { return new Color(x,x,x,a); }
        internal static Color[] Fill(Color x) { var p=new Color[Count];for(int i=0;i<Count;i++)p[i]=x;return p; }
        internal static void Set(Texture2D t,Color[] p){t.SetPixels(p);t.Apply(false,false);}
        Texture2D Tex(TextureFormat format,Color color,int size=Size)
        {var t=new Texture2D(size,size,format,false,true);owned.Add(t);var pixels=new Color[size*size];Array.Fill(pixels,color);Set(t,pixels);return t;}
        RenderTexture Rt(RenderTextureFormat format,int size=Size)
        {var t=new RenderTexture(size,size,0,format,RenderTextureReadWrite.Linear){enableRandomWrite=true};t.Create();owned.Add(t);return t;}
        RenderTexture IdentityTexture(uint primitive)
        {
            var t=new RenderTexture(new RenderTextureDescriptor(Size,Size){graphicsFormat=GraphicsFormat.R32G32B32A32_UInt,depthBufferBits=0,enableRandomWrite=true,msaaSamples=1});t.Create();
            owned.Add(t);SetIdentity(t,primitive);return t;
        }
        internal void SetIdentity(RenderTexture t,uint primitive)
        {
            var upload=AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/ComparisonHarness/Editor/DenoiseFixture.compute");
            int k=upload.FindKernel("FillIdentity");upload.SetTexture(k,"Result",t);upload.SetInt("Primitive",(int)primitive);upload.Dispatch(k,(Size+7)/8,(Size+7)/8,1);
        }
        internal Fixture(bool useIdentity,RenderTextureFormat momentsFormat=RenderTextureFormat.ARGBFloat,ComputeShader source=null)
        {
            identity=useIdentity;shader=source?source:Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
            kernel=shader.FindKernel(identity?"CSTemporalIdentity":"CSTemporal");filter=shader.FindKernel("CSFilter");
            input=Tex(TextureFormat.RGBAHalf,Gray(1));geometry=Tex(TextureFormat.RGBAFloat,new Color(0,0,8390657,.5f));
            material=Tex(TextureFormat.RGBA32,new Color(.5f,.5f,.5f,1));zero=Tex(TextureFormat.RGBAFloat,Color.clear);
            poison=Tex(TextureFormat.RGBAFloat,new Color(1,float.PositiveInfinity,4,0));
            for(int i=0;i<2;i++){history[i]=Rt(RenderTextureFormat.ARGBHalf);moments[i]=Rt(momentsFormat);filtered[i]=Rt(RenderTextureFormat.ARGBHalf);}
            changes=new ComputeBuffer(1,48);changes.SetData(new float[12]);
            candidates=new ComputeBuffer(Count,12);var c=new Candidate[Count];for(int i=0;i<Count;i++)c[i]=new Candidate{owner=1,primitive=3};candidates.SetData(c);
            objects=new ComputeBuffer(1,80);objects.SetData(new[]{new IdentityRow{pose=Matrix4x4.identity,keyLow=7,keyHigh=11,flags=1,group=1}});
            if(identity){identityNow=IdentityTexture(3);identityOld=IdentityTexture(3);}
            Reset();
        }
        internal void Reset()
        {
            read=0;Set(input,Fill(Gray(1)));Set(geometry,Fill(new Color(0,0,8390657,.5f)));Set(material,Fill(new Color(.5f,.5f,.5f,1)));if(identity)SetIdentity(identityOld,3);
            var cmd=new CommandBuffer();foreach(var t in history){cmd.SetRenderTarget(t);cmd.ClearRenderTarget(false,true,Color.clear);}foreach(var t in moments){cmd.SetRenderTarget(t);cmd.ClearRenderTarget(false,true,Color.clear);}Graphics.ExecuteCommandBuffer(cmd);cmd.Release();
            shader.SetVector("_HLGI_Size",new Vector4(Size,Size,1f/Size,1f/Size));shader.SetVector("_HLGI_FullSize",new Vector4(Size,Size,1f/Size,1f/Size));
            foreach(string matrix in new[]{"_HLGI_InvVP","_HLGI_PreviousVP","_HLGI_PreviousInvVP","_HLGI_View"})shader.SetMatrix(matrix,Matrix4x4.identity);
            shader.SetInt("_HLGI_HasMotion",0);shader.SetInt("_HLGI_MaxHistory",32);shader.SetFloat("_HLGI_CurrentWeight",.25f);
            shader.SetFloat("_HLGI_DepthThreshold",.015f);shader.SetFloat("_HLGI_NormalThreshold",.9f);
            shader.SetInt("_HLGI_ChangeCount",0);shader.SetFloat("_HLGI_GlobalReactive",0);shader.SetFloat("_HLGI_GlobalGeometryChange",0);
            shader.SetBuffer(kernel,"_HLGI_ChangeRegions",changes);
            if(identity)
            {
                shader.SetTexture(kernel,"_HLGI_IdentityCurrent",identityNow);shader.SetTexture(kernel,"_HLGI_IdentityPrevious",identityOld);
                shader.SetBuffer(kernel,"_HLGI_IdentityCandidates",candidates);shader.SetBuffer(kernel,"_HLGI_IdentityObjects",objects);shader.SetInt("_HLGI_IdentityObjectCount",1);
            }
        }
        internal void Step(bool valid, bool poisonOld=false)
        {
            int write=1-read;shader.SetInt("_HLGI_HistoryValid",valid?1:0);
            shader.SetTexture(kernel,"_HLGI_Input",input);shader.SetTexture(kernel,"_HLGI_Geometry",geometry);shader.SetTexture(kernel,"_HLGI_Material",material);
            shader.SetTexture(kernel,"_HLGI_PreviousGeometry",geometry);shader.SetTexture(kernel,"_HLGI_PreviousMaterial",material);
            shader.SetTexture(kernel,"_HLGI_History",history[read]);shader.SetTexture(kernel,"_HLGI_PreviousMoments",poisonOld?(Texture)poison:moments[read]);
            shader.SetTexture(kernel,"_HLGI_Motion",zero);shader.SetTexture(kernel,"_HLGI_Output",history[write]);shader.SetTexture(kernel,"_HLGI_MomentsOut",moments[write]);
            shader.Dispatch(kernel,(Size+7)/8,(Size+7)/8,1);read=write;last=Read(history[read]);lastMoments=Read(moments[read]);
        }
        internal float[] Filter(int step,int index)
        {
            shader.SetTexture(filter,"_HLGI_Input",index==0?history[read]:filtered[1-(index%2)]);shader.SetTexture(filter,"_HLGI_Output",filtered[index%2]);
            shader.SetTexture(filter,"_HLGI_Geometry",geometry);shader.SetTexture(filter,"_HLGI_Material",material);shader.SetTexture(filter,"_HLGI_Moments",moments[read]);
            shader.SetInt("_HLGI_FilterStep",step);shader.Dispatch(filter,(Size+7)/8,(Size+7)/8,1);return Read(filtered[index%2]);
        }
        internal float[] RenderComposite(int mode=3,int fullSize=Size,Texture inputGi=null,Shader source=null)
        {
            var debugShader=source!=null?source:Shader.Find("Hidden/HybridLumenGI/Composite");if(debugShader==null)throw new Exception("Missing composite shader");
            var mat=new Material(debugShader);var normal=Tex(TextureFormat.RGBAFloat,new Color(0,0,1,1),fullSize);var depth=Tex(TextureFormat.RGBAFloat,Gray(.5f),fullSize);
            var emission=Tex(TextureFormat.RGBAFloat,Gray(0),fullSize);var target=Rt(RenderTextureFormat.ARGBFloat,fullSize);
            var diffuse=fullSize==Size?material:Tex(TextureFormat.RGBA32,new Color(.5f,.5f,.5f,1),fullSize);
            try
            {
                mat.SetTexture("_HLGI_GITexture",inputGi!=null?inputGi:history[read]);mat.SetTexture("_HLGI_Geometry",geometry);mat.SetTexture("_HLGI_Diffuse",diffuse);mat.SetTexture("_HLGI_Emission",emission);
                mat.SetTexture("_HLGI_Normals",normal);mat.SetTexture("_HLGI_Depth",depth);mat.SetTexture("_HLGI_CaptureDepth",depth);mat.SetTexture("_HLGI_Moments",moments[read]);
                mat.SetVector("_HLGI_Size",new Vector4(Size,Size,1f/Size,1f/Size));mat.SetMatrix("_HLGI_InvVP",Matrix4x4.identity);mat.SetFloat("_HLGI_DepthThreshold",.015f);mat.SetFloat("_HLGI_Intensity",1);mat.SetInt("_HLGI_Debug",mode);
                using(var cmd=new CommandBuffer()){cmd.SetRenderTarget(target);cmd.ClearRenderTarget(false,true,Color.clear);cmd.SetViewport(new Rect(0,0,fullSize,fullSize));cmd.DrawProcedural(Matrix4x4.identity,mat,1,MeshTopology.Triangles,3);Graphics.ExecuteCommandBuffer(cmd);}
                return Read(target);
            }
            finally{UnityEngine.Object.DestroyImmediate(mat);}
        }
        public void Dispose()
        {changes.Dispose();candidates.Dispose();objects.Dispose();foreach(var t in owned){if(t is RenderTexture rt)rt.Release();UnityEngine.Object.DestroyImmediate(t);}}
    }
    static bool Finite(float[] a){foreach(float x in a)if(float.IsNaN(x)||float.IsInfinity(x))return false;return true;}
    static string rawDirectory;
    static bool transitionCandidate;
    static float[] Pixel(float[] a){return new[]{a[Fixture.Center],a[Fixture.Center+1],a[Fixture.Center+2],a[Fixture.Center+3]};}
    static ContractRow Observe(List<ContractRow> rows,Fixture f,string name,int frame,string stage,float[] values=null)
    {
        var a=values??f.last;var r=new ContractRow{name=name,kernel=f.identity?"CSTemporalIdentity":"CSTemporal",frame=frame,stage=stage,passed=Finite(a)&&Finite(f.lastMoments),center=Pixel(a),centerMoments=Pixel(f.lastMoments),minimumHistory=float.MaxValue};
        r.temporalVariance=Mathf.Max(r.centerMoments[1]-r.centerMoments[0]*r.centerMoments[0],0);r.spatialVariance=r.centerMoments[3];
        float effective=r.centerMoments[2]<4?Mathf.Max(r.temporalVariance,r.spatialVariance*(4/Mathf.Max(r.centerMoments[2],1))):r.temporalVariance;
        r.effectiveSigma=Mathf.Max(Mathf.Sqrt(effective)*4,.05f);
        if(transitionCandidate&&r.centerMoments[2]<4){float temporalSigma=Mathf.Max(Mathf.Sqrt(r.temporalVariance)*4,.05f);r.effectiveSigma=Mathf.Lerp(temporalSigma,r.effectiveSigma,Mathf.Clamp01((4-r.centerMoments[2])/3));}
        r.rawOutput=r.kernel+"-"+name+"-"+frame+"-"+stage;
        foreach(var pair in new[]{("output",a),("moments",f.lastMoments)})using(var writer=new BinaryWriter(File.Create(Path.Combine(rawDirectory,r.rawOutput+"-"+pair.Item1+".rgba32f"))))foreach(float v in pair.Item2)writer.Write(v);
        for(int i=0;i<Fixture.Count;i++){r.meanLuminance+=a[i*4]/Fixture.Count;r.minimumHistory=Mathf.Min(r.minimumHistory,f.lastMoments[i*4+2]);r.maximumHistory=Mathf.Max(r.maximumHistory,f.lastMoments[i*4+2]);}
        rows.Add(r);Require(r,r.passed,"nonfinite stored output");return r;
    }
    static void Require(ContractRow row,bool pass,string reason)
    {row.passed&=pass;if(!pass)throw new Exception(row.kernel+"/"+row.name+"/"+row.stage+"/"+row.frame+": "+reason);}
    static void Uniform(ContractRow r,Fixture f,float value,float count,float confidence=1)
    {
        for(int i=0;i<Fixture.Count;i++)
        {
            for(int c=0;c<3;c++)Require(r,Mathf.Abs(f.last[i*4+c]-value)<=Mathf.Max(.001f,Mathf.Abs(value)*.001f),"radiance changed");
            Require(r,Mathf.Abs(f.last[i*4+3]-confidence)<.001f,"confidence mismatch");
            Require(r,Mathf.Abs(f.lastMoments[i*4+2]-count)<.001f,"history length mismatch");
            float expected=count>0?value:0;
            Require(r,Mathf.Abs(f.lastMoments[i*4]-expected)<=Mathf.Max(.001f,Mathf.Abs(expected)*.000003f),"first moment mismatch");
            Require(r,Mathf.Abs(f.lastMoments[i*4+1]-expected*expected)<=Mathf.Max(.001f,expected*expected*.000003f),"second moment mismatch");
        }
    }
    static void DebugCheck(List<ContractRow> rows,Fixture f,string name)
    {
        var a=f.RenderComposite();var r=Observe(rows,f,name,0,"actual-composite-debug",a);
        for(int i=0;i<Fixture.Count;i++)
        {
            float v=f.lastMoments[i*4+3],expected=v/(1+v);
            for(int c=0;c<3;c++)r.maximumError=Mathf.Max(r.maximumError,Mathf.Abs(a[i*4+c]-expected));
            Require(r,a[i*4+3]>.99f,"debug pixel did not render");
        }
        Require(r,r.maximumError<=.002f,"debug variance mapping mismatch");
    }
    static void Contracts(List<ContractRow> rows,bool identity)
    {
        using(var f=new Fixture(identity))
        {
            foreach(float value in new[]{255f,256f,1000f,65504f})
            {
                f.Reset();Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(value)));
                for(int frame=1;frame<=5;frame++){f.Step(frame>1);var r=Observe(rows,f,"hdr-"+value,frame,"temporal");Uniform(r,f,value,frame);}
            }
            foreach(string test in new[]{"unknown-retains","unknown-clears","nonfinite-old","unknown-Ng","reset","reactive","max-history-one","identity-mismatch"})
            {
                if(test=="identity-mismatch"&&!identity)continue;
                f.Reset();for(int frame=1;frame<=4;frame++)f.Step(frame>1);
                if(test.StartsWith("unknown-")&&test!="unknown-Ng")Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(0,-1)));
                if(test=="unknown-Ng"){Fixture.Set(f.geometry,Fixture.Fill(new Color(0,0,-1,.5f)));Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(1000)));}
                if(test=="reactive")f.shader.SetFloat("_HLGI_GlobalReactive",1);
                if(test=="max-history-one")f.shader.SetInt("_HLGI_MaxHistory",1);
                if(test=="identity-mismatch"){f.SetIdentity(f.identityOld,4);Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(0,-1)));}
                f.Step(test!="reset"&&test!="unknown-clears",test=="nonfinite-old");var row=Observe(rows,f,test,5,"temporal");
                float expectedHistory=test=="unknown-retains"?4:test=="reactive"?2:(test=="unknown-clears"||test=="identity-mismatch")?0:1;
                Uniform(row,f,test=="unknown-Ng"?1000:expectedHistory==0?0:1,expectedHistory,expectedHistory==0?0:1);
            }
            foreach(bool unknown in new[]{false,true})
            {
                f.Reset();Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(unknown?1:0)));if(unknown){var p=Fixture.Fill(Fixture.Gray(1));p[Fixture.Center/4]=Fixture.Gray(0,-1);Fixture.Set(f.input,p);}
                f.Step(false);var r=Observe(rows,f,unknown?"unknown-center":"measured-black",1,"temporal");
                if(unknown)for(int c=0;c<4;c++)Require(r,f.last[Fixture.Center+c]==0&&f.lastMoments[Fixture.Center+c]==0,"unknown center temporal state changed");
                if(!unknown)Uniform(r,f,0,1);
                for(int index=0;index<3;index++){var a=f.Filter(1<<index,index);var rr=Observe(rows,f,unknown?"unknown-center":"measured-black",1,"filter-"+(1<<index),a);for(int c=0;c<4;c++)Require(rr,Mathf.Abs(a[Fixture.Center+c]-(c==3&&!unknown?1:0))<.001f,"black/unknown center changed");}
            }
            f.Reset();for(int frame=1;frame<=5;frame++)f.Step(frame>1);DebugCheck(rows,f,"uniform-accepted");
            var final=f.RenderComposite(0);var finalRow=Observe(rows,f,"uniform-accepted",5,"actual-composite-final",final);
            float reflectance=f.material.GetPixel(8,8).r;
            for(int i=0;i<Fixture.Count;i++){for(int c=0;c<3;c++)Require(finalRow,Mathf.Abs(final[i*4+c]-reflectance)<.002f,"Final radiance changed");Require(finalRow,final[i*4+3]==0,"Final alpha changed");}
            // R1/R2: controlled inputs, not a physical-scene reference. History feedback is never filtered.
            foreach(string boundary in new[]{"noise","coplanar-edge","parallel-plane","material-edge","normal-edge"})
            {
                f.Reset();var pixels=Fixture.Fill(Fixture.Gray(0));var g=Fixture.Fill(new Color(0,0,8390657,.5f));var m=Fixture.Fill(new Color(.5f,.5f,.5f,1));
                for(int y=0;y<Fixture.Size;y++)for(int x=0;x<Fixture.Size;x++)
                {
                    int i=y*Fixture.Size+x;float value=((x+y)%2==0?.25f:.75f)+(boundary!="noise"&&x>=9?3:0);pixels[i]=Fixture.Gray(value);
                    if(x>=9){if(boundary=="parallel-plane")g[i].a=.53f;if(boundary=="material-edge")m[i]=new Color(.9f,.1f,.1f,1);if(boundary=="normal-edge")g[i]=new Color(1,0,8392704,.5f);}
                }
                Fixture.Set(f.input,pixels);Fixture.Set(f.geometry,g);Fixture.Set(f.material,m);
                for(int frame=1;frame<=5;frame++)
                {
                    f.Step(frame>1);Observe(rows,f,boundary,frame,"temporal");
                    for(int index=0;index<3;index++)
                    {
                        var a=f.Filter(1<<index,index);var r=Observe(rows,f,boundary,frame,"filter-"+(1<<index),a);
                        for(int i=0;i<Fixture.Count;i++)Require(r,a[i*4+3]==f.last[i*4+3],"filter confidence changed");
                    }
                    if(boundary=="noise"&&frame==1)DebugCheck(rows,f,"noisy-rejected");
                }
            }
        }
    }
    public static void Run()
    {
        var rows=new List<ContractRow>();var report=new ContractReport{unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString(),radianceFormat="R16G16B16A16_SFloat",momentsFormat="R32G32B32A32_SFloat"};
        string path=Arg("-denoiseReport","I:/Unity test/Comparison/Evidence/local-denoise-02/gpu-contracts.json");
        rawDirectory=Path.Combine(Path.GetDirectoryName(path),"raw-contracts");Directory.CreateDirectory(rawDirectory);
        try{RunLegacy();Contracts(rows,false);Contracts(rows,true);report.passed=true;}
        catch(Exception e){report.error=e.ToString();throw;}
        finally{report.cases=rows.ToArray();Directory.CreateDirectory(Path.GetDirectoryName(path));File.WriteAllText(path,JsonUtility.ToJson(report,true));}
        Debug.Log("DENOISE_CONTRACTS_PASSED rows="+rows.Count);
    }
    public static void RunBaseline()
    {
        string path=Arg("-denoiseBaseline","I:/Unity test/Comparison/Evidence/local-denoise-02/baseline");Directory.CreateDirectory(path);
        var lines=new List<string>{"frame,radianceFormat,momentsFormat,nonfiniteRadiance,nonfiniteMoments,centerRadiance,centerSecondMoment,centerHistory"};
        using(var f=new Fixture(false,RenderTextureFormat.ARGBHalf))
        {
            Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(1000)));
            for(int frame=1;frame<=5;frame++)
            {
                f.Step(frame>1);int badH=0,badM=0;foreach(float v in f.last)if(!float.IsFinite(v))badH++;foreach(float v in f.lastMoments)if(!float.IsFinite(v))badM++;
                lines.Add(string.Join(",",frame,f.history[f.read].graphicsFormat,f.moments[f.read].graphicsFormat,badH,badM,f.last[Fixture.Center],f.lastMoments[Fixture.Center+1],f.lastMoments[Fixture.Center+2]));
                foreach(var pair in new[]{("history",f.last),("moments",f.lastMoments)})using(var writer=new BinaryWriter(File.Create(Path.Combine(path,"frame-"+frame+"-"+pair.Item1+".rgba32f"))))foreach(float v in pair.Item2)writer.Write(v);
            }
        }
        File.WriteAllLines(Path.Combine(path,"storage.csv"),lines);Debug.Log("DENOISE_BASELINE_CAPTURED "+path);
    }
    public static void PlayChecked(){Run();RuntimeAuditEditor.Play();}
    public static void VerifyFormats()
    {
        using(var f=new Fixture(false))
        {
            var rows=new List<string>{"target,created,actualGraphicsFormat"};
            for(int i=0;i<2;i++)
            {
                if(!f.history[i].IsCreated()||!f.moments[i].IsCreated()||f.history[i].graphicsFormat!=GraphicsFormat.R16G16B16A16_SFloat||f.moments[i].graphicsFormat!=GraphicsFormat.R32G32B32A32_SFloat)throw new Exception("Actual history/moments format mismatch");
                rows.Add("history"+i+",true,"+f.history[i].graphicsFormat);rows.Add("moments"+i+",true,"+f.moments[i].graphicsFormat);
            }
            string path="I:/Unity test/Comparison/Evidence/local-denoise-02/actual-formats.csv";File.WriteAllLines(path,rows);Debug.Log("DENOISE_FORMATS_VERIFIED");
        }
    }
    static void FilterGuard(List<ContractRow> rows,Fixture f,string name,int frame,float value,float confidence=1,bool centerOnly=false)
    {
        Observe(rows,f,name,frame,"temporal");
        for(int index=0;index<3;index++)
        {
            var a=f.Filter(1<<index,index);var row=Observe(rows,f,name,frame,"filter-"+(1<<index),a);
            for(int i=0;i<Fixture.Count;i++)
            {
                Require(row,a[i*4+3]==f.last[i*4+3],"filter changed confidence");
                if(centerOnly&&i!=Fixture.Center/4)continue;
                for(int c=0;c<3;c++)Require(row,Mathf.Abs(a[i*4+c]-value)<=Mathf.Max(.001f,Mathf.Abs(value)*.001f),"constant guard changed radiance");
                Require(row,Mathf.Abs(a[i*4+3]-confidence)<.001f,"guard confidence mismatch");
            }
        }
    }
    static void Transition(List<ContractRow> rows,bool identity)
    {
        using(var f=new Fixture(identity))
        {
            foreach(string signal in new[]{"fixed-checker","changing-noise","signal-edge","parallel-bright","parallel-control"})
            {
                f.Reset();f.shader.SetInt("_HLGI_MaxHistory",64);
                var geometry=Fixture.Fill(new Color(0,0,8390657,.5f));
                if(signal.StartsWith("parallel"))for(int y=0;y<Fixture.Size;y++)for(int x=9;x<Fixture.Size;x++)geometry[y*Fixture.Size+x].a=.53f;
                Fixture.Set(f.geometry,geometry);
                for(int frame=1;frame<=64;frame++)
                {
                    var pixels=new Color[Fixture.Count];
                    for(int y=0;y<Fixture.Size;y++)for(int x=0;x<Fixture.Size;x++)
                    {
                        int i=y*Fixture.Size+x;float v=(x+y)%2==0?.25f:.75f;
                        if(signal=="changing-noise")
                        {
                            uint bits=unchecked((uint)(0x48b1+frame*289+i)*747796405u+2891336453u);
                            bits=((bits>>((int)(bits>>28)+4))^bits)*277803737u;bits=(bits>>22)^bits;
                            v=(bits&1)==0?.25f:.75f;
                        }
                        if(signal=="signal-edge")v=x<9?.5f:3.5f;
                        if(signal=="parallel-bright"&&x>=9)v+=3;
                        pixels[i]=Fixture.Gray(v);
                    }
                    Fixture.Set(f.input,pixels);f.Step(frame>1);
                    if(frame<=8||frame==32||frame==64)
                    {
                        var row=Observe(rows,f,signal,frame,"temporal");Require(row,row.minimumHistory==frame&&row.maximumHistory==frame,"unexpected history progression");
                        for(int index=0;index<3;index++)
                        {
                            var a=f.Filter(1<<index,index);var filteredRow=Observe(rows,f,signal,frame,"filter-"+(1<<index),a);
                            for(int i=0;i<Fixture.Count;i++)Require(filteredRow,a[i*4+3]==f.last[i*4+3],"filter changed confidence");
                        }
                    }
                    else if(!Finite(f.last)||!Finite(f.lastMoments))throw new Exception("Nonfinite intervening temporal frame");
                }
            }
            foreach(float value in new[]{0f,1000f,65504f})
            {
                f.Reset();Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(value)));f.Step(false);FilterGuard(rows,f,"constant-"+value,1,value);
            }
            foreach(string name in new[]{"unknown-center","unknown-retains","reset","identity-reject","max-history-one","reactive"})
            {
                if(name=="identity-reject"&&!identity)continue;
                f.Reset();for(int i=1;i<=4;i++)f.Step(i>1);
                if(name=="unknown-center"){var p=Fixture.Fill(Fixture.Gray(1));p[Fixture.Center/4]=Fixture.Gray(0,-1);Fixture.Set(f.input,p);}
                if(name=="unknown-retains"||name=="identity-reject")Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(0,-1)));
                if(name=="identity-reject")f.SetIdentity(f.identityOld,4);
                if(name=="max-history-one")f.shader.SetInt("_HLGI_MaxHistory",1);
                if(name=="reactive")f.shader.SetFloat("_HLGI_GlobalReactive",1);
                f.Step(name!="reset"&&name!="unknown-center");
                bool invalid=name=="unknown-center"||name=="identity-reject";
                FilterGuard(rows,f,name,5,invalid?0:1,invalid?0:1,name=="unknown-center");
            }
        }
    }
    public static void RunTransition()
    {
        string label=Arg("-transitionLabel","baseline");transitionCandidate=label=="candidate";
        string path="I:/Unity test/Comparison/Evidence/local-denoise-03/"+label+"/gpu-transition.json";
        rawDirectory=Path.Combine(Path.GetDirectoryName(path),"raw");Directory.CreateDirectory(rawDirectory);
        var rows=new List<ContractRow>();var report=new ContractReport{unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString(),radianceFormat="expected R16G16B16A16_SFloat",momentsFormat="expected R32G32B32A32_SFloat",scope="One short-history candidate; CPU-derived sigma; fixed-signal and stochastic-noise interpretations scored separately."};
        try{Transition(rows,false);Transition(rows,true);report.passed=true;}
        catch(Exception e){report.error=e.ToString();throw;}
        finally{report.cases=rows.ToArray();File.WriteAllText(path,JsonUtility.ToJson(report,true));}
        Debug.Log("DENOISE_TRANSITION_CAPTURED label="+label+" rows="+rows.Count);
    }
}
