param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot),[string]$RepresentationSource,[switch]$RepresentationOnly,[switch]$ExpectSingleObserver)
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-streaming-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
if(!$RepresentationOnly){
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIChunkStreaming.cs") -Destination (Join-Path $runDirectory "ChunkStreaming.cs")
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIAssetPageStreaming.cs") -Destination (Join-Path $runDirectory "AssetPageStreaming.cs")
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/AssetPageStreamingChecks.cs.txt") -Destination (Join-Path $runDirectory "AssetPageStreamingChecks.cs")
foreach($template in @("UnityStubs","SceneDependencies")) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/$template.cs.txt") -Destination (Join-Path $runDirectory "$template.cs") }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneBvh/StreamingProgram.cs.txt") -Destination (Join-Path $runDirectory "Program.cs")
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "Chunk streaming validation failed." }
}
$representationDirectory=Join-Path $runDirectory 'Representation'
New-Item -ItemType Directory -Path $representationDirectory | Out-Null
if(!$RepresentationSource){$RepresentationSource=Join-Path $SourceRoot 'Runtime/HybridLumenGIStreamedRepresentation.cs'}
Copy-Item -LiteralPath $RepresentationSource -Destination (Join-Path $representationDirectory 'Representation.cs')
foreach($source in @('HybridLumenGIAssetPageStreaming','HybridLumenGIAssetPageStreamer')){
    Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/$source.cs") -Destination (Join-Path $representationDirectory "$source.cs")
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'StandaloneBvh/UnityStubs.cs.txt') -Destination (Join-Path $representationDirectory 'UnityStubs.cs')
foreach($source in @('Adapters','Program')){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneStreamedRepresentation/$source.cs.txt") -Destination (Join-Path $representationDirectory "$source.cs")
}
Set-Content -LiteralPath (Join-Path $representationDirectory 'Check.csproj') -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
$representationArguments=@();if($ExpectSingleObserver){$representationArguments+= '--expect-single-observer'}
& dotnet run --project (Join-Path $representationDirectory 'Check.csproj') --configuration Release --verbosity quiet -- @representationArguments
if($LASTEXITCODE -ne 0){throw 'Actual streamed-representation demand validation failed.'}
