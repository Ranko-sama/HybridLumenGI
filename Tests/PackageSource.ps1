param([string]$Destination = "", [string]$RuntimeReport = "")
$ErrorActionPreference = "Stop"
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if (-not $Destination) { $Destination = Join-Path $packageRoot ("Delivery/HybridLumenGI-" + (Get-Date -Format "yyyy-MM-dd") + "-integration-source.zip") }
$Destination = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) { throw "Archive already exists; choose a new destination: $Destination" }
# Historical offline candidates retain their original gate. A Unity-validated
# repair candidate instead carries an explicit current-source runtime receipt;
# unchanged offline results remain historical, not relabeled as newly executed.
$runtimeEvidence = $null
if ($RuntimeReport) {
    $RuntimeReport = [IO.Path]::GetFullPath($RuntimeReport)
    $runtimeEvidence = Get-Content -LiteralPath $RuntimeReport -Raw | ConvertFrom-Json
    if ($runtimeEvidence.status -ne 'friend-test-candidate' -or !$runtimeEvidence.playerBuildVerified -or !$runtimeEvidence.playerRunVerified) {
        throw 'Runtime report must identify a built and executed friend test candidate.'
    }
    $checked = @{}
    foreach ($entry in $runtimeEvidence.productSources) {
        if ($entry.file -notmatch '^(Runtime|Editor)/' -or $entry.file.Contains('..')) { throw 'Invalid product source path.' }
        $source = Join-Path $packageRoot $entry.file
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Runtime source changed: $($entry.file)" }
        $checked[$entry.file] = $true
    }
    foreach ($directory in @('Runtime','Editor')) {
        Get-ChildItem -LiteralPath (Join-Path $packageRoot $directory) -File -Recurse | Where-Object Extension -ne '.meta' | ForEach-Object {
            $relative = $_.FullName.Substring($packageRoot.Length + 1).Replace('\','/')
            if (!$checked.ContainsKey($relative)) { throw "Runtime source missing from report: $relative" }
        }
    }
} else {
    & (Join-Path $PSScriptRoot "Verify-OfflineReport.ps1") -SourceRoot $packageRoot
}
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Destination)) -Force | Out-Null
$files = [Collections.Generic.List[IO.FileInfo]]::new()
foreach ($directory in @("Runtime", "Editor", "Documentation", "Tests")) {
    Get-ChildItem -LiteralPath (Join-Path $packageRoot $directory) -File -Recurse | ForEach-Object { $files.Add($_) }
    $folderMeta = Join-Path $packageRoot ($directory + ".meta")
    if (Test-Path -LiteralPath $folderMeta) { $files.Add((Get-Item -LiteralPath $folderMeta)) }
}
foreach ($name in @("README.md", "README.md.meta")) {
    $path = Join-Path $packageRoot $name
    if (Test-Path -LiteralPath $path) { $files.Add((Get-Item -LiteralPath $path)) }
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
$archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
$manifest = [Collections.Generic.List[object]]::new()
try {
    foreach ($file in ($files | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($packageRoot.Length + 1).Replace("\", "/")
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName,
            "HybridLumenGI/" + $relative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        $manifest.Add([pscustomobject]@{ file=$relative; bytes=$file.Length; sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash })
    }
    $entry = $archive.CreateEntry("HybridLumenGI/SOURCE-MANIFEST.json")
    $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
    try {
        $writer.Write(([pscustomobject]@{
            status="Integration candidate; not UE5 Lumen equivalent or production certified"
            runtimeTarget=if($runtimeEvidence){$runtimeEvidence.runtimeTarget}else{"Unity 6 / URP 17, DX12, Linear; Unity runtime unverified"}
            generatedUtc=[DateTime]::UtcNow.ToString("o")
            unityExecutionVerified=($null -ne $runtimeEvidence)
            hardwareExecutionVerified=($null -ne $runtimeEvidence -and $runtimeEvidence.hardwareEditorVerified)
            runtimeEvidence=if($runtimeEvidence){"Tests/runtime-validation-results.json"}else{$null}
            runtimeEvidenceSha256=if($runtimeEvidence){(Get-FileHash -LiteralPath $RuntimeReport -Algorithm SHA256).Hash}else{$null}
            validationScope=if($runtimeEvidence){$runtimeEvidence.scope}else{"Historical full offline gate; no Unity execution"}
            offlineEvidence="Tests/offline-validation-results.json"
            offlineEvidenceSha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot "offline-validation-results.json") -Algorithm SHA256).Hash
            remainingReleaseGates="Documentation/ProductionPlan.md"
            files=@($manifest)
        } | ConvertTo-Json -Depth 6))
    } finally { $writer.Dispose() }
} finally { $archive.Dispose(); $stream.Dispose() }
Get-Item -LiteralPath $Destination | Select-Object FullName,Length
Get-FileHash -LiteralPath $Destination -Algorithm SHA256 | Select-Object Hash
