param([string]$SourceRoot=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference='Stop'
$sources=@{}
foreach($name in @('HybridLumenGIDeformedMesh','HybridLumenGIResourceRetirement')) {
    $path=Join-Path $SourceRoot ('Runtime/'+$name+'.cs')
    $sources[($name+'.cs')]=[IO.File]::ReadAllText($path)
    Write-Output ($name+' SHA256 '+(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)
}
# Only the existing external Unity adapter is scheduled. Product source is not rewritten.
$adapter=[IO.File]::ReadAllText((Join-Path $SourceRoot 'Tests/StandaloneDeformedMesh/Adapters.cs.txt'))
$old='public int Context;public Action[] Readers=Array.Empty<Action>();'
if($adapter.Contains($old)) {
    $adapter=$adapter.Replace($old,'public int Context,QueryCount;public Action[] Readers=Array.Empty<Action>();')
    $old='return record!=null && record.Submitted && record.Completed;'
    if(!$adapter.Contains($old)){throw 'Fence query adapter shape changed'}
    $adapter=$adapter.Replace($old,'if(record!=null && record.Submitted && ++record.QueryCount>=2)record.Completed=true;return record!=null && record.Submitted && record.Completed;')
} else {
    $old='public static int Submits,CompleteNewFenceOnQuery;'
    if(!$adapter.Contains($old)){throw 'Fence adapter shape changed'}
    $adapter=$adapter.Replace($old,'public static int Submits,CompleteNewFenceOnQuery=2;')
}
$sources['Adapters.cs']=$adapter
$sources['Program.cs']=@'
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
'@
& (Join-Path $SourceRoot 'Tests/Invoke-CSharpHarness.ps1') -Name 'retirement-progress' -Sources $sources -TimeoutSeconds 30
