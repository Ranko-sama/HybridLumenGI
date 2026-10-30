$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$ownedRoot = [IO.Path]::GetFullPath("$project/Assets/HLGIMpbPersistenceCheck")
$builder = "$project/Assets/HybridLumenGI/Editor/HybridLumenGIAssetPageBuilder.cs"
$result = Join-Path $PSScriptRoot 'result02.json'
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
        scope='One static opaque URP Lit MPB export, prefab persistence, bundle reload and existing ColorContract shader input comparison. No Player, GI reference, performance, hashes or arbitrary shader/animation matrix.'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'attempt02.json') -Encoding utf8
    & 'I:/Unity test/Start-Unity.ps1' -Batch -LogName 'AssetPageMpbPersistence02' -ExecuteMethod 'MpbPersistenceCheck.Run' `
        -ExtraArguments @('-mpbPersistenceResult', $result)
    $nativeExit = $LASTEXITCODE
    [ordered]@{exitCode=$nativeExit;endedUtc=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'native-exit02.json') -Encoding utf8
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
