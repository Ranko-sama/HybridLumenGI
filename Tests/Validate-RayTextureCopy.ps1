param(
    [string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$CompilerPath='',
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$artifactRoot=Join-Path $env:TEMP ('hlgi-ray-texture-copy-warp-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
$templateRoot=Join-Path $SourceRoot 'Tests/StandaloneRayTextureCopy'
$shaderRoot=Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI'
. (Join-Path $PSScriptRoot 'Invoke-OfflineCheck.ps1')
$checks=New-Object 'System.Collections.Generic.List[object]'
$sourceNames=@('Runtime/Resources/HybridLumenGI/HybridLumenGIRayTextureCopy.hlsl',
    'Runtime/Resources/HybridLumenGI/HybridLumenGIRayTextureCopy.compute','Tests/StandaloneRayTextureCopy/RayTextureCopyWarp.cpp.txt',
    'Tests/StandaloneRayTextureCopy/RayTextureCopyOracle.mjs','Tests/StandaloneRayTextureCopy/CMakeLists.txt','Tests/Invoke-OfflineCheck.ps1','Tests/Validate-RayTextureCopy.ps1')
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
$report=[ordered]@{schemaVersion=1;kind='RayTextureCopyActualWarpValidation';status='running';startedUtc=[DateTime]::UtcNow.ToString('o');artifactDirectory=$artifactRoot;
    scope='Actual Begin/CopyMip/Finish runtime DXIL on D3D12 WARP with real multi-mip float32/sRGB8 Texture2D resources and reduced SRVs, UAV barriers and fence readback. Independent source-pixel/sRGB oracle. Not Unity importer/streaming, reserved tiled-resource misses, DXR or physical GPU.';
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
    Run-Check 'oracle-prepare' $node @((Join-Path $templateRoot 'RayTextureCopyOracle.mjs'),'prepare',$artifactRoot) | Out-Null
    $dxils=@();$listings=@();$report.compilerEntries=@()
    foreach($entry in @('CSBeginRayTextureCopy','CSCopyRayTextureMip','CSFinishRayTextureCopy','CSCopyRayTextureRange')){
        $dxil=Join-Path $artifactRoot ($entry+'.dxil');$listing=Join-Path $artifactRoot ($entry+'.ll')
        Run-Check ('dxc-'+$entry) $CompilerPath @('-HV','2018','-T','cs_6_0','-E',$entry,'-I',$shaderRoot,'-Fo',$dxil,'-Fc',$listing,(Join-Path $shaderRoot 'HybridLumenGIRayTextureCopy.hlsl')) | Out-Null
        $assembly=Get-Content -LiteralPath $listing -Encoding utf8 -Raw
        if($assembly -notmatch '(?s)HLGIRayTextureCopyMetadata.*?Size:\s+64' -or $assembly -notmatch 'float4 sampling;\s*; Offset:\s+48' -or
            $assembly -notmatch '(?s)HLGIRayTextureCopyParameters.*?Size:\s+24' -or $assembly -notmatch '_HLGI_CopyTextureCapacity;\s*; Offset:\s+12'){
            throw ('Actual DXIL metadata/parameters ABI differs: '+$entry)
        }
        $dxils+=$dxil;$listings+=$listing;$report.compilerEntries += [pscustomobject]@{entry=$entry;profile='cs_6_0';exitCode=0;dxilPath=$dxil;listingPath=$listing}
    }
    $buildSource=Join-Path $artifactRoot 'source';$build=Join-Path $artifactRoot 'build';New-Item -ItemType Directory -Path $buildSource | Out-Null
    Copy-Item -LiteralPath (Join-Path $templateRoot 'CMakeLists.txt') -Destination (Join-Path $buildSource 'CMakeLists.txt')
    Copy-Item -LiteralPath (Join-Path $templateRoot 'RayTextureCopyWarp.cpp.txt') -Destination (Join-Path $buildSource 'RayTextureCopyWarp.cpp')
    Run-Check 'cmake-configure' $cmake @('-S',$buildSource,'-B',$build,'-G','Visual Studio 17 2022','-A','x64',('-DCMAKE_GENERATOR_INSTANCE='+$vs.installationPath)) | Out-Null
    $compilerMetadata=Get-ChildItem -LiteralPath (Join-Path $build 'CMakeFiles') -Recurse -File -Filter CMakeCXXCompiler.cmake | Select-Object -First 1
    if(-not $compilerMetadata){throw 'Configured C++ compiler metadata is absent.'}
    $compilerText=Get-Content -LiteralPath $compilerMetadata.FullName -Encoding utf8 -Raw
    foreach($field in @('CMAKE_CXX_COMPILER','CMAKE_CXX_COMPILER_ID','CMAKE_CXX_COMPILER_VERSION')){
        $match=[regex]::Match($compilerText,'set\('+[regex]::Escape($field)+' "([^"]+)"\)')
        if(-not $match.Success){throw ('Missing actual compiler metadata '+$field)}
        $report.tools[$field]=$match.Groups[1].Value
    }
    Run-Check 'cmake-build' $cmake @('--build',$build,'--config','Release','--target','RayTextureCopyWarp') | Out-Null
    $exe=Join-Path $build 'Release/RayTextureCopyWarp.exe'
    Run-Check 'warp-execute' $exe @($dxils[0],$dxils[1],$dxils[2],$dxils[3],(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot 'outputs.bin')) | Out-Null
    $report.warpExecuted=$true
    Run-Check 'oracle-verify' $node @((Join-Path $templateRoot 'RayTextureCopyOracle.mjs'),'verify',$artifactRoot) | Out-Null
    $report.oracle=Get-Content -LiteralPath (Join-Path $artifactRoot 'oracle-results.json') -Encoding utf8 -Raw | ConvertFrom-Json
    if($report.oracle.status -ne 'passed' -or $report.oracle.count -ne 103){throw 'Unexpected actual-copy oracle coverage.'}
    $report.artifacts=@();foreach($file in @($dxils+$listings+@($exe,(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot 'outputs.bin'),(Join-Path $artifactRoot 'oracle.json'),(Join-Path $artifactRoot 'oracle-results.json')))){
        $report.artifacts += [pscustomobject]@{path=$file;bytes=(Get-Item -LiteralPath $file).Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
    $report.status='passed';$exitCode=0
}catch{$report.status=if($script:environmentUnavailable){'unavailable'}else{'failed'};$report.error=$_.ToString();$report.errorLocation=$_.ScriptStackTrace;$exitCode=if($script:environmentUnavailable){2}else{1}}
finally {
    $after=@(Source-Hashes);$changed=@($sources|Where-Object {$before=$_;@($after|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
    if($changed.Count){$report.status='failed';$report.sourceChanges=$changed;$exitCode=1}
    $report.sources=$sources;$report.sourcesAfter=$after;$report.checks=@($checks.ToArray());$report.completedUtc=[DateTime]::UtcNow.ToString('o')
    $destination=if($ReportPath){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $artifactRoot 'ray-texture-copy-results.json'}
    [IO.File]::WriteAllText($destination,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($true))
    Write-Output ('RayTextureCopy '+$report.status+'; report: '+$destination)
    if($report.error){Write-Output $report.error}
    if($report.oracle){Write-Output ($report.oracle|ConvertTo-Json -Compress)}
}
exit $exitCode
