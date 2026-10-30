$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/HLGIMpbExportCheck")
$builder = "$project/Assets/HybridLumenGI/Editor/HybridLumenGIAssetPageBuilder.cs"
$result = Join-Path $PSScriptRoot 'result.json'
if ((Test-Path -LiteralPath $ownedRoot) -or (Test-Path -LiteralPath "$ownedRoot.meta") -or (Test-Path -LiteralPath $result)) {
    throw 'Preserve existing inputs or result.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'A rendering process is active.' }
$backup = Join-Path $env:TEMP ('hlgi-mpb-export-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
Copy-Item -LiteralPath $builder -Destination (Join-Path $backup 'HybridLumenGIAssetPageBuilder.cs')
$nativeExit = $null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../../Editor/HybridLumenGIAssetPageBuilder.cs') -Destination $builder
    [IO.Directory]::CreateDirectory("$ownedRoot/Editor") | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'AssetPageMpbExportCheck.cs') -Destination "$ownedRoot/Editor/AssetPageMpbExportCheck.cs"
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); backup=$backup;
        scope='One real Editor call for renderer and material-slot MPB export rejection; no bundles, Player, GPU, hashes or source reconstruction.'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'attempt.json') -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'AssetPageMpbExport01' -ExecuteMethod 'AssetPageMpbExportCheck.Run' `
        -ExtraArguments @('-mpbExportResult', $result)
    $nativeExit = $LASTEXITCODE
    [ordered]@{exitCode=$nativeExit;endedUtc=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'native-exit.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the staged helper; preserve $backup until exit." }
    if (Test-Path -LiteralPath $ownedRoot) {
        $resolved = (Resolve-Path -LiteralPath $ownedRoot).Path
        if (-not $resolved.Equals([IO.Path]::GetFullPath('I:/Unity test/Project/Assets/HLGIMpbExportCheck'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe helper cleanup.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    if (Test-Path -LiteralPath "$ownedRoot.meta") { Remove-Item -LiteralPath "$ownedRoot.meta" }
    Write-Output "Removed the temporary Editor helper; product exporter fix remains deployed. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
