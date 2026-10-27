param(
    [Parameter(Mandatory=$true)][string]$SourceArchive,
    [Parameter(Mandatory=$true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$SourceArchive = (Resolve-Path -LiteralPath $SourceArchive).Path
$Destination = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) { throw "Archive already exists: $Destination" }
& (Join-Path $PSScriptRoot 'Verify-OfflineReport.ps1') -SourceRoot $root
& (Join-Path $PSScriptRoot 'VerifySourcePackage.ps1') -ArchivePath $SourceArchive
$reportPath = Join-Path $PSScriptRoot 'offline-validation-results.json'
$report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
$timing = $report.nativeGpuTimingReport
$dll = $timing.build.artifacts.dll
if (!(Test-Path -LiteralPath $dll.path -PathType Leaf) -or
    (Get-FileHash -LiteralPath $dll.path -Algorithm SHA256).Hash -ne $dll.sha256) {
    throw 'The tested native DLL is missing or changed; rebuild and revalidate before packaging.'
}
$sourceHash = (Get-FileHash -LiteralPath $SourceArchive -Algorithm SHA256).Hash
$reportHash = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash
$utf8 = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sourceZip = [IO.Compression.ZipFile]::OpenRead($SourceArchive)
$payload = [ordered]@{}
try {
    $entry = $sourceZip.GetEntry('HybridLumenGI/SOURCE-MANIFEST.json')
    $reader = [IO.StreamReader]::new($entry.Open(), $utf8)
    try { $sourceManifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($sourceManifest.offlineEvidenceSha256 -ne $reportHash -or
        $sourceManifest.unityExecutionVerified -ne $false -or $sourceManifest.hardwareExecutionVerified -ne $false) {
        throw 'Source archive must contain this exact offline report and retain unverified runtime status.'
    }
    $sourceFiles = @{}
    foreach ($file in $sourceManifest.files) { $sourceFiles[$file.file] = $file.sha256 }
    if ($sourceFiles['Tests/offline-validation-results.json'] -ne $reportHash) {
        throw 'Source archive embeds a different offline report than its evidence declaration.'
    }
    foreach ($source in $report.sources) {
        if ($sourceFiles[$source.file] -ne $source.sha256) { throw "Source archive mismatch: $($source.file)" }
    }
    foreach ($name in @('Documentation/NativeGpuTiming.md',
                        'Documentation/NativeGpuTimingThirdPartyNotices.md',
                        'Documentation/Licenses/Unity-Companion-License.txt')) {
        $entry = $sourceZip.GetEntry('HybridLumenGI/' + $name)
        if (!$entry) { throw "Required integration/license document missing from source archive: $name" }
        $inputStream = $entry.Open(); $memory = [IO.MemoryStream]::new()
        try { $inputStream.CopyTo($memory); $payload[$name] = $memory.ToArray() }
        finally { $inputStream.Dispose(); $memory.Dispose() }
    }
} finally { $sourceZip.Dispose() }
$payload['Plugins/x86_64/HybridLumenGIGpuTiming.dll'] = [IO.File]::ReadAllBytes($dll.path)
# Hash the captured bytes too; a post-check replacement must not enter the archive.
$sha = [Security.Cryptography.SHA256]::Create()
try { $capturedHash = [BitConverter]::ToString($sha.ComputeHash($payload['Plugins/x86_64/HybridLumenGIGpuTiming.dll'])).Replace('-', '') }
finally { $sha.Dispose() }
if ($capturedHash -ne $dll.sha256) { throw 'Native DLL changed while collecting package bytes.' }
$payload['Evidence/native-gpu-timing-validation.json'] = $utf8.GetBytes(($timing | ConvertTo-Json -Depth 32))
$payload['README.txt'] = $utf8.GetBytes(@'
HybridLumenGI optional native DX12 GPU timing integration candidate

Use this bundle only with the exact source archive identified in NATIVE-MANIFEST.json.
It measures three GI scopes for adaptive work budgets; it is not the DXR tracing backend.
When optional receiver identity is enabled, the first scope now extends from
material capture through all four identity passes. This is an elapsed queue
interval, not a separate measurement for each pass or the whole application.

Copy ONLY Plugins/x86_64/HybridLumenGIGpuTiming.dll to Assets/Plugins/x86_64
in your Unity test project. In Plugin Inspector disable Any Platform and enable
Windows Editor x86_64 and Windows x86_64 Player only. Restart the Editor when
replacing an already loaded plugin. Do not install duplicate DLLs or hot-unload it.

Adaptive GPU budgeting is disabled by default. First validate the source package.
Then enable adaptiveGpuBudget, set a measured device target, and keep
preferNativeGpuTiming enabled. Missing/unavailable native timing falls back to
Recorder or static budgets. See Documentation/NativeGpuTiming.md for diagnostics.

Evidence: native MSVC build, CPU state-machine tests and real D3D12 WARP software
execution with a mock Unity host. Actual Unity, RenderGraph, physical GPUs,
Release Player, visual quality and target performance have NOT been validated.
This is neither production certification nor proof of UE5 Lumen equivalence.

Keep Documentation/NativeGpuTimingThirdPartyNotices.md and
Documentation/Licenses/Unity-Companion-License.txt with redistribution.
'@)
$files = @($payload.Keys | ForEach-Object {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($payload[$_])).Replace('-', '') }
    finally { $sha.Dispose() }
    [pscustomobject]@{ file=$_; bytes=$payload[$_].Length; sha256=$hash }
})
$manifest = [ordered]@{
    schemaVersion=1; kind='HybridLumenGINativeTimingCandidate'; generatedUtc=[DateTime]::UtcNow.ToString('o')
    platform='Windows x86_64 Direct3D 12'; status='Integration candidate; runtime and production acceptance pending'
    sourceArchive=[IO.Path]::GetFileName($SourceArchive); sourceArchiveSha256=$sourceHash
    offlineEvidenceSha256=$reportHash; nativeDllSha256=$dll.sha256
    unityExecutionVerified=$false; physicalGpuExecutionVerified=$false; warpSoftwareExecutionVerified=$true
    nativeSources=@($timing.sourceHashes); files=$files
}
$payload['NATIVE-MANIFEST.json'] = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 10))
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Destination)) -Force | Out-Null
$outputStream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
$zip = [IO.Compression.ZipArchive]::new($outputStream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in $payload.Keys) {
        $entry = $zip.CreateEntry('HybridLumenGI-NativeTiming/' + $name, [IO.Compression.CompressionLevel]::Optimal)
        $stream = $entry.Open()
        try { $stream.Write($payload[$name], 0, $payload[$name].Length) } finally { $stream.Dispose() }
    }
} finally { $zip.Dispose(); $outputStream.Dispose() }
# Reopen the written archive and compare every byte with the collected payload.
$zip = [IO.Compression.ZipFile]::OpenRead($Destination)
try {
    if ($zip.Entries.Count -ne $payload.Count) { throw 'Native archive entry count mismatch.' }
    foreach ($name in $payload.Keys) {
        $entry = $zip.GetEntry('HybridLumenGI-NativeTiming/' + $name)
        if (!$entry -or $entry.Length -ne $payload[$name].Length) { throw "Native archive entry missing/truncated: $name" }
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $expected = [BitConverter]::ToString($sha.ComputeHash($payload[$name]))
            $actual = [BitConverter]::ToString($sha.ComputeHash($stream))
            if ($actual -ne $expected) { throw "Native archive bytes differ: $name" }
        } finally { $sha.Dispose(); $stream.Dispose() }
    }
} finally { $zip.Dispose() }
if ((Get-FileHash -LiteralPath $SourceArchive -Algorithm SHA256).Hash -ne $sourceHash) {
    throw 'Source archive changed during native packaging.'
}
$zipHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
[IO.File]::WriteAllText(($Destination + '.sha256'), ($zipHash + '  ' + [IO.Path]::GetFileName($Destination) + [Environment]::NewLine), $utf8)
Write-Output "PASS: optional native bundle verified; $($files.Count) payload entries, exact tested DLL and source-archive identity."
Write-Output "Archive: $Destination"
Write-Output "SHA256: $zipHash"
