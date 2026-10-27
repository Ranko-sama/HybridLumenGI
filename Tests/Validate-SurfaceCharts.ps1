param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$runtime = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGISurfaceCharts.cs") -Raw
$stubs = Get-Content -LiteralPath (Join-Path $PSScriptRoot "StandaloneSurfaceCharts/UnityStubs.cs.txt") -Raw
$program = Get-Content -LiteralPath (Join-Path $PSScriptRoot "StandaloneSurfaceCharts/Program.cs.txt") -Raw
& (Join-Path $PSScriptRoot "Invoke-CSharpHarness.ps1") -Name "surface-charts" -TimeoutSeconds 120 -Sources @{
    "HybridLumenGISurfaceCharts.cs" = $runtime
    "UnityStubs.cs" = $stubs
    "Program.cs" = $program
}
