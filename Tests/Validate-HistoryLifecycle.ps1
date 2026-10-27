param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runtime = Join-Path $SourceRoot 'Runtime/HybridLumenGIHistoryLifecycle.cs'
$feature = Join-Path $SourceRoot 'Runtime/HybridLumenGIRendererFeature.cs'
$program = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneHistoryLifecycle/Program.cs.txt'))
$featureSource = [IO.File]::ReadAllText($feature)
# Compile the actual feature's history/target/publication helpers against a minimal
# camera shell. Value-only matrix stand-ins test assignment lifetime, not Unity math.
# ReceiverHistory is a call/order spy only: it checks the actual helper calls against
# the real HistoryLifecycle receipt. Its separate actual-source suite owns behavior.
$start = $featureSource.IndexOf('internal void InvalidateScreenHistory()',[StringComparison]::Ordinal)
$end = $featureSource.IndexOf('internal void PrepareGpuBudget',$start,[StringComparison]::Ordinal)
if ($start -lt 0 -or $end -le $start) { throw 'Cannot locate actual CameraState failure hooks.' }
$program = $program.Replace('__CAMERA_FAILURE_METHODS__',$featureSource.Substring($start,$end-$start))
# Exercise the actual renderer-feature camera reference guard. Evict is a recording
# stand-in here; the test does not model Unity destruction or the LRU implementation.
$registryStart = $featureSource.IndexOf('private CameraState GetCameraState(Camera camera)',[StringComparison]::Ordinal)
$registryEnd = $featureSource.IndexOf('private void Evict(int current)',$registryStart,[StringComparison]::Ordinal)
if ($registryStart -lt 0 -or $registryEnd -le $registryStart) { throw 'Cannot locate actual camera reference-identity guard.' }
$program = $program.Replace('__CAMERA_LOOKUP_METHOD__',$featureSource.Substring($registryStart,$registryEnd-$registryStart))
# Compile the actual transport callback against call/order spies. Material batch
# and timing internals have their own actual-source suites; here exercise the
# callback's real exception/finally control flow instead of matching its layout.
$executeStart = $featureSource.IndexOf('private void Execute(Work d,CommandBuffer cmd)',[StringComparison]::Ordinal)
$executeEnd = $featureSource.IndexOf('private void PrepareHardwareMaterials(', $executeStart,[StringComparison]::Ordinal)
if ($executeStart -lt 0 -or $executeEnd -le $executeStart) { throw 'Cannot locate actual transport callback.' }
$program = $program.Replace('__TRANSPORT_EXECUTE_METHOD__',$featureSource.Substring($executeStart,$executeEnd-$executeStart))
# The frame oracle compiles and calls the complete unchanged runtime class. The
# feature snapshot is used only for supplementary wiring checks, not the oracle.
$featureLiteral = '"' + $featureSource.Replace('\','\\').Replace('"','\"').Replace("`r",'\r').Replace("`n",'\n') + '"'
$program = $program.Replace('__FEATURE_SOURCE__', $featureLiteral)
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'history-lifecycle' -Sources @{
    'HybridLumenGIHistoryLifecycle.cs' = [IO.File]::ReadAllText($runtime)
    'Program.cs' = $program
}
foreach ($path in @($runtime,$feature)) {
    Write-Output ((Split-Path -Leaf $path) + ' SHA256: ' + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)
}
