$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/HLGIMpbPersistenceCheck")
$builder = "$project/Assets/HybridLumenGI/Editor/HybridLumenGIAssetPageBuilder.cs"
$result = Join-Path $PSScriptRoot 'result04.json'
if ((Test-Path -LiteralPath $ownedRoot) -or (Test-Path -LiteralPath "$ownedRoot.meta") -or (Test-Path -LiteralPath $result)) {
    throw 'Preserve existing inputs or result.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'A rendering process is active.' }
$backup = Join-Path $env:TEMP ('hlgi-mpb-persistence-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
Copy-Item -LiteralPath $builder -Destination (Join-Path $backup 'HybridLumenGIAssetPageBuilder.cs')
$nativeExit = $null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../../Editor/HybridLumenGIAssetPageBuilder.cs') -Destination $builder
    [IO.Directory]::CreateDirectory("$ownedRoot/Editor") | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'MpbPersistenceCheck.cs') -Destination "$ownedRoot/Editor/MpbPersistenceCheck.cs"
    [ordered]@{ startedUtc=[DateTime]::UtcNow.ToString('o'); backup=$backup;
        scope='Only direct source values/bindings before and after the same export fixture; does not repeat the successful saved bundle/color observations from attempt03.'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'attempt04.json') -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'AssetPageMpbPersistence04' -ExecuteMethod 'MpbPersistenceCheck.Run' `
        -ExtraArguments @('-mpbPersistenceResult', $result, '-sourcePreservationOnly')
    $nativeExit = $LASTEXITCODE
    [ordered]@{exitCode=$nativeExit;endedUtc=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'native-exit04.json') -Encoding utf8
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the staged helper; preserve $backup until exit." }
    if (Test-Path -LiteralPath $ownedRoot) {
        $resolved = (Resolve-Path -LiteralPath $ownedRoot).Path
        if (-not $resolved.Equals([IO.Path]::GetFullPath('I:/Unity test/Project/Assets/HLGIMpbPersistenceCheck'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe helper cleanup.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    if (Test-Path -LiteralPath "$ownedRoot.meta") { Remove-Item -LiteralPath "$ownedRoot.meta" }
    Write-Output "Removed the temporary Editor helper; product exporter fix remains deployed. Backup: $backup"
}
if ($null -ne $nativeExit) { exit $nativeExit }
