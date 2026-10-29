param(
    [string]$CompilerPath='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe',
    [string]$IncludeRoot=(Join-Path $env:TEMP 'HybridLumenGI-shader-validation'),
    [string]$OutputRoot=(Join-Path $PSScriptRoot 'compile')
)
$ErrorActionPreference='Stop'
$sourceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$shaderRoot=Join-Path $sourceRoot 'Runtime/Resources/HybridLumenGI'
$OutputRoot=[IO.Path]::GetFullPath($OutputRoot)
if(Test-Path -LiteralPath $OutputRoot){throw 'Choose a fresh output directory; preserve prior compile results.'}
if(!(Test-Path -LiteralPath $CompilerPath)){throw 'Installed DXC is unavailable.'}
if(!(Test-Path -LiteralPath (Join-Path $IncludeRoot 'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl'))){throw 'Pinned Unity include cache is unavailable.'}
$adapter=Join-Path $IncludeRoot 'Adapters/UnityRayQuery.cginc'
if((Get-FileHash -LiteralPath $adapter).Hash -ne (Get-FileHash -LiteralPath (Join-Path $sourceRoot 'Tests/ShaderAdapters/UnityRayQuery.cginc.txt')).Hash){throw 'RayQuery adapter differs from the repository source.'}
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
. (Join-Path $sourceRoot 'Tests/Invoke-OfflineCheck.ps1')
function Hash-Files([string]$Path,[bool]$Recurse=$false) {
    @(Get-ChildItem -LiteralPath $Path -File -Recurse:$Recurse | Where-Object {$_.Extension -in @('.hlsl','.compute','.shader','.cginc')} | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{path=$_.FullName;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
    })
}
$sources=@(Hash-Files $shaderRoot)
$includes=@(Hash-Files $IncludeRoot $true)
$checks=New-Object 'System.Collections.Generic.List[object]'
$version=Invoke-HLGIOfflineCheck -Name 'compiler-version' -Executable $CompilerPath -Arguments @('--version') -LogDirectory $OutputRoot
if($version.exitCode -ne 0){throw 'DXC version query failed.'}
$report=[ordered]@{
    status='running';startedUtc=[DateTime]::UtcNow.ToString('o');baseline='78618e1';
    scope='Optimized complete cache/gather entries for three backends and both shared temporal entries. Pinned Unity includes and repository RayQuery compile adapter; no Unity import, native DXR execution or whole-scene quality claim.';
    compiler=$CompilerPath;compilerSha256=(Get-FileHash -LiteralPath $CompilerPath).Hash;compilerVersion=$version.output.Trim();
    runnerSha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;sources=$sources;includes=$includes;checks=@()
}
$destination=Join-Path $OutputRoot 'report.json'
function Save-Report { $report.checks=$checks.ToArray();$report | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $destination -Encoding utf8 }
Save-Report
try {
    $entries=@()
    foreach($backend in @('software','exact-software','hardware')) {
        $file=if($backend -eq 'hardware'){'HybridLumenGIHardware.compute'}elseif($backend -eq 'exact-software'){'HybridLumenGIExactSoftware.compute'}else{'HybridLumenGI.compute'}
        $profile=if($backend -eq 'hardware'){'cs_6_5'}else{'cs_6_0'}
        foreach($entry in @('CSUpdateCache','CSTrace')) {$entries+=@{name=$backend+'-'+$entry;entry=$entry;file=$file;profile=$profile;identity=$false}}
    }
    foreach($entry in @('CSTemporal','CSTemporalIdentity')) {$entries+=@{name=$entry;entry=$entry;file='HybridLumenGI.compute';profile='cs_6_0';identity=$entry -eq 'CSTemporalIdentity'}}
    foreach($item in $entries) {
        $binary=Join-Path $OutputRoot ($item.name+'.dxil')
        $arguments=@('-O3','-T',$item.profile,'-E',$item.entry,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
            '-I',(Join-Path $IncludeRoot 'Adapters'),'-I',$IncludeRoot,'-I',$shaderRoot,'-Fo',$binary,(Join-Path $shaderRoot $item.file))
        if($item.identity){$arguments+=@('-D','HLGI_RECEIVER_IDENTITY=1')}
        $result=Invoke-HLGIOfflineCheck -Name $item.name -Executable $CompilerPath -Arguments $arguments -LogDirectory $OutputRoot
        $checks.Add([pscustomobject]@{name=$item.name;exitCode=$result.exitCode;startedUtc=$result.startedUtc;completedUtc=$result.completedUtc;arguments=$arguments;log=$result.log;diagnostics=$result.output;
            binarySha256=$(if(Test-Path -LiteralPath $binary){(Get-FileHash -LiteralPath $binary).Hash}else{$null})})
        Save-Report
        Write-Output ($item.name+' exit='+$result.exitCode)
        if($result.exitCode -ne 0){throw ($item.name+' failed.')}
    }
    $after=@(Hash-Files $shaderRoot)
    $includesAfter=@(Hash-Files $IncludeRoot $true)
    if((ConvertTo-Json -InputObject $sources -Compress) -ne (ConvertTo-Json -InputObject $after -Compress)){throw 'Shader sources changed during compilation.'}
    if((ConvertTo-Json -InputObject $includes -Compress) -ne (ConvertTo-Json -InputObject $includesAfter -Compress)){throw 'Compiler includes changed during compilation.'}
    $report.status='passed'
} catch {
    $report.status='failed';$report.error=$_.ToString();throw
} finally {
    $report.completedUtc=[DateTime]::UtcNow.ToString('o');Save-Report
}
