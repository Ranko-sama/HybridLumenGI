param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$runtime = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIGpuBudgetController.cs") -Raw
$program = Get-Content -LiteralPath (Join-Path $PSScriptRoot "StandaloneGpuBudget/Program.cs.txt") -Raw
# Compile the unchanged runtime class. No Unity stubs, Add-Type, or timing estimates.
& (Join-Path $PSScriptRoot "Invoke-CSharpHarness.ps1") -Name "gpu-budget" -TimeoutSeconds 120 -Sources @{
    "HybridLumenGIGpuBudgetController.cs" = $runtime
    "Program.cs" = $program
}
