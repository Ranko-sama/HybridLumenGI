param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $SourceRoot 'Runtime/HybridLumenGILights.cs'
$sources = @{
    'HybridLumenGILights.cs' = [IO.File]::ReadAllText($runtime)
    'HybridLumenGILightRelevance.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGILightRelevance.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneLighting/UnityStubs.cs.txt'))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneLighting/Program.cs.txt'))
}
$shadowmask = Join-Path $SourceRoot 'Runtime/HybridLumenGIShadowmask.cs'
if (Test-Path -LiteralPath $shadowmask -PathType Leaf) {
    # Only the light's baking output participates in the collector. The other methods
    # belong to renderer/texture capture and aren't part of this standalone host.
    $method = [regex]::Match([IO.File]::ReadAllText($shadowmask), '(?ms)^        internal static int ChannelPlusOne\(Light light\)\s*\{.*?^        \}')
    if (!$method.Success) { throw 'Cannot locate HybridLumenGIShadowmask.ChannelPlusOne in the selected product source.' }
    $sources['HybridLumenGIShadowmask.cs'] = "using UnityEngine; using UnityEngine.Rendering; namespace HybridLumenGI { internal static class HybridLumenGIShadowmask { $($method.Value) } }"
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'lighting' -Sources $sources
if ($env:HLGI_LIGHT_NATIVE_REPLAY -or $env:HLGI_LIGHT_RELEVANCE_BASELINE -eq '1') {
    Write-Output ('Actual light collector SHA256: ' + (Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash)
    Write-Output ('Actual relevance helper SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot 'Runtime/HybridLumenGILightRelevance.cs') -Algorithm SHA256).Hash)
}
