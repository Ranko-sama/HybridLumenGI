param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$program = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "StandaloneEmissiveResources/Program.cs.txt"))
# C# verbatim strings preserve backslashes; double any literal quote in the path.
$program = $program.Replace('__SOURCE_ROOT__', $SourceRoot.Replace('"', '""'))
$sources = @{
    'HybridLumenGIEmissiveSampling.cs' = [IO.File]::ReadAllText((Join-Path $SourceRoot "Runtime/HybridLumenGIEmissiveSampling.cs"))
    'UnityStubs.cs' = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "StandaloneEmissiveResources/UnityStubs.cs.txt"))
    'Program.cs' = $program
}
& (Join-Path $PSScriptRoot "Invoke-CSharpHarness.ps1") -Name 'emissive-resources' -Sources $sources
Write-Output ("Runtime source SHA256: " + (Get-FileHash -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIEmissiveSampling.cs") -Algorithm SHA256).Hash)
Write-Output ("Feature source SHA256: " + (Get-FileHash -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIRendererFeature.cs") -Algorithm SHA256).Hash)
