param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runtime = Join-Path $SourceRoot 'Runtime/HybridLumenGIProxy.cs'
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'proxy-updates' -Sources @{
    'HybridLumenGIProxy.cs' = [IO.File]::ReadAllText($runtime)
    'HybridLumenGIUniformLighting.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIUniformLighting.cs'))
    'HybridLumenGIMeshSource.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIMeshSource.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneProxyUpdates/UnityStubs.cs.txt'))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneProxyUpdates/Program.cs.txt'))
}
Write-Output ('Actual Proxy source SHA256: ' + (Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash)
