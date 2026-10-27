// Local GPU regression for the actual CSTemporal kernel; not part of the runtime package.
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public static class DenoiseRegressionEditor
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
    public static void Run()
    {
        var shader=Resources.Load<ComputeShader>("HybridLumenGI/HybridLumenGI");
        int kernel=shader.FindKernel("CSTemporal");var input=Texture(new Color(0,0,0,1));
        // Oct(0,0), quantized geometric +Z, reversed-Z depth .5.
        var packed=new Color(0,0,8390657,.5f);var geometry=Texture(packed);
        var material=Texture(new Color(.5f,.5f,.5f,1));var zero=Texture(Color.clear);
        var output=Target();var moments=Target();var rows=new List<Row>();
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
                bool finite=!float.IsNaN(m[19])&&!float.IsInfinity(m[19]);
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
        string path=Arg("-denoiseReport","I:/Unity test/Comparison/Evidence/local-denoise-01/gpu-regression.json");
        Directory.CreateDirectory(Path.GetDirectoryName(path));File.WriteAllText(path,JsonUtility.ToJson(report,true));
        if(!report.passed)throw new Exception("Denoise GPU regression failed: "+path);
        Debug.Log("DENOISE_GPU_REGRESSION_PASSED cases="+rows.Count);
    }
    public static void PlayChecked(){Run();RuntimeAuditEditor.Play();}
}
