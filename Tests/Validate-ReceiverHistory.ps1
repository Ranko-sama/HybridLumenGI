param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$sources = @{}
foreach ($name in @('HybridLumenGIReceiverRegistry','HybridLumenGIReceiverHistory','HybridLumenGIHistoryLifecycle','HybridLumenGIMeshSource')) {
    $sources[$name+'.cs'] = Get-Content -LiteralPath (Join-Path $SourceRoot ('Runtime/'+$name+'.cs')) -Raw
}
foreach ($name in @('Program','UnityStubs')) {
    $sources[$name+'.cs'] = Get-Content -LiteralPath (Join-Path $PSScriptRoot ('StandaloneReceiverHistory/'+$name+'.cs.txt')) -Raw
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'receiver-history' -Sources $sources
