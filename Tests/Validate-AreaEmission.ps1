param(
    [string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$CompilerPath='',
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
$artifactRoot=Join-Path $env:TEMP ('hlgi-area-emission-warp-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
$templateRoot=Join-Path $SourceRoot 'Tests/StandaloneAreaEmission'
$shaderRoot=Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI'
. (Join-Path $PSScriptRoot 'Invoke-OfflineCheck.ps1')
$checks=New-Object 'System.Collections.Generic.List[object]'
$sourceNames=@('Runtime/HybridLumenGIAreaEmission.cs','Runtime/Resources/HybridLumenGI/HybridLumenGIAreaEmission.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIHit.hlsl',
'Tests/StandaloneAreaEmission/AreaEmissionWarp.cpp.txt','Tests/StandaloneAreaEmission/AreaEmissionHarness.hlsl','Tests/StandaloneAreaEmission/AreaEmissionOracle.mjs',
'Tests/StandaloneAreaEmission/CMakeLists.txt','Tests/StandaloneAreaEmission/Program.cs.txt','Tests/StandaloneAreaEmission/UnityStubs.cs.txt',
'Tests/Invoke-OfflineCheck.ps1','Tests/Invoke-CSharpHarness.ps1','Tests/Validate-AreaEmissionBuilder.ps1','Tests/Validate-AreaEmission.ps1')
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
$report=[ordered]@{schemaVersion=1;kind='AreaEmissionActualWarpValidation';status='running';startedUtc=[DateTime]::UtcNow.ToString('o');artifactDirectory=$artifactRoot;
    scope='Actual area emitter C# builder and HLSL DXIL on D3D12 WARP with independent double area/PDF/MIS quadrature. No Unity, real RTAS/visibility, product integration or physical GPU.';
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
    Run-Check 'cpu-builder' ((Get-Process -Id $PID).Path) @('-NoProfile','-File',(Join-Path $SourceRoot 'Tests/Validate-AreaEmissionBuilder.ps1'),'-SourceRoot',$SourceRoot) | Out-Null
    Run-Check 'oracle-prepare' $node @((Join-Path $templateRoot 'AreaEmissionOracle.mjs'),'prepare',$artifactRoot) | Out-Null
    $dxil=Join-Path $artifactRoot 'area-emission.dxil';$listing=Join-Path $artifactRoot 'area-emission.ll'
    Run-Check 'dxc-actual-helper' $CompilerPath @('-HV','2018','-T','cs_6_0','-E','CSAreaEmissionTest','-I',$shaderRoot,'-Fo',$dxil,'-Fc',$listing,(Join-Path $templateRoot 'AreaEmissionHarness.hlsl')) | Out-Null
    $assembly=Get-Content -LiteralPath $listing -Encoding utf8 -Raw
    if($assembly -notmatch '(?s)AreaEmissionInput.*?Size:\s+192' -or $assembly -notmatch '(?s)AreaEmissionOutput.*?Size:\s+64' -or
        $assembly -notmatch '(?s)HLGIAreaEmitter.*?Size:\s+96') {throw 'Actual DXIL input/output/emitter ABI differs from the binary harness.'}
    $buildSource=Join-Path $artifactRoot 'source';$build=Join-Path $artifactRoot 'build';New-Item -ItemType Directory -Path $buildSource | Out-Null
    Copy-Item -LiteralPath (Join-Path $templateRoot 'CMakeLists.txt') -Destination (Join-Path $buildSource 'CMakeLists.txt')
    Copy-Item -LiteralPath (Join-Path $templateRoot 'AreaEmissionWarp.cpp.txt') -Destination (Join-Path $buildSource 'AreaEmissionWarp.cpp')
    Run-Check 'cmake-configure' $cmake @('-S',$buildSource,'-B',$build,'-G','Visual Studio 17 2022','-A','x64',('-DCMAKE_GENERATOR_INSTANCE='+$vs.installationPath)) | Out-Null
    $compilerMetadata=Get-ChildItem -LiteralPath (Join-Path $build 'CMakeFiles') -Recurse -File -Filter CMakeCXXCompiler.cmake | Select-Object -First 1
    if(-not $compilerMetadata){throw 'Configured C++ compiler metadata is absent.'}
    $compilerText=Get-Content -LiteralPath $compilerMetadata.FullName -Encoding utf8 -Raw
    foreach($field in @('CMAKE_CXX_COMPILER','CMAKE_CXX_COMPILER_ID','CMAKE_CXX_COMPILER_VERSION')){
        $match=[regex]::Match($compilerText,'set\('+[regex]::Escape($field)+' "([^"]+)"\)')
        if(-not $match.Success){throw ('Missing actual compiler metadata '+$field)}
        $report.tools[$field]=$match.Groups[1].Value
    }
    Run-Check 'cmake-build' $cmake @('--build',$build,'--config','Release','--target','AreaEmissionWarp') | Out-Null
    $exe=Join-Path $build 'Release/AreaEmissionWarp.exe'
    Run-Check 'warp-execute' $exe @($dxil,(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot 'emitters.bin'),(Join-Path $artifactRoot 'outputs.bin')) | Out-Null
    $report.warpExecuted=$true
    Run-Check 'oracle-verify' $node @((Join-Path $templateRoot 'AreaEmissionOracle.mjs'),'verify',$artifactRoot) | Out-Null
    $report.oracle=Get-Content -LiteralPath (Join-Path $artifactRoot 'oracle-results.json') -Encoding utf8 -Raw | ConvertFrom-Json
    if($report.oracle.status -ne 'passed' -or $report.oracle.count -lt 1000){throw 'Unexpected actual-helper oracle coverage.'}
    $report.artifacts=@();foreach($file in @($dxil,$listing,$exe,(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot 'emitters.bin'),(Join-Path $artifactRoot 'outputs.bin'),(Join-Path $artifactRoot 'oracle.json'),(Join-Path $artifactRoot 'oracle-results.json'))){
        $report.artifacts += [pscustomobject]@{path=$file;bytes=(Get-Item -LiteralPath $file).Length;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
    $report.status='passed';$exitCode=0
}catch{$report.status=if($script:environmentUnavailable){'unavailable'}else{'failed'};$report.error=$_.ToString();$report.errorLocation=$_.ScriptStackTrace;$exitCode=if($script:environmentUnavailable){2}else{1}}
finally {
    $after=@(Source-Hashes);$changed=@($sources|Where-Object {$before=$_;@($after|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
    if($changed.Count){$report.status='failed';$report.sourceChanges=$changed;$exitCode=1}
    $report.sources=$sources;$report.sourcesAfter=$after;$report.checks=@($checks.ToArray());$report.completedUtc=[DateTime]::UtcNow.ToString('o')
    $destination=if($ReportPath){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $artifactRoot 'area-emission-results.json'}
    [IO.File]::WriteAllText($destination,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($true))
    Write-Output ('AreaEmission '+$report.status+'; report: '+$destination)
    if($report.error){Write-Output $report.error}
    if($report.oracle){Write-Output ($report.oracle|ConvertTo-Json -Compress)}
}
exit $exitCode
