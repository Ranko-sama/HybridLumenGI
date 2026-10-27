param([switch]$DownloadIncludes, [string]$ReportPath = (Join-Path $env:TEMP "HybridLumenGI-offline-results.json"))
$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$ReportPath = [IO.Path]::GetFullPath($ReportPath)
$results = [Collections.Generic.List[object]]::new()
$runRoot = Join-Path $env:TEMP ("hlgi-suite-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $runRoot | Out-Null
. (Join-Path $PSScriptRoot "Invoke-OfflineCheck.ps1")
function Source-Hashes {
    foreach ($directory in @("Runtime","Editor","Tests")) {
        Get-ChildItem -LiteralPath (Join-Path $root $directory) -File -Recurse | Where-Object {
            $_.Extension -in @(".cs",".hlsl",".shader",".compute",".ps1",".mjs",".cpp",".h",".hpp",".cmake") -or $_.Name -eq "CMakeLists.txt" -or $_.Name.EndsWith(".cs.txt") -or $_.Name.EndsWith(".cpp.txt") -or $_.Name.EndsWith(".cginc.txt")
        } | ForEach-Object {
            [pscustomobject]@{file=$_.FullName.Substring($root.Length+1).Replace("\","/");sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        }
    }
}
$report = [ordered]@{
    schemaVersion=1; status="running"; startedUtc=[DateTime]::UtcNow.ToString("o"); completedUtc=$null
    scope="CPU algorithms/adapters, numerical references, selected DXC variants, C# syntax, native C++ build and D3D12 WARP software execution with mock Unity host; no Unity import/API type-check, physical GPU, rendered GI imagery or target-device performance"
    checks=@(); sources=@(Source-Hashes); sourceChanges=@(); artifactErrors=@()
    globalSdfReport=$null; shaderReports=@(); nativeGpuTimingReport=$null; receiverPolicyReport=$null
    receiverIdentityReport=$null;receiverTemporalReport=$null
    runDirectory=$runRoot;hitMaterialReports=@();transportReports=@()
}
function Save-Report {
    $report.checks=@($results.ToArray())
    $report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $ReportPath -Encoding utf8
}
function Check([string]$Name,[string]$Executable,[string[]]$Arguments) {
    $result=Invoke-HLGIOfflineCheck -Name $Name -Executable $Executable -Arguments $Arguments -LogDirectory $runRoot
    $result | Add-Member -NotePropertyName executable -NotePropertyValue $Executable
    $result | Add-Member -NotePropertyName arguments -NotePropertyValue $Arguments
    $results.Add($result)
    Save-Report
    Write-Output "$Name exit=$($result.exitCode)"
    if($result.exitCode -ne 0) { Write-Output $result.output }
}
Push-Location $root
try {
    Save-Report
    foreach($test in @("OfflineRunner","CSharpSyntax","SdfNumerics","SdfAtlasAllocator","SdfAtlasRepresentation","SceneBvh","SceneResidency",
        "CacheScheduler","ChangeRegions","HlodTransactions","ChunkStreaming","SurfaceCharts","SurfaceCache","SurfaceReadiness","SurfaceSource","LitQualification","HardwareBackend","HlodReadback","EmissiveResources","GpuBudget","GpuTiming","GpuFrameTiming","NativeTimingBridge","HistoryLifecycle","ProxyUpdates","Lighting","MeshSource","MaterialSource","ReceiverHistory","ReceiverIdentityFrame","ReceiverIdentityPass","ScreenBudget",
        "RayTexturePool","HitMaterialLayout","HitMaterialBatch","HitMaterialPass","DeformedMesh")) {
        Check $test "powershell" @("-NoProfile","-ExecutionPolicy","Bypass","-File",("Tests/Validate-"+$test+".ps1"))
    }
    foreach($test in @("transport-reference","transport-audit-reference","Validate-GuidedSampling","Validate-GlobalSdfBounds","native-diffuse-reference","near-far-reference","Validate-SurfaceAnchors","Validate-EmissiveSampling","Validate-EmissiveProposals","Validate-SurfaceGeometryNormals","transport-normal-reference","Validate-ScreenGeometryPacking","Validate-SurfaceHitIdentity","Validate-DirectLighting","Validate-ReceiverPolicyCapture","Validate-ScreenSampling","Validate-ReceiverIdentity")) {
        Check $test "node" @("Tests/"+$test+".mjs")
    }
    Check "CaptureComparator" "node" @("Tests/compare-validation-captures.mjs","--self-test")
    # Reports belong to this run, so a failed compiler cannot reuse an old PASS.
    $coreReport=Join-Path $runRoot "shader-results.json"
    $nativeReport=Join-Path $runRoot "native-diffuse-results.json"
    $globalReport=Join-Path $runRoot "global-sdf-results.json"
    $core=@("-NoProfile","-ExecutionPolicy","Bypass","-File","Tests/ValidateShaders.ps1","-ReportPath",$coreReport)
    $native=@("-NoProfile","-ExecutionPolicy","Bypass","-File","Tests/Validate-NativeDiffuseCapture.ps1","-ReportPath",$nativeReport)
    if($DownloadIncludes) { $core+="-DownloadIncludes";$native+="-DownloadIncludes" }
    Check "CoreShaders" "powershell" $core
    Check "NativeDiffuseShaders" "powershell" $native
    $receiverReport=Join-Path $runRoot "receiver-policy-results.json"
    Check "ReceiverPolicyShaders" "powershell" @("-NoProfile","-ExecutionPolicy","Bypass","-File","Tests/Validate-ReceiverPolicyShaders.ps1","-ReportPath",$receiverReport)
    try {
        $report.receiverPolicyReport=Get-Content -LiteralPath $receiverReport -Raw -Encoding utf8 | ConvertFrom-Json
        if($report.receiverPolicyReport.status -ne "passed") { throw "Receiver policy shader report is not passed." }
    } catch { $report.artifactErrors+=@("${receiverReport}: $($_.Exception.Message)") }
    foreach($spec in @(@('ReceiverIdentityShaders','receiverIdentityReport'),@('ReceiverTemporal','receiverTemporalReport'))) {
        $identityReport=Join-Path $runRoot ($spec[0]+'-results.json')
        Check $spec[0] "powershell" @('-NoProfile','-ExecutionPolicy','Bypass','-File',('Tests/Validate-'+$spec[0]+'.ps1'),'-ReportPath',$identityReport)
        try {
            $artifact=Get-Content -LiteralPath $identityReport -Raw -Encoding utf8 | ConvertFrom-Json
            if($artifact.status -ne 'passed') {throw 'Receiver identity/temporal artifact is not passed.'}
            $report[$spec[1]]=$artifact
        } catch { $report.artifactErrors+=@("${identityReport}: $($_.Exception.Message)") }
    }
    Check "GlobalSdf" "powershell" @("-NoProfile","-ExecutionPolicy","Bypass","-File","Tests/Validate-GlobalSdf.ps1","-ReportPath",$globalReport)
    $nativeGpuReport=Join-Path $runRoot "native-gpu-timing-results.json"
    $nativeGpuArgs=@("-NoProfile","-ExecutionPolicy","Bypass","-File","Tests/Validate-NativeGpuTiming.ps1","-ReportPath",$nativeGpuReport)
    if($DownloadIncludes) { $nativeGpuArgs+="-DownloadUnityHeaders" }
    Check "NativeGpuTiming" "powershell" $nativeGpuArgs
    try {
        $report.nativeGpuTimingReport=Get-Content -LiteralPath $nativeGpuReport -Raw -Encoding utf8 | ConvertFrom-Json
        if($report.nativeGpuTimingReport.status -ne "passed") { throw "Native GPU timing report is not passed." }
    } catch { $report.artifactErrors+=@("${nativeGpuReport}: $($_.Exception.Message)") }
    foreach ($path in @($coreReport,$nativeReport,$globalReport)) {
        try {
            $artifact=Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
            if (!$artifact.checks -or @($artifact.checks | Where-Object exitCode -ne 0).Count -gt 0) { throw "Artifact has missing or failed checks." }
            if ($path -eq $globalReport) { $report.globalSdfReport=$artifact } else { $report.shaderReports+=@($artifact) }
        } catch { $report.artifactErrors+=@("${path}: $($_.Exception.Message)") }
    }
    # Each standalone GPU report is freshly addressed inside this run. Keep its
    # exact serialized bytes/hash as well as the embedded evidence. The packaging
    # verifier also re-reads actual DXIL/host/input/output/include files.
    foreach($stage in @('HardwareNormals','HardwareSurface','HardwareMaterials','HitMaterials','RayTextures','RayTextureCopy','RayFootprint','RadianceValidity','RayQueryPropagation')) {
        $materialReport=Join-Path $runRoot ($stage+'-results.json')
        Check $stage 'powershell' @('-NoProfile','-ExecutionPolicy','Bypass','-File',('Tests/Validate-'+$stage+'.ps1'),'-ReportPath',$materialReport)
        try {
            $artifact=Get-Content -LiteralPath $materialReport -Raw -Encoding utf8 | ConvertFrom-Json
            if($artifact.status -ne 'passed'){throw 'Material-chain standalone artifact is not passed.'}
            $report.hitMaterialReports+=@([pscustomobject]@{stage=$stage;reportPath=$materialReport;
                reportSha256=(Get-FileHash -LiteralPath $materialReport -Algorithm SHA256).Hash;report=$artifact})
        } catch { $report.artifactErrors+=@("${materialReport}: $($_.Exception.Message)") }
    }
    foreach($stage in @('AreaEmission','SoftwareTriangleBvh')) {
        $transportReport=Join-Path $runRoot ($stage+'-results.json')
        Check $stage 'powershell' @('-NoProfile','-ExecutionPolicy','Bypass','-File',('Tests/Validate-'+$stage+'.ps1'),'-ReportPath',$transportReport)
        try {
            $artifact=Get-Content -LiteralPath $transportReport -Raw -Encoding utf8 | ConvertFrom-Json
            if($artifact.status -ne 'passed'){throw 'Transport standalone artifact is not passed.'}
            $report.transportReports+=@([pscustomobject]@{stage=$stage;reportPath=$transportReport;
                reportSha256=(Get-FileHash -LiteralPath $transportReport -Algorithm SHA256).Hash;report=$artifact})
        } catch { $report.artifactErrors+=@("${transportReport}: $($_.Exception.Message)") }
    }
    $current=@{}
    @(Source-Hashes) | ForEach-Object { $current[$_.file]=$_.sha256 }
    foreach ($source in $report.sources) {
        if (!$current.ContainsKey($source.file) -or $current[$source.file] -ne $source.sha256) { $report.sourceChanges+=@($source.file) }
        $current.Remove($source.file)
    }
    $report.sourceChanges+=@($current.Keys)
    $passed=($results.Count -eq 73 -and @($results | Where-Object exitCode -ne 0).Count -eq 0 -and
        $report.artifactErrors.Count -eq 0 -and $report.sourceChanges.Count -eq 0)
    $report.status=if($passed) { "passed" } else { "failed" }
    $report.completedUtc=[DateTime]::UtcNow.ToString("o")
    Save-Report
    Write-Output "Report: $ReportPath"
    if(!$passed) {
        $report.artifactErrors | Write-Output
        if ($report.sourceChanges.Count) { Write-Output "Sources changed during validation: $($report.sourceChanges -join ', ')" }
        exit 1
    }
    # Reuse the packaging verifier so suite success includes exact stage/compiler
    # coverage and the validation-only RayQuery adapter, not just nonzero counts.
    & (Join-Path $PSScriptRoot "Verify-OfflineReport.ps1") -ReportPath $ReportPath -SourceRoot $root
    Write-Output "PASS: $($results.Count) offline stages. Production runtime validation remains outstanding."
} catch {
    $report.status="failed"
    $report.completedUtc=[DateTime]::UtcNow.ToString("o")
    $report.artifactErrors+=@($_.Exception.Message)
    Save-Report
    throw
} finally { Pop-Location }
