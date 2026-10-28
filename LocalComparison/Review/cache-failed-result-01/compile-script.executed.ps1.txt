param([string]$CompilerPath='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe',
      [string]$IncludeRoot=(Join-Path $env:TEMP 'HybridLumenGI-shader-validation'))
$ErrorActionPreference='Stop'
$sourceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$shaderRoot=Join-Path $sourceRoot 'Runtime/Resources/HybridLumenGI'
$outputRoot=Join-Path $sourceRoot 'LocalComparison/Review/cache-failed-result-01/shader-compile'
if(Test-Path -LiteralPath $outputRoot){throw 'Do not overwrite or silently repeat a completed compile set.'}
if(!(Test-Path -LiteralPath $CompilerPath)){throw 'Pinned installed DXC unavailable; no installation attempted.'}
if(!(Test-Path -LiteralPath (Join-Path $IncludeRoot 'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl'))){throw 'Existing pinned Unity include cache unavailable; no download attempted.'}
New-Item -ItemType Directory -Path $outputRoot | Out-Null
$adapterRoot=Join-Path $outputRoot 'Adapters'
New-Item -ItemType Directory -Path $adapterRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'Tests/ShaderAdapters/UnityRayQuery.cginc.txt') -Destination (Join-Path $adapterRoot 'UnityRayQuery.cginc')
. (Join-Path $sourceRoot 'Tests/Invoke-OfflineCheck.ps1')
$entries=New-Object 'System.Collections.Generic.List[object]'
$sources=@(Get-ChildItem -LiteralPath $shaderRoot -File | Where-Object {$_.Extension -in @('.hlsl','.compute')} | ForEach-Object {
    [pscustomobject]@{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$includes=@(Get-ChildItem -LiteralPath (Join-Path $IncludeRoot 'Packages') -Recurse -File | ForEach-Object {
    [pscustomobject]@{path=$_.FullName.Substring($IncludeRoot.Length+1);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$report=[ordered]@{passed=$false;scope='Six affected complete transport entries (cache update and gather across legacy software, exact software and native RayQuery compile adapter). DXC compile only, not Unity variant import or physical DXR execution.';
    compiler=$CompilerPath;compilerVersion=(& $CompilerPath --version | Out-String).Trim();sources=$sources;includeSource='Existing pinned Unity Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53 cache';includes=$includes;entries=@()}
try {
    foreach($backend in @('software','exact-software','hardware')) {
        $filename=if($backend -eq 'hardware'){'HybridLumenGIHardware.compute'}elseif($backend -eq 'exact-software'){'HybridLumenGIExactSoftware.compute'}else{'HybridLumenGI.compute'}
        $profile=if($backend -eq 'hardware'){'cs_6_5'}else{'cs_6_0'}
        foreach($entry in @('CSUpdateCache','CSTrace')) {
            $name=$backend+'-'+$entry
            $arguments=@('-T',$profile,'-E',$entry,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
                '-I',$adapterRoot,'-I',$IncludeRoot,'-I',$shaderRoot,'-Fo',(Join-Path $outputRoot ($name+'.dxil')),(Join-Path $shaderRoot $filename))
            $result=Invoke-HLGIOfflineCheck -Name $name -Executable $CompilerPath -Arguments $arguments -LogDirectory $outputRoot
            $entries.Add([pscustomobject]@{name=$name;profile=$profile;exitCode=$result.exitCode;arguments=$arguments;diagnostics=$result.output})
            $report.entries=$entries.ToArray();$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'report.json') -Encoding UTF8
            Write-Output ($name+' exit='+$result.exitCode)
            if($result.exitCode -ne 0){throw ('Affected shader compile failed: '+$name)}
        }
    }
    $report.passed=$entries.Count -eq 6
} finally {
    $report.entries=$entries.ToArray();$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputRoot 'report.json') -Encoding UTF8
}
if(!$report.passed){exit 1}
