param(
    [string]$CompilerPath = "",
    [string]$IncludeRoot = (Join-Path $env:TEMP "HybridLumenGI-shader-validation"),
    [string]$ReportPath = ""
)
$ErrorActionPreference = "Stop"
$startedUtc = [DateTime]::UtcNow.ToString("o")
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$shaderRoot = Join-Path $sourceRoot "Runtime/Resources/HybridLumenGI"
$IncludeRoot = [IO.Path]::GetFullPath($IncludeRoot)
if (-not $CompilerPath) {
    $found = Get-Command dxc -ErrorAction SilentlyContinue
    if ($found) { $CompilerPath = $found.Source }
    else {
        $sdkRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin"
        $found = Get-ChildItem -LiteralPath $sdkRoot -Filter dxc.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]x64[\\/]' } | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { $CompilerPath = $found.FullName }
    }
}
if (-not $CompilerPath -or -not (Test-Path -LiteralPath $CompilerPath)) { throw "Pass -CompilerPath with an installed x64 DXC path." }
if (-not (Test-Path -LiteralPath (Join-Path $IncludeRoot "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"))) {
    throw "Unity shader includes are missing. Populate this IncludeRoot using Validate-NativeDiffuseCapture.ps1 -DownloadIncludes first."
}
. (Join-Path $PSScriptRoot "Invoke-OfflineCheck.ps1")
$artifactRoot = Join-Path $env:TEMP ("hlgi-receiver-policy-dxc-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
$compilerInfo = Invoke-HLGIOfflineCheck -Name "compiler-version" -Executable $CompilerPath -Arguments @("--version") -LogDirectory $artifactRoot
if ($compilerInfo.exitCode -ne 0) { throw "DXC version query failed: $($compilerInfo.output)" }
$sourceNames = @("HybridLumenGISurface.shader", "HybridLumenGINativeDiffuseCapture.shader", "HybridLumenGIReceiverPolicyCapture.hlsl")
function Read-SourceHashes {
    foreach ($name in $sourceNames) {
        [pscustomobject]@{file="Runtime/Resources/HybridLumenGI/$name";sha256=(Get-FileHash -LiteralPath (Join-Path $shaderRoot $name) -Algorithm SHA256).Hash}
    }
}
$sources = @(Read-SourceHashes)
function Read-IncludeHashes {
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $IncludeRoot "Packages") -Recurse -File -Filter "*.hlsl" | Sort-Object FullName) {
        [pscustomobject]@{file=$file.FullName.Substring($IncludeRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
    }
}
$includes = @(Read-IncludeHashes)
$scriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
foreach ($capture in @("Surface", "NativeDiffuseCapture")) {
    $source = Get-Content -LiteralPath (Join-Path $shaderRoot ("HybridLumenGI$capture.shader")) -Raw -Encoding utf8
    $blocks = [regex]::Matches($source, '(?s)HLSLPROGRAM(.*?)ENDHLSL')
    if ($blocks.Count -ne 1) { throw "Expected one $capture capture program." }
    $body = $blocks[0].Groups[1].Value
    # DXC does not execute Unity pragmas. Assert that our explicit adapter defines
    # really enable instancing and its rendering-layer array in official includes.
    $body += "`n#if defined(INSTANCING_ON) && (!defined(UNITY_USE_RENDERINGLAYER_ARRAY) || !defined(UNITY_INSTANCING_ENABLED))`n#error Instanced rendering-layer adapter did not activate.`n#endif`n"
    Set-Content -LiteralPath (Join-Path $artifactRoot "$capture.hlsl") -Value $body -Encoding utf8
}
$checks = New-Object 'System.Collections.Generic.List[object]'
function Compile-Receiver([string]$Name, [string]$Capture, [string]$Stage, [string[]]$Defines, [bool]$Instancing) {
    $profile = if ($Stage -eq "VERTEX") { "vs_6_0" } else { "ps_6_0" }
    $entry = if ($Capture -eq "Surface") { if ($Stage -eq "VERTEX") { "Vert" } else { "Frag" } }
        else { if ($Stage -eq "VERTEX") { "LitPassVertex" } else { "HLGICaptureNativeDiffuse" } }
    $listing = Join-Path $artifactRoot "$Name.ll"
    $dxil = Join-Path $artifactRoot "$Name.dxil"
    # Fixed URP instancing uses FXC-style expansion before token pasting. Keep
    # official includes intact and request that supported DXC preprocessor mode.
    $arguments = @("-HV","2018","-flegacy-macro-expansion","-T",$profile,"-E",$entry,
        "-D","SHADER_API_D3D11=1","-D","SHADER_STAGE_$Stage=1","-D","UNITY_COMPILER_DXC=1",
        "-D","UNITY_VERSION=600000","-D","SHADER_TARGET=45","-I",$IncludeRoot,"-I",$shaderRoot,
        "-Fo",$dxil,"-Fc",$listing)
    if ($Instancing) { $Defines += @("INSTANCING_ON", "UNITY_INSTANCED_RENDERING_LAYER") }
    foreach ($define in $Defines) { $arguments += @("-D","$define=1") }
    $arguments += (Join-Path $artifactRoot "$Capture.hlsl")
    $result = Invoke-HLGIOfflineCheck -Name $Name -Executable $CompilerPath -Arguments $arguments -LogDirectory $artifactRoot
    $signature = $null; $signatureVerified = $false; $instanceArray = $null; $signatureLine = $null; $validationError = $null
    $exitCode = $result.exitCode
    if ($exitCode -eq 0) {
        $assembly = Get-Content -LiteralPath $listing -Raw -Encoding utf8
        if ($Stage -eq "FRAGMENT") {
            $target = if ($Capture -eq "Surface") { 2 } else { 3 }
            $match = [regex]::Match($assembly, '(?m)^.*SV_Target\s+' + $target + '\s+xy\s+\d+\s+TARGET\s+uint.*$')
            $signature = $match.Success; $signatureVerified = $match.Success; $signatureLine = $match.Value.Trim()
            if (-not $signature) { $validationError = "Unsigned two-channel MRT signature is absent."; $exitCode = 1 }
            if ($Instancing) {
                $instanceArray = $assembly.Contains("unity_RenderingLayerArray")
                if (-not $instanceArray) { $validationError = "Per-instance rendering-layer array was not emitted."; $exitCode = 1 }
            }
        } else {
            $match = [regex]::Match($assembly, '(?m)^.*SV_Position\s+0\s+xyzw\s+\d+\s+POS\s+float.*$')
            $signatureVerified = $match.Success; $signatureLine = $match.Value.Trim()
            if (-not $signatureVerified) { $validationError = "Vertex float4 position output is absent."; $exitCode = 1 }
        }
    }
    $checks.Add([pscustomobject]@{
        name=$Name;entry=$entry;profile=$profile;defines=@($Defines);arguments=$arguments
        exitCode=$exitCode;compilerExitCode=$result.exitCode;signatureVerified=$signatureVerified;signatureLine=$signatureLine;integerMrtSignature=$signature
        instancedRenderingLayerArray=$instanceArray;validationError=$validationError;diagnostics=$result.output.Trim();log=$result.log
        listing=$listing;dxil=$dxil;listingSha256=$(if(Test-Path -LiteralPath $listing){(Get-FileHash -LiteralPath $listing -Algorithm SHA256).Hash}else{$null})
        dxilSha256=$(if(Test-Path -LiteralPath $dxil){(Get-FileHash -LiteralPath $dxil -Algorithm SHA256).Hash}else{$null})
    })
    Write-Output "$Name exit=$exitCode uintMRT=$signature instancedArray=$instanceArray"
    if ($exitCode -ne 0) { Write-Output ($result.output.Trim() + " " + $validationError) }
}
foreach ($instancing in @($false, $true)) {
    $suffix = if ($instancing) { "instanced" } else { "perdraw" }
    Compile-Receiver "surface-$suffix-vs" "Surface" "VERTEX" @() $instancing
    for ($bits=0; $bits -lt 8; $bits++) {
        $defines=@();if($bits-band 1){$defines+="_METALLICSPECGLOSSMAP"};if($bits-band 2){$defines+="_EMISSION"};if($bits-band 4){$defines+="_OCCLUSIONMAP"}
        Compile-Receiver "surface-$suffix-ps-$bits" "Surface" "FRAGMENT" $defines $instancing
    }
}
foreach ($variant in @(@{name="sh";defines=@()},@{name="forward-plus-ssao";defines=@("_FORWARD_PLUS","_ADDITIONAL_LIGHTS","_SCREEN_SPACE_OCCLUSION","_LIGHT_LAYERS")})) {
    foreach ($stage in @("VERTEX", "FRAGMENT")) {
        Compile-Receiver "native-instanced-$($variant.name)-$stage" "NativeDiffuseCapture" $stage $variant.defines $true
    }
}
$sourcesAfter = @(Read-SourceHashes)
$sourceChanges = @($sources | Where-Object { $before=$_; @($sourcesAfter|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1 })
$includesAfter = @(Read-IncludeHashes)
$includeChanges = @($includes | Where-Object { $before=$_; @($includesAfter|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1 })
$scriptChanged = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash -ne $scriptSha256
$report = [ordered]@{
    schemaVersion=1;kind="ReceiverPolicyShaderValidation";startedUtc=$startedUtc;completedUtc=[DateTime]::UtcNow.ToString("o")
    status=$(if(@($checks|Where-Object exitCode -ne 0).Count -eq 0 -and $checks.Count -eq 22 -and $sourceChanges.Count -eq 0 -and $includeChanges.Count -eq 0 -and -not $scriptChanged){"passed"}else{"failed"})
    scope="22 selected actual capture HLSL entry points with unsigned MRT signatures and explicit instancing adapters; no Unity import, per-draw data, batching, render-target binding, physical GPU or raster-write verification."
    compiler=$CompilerPath;compilerVersion=$compilerInfo.output.Trim();compilerVersionLog=$compilerInfo.log
    includeRoot=$IncludeRoot;expectedUnityGraphicsRevision="feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53"
    compilerOptions=@("-HV","2018","-flegacy-macro-expansion")
    adapterDefines=@{common=@("SHADER_API_D3D11=1","UNITY_COMPILER_DXC=1","UNITY_VERSION=600000","SHADER_TARGET=45");instanced=@("INSTANCING_ON=1","UNITY_INSTANCED_RENDERING_LAYER=1")}
    artifactDirectory=$artifactRoot;script="Tests/Validate-ReceiverPolicyShaders.ps1";scriptSha256=$scriptSha256;scriptChanged=$scriptChanged
    sources=$sources;sourcesAfter=$sourcesAfter;sourceChanges=$sourceChanges;includes=$includes;includeChanges=$includeChanges;checks=@($checks.ToArray())
}
$destination = if ($ReportPath) { [IO.Path]::GetFullPath($ReportPath) } else { Join-Path $artifactRoot "receiver-policy-results.json" }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destination -Encoding utf8
Write-Output "Results: $destination"
if ($report.status -ne "passed") { exit 1 }
