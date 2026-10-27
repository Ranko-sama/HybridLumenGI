param([Parameter(Mandatory=$true)]$Report,[Parameter(Mandatory=$true)][hashtable]$SourceHashes)
$ErrorActionPreference='Stop'
function Check-Sources($Entries,[string[]]$Expected) {
    $found=@{}
    foreach($entry in $Entries) {
        if($found.ContainsKey($entry.file) -or $Expected -notcontains $entry.file -or
            !$SourceHashes.ContainsKey($entry.file) -or $entry.sha256 -ne $SourceHashes[$entry.file]) {
            throw ('Identity validation source mismatch: '+$entry.file)
        }
        $found[$entry.file]=$true
    }
    if($found.Count -ne $Expected.Count){throw 'Identity validation source coverage is incomplete.'}
}
$identity=$Report.receiverIdentityReport
if(!$identity -or $identity.schemaVersion -ne 1 -or $identity.kind -ne 'ReceiverIdentityShaderValidation' -or
    $identity.status -ne 'passed' -or !$identity.completedUtc -or $identity.scriptChanged -ne $false -or
    @($identity.sourceChanges).Count -ne 0 -or @($identity.includeChanges).Count -ne 0 -or
    $identity.expectedUnityGraphicsRevision -ne 'feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53' -or
    $identity.script -ne 'Tests/Validate-ReceiverIdentityShaders.ps1' -or
    $identity.scriptSha256 -ne $SourceHashes[$identity.script]) {throw 'Identity shader artifact is missing, stale or failed.'}
$sources=@('HybridLumenGIReceiverIdentity.shader','HybridLumenGIReceiverIdentity.compute','HybridLumenGIReceiverIdentity.hlsl','HybridLumenGIScreenSampling.hlsl') |
    ForEach-Object {'Runtime/Resources/HybridLumenGI/'+$_}
Check-Sources $identity.sources $sources;Check-Sources $identity.sourcesAfter $sources
$entries=@{}
foreach($cull in @('Off','Front','Back')) {
    $entries['identity-cull-'+$cull+'-vs']=@('HLGIIdentityVertex','vs_6_0')
    $entries['identity-cull-'+$cull+'-ps']=@('HLGIIdentityFragment','ps_6_0')
    $entries['identity-cull-'+$cull+'-ps-debug']=@('HLGIIdentityFragment','ps_6_0')
}
foreach($kernel in @('CSClearIdentity','CSMaskUnknownIdentity','CSResolveIdentity')){$entries[$kernel]=@($kernel,'cs_6_0')}
foreach($check in $identity.checks) {
    if(!$entries.ContainsKey($check.name) -or $check.entry -ne $entries[$check.name][0] -or
        $check.profile -ne $entries[$check.name][1] -or $check.exitCode -ne 0 -or $check.compilerExitCode -ne 0 -or
        $check.signatureVerified -ne $true -or $check.validationError -or !$check.log -or
        $check.listingSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or $check.dxilSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
        throw ('Invalid identity compiler evidence: '+$check.name)
    }
    $entries.Remove($check.name)
}
if($entries.Count){throw 'Identity compiler coverage is incomplete.'}
$includeNames=@{}
foreach($include in $identity.includes) {
    if(!$include.file -or $includeNames.ContainsKey($include.file) -or $include.sha256 -notmatch '^[0-9A-Fa-f]{64}$'){throw 'Invalid identity include evidence.'}
    $includeNames[$include.file]=$true
}
foreach($file in @('Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl','Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl')) {
    if(!$includeNames.ContainsKey($file)){throw ('Missing identity include: '+$file)}
}
$temporal=$Report.receiverTemporalReport
if(!$temporal -or $temporal.schemaVersion -ne 1 -or $temporal.kind -ne 'ReceiverTemporalActualWarpValidation' -or
    $temporal.status -ne 'passed' -or !$temporal.completedUtc -or $temporal.error -or $temporal.sourceChanges -or
    $temporal.warpExecuted -ne $true -or $temporal.unityExecuted -ne $false -or $temporal.physicalGpuExecuted -ne $false -or
    $temporal.oracle.status -ne 'passed' -or $temporal.oracle.count -ne 2179 -or $temporal.oracle.checks -ne 46841) {
    throw 'Actual receiver temporal WARP evidence is missing, failed or incomplete.'
}
$sources=@('Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverTemporal.hlsl','Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.hlsl',
    'Tests/StandaloneReceiverTemporal/ReceiverTemporalWarp.cpp.txt','Tests/StandaloneReceiverTemporal/ReceiverTemporalHarness.hlsl',
    'Tests/StandaloneReceiverTemporal/ReceiverTemporalOracle.mjs','Tests/StandaloneReceiverTemporal/CMakeLists.txt','Tests/Invoke-OfflineCheck.ps1','Tests/Validate-ReceiverTemporal.ps1')
Check-Sources $temporal.sources $sources;Check-Sources $temporal.sourcesAfter $sources
$entries=@{}
foreach($name in @('vswhere','cmake-version','dxc-version','oracle-prepare','dxc-actual-helper','cmake-configure','cmake-build','warp-execute','oracle-verify')){$entries[$name]=$true}
foreach($check in $temporal.checks) {
    if(!$entries.ContainsKey($check.name) -or $check.exitCode -ne 0 -or !$check.log -or
        ($check.name -ne 'dxc-actual-helper' -and [string]::IsNullOrWhiteSpace($check.output))) {
        throw ('Invalid actual temporal stage: '+$check.name)
    }
    $entries.Remove($check.name)
}
if($entries.Count){throw 'Actual temporal stages are incomplete.'}
$entries=@{}
foreach($name in @('receiver-temporal.dxil','receiver-temporal.ll','ReceiverTemporalWarp.exe','inputs.bin','outputs.bin','oracle.json','oracle-results.json')){$entries[$name]=$true}
foreach($artifact in $temporal.artifacts) {
    $name=Split-Path -Leaf $artifact.path
    if(!$entries.ContainsKey($name) -or $artifact.bytes -le 0 -or $artifact.sha256 -notmatch '^[0-9A-Fa-f]{64}$'){throw ('Invalid actual temporal artifact: '+$name)}
    $entries.Remove($name)
}
if($entries.Count){throw 'Actual temporal artifact coverage is incomplete.'}
Write-Output 'PASS: identity shader and actual temporal WARP report coverage/source bindings. Rasterization, RenderGraph and Unity remain unverified.'
