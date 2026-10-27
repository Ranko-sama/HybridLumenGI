param(
    [string]$CompilerPath = "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe",
    [string]$IncludeRoot = (Join-Path $env:TEMP "HybridLumenGI-shader-validation"),
    [switch]$DownloadIncludes,
    [string]$ReportPath = ""
)
$ErrorActionPreference = "Stop"
$revision = "feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53"
$shaderRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../Runtime/Resources/HybridLumenGI"))
$IncludeRoot = [IO.Path]::GetFullPath($IncludeRoot)
New-Item -ItemType Directory -Path $IncludeRoot -Force | Out-Null
if ($DownloadIncludes) {
    $seen = [Collections.Generic.HashSet[string]]::new()
    function Fetch-Include([string]$Relative) {
        $Relative = $Relative.Replace("\", "/")
        if (!$Relative.StartsWith("Packages/") -or !$seen.Add($Relative)) { return }
        if ($Relative -match "ShaderLibrary/API/(?!D3D11|Validate)" -or $Relative -match "render-pipelines\.(gamecore|ps5|ps4|xboxone)/") { return }
        $target = [IO.Path]::GetFullPath((Join-Path $IncludeRoot $Relative))
        if (!$target.StartsWith($IncludeRoot + [IO.Path]::DirectorySeparatorChar)) { throw "Include escapes validation root." }
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Unity-Technologies/Graphics/$revision/$Relative" -OutFile $target
        $source = Get-Content -LiteralPath $target -Raw
        foreach ($match in [regex]::Matches($source, '#include\s+"([^"]+)"')) {
            $path = $match.Groups[1].Value
            if (!$path.StartsWith("Packages/")) { $path = [IO.Path]::GetDirectoryName($Relative).Replace("\", "/") + "/" + $path }
            Fetch-Include $path
        }
    }
    Fetch-Include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
    Fetch-Include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
}
if (!(Test-Path -LiteralPath $CompilerPath)) { throw "Pass -CompilerPath with an installed DXC path." }
$shader = Join-Path $shaderRoot "HybridLumenGINativeDiffuseCapture.shader"
$source = Get-Content -LiteralPath $shader -Raw
$blocks = [regex]::Matches($source, '(?s)HLSLPROGRAM(.*?)ENDHLSL')
if ($blocks.Count -ne 1) { throw "Expected exactly one native diffuse capture program." }
$inputPath = Join-Path $IncludeRoot "NativeDiffuseCapture.validation.hlsl"
Set-Content -LiteralPath $inputPath -Value $blocks[0].Groups[1].Value -Encoding utf8
$results = [Collections.Generic.List[object]]::new()
$variants = @(
    @{ name="sh-pixel"; defines=@() },
    @{ name="sh-vertex"; defines=@("EVALUATE_SH_VERTEX") },
    @{ name="sh-mixed-normal"; defines=@("EVALUATE_SH_MIXED","_NORMALMAP") },
    @{ name="metal-textured"; defines=@("_METALLICSPECGLOSSMAP","_NORMALMAP","_OCCLUSIONMAP","_EMISSION") },
    @{ name="specular-detail"; defines=@("_SPECULAR_SETUP","_METALLICSPECGLOSSMAP","_NORMALMAP","_DETAIL_SCALED") },
    @{ name="parallax-cutout"; defines=@("_PARALLAXMAP","_DETAIL_MULX2","_ALPHATEST_ON","_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A") },
    @{ name="static-lightmap"; defines=@("LIGHTMAP_ON") },
    @{ name="directional-lightmap"; defines=@("LIGHTMAP_ON","DIRLIGHTMAP_COMBINED") },
    @{ name="dynamic-directional-lightmap"; defines=@("LIGHTMAP_ON","DYNAMICLIGHTMAP_ON","DIRLIGHTMAP_COMBINED","USE_LEGACY_LIGHTMAPS") },
    @{ name="shadowmask"; defines=@("LIGHTMAP_ON","LIGHTMAP_SHADOW_MIXING","SHADOWS_SHADOWMASK","_MAIN_LIGHT_SHADOWS_CASCADE","_SHADOWS_SOFT_HIGH") },
    @{ name="forward-plus-ssao"; defines=@("_FORWARD_PLUS","_ADDITIONAL_LIGHTS","_SCREEN_SPACE_OCCLUSION","_LIGHT_LAYERS") },
    @{ name="dbuffer-three"; defines=@("_DBUFFER_MRT3","_NORMALMAP","_SCREEN_SPACE_OCCLUSION") },
    @{ name="fog-linear"; defines=@("FOG_LINEAR") },
    @{ name="fog-exp"; defines=@("FOG_EXP") },
    @{ name="fog-exp2"; defines=@("FOG_EXP2") },
    @{ name="lod-crossfade"; defines=@("LOD_FADE_CROSSFADE") },
    @{ name="reject-subtractive"; defines=@("LIGHTMAP_ON","LIGHTMAP_SHADOW_MIXING") },
    @{ name="reject-apv-l1"; defines=@("PROBE_VOLUMES_L1") },
    @{ name="reject-apv-l2"; defines=@("PROBE_VOLUMES_L2") },
    @{ name="reject-debug"; defines=@("DEBUG_DISPLAY") },
    @{ name="reject-transparent"; defines=@("_SURFACE_TYPE_TRANSPARENT") }
)
foreach ($variant in $variants) {
    foreach ($stage in @("VERTEX", "FRAGMENT")) {
        $profile = if ($stage -eq "VERTEX") { "vs_6_0" } else { "ps_6_0" }
        $entry = if ($stage -eq "VERTEX") { "LitPassVertex" } else { "HLGICaptureNativeDiffuse" }
        $name = "native-diffuse-$($variant.name)-$stage"
        # URP 17 source predates HLSL 2021 short-circuit vector restrictions.
        $arguments = @("-HV","2018","-T",$profile,"-E",$entry,"-D","SHADER_API_D3D11=1","-D","SHADER_STAGE_$stage=1",
            "-D","UNITY_COMPILER_DXC=1","-D","UNITY_VERSION=600000","-I",$IncludeRoot,"-I",$shaderRoot,
            "-Fo",(Join-Path $IncludeRoot "$name.dxil"))
        foreach ($keyword in $variant.defines) { $arguments += @("-D","$keyword=1") }
        $arguments += $inputPath
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $diagnostics = (& $CompilerPath @arguments 2>&1 | Out-String)
            $exitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $oldPreference }
        $results.Add([pscustomobject]@{name=$name;exitCode=$exitCode;diagnostics=$diagnostics.Trim()})
        Write-Output "$name exit=$exitCode"
        if ($exitCode -ne 0) { Write-Output $diagnostics.Trim() }
    }
}
$report = [pscustomobject]@{
    utcTime=[DateTime]::UtcNow.ToString("o");revision=$revision;compiler=$CompilerPath;
    sha256=(Get-FileHash -LiteralPath $shader -Algorithm SHA256).Hash;
    limitation="Selected DXC variants only. Does not prove Unity import, override keyword mapping, per-object data, RenderGraph bindings, GPU pixels, build stripping, or performance.";
    checks=@($results)
}
$reportPath = if ($ReportPath) { [IO.Path]::GetFullPath($ReportPath) } else { Join-Path $IncludeRoot "native-diffuse-results.json" }
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportPath -Encoding utf8
Write-Output "Results: $reportPath"
if (@($results | Where-Object {$_.exitCode -ne 0}).Count -gt 0) { exit 1 }
