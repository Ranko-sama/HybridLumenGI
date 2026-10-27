param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$source=Join-Path $SourceRoot 'Runtime/HybridLumenGIReceiverIdentityFrame.cs'
# Actual complete builder; Unity values and already-frozen source/history inputs are
# adapters. They do not validate Unity rasterization, the registry or receipt producer.
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'receiver-identity-frame' -Sources @{
    'HybridLumenGIReceiverIdentityFrame.cs'=[IO.File]::ReadAllText($source)
    'Adapters.cs'=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneReceiverIdentityFrame/Adapters.cs.txt'))
    'Program.cs'=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneReceiverIdentityFrame/Program.cs.txt'))
}
Write-Output ('Actual identity-frame SHA256: '+(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash)
