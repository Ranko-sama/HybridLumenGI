using System;
using System.Reflection;
using UnityEngine;
using UnityEngine.Rendering;
using HybridLumenGI;
static class Program {
    static void Main() {
        HybridLumenGIResourceRetirement.EnsureRegistered();
        typeof(HybridLumenGIResourceRetirement).GetMethod("InitializeRuntime",BindingFlags.Static|BindingFlags.NonPublic).Invoke(null,null);
        HybridLumenGIResourceRetirement.IdleUpdate();
        int parent=0,child=0;
        HybridLumenGIResourceRetirement.RegisterShutdownOwner(()=>HybridLumenGIResourceRetirement.Retire(()=>{
            parent++;HybridLumenGIResourceRetirement.Retire(()=>child++);
        }));
        Application.Quit();
        Console.WriteLine("Actual source shutdown: parent="+parent+", child="+child+", owned="+HybridLumenGIResourceRetirement.OwnedCount+", pending="+HybridLumenGIResourceRetirement.PendingCount+", warnings="+Debug.Warnings.Count);
        foreach(var fence in RecordedGpu.Fences)Console.WriteLine("External fence adapter: submitted="+fence.Submitted+", completed="+fence.Completed+", queryCount="+fence.QueryCount);
        if(parent!=1 || child!=1 || HybridLumenGIResourceRetirement.OwnedCount!=0 || HybridLumenGIResourceRetirement.PendingCount!=0)
            throw new Exception("Ready parent/child destruction was stranded when a submitted fence completed between polls.");
        Console.WriteLine("PASS: submitted fence false on first read, true from second read; both parent and child destroy exactly once in the same shutdown. External deterministic adapter; no native/GPU claim.");
    }
}