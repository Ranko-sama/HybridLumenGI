param([string]$SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runtime = Join-Path $SourceRoot 'Runtime/HybridLumenGIMeshSource.cs'
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'mesh-source' -Sources @{
    'MeshSource.cs' = [IO.File]::ReadAllText($runtime)
    'Program.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StandaloneMeshSource/Program.cs.txt'))
}
Write-Output ('Actual MeshSource SHA256: ' + (Get-FileHash -LiteralPath $runtime -Algorithm SHA256).Hash)
