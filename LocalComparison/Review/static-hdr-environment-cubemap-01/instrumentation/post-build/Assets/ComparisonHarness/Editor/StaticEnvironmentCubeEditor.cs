using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using HybridLumenGI;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static class StaticEnvironmentCubeEditor
{
    [StructLayout(LayoutKind.Sequential)] struct Proxy {public Vector4 centerShape,extentsRoughness,albedo,emission,identity;}
    [StructLayout(LayoutKind.Sequential)] struct Entry {public Vector4 irradiance,tag,anchor,normal,guide;}
    [StructLayout(LayoutKind.Sequential)] struct UInt4 {public uint x,y,z,w;}
    [Serializable] sealed class Row {public string name,kernel,file,sha256;public int bytes;public Vector4 value;}
    [Serializable] sealed class Result
    {
        public string status="failed",error,api,gpu;public bool batchMode,cleanupCompleted,formatContract,settingsInvalidation;
        public int cases,dispatches,pending;public Row[] rows;public string[] compiledEntries;
    }
    sealed class Case {public string name;public Cubemap cube;public Vector3 axis,expected;public int axisMode=1,mode,zero;public bool enabled=true,compareLegacy;public float worldAlpha=1,screenAlpha=.25f;}
    static readonly Vector3 Constant=new Vector3(2,4,8);
    static readonly Vector3[] Axes={Vector3.right,Vector3.left,Vector3.up,Vector3.down,Vector3.forward,Vector3.back};
    static readonly Color[] Faces={new Color(1,.125f,.25f,1),new Color(.5f,2,.25f,1),new Color(.5f,.25f,3,1),new Color(4,.25f,.5f,1),new Color(.25f,5,.5f,1),new Color(.25f,.5f,6,1)};
    static string Arg(string n){var a=Environment.GetCommandLineArgs();int i=Array.IndexOf(a,n);return i>=0&&i+1<a.Length?a[i+1]:null;}
    static void Require(bool v,string why){if(!v)throw new Exception(why);}
    static Cubemap Cube(List<Cubemap> owned,TextureFormat format,Color[] colors)
    {
        var c=new Cubemap(2,format,false){filterMode=FilterMode.Bilinear,wrapMode=TextureWrapMode.Clamp};owned.Add(c);
        var faces=new[]{CubemapFace.PositiveX,CubemapFace.NegativeX,CubemapFace.PositiveY,CubemapFace.NegativeY,CubemapFace.PositiveZ,CubemapFace.NegativeZ};
        for(int i=0;i<6;i++)c.SetPixels(Enumerable.Repeat(colors.Length==1?colors[0]:colors[i],4).ToArray(),faces[i],0);
        c.Apply(false,false);return c;
    }
    static RenderTexture Target(List<RenderTexture> owned)
    {
        var r=new RenderTexture(1,1,0,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear){enableRandomWrite=true,useMipMap=false,autoGenerateMips=false};
        owned.Add(r);Require(r.Create(),"Float UAV creation failed");return r;
    }
    static ComputeBuffer Buffer(List<ComputeBuffer> owned,int stride){var b=new ComputeBuffer(1,stride);owned.Add(b);return b;}
    static string Hash(byte[] bytes){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
    static Vector4 Value(byte[] bytes)=>new Vector4(BitConverter.ToSingle(bytes,0),BitConverter.ToSingle(bytes,4),BitConverter.ToSingle(bytes,8),BitConverter.ToSingle(bytes,12));
    static void Check(byte[] data,Vector3 rgb,float alpha)
    {
        for(int i=0;i<data.Length;i+=4)Require(!float.IsNaN(BitConverter.ToSingle(data,i))&&!float.IsInfinity(BitConverter.ToSingle(data,i)),"Nonfinite result");
        var v=Value(data);Require(Mathf.Abs(v.x-rgb.x)<=2e-6f&&Mathf.Abs(v.y-rgb.y)<=2e-6f&&Mathf.Abs(v.z-rgb.z)<=2e-6f&&v.w==alpha,"Frozen radiance/validity mismatch: "+v);
    }
    public static void Run()
    {
        string folder=Arg("-staticEnvironmentOutput");Require(!string.IsNullOrEmpty(folder)&&Path.IsPathRooted(folder)&&!Directory.Exists(folder),"New absolute output required");Directory.CreateDirectory(folder);
        var result=new Result{api=SystemInfo.graphicsDeviceType.ToString(),gpu=SystemInfo.graphicsDeviceName,batchMode=Application.isBatchMode};
        var rows=new List<Row>();var cubes=new List<Cubemap>();var textures=new List<RenderTexture>();var buffers=new List<ComputeBuffer>();var errors=new List<string>();var entries=new List<string>();
        Application.LogCallback logged=(message,stack,type)=>{if(type==LogType.Error||type==LogType.Exception||type==LogType.Assert)errors.Add(message);};Application.logMessageReceived+=logged;
        try
        {
            Require(result.batchMode&&result.api=="Direct3D12"&&SystemInfo.supportsAsyncGPUReadback,"Frozen native compute requirements differ");
            foreach(string name in new[]{"HybridLumenGI","HybridLumenGIExactSoftware","HybridLumenGIHardware"})
            {
                string path="Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/"+name+".compute";
                AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceUpdate|ImportAssetOptions.ForceSynchronousImport);
                var actual=AssetDatabase.LoadAssetAtPath<ComputeShader>(path);Require(actual,"Product compute missing");
                foreach(string kernel in new[]{"CSUpdateCache","CSTrace"}){Require(actual.HasKernel(kernel),"Product entry missing");actual.FindKernel(kernel);entries.Add(name+"/"+kernel);}
                Require(!ShaderUtil.GetComputeShaderMessages(actual).Any(m=>m.severity.ToString()=="Error"),"Product compute compilation failed");
            }
            var shader=Resources.Load<ComputeShader>("StaticEnvironmentCube");Require(shader,"Environment fixture missing");
            Require(!ShaderUtil.GetComputeShaderMessages(shader).Any(m=>m.severity.ToString()=="Error"),"Fixture compilation failed");
            var constant=Cube(cubes,TextureFormat.RGBAHalf,new[]{new Color(2,4,8,1)});
            var directional=Cube(cubes,TextureFormat.RGBAFloat,Faces);
            var nonfinite=Cube(cubes,TextureFormat.RGBAFloat,new[]{new Color(float.NaN,1,2,1)});
            var invalid=Cube(cubes,TextureFormat.RGBA32,new[]{Color.white});
            var admission=typeof(HybridLumenGIRendererFeature).GetMethod("IsSupportedEnvironmentCubemap",BindingFlags.Static|BindingFlags.NonPublic);
            Require(admission!=null,"Actual environment admission method missing");
            Func<Cubemap,bool> supported=c=>(bool)admission.Invoke(null,new object[]{c});
            result.formatContract=supported(constant)&&supported(directional)&&!supported(invalid)&&!supported(null);Require(result.formatContract,"Actual format admission mismatch");
            result.settingsInvalidation=EnvironmentSettingsActual.Check(constant,directional,folder);Require(result.settingsInvalidation,"Actual serialized settings transition failed");
            var cases=new List<Case>{new Case{name="disabled-cosine",cube=CoreUtils.blackCubeTexture,enabled=false,axis=Vector3.forward,axisMode=0,expected=Constant,compareLegacy=true},
                new Case{name="constant-cosine",cube=constant,axis=Vector3.forward,axisMode=0,expected=Constant,compareLegacy=true}};
            for(int i=0;i<6;i++)cases.Add(new Case{name="axis-"+i,cube=directional,axis=Axes[i],expected=new Vector3(Faces[i].r,Faces[i].g,Faces[i].b)});
            cases.Add(new Case{name="unresolved",cube=directional,axis=Vector3.forward,mode=1,expected=Vector3.zero,worldAlpha=0,screenAlpha=-1,compareLegacy=true});
            cases.Add(new Case{name="ordinary-hit",cube=directional,axis=Vector3.forward,mode=2,expected=new Vector3(.5f,1,2),screenAlpha=.65f,compareLegacy=true});
            cases.Add(new Case{name="nonfinite-miss",cube=nonfinite,axis=Vector3.forward,expected=Vector3.zero,worldAlpha=0,screenAlpha=-1});
            cases.Add(new Case{name="zero-weight",cube=nonfinite,axis=Vector3.forward,zero=1,expected=Vector3.zero,screenAlpha=1,compareLegacy=true});
            var proxy=Buffer(buffers,80);proxy.SetData(new[]{new Proxy{albedo=new Vector4(.5f,.5f,.5f,1),identity=new Vector4(11,2,0,1)}});
            var policy=Buffer(buffers,16);policy.SetData(new[]{new UInt4{x=1,y=1,z=1}});
            var read=Buffer(buffers,80);var write=Buffer(buffers,80);var mask=Buffer(buffers,4);mask.SetData(new uint[]{1});
            var output=Target(textures);var geometry=Target(textures);var material=Target(textures);
            shader.SetInt("_HLGI_Rays",4);shader.SetInt("_HLGI_CacheRays",4);shader.SetInt("_HLGI_Epoch",3);shader.SetInt("_HLGI_FrameIndex",7);shader.SetVector("_HLGI_Environment",new Vector4(2,4,8,1));
            foreach(var c in cases)
            {
                shader.SetVector("_Axis",new Vector4(c.axis.x,c.axis.y,c.axis.z,0));shader.SetInt("_AxisMode",c.axisMode);shader.SetInt("_CaseMode",c.mode);shader.SetInt("_ZeroWeight",c.zero);shader.SetInt("_HLGI_EnvironmentCubeEnabled",c.enabled?1:0);
                var values=new Dictionary<string,byte[]>();
                foreach(string name in new[]{"CSUpdateCacheLegacy","CSUpdateCache","CSTraceLegacy","CSTrace"})
                {
                    bool world=name.StartsWith("CSUpdateCache"),legacy=name.EndsWith("Legacy");int k=shader.FindKernel(name);
                    read.SetData(new Entry[1]);write.SetData(new Entry[1]);shader.SetBuffer(k,"_HLGI_Proxies",proxy);shader.SetBuffer(k,"_HLGI_LightingPolicies",policy);
                    if(!legacy)shader.SetTexture(k,"_HLGI_EnvironmentCube",c.cube);
                    if(world){shader.SetBuffer(k,"_HLGI_CacheRead",read);shader.SetBuffer(k,"_HLGI_CacheWrite",write);shader.SetBuffer(k,"_HLGI_CacheUpdateMask",mask);}
                    else {shader.SetTexture(k,"_HLGI_Output",output);shader.SetTexture(k,"_HLGI_GeometryOut",geometry);shader.SetTexture(k,"_HLGI_MaterialOut",material);}
                    result.pending++;shader.Dispatch(k,1,1,1);result.dispatches++;
                    var request=world?AsyncGPUReadback.Request(write):AsyncGPUReadback.Request(output,0,TextureFormat.RGBAFloat);
                    request.WaitForCompletion();if(!request.done)AsyncGPUReadback.WaitAllRequests();if(request.done)result.pending--;
                    Require(request.done&&!request.hasError,"Readback completion unproven");byte[] bytes=request.GetData<byte>().ToArray();Require(bytes.Length==(world?80:16),"Result ABI differs");
                    string file=c.name+"-"+name+".bin";File.WriteAllBytes(Path.Combine(folder,file),bytes);values.Add(name,bytes);rows.Add(new Row{name=c.name,kernel=name,file=file,bytes=bytes.Length,sha256=Hash(bytes),value=Value(bytes)});
                    Vector3 expected=legacy&&c.mode==0&&c.zero==0?Constant:c.expected;float alpha=legacy&&c.mode==0&&c.zero==0?(world?1:.25f):(world?c.worldAlpha:c.screenAlpha);
                    Check(bytes,expected,alpha);
                    if(world)Require(BitConverter.ToSingle(bytes,16)==11&&BitConverter.ToSingle(bytes,20)==2&&BitConverter.ToSingle(bytes,24)==3&&BitConverter.ToSingle(bytes,28)==1,"World identity/generation mismatch");
                    Require(errors.Count==0,string.Join("\n",errors));
                }
                if(c.compareLegacy){Require(values["CSUpdateCacheLegacy"].SequenceEqual(values["CSUpdateCache"]),"Legacy world control changed");Require(values["CSTraceLegacy"].SequenceEqual(values["CSTrace"]),"Legacy screen control changed");}
                result.cases++;
            }
            Require(result.cases==12&&result.dispatches==48&&result.pending==0,"Fixed batch incomplete");result.status="finite-directional-environment-established";
        }
        catch(Exception e){result.error=e.ToString();Debug.LogError("STATIC_ENVIRONMENT_FAILED "+e);}
        finally
        {
            if(result.pending==0){foreach(var b in buffers)b.Dispose();foreach(var t in textures){t.Release();UnityEngine.Object.DestroyImmediate(t);}foreach(var c in cubes)UnityEngine.Object.DestroyImmediate(c);result.cleanupCompleted=true;}
            else Debug.LogError("STATIC_ENVIRONMENT_FAILED completion unproven; retaining owned inputs until process exit");
            Application.logMessageReceived-=logged;result.rows=rows.ToArray();result.compiledEntries=entries.ToArray();File.WriteAllText(Path.Combine(folder,"result.json"),JsonUtility.ToJson(result,true));
        }
        EditorApplication.Exit(result.status=="finite-directional-environment-established"&&result.cleanupCompleted?0:1);
    }
}
