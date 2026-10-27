param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$BuildDirectory,
    [string]$UnityPluginApiDirectory,
    [switch]$DownloadUnityHeaders,
    [switch]$PassThru
)
$ErrorActionPreference = 'Stop'

# No compiler installation, persistent environment changes, or copy into Runtime.
# Unity API headers stay outside the package. Their own notices specify the Unity
# Companion License; the sample repository's root MIT LICENSE does not replace it.
$unityCommit = '522254181faf188efa8b50c3e3bf6fce720b26e4'
$unityFiles = @(
    [pscustomobject]@{ name='IUnityInterface.h'; path='PluginSource/source/Unity/IUnityInterface.h'; sha256='e23e267b57c049b438307542d62c30fbcd3fa77b6dac3b08842eae0df10b8239' },
    [pscustomobject]@{ name='IUnityGraphics.h'; path='PluginSource/source/Unity/IUnityGraphics.h'; sha256='e95a8ac359897b5746494db84ae594d6f59f3709c2ec20bd869d592ed4bbf4f7' },
    [pscustomobject]@{ name='IUnityGraphicsD3D12.h'; path='PluginSource/source/Unity/IUnityGraphicsD3D12.h'; sha256='7e6322a1f280e4d7dea9aa567e5085875f05ac373c1dc134d4dadc7985c21617' },
    [pscustomobject]@{ name='LICENSE.NativeRenderingPlugin.MIT'; path='LICENSE'; sha256='8ff2aeedfc43211d085e27fc057a2c4c58d665808e2369a97cc43099dc390afb' }
)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$jsonUtf8 = New-Object System.Text.UTF8Encoding($true)

function Write-HLGIJson([string]$Path, $Value, [bool]$WithBom = $false) {
    # Reports are also read by Windows PowerShell 5.1, whose default encoding is
    # the system ANSI codepage without a BOM. Node download manifests stay BOM-free.
    $encoding = if ($WithBom) { $jsonUtf8 } else { $utf8 }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), $encoding)
}

function ConvertTo-HLGIProcessArgument([string]$Value) {
    # Windows CRT quoting, including quotes and a directory's trailing backslashes.
    if ($null -eq $Value) { $Value = '' }
    $quoted = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
    return '"' + $quoted + '"'
}

function Invoke-HLGIBuildProcess {
    param([string]$Name, [string]$Executable, [string[]]$Arguments, [int]$TimeoutSeconds = 300)
    $started = [DateTime]::UtcNow
    $log = Join-Path $BuildDirectory ($Name + '.log')
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = (($Arguments | ForEach-Object { ConvertTo-HLGIProcessArgument $_ }) -join ' ')
    $start.WorkingDirectory = $BuildDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    $exitCode = -1; $stdout = ''; $stderr = ''; $timedOut = $false
    try {
        if (!$process.Start()) { throw "Could not start $Name." }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            $process.Kill()
            $process.WaitForExit()
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
        if ($timedOut) { $exitCode = -1; $stderr += "`nProcess timed out after $TimeoutSeconds seconds." }
    } catch {
        $stderr += "`n" + ($_ | Out-String)
    } finally {
        $process.Dispose()
    }
    $output = $stdout + $stderr
    [IO.File]::WriteAllText($log, $output, $utf8)
    if ($stdout.Trim()) { Write-Host $stdout.TrimEnd() }
    if ($stderr.Trim()) { Write-Host $stderr.TrimEnd() }
    [pscustomobject]@{
        name=$Name; executable=$Executable; arguments=$Arguments; exitCode=$exitCode; timedOut=$timedOut
        stdout=$stdout; stderr=$stderr; log=$log; startedUtc=$started.ToString('o'); completedUtc=[DateTime]::UtcNow.ToString('o')
    }
}

function Get-HLGISourceHashes {
    $files = @(Get-ChildItem -LiteralPath $nativeRoot -Recurse -File | Where-Object {
        $_.Extension -in @('.cpp','.h','.hpp') -or $_.Name -eq 'CMakeLists.txt'
    })
    @($files | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{
            file=$_.FullName.Substring($SourceRoot.TrimEnd('\','/').Length+1).Replace('\','/')
            sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
}

function Get-HLGIScriptHashes {
    @('Build-NativeGpuTiming.ps1','Validate-NativeGpuTiming.ps1') | ForEach-Object {
        $path = Join-Path $PSScriptRoot $_
        [pscustomobject]@{ file=$path; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    }
}

function Get-HLGIHeaderHashes([string]$Directory, [bool]$IncludeLicense) {
    @($unityFiles | Where-Object { $IncludeLicense -or $_.name.EndsWith('.h') } | ForEach-Object {
        $path = Join-Path $Directory $_.name
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing Unity native API file: $path" }
        [pscustomobject]@{ file=$_.name; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    })
}

function Get-HLGIChanges($Before, $After) {
    $previous = @{}; $current = @{}
    foreach ($item in $Before) { $previous[$item.file] = $item.sha256 }
    foreach ($item in $After) { $current[$item.file] = $item.sha256 }
    @(@($previous.Keys) + @($current.Keys) | Sort-Object -Unique | Where-Object {
        !$previous.ContainsKey($_) -or !$current.ContainsKey($_) -or $previous[$_] -ne $current[$_]
    })
}

function Read-HLGICMakeValue([string]$Text, [string]$Name) {
    $match = [regex]::Match($Text, '(?m)^set\(' + [regex]::Escape($Name) + ' "([^"\r\n]*)"\)')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$nativeRoot = Join-Path $SourceRoot 'Runtime/Native~/GpuTiming'
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path ([IO.Path]::GetTempPath()) ('hlgi-native-timing-' + [Guid]::NewGuid().ToString('N'))
}
$BuildDirectory = [IO.Path]::GetFullPath($BuildDirectory)
$runtimeRoot = [IO.Path]::GetFullPath((Join-Path $SourceRoot 'Runtime')).TrimEnd('\','/')
if ($BuildDirectory.Equals($runtimeRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $BuildDirectory.StartsWith($runtimeRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'BuildDirectory must be outside Runtime; compiled artifacts must not enter the source package automatically.'
}
New-Item -ItemType Directory -Path $BuildDirectory -Force | Out-Null
$BuildDirectory = (Resolve-Path -LiteralPath $BuildDirectory).Path
$reportPath = Join-Path $BuildDirectory 'report.json'
$report = [ordered]@{
    schemaVersion=1; kind='NativeGpuTimingBuild'; status='running'; startedUtc=[DateTime]::UtcNow.ToString('o'); completedUtc=$null
    sourceRoot=$SourceRoot; nativeSourceDirectory=$nativeRoot; buildDirectory=$BuildDirectory; buildReportPath=$reportPath
    configuration='Release'; architecture='x64'; generator='Visual Studio 17 2022'; gpuExecuted=$false
    evidenceScope='Native DLL, CPU test and WARP smoke compilation only; no Unity loading, GPU timing, or device execution.'
    tools=$null; unityHeaders=$null; sourceHashes=@(); sourceHashesAfter=@(); sourceChanges=@(); headerChanges=@()
    scriptHashes=@(); scriptChanges=@()
    stages=@(); artifacts=$null; error=$null
}
try {
    foreach ($file in @('CMakeLists.txt','QueryPool.h','NativeAbi.h','GpuTimingPlugin.cpp','tests/QueryPoolTests.cpp','tests/NativeTimingSmoke.cpp')) {
        if (!(Test-Path -LiteralPath (Join-Path $nativeRoot $file) -PathType Leaf)) { throw "Missing native source: $nativeRoot/$file" }
    }
    if ($UnityPluginApiDirectory -and $DownloadUnityHeaders) { throw 'Use UnityPluginApiDirectory or DownloadUnityHeaders, not both.' }
    $report.sourceHashes = @(Get-HLGISourceHashes)
    $report.scriptHashes = @(Get-HLGIScriptHashes)
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere -PathType Leaf)) { throw 'VS2022 Build Tools discovery requires an existing vswhere.exe; this script does not install tools.' }
    $discovery = Invoke-HLGIBuildProcess -Name 'vswhere' -Executable $vswhere -Arguments @('-latest','-products','*','-version','[17.0,18.0)','-requires','Microsoft.VisualStudio.Component.VC.Tools.x86.x64','-format','json','-utf8')
    $report.stages += $discovery
    if ($discovery.exitCode -ne 0) { throw "VS2022 discovery failed; see $($discovery.log)" }
    $installations = @($discovery.stdout | ConvertFrom-Json)
    if ($installations.Count -ne 1 -or !$installations[0].installationPath) { throw 'No installed VS2022 C++ x64 build tools found. No installation was attempted.' }
    $vs = $installations[0]
    $cmake = Join-Path $vs.installationPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    if (!(Test-Path -LiteralPath $cmake -PathType Leaf)) {
        $foundCMake = Get-Command cmake -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (!$foundCMake) { throw 'CMake is not installed in VS2022 or available on PATH. No installation was attempted.' }
        $cmake = $foundCMake.Source
    }
    $version = Invoke-HLGIBuildProcess -Name 'cmake-version' -Executable $cmake -Arguments @('--version')
    $report.stages += $version
    if ($version.exitCode -ne 0) { throw "Cannot execute CMake; see $($version.log)" }
    $report.tools = [ordered]@{
        visualStudio=$vs.installationPath; visualStudioVersion=$vs.installationVersion
        cmake=$cmake; cmakeVersion=($version.stdout -split '\r?\n')[0]
        compiler=$null; compilerId=$null; compilerVersion=$null; compilerFileVersion=$null; windowsSdk=$null
    }

    if ($UnityPluginApiDirectory) {
        $UnityPluginApiDirectory = (Resolve-Path -LiteralPath $UnityPluginApiDirectory).Path
        $headerHashes = @(Get-HLGIHeaderHashes $UnityPluginApiDirectory $false)
        $pinned = $true
        foreach ($header in $headerHashes) {
            $expected = $unityFiles | Where-Object { $_.name -eq $header.file }
            if ($header.sha256 -ne $expected.sha256) { $pinned = $false }
        }
        $report.unityHeaders = [ordered]@{
            mode='ExplicitLocalDirectory'; directory=$UnityPluginApiDirectory; matchesPinnedHeaders=$pinned
            commit=$(if ($pinned) { $unityCommit } else { $null }); files=$headerHashes
            headerLicense='Read preserved per-file notices; pinned official headers specify Unity Companion License.'
        }
    } else {
        $UnityPluginApiDirectory = Join-Path ([IO.Path]::GetTempPath()) ('hlgi-unity-plugin-api-' + $unityCommit)
        $cacheValid = $true
        foreach ($file in $unityFiles) {
            $cached = Join-Path $UnityPluginApiDirectory $file.name
            if (!(Test-Path -LiteralPath $cached -PathType Leaf) -or
                (Get-FileHash -LiteralPath $cached -Algorithm SHA256).Hash -ne $file.sha256) { $cacheValid = $false; break }
        }
        if (!$cacheValid -and !$DownloadUnityHeaders) {
            throw "Pinned Unity header cache is missing or has a hash mismatch: $UnityPluginApiDirectory. Run once with -DownloadUnityHeaders, or supply -UnityPluginApiDirectory. No network download was attempted."
        }
        if (!$cacheValid) {
            $node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (!$node) { throw 'Downloading pinned Unity headers requires an existing Node.js runtime; no installation was attempted.' }
            $staging = Join-Path $BuildDirectory ('unity-headers-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $staging | Out-Null
            $manifestPath = Join-Path $BuildDirectory 'unity-download-manifest.json'
            Write-HLGIJson $manifestPath ([ordered]@{ commit=$unityCommit; files=$unityFiles })
            $downloadScript = Join-Path $BuildDirectory 'download-unity-headers.cjs'
            $javascript = @'
const fs = require('fs'), path = require('path'), https = require('https'), crypto = require('crypto');
const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const directory = process.argv[3];
function read(url) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, { headers: { 'User-Agent': 'HybridLumenGI-pinned-native-build' } }, response => {
      if (response.statusCode !== 200) { response.resume(); reject(new Error('HTTP ' + response.statusCode + ' for ' + url)); return; }
      const chunks = []; let size = 0;
      response.on('data', chunk => { size += chunk.length; if (size > 1024 * 1024) request.destroy(new Error('Unexpected oversized header')); else chunks.push(chunk); });
      response.on('error', reject);
      response.on('end', () => resolve(Buffer.concat(chunks)));
    });
    request.setTimeout(20000, () => request.destroy(new Error('HTTPS download timeout')));
    request.on('error', reject);
  });
}
(async () => {
  for (const file of manifest.files) {
    const url = 'https://raw.githubusercontent.com/Unity-Technologies/NativeRenderingPlugin/' + manifest.commit + '/' + file.path;
    const bytes = await read(url);
    const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
    if (sha256 !== file.sha256) throw new Error('Pinned SHA256 mismatch for ' + file.name + ': ' + sha256);
    fs.writeFileSync(path.join(directory, file.name), bytes);
    console.log(JSON.stringify({ file: file.name, bytes: bytes.length, sha256, url }));
  }
})().catch(error => { console.error(error.stack || error.message); process.exitCode = 1; });
'@
            [IO.File]::WriteAllText($downloadScript, $javascript, $utf8)
            $download = Invoke-HLGIBuildProcess -Name 'unity-header-download' -Executable $node.Source -Arguments @($downloadScript,$manifestPath,$staging) -TimeoutSeconds 120
            $report.stages += $download
            if ($download.exitCode -ne 0) { throw "Pinned Unity header download failed; preserved details: $($download.log)" }
            New-Item -ItemType Directory -Path $UnityPluginApiDirectory -Force | Out-Null
            foreach ($file in $unityFiles) {
                $source = Join-Path $staging $file.name
                if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $file.sha256) { throw "Downloaded header changed before cache publication: $($file.name)" }
                $temporary = Join-Path $UnityPluginApiDirectory ($file.name + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
                [IO.File]::WriteAllBytes($temporary, [IO.File]::ReadAllBytes($source))
                Move-Item -LiteralPath $temporary -Destination (Join-Path $UnityPluginApiDirectory $file.name) -Force
            }
            Write-HLGIJson (Join-Path $UnityPluginApiDirectory 'SOURCE.json') ([ordered]@{
                repository='https://github.com/Unity-Technologies/NativeRenderingPlugin'; commit=$unityCommit; files=$unityFiles
                headerLicense='Unity Companion License (preserved in every header)'; headerLicenseUrl='https://unity.com/legal/licenses/unity-companion-license'
                repositoryLicense='MIT root LICENSE is retained separately; it does not replace header-specific notices.'
            })
        }
        $headerHashes = @(Get-HLGIHeaderHashes $UnityPluginApiDirectory $true)
        foreach ($header in $headerHashes) {
            $expected = $unityFiles | Where-Object { $_.name -eq $header.file }
            if ($header.sha256 -ne $expected.sha256) { throw "Pinned cache hash mismatch before configuration: $($header.file)" }
        }
        $report.unityHeaders = [ordered]@{
            mode='PinnedExternalCache'; directory=$UnityPluginApiDirectory; matchesPinnedHeaders=$true
            commit=$unityCommit; files=$headerHashes
            headerLicense='Unity Companion License; repository MIT LICENSE retained separately.'
        }
    }

    $configure = Invoke-HLGIBuildProcess -Name 'cmake-configure' -Executable $cmake -Arguments @(
        '-S',$nativeRoot,'-B',$BuildDirectory,'-G','Visual Studio 17 2022','-A','x64',
        ('-DCMAKE_GENERATOR_INSTANCE:PATH=' + $vs.installationPath), ('-DUNITY_PLUGIN_API_DIR:PATH=' + $UnityPluginApiDirectory))
    $report.stages += $configure
    if ($configure.exitCode -ne 0) { throw "CMake configure failed; see $($configure.log)" }
    $compilerFile = Get-ChildItem -LiteralPath (Join-Path $BuildDirectory 'CMakeFiles') -Filter 'CMakeCXXCompiler.cmake' -Recurse -File | Select-Object -First 1
    if (!$compilerFile) { throw 'Configured CMake compiler metadata is missing.' }
    $compilerText = Get-Content -LiteralPath $compilerFile.FullName -Raw
    $report.tools.compiler = Read-HLGICMakeValue $compilerText 'CMAKE_CXX_COMPILER'
    $report.tools.compilerId = Read-HLGICMakeValue $compilerText 'CMAKE_CXX_COMPILER_ID'
    $report.tools.compilerVersion = Read-HLGICMakeValue $compilerText 'CMAKE_CXX_COMPILER_VERSION'
    # CMAKE_SYSTEM_VERSION can describe the target OS instead of the selected SDK.
    # Read the actual generated plugin project's WindowsTargetPlatformVersion.
    $projectFile = Join-Path $BuildDirectory 'HybridLumenGIGpuTiming.vcxproj'
    if (!(Test-Path -LiteralPath $projectFile -PathType Leaf)) { throw 'Generated native plugin project is missing.' }
    $sdkMatch = [regex]::Match((Get-Content -LiteralPath $projectFile -Raw), '<WindowsTargetPlatformVersion>([^<]+)</WindowsTargetPlatformVersion>')
    if (!$sdkMatch.Success) { throw 'Generated project does not identify its Windows SDK.' }
    $report.tools.windowsSdk = $sdkMatch.Groups[1].Value
    if (!$report.tools.compiler -or !(Test-Path -LiteralPath $report.tools.compiler -PathType Leaf)) { throw 'Configured C++ compiler path is missing.' }
    $report.tools.compilerFileVersion = (Get-Item -LiteralPath $report.tools.compiler).VersionInfo.FileVersion
    if ($report.tools.compilerId -ne 'MSVC') { throw "Expected MSVC for the selected VS2022 build; found $($report.tools.compilerId)." }

    $build = Invoke-HLGIBuildProcess -Name 'cmake-build' -Executable $cmake -Arguments @(
        '--build',$BuildDirectory,'--config','Release','--target','HybridLumenGIGpuTiming','HLGIQueryPoolTests','HLGINativeTimingSmoke','--parallel','2')
    $report.stages += $build
    if ($build.exitCode -ne 0) { throw "Native Release build failed; see $($build.log)" }
    $dll = Join-Path $BuildDirectory 'Release/HybridLumenGIGpuTiming.dll'
    $test = Join-Path $BuildDirectory 'Release/HLGIQueryPoolTests.exe'
    $smoke = Join-Path $BuildDirectory 'Release/HLGINativeTimingSmoke.exe'
    foreach ($artifact in @($dll,$test,$smoke)) {
        if (!(Test-Path -LiteralPath $artifact -PathType Leaf) -or (Get-Item -LiteralPath $artifact).Length -eq 0) { throw "Expected nonempty Release artifact is missing: $artifact" }
    }
    $report.artifacts = [ordered]@{
        dll=[ordered]@{ path=$dll; sha256=(Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash }
        cpuTest=[ordered]@{ path=$test; sha256=(Get-FileHash -LiteralPath $test -Algorithm SHA256).Hash }
        nativeSmoke=[ordered]@{ path=$smoke; sha256=(Get-FileHash -LiteralPath $smoke -Algorithm SHA256).Hash }
    }
    $report.sourceHashesAfter = @(Get-HLGISourceHashes)
    $report.sourceChanges = @(Get-HLGIChanges $report.sourceHashes $report.sourceHashesAfter)
    $report.scriptChanges = @(Get-HLGIChanges $report.scriptHashes @(Get-HLGIScriptHashes))
    $headersAfter = @(Get-HLGIHeaderHashes $UnityPluginApiDirectory ($report.unityHeaders.mode -eq 'PinnedExternalCache'))
    $report.headerChanges = @(Get-HLGIChanges $report.unityHeaders.files $headersAfter)
    if ($report.sourceChanges.Count -ne 0 -or $report.headerChanges.Count -ne 0 -or $report.scriptChanges.Count -ne 0) { throw 'Native sources, build scripts, or Unity headers changed during compilation; results are not a stable-source build.' }
    $report.status = 'passed'
    Write-Host ("Native build passed: {0} {1}, SDK {2}, x64 Release." -f $report.tools.compilerId,$report.tools.compilerVersion,$report.tools.windowsSdk)
    foreach ($source in $report.sourceHashes) { Write-Host ("SHA256 {0} {1}" -f $source.sha256,$source.file) }
    foreach ($script in $report.scriptHashes) { Write-Host ("SCRIPT SHA256 {0} {1}" -f $script.sha256,$script.file) }
    Write-Host "Artifacts remain in $BuildDirectory. No DLL was installed into Unity."
} catch {
    $report.status = 'failed'
    $report.error = ($_ | Out-String).Trim()
    throw
} finally {
    $report.completedUtc = [DateTime]::UtcNow.ToString('o')
    Write-HLGIJson $reportPath $report $true
    Write-Host "Native build report: $reportPath"
}
if ($PassThru) { [pscustomobject]$report }
