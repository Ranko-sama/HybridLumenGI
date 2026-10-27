param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$sources=@{
    'ScreenBudget.cs'=(Get-Content -LiteralPath (Join-Path $SourceRoot 'Runtime/HybridLumenGIScreenBudget.cs') -Raw)
    'Program.cs'=(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'StandaloneScreenBudget/Program.cs.txt') -Raw)
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'screen-budget' -Sources $sources
