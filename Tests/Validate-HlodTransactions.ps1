param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-hlod-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
foreach($source in @("HybridLumenGIScene","HybridLumenGISceneBvh","HybridLumenGIHlodReadiness","HybridLumenGIRtasBudget")) { Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/$source.cs") -Destination (Join-Path $runDirectory "$source.cs") }
foreach($template in @("UnityStubs","SceneDependencies")) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/$template.cs.txt") -Destination (Join-Path $runDirectory "$template.cs") }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/HlodProgram.cs.txt") -Destination (Join-Path $runDirectory "Program.cs")
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "HLOD transaction validation failed." }
