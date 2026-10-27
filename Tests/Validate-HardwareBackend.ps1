param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-hardware-backend-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIHardwareBackend.cs") -Destination (Join-Path $runDirectory "HardwareBackend.cs")
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIRtasBudget.cs") -Destination (Join-Path $runDirectory "RtasBudget.cs")
foreach ($file in @("UnityStubs", "Program")) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneHardwareBackend/$file.cs.txt") -Destination (Join-Path $runDirectory "$file.cs")
}
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding utf8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet -- $SourceRoot
if ($LASTEXITCODE -ne 0) { throw "Actual-source hardware backend validation failed." }
Write-Output ("Runtime source SHA256: " + (Get-FileHash -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIHardwareBackend.cs") -Algorithm SHA256).Hash)

