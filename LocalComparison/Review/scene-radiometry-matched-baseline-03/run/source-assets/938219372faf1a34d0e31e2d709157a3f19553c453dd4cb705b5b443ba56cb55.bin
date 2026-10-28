using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;

// Temporary local investigation only: read existing state, never alter rendering.
public static class CacheInspection
{
    static object Field(object o,string n)=>o.GetType().GetField(n,BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public).GetValue(o);
    static void Save(ComputeBuffer b,string path)
    {
        var r=AsyncGPUReadback.Request(b);r.WaitForCompletion();
        if(r.hasError)throw new Exception("Cache inspection readback failed");
        File.WriteAllBytes(path,r.GetData<byte>().ToArray());
    }
    public static void Capture(object feature,string directory,int frame)
    {
        if(frame!=30 && frame!=719)return;
        if(Array.IndexOf(Environment.GetCommandLineArgs(),"-inspectCache")<0)return;
        var pass=Field(feature,"pass");var cameras=(IDictionary)Field(pass,"cameras");
        foreach(var state in cameras.Values)
        {
            var buffers=(ComputeBuffer[])Field(state,"cache");
            for(int i=0;i<buffers.Length;i++)Save(buffers[i],Path.Combine(directory,$"cache-{frame:D4}-{i}.bin"));
            var surfaces=Field(state,"surfaceCache");
            Save((ComputeBuffer)Field(surfaces,"metadataBuffer"),Path.Combine(directory,$"cards-{frame:D4}.bin"));
            var owners=(Array)Field(surfaces,"owners");
            using(var writer=new StreamWriter(Path.Combine(directory,$"owners-{frame:D4}.txt")))
                for(int i=0;i<owners.Length;i++) {var owner=owners.GetValue(i);if(owner!=null)writer.WriteLine(i+" "+((Component)Field(owner,"proxy")).name);}
        }
    }
}
