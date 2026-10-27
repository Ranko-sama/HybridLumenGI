param(
    [string]$CompilerPath = "",
    [string]$IncludeRoot = (Join-Path $env:TEMP "HybridLumenGI-shader-validation"),
    [string]$ReportPath = ""
)
$ErrorActionPreference = 'Stop'
$started = [DateTime]::UtcNow.ToString('o')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$shaders = Join-Path $root 'Runtime/Resources/HybridLumenGI'
$IncludeRoot = [IO.Path]::GetFullPath($IncludeRoot)
if (-not $CompilerPath) {
    $found = Get-Command dxc -ErrorAction SilentlyContinue
    if ($found) { $CompilerPath = $found.Source }
    else {
        $found = Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin') -Filter dxc.exe -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '[\\/]x64[\\/]' } | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) { $CompilerPath = $found.FullName }
    }
}
if (-not $CompilerPath -or -not (Test-Path -LiteralPath $CompilerPath)) { throw 'An installed x64 DXC is required; pass -CompilerPath.' }
if (-not (Test-Path -LiteralPath (Join-Path $IncludeRoot 'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl'))) { throw 'Populate the fixed Unity include cache with Validate-NativeDiffuseCapture.ps1 -DownloadIncludes first.' }
. (Join-Path $PSScriptRoot 'Invoke-OfflineCheck.ps1')
$artifacts = Join-Path $env:TEMP ('hlgi-receiver-identity-dxc-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $artifacts | Out-Null
$scriptHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$names = @('HybridLumenGIReceiverIdentity.shader','HybridLumenGIReceiverIdentity.compute','HybridLumenGIReceiverIdentity.hlsl','HybridLumenGIScreenSampling.hlsl')
function Source-Hashes {
    foreach($name in $names) { [pscustomobject]@{file='Runtime/Resources/HybridLumenGI/'+$name;sha256=(Get-FileHash -LiteralPath (Join-Path $shaders $name) -Algorithm SHA256).Hash} }
}
function Include-Hashes {
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $IncludeRoot 'Packages') -Recurse -File -Filter '*.hlsl' | Sort-Object FullName) {
        [pscustomobject]@{file=$file.FullName.Substring($IncludeRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
    }
}
$sources=@(Source-Hashes);$includes=@(Include-Hashes)
$version=Invoke-HLGIOfflineCheck -Name 'compiler-version' -Executable $CompilerPath -Arguments @('--version') -LogDirectory $artifacts
if($version.exitCode -ne 0){throw $version.output}
$source=Get-Content -LiteralPath (Join-Path $shaders $names[0]) -Raw -Encoding utf8
$shared=[regex]::Match($source,'(?s)HLSLINCLUDE(.*?)ENDHLSL')
$programs=[regex]::Matches($source,'(?s)HLSLPROGRAM(.*?)ENDHLSL')
if(-not $shared.Success -or $programs.Count -ne 3){throw 'Expected one shared include and three fixed identity raster passes.'}
$culls=@('Off','Front','Back')
foreach($cull in $culls){if($source -notmatch ('Name "Cull'+$cull+'"\s+Cull '+$cull+' ZWrite Off ZTest Always Blend Off ColorMask 0')){throw ('Fixed pass state missing: '+$cull)}}
$checks=New-Object 'System.Collections.Generic.List[object]'
function Compile-Identity([string]$Name,[string]$Entry,[string]$Profile,[string]$File,[bool]$DebugVariant=$false) {
    $listing=Join-Path $artifacts ($Name+'.ll');$dxil=Join-Path $artifacts ($Name+'.dxil')
    $stage=if($Profile -eq 'vs_6_0'){'VERTEX'}elseif($Profile -eq 'ps_6_0'){'FRAGMENT'}else{'COMPUTE'}
    $compilerArguments=@('-HV','2018','-flegacy-macro-expansion','-T',$Profile,'-E',$Entry,'-D','SHADER_API_D3D11=1','-D',('SHADER_STAGE_'+$stage+'=1'),'-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-D','SHADER_TARGET=50','-I',$IncludeRoot,'-I',$shaders,'-Fo',$dxil,'-Fc',$listing,$File)
    if($DebugVariant){$compilerArguments+=@('-D','DEBUG_DISPLAY=1')}
    $run=Invoke-HLGIOfflineCheck -Name $Name -Executable $CompilerPath -Arguments $compilerArguments -LogDirectory $artifacts
    $valid=$run.exitCode -eq 0;$contractError=$null;$signature=$null
    if($valid){
        $assembly=Get-Content -LiteralPath $listing -Raw -Encoding utf8
        if($DebugVariant){
            if($assembly -notmatch 'dx.op.discard' -or $assembly -match 'atomicCompareExchange|atomicBinOp|_HLGI_IdentityCandidates'){$valid=$false;$contractError='Debug variant must discard without any candidate UAV/atomic claim.'}
        }elseif($Profile -eq 'ps_6_0'){
            $signature=[regex]::Match($assembly,'(?m)^.*SV_PrimitiveID.*PRIMID\s+uint.*$').Value.Trim()
            if(-not $signature -or $assembly -notmatch '(?m)^;\s*_HLGI_IdentityCandidates\s+UAV\s+struct\s+r/w\s+U\d+\s+u1\s+1\s*$' -or
                $assembly -notmatch 'atomicCompareExchange' -or $assembly -notmatch 'atomicBinOp'){$valid=$false;$contractError='Missing uint primitive input, u1 structured UAV, or atomic instructions.'}
        }elseif($Profile -eq 'vs_6_0'){
            $signature=[regex]::Match($assembly,'(?m)^.*SV_Position\s+0\s+xyzw\s+\d+\s+POS\s+float.*$').Value.Trim()
            if(-not $signature){$valid=$false;$contractError='Missing float4 raster position.'}
        }elseif($Entry -eq 'CSResolveIdentity'){
            if($assembly -notmatch '(?s)struct (?:hostlayout\.struct\.)?HLGIReceiverIdentityObject.*?key;\s*; Offset:\s+64.*?flags;\s*; Offset:\s+72.*?reserved;\s*; Offset:\s+76.*?Size:\s+80' -or $assembly -notmatch '_HLGI_IdentityOutput\s+UAV\s+u32\s+2d'){$valid=$false;$contractError='Missing 80-byte object row or unsigned resolve output.'}
        }
    }
    $checks.Add([pscustomobject]@{name=$Name;entry=$Entry;profile=$Profile;debugVariant=$DebugVariant;exitCode=$(if($valid){0}else{1});compilerExitCode=$run.exitCode;signatureVerified=$valid;signatureLine=$signature;validationError=$contractError;diagnostics=$run.output.Trim();arguments=$compilerArguments;log=$run.log;listing=$listing;dxil=$dxil;listingSha256=$(if(Test-Path -LiteralPath $listing){(Get-FileHash -LiteralPath $listing -Algorithm SHA256).Hash}else{$null});dxilSha256=$(if(Test-Path -LiteralPath $dxil){(Get-FileHash -LiteralPath $dxil -Algorithm SHA256).Hash}else{$null})})
    Write-Output ($Name+' compiler='+$run.exitCode+' contract='+$valid)
    if(-not $valid){Write-Output ($run.output+$contractError)}
}
for($i=0;$i -lt 3;$i++){
    $adapter=Join-Path $artifacts ('pass'+$i+'.hlsl')
    [IO.File]::WriteAllText($adapter,$shared.Groups[1].Value+$programs[$i].Groups[1].Value,[Text.UTF8Encoding]::new($false))
    Compile-Identity ('identity-cull-'+$culls[$i]+'-vs') 'HLGIIdentityVertex' 'vs_6_0' $adapter
    Compile-Identity ('identity-cull-'+$culls[$i]+'-ps') 'HLGIIdentityFragment' 'ps_6_0' $adapter
    Compile-Identity ('identity-cull-'+$culls[$i]+'-ps-debug') 'HLGIIdentityFragment' 'ps_6_0' $adapter $true
}
foreach($entry in @('CSClearIdentity','CSMaskUnknownIdentity','CSResolveIdentity')){Compile-Identity $entry $entry 'cs_6_0' (Join-Path $shaders $names[1])}
$after=@(Source-Hashes);$includeAfter=@(Include-Hashes)
$changed=@($sources | Where-Object {$before=$_;@($after|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
$includeChanged=@($includes | Where-Object {$before=$_;@($includeAfter|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
$scriptChanged=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash -ne $scriptHash
$status=if($checks.Count -eq 12 -and @($checks|Where-Object exitCode -ne 0).Count -eq 0 -and $changed.Count -eq 0 -and $includeChanged.Count -eq 0 -and -not $scriptChanged){'passed'}else{'failed'}
$report=[ordered]@{schemaVersion=1;kind='ReceiverIdentityShaderValidation';startedUtc=$started;completedUtc=[DateTime]::UtcNow.ToString('o');status=$status;scope='12 actual HLSL entry points and selected DXIL ABI/atomic signatures, including three DEBUG_DISPLAY discard-only PS variants. Development evidence only: no Unity import, raster visibility, UAV barriers, per-draw bindings or physical GPU verification.';compiler=$CompilerPath;compilerVersion=$version.output.Trim();compilerVersionLog=$version.log;expectedUnityGraphicsRevision='feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53';includeRoot=$IncludeRoot;includes=$includes;includeChanges=$includeChanged;artifactDirectory=$artifacts;script='Tests/Validate-ReceiverIdentityShaders.ps1';scriptSha256=$scriptHash;scriptChanged=$scriptChanged;sources=$sources;sourcesAfter=$after;sourceChanges=$changed;checks=@($checks.ToArray())}
$destination=if($ReportPath){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $artifacts 'receiver-identity-results.json'}
[IO.File]::WriteAllText($destination,($report|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
Write-Output ('Results: '+$destination)
if($status -ne 'passed'){exit 1}
