param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$sources=@{}
foreach($name in @('HybridLumenGIDeformedMesh','HybridLumenGIResourceRetirement','HybridLumenGIResourceRetirementPump')) {
    $sources[($name+'.cs')]=[IO.File]::ReadAllText((Join-Path $SourceRoot ('Runtime/'+$name+'.cs')))
}
foreach($name in @('Adapters','Program')) {
    $sources[($name+'.cs')]=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ('StandaloneDeformedMesh/'+$name+'.cs.txt')))
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'deformed-mesh' -Sources $sources -TimeoutSeconds 30

# These are deliberately source wiring contracts, not an assertion that Unity ran the consumers.
$contracts=@{
    'HybridLumenGIProxy.cs'=@('SourceMesh\s*=>\s*HybridLumenGIDeformedMesh\.GetSourceMesh\(sourceRenderer\)',
        'HybridLumenGIDeformedMesh\.GetSdf\(sourceRenderer,meshSdf\)', 'HybridLumenGIDeformedMesh\.GetCharts\(sourceRenderer,surfaceCharts\)')
    'HybridLumenGISurfaceCache.cs'=@('private static Mesh GetMesh\(Renderer renderer\)\s*=>\s*HybridLumenGIDeformedMesh\.GetSourceMesh\(renderer\)')
    'HybridLumenGISdfAtlas.cs'=@('HybridLumenGIDeformedMesh\.GetSourceMesh\(renderer\)\s*!=\s*asset\.SourceMesh')
    'HybridLumenGIHardwareBackend.cs'=@('HybridLumenGIDeformedMesh\.GetSourceMesh\(renderer\)')
}
foreach($file in $contracts.Keys) {
    $source=[IO.File]::ReadAllText((Join-Path $SourceRoot ('Runtime/'+$file)))
    foreach($pattern in $contracts[$file]) {if($source -notmatch $pattern){throw "Unified geometry source contract missing in $file : $pattern"}}
}
Write-Output 'PASS: source-only contracts confirm Proxy, SurfaceCache, SdfAtlas and HardwareBackend route geometry through the shared deformed snapshot accessor; this does not execute those consumers in Unity.'
