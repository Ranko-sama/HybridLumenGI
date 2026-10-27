param(
    [string]$CompilerPath = "",
    [string]$IncludeRoot = (Join-Path $env:TEMP "HybridLumenGI-shader-validation"),
    [string]$UnityGraphicsRevision = "feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53",
    [switch]$DownloadIncludes,
    [switch]$OnlyColorProbe,
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$packageRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$shaderRoot = Join-Path $packageRoot "Runtime/Resources/HybridLumenGI"
$IncludeRoot = [System.IO.Path]::GetFullPath($IncludeRoot)
New-Item -ItemType Directory -Path $IncludeRoot -Force | Out-Null

if (-not $CompilerPath) {
    $found = Get-Command dxc -ErrorAction SilentlyContinue
    if ($found) { $CompilerPath = $found.Source }
    else {
        $sdkRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin"
        $found = Get-ChildItem -LiteralPath $sdkRoot -Filter dxc.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]x64[\\/]' } |
            Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { $CompilerPath = $found.FullName }
    }
}
if (-not $CompilerPath -or -not (Test-Path -LiteralPath $CompilerPath)) {
    throw "DXC was not found. Pass -CompilerPath with the Windows SDK x64 dxc.exe path."
}

# Dependency download is opt-in. Third-party source is retained only in the chosen
# temporary include directory, never copied into the runtime package.
if ($DownloadIncludes) {
    if ($UnityGraphicsRevision -notmatch '^[a-fA-F0-9]{40}$') { throw "Use a full Unity Graphics commit SHA." }
    $sourceBase = "https://raw.githubusercontent.com/Unity-Technologies/Graphics/$UnityGraphicsRevision/"
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    function Fetch-Include([string]$Relative) {
        $Relative = $Relative.Replace("\", "/")
        if (-not $Relative.StartsWith("Packages/")) { return }
        if ($Relative -match "ShaderLibrary/API/(?!D3D11|Validate)") { return }
        if ($Relative -match "render-pipelines\.(gamecore|ps5|ps4|xboxone)/") { return }
        if (-not $seen.Add($Relative)) { return }
        $target = [System.IO.Path]::GetFullPath((Join-Path $IncludeRoot $Relative))
        if (-not $target.StartsWith($IncludeRoot + [System.IO.Path]::DirectorySeparatorChar)) {
            throw "Include path escapes the validation directory: $Relative"
        }
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        Invoke-WebRequest -Uri ($sourceBase + $Relative) -OutFile $target
        $source = Get-Content -LiteralPath $target -Raw
        foreach ($include in [regex]::Matches($source, '#include\s+"([^"]+)"')) {
            $dependency = $include.Groups[1].Value
            if (-not $dependency.StartsWith("Packages/")) {
                $dependency = [System.IO.Path]::GetDirectoryName($Relative).Replace("\", "/") + "/" + $dependency
            }
            Fetch-Include $dependency
        }
    }
    Fetch-Include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    Fetch-Include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
    Fetch-Include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
}

$core = Join-Path $IncludeRoot "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
if (-not (Test-Path -LiteralPath $core)) {
    throw "Unity includes are missing. Re-run with -DownloadIncludes or supply -IncludeRoot."
}
$adapterRoot = Join-Path $IncludeRoot "Adapters"
New-Item -ItemType Directory -Path $adapterRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "ShaderAdapters/UnityRayQuery.cginc.txt") -Destination (Join-Path $adapterRoot "UnityRayQuery.cginc")
$results = [System.Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot "Invoke-OfflineCheck.ps1")
$compilerLogRoot = Join-Path $env:TEMP ("hlgi-dxc-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $compilerLogRoot | Out-Null
function Compile-Entry([string]$Name, [string]$Source, [string]$Entry, [string]$Profile, [string]$Stage, [string[]]$Keywords = @()) {
    $arguments = @(
        "-T", $Profile, "-E", $Entry,
        "-D", "SHADER_API_D3D11=1", "-D", "SHADER_STAGE_$($Stage)=1",
        "-D", "UNITY_COMPILER_DXC=1", "-D", "UNITY_VERSION=600000",
        "-I", $adapterRoot, "-I", $IncludeRoot, "-I", $shaderRoot,
        "-Fo", (Join-Path $IncludeRoot "$Name.dxil")
    )
    foreach ($keyword in $Keywords) { $arguments += @("-D", "$keyword=1") }
    $arguments += $Source
    # Native stderr becomes a terminating NativeCommandError under PowerShell 5
    # with Stop. Preserve the compiler's actual diagnostics/exit code instead of
    # aborting on its first line and losing the failed entry's report.
    $compiled = Invoke-HLGIOfflineCheck -Name $Name -Executable $CompilerPath -Arguments $arguments -LogDirectory $compilerLogRoot
    $diagnostics = $compiled.output
    $exitCode = $compiled.exitCode
    $results.Add([pscustomobject]@{ name=$Name; entry=$Entry; profile=$Profile; exitCode=$exitCode; diagnostics=$diagnostics.Trim() })
    Write-Output "$Name exit=$exitCode"
    if ($diagnostics) { Write-Output $diagnostics.Trim() }
}

if (-not $OnlyColorProbe) {
foreach ($backend in @("software", "hardware", "exact-software")) {
    $source = if ($backend -eq "hardware") { "HybridLumenGIHardware.compute" } elseif($backend -eq "exact-software") { "HybridLumenGIExactSoftware.compute" } else { "HybridLumenGI.compute" }
    $profile = if ($backend -eq "hardware") { "cs_6_5" } else { "cs_6_0" }
    foreach ($entry in @("CSUpdateCache", "CSTrace", "CSTemporal", "CSFilter")) {
        Compile-Entry "$backend-$entry" (Join-Path $shaderRoot $source) $entry $profile "COMPUTE"
    }
    Compile-Entry "$backend-CSTemporalIdentity" (Join-Path $shaderRoot $source) "CSTemporalIdentity" $profile "COMPUTE" @("HLGI_RECEIVER_IDENTITY")
}

$compositeText = Get-Content -LiteralPath (Join-Path $shaderRoot "HybridLumenGIComposite.shader") -Raw
$compositeCode = [regex]::Match($compositeText, '(?s)HLSLINCLUDE(.*?)ENDHLSL').Groups[1].Value
if (-not $compositeCode) { throw "Composite HLSLINCLUDE block not found." }
$compositeSource = Join-Path $IncludeRoot "Composite.validation.hlsl"
Set-Content -LiteralPath $compositeSource -Value $compositeCode -Encoding utf8
Compile-Entry "composite-vertex" $compositeSource "Vert" "vs_6_0" "VERTEX"
Compile-Entry "composite-fragment" $compositeSource "Frag" "ps_6_0" "FRAGMENT"

$surfaceText = Get-Content -LiteralPath (Join-Path $shaderRoot "HybridLumenGISurface.shader") -Raw
$surfaceCode = [regex]::Match($surfaceText, '(?s)HLSLPROGRAM(.*?)ENDHLSL').Groups[1].Value
if (-not $surfaceCode) { throw "Surface HLSLPROGRAM block not found." }
$surfaceSource = Join-Path $IncludeRoot "Surface.validation.hlsl"
Set-Content -LiteralPath $surfaceSource -Value $surfaceCode -Encoding utf8
for ($variant = 0; $variant -lt 8; $variant++) {
    $keywords = @()
    if ($variant -band 1) { $keywords += "_METALLICSPECGLOSSMAP" }
    if ($variant -band 2) { $keywords += "_EMISSION" }
    if ($variant -band 4) { $keywords += "_OCCLUSIONMAP" }
    Compile-Entry "surface-$variant-vertex" $surfaceSource "Vert" "vs_6_0" "VERTEX" $keywords
    Compile-Entry "surface-$variant-fragment" $surfaceSource "Frag" "ps_6_0" "FRAGMENT" $keywords
}
}

$colorText = Get-Content -LiteralPath (Join-Path $shaderRoot "HybridLumenGIColorContractProbe.shader") -Raw
$colorCode = [regex]::Match($colorText, '(?s)HLSLINCLUDE(.*?)ENDHLSL').Groups[1].Value
if (-not $colorCode) { throw "Color probe HLSLINCLUDE block not found." }
$colorSource = Join-Path $IncludeRoot "ColorContractProbe.validation.hlsl"
Set-Content -LiteralPath $colorSource -Value $colorCode -Encoding utf8
Compile-Entry "color-probe-vertex" $colorSource "ProbeVertex" "vs_6_0" "VERTEX"
foreach ($entry in @("ProbeBase", "ProbeSpecular", "ProbeEmission")) {
    Compile-Entry "color-probe-$entry" $colorSource $entry "ps_6_0" "FRAGMENT"
}

if (-not $OnlyColorProbe) {
    $cardText = Get-Content -LiteralPath (Join-Path $shaderRoot "HybridLumenGICardCapture.shader") -Raw
    $cardBlocks = [regex]::Matches($cardText, '(?s)HLSLPROGRAM(.*?)ENDHLSL')
    if ($cardBlocks.Count -ne 2) { throw "Expected card capture and tile-clear shader programs." }
    $cardSource = Join-Path $IncludeRoot "CardCapture.validation.hlsl"
    $cardClearSource = Join-Path $IncludeRoot "CardClear.validation.hlsl"
    Set-Content -LiteralPath $cardSource -Value $cardBlocks[0].Groups[1].Value -Encoding utf8
    Set-Content -LiteralPath $cardClearSource -Value $cardBlocks[1].Groups[1].Value -Encoding utf8
    # Selected semantic combinations, not an exhaustive material keyword matrix.
    $cardVariants = @(
        @(),
        @("_METALLICSPECGLOSSMAP"),
        @("_SPECULAR_SETUP", "_METALLICSPECGLOSSMAP"),
        @("_NORMALMAP"),
        @("_EMISSION", "_OCCLUSIONMAP"),
        @("_NORMALMAP", "_DETAIL_MULX2", "_METALLICSPECGLOSSMAP", "_EMISSION", "_OCCLUSIONMAP"),
        @("_NORMALMAP", "_DETAIL_SCALED", "_SPECULAR_SETUP", "_METALLICSPECGLOSSMAP", "_EMISSION", "_OCCLUSIONMAP"),
        @("_NORMALMAP", "_PARALLAXMAP", "_DETAIL_SCALED", "_ALPHATEST_ON", "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A", "_EMISSION", "_OCCLUSIONMAP")
    )
    Compile-Entry "card-vertex" $cardSource "CardVert" "vs_6_0" "VERTEX"
    for ($variant = 0; $variant -lt $cardVariants.Count; $variant++) {
        Compile-Entry "card-fragment-$variant" $cardSource "CardFrag" "ps_6_0" "FRAGMENT" $cardVariants[$variant]
    }
    Compile-Entry "card-clear-vertex" $cardClearSource "CardClearVert" "vs_6_0" "VERTEX"
    Compile-Entry "card-clear-fragment" $cardClearSource "CardClearFrag" "ps_6_0" "FRAGMENT"
    $cacheHarness = @'
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
struct HLGIProxy { float4 centerShape,extentsRoughness,albedo,emission,identity; };
StructuredBuffer<HLGIProxy> _HLGI_Proxies;
int _HLGI_ProxyCount;
#include "HybridLumenGISurfaceCache.hlsl"
StructuredBuffer<HLGIHit> ValidationHits;
RWStructuredBuffer<float4> Result;
[numthreads(1,1,1)]
void CSValidate(uint3 id:SV_DispatchThreadID) {
    HLGISurfaceSample s;
    bool hit = HLGITrySurfacePatch(id.x,uint2(1,2),4,s);
    HLGISurfaceSample m;
    bool material = hit && HLGITrySurfaceMaterial((int)s.ownerSlot,s.position,s.geometricNormal,m);
    HLGISurfaceSample bound;
    bool exact = HLGITrySurfaceMaterialHit(ValidationHits[id.x],bound);
    float2 uv;
    bool projected = HLGISurfaceCardUv(id.x,s.position,uv);
    Result[id.x] = float4(s.diffuse+m.emission+(exact?bound.diffuse:0),(hit && material && projected)?1:0);
}
'@
    $cacheSource = Join-Path $IncludeRoot "SurfaceCache.validation.hlsl"
    Set-Content -LiteralPath $cacheSource -Value $cacheHarness -Encoding utf8
    Compile-Entry "surface-cache-query" $cacheSource "CSValidate" "cs_6_0" "COMPUTE"
    Compile-Entry "surface-anchor-build" (Join-Path $shaderRoot "HybridLumenGISurfaceAnchors.compute") "CSBuildAnchors" "cs_6_0" "COMPUTE"
    Compile-Entry "emissive-proposal-build" (Join-Path $shaderRoot "HybridLumenGIEmissiveProposals.compute") "CSBuildEmissiveProposals" "cs_6_0" "COMPUTE"
}

$manifest = Get-ChildItem -LiteralPath $shaderRoot -File |
    Where-Object { $_.Extension -in @(".compute", ".hlsl", ".shader") } |
    ForEach-Object { [pscustomobject]@{ file=$_.Name; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } }
$report = [pscustomobject]@{
    utcTime = [DateTime]::UtcNow.ToString("o")
    compiler = $CompilerPath
    compilerVersion = (& $CompilerPath --version | Out-String).Trim()
    includeSource = "Unity-Technologies/Graphics $UnityGraphicsRevision (6000.0/staging); see downloaded include hashes"
    limitation = "Native DX12 RayQuery adapter only; not Unity Editor import, runtime, driver execution or visual validation."
    subset = if ($OnlyColorProbe) { "color property probe only" } else { "all listed shader entry points" }
    rayQueryAdapterSha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot "ShaderAdapters/UnityRayQuery.cginc.txt") -Algorithm SHA256).Hash
    sources = @($manifest)
    includes = @(Get-ChildItem -LiteralPath (Join-Path $IncludeRoot "Packages") -File -Recurse | ForEach-Object {
        [pscustomobject]@{ file=$_.FullName.Substring($IncludeRoot.Length + 1); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    checks = @($results)
}
$resultPath = if ($ReportPath) { [IO.Path]::GetFullPath($ReportPath) } else { Join-Path $IncludeRoot "shader-results.json" }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
Write-Output "Results: $resultPath"
if (@($results | Where-Object { $_.exitCode -ne 0 }).Count -gt 0) { exit 1 }
