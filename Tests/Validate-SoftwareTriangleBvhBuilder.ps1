param([string]$SourceRoot=(Split-Path -Parent $PSScriptRoot),[Parameter(Mandatory=$true)][string]$ArtifactDirectory)
$ErrorActionPreference='Stop'
$paths=@('Runtime/HybridLumenGIAreaEmission.cs','Runtime/HybridLumenGISoftwareTriangleBvh.cs','Tests/StandaloneAreaEmission/UnityStubs.cs.txt','Tests/StandaloneSoftwareTriangleBvh/Program.cs.txt')
$sources=@{};foreach($path in $paths){$sources[[IO.Path]::GetFileName($path).Replace('.txt','')]=[IO.File]::ReadAllText((Join-Path $SourceRoot $path))}
$previous=$env:HLGI_SOFTWARE_BVH_OUTPUT
try{$env:HLGI_SOFTWARE_BVH_OUTPUT=$ArtifactDirectory;& (Join-Path $PSScriptRoot 'Invoke-CSharpHarness.ps1') -Name 'software-triangle-bvh' -Sources $sources}
finally{$env:HLGI_SOFTWARE_BVH_OUTPUT=$previous}
