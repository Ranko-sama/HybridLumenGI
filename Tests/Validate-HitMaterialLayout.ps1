param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$paths = @('Runtime/HybridLumenGIHitMaterialLayout.cs','Runtime/HybridLumenGIRayTexturePool.cs',
    'Runtime/HybridLumenGIRayTextureLayout.cs','Runtime/HybridLumenGIRayTextureImporter.cs','Runtime/HybridLumenGIHitMaterialData.cs','Runtime/HybridLumenGIMaterialSource.cs')
$sources = @{}
foreach ($path in $paths) { $sources[[IO.Path]::GetFileName($path)] = [IO.File]::ReadAllText((Join-Path $SourceRoot $path)) }
foreach ($name in @('MaterialStubs','UnityStubs','Program')) {
    $sources[$name+'.cs'] = [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('StandaloneHitMaterialLayout/'+$name+'.cs.txt')))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'hit-material-layout' -Sources $sources
foreach ($path in $paths) { Write-Output ($path + ' SHA256 ' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot $path) -Algorithm SHA256).Hash) }
