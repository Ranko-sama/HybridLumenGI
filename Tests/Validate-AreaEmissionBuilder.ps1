param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$paths=@('Runtime/HybridLumenGIAreaEmission.cs','Tests/StandaloneAreaEmission/UnityStubs.cs.txt','Tests/StandaloneAreaEmission/Program.cs.txt')
$before=@($paths|ForEach-Object{[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $SourceRoot $_) -Algorithm SHA256).Hash}})
$sources=@{}
foreach($path in $paths){$name=[IO.Path]::GetFileName($path).Replace('.txt','');$sources[$name]=[IO.File]::ReadAllText((Join-Path $SourceRoot $path))}
& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'area-emission' -Sources $sources
foreach($source in $before){if((Get-FileHash -LiteralPath (Join-Path $SourceRoot $source.path) -Algorithm SHA256).Hash -ne $source.sha256){throw 'Area emission source changed during validation.'};Write-Output ($source.path+' SHA256 '+$source.sha256)}
