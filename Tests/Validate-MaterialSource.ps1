param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$actualPath = Join-Path $SourceRoot 'Runtime/HybridLumenGIMaterialSource.cs'
$sources = @{
    'MaterialSource.cs' = [IO.File]::ReadAllText($actualPath)
    'HitMaterialData.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGIHitMaterialData.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneMaterialSource/UnityStubs.cs.txt'))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneMaterialSource/Program.cs.txt'))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'material-source' -Sources $sources
Write-Output ('Runtime source SHA256: ' + (Get-FileHash -LiteralPath $actualPath -Algorithm SHA256).Hash)
Write-Output ('Hit input source SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot 'Runtime/HybridLumenGIHitMaterialData.cs') -Algorithm SHA256).Hash)
