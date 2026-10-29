// Finite native-storage check; uses the existing fixture and complete shipped kernels.
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

public static partial class DenoiseRegressionEditor
{
    [Serializable] sealed class ReactiveLimitRow
    {
        public string name,kernel,stage,raw;
        public int maxHistory,warmupFrames;
        public bool passed;
        public float[] center,centerMoments;
        public double expectedStoredRadiance,expectedMean,expectedSecond;
        public int expectedHistory;
    }
    [Serializable] sealed class ReactiveLimitReport
    {
        public string unity,gpu,api,error,computePath,computeSha256,kernelsPath,kernelsSha256;
        public string inputFormat,historyFormat,momentsFormat,geometryFormat,identityFormat;
        public bool passed;
        public int actualTemporalDispatches;
        public string scope="Complete current CSTemporal/CSTemporalIdentity on real Unity GPU textures; fixed uniform geometry and synthetic signals, not scene motion or whole-image quality acceptance.";
        public ReactiveLimitRow[] cases;
    }
    sealed class ReactiveLimitCase
    {
        internal string name;
        internal int maximum,warmup,eventAge,recoveryAge;
        internal bool reactive,unknown,invalid;
        internal double eventAlpha,recoveryAlpha;
    }
    [StructLayout(LayoutKind.Explicit)] struct ReactiveLimitBits
    { [FieldOffset(0)] internal float value; [FieldOffset(0)] internal uint bits; }

    static void ReactiveLimitRequire(bool condition,string reason)
    {if(!condition)throw new InvalidOperationException("Reactive history limit: "+reason);}
    static string ReactiveLimitHash(string path)
    {using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(path))).Replace("-","").ToLowerInvariant();}
    static float ReactiveLimitStored(double value)
    {
        // All declared values are normal positive [1,2). D3D FLOAT narrowing
        // truncates toward zero: retain the ten binary16 fraction bits.
        ReactiveLimitRequire(value>=1&&value<2&&!double.IsNaN(value),"oracle storage domain");
        var encoded=new ReactiveLimitBits{value=(float)value};encoded.bits&=0xffffe000u;return encoded.value;
    }
    static void ReactiveLimitWrite(string path,float[] values)
    {using(var output=new BinaryWriter(File.Create(path)))foreach(float value in values)output.Write(value);}
    static void ReactiveLimitFormats(Fixture f,ReactiveLimitReport report)
    {
        report.inputFormat=f.input.graphicsFormat.ToString();report.geometryFormat=f.geometry.graphicsFormat.ToString();
        report.historyFormat=f.history[0].graphicsFormat.ToString();report.momentsFormat=f.moments[0].graphicsFormat.ToString();
        ReactiveLimitRequire(f.input.graphicsFormat==GraphicsFormat.R16G16B16A16_SFloat,"input is not linear RGBA16F");
        ReactiveLimitRequire(f.geometry.graphicsFormat==GraphicsFormat.R32G32B32A32_SFloat,"geometry is not RGBA32F");
        for(int i=0;i<2;i++)ReactiveLimitRequire(f.history[i].IsCreated()&&f.moments[i].IsCreated()&&
            f.history[i].graphicsFormat==GraphicsFormat.R16G16B16A16_SFloat&&
            f.moments[i].graphicsFormat==GraphicsFormat.R32G32B32A32_SFloat,"history/moments format or creation");
        if(f.identity)
        {
            report.identityFormat=f.identityNow.graphicsFormat.ToString();
            ReactiveLimitRequire(f.identityNow.IsCreated()&&f.identityOld.IsCreated()&&
                f.identityNow.graphicsFormat==GraphicsFormat.R32G32B32A32_UInt&&
                f.identityOld.graphicsFormat==GraphicsFormat.R32G32B32A32_UInt,"identity is not real UInt4 texture");
        }
    }
    static void ReactiveLimitCheck(Fixture f,ReactiveLimitCase test,string stage,double radiance,double mean,double second,int age,
        string directory,List<ReactiveLimitRow> rows)
    {
        var row=new ReactiveLimitRow{name=test.name,kernel=f.identity?"CSTemporalIdentity":"CSTemporal",stage=stage,
            maxHistory=test.maximum,warmupFrames=test.warmup,center=Pixel(f.last),centerMoments=Pixel(f.lastMoments),
            expectedStoredRadiance=radiance,expectedMean=mean,expectedSecond=second,expectedHistory=age};
        row.raw=row.kernel+"-"+test.name+"-"+stage;rows.Add(row);
        ReactiveLimitWrite(Path.Combine(directory,row.raw+"-history.rgba32f"),f.last);
        ReactiveLimitWrite(Path.Combine(directory,row.raw+"-moments.rgba32f"),f.lastMoments);
        ReactiveLimitRequire(Finite(f.last)&&Finite(f.lastMoments),row.raw+" nonfinite output");
        for(int i=0;i<Fixture.Count;i++)
        {
            for(int channel=0;channel<3;channel++)ReactiveLimitRequire(f.last[i*4+channel]==(float)radiance,row.raw+" stored radiance at "+i);
            ReactiveLimitRequire(f.last[i*4+3]==1&&f.lastMoments[i*4+2]==age,row.raw+" confidence/history at "+i);
            ReactiveLimitRequire(Math.Abs(f.lastMoments[i*4]-mean)<=0.000002&&
                Math.Abs(f.lastMoments[i*4+1]-second)<=0.000002&&Math.Abs(f.lastMoments[i*4+3])<=0.000002,row.raw+" moments at "+i);
        }
        row.passed=true;
    }
    public static void RunReactiveHistoryLimit()
    {
        string requested=Arg("-reactiveHistoryLimitReport",null);
        ReactiveLimitRequire(!string.IsNullOrWhiteSpace(requested)&&Path.IsPathRooted(requested),"explicit absolute report path required");
        string path=Path.GetFullPath(requested),directory=Path.GetDirectoryName(path),raw=Path.Combine(directory,"reactive-history-limit-raw");
        ReactiveLimitRequire(!File.Exists(path)&&!Directory.Exists(raw),"refusing to overwrite existing evidence");
        Directory.CreateDirectory(directory);Directory.CreateDirectory(raw);
        var rows=new List<ReactiveLimitRow>();var report=new ReactiveLimitReport{unity=Application.unityVersion,
            gpu=SystemInfo.graphicsDeviceName,api=SystemInfo.graphicsDeviceType.ToString()};
        try
        {
            ReactiveLimitRequire(SystemInfo.graphicsDeviceType==GraphicsDeviceType.Direct3D12&&
                QualitySettings.activeColorSpace==ColorSpace.Linear&&SystemInfo.supportsComputeShaders,"DX12 Linear compute required");
            var shader=Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
            ReactiveLimitRequire(shader!=null,"current product compute is missing");
            shader.FindKernel("CSTemporal");shader.FindKernel("CSTemporalIdentity");shader.FindKernel("CSFilter");
            var uploader=AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/ComparisonHarness/Editor/DenoiseFixture.compute");
            ReactiveLimitRequire(uploader!=null,"existing identity uploader is missing");uploader.FindKernel("FillIdentity");
            report.computePath=Path.GetFullPath(Path.Combine(Directory.GetParent(Application.dataPath).FullName,AssetDatabase.GetAssetPath(shader)));
            report.kernelsPath=Path.Combine(Path.GetDirectoryName(report.computePath),"HybridLumenGIKernels.hlsl");
            report.computeSha256=ReactiveLimitHash(report.computePath);report.kernelsSha256=ReactiveLimitHash(report.kernelsPath);
            var cases=new[]{
                new ReactiveLimitCase{name="max1-reactive-known",maximum=1,warmup=1,reactive=true,eventAge=1,recoveryAge=1,eventAlpha=1,recoveryAlpha=1},
                new ReactiveLimitCase{name="max1-stable-known",maximum=1,warmup=1,eventAge=1,recoveryAge=1,eventAlpha=1,recoveryAlpha=1},
                new ReactiveLimitCase{name="max2-reactive-known",maximum=2,warmup=2,reactive=true,eventAge=2,recoveryAge=2,eventAlpha=.5,recoveryAlpha=.5},
                new ReactiveLimitCase{name="max32-reactive-known",maximum=32,warmup=32,reactive=true,eventAge=2,recoveryAge=3,eventAlpha=.5,recoveryAlpha=1.0/3},
                new ReactiveLimitCase{name="max1-invalid-previous",maximum=1,warmup=1,reactive=true,invalid=true,eventAge=1,recoveryAge=1,eventAlpha=1,recoveryAlpha=1},
                new ReactiveLimitCase{name="max1-reactive-unknown",maximum=1,warmup=1,reactive=true,unknown=true,eventAge=1,recoveryAge=1,eventAlpha=0,recoveryAlpha=1},
                new ReactiveLimitCase{name="max32-reactive-unknown",maximum=32,warmup=32,reactive=true,unknown=true,eventAge=2,recoveryAge=3,eventAlpha=0,recoveryAlpha=1.0/3}
            };
            foreach(bool identity in new[]{false,true})using(var f=new Fixture(identity,RenderTextureFormat.ARGBFloat,shader))
            {
                ReactiveLimitFormats(f,report);
                foreach(var test in cases)
                {
                    f.Reset();f.shader.SetInt("_HLGI_MaxHistory",test.maximum);f.shader.SetFloat("_HLGI_CurrentWeight",.08f);
                    for(int frame=1;frame<=test.warmup;frame++)
                    {
                        f.Step(frame>1);report.actualTemporalDispatches++;
                        ReactiveLimitRequire(Finite(f.last)&&Finite(f.lastMoments),test.name+" warmup nonfinite");
                        for(int i=0;i<Fixture.Count;i++)ReactiveLimitRequire(f.last[i*4]==1&&f.last[i*4+3]==1&&
                            f.lastMoments[i*4+2]==frame,test.name+" warmup did not establish actual history "+frame);
                    }
                    f.shader.SetFloat("_HLGI_GlobalReactive",test.reactive?1:0);
                    Fixture.Set(f.input,Fixture.Fill(test.unknown?Fixture.Gray(0,-1):Fixture.Gray(1.03125f)));
                    f.Step(!test.invalid);report.actualTemporalDispatches++;
                    double eventMean=1*(1-test.eventAlpha)+1.03125*test.eventAlpha;
                    double eventSecond=1*(1-test.eventAlpha)+(1.03125*1.03125)*test.eventAlpha;
                    float eventStored=ReactiveLimitStored(eventMean);
                    ReactiveLimitCheck(f,test,"event",eventStored,eventMean,eventSecond,test.eventAge,raw,rows);
                    f.shader.SetFloat("_HLGI_GlobalReactive",0);Fixture.Set(f.input,Fixture.Fill(Fixture.Gray(1.03125f)));
                    f.Step(true);report.actualTemporalDispatches++;
                    double mean=eventMean*(1-test.recoveryAlpha)+1.03125*test.recoveryAlpha;
                    double second=eventSecond*(1-test.recoveryAlpha)+(1.03125*1.03125)*test.recoveryAlpha;
                    float stored=ReactiveLimitStored(eventStored*(1-test.recoveryAlpha)+1.03125*test.recoveryAlpha);
                    ReactiveLimitCheck(f,test,"recovery",stored,mean,second,test.recoveryAge,raw,rows);
                }
            }
            ReactiveLimitRequire(rows.Count==28&&report.actualTemporalDispatches==168,"unexpected finite coverage");
            report.passed=true;
        }
        catch(Exception error){report.error=error.ToString();throw;}
        finally{report.cases=rows.ToArray();File.WriteAllText(path,JsonUtility.ToJson(report,true));}
        Debug.Log("REACTIVE_HISTORY_LIMIT_PASSED rows="+rows.Count+" report="+path);
    }
}
