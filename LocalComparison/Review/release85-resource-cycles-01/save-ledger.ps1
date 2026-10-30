param([Parameter(Mandatory=$true)][string]$Label)
$ErrorActionPreference = 'Stop'
if ($Label -notmatch '^[a-z0-9-]+$') { throw 'Use a simple stage label.' }
$output = Join-Path $PSScriptRoot ($Label + '.json')
if (Test-Path -LiteralPath $output) { throw 'Preserve existing observation.' }
$line = Select-String -LiteralPath 'I:/Unity test/Comparison/Release85ResourceCycles01/player.log' -Pattern 'HLGI_UNIFIED_SAMPLE ' | Select-Object -Last 1
if ($null -eq $line) { throw 'No F2 observation.' }
$raw = $line.Line.Substring($line.Line.IndexOf('HLGI_UNIFIED_SAMPLE ') + 19)
$ledger = $raw | ConvertFrom-Json
[IO.File]::WriteAllText($output,$raw,[Text.UTF8Encoding]::new($false))
[ordered]@{ label=$Label;engineFrame=$ledger.engineFrame;status=$ledger.status;actualBackend=$ledger.actualBackend;
    visible=$ledger.visibleMembers;bound=$ledger.boundMembers;pagesReady=$ledger.pagesReady;loading=$ledger.pagesLoading;
    releasing=$ledger.pagesReleasing;failed=$ledger.pagesFailed;references=$ledger.pageConsumerReferences;
    leases=$ledger.pageRetiringLeases;operations=$ledger.pageActiveOperations;ioInFlight=$ledger.pageIoBytesInFlight;
    bundleBytes=$ledger.pageBundleBytes;residentBytes=$ledger.pageResidentBytes;
    retirementPending=$ledger.retirementPending;retirementFailed=$ledger.retirementFailed;uncertain=$ledger.retirementSubmissionUncertain;
    giFrame=$ledger.cameraGi.frame;hardwareMeshes=$ledger.cameraGi.hardwareMeshes
} | ConvertTo-Json
