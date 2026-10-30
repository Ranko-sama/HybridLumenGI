param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
# Actual recorder; Unity/RenderGraph and registry rows are recording adapters.
# The real ReceiverSkinPose is exercised by Validate-ReceiverHistory.ps1.
$sources = @{'ReceiverIdentityPass.cs'=(Get-Content -LiteralPath (Join-Path $SourceRoot 'Runtime/HybridLumenGIReceiverIdentityPass.cs') -Raw)}
foreach ($name in @('Program','UnityStubs')) {
    $sources[$name+'.cs']=Get-Content -LiteralPath (Join-Path $PSScriptRoot ('StandaloneReceiverIdentityPass/'+$name+'.cs.txt')) -Raw
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'receiver-identity-pass' -Sources $sources
