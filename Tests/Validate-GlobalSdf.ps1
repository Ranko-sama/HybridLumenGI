param([string] $SourceRoot = (Split-Path -Parent $PSScriptRoot), [string] $CompilerPath = "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe", [string] $ReportPath = "")
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$runDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hlgi-global-sdf-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceRoot "Runtime/HybridLumenGIGlobalSdf.cs") -Destination (Join-Path $runDirectory "GlobalSdf.cs")
foreach ($file in @("UnityStubs", "Program")) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "StandaloneGlobalSdf/$file.cs.txt") -Destination (Join-Path $runDirectory "$file.cs")
}
Set-Content -LiteralPath (Join-Path $runDirectory "Check.csproj") -Encoding utf8 -Value '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>disable</Nullable></PropertyGroup></Project>'
& dotnet run --project (Join-Path $runDirectory "Check.csproj") --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) { throw "Actual-source global SDF scheduler validation failed." }

if (-not (Test-Path -LiteralPath $CompilerPath)) { throw "DXC not found; pass -CompilerPath." }
$shaderRoot = Join-Path $SourceRoot "Runtime/Resources/HybridLumenGI"
$compute = Join-Path $shaderRoot "HybridLumenGIGlobalSdf.compute"
$results = @()
foreach ($entry in @("CSMergeBricks", "CSPublishBricks")) {
    $diagnostics = (& $CompilerPath -T cs_6_0 -E $entry -I $shaderRoot -Fo (Join-Path $runDirectory "$entry.dxil") $compute 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    $results += [pscustomobject]@{ entry=$entry; exitCode=$exitCode; diagnostics=$diagnostics.Trim() }
}
$query = @'
#include "HybridLumenGIGlobalSdf.hlsl"
RWStructuredBuffer<float4> _ValidationResult;
[numthreads(1,1,1)] void CSQuery(uint3 id:SV_DispatchThreadID)
{
    float value; bool known=HLGIGlobalSdfEmptyDistance(float3(id),value);
    _ValidationResult[id.x]=float4(value,known?1:0,0,0);
}
'@
$queryPath = Join-Path $runDirectory "Query.hlsl"
Set-Content -LiteralPath $queryPath -Value $query -Encoding utf8
$diagnostics = (& $CompilerPath -T cs_6_0 -E CSQuery -I $shaderRoot -Fo (Join-Path $runDirectory "CSQuery.dxil") $queryPath 2>&1 | Out-String)
$exitCode = $LASTEXITCODE
$results += [pscustomobject]@{ entry="CSQuery"; exitCode=$exitCode; diagnostics=$diagnostics.Trim() }
$results | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $runDirectory "results.json") -Encoding utf8
if ($ReportPath) {
    [pscustomobject]@{
        utcTime=[DateTime]::UtcNow.ToString("o")
        scope="77 actual-source CPU scheduler assertions and native DXC; not Unity/GPU execution"
        compiler=$CompilerPath
        checks=$results
        sources=@("HybridLumenGIGlobalSdf.compute","HybridLumenGIGlobalSdf.hlsl","HybridLumenGISdfTrace.hlsl") | ForEach-Object {
            [pscustomobject]@{file=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $shaderRoot $_) -Algorithm SHA256).Hash}
        }
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding utf8
}
foreach ($result in $results) {
    Write-Output "$($result.entry): DXC exit $($result.exitCode)"
    if ($result.diagnostics) { Write-Output $result.diagnostics }
}
if ($results | Where-Object exitCode -ne 0) { throw "Global SDF HLSL compile validation failed." }
Write-Output "Native DXC: 3/3 entries passed. No Unity shader import, RenderGraph or GPU execution was performed."

