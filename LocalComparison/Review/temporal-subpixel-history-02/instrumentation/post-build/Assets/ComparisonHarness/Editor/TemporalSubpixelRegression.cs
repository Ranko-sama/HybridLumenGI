// One bounded actual-kernel comparison. Reuses the existing fixture and readback.
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static partial class DenoiseRegressionEditor
{
    const int SubFullWidth=25,SubFullHeight=23;
    const double SubRadianceBound=.0009,SubMomentBound=.000002;
    [Serializable] sealed class SubpixelRow
    {
        public string name;public bool identity,passed,exactFallback;
        public Vector2 previousUv;public float[] baseline,baselineMoments,candidate,candidateMoments;
        public double expectedBaseline,expectedCandidate,expectedMoment1,expectedMoment2,expectedLength;
        public double baselineError,candidateError;public string failure;
    }
    [Serializable] sealed class SubpixelReport
    {
        public bool passed;public string error,unity,gpu,api;
        public string scope="One actual Unity temporal-kernel batch; same fixed inputs, no Player, scene flicker or broad denoise acceptance";
        public int giWidth=17,giHeight=17,fullWidth=SubFullWidth,fullHeight=SubFullHeight;
        public double radianceErrorBound=SubRadianceBound,momentErrorBound=SubMomentBound;
        public double[] baselineRmse,candidateRmse;public SubpixelRow[] rows;
    }
    sealed class SubpixelCase
    {
        internal string name;internal Vector2 uv;internal bool constant,unequal,fallback,unknown,noGeometry,nearestInvalid;
        internal string boundary;
    }
    static double SubCenter(int index,int full)=>
        (Math.Floor((2.0*index+1)*full/(2*Fixture.Size))+.5)/full;
    static int SubNearest(double uv,int full)
    {
        int best=0;double distance=double.PositiveInfinity;
        for(int i=0;i<Fixture.Size;i++){double d=Math.Abs(SubCenter(i,full)-uv);if(d<distance){best=i;distance=d;}}return best;
    }
    static void SubBracket(double uv,int full,out int lo,out int hi,out double fraction)
    {
        lo=0;hi=Fixture.Size-1;
        for(int i=0;i<Fixture.Size;i++)if(SubCenter(i,full)<=uv)lo=i;
        for(int i=Fixture.Size-1;i>=0;i--)if(SubCenter(i,full)>=uv)hi=i;
        if(uv<=SubCenter(0,full))lo=hi=0;
        if(uv>=SubCenter(Fixture.Size-1,full))lo=hi=Fixture.Size-1;
        fraction=lo==hi?0:(uv-SubCenter(lo,full))/(SubCenter(hi,full)-SubCenter(lo,full));
    }
    static double SubField(int x,int y,bool constant)=>constant?1:
        1+.07*(SubCenter(x,SubFullWidth)-.5)+.005*(SubCenter(y,SubFullHeight)-.5);
    static double SubLength(int x,int y,bool unequal)=>!unequal?16:x==7&&y==8?4:x==7&&y==7?6:x==6&&y==8?9:16;
    static Vector2 SubInterior(double x)=>new Vector2((float)(SubCenter(6,SubFullWidth)*(1-x)+SubCenter(7,SubFullWidth)*x),
        (float)(SubCenter(7,SubFullHeight)*.625+SubCenter(8,SubFullHeight)*.375));
    static List<SubpixelCase> SubCases(bool identity)
    {
        var result=new List<SubpixelCase>();
        for(int i=0;i<8;i++)result.Add(new SubpixelCase{name="linear-"+i,uv=SubInterior((2*i+1)/16.0)});
        result.Add(new SubpixelCase{name="constant",uv=SubInterior(.1875),constant=true});
        result.Add(new SubpixelCase{name="minimum-history-length",uv=SubInterior(.1875),constant=true,unequal=true});
        result.Add(new SubpixelCase{name="duplicate-edge",uv=new Vector2(.005f,.005f),fallback=true});
        foreach(string boundary in identity?new[]{"depth","history","identity"}:new[]{"depth","history"})
            result.Add(new SubpixelCase{name=boundary+"-boundary",uv=SubInterior(.1875),boundary=boundary,fallback=true});
        result.Add(new SubpixelCase{name="invalid-nearest",uv=SubInterior(.1875),nearestInvalid=true,fallback=true});
        result.Add(new SubpixelCase{name="unknown-current",uv=SubInterior(.1875),unknown=true,fallback=true});
        result.Add(new SubpixelCase{name="unknown-geometric-normal",uv=SubInterior(.1875),noGeometry=true,fallback=true});
        return result;
    }
    static void SubUpload(RenderTexture destination,Color[] pixels,TextureFormat format)
    {
        var texture=new Texture2D(Fixture.Size,Fixture.Size,format,false,true);
        try{texture.SetPixels(pixels);texture.Apply(false,false);Graphics.CopyTexture(texture,destination);}
        finally{UnityEngine.Object.DestroyImmediate(texture);}
    }
    static void SubExecute(Fixture f,SubpixelCase test,ComputeBuffer fullCandidates)
    {
        f.Reset();f.shader.SetVector("_HLGI_FullSize",new Vector4(SubFullWidth,SubFullHeight,1f/SubFullWidth,1f/SubFullHeight));
        var inverse=Matrix4x4.Scale(new Vector3(.01f,.01f,1));var previous=Matrix4x4.Scale(new Vector3(100,100,1));
        var currentUv=new Vector2((float)SubCenter(8,SubFullWidth),(float)SubCenter(8,SubFullHeight));
        previous.m03=2*(test.uv.x-currentUv.x);previous.m13=-2*(test.uv.y-currentUv.y);
        f.shader.SetMatrix("_HLGI_InvVP",inverse);f.shader.SetMatrix("_HLGI_PreviousVP",previous);f.shader.SetMatrix("_HLGI_PreviousInvVP",previous.inverse);
        if(f.identity)f.shader.SetBuffer(f.kernel,"_HLGI_IdentityCandidates",fullCandidates);
        var history=new Color[Fixture.Count];var moments=new Color[Fixture.Count];
        for(int y=0;y<Fixture.Size;y++)for(int x=0;x<Fixture.Size;x++)
        {
            double h=SubField(x,y,test.constant);int i=y*Fixture.Size+x;
            history[i]=Fixture.Gray((float)h);moments[i]=new Color((float)h,(float)(h*h),(float)SubLength(x,y,test.unequal),0);
        }
        const int boundaryPixel=8*Fixture.Size+7;
        if(test.boundary=="history")history[boundaryPixel].a=0;
        if(test.nearestInvalid)moments[SubNearest(test.uv.y,SubFullHeight)*Fixture.Size+SubNearest(test.uv.x,SubFullWidth)].b=0;
        if(test.boundary=="depth")
        {var geometry=Fixture.Fill(new Color(0,0,8390657,.5f));geometry[boundaryPixel].a=.8f;Fixture.Set(f.geometry,geometry);}
        if(test.noGeometry)
        {var geometry=Fixture.Fill(new Color(0,0,8390657,.5f));geometry[Fixture.Center/4].b=-1;Fixture.Set(f.geometry,geometry);}
        if(test.unknown)
        {var input=Fixture.Fill(Fixture.Gray(1));input[Fixture.Center/4]=Fixture.Gray(0,-1);Fixture.Set(f.input,input);}
        if(test.boundary=="identity")
        {
            var upload=AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/ComparisonHarness/Editor/DenoiseFixture.compute");
            int k=upload.FindKernel("SetIdentityPixel");upload.SetTexture(k,"Result",f.identityOld);upload.SetInts("TargetPixel",7,8);upload.SetInt("Primitive",4);upload.Dispatch(k,1,1,1);
        }
        SubUpload(f.history[0],history,TextureFormat.RGBAHalf);SubUpload(f.moments[0],moments,TextureFormat.RGBAFloat);
        f.Step(true);
    }
    static float[] SubCenterValues(float[] values)
    {var result=new float[4];Array.Copy(values,Fixture.Center,result,0,4);return result;}
    static bool SubSameBits(float[] a,float[] b)
    {for(int i=0;i<a.Length;i++)if(BitConverter.ToInt32(BitConverter.GetBytes(a[i]),0)!=BitConverter.ToInt32(BitConverter.GetBytes(b[i]),0))return false;return true;}
    static void SubReference(SubpixelCase test,bool interpolate,out double radiance,out double first,out double second,out double length)
    {
        if(test.nearestInvalid||test.noGeometry){radiance=first=second=length=1;return;}
        int nearestX=SubNearest(test.uv.x,SubFullWidth),nearestY=SubNearest(test.uv.y,SubFullHeight);
        double h=SubField(nearestX,nearestY,test.constant),m2=h*h,n=SubLength(nearestX,nearestY,test.unequal);
        if(interpolate&&!test.fallback)
        {
            SubBracket(test.uv.x,SubFullWidth,out int x0,out int x1,out double fx);SubBracket(test.uv.y,SubFullHeight,out int y0,out int y1,out double fy);
            h=m2=0;n=double.PositiveInfinity;
            for(int y=0;y<2;y++)for(int x=0;x<2;x++)
            {
                double weight=(x==0?1-fx:fx)*(y==0?1-fy:fy);if(weight<=0)continue;
                int ix=x==0?x0:x1,iy=y==0?y0:y1;double value=SubField(ix,iy,test.constant);
                h+=weight*value;m2+=weight*value*value;n=Math.Min(n,SubLength(ix,iy,test.unequal));
            }
        }
        if(test.unknown){radiance=first=h;second=m2;length=n;return;}
        length=Math.Min(n+1,32);double alpha=Math.Max(.25,1/length);
        radiance=first=h*(1-alpha)+alpha;second=m2*(1-alpha)+alpha;
    }
    static void SubRequire(bool ok,string reason){if(!ok)throw new InvalidOperationException(reason);}
    public static void RunSubpixel()
    {
        string directory=Arg("-subpixelOutput","");SubRequire(Path.IsPathRooted(directory),"Absolute output directory required");
        Directory.CreateDirectory(directory);string path=Path.Combine(directory,"result.json");SubRequire(!File.Exists(path),"Unique compute batch already recorded");
        var rows=new List<SubpixelRow>();var report=new SubpixelReport{unity=Application.unityVersion,gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString(),baselineRmse=new double[2],candidateRmse=new double[2]};
        try
        {
            SubRequire(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&SystemInfo.graphicsUVStartsAtTop,"Fixed DX12 UV contract required");
            var baseline=AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/ComparisonHarness/Editor/TemporalSubpixelBaseline/Temporal.compute");
            var candidate=AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/ComparisonHarness/Editor/TemporalSubpixelCandidate/Temporal.compute");
            SubRequire(baseline&&candidate,"Frozen actual kernels missing");
            for(int mode=0;mode<2;mode++)
            using(var oldFixture=new Fixture(mode==1,RenderTextureFormat.ARGBFloat,baseline))
            using(var newFixture=new Fixture(mode==1,RenderTextureFormat.ARGBFloat,candidate))
            using(var candidates=new ComputeBuffer(SubFullWidth*SubFullHeight,12))
            {
                var values=new Candidate[SubFullWidth*SubFullHeight];for(int i=0;i<values.Length;i++)values[i]=new Candidate{owner=1,primitive=3};candidates.SetData(values);
                double oldSquared=0,newSquared=0;int linearCount=0;
                foreach(var test in SubCases(mode==1))
                {
                    SubExecute(oldFixture,test,candidates);SubExecute(newFixture,test,candidates);
                    var row=new SubpixelRow{name=test.name,identity=mode==1,previousUv=test.uv,baseline=SubCenterValues(oldFixture.last),baselineMoments=SubCenterValues(oldFixture.lastMoments),
                        candidate=SubCenterValues(newFixture.last),candidateMoments=SubCenterValues(newFixture.lastMoments)};rows.Add(row);
                    SubReference(test,false,out double oldExpected,out double oldFirst,out double oldSecond,out double oldLength);
                    SubReference(test,true,out double expected,out double first,out double second,out double length);
                    row.expectedBaseline=oldExpected;row.expectedCandidate=expected;row.expectedMoment1=first;row.expectedMoment2=second;row.expectedLength=length;
                    try
                    {
                        for(int c=0;c<3;c++)
                        {SubRequire(Math.Abs(row.baseline[c]-oldExpected)<=SubRadianceBound,"Baseline final radiance differs from nearest oracle");SubRequire(Math.Abs(row.candidate[c]-expected)<=SubRadianceBound,"Candidate final radiance differs from declared oracle");}
                        SubRequire(Math.Abs(row.baselineMoments[0]-oldFirst)<=SubMomentBound&&Math.Abs(row.baselineMoments[1]-oldSecond)<=SubMomentBound&&row.baselineMoments[2]==oldLength,"Baseline moments/length differ from oracle");
                        SubRequire(Math.Abs(row.candidateMoments[0]-first)<=SubMomentBound&&Math.Abs(row.candidateMoments[1]-second)<=SubMomentBound&&row.candidateMoments[2]==length,"Candidate moments/length differ from oracle");
                        SubRequire(row.baseline[3]==1&&row.candidate[3]==1&&Math.Abs(row.baselineMoments[3])<=SubMomentBound&&Math.Abs(row.candidateMoments[3])<=SubMomentBound,"Confidence/spatial moments changed");
                        row.exactFallback=SubSameBits(row.baseline,row.candidate)&&SubSameBits(row.baselineMoments,row.candidateMoments);
                        if(test.fallback)SubRequire(row.exactFallback,"Incomplete support or preserved path failed exact nearest fallback");
                        if(test.name.StartsWith("linear-"))
                        {row.baselineError=row.baseline[0]-expected;row.candidateError=row.candidate[0]-expected;oldSquared+=row.baselineError*row.baselineError;newSquared+=row.candidateError*row.candidateError;linearCount++;}
                        row.passed=true;
                    }
                    catch(Exception e){row.failure=e.Message;throw new InvalidOperationException(test.name+" identity="+(mode==1)+": "+e.Message,e);}
                }
                report.baselineRmse[mode]=Math.Sqrt(oldSquared/linearCount);report.candidateRmse[mode]=Math.Sqrt(newSquared/linearCount);
                SubRequire(linearCount==8&&report.baselineRmse[mode]>0&&report.candidateRmse[mode]<=.5*report.baselineRmse[mode],"No declared useful subpixel improvement");
            }
            report.passed=true;
        }
        catch(Exception e){report.error=e.ToString();throw;}
        finally{report.rows=rows.ToArray();File.WriteAllText(path,JsonUtility.ToJson(report,true));}
        Debug.Log("TEMPORAL_SUBPIXEL_CONTRACT_PASSED");
    }
}
