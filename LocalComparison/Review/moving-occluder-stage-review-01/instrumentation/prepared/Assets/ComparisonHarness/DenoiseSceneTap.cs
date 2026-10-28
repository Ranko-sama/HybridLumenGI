// Test-project-only readback tap. Never copy into the product Runtime folder.
using System;
using System.IO;
using System.Reflection;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public static class DenoiseSceneTap
{
    static readonly bool enabled=Array.IndexOf(Environment.GetCommandLineArgs(),"-denoiseSceneTap")>=0;
    static readonly FieldInfo frameField=typeof(ComparisonCapture).GetField("logicalFrame",BindingFlags.Instance|BindingFlags.NonPublic);
    static readonly FieldInfo directoryField=typeof(ComparisonCapture).GetField("directory",BindingFlags.Instance|BindingFlags.NonPublic);
    static readonly object gate=new object();
    static readonly HashSet<int> completed=new HashSet<int>();
    static ComparisonCapture capture;
    static int pending,errors;
    [Serializable] class Receipt {public int logicalFrame,giFrame,engineFrame,cameraId,width,height;public string actualFormat;}
    [Serializable] class Summary {public int first=176,last=196,completedFrames,pending,errors;public bool passed;}
    public static bool Wants(int frame)=>enabled&&frame>=176&&frame<=196;
    public static void Record(CommandBuffer cmd,RenderTexture raw,Camera camera,int giFrame)
    {
        if(!enabled)return;
        if(!capture)capture=UnityEngine.Object.FindFirstObjectByType<ComparisonCapture>();
        if(!capture||capture.camera!=camera)return;
        int logical=(int)frameField.GetValue(capture);if(!Wants(logical))return;
        string directory=(string)directoryField.GetValue(capture);
        if(string.IsNullOrEmpty(directory))throw new Exception("Missing scene-tap capture directory");
        var receipt=new Receipt{logicalFrame=logical,giFrame=giFrame,engineFrame=Time.frameCount,cameraId=camera.GetInstanceID(),width=raw.width,height=raw.height,actualFormat=raw.graphicsFormat.ToString()};
        string filename=Path.Combine(directory,"denoise-"+logical.ToString("D4")+"-raw.rgba32f");
        pending++;
        // This command copies the transient gather while it still belongs to
        // this graph pass. The callback never looks up a reused RenderTexture.
        cmd.RequestAsyncReadback(raw,0,TextureFormat.RGBAFloat,request=>
        {
            try
            {
                if(request.hasError)throw new Exception("Scene-tap readback error");
                var data=request.GetData<float>();if(data.Length!=receipt.width*receipt.height*4)throw new Exception("Scene-tap dimensions changed");
                for(int i=0;i<data.Length;i++)if(float.IsNaN(data[i])||float.IsInfinity(data[i]))throw new Exception("Scene-tap nonfinite component");
                byte[] bytes=request.GetData<byte>().ToArray();
                lock(gate)
                {
                    if(!completed.Add(logical))throw new Exception("Duplicate scene-tap frame");
                    File.WriteAllBytes(filename,bytes);File.AppendAllText(Path.Combine(directory,"denoise-raw-receipts.jsonl"),JsonUtility.ToJson(receipt)+Environment.NewLine);
                }
            }
            catch(Exception e){errors++;Debug.LogError(e);}
            finally{pending--;}
        });
    }
    public static void Finish(bool collected)
    {
        if(!enabled)return;
        AsyncGPUReadback.WaitAllRequests();
        var report=new Summary{completedFrames=completed.Count,pending=pending,errors=errors,passed=completed.Count==21&&pending==0&&errors==0};
        string directory=capture?(string)directoryField.GetValue(capture):null;
        if(!string.IsNullOrEmpty(directory))File.WriteAllText(Path.Combine(directory,"denoise-raw-summary.json"),JsonUtility.ToJson(report,true));
        if(collected&&!report.passed)throw new Exception("Incomplete scene-tap evidence");
    }
}
