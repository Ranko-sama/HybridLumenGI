param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-sdf-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
# Compile the runtime kernel used by both the Editor and deformation workers.
# Only Unity vector/bounds operations are adapted; this is not a Unity integration test.
$source = Get-Content -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIMeshSdfBake.cs") -Raw
Set-Content -LiteralPath (Join-Path $runDirectory "Baker.cs") -Value $source -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneSdf/UnityMath.cs.txt") -Destination (Join-Path $runDirectory "UnityMath.cs")
$program = "using HybridLumenGIMeshSdfBaker = HybridLumenGI.HybridLumenGIMeshSdfBake;`n" + (Get-Content -LiteralPath (Join-Path $PSScriptRoot "StandaloneSdf/Program.cs.txt") -Raw)
Set-Content -LiteralPath (Join-Path $runDirectory "Program.cs") -Value $program -Encoding UTF8
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding UTF8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "SDF numerical validation failed." }
