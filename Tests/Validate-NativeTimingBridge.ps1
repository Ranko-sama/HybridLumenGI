param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$sources = @{
    'HybridLumenGINativeGpuTiming.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGINativeGpuTiming.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneNativeTimingBridge/UnityStubs.cs.txt'))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneNativeTimingBridge/Program.cs.txt'))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'native-timing-bridge' -Sources $sources
Write-Output ('Runtime source SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot 'Runtime/HybridLumenGINativeGpuTiming.cs') -Algorithm SHA256).Hash)
