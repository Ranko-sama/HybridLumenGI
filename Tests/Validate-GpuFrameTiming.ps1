param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$sources=@{}
foreach($name in @('HybridLumenGIGpuFrameTiming','HybridLumenGIGpuTiming','HybridLumenGINativeGpuTiming')) {
    $sources[$name+'.cs']=[IO.File]::ReadAllText((Join-Path $SourceRoot ('Runtime/'+$name+'.cs')))
}
foreach($name in @('Program','UnityStubs')) {
    $sources[$name+'.cs']=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ('StandaloneGpuFrameTiming/'+$name+'.cs.txt')))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'gpu-frame-timing' -Sources $sources
foreach($name in @('HybridLumenGIGpuFrameTiming','HybridLumenGIGpuTiming','HybridLumenGINativeGpuTiming')) {
    Write-Output ($name+' SHA256: '+(Get-FileHash -LiteralPath (Join-Path $SourceRoot ('Runtime/'+$name+'.cs')) -Algorithm SHA256).Hash)
}
