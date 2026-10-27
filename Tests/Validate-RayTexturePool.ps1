param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$paths = @('Runtime/HybridLumenGIRayTexturePool.cs','Runtime/HybridLumenGIRayTextureImporter.cs','Runtime/HybridLumenGIRayTextureLayout.cs',
    'Runtime/HybridLumenGIHitMaterialData.cs','Runtime/HybridLumenGIMaterialSource.cs')
$sources = @{}
foreach ($path in $paths) { $sources[[IO.Path]::GetFileName($path)] = [IO.File]::ReadAllText((Join-Path $SourceRoot $path)) }
$sources['UnityMaterialStubs.cs'] = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneRayTexturePool/MaterialStubs.cs.txt'))
$sources['UnityPoolStubs.cs'] = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneRayTexturePool/UnityStubs.cs.txt'))
$sources['Program.cs'] = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneRayTexturePool/Program.cs.txt'))
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'ray-texture-pool' -Sources $sources
foreach ($path in $paths) { Write-Output ($path + ' SHA256 ' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot $path) -Algorithm SHA256).Hash) }
