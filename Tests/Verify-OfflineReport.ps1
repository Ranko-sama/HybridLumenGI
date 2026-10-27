param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "offline-validation-results.json"),
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference = "Stop"
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$report = Get-Content -LiteralPath $ReportPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($report.schemaVersion -ne 1 -or $report.status -ne "passed" -or !$report.completedUtc -or
    @($report.sourceChanges).Count -ne 0 -or @($report.artifactErrors).Count -ne 0) {
    throw "Offline report is incomplete, failed, or contains changed sources/artifact errors."
}
$expected=@("OfflineRunner","CSharpSyntax","SdfNumerics","SdfAtlasAllocator","SdfAtlasRepresentation","SceneBvh","SceneResidency",
    "CacheScheduler","ChangeRegions","HlodTransactions","ChunkStreaming","SurfaceCharts","SurfaceCache","SurfaceReadiness","SurfaceSource","LitQualification","HardwareBackend","HlodReadback","EmissiveResources","GpuBudget","GpuTiming","GpuFrameTiming","NativeTimingBridge","NativeGpuTiming","HistoryLifecycle","ProxyUpdates",
    "transport-reference","transport-audit-reference","Validate-GuidedSampling","Validate-GlobalSdfBounds","native-diffuse-reference","near-far-reference","Validate-SurfaceAnchors","Validate-EmissiveSampling","Validate-EmissiveProposals","Validate-SurfaceGeometryNormals","transport-normal-reference","Validate-ScreenGeometryPacking","Validate-SurfaceHitIdentity",
    "CoreShaders","NativeDiffuseShaders","GlobalSdf","Lighting","Validate-DirectLighting","Validate-ReceiverPolicyCapture","ReceiverPolicyShaders","Validate-ScreenSampling","MeshSource","MaterialSource","ReceiverHistory",
    "ReceiverIdentityFrame","ReceiverIdentityPass","Validate-ReceiverIdentity","ReceiverIdentityShaders","ReceiverTemporal","ScreenBudget","CaptureComparator",
    "RayTexturePool","HitMaterialLayout","HitMaterialBatch","HitMaterialPass","DeformedMesh","AreaEmission","SoftwareTriangleBvh",
    "HardwareNormals","HardwareSurface","HardwareMaterials","HitMaterials","RayTextures","RayTextureCopy","RayFootprint","RadianceValidity","RayQueryPropagation")
$checks=@{}
foreach ($check in $report.checks) {
    if ($checks.ContainsKey($check.name) -or $expected -notcontains $check.name -or $check.exitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace($check.output)) { throw "Invalid or duplicate offline stage: $($check.name)" }
    $checks[$check.name]=$check
}
if ($checks.Count -ne $expected.Count) { throw "Offline stage coverage is incomplete." }
$current=@{}
foreach ($directory in @("Runtime","Editor","Tests")) {
    Get-ChildItem -LiteralPath (Join-Path $SourceRoot $directory) -File -Recurse | Where-Object {
        $_.Extension -in @(".cs",".hlsl",".shader",".compute",".ps1",".mjs",".cpp",".h",".hpp",".cmake") -or $_.Name -eq "CMakeLists.txt" -or $_.Name.EndsWith(".cs.txt") -or $_.Name.EndsWith(".cpp.txt") -or $_.Name.EndsWith(".cginc.txt")
    } | ForEach-Object {
        $relative=$_.FullName.Substring($SourceRoot.Length+1).Replace("\","/")
        $current[$relative]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
}
$seen=@{}
foreach ($source in $report.sources) {
    if ($seen.ContainsKey($source.file) -or !$current.ContainsKey($source.file) -or $current[$source.file] -ne $source.sha256) {
        throw "Missing, duplicated or changed validated source: $($source.file)"
    }
    $seen[$source.file]=$true
}
if ($seen.Count -ne $current.Count) { throw "New source files are absent from the offline report." }
if (@($report.shaderReports).Count -ne 2 -or !$report.globalSdfReport) { throw "Compiler artifacts are missing." }
$core=$report.shaderReports[0];$native=$report.shaderReports[1];$globalSdf=$report.globalSdfReport
foreach ($pair in @(@($core,51),@($native,42),@($globalSdf,3))) {
    $names=@{}
    foreach ($check in $pair[0].checks) {
        $key=if ($check.name) { $check.name } else { $check.entry }
        if (!$key -or $names.ContainsKey($key) -or $check.exitCode -ne 0) { throw "Invalid compiler entry: $key" }
        $names[$key]=$true
    }
    if ($names.Count -ne $pair[1]) { throw "Unexpected compiler coverage: $($names.Count), expected $($pair[1])." }
}
foreach ($artifact in @($core,$globalSdf)) {
    foreach ($source in $artifact.sources) {
        $relative="Runtime/Resources/HybridLumenGI/"+$source.file
        if (!$current.ContainsKey($relative) -or $current[$relative] -ne $source.sha256) { throw "Compiler artifact source mismatch: $relative" }
    }
}
if ($native.sha256 -ne $current["Runtime/Resources/HybridLumenGI/HybridLumenGINativeDiffuseCapture.shader"]) { throw "Native diffuse compiler source mismatch." }
if ($core.rayQueryAdapterSha256 -ne $current["Tests/ShaderAdapters/UnityRayQuery.cginc.txt"]) { throw "RayQuery test adapter source mismatch." }
$receiver=$report.receiverPolicyReport
if (!$receiver -or $receiver.schemaVersion -ne 1 -or $receiver.status -ne "passed" -or !$receiver.completedUtc -or
    @($receiver.sourceChanges).Count -ne 0 -or @($receiver.includeChanges).Count -ne 0 -or $receiver.scriptChanged -or
    $receiver.script -ne "Tests/Validate-ReceiverPolicyShaders.ps1" -or $receiver.scriptSha256 -ne $current[$receiver.script]) {
    throw "Receiver policy compiler evidence is incomplete, failed or changed."
}
$receiverExpected=@("surface-perdraw-vs","surface-instanced-vs",
    "native-instanced-sh-VERTEX","native-instanced-sh-FRAGMENT",
    "native-instanced-forward-plus-ssao-VERTEX","native-instanced-forward-plus-ssao-FRAGMENT")
foreach($mode in @("perdraw","instanced")) { foreach($i in 0..7) { $receiverExpected+="surface-$mode-ps-$i" } }
$receiverSeen=@{}
foreach($entry in $receiver.checks) {
    $expectedFragment=$entry.name -match '(-ps-[0-7]|-FRAGMENT)$'
    $expectedProfile=if($expectedFragment){'ps_6_0'}else{'vs_6_0'}
    if($receiverExpected -notcontains $entry.name -or $receiverSeen.ContainsKey($entry.name) -or
        $entry.exitCode -ne 0 -or $entry.compilerExitCode -ne 0 -or $entry.signatureVerified -ne $true -or
        [string]::IsNullOrWhiteSpace($entry.signatureLine) -or $entry.validationError -or $entry.profile -ne $expectedProfile) {
        throw "Invalid receiver policy compiler entry: $($entry.name)"
    }
    if($entry.profile -eq "ps_6_0") {
        if($entry.integerMrtSignature -ne $true) { throw "Receiver policy integer MRT signature is missing: $($entry.name)" }
        if($entry.name -match 'instanced' -and $entry.instancedRenderingLayerArray -ne $true) {
            throw "Receiver policy instanced rendering-layer array is missing: $($entry.name)"
        }
    } elseif($entry.profile -ne "vs_6_0") { throw "Unexpected receiver policy shader profile." }
    $signaturePattern=if($expectedFragment) {
        $target=if($entry.name.StartsWith('native-')){3}else{2}
        '^;?\s*SV_Target\s+'+$target+'\s+xy\s+\d+\s+TARGET\s+uint(?:\s|$)'
    } else { '^;?\s*SV_Position\s+0\s+xyzw\s+\d+\s+POS\s+float(?:\s|$)' }
    if($entry.signatureLine -notmatch $signaturePattern) { throw "Receiver policy signature text is inconsistent: $($entry.name)" }
    if($entry.listingSha256 -notmatch '^[0-9a-fA-F]{64}$' -or $entry.dxilSha256 -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Receiver policy compiler artifact identity is missing: $($entry.name)"
    }
    $receiverSeen[$entry.name]=$true
}
if($receiverSeen.Count -ne 22) { throw "Receiver policy compiler coverage is incomplete." }
$receiverSources=@("Runtime/Resources/HybridLumenGI/HybridLumenGISurface.shader",
    "Runtime/Resources/HybridLumenGI/HybridLumenGINativeDiffuseCapture.shader",
    "Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverPolicyCapture.hlsl")
foreach($sourceSet in @(@($receiver.sources),@($receiver.sourcesAfter))) {
    $sourceSeen=@{}
    foreach($source in $sourceSet) {
        if($receiverSources -notcontains $source.file -or $sourceSeen.ContainsKey($source.file) -or $current[$source.file] -ne $source.sha256) {
            throw "Receiver policy compiler source mismatch: $($source.file)"
        }
        $sourceSeen[$source.file]=$true
    }
    if($sourceSeen.Count -ne 3) { throw "Receiver policy compiler source coverage is incomplete." }
}
$coreIncludes=@{};foreach($include in $core.includes) { $coreIncludes[$include.file.Replace('\','/')]=$include.sha256 }
$receiverIncludes=@{}
foreach($include in $receiver.includes) {
    $name=$include.file.Replace('\','/')
    if($receiverIncludes.ContainsKey($name) -or !$coreIncludes.ContainsKey($name) -or $coreIncludes[$name] -ne $include.sha256) {
        throw "Receiver policy compiler include mismatch: $name"
    }
    $receiverIncludes[$name]=$true
}
if($receiverIncludes.Count -ne $coreIncludes.Count) { throw "Receiver policy compiler include coverage is incomplete." }
foreach($requiredInclude in @(
    'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl',
    'Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl',
    'Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl',
    'Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl',
    'Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl',
    'Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl')) {
    if(!$receiverIncludes.ContainsKey($requiredInclude)) { throw "Required receiver policy compiler include is missing: $requiredInclude" }
}
$nativeTiming=$report.nativeGpuTimingReport
if (!$nativeTiming -or $nativeTiming.schemaVersion -ne 1 -or $nativeTiming.status -ne "passed" -or
    !$nativeTiming.completedUtc -or !$nativeTiming.warpExecuted -or $nativeTiming.unityExecuted -or $nativeTiming.physicalGpuExecuted -or
    @($nativeTiming.sourceChanges).Count -ne 0 -or @($nativeTiming.scriptChanges).Count -ne 0 -or $nativeTiming.error) {
    throw "Native timing evidence is missing, failed, changed, or claims unexecuted Unity/physical-GPU validation."
}
$build=$nativeTiming.build
if (!$build -or $build.status -ne "passed" -or $build.configuration -ne "Release" -or $build.architecture -ne "x64" -or
    $build.tools.compilerId -ne "MSVC" -or @($build.sourceChanges).Count -ne 0 -or @($build.scriptChanges).Count -ne 0 -or
    @($build.headerChanges).Count -ne 0 -or $build.unityHeaders.commit -ne "522254181faf188efa8b50c3e3bf6fce720b26e4" -or !$build.unityHeaders.matchesPinnedHeaders) {
    throw "Native compiler/header evidence is incomplete or outside the pinned integration candidate."
}
foreach ($name in @("cmake-configure","cmake-build")) {
    $stage=@($build.stages | Where-Object name -eq $name)
    if ($stage.Count -ne 1 -or $stage[0].exitCode -ne 0 -or $stage[0].timedOut) { throw "Native compile stage failed/missing: $name" }
}
$headerPins=@{
    "IUnityInterface.h"="E23E267B57C049B438307542D62C30FBCD3FA77B6DAC3B08842EAE0DF10B8239"
    "IUnityGraphics.h"="E95A8AC359897B5746494DB84AE594D6F59F3709C2EC20BD869D592ED4BBF4F7"
    "IUnityGraphicsD3D12.h"="7E6322A1F280E4D7DEA9AA567E5085875F05AC373C1DC134D4DADC7985C21617"
    "LICENSE.NativeRenderingPlugin.MIT"="8FF2AEEDFC43211D085E27FC057A2C4C58D665808E2369A97CC43099DC390AFB"
}
$headerSeen=@{}
foreach ($header in $build.unityHeaders.files) {
    if (!$headerPins.ContainsKey($header.file) -or $headerSeen.ContainsKey($header.file) -or
        $header.sha256 -ne $headerPins[$header.file]) { throw "Native PluginAPI header evidence mismatch: $($header.file)" }
    $headerSeen[$header.file]=$true
}
if ($headerSeen.Count -ne $headerPins.Count) { throw "Native PluginAPI header evidence is incomplete." }
foreach ($artifact in @($build.artifacts.dll,$build.artifacts.cpuTest,$build.artifacts.nativeSmoke)) {
    if (!$artifact.path -or $artifact.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Native binary artifact identity is missing." }
}
foreach ($test in @($nativeTiming.cpuTest,$nativeTiming.warpSmoke)) {
    if (!$test -or $test.status -ne "passed" -or $test.exitCode -ne 0 -or $test.timedOut -or !$test.processStarted -or
        [string]::IsNullOrWhiteSpace($test.output)) { throw "Native executable evidence is missing or failed." }
}
if ($nativeTiming.cpuTest.sha256 -ne $build.artifacts.cpuTest.sha256 -or
    $nativeTiming.warpSmoke.sha256 -ne $build.artifacts.nativeSmoke.sha256 -or
    @($nativeTiming.warpSmoke.arguments).Count -ne 1 -or $nativeTiming.warpSmoke.arguments[0] -ne $build.artifacts.dll.path) {
    throw "Native tested executable or DLL does not match the compiled artifacts."
}
foreach ($sources in @(@($nativeTiming.sourceHashes),@($build.sourceHashes),@($build.sourceHashesAfter))) {
    $nativeSeen=@{}
    foreach ($source in $sources) {
        if ($source.file -notlike "Runtime/Native~/GpuTiming/*" -or $nativeSeen.ContainsKey($source.file) -or
            !$current.ContainsKey($source.file) -or $current[$source.file] -ne $source.sha256) { throw "Native source evidence mismatch: $($source.file)" }
        $nativeSeen[$source.file]=$true
    }
    if ($nativeSeen.Count -ne @($current.Keys | Where-Object { $_ -like "Runtime/Native~/GpuTiming/*" }).Count) { throw "Native source evidence coverage is incomplete." }
}
foreach ($scripts in @(@($nativeTiming.scriptHashes),@($build.scriptHashes))) {
    $scriptSeen=@{}
    foreach ($script in $scripts) {
        $name=$script.file -replace '^.*[/\\]',''
        if ($name -notin @("Build-NativeGpuTiming.ps1","Validate-NativeGpuTiming.ps1") -or $scriptSeen.ContainsKey($name) -or
            $current["Tests/"+$name] -ne $script.sha256) { throw "Native validation script mismatch: $name" }
        $scriptSeen[$name]=$true
    }
    if ($scriptSeen.Count -ne 2) { throw "Native validation script coverage is incomplete." }
}
& (Join-Path $PSScriptRoot 'Verify-ReceiverIdentityReports.ps1') -Report $report -SourceHashes $current
& (Join-Path $PSScriptRoot 'Verify-HitMaterialReports.ps1') -Report $report -SourceHashes $current -SourceRoot $SourceRoot
# New transport kernels retain their actual-source and binary evidence; the
# mathematical case count is deliberately not a product completion criterion.
if(@($report.transportReports).Count -ne 2){throw 'Transport artifacts are missing.'}
$transportSeen=@{}
foreach($envelope in $report.transportReports) {
    if($envelope.stage -notin @('AreaEmission','SoftwareTriangleBvh') -or $transportSeen.ContainsKey($envelope.stage)){throw 'Invalid transport stage.'}
    $transportSeen[$envelope.stage]=$true
    if((Get-FileHash -LiteralPath $envelope.reportPath -Algorithm SHA256).Hash -ne $envelope.reportSha256){throw 'Transport report hash differs.'}
    $artifact=Get-Content -LiteralPath $envelope.reportPath -Raw -Encoding utf8 | ConvertFrom-Json
    if($artifact.status -ne 'passed' -or !$artifact.warpExecuted -or $artifact.unityExecuted -or $artifact.physicalGpuExecuted){throw 'Invalid transport evidence scope.'}
    foreach($stage in @('cpu-builder','dxc-actual-helper','warp-execute','oracle-verify')) {
        $entries=@($artifact.checks | Where-Object name -eq $stage)
        if($entries.Count -ne 1 -or $entries[0].exitCode -ne 0){throw "Missing transport check: $stage"}
    }
    foreach($source in @($artifact.sources)+@($artifact.sourcesAfter)) {
        if(!$current.ContainsKey($source.file) -or $current[$source.file] -ne $source.sha256){throw "Transport source differs: $($source.file)"}
    }
    foreach($binary in $artifact.artifacts) {
        if((Get-Item -LiteralPath $binary.path).Length -ne $binary.bytes -or
            (Get-FileHash -LiteralPath $binary.path -Algorithm SHA256).Hash -ne $binary.sha256){throw "Transport binary differs: $($binary.path)"}
    }
}
# Count the already-verified compiler entries, excluding tool/version commands.
$selectedDxc=@($core.checks).Count+@($native.checks).Count+@($globalSdf.checks).Count+
    @($receiver.checks).Count+@($report.receiverIdentityReport.checks).Count+
    @($report.receiverTemporalReport.checks|Where-Object name -eq 'dxc-actual-helper').Count
foreach($envelope in $report.hitMaterialReports){
    $selectedDxc+=@($envelope.report.checks|Where-Object {$_.name -like 'dxc-*' -and $_.name -ne 'dxc-version'}).Count
}
$selectedDxc+=2 # One actual transport helper entry in each verified transport report.
Write-Output "PASS: $($checks.Count) offline stages and $selectedDxc selected DXC checks; $($seen.Count) source hashes match the current package."
Write-Output "Native D3D12 evidence uses WARP software plus a mock Unity host; no Unity/physical-GPU production acceptance."
