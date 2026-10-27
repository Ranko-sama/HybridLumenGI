param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-change-regions-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
# Compile the current runtime implementation unchanged. The adapter records its GPU API calls.
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIChangeRegions.cs") -Destination (Join-Path $runDirectory "ChangeRegions.cs")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneChanges/Adapters.cs.txt") -Destination (Join-Path $runDirectory "Adapters.cs")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneChanges/Program.cs.txt") -Destination (Join-Path $runDirectory "Program.cs")
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet -- $SourceRoot
if ($LASTEXITCODE -ne 0) { throw "Local change-region validation failed." }
