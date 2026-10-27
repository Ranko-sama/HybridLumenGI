param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-residency-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIScene.cs") -Destination (Join-Path $runDirectory "Scene.cs")
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGISceneBvh.cs") -Destination (Join-Path $runDirectory "SceneBvh.cs")
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIHlodReadiness.cs") -Destination (Join-Path $runDirectory "HlodReadiness.cs")
foreach($template in @("UnityStubs","SceneDependencies")) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/$template.cs.txt") -Destination (Join-Path $runDirectory "$template.cs") }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/SceneProgram.cs.txt") -Destination (Join-Path $runDirectory "Program.cs")
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "Scene residency/dirty-region validation failed." }
