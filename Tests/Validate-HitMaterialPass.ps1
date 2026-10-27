param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$paths = @('Runtime/HybridLumenGIHitMaterialPass.cs','Runtime/HybridLumenGIHitMaterialBatch.cs',
    'Runtime/HybridLumenGIRayTexturePool.cs','Runtime/HybridLumenGIRayTextureImporter.cs',
    'Runtime/HybridLumenGIRayTextureLayout.cs','Runtime/HybridLumenGIHitMaterialLayout.cs',
    'Runtime/HybridLumenGIHitMaterialData.cs','Runtime/HybridLumenGIMaterialSource.cs')
$sources = @{}
$before = @{}
foreach ($path in $paths) {
    $full = Join-Path $SourceRoot $path
    $sources[[IO.Path]::GetFileName($path)] = [IO.File]::ReadAllText($full)
    $before[$path] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
}
foreach ($pair in @(@('MaterialStubs.cs.txt','UnityMaterialStubs.cs'),@('UnityStubs.cs.txt','UnityBatchStubs.cs'),
        @('RenderGraphStubs.cs.txt','RenderGraphStubs.cs'),@('Program.cs.txt','Program.cs'))) {
    $sources[$pair[1]] = [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('StandaloneHitMaterialPass/' + $pair[0])))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'hit-material-pass' -Sources $sources
foreach ($path in $paths) {
    $after = (Get-FileHash -LiteralPath (Join-Path $SourceRoot $path) -Algorithm SHA256).Hash
    if ($before[$path] -ne $after) { throw "Source changed during validation: $path" }
    Write-Output ($path + ' SHA256 ' + $after)
}
