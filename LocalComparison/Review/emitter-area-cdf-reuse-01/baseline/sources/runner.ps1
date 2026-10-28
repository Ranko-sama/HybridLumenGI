param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),[switch]$ExpectReuse,[string]$SourceArchive)
$ErrorActionPreference='Stop'
$paths=@('Runtime/HybridLumenGIAreaEmission.cs','Tests/StandaloneAreaEmission/UnityStubs.cs.txt','Tests/StandaloneAreaEmission/Program.cs.txt')
$before=@($paths|ForEach-Object{[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $SourceRoot $_) -Algorithm SHA256).Hash}})
$sources=@{}
foreach($path in $paths){$name=[IO.Path]::GetFileName($path).Replace('.txt','');$sources[$name]=[IO.File]::ReadAllText((Join-Path $SourceRoot $path))}
if($ExpectReuse){$sources['Program.cs']="#define HLGI_AREA_CACHE_REUSE`n"+$sources['Program.cs']}
if($SourceArchive){
    if(Test-Path -LiteralPath $SourceArchive){throw 'Preserve the existing source archive.'}
    New-Item -ItemType Directory -Path $SourceArchive | Out-Null
    $utf8=New-Object System.Text.UTF8Encoding($false)
    foreach($name in $sources.Keys){[IO.File]::WriteAllText((Join-Path $SourceArchive $name),$sources[$name],$utf8)}
    Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $SourceArchive 'runner.ps1')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Destination (Join-Path $SourceArchive 'Invoke-CSharpHarness.ps1')
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'Documentation/Checkpoint-Iteration53.md') -Destination (Join-Path $SourceArchive 'contract.md')
}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'area-emission' -Sources $sources
foreach($source in $before){if((Get-FileHash -LiteralPath (Join-Path $SourceRoot $source.path) -Algorithm SHA256).Hash -ne $source.sha256){throw 'Area emission source changed during validation.'};Write-Output ($source.path+' SHA256 '+$source.sha256)}
