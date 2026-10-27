param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-streaming-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIChunkStreaming.cs") -Destination (Join-Path $runDirectory "ChunkStreaming.cs")
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIAssetPageStreaming.cs") -Destination (Join-Path $runDirectory "AssetPageStreaming.cs")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/AssetPageStreamingChecks.cs.txt") -Destination (Join-Path $runDirectory "AssetPageStreamingChecks.cs")
foreach($template in @("UnityStubs","SceneDependencies")) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/$template.cs.txt") -Destination (Join-Path $runDirectory "$template.cs") }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/StreamingProgram.cs.txt") -Destination (Join-Path $runDirectory "Program.cs")
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "Chunk streaming validation failed." }
