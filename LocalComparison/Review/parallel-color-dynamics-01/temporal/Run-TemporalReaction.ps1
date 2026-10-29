param(
    [string]$SourceRoot=(Join-Path $PSScriptRoot '../../../..'),
    [string]$CandidatePath='',
    [string]$CompilerPath=''
)
$ErrorActionPreference='Stop'
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
if(-not $CandidatePath){$CandidatePath=Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'}
$CandidatePath=[IO.Path]::GetFullPath($CandidatePath)
$frozen=Join-Path $PSScriptRoot 'frozen'
$artifactRoot=Join-Path $PSScriptRoot 'execution'
if(Test-Path -LiteralPath $artifactRoot){throw 'The unique execution directory already exists; preserve it and seek a decision before any rerun.'}
New-Item -ItemType Directory -Path $artifactRoot | Out-Null
. (Join-Path $frozen 'Invoke-OfflineCheck.ps1')
$checks=New-Object 'System.Collections.Generic.List[object]'
$tracked=@($CandidatePath,(Join-Path $PSScriptRoot 'proposal.txt'),(Join-Path $PSScriptRoot 'contract.txt'),
    (Join-Path $PSScriptRoot 'TemporalReactionAdapters.hlsl'),(Join-Path $PSScriptRoot 'TemporalReactionOracle.mjs'),
    (Join-Path $PSScriptRoot 'Run-TemporalReaction.ps1'),(Join-Path $PSScriptRoot 'frozen-manifest.json'),(Join-Path $PSScriptRoot 'host-reuse.json'))
$tracked+=@(Get-ChildItem -LiteralPath $frozen -File | ForEach-Object FullName)
function Source-Hashes {foreach($file in $tracked){[pscustomobject]@{file=$file;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}}}
$sources=@(Source-Hashes)
function Run-Check([string]$Name,[string]$Executable,[string[]]$Arguments) {
    $result=Invoke-HLGIOfflineCheck -Name $Name -Executable $Executable -Arguments $Arguments -LogDirectory $artifactRoot
    $result | Add-Member -NotePropertyName executable -NotePropertyValue $Executable
    $result | Add-Member -NotePropertyName arguments -NotePropertyValue $Arguments
    $checks.Add($result);Write-Output ($Name+' exit='+$result.exitCode)
    if($result.exitCode -ne 0){throw ($Name+' failed: '+$result.output)}
    return $result
}
$report=[ordered]@{schemaVersion=1;kind='ReactiveUnknownTemporalActualBody';status='running';startedUtc=[DateTime]::UtcNow.ToString('o');
    scope='Paired extracted actual temporal body, both preprocessor variants, fixed 1x1 resource/geometry/projection and explicit half-rounding adapters on software WARP. No Unity, real texture-format/UAV validation, physical GPU, scene incidence or dynamic quality claim.';
    unityExecuted=$false;physicalGpuExecuted=$false;candidatePath=$CandidatePath;artifactDirectory=$artifactRoot}
$exitCode=1
try {
    $manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'frozen-manifest.json') -Raw | ConvertFrom-Json
    foreach($record in $manifest){
        if((Get-FileHash -LiteralPath $record.frozen -Algorithm SHA256).Hash -ne $record.sha256){throw ('Frozen source modified: '+$record.frozen)}
    }
    $hostReceipt=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'host-reuse.json') -Raw | ConvertFrom-Json
    foreach($property in $hostReceipt.files.PSObject.Properties){
        $record=$property.Value
        if((Get-FileHash -LiteralPath $record.path -Algorithm SHA256).Hash -ne $record.sha256){throw ('Previously built host identity changed: '+$record.path)}
    }
    if($hostReceipt.files.cpp.sha256 -ne (Get-FileHash -LiteralPath (Join-Path $frozen 'ReceiverTemporalWarp.cpp.txt') -Algorithm SHA256).Hash -or
       $hostReceipt.files.cmake.sha256 -ne (Get-FileHash -LiteralPath (Join-Path $frozen 'CMakeLists.txt') -Algorithm SHA256).Hash){throw 'Existing host sources differ from frozen host'}
    $priorReport=Get-Content -LiteralPath $hostReceipt.files.priorReport.path -Raw | ConvertFrom-Json
    $priorExe=@($priorReport.artifacts | Where-Object {$_.path -eq $hostReceipt.files.exe.path -and $_.sha256 -eq $hostReceipt.files.exe.sha256})
    if($priorReport.status -ne 'passed' -or $priorExe.Count -ne 1){throw 'Existing executable is not identified by its prior passed report'}
    $exe=$hostReceipt.files.exe.path;$report.reusedHost=$hostReceipt
    $tracked+=@($hostReceipt.files.PSObject.Properties | ForEach-Object {$_.Value.path})
    $sources=@(Source-Hashes)
    if(-not $CompilerPath){
        $found=Get-Command dxc -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if($found){$CompilerPath=$found.Source}else{
            $found=Get-ChildItem -LiteralPath (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin') -Recurse -Filter dxc.exe -ErrorAction SilentlyContinue |
                Where-Object {$_.FullName -match '[\\/]x64[\\/]'} | Sort-Object FullName -Descending | Select-Object -First 1
            if($found){$CompilerPath=$found.FullName}
        }
    }
    if(-not $CompilerPath){throw 'An installed DXC is required; no installation is attempted.'}
    $node=(Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $report.tools=[ordered]@{dxc=$CompilerPath;node=$node;existingWarpHost=$exe;existingWarpHostSha256=$hostReceipt.files.exe.sha256}
    Run-Check 'oracle-prepare' $node @((Join-Path $PSScriptRoot 'TemporalReactionOracle.mjs'),'prepare',$artifactRoot,$CandidatePath) | Out-Null
    foreach($variant in @('baseline','candidate')){foreach($mode in @('legacy','identity')){
        $label=$variant+'-'+$mode
        $arguments=@('-HV','2018','-T','cs_6_0','-E','CSTemporalReactionTest','-I',$frozen,'-I',(Join-Path $artifactRoot $variant),
            '-Fo',(Join-Path $artifactRoot ($label+'.dxil')),'-Fc',(Join-Path $artifactRoot ($label+'.ll')))
        if($mode -eq 'identity'){$arguments+=@('-D','HLGI_RECEIVER_IDENTITY=1')}
        $arguments+=(Join-Path $PSScriptRoot 'TemporalReactionAdapters.hlsl')
        Run-Check ('dxc-'+$label) $CompilerPath $arguments | Out-Null
        $assembly=Get-Content -LiteralPath (Join-Path $artifactRoot ($label+'.ll')) -Raw
        if($assembly -notmatch '(?s)TemporalReactionInput.*?Size:\s+176' -or $assembly -notmatch '(?s)TemporalReactionOutput.*?Size:\s+64'){
            throw ($label+': actual DXIL ABI differs from unchanged host')
        }
    }}
    foreach($variant in @('baseline','candidate')){foreach($mode in @('legacy','identity')){
        $label=$variant+'-'+$mode
        Run-Check ('warp-'+$label) $exe @((Join-Path $artifactRoot ($label+'.dxil')),(Join-Path $artifactRoot 'inputs.bin'),(Join-Path $artifactRoot ($label+'.bin'))) | Out-Null
    }}
    $report.warpExecuted=$true
    Run-Check 'oracle-verify' $node @((Join-Path $PSScriptRoot 'TemporalReactionOracle.mjs'),'verify',$artifactRoot) | Out-Null
    $report.oracle=Get-Content -LiteralPath (Join-Path $artifactRoot 'oracle-results.json') -Raw | ConvertFrom-Json
    if($report.oracle.status -ne 'passed' -or $report.oracle.cases.Count -ne 12){throw 'Unexpected finite oracle coverage'}
    $report.status='passed';$exitCode=0
}catch{$report.status='failed';$report.error=$_.ToString();$report.errorLocation=$_.ScriptStackTrace}
finally {
    $after=@(Source-Hashes)
    $changed=@($sources|Where-Object {$before=$_;@($after|Where-Object {$_.file -eq $before.file -and $_.sha256 -eq $before.sha256}).Count -ne 1})
    if($changed.Count){$report.status='failed';$report.sourceChanges=$changed;$exitCode=1}
    $report.sources=$sources;$report.sourcesAfter=$after;$report.checks=@($checks.ToArray())
    $report.artifacts=@(Get-ChildItem -LiteralPath $artifactRoot -Recurse -File |
        ForEach-Object {[pscustomobject]@{path=$_.FullName;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $report.completedUtc=[DateTime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText((Join-Path $artifactRoot 'result.json'),($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
    Write-Output ('Temporal reaction '+$report.status+'; report: '+(Join-Path $artifactRoot 'result.json'))
    if($report.error){Write-Output $report.error}
}
exit $exitCode
