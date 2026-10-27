param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$sources = @{
    'SurfaceCache.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGISurfaceCache.cs'))
    'MaterialSource.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIMaterialSource.cs'))
    'HitMaterialData.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIHitMaterialData.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneSurfaceCache/UnityStubs.cs.txt'))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneSurfaceCache/Program.cs.txt'))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'surface-cache' -Sources $sources
Write-Output ("Runtime source SHA256: " + (Get-FileHash -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGISurfaceCache.cs") -Algorithm SHA256).Hash)
