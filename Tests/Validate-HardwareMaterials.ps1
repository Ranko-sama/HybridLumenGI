param(
    [string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$CompilerPath='',
    [string]$IncludeRoot=(Join-Path $env:TEMP 'HybridLumenGI-shader-validation'),
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$artifactRoot=Join-Path $env:TEMP ('hlgi-hardware-materials-warp-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
$templateRoot=Join-Path $SourceRoot 'Tests/StandaloneHardwareMaterials'
$shaderRoot=Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI'
. (Join-Path $PSScriptRoot 'Invoke-OfflineCheck.ps1')
$checks=New-Object 'System.Collections.Generic.List[object]'
$sourceNames=@('Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareMaterials.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl',
    'Runtime/Resources/HybridLumenGI/HybridLumenGIHitMaterials.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIRayTextures.hlsl',
    'Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareSurface.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareNormals.hlsl',
    'Tests/StandaloneHardwareMaterials/HardwareMaterialsWarp.cpp.txt','Tests/StandaloneHardwareMaterials/HardwareMaterialsHarness.hlsl',
    'Tests/StandaloneHardwareMaterials/HardwareMaterialsOracle.mjs','Tests/StandaloneHardwareMaterials/CMakeLists.txt','Tests/Invoke-OfflineCheck.ps1','Tests/Validate-HardwareMaterials.ps1')
function Source-Hashes { foreach($file in $sourceNames){[pscustomobject]@{file=$file;sha256=(Get-FileHash -LiteralPath (Join-Path $SourceRoot $file) -Algorithm SHA256).Hash}} }
function Run-Check([string]$Name,[string]$Executable,[string[]]$Arguments) {
    $result=Invoke-HLGIOfflineCheck -Name $Name -Executable $Executable -Arguments $Arguments -LogDirectory $artifactRoot
    $result | Add-Member -NotePropertyName executable -NotePropertyValue $Executable
    $result | Add-Member -NotePropertyName arguments -NotePropertyValue $Arguments
    $checks.Add($result);Write-Output ($Name+' exit='+$result.exitCode)
    if($result.exitCode -ne 0){if($Name -like 'warp-execute-*' -and $result.exitCode -eq 2){$script:environmentUnavailable=$true};throw ($Name+' failed: '+$result.output)}
    return $result
}
$script:environmentUnavailable=$false
$report=[ordered]@{schemaVersion=1;kind='HardwareMaterialsActualWarpValidation';status='running';startedUtc=[DateTime]::UtcNow.ToString('o');artifactDirectory=$artifactRoot;
    scope='Actual runtime hardware material bridge with compile-time constant full/surface-coverage/shadow-coverage calls and point/orthographic material views, sampler, evaluator, TBN and LOD on D3D12 WARP. Independent double material and projected circular-footprint oracle. Exact type declarations extracted from ExactMesh, shared by hardware and software tracing. Not dynamic purpose selection, Unity, DXR traversal, native texture upload, physical GPU or a performance acceptance test.';
    selectedDxcEntries=9;softwareFenceWaitLimitMs=180000;unityExecuted=$false;physicalGpuExecuted=$false;warpExecuted=$false}
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
    $includeCopy=Join-Path $artifactRoot 'includes';New-Item -ItemType Directory -Path $includeCopy | Out-Null
    Copy-Item -LiteralPath (Join-Path $IncludeRoot 'Packages') -Destination $includeCopy -Recurse
    $report.unityGraphicsRevision='feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53'
    $report.includes=@(Get-ChildItem -LiteralPath (Join-Path $includeCopy 'Packages') -File -Recurse | ForEach-Object {
        [pscustomobject]@{file=$_.FullName.Substring($includeCopy.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    $trace=Get-Content -LiteralPath (Join-Path $shaderRoot 'HybridLumenGIExactMesh.hlsl') -Raw -Encoding utf8
    $extracted=''
    foreach($type in @('HLGIHardwareInstance','HLGITriangleNormals')){
        $matches=[regex]::Matches($trace,'(?s)struct\s+'+[regex]::Escape($type)+'\s*\{.*?\};')
        if($matches.Count -ne 1){throw ('Expected exactly one actual struct '+$type)}
        $extracted+=$matches[0].Value+"`n"
    }
    $types=Join-Path $includeCopy 'HardwareTraceTypes.hlsl'
    [IO.File]::WriteAllText($types,$extracted,[Text.UTF8Encoding]::new($false))
    $report.extractedTypes=[ordered]@{source='Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl';path=$types;sha256=(Get-FileHash -LiteralPath $types -Algorithm SHA256).Hash;types=@('HLGIHardwareInstance','HLGITriangleNormals')}
    $artifacts=New-Object 'System.Collections.Generic.List[string]'
    foreach($variant in @('rgag-full','rgag-coverage','rgag-shadow','rgb-full','rgb-coverage','rgb-shadow','ag-full','ag-coverage','ag-shadow')){
        $encoding,$kind=$variant.Split('-')
        $variantRoot=Join-Path $artifactRoot $variant
        Run-Check ('oracle-prepare-'+$variant) $node @((Join-Path $templateRoot 'HardwareMaterialsOracle.mjs'),'prepare',$variantRoot,$encoding,$kind) | Out-Null
        $dxil=Join-Path $variantRoot 'hardware-materials.dxil';$listing=Join-Path $variantRoot 'hardware-materials.ll'
        $entry=if($kind -eq 'full'){'CSHardwareMaterialsFull'}elseif($kind -eq 'coverage'){'CSHardwareMaterialsCoverage'}else{'CSHardwareMaterialsShadow'}
        $arguments=@('-HV','2018','-T','cs_6_0','-E',$entry,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',$includeCopy,'-I',$shaderRoot,'-Fo',$dxil,'-Fc',$listing)
        if($encoding -eq 'rgb'){$arguments+=@('-D','UNITY_NO_DXT5nm=1')}
        if($encoding -eq 'ag'){$arguments+=@('-D','UNITY_ASTC_NORMALMAP_ENCODING=1')}
        $arguments+=(Join-Path $templateRoot 'HardwareMaterialsHarness.hlsl')
        Run-Check ('dxc-actual-material-'+$variant) $CompilerPath $arguments | Out-Null
        $assembly=Get-Content -LiteralPath $listing -Encoding utf8 -Raw
        if($assembly -notmatch '(?s)HardwareMaterialInput.*?Size:\s+320' -or $assembly -notmatch '(?s)HardwareMaterialOutput.*?Size:\s+112' -or
            $assembly -notmatch 'column_major float4x4 normalToWorld;\s*; Offset:\s+0' -or
            $assembly -notmatch 'attributes;\s*; Offset:\s+128' -or $assembly -notmatch 'float4 objectRow0;\s*; Offset:\s+208' -or
            $assembly -notmatch 'float4 uvY;\s*; Offset:\s+192' -or $assembly -notmatch 'uint4 controls;\s*; Offset:\s+304' -or
            $assembly -notmatch '(?s)HLGIHitMaterialRecord.*?Size:\s+240' -or $assembly -notmatch '(?s)HLGIHardwareMaterialBinding.*?Size:\s+32' -or
            $assembly -notmatch '(?s)HLGITriangleSurface.*?Size:\s+96' -or $assembly -notmatch '(?s)HLGIRayTextureMetadata.*?Size:\s+64') {throw 'Actual DXIL bridge ABI differs from the binary harness.'}
        $expectedBindings=@('_HLGI_RayTextureMetadata','_HLGI_RayTextureTexels','_HLGI_HitMaterials','_HLGI_HardwareMaterialBindings','_HLGI_HardwareTriangleSurface','_Inputs')
        for($slot=0;$slot -lt $expectedBindings.Count;$slot++){
            if($assembly -notmatch ('(?m)^;\s*'+[regex]::Escape($expectedBindings[$slot])+'\s+texture\s+struct\s+r/o\s+T\d+\s+t'+$slot+'\s+1\s*$')){throw ('Unexpected actual SRV binding '+$expectedBindings[$slot])}
        }
        foreach($file in @($dxil,$listing,(Join-Path $variantRoot 'inputs.bin'),(Join-Path $variantRoot 'oracle.json'))){$artifacts.Add($file)}
    }
    $buildSource=Join-Path $artifactRoot 'source';$build=Join-Path $artifactRoot 'build';New-Item -ItemType Directory -Path $buildSource | Out-Null
    Copy-Item -LiteralPath (Join-Path $templateRoot 'CMakeLists.txt') -Destination (Join-Path $buildSource 'CMakeLists.txt')
    Copy-Item -LiteralPath (Join-Path $templateRoot 'HardwareMaterialsWarp.cpp.txt') -Destination (Join-Path $buildSource 'HardwareMaterialsWarp.cpp')
    Run-Check 'cmake-configure' $cmake @('-S',$buildSource,'-B',$build,'-G','Visual Studio 17 2022','-A','x64',('-DCMAKE_GENERATOR_INSTANCE='+$vs.installationPath)) | Out-Null
    $compilerMetadata=Get-ChildItem -LiteralPath (Join-Path $build 'CMakeFiles') -Recurse -File -Filter CMakeCXXCompiler.cmake | Select-Object -First 1
    if(-not $compilerMetadata){throw 'Configured C++ compiler metadata is absent.'}
    $compilerText=Get-Content -LiteralPath $compilerMetadata.FullName -Encoding utf8 -Raw
    foreach($field in @('CMAKE_CXX_COMPILER','CMAKE_CXX_COMPILER_ID','CMAKE_CXX_COMPILER_VERSION')){
        $match=[regex]::Match($compilerText,'set\('+[regex]::Escape($field)+' "([^"]+)"\)')
        if(-not $match.Success){throw ('Missing actual compiler metadata '+$field)}
        $report.tools[$field]=$match.Groups[1].Value
    }
    Run-Check 'cmake-build' $cmake @('--build',$build,'--config','Release','--target','HardwareMaterialsWarp') | Out-Null
    $exe=Join-Path $build 'Release/HardwareMaterialsWarp.exe'
    $report.oracle=@();$artifacts.Add($exe)
    foreach($variant in @('rgag-full','rgag-coverage','rgag-shadow','rgb-full','rgb-coverage','rgb-shadow','ag-full','ag-coverage','ag-shadow')){
        $encoding,$kind=$variant.Split('-')
        $variantRoot=Join-Path $artifactRoot $variant
        Run-Check ('warp-execute-'+$variant) $exe @((Join-Path $variantRoot 'hardware-materials.dxil'),(Join-Path $variantRoot 'inputs.bin'),(Join-Path $variantRoot 'outputs.bin')) | Out-Null
        $report.warpExecuted=$true
        Run-Check ('oracle-verify-'+$variant) $node @((Join-Path $templateRoot 'HardwareMaterialsOracle.mjs'),'verify',$variantRoot,$encoding,$kind) | Out-Null
        $oracle=Get-Content -LiteralPath (Join-Path $variantRoot 'oracle-results.json') -Encoding utf8 -Raw | ConvertFrom-Json
        if($oracle.status -ne 'passed' -or $oracle.count -ne $(if($kind -eq 'full'){248}elseif($kind -eq 'coverage'){149}else{152})){throw 'Unexpected actual-material oracle coverage.'}
        $report.oracle+=@($oracle)
        $artifacts.Add((Join-Path $variantRoot 'outputs.bin'));$artifacts.Add((Join-Path $variantRoot 'oracle-results.json'))
    }
    $report.artifacts=@();foreach($file in $artifacts){
        $report.artifacts += [pscustomobject]@{path=$file;bytes=(Get-Item -LiteralPath $file).Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
    $report.status='passed';$exitCode=0
}catch{$report.status=if($script:environmentUnavailable){'unavailable'}else{'failed'};$report.error=$_.ToString();$report.errorLocation=$_.ScriptStackTrace;$exitCode=if($script:environmentUnavailable){2}else{1}}
finally {
    $after=@(Source-Hashes);$changed=@($sources|Where-Object {$before=$_;@($after|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
    if($changed.Count){$report.status='failed';$report.sourceChanges=$changed;$exitCode=1}
    $report.sources=$sources;$report.sourcesAfter=$after;$report.checks=@($checks.ToArray());$report.completedUtc=[DateTime]::UtcNow.ToString('o')
    $destination=if($ReportPath){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $artifactRoot 'hardware-materials-results.json'}
    [IO.File]::WriteAllText($destination,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($true))
    Write-Output ('HardwareMaterials '+$report.status+'; report: '+$destination)
    if($report.error){Write-Output $report.error}
    if($report.oracle){Write-Output ($report.oracle|ConvertTo-Json -Compress)}
}
exit $exitCode

