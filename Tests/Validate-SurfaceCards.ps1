param(
    [string]$CompilerPath = "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe",
    [string]$IncludeRoot = (Join-Path $env:TEMP "HybridLumenGI-shader-validation")
)
$ErrorActionPreference = "Stop"
$packageRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$shaderRoot = Join-Path $packageRoot "Runtime/Resources/HybridLumenGI"
$IncludeRoot = [System.IO.Path]::GetFullPath($IncludeRoot)
$litInput = Join-Path $IncludeRoot "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
if (-not (Test-Path -LiteralPath $litInput)) { throw "Provide the official Unity 6000.0/staging LitInput and BRDF include dependencies in IncludeRoot." }
$shaderText = Get-Content -LiteralPath (Join-Path $shaderRoot "HybridLumenGICardCapture.shader") -Raw
$blocks = [regex]::Matches($shaderText, '(?s)HLSLPROGRAM(.*?)ENDHLSL')
if ($blocks.Count -ne 2) { throw "Expected capture and tile-clear shader programs." }
$capturePath = Join-Path $IncludeRoot "CardCapture.validation.hlsl"
$clearPath = Join-Path $IncludeRoot "CardClear.validation.hlsl"
Set-Content -LiteralPath $capturePath -Value $blocks[0].Groups[1].Value -Encoding utf8
Set-Content -LiteralPath $clearPath -Value $blocks[1].Groups[1].Value -Encoding utf8
$results = [System.Collections.Generic.List[object]]::new()
function Compile-Card([string]$Name, [string]$Source, [string]$Entry, [string]$Profile, [string]$Stage, [string[]]$Keywords = @()) {
    $arguments = @("-T",$Profile,"-E",$Entry,"-D","SHADER_API_D3D11=1","-D","SHADER_STAGE_$($Stage)=1",
        "-D","UNITY_COMPILER_DXC=1","-D","UNITY_VERSION=600000","-I",$IncludeRoot,"-I",$shaderRoot,
        "-Fo",(Join-Path $IncludeRoot "$Name.dxil"))
    foreach($keyword in $Keywords) { $arguments += @("-D","$keyword=1") }
    $arguments += $Source
    $diagnostics = (& $CompilerPath @arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    $results.Add([pscustomobject]@{name=$Name;entry=$Entry;exitCode=$exitCode;diagnostics=$diagnostics.Trim()})
    Write-Output "$Name exit=$exitCode"
    if($diagnostics) { Write-Output $diagnostics.Trim() }
}
$variants = @(
    @(),
    @("_METALLICSPECGLOSSMAP"),
    @("_SPECULAR_SETUP","_METALLICSPECGLOSSMAP"),
    @("_NORMALMAP"),
    @("_EMISSION","_OCCLUSIONMAP"),
    @("_NORMALMAP","_DETAIL_MULX2","_METALLICSPECGLOSSMAP","_EMISSION","_OCCLUSIONMAP"),
    @("_NORMALMAP","_DETAIL_SCALED","_SPECULAR_SETUP","_METALLICSPECGLOSSMAP","_EMISSION","_OCCLUSIONMAP"),
    @("_NORMALMAP","_PARALLAXMAP","_DETAIL_SCALED","_ALPHATEST_ON","_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A","_EMISSION","_OCCLUSIONMAP")
)
Compile-Card "card-vertex" $capturePath "CardVert" "vs_6_0" "VERTEX"
for($index=0;$index -lt $variants.Count;$index++) {
    Compile-Card "card-fragment-$index" $capturePath "CardFrag" "ps_6_0" "FRAGMENT" $variants[$index]
}
Compile-Card "card-clear-vertex" $clearPath "CardClearVert" "vs_6_0" "VERTEX"
Compile-Card "card-clear-fragment" $clearPath "CardClearFrag" "ps_6_0" "FRAGMENT"
$cacheHarness = @'
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
struct HLGIProxy { float4 centerShape,extentsRoughness,albedo,emission,identity; };
StructuredBuffer<HLGIProxy> _HLGI_Proxies;
int _HLGI_ProxyCount;
#include "HybridLumenGISurfaceCache.hlsl"
RWStructuredBuffer<float4> Result;
[numthreads(1,1,1)]
void CSValidate(uint3 id:SV_DispatchThreadID) {
    HLGISurfaceSample s;
    bool hit = HLGITrySurfacePatch(id.x,uint2(1,2),4,s);
    HLGISurfaceSample m;
    bool material = hit && HLGITrySurfaceMaterial((int)s.ownerSlot,s.position,s.normal,m);
    float2 uv;
    bool projected = HLGISurfaceCardUv(id.x,s.position,uv);
    Result[id.x] = float4(s.diffuse+m.emission,(hit && material && projected)?1:0);
}
'@
$cachePath = Join-Path $IncludeRoot "SurfaceCache.validation.hlsl"
Set-Content -LiteralPath $cachePath -Value $cacheHarness -Encoding utf8
Compile-Card "surface-cache-query" $cachePath "CSValidate" "cs_6_0" "COMPUTE"
Compile-Card "surface-anchor-build" (Join-Path $shaderRoot "HybridLumenGISurfaceAnchors.compute") "CSBuildAnchors" "cs_6_0" "COMPUTE"
$report = [pscustomobject]@{
    utcTime=[DateTime]::UtcNow.ToString("o");compiler=$CompilerPath;
    limitation="Native DXC compilation of selected material variants and query harness only; no Unity import, GPU execution, coverage or visual certification.";
    sources=@(Get-ChildItem -LiteralPath $shaderRoot -File | Where-Object {$_.Name -match '(CardCapture|SurfaceCache|SurfaceAnchors)\.(shader|hlsl|compute)$'} | ForEach-Object {
        [pscustomobject]@{file=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    });
    checks=@($results)
}
$resultPath = Join-Path $IncludeRoot "surface-card-results.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
Write-Output "Results: $resultPath"
if(@($results | Where-Object {$_.exitCode -ne 0}).Count -gt 0) { exit 1 }
