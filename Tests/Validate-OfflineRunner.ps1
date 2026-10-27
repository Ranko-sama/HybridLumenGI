$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Invoke-OfflineCheck.ps1")
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("hlgi-runner-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$child = Join-Path $testRoot "child.ps1"
Set-Content -LiteralPath $child -Encoding utf8 -Value @'
param([int]$Code=0,[switch]$Stderr)
Write-Output "stdout-evidence"
if ($Stderr) { [Console]::Error.WriteLine("stderr-evidence") }
exit $Code
'@
$shellPath = (Get-Process -Id $PID).Path
$success = Invoke-HLGIOfflineCheck -Name success -Executable $shellPath -Arguments @("-NoProfile","-File",$child,"-Stderr") -LogDirectory $testRoot
$failure = Invoke-HLGIOfflineCheck -Name failure -Executable $shellPath -Arguments @("-NoProfile","-File",$child,"-Code","7","-Stderr") -LogDirectory $testRoot
$missing = Invoke-HLGIOfflineCheck -Name missing -Executable (Join-Path $testRoot "does-not-exist.exe") -LogDirectory $testRoot
$following = Invoke-HLGIOfflineCheck -Name following -Executable $shellPath -Arguments @("-NoProfile","-File",$child) -LogDirectory $testRoot
$shortName = Invoke-HLGIOfflineCheck -Name short-name -Executable "node" -Arguments @("--version") -LogDirectory $testRoot
if ($success.exitCode -ne 0 -or $failure.exitCode -ne 7 -or $missing.exitCode -ne -1 -or $following.exitCode -ne 0 -or $shortName.exitCode -ne 0) {
    throw "Native command failure handling or continuation regressed."
}
foreach ($result in @($success,$failure)) {
    if (!$result.output.Contains("stdout-evidence") -or !$result.output.Contains("stderr-evidence")) { throw "stdout/stderr evidence was lost." }
}
foreach ($result in @($success,$failure,$missing,$following,$shortName)) {
    if (!(Test-Path -LiteralPath $result.log) -or [string]::IsNullOrWhiteSpace($result.output)) { throw "A command result lost its diagnostic log." }
}
if ($ErrorActionPreference -ne "Stop") { throw "Caller error preference leaked." }
Write-Output "Offline runner: success with stderr, failure exit 7, missing executable, continuation and short-name PATH lookup all preserved with logs."
