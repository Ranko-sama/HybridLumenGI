param([Parameter(Mandatory=$true)][string]$ArchivePath)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ArchivePath))
try {
    $entries = @{}
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName.Replace("\", "/")
        if (-not $name.StartsWith("HybridLumenGI/") -or $name -match '(^|/)\.\.(/|$)' -or $name.Contains(":")) {
            throw "Unexpected archive path: $name"
        }
        if ($entries.ContainsKey($name)) { throw "Duplicate archive path: $name" }
        $entries[$name] = $entry
    }
    $manifestPath = "HybridLumenGI/SOURCE-MANIFEST.json"
    if (-not $entries.ContainsKey($manifestPath)) { throw "Source manifest is missing." }
    $reader = [IO.StreamReader]::new($entries[$manifestPath].Open())
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    $seen = @{}
    foreach ($file in $manifest.files) {
        $name = "HybridLumenGI/" + $file.file
        if ($seen.ContainsKey($name)) { throw "Duplicate manifest path: $name" }
        $seen[$name] = $true
        if (-not $entries.ContainsKey($name)) { throw "Missing file: $name" }
        $entry = $entries[$name]
        if ($entry.Length -ne $file.bytes) { throw "Length mismatch: $name" }
        $inputStream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $actual = [BitConverter]::ToString($sha.ComputeHash($inputStream)).Replace("-", "") }
        finally { $sha.Dispose(); $inputStream.Dispose() }
        if ($actual -ne $file.sha256) { throw "SHA-256 mismatch: $name" }
    }
    if ($archive.Entries.Count -ne $seen.Count + 1) { throw "Unmanifested archive entries exist." }
    Write-Output "PASS: $($seen.Count) source files verified by length and SHA-256; no extra or duplicate entries."
    Write-Output "Declared status: $($manifest.status)"
    Write-Output "Integrity verification does not prove Unity compilation, rendering correctness or production readiness."
} finally { $archive.Dispose() }
