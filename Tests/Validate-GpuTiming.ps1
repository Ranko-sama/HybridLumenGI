param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$sources = @{
    'HybridLumenGIGpuTiming.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot "Runtime/HybridLumenGIGpuTiming.cs"))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "StandaloneGpuTiming/UnityStubs.cs.txt"))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "StandaloneGpuTiming/Program.cs.txt"))
}
& (Join-Path $PSScriptRoot "Invoke-CSharpHarness.ps1") -Name 'gpu-timing' -Sources $sources
Write-Output ("Runtime source SHA256: " + (Get-FileHash -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIGpuTiming.cs") -Algorithm SHA256).Hash)
