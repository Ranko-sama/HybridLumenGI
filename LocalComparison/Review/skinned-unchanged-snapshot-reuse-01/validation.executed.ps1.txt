param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),[string]$DeformationSource='',[switch]$LegacyContinuousControl,[switch]$LegacyUnchangedControl,[string]$SourceArchive='')
$ErrorActionPreference='Stop'
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$sources=@{}
foreach($name in @('HybridLumenGIDeformedMesh','HybridLumenGIResourceRetirement','HybridLumenGIResourceRetirementPump')) {
    $sources[($name+'.cs')]=[IO.File]::ReadAllText((Join-Path $SourceRoot ('Runtime/'+$name+'.cs')))
}
foreach($name in @('Adapters','FingerprintAdapters','Program')) {
    $sources[($name+'.cs')]=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ('StandaloneDeformedMesh/'+$name+'.cs.txt')))
}
if($DeformationSource){$sources['HybridLumenGIDeformedMesh.cs']=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $DeformationSource).Path)}
$fingerprintSource=[IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGISurfaceCharts.cs'))
$fingerprintStart=$fingerprintSource.IndexOf('        public static string ComputeContentFingerprint(Mesh mesh)')
$fingerprintEnd=$fingerprintSource.IndexOf('        public static Chart[] Bake(Mesh mesh,',$fingerprintStart)
if($fingerprintStart -lt 0 -or $fingerprintEnd -le $fingerprintStart){throw 'Actual fingerprint method/dependencies not found.'}
$fingerprintVersion=[regex]::Match($fingerprintSource,'private const int FingerprintVersion = [0-9]+;').Value
if(!$fingerprintVersion){throw 'Actual fingerprint version not found.'}
$sources['ActualContentFingerprint.cs']='using System; using System.IO; using System.Security.Cryptography; using UnityEngine; using Unity.Collections; namespace HybridLumenGI { public sealed partial class HybridLumenGISurfaceCharts { '+$fingerprintVersion+"`n"+$fingerprintSource.Substring($fingerprintStart,$fingerprintEnd-$fingerprintStart)+' } }'
if($SourceArchive){
    if(Test-Path -LiteralPath $SourceArchive){throw 'Do not overwrite frozen compiled sources.'}
    New-Item -ItemType Directory -Path $SourceArchive | Out-Null
    $archiveEncoding=New-Object System.Text.UTF8Encoding($false)
    foreach($fileName in $sources.Keys){[IO.File]::WriteAllText((Join-Path $SourceArchive ($fileName+'.txt')),[string]$sources[$fileName],$archiveEncoding)}
}
$previousControl=[Environment]::GetEnvironmentVariable('HLGI_COALESCED_LEGACY_CONTROL','Process')
$previousUnchanged=[Environment]::GetEnvironmentVariable('HLGI_SKINNED_UNCHANGED_LEGACY_CONTROL','Process')
try {
    [Environment]::SetEnvironmentVariable('HLGI_COALESCED_LEGACY_CONTROL',$(if($LegacyContinuousControl){'1'}else{$null}),'Process')
    [Environment]::SetEnvironmentVariable('HLGI_SKINNED_UNCHANGED_LEGACY_CONTROL',$(if($LegacyUnchangedControl){'1'}else{$null}),'Process')
    & (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'deformed-mesh' -Sources $sources -TimeoutSeconds 30
} finally {
    [Environment]::SetEnvironmentVariable('HLGI_COALESCED_LEGACY_CONTROL',$previousControl,'Process')
    [Environment]::SetEnvironmentVariable('HLGI_SKINNED_UNCHANGED_LEGACY_CONTROL',$previousUnchanged,'Process')
}
if($LegacyContinuousControl -or $LegacyUnchangedControl){return}

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
