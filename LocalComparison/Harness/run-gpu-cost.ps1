$ErrorActionPreference='Stop'
$taskRootPath='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskPackagePath=Join-Path $taskRootPath 'LocalComparison/Review/gpu-cost-baseline-01'
$taskModePath=Join-Path $taskPackagePath 'native-window'
$taskPython='C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskPlayer='I:/Unity test/Comparison/Builds/GpuCost22/HybridLumenGITest.exe'
if(Test-Path -LiteralPath (Join-Path $taskModePath 'attempt.json')){throw 'Unique cost run already attempted.'}
if(Get-Process -Name Unity,HybridLumenGITest -ErrorAction SilentlyContinue){throw 'Existing Unity/Player process must finish first.'}
if(!((Get-Content -LiteralPath (Join-Path $taskPackagePath 'build-analysis.json') -Raw | ConvertFrom-Json).nativePluginVerified)){throw 'Native build gate failed.'}
& $taskPython (Join-Path $taskRootPath 'LocalComparison/Harness/analyze-gpu-cost.py') verify
if($LASTEXITCODE -ne 0){throw 'Frozen product gate failed.'}
New-Item -ItemType Directory -Path $taskModePath -Force | Out-Null
$taskArgs=@('-force-d3d12','-screen-fullscreen','0','-screen-width','640','-screen-height','360','-gpuCost',
    '-gpuCostOutput',(Join-Path $taskModePath 'run'),'-logFile',(Join-Path $taskModePath 'player.log'))
@{attempt=1;executable=$taskPlayer;arguments=$taskArgs;startedUtc=[DateTime]::UtcNow.ToString('o');maximumFrames=800;watchdogSeconds=1200} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskModePath 'attempt.json') -Encoding utf8
$taskInfo=New-Object System.Diagnostics.ProcessStartInfo
$taskInfo.FileName=$taskPlayer;$taskInfo.WorkingDirectory=Split-Path -Parent $taskPlayer;$taskInfo.UseShellExecute=$false
$taskInfo.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Normal;$taskInfo.CreateNoWindow=$false
$taskInfo.Arguments=($taskArgs | ForEach-Object {'"'+$_+'"'}) -join ' '
$taskProcess=[System.Diagnostics.Process]::Start($taskInfo)
Write-Output "Fixed GPU cost Player PID $($taskProcess.Id)"
$taskTerminated=$false
if(!$taskProcess.WaitForExit(1200000)){$taskTerminated=$true;Stop-Process -Id $taskProcess.Id -Force;$taskProcess.WaitForExit()}
$taskNativeExit=$taskProcess.ExitCode
@{processId=$taskProcess.Id;exitCode=$taskNativeExit;watchdogTerminated=$taskTerminated;completedUtc=[DateTime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskModePath 'native-exit.json') -Encoding utf8
Write-Output "GPU cost Player exited $taskNativeExit; watchdog=$taskTerminated"
exit $taskNativeExit
