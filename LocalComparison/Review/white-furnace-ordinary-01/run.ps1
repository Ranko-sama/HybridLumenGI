$ErrorActionPreference = 'Stop'
$project = 'I:/Unity test/Project'
$assets = [IO.Path]::GetFullPath("$project/Assets")
$name = 'HLGIWhiteFurnace01'
$stage = [IO.Path]::GetFullPath((Join-Path $assets $name))
$output = 'I:/Unity test/Comparison/WhiteFurnaceOrdinary01'
$quality = "$project/ProjectSettings/QualitySettings.asset"
if ((Test-Path -LiteralPath $stage) -or (Test-Path -LiteralPath ($stage + '.meta')) -or (Test-Path -LiteralPath $output)) {
    throw 'Preserve existing inputs and results.'
}
if (Get-Process Unity,HybridLumenGIPlayer -ErrorAction SilentlyContinue) { throw 'The Unity project is in use.' }
$backup = Join-Path $env:TEMP ('hlgi-furnace-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($backup) | Out-Null
$originalQuality = [IO.File]::ReadAllBytes($quality)
[IO.File]::WriteAllBytes((Join-Path $backup 'QualitySettings.asset'), $originalQuality)
try {
    [IO.Directory]::CreateDirectory((Join-Path $stage 'Editor')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'WhiteFurnaceEditor.cs') -Destination (Join-Path $stage 'Editor')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'WhiteFurnaceRequest.cs') -Destination $stage
    & 'I:/Unity test/Start-Unity.ps1' -Batch -KeepRunning -LogName 'WhiteFurnaceOrdinary01' -ExecuteMethod 'WhiteFurnaceEditor.Run' -ExtraArguments @('-furnaceOutput',$output)
    $nativeExit = $LASTEXITCODE
}
finally {
    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw "Unity still owns the project. Preserve staged inputs and backup $backup." }
    [IO.File]::WriteAllBytes($quality, $originalQuality)
    $resolved = (Resolve-Path -LiteralPath $stage).Path
    $expected = [IO.Path]::GetFullPath('I:/Unity test/Project/Assets/HLGIWhiteFurnace01')
    if ($resolved -ne $expected) { throw 'Unexpected staging directory.' }
    Move-Item -LiteralPath $resolved -Destination (Join-Path $backup $name)
    if (Test-Path -LiteralPath ($stage+'.meta')) { Move-Item -LiteralPath ($stage+'.meta') -Destination (Join-Path $backup ($name+'.meta')) }
    Write-Output "Quality restored. The temporary scene and its inputs are preserved in $backup"
}
exit $nativeExit
