param(
    [string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$CompilerPath='',
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$artifactRoot=Join-Path $env:TEMP ('hlgi-radiance-validity-warp-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
$templateRoot=Join-Path $SourceRoot 'Tests/StandaloneRadianceValidity'
$shaderRoot=Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI'
. (Join-Path $PSScriptRoot 'Invoke-OfflineCheck.ps1')
$checks=New-Object 'System.Collections.Generic.List[object]'
$sourceNames=@('Runtime/Resources/HybridLumenGI/HybridLumenGIRadianceValidity.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIHit.hlsl',
    'Runtime/Resources/HybridLumenGI/HybridLumenGIScreenMaterial.hlsl',
    'Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl',
    'Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareTrace.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIRayFootprint.hlsl',
    'Tests/StandaloneRadianceValidity/RadianceValidityWarp.cpp.txt','Tests/StandaloneRadianceValidity/RadianceValidityHarness.hlsl',
    'Tests/StandaloneRadianceValidity/RadianceValidityOracle.mjs','Tests/StandaloneRadianceValidity/CMakeLists.txt',
    'Tests/Invoke-OfflineCheck.ps1','Tests/Validate-RadianceValidity.ps1')
function Extract-Function([string]$Text,[string]$Pattern) {
    $match=[regex]::Match($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::Multiline)
    if(-not $match.Success){throw ('Actual function declaration absent: '+$Pattern)}
    $open=$Text.IndexOf('{',$match.Index);$depth=0
    for($at=$open;$at -lt $Text.Length;$at++) {
        if($Text[$at] -eq '{'){$depth++}elseif($Text[$at] -eq '}'){$depth--;if($depth -eq 0){return $Text.Substring($match.Index,$at-$match.Index+1)}}
    }
    throw 'Unterminated actual HLSL function'
}
function Source-Hashes { foreach($file in $sourceNames){[pscustomobject]@{file=$file;sha256=(Get-FileHash -LiteralPath (Join-Path $SourceRoot $file) -Algorithm SHA256).Hash}} }
function Run-Check([string]$Name,[string]$Executable,[string[]]$Arguments) {
    $result=Invoke-HLGIOfflineCheck -Name $Name -Executable $Executable -Arguments $Arguments -LogDirectory $artifactRoot
    $result | Add-Member -NotePropertyName executable -NotePropertyValue $Executable
    $result | Add-Member -NotePropertyName arguments -NotePropertyValue $Arguments
    $checks.Add($result);Write-Output ($Name+' exit='+$result.exitCode)
    if($result.exitCode -ne 0){if($Name -eq 'warp-execute' -and $result.exitCode -eq 2){$script:environmentUnavailable=$true};throw ($Name+' failed: '+$result.output)}
    return $result
}
$script:environmentUnavailable=$false
$report=[ordered]@{schemaVersion=1;kind='RadianceValidityActualWarpValidation';status='running';startedUtc=[DateTime]::UtcNow.ToString('o');artifactDirectory=$artifactRoot;
    scope='Actual production radiance validity helpers and extracted committed-material publication (bridge call spy)/TraceShadow/DirectIrradiance/ProxyRadiance/TraceScreen on D3D12 WARP with explicit scene/texture dependency adapters. Not DXR traversal, Unity, full temporal reprojection, RenderGraph synchronization, texture filtering or physical GPU validation.';
    unityExecuted=$false;physicalGpuExecuted=$false;warpExecuted=$false}
$sources=@(Source-Hashes);$exitCode=1
try {
    if(-not $CompilerPath){
        $found=Get-Command dxc -ErrorAction SilentlyContinue
        if($found){$CompilerPath=$found.Source}else{
            $found=Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin') -Recurse -Filter dxc.exe -ErrorAction SilentlyContinue |
                Where-Object {$_.FullName -match '[\\/]x64[\\/]'} | Sort-Object FullName -Descending | Select-Object -First 1
            if($found){$CompilerPath=$found.FullName}
        }
    }
    if(-not $CompilerPath){throw 'Installed DXC is required. No tool installation is attempted.'}
    $node=(Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $vsResult=Run-Check 'vswhere' $vswhere @('-latest','-products','*','-version','[17.0,18.0)','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-format','json','-utf8')
    # Run-Check prints a concise progress string before its result object.
    $vsResult=@($vsResult|Where-Object {$_ -isnot [string]})[-1]
    $vs=@($vsResult.output|ConvertFrom-Json)[0]
    if(-not $vs.installationPath){throw 'An existing VS2022 x64 C++ toolchain is required.'}
    $cmake=Join-Path $vs.installationPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    if(-not (Test-Path -LiteralPath $cmake)){$cmake=(Get-Command cmake -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source}
    $report.tools=[ordered]@{vsInstallation=$vs.installationPath;cmake=$cmake;dxc=$CompilerPath;node=$node}
    Run-Check 'cmake-version' $cmake @('--version') | Out-Null
    Run-Check 'dxc-version' $CompilerPath @('--version') | Out-Null
    Run-Check 'oracle-prepare' $node @((Join-Path $templateRoot 'RadianceValidityOracle.mjs'),'prepare',$artifactRoot) | Out-Null
    $transport=[IO.File]::ReadAllText((Join-Path $shaderRoot 'HybridLumenGITransport.hlsl'))
    $kernels=[IO.File]::ReadAllText((Join-Path $shaderRoot 'HybridLumenGIKernels.hlsl'))
    $hardware=[IO.File]::ReadAllText((Join-Path $shaderRoot 'HybridLumenGIHardwareTrace.hlsl'))
    $exact=[IO.File]::ReadAllText((Join-Path $shaderRoot 'HybridLumenGIExactMesh.hlsl'))
    $committed=Extract-Function $exact '^void HLGIHardwareResolveCommittedMaterial\('
    $functions=@(
        $committed,
        (Extract-Function $transport '^HLGIRayFootprint HLGIPointQueryFootprint\('),
        (Extract-Function $transport '^bool TraceShadow\([^\r\n]*useRenderingLayers,\r?\n'),
        (Extract-Function $transport '^bool TraceShadow\([^\r\n]*out bool known\)'),
        (Extract-Function $transport '^bool TraceShadow\([^\r\n]*bool useRenderingLayers\)'),
        (Extract-Function $transport '^bool HLGIHitOwnerCurrent\('),
        (Extract-Function $transport '^float3 DirectIrradiance\([^\r\n]*bool receivesShadows,\r?\n'),
        (Extract-Function $transport '^float3 DirectIrradiance\([^\r\n]*bool receivesShadows,out bool known\)'),
        (Extract-Function $transport '^float3 DirectIrradiance\(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,out bool known\)'),
        (Extract-Function $transport '^float3 DirectIrradiance\(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers\)'),
        (Extract-Function $transport '^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,[^\r\n]*float emissionWeight,'),
        (Extract-Function $transport '^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,out float confidence\)'),
        (Extract-Function $transport '^float3 ProxyRadiance\(HLGIHit hit,out float confidence\)'),
        (Extract-Function $kernels '^bool TraceScreen\('))
    $actualFunctions=Join-Path $artifactRoot 'ActualTransportFunctions.hlsl'
    [IO.File]::WriteAllText($actualFunctions,($functions -join ([Environment]::NewLine+[Environment]::NewLine)),[Text.UTF8Encoding]::new($false))
    # Supplementary source wiring checks; the actual function bodies/helpers are
    # executed below. These checks do not claim full-kernel or Unity execution.
    $query=Extract-Function $hardware '^bool HLGIHardwareTraceQuery\('
    $candidate=$query.Substring($query.IndexOf('while(query.Proceed())'),$query.IndexOf('if(query.CommittedStatus()')-$query.IndexOf('while(query.Proceed())'))
    if($candidate.IndexOf('HLGIShadowOwnerAllowed(') -gt $candidate.IndexOf('HLGIHardwareEvaluateHit(') -or
        $candidate.IndexOf('if(!sideAllowed) continue;') -lt 0 -or
        $candidate.IndexOf('if(!HLGIHitCoverageBlocks(coverageKnown,covered)) continue;') -lt $candidate.IndexOf('HLGIHardwareEvaluateHit(') -or
        ([regex]::Matches($candidate,'query\.CommitNonOpaqueTriangleHit\(\)')).Count -ne 1 -or
        $candidate.IndexOf('query.CommitNonOpaqueTriangleHit()') -lt $candidate.IndexOf('HLGIHitCoverageBlocks(')) {throw 'Candidate cull/policy/coverage/commit wiring differs; unknown coverage must remain blocking.'}
    if($committed -notmatch 'if\(!coverageKnown \|\| !covered\) hit.flags\|=HLGI_HIT_MATERIAL_UNKNOWN;' -or
        $committed -notmatch 'if\(!materialKnown\) hit.flags\|=HLGI_HIT_MATERIAL_UNKNOWN\|HLGI_HIT_COVERAGE_CONFIRMED;' -or
        $committed -notmatch 'hit.materialDiffuse=material.diffuseReflectance' -or
        $committed -notmatch 'hit.shadingNormal=materialNormal;hit.flags\|=HLGI_HIT_UV_MATERIAL\|HLGI_HIT_SHADING_NORMAL') {throw 'Committed unknown/payload publication wiring differs.'}
    if($committed -notmatch 'else if\(resolveMaterial && !shadowQuery\)' -or
        $query -notmatch 'coneRadiusAtOrigin,coneSlope,shadowQuery,resolveMaterial,hit\)' -or
        $candidate -notmatch 'candidateRadius,true,shadowQuery' -or
        $transport -notmatch 'TraceSceneQuery\(o,d,maxT,false,false,0xffffffffu,0xffffffffu,false,result\)' -or
        $transport -notmatch 'if\(TraceSceneVisibilityHit\(e.anchor' -or
        $kernels -notmatch 'if\(!TraceSceneVisibilityHit\(position\+estimatedGeometricNormal') {throw 'Explicit ordinary visibility/full material purpose routing differs.'}
    $cache=Extract-Function $transport '^void CSUpdateCache\('
    if($cache.IndexOf('change.x>0.5') -lt 0 -or $cache.IndexOf('change.x>0.5') -gt $cache.IndexOf('HLGICommitCacheEstimate') -or
        $cache -notmatch 'HLGIAccumulateRadianceSample\(incoming,materialConfidence,weight,sum\)') {throw 'Actual cache invalidation/known-sample commit wiring differs.'}
    $temporal=$kernels.Substring($kernels.IndexOf('void CSTemporalIdentity('),$kernels.IndexOf('void CSFilter(')-$kernels.IndexOf('void CSTemporalIdentity('))
    if($temporal.IndexOf('HLGIResolveUnknownHistory(valid,history,moments') -lt $temporal.IndexOf('valid=valid && change.x<0.5') -or
        $temporal -notmatch 'HLGIHasRadianceMeasurement\(neighbor\)' -or $kernels -notmatch 'HLGIHasRadianceMeasurement\(center\)' -or
        $kernels -notmatch 'HLGIHasRadianceMeasurement\(sampleGI\)') {throw 'Actual temporal/filter validity wiring differs.'}
    $dxil=Join-Path $artifactRoot 'radiance-validity.dxil';$listing=Join-Path $artifactRoot 'radiance-validity.ll'
    Run-Check 'dxc-actual-helper' $CompilerPath @('-HV','2018','-T','cs_6_0','-E','CSRadianceValidityTest','-I',$shaderRoot,'-I',$artifactRoot,'-Fo',$dxil,'-Fc',$listing,(Join-Path $templateRoot 'RadianceValidityHarness.hlsl')) | Out-Null
    $assembly=Get-Content -LiteralPath $listing -Encoding utf8 -Raw
    if($assembly -notmatch '(?s)RadianceInput.*?Size:\s+208' -or $assembly -notmatch '(?s)RadianceOutput.*?Size:\s+368') {throw 'Actual DXIL input/output ABI differs from the frozen binary harness.'}
    $buildSource=Join-Path $artifactRoot 'source';$build=Join-Path $artifactRoot 'build';New-Item -ItemType Directory -Path $buildSource | Out-Null
    Copy-Item -LiteralPath (Join-Path $templateRoot 'CMakeLists.txt') -Destination (Join-Path $buildSource 'CMakeLists.txt')
    Copy-Item -LiteralPath (Join-Path $templateRoot 'RadianceValidityWarp.cpp.txt') -Destination (Join-Path $buildSource 'RadianceValidityWarp.cpp')
    Run-Check 'cmake-configure' $cmake @('-S',$buildSource,'-B',$build,'-G','Visual Studio 17 2022','-A','x64',('-DCMAKE_GENERATOR_INSTANCE='+$vs.installationPath)) | Out-Null
    $compilerMetadata=Get-ChildItem -LiteralPath (Join-Path $build 'CMakeFiles') -Recurse -File -Filter CMakeCXXCompiler.cmake | Select-Object -First 1
    if(-not $compilerMetadata){throw 'Configured C++ compiler metadata is absent.'}
    $compilerText=Get-Content -LiteralPath $compilerMetadata.FullName -Encoding utf8 -Raw
    foreach($field in @('CMAKE_CXX_COMPILER','CMAKE_CXX_COMPILER_ID','CMAKE_CXX_COMPILER_VERSION')){
        $match=[regex]::Match($compilerText,'set\('+[regex]::Escape($field)+' "([^"]+)"\)')
        if(-not $match.Success){throw ('Missing actual compiler metadata '+$field)}
        $report.tools[$field]=$match.Groups[1].Value
    }
    Run-Check 'cmake-build' $cmake @('--build',$build,'--config','Release','--target','RadianceValidityWarp') | Out-Null
    $exe=Join-Path $build 'Release/RadianceValidityWarp.exe'
    Run-Check 'warp-execute' $exe @($dxil,(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot 'outputs.bin')) | Out-Null
    $report.warpExecuted=$true
    Run-Check 'oracle-verify' $node @((Join-Path $templateRoot 'RadianceValidityOracle.mjs'),'verify',$artifactRoot) | Out-Null
    $report.oracle=Get-Content -LiteralPath (Join-Path $artifactRoot 'oracle-results.json') -Encoding utf8 -Raw | ConvertFrom-Json
    if($report.oracle.status -ne 'passed' -or $report.oracle.count -ne 2534){throw 'Unexpected actual-helper oracle coverage.'}
    $report.artifacts=@();foreach($file in @($actualFunctions,$dxil,$listing,$exe,(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot 'outputs.bin'),(Join-Path $artifactRoot 'oracle.json'),(Join-Path $artifactRoot 'oracle-results.json'))){
        $report.artifacts += [pscustomobject]@{path=$file;bytes=(Get-Item -LiteralPath $file).Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
    $report.status='passed';$exitCode=0
}catch{$report.status=if($script:environmentUnavailable){'unavailable'}else{'failed'};$report.error=$_.ToString();$report.errorLocation=$_.ScriptStackTrace;$exitCode=if($script:environmentUnavailable){2}else{1}}
finally {
    $after=@(Source-Hashes);$changed=@($sources|Where-Object {$before=$_;@($after|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
    if($changed.Count){$report.status='failed';$report.sourceChanges=$changed;$exitCode=1}
    $report.sources=$sources;$report.sourcesAfter=$after;$report.checks=@($checks.ToArray());$report.completedUtc=[DateTime]::UtcNow.ToString('o')
    $destination=if($ReportPath){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $artifactRoot 'radiance-validity-results.json'}
    [IO.File]::WriteAllText($destination,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($true))
    Write-Output ('RadianceValidity '+$report.status+'; report: '+$destination)
    if($report.error){Write-Output $report.error}
    if($report.oracle){Write-Output ($report.oracle|ConvertTo-Json -Compress)}
}
exit $exitCode
