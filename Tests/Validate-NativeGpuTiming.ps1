param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BuildDirectory,
    [string]$UnityPluginApiDirectory,
    [switch]$DownloadUnityHeaders,
    [string]$ReportPath
)
$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path ([IO.Path]::GetTempPath()) ('hlgi-native-timing-' + [Guid]::NewGuid().ToString('N'))
}
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = Join-Path $BuildDirectory 'validation-report.json' }
$ReportPath = [IO.Path]::GetFullPath($ReportPath)
$utf8 = New-Object System.Text.UTF8Encoding($false)
# Make native reports self-identifying for Windows PowerShell 5.1 default readers.
$jsonUtf8 = New-Object System.Text.UTF8Encoding($true)

function Invoke-HLGITimingTest {
    param([string]$Name, [string]$Executable, [string]$Sha256, [string[]]$Arguments, [string]$EvidenceScope)
    if ((Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash -ne $Sha256) { throw "Test executable changed after compilation: $Executable" }
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = (($Arguments | ForEach-Object {
        $value = [regex]::Replace([string]$_, '(\\*)"', '$1$1\"')
        '"' + [regex]::Replace($value, '(\\+)$', '$1$1') + '"'
    }) -join ' ')
    $start.WorkingDirectory = $BuildDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    $stdout = ''; $stderr = ''; $exitCode = -1; $timedOut = $false; $processStarted = $false
    try {
        if (!$process.Start()) { throw "Could not start $Name." }
        $processStarted = $true
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit(120000)) {
            $timedOut = $true
            $process.Kill()
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
        if ($timedOut) { $exitCode = -1; $stderr += [Environment]::NewLine + "$Name timed out after 120 seconds." }
    } catch {
        $stderr += [Environment]::NewLine + ($_ | Out-String)
    } finally {
        $process.Dispose()
    }
    $output = $stdout + $stderr
    $log = Join-Path $BuildDirectory ($Name + '.log')
    [IO.File]::WriteAllText($log, $output, $utf8)
    if ($stdout.Trim()) { Write-Host $stdout.TrimEnd() }
    if ($stderr.Trim()) { Write-Host $stderr.TrimEnd() }
    $status = if ($exitCode -eq 0 -and ![string]::IsNullOrWhiteSpace($stdout)) { 'passed' } else { 'failed' }
    if ($Name -eq 'native-warp-smoke' -and $exitCode -eq 2) { $status = 'unavailable' }
    [pscustomobject]@{
        name=$Name; executable=$Executable; sha256=$Sha256; arguments=$Arguments; status=$status
        exitCode=$exitCode; timedOut=$timedOut; processStarted=$processStarted; evidenceScope=$EvidenceScope
        output=$output; stdout=$stdout; stderr=$stderr; log=$log
        startedUtc=$started.ToString('o'); completedUtc=[DateTime]::UtcNow.ToString('o')
    }
}

$report = [ordered]@{
    schemaVersion=1; kind='NativeGpuTimingValidation'; status='running'; startedUtc=[DateTime]::UtcNow.ToString('o'); completedUtc=$null
    sourceRoot=$SourceRoot; buildDirectory=$BuildDirectory; buildReportPath=(Join-Path $BuildDirectory 'report.json')
    configuration='Release'; architecture='x64'; warpExecuted=$false; physicalGpuExecuted=$false; unityExecuted=$false
    evidenceScope='Actual native DLL compilation, CPU query-pool tests, and D3D12 WARP software-adapter execution with a mock Unity host. Not actual Unity or physical-GPU integration/performance validation.'
    build=$null; cpuTest=$null; warpSmoke=$null; sourceHashes=@(); sourceChanges=@(); scriptHashes=@(); scriptChanges=@(); error=$null
}
try {
    $buildArguments = @{ SourceRoot=$SourceRoot; BuildDirectory=$BuildDirectory; PassThru=$true }
    if ($UnityPluginApiDirectory) { $buildArguments.UnityPluginApiDirectory = $UnityPluginApiDirectory }
    if ($DownloadUnityHeaders) { $buildArguments.DownloadUnityHeaders = $true }
    $built = & (Join-Path $PSScriptRoot 'Build-NativeGpuTiming.ps1') @buildArguments
    if (!$built -or $built.status -ne 'passed' -or !$built.artifacts.cpuTest.path -or !$built.artifacts.nativeSmoke.path) {
        throw 'Build did not return successful native test artifacts.'
    }
    $report.build = $built
    $report.sourceHashes = @($built.sourceHashes)
    $report.scriptHashes = @($built.scriptHashes)
    $report.cpuTest = Invoke-HLGITimingTest -Name 'query-pool-tests' -Executable $built.artifacts.cpuTest.path -Sha256 $built.artifacts.cpuTest.sha256 -Arguments @() -EvidenceScope 'Actual platform-independent C++17 query-pool state machine; no Unity or graphics execution.'
    if ($report.cpuTest.status -ne 'passed') {
        throw "Native CPU tests failed or produced no assertion summary (exit $($report.cpuTest.exitCode)); see $($report.cpuTest.log)"
    }

    if ((Get-FileHash -LiteralPath $built.artifacts.dll.path -Algorithm SHA256).Hash -ne $built.artifacts.dll.sha256) {
        throw 'Native DLL changed before WARP smoke execution.'
    }
    $report.warpSmoke = Invoke-HLGITimingTest -Name 'native-warp-smoke' -Executable $built.artifacts.nativeSmoke.path -Sha256 $built.artifacts.nativeSmoke.sha256 -Arguments @($built.artifacts.dll.path) -EvidenceScope 'Real D3D12 API execution on WARP software adapter with a mock Unity native-plugin host; no Unity engine or physical GPU.'
    $report.warpExecuted = $report.warpSmoke.status -eq 'passed'
    if ($report.warpSmoke.status -eq 'unavailable') {
        throw "D3D12 WARP smoke environment is unavailable (exit 2); this is not PASS. See $($report.warpSmoke.log)"
    }
    if ($report.warpSmoke.status -ne 'passed') {
        throw "D3D12 WARP smoke failed or produced no assertion summary (exit $($report.warpSmoke.exitCode)); see $($report.warpSmoke.log)"
    }

    $beforeNames = @{}
    foreach ($source in $built.sourceHashes) {
        $beforeNames[$source.file] = $true
        $path = Join-Path $SourceRoot $source.file
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $source.sha256) { $report.sourceChanges += $source.file }
    }
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'Runtime/Native~/GpuTiming') -Recurse -File | Where-Object {
        $_.Extension -in @('.cpp','.h','.hpp') -or $_.Name -eq 'CMakeLists.txt'
    })) {
        $relative = $file.FullName.Substring($SourceRoot.TrimEnd('\','/').Length+1).Replace('\','/')
        if (!$beforeNames.ContainsKey($relative)) { $report.sourceChanges += $relative }
    }
    foreach ($script in $built.scriptHashes) {
        if (!(Test-Path -LiteralPath $script.file -PathType Leaf) -or
            (Get-FileHash -LiteralPath $script.file -Algorithm SHA256).Hash -ne $script.sha256) { $report.scriptChanges += $script.file }
    }
    if ($report.sourceChanges.Count -ne 0 -or $report.scriptChanges.Count -ne 0) { throw 'Validated sources or scripts changed during test execution.' }
    foreach ($artifact in @($built.artifacts.cpuTest,$built.artifacts.nativeSmoke,$built.artifacts.dll)) {
        if ((Get-FileHash -LiteralPath $artifact.path -Algorithm SHA256).Hash -ne $artifact.sha256) {
            throw "Native artifact changed during test execution: $($artifact.path)"
        }
    }
    $report.status = 'passed'
    Write-Output 'PASS: native x64 Release build, CPU query-pool tests, and D3D12 WARP software smoke with mock Unity host. Actual Unity and physical-GPU validation were not performed.'
} catch {
    $report.status = 'failed'
    $report.error = ($_ | Out-String).Trim()
    if (!$report.build -and (Test-Path -LiteralPath $report.buildReportPath -PathType Leaf)) {
        $report.build = Get-Content -LiteralPath $report.buildReportPath -Raw -Encoding utf8 | ConvertFrom-Json
    }
    throw
} finally {
    $report.completedUtc = [DateTime]::UtcNow.ToString('o')
    $parent = Split-Path -Parent $ReportPath
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 24), $jsonUtf8)
    Write-Host "Native validation report: $ReportPath"
}
