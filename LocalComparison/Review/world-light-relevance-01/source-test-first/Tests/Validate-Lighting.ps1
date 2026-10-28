param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $SourceRoot 'Runtime/HybridLumenGILights.cs'
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'lighting' -Sources @{
    'HybridLumenGILights.cs' = [IO.File]::ReadAllText($runtime)
    'HybridLumenGILightRelevance.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/HybridLumenGILightRelevance.cs'))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneLighting/UnityStubs.cs.txt'))
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneLighting/Program.cs.txt'))
}
Write-Output ('Actual light collector SHA256: ' + (Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash)
Write-Output ('Actual relevance helper SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $SourceRoot 'Runtime/HybridLumenGILightRelevance.cs') -Algorithm SHA256).Hash)
