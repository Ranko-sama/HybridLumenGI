param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,
    [Parameter(Mandatory=$true)][hashtable]$Sources,
    [ValidateRange(1,600)][int]$TimeoutSeconds = 60
)
$ErrorActionPreference = "Stop"
$dotnetCommand = Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1
$sdkLines = @(& $dotnetCommand.Source --list-sdks)
if ($LASTEXITCODE -ne 0) { throw "Cannot enumerate .NET SDKs." }
$sdkVersions = @($sdkLines | ForEach-Object {
    if ($_ -match '^(8\.\d+\.\d+)\s+\[') { [Version]$Matches[1] }
} | Sort-Object -Descending)
if ($sdkVersions.Count -eq 0) { throw "Install .NET SDK 8 to run the C# source harness. PowerShell Add-Type is intentionally not used." }

$runDirectory = Join-Path ([IO.Path]::GetTempPath()) ("hlgi-" + $Name + "-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($fileName in $Sources.Keys) {
    if ($fileName -notmatch '^[A-Za-z0-9_.-]+\.cs$') { throw "Harness sources must use simple .cs filenames: $fileName" }
    [IO.File]::WriteAllText((Join-Path $runDirectory $fileName), [string]$Sources[$fileName], $utf8)
}
$project = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
    <NuGetAudit>false</NuGetAudit>
  </PropertyGroup>
</Project>
'@
$projectPath = Join-Path $runDirectory "Harness.csproj"
[IO.File]::WriteAllText($projectPath, $project, $utf8)
$sdk = @{ sdk = @{ version = $sdkVersions[0].ToString(); rollForward = "disable" } } | ConvertTo-Json -Depth 3
[IO.File]::WriteAllText((Join-Path $runDirectory "global.json"), $sdk, $utf8)
# No package dependencies exist; use installed targeting packs without network.
[IO.File]::WriteAllText((Join-Path $runDirectory "NuGet.Config"), '<configuration><packageSources><clear /></packageSources></configuration>', $utf8)

# Capture the native process directly so Windows PowerShell 5.1 does not turn
# compiler stderr into a terminating NativeCommandError before its exit is read.
$start = New-Object System.Diagnostics.ProcessStartInfo
$start.FileName = $dotnetCommand.Source
$start.WorkingDirectory = $runDirectory
# Generated Windows paths cannot contain a quote and end in a filename, so this
# quoted project argument has no trailing-backslash/quote escaping ambiguity.
$start.Arguments = 'run --project "' + $projectPath + '" --configuration Release --verbosity quiet --no-launch-profile'
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$process = New-Object System.Diagnostics.Process
$process.StartInfo = $start
try {
    if (!$process.Start()) { throw "Could not start .NET harness $Name." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "C# harness '$Name' timed out; generated sources: $runDirectory"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    if ($stdout) { Write-Output $stdout.TrimEnd() }
    if ($stderr) { Write-Output $stderr.TrimEnd() }
    if ($exitCode -ne 0) { throw "C# harness '$Name' failed with exit code $exitCode; generated sources: $runDirectory" }
} finally {
    $process.Dispose()
}
