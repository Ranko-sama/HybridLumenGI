$ErrorActionPreference='Stop'
$taskRoot='C:/Users/Administrator/Desktop/test/HybridLumenGI'
$taskOld=Join-Path $taskRoot 'LocalComparison/Review/material-mpb-propagation-01'
$taskOut=Join-Path $taskRoot 'LocalComparison/Review/material-mpb-propagation-02/preflight'
$taskSource=Join-Path $taskRoot 'LocalComparison/Harness/MaterialEventSelection.cs'
New-Item -ItemType Directory -Path $taskOut -Force | Out-Null
Add-Type -Path $taskSource
$taskFolder=(Get-ChildItem -LiteralPath (Join-Path $taskOld 'native-window/run') -Directory).FullName
$taskRows=Get-Content -LiteralPath (Join-Path $taskFolder 'material-frames.jsonl') | ForEach-Object {$_ | ConvertFrom-Json}
$taskIdentityPath=Join-Path $taskFolder 'material-0158-identity-current.bin'
$taskGeometryPath=Join-Path $taskFolder 'material-0158-geometry.bin'
$taskIds=[IO.File]::ReadAllBytes($taskIdentityPath);$taskGeometry=[IO.File]::ReadAllBytes($taskGeometryPath)
$taskResults=@()
foreach($taskRole in $taskRows[158].sources){
    $taskCount=0
    $taskIndex=[HybridLumenGI.MaterialEventSelection]::FindInterior($taskIds,$taskGeometry,320,180,[uint32]$taskRole.keyLow,[uint32]$taskRole.keyHigh,
        [double][single]$taskRole.projectedCenter.x,[double][single]$taskRole.projectedCenter.y,[ref]$taskCount)
    $taskOldMatches=0
    for($taskOffset=0;$taskOffset -lt $taskIds.Length;$taskOffset+=16){
        if([BitConverter]::ToUInt32($taskIds,$taskOffset) -eq $taskRole.keyLow -and [BitConverter]::ToUInt32($taskIds,$taskOffset+4) -eq $taskRole.keyHigh -and
            [BitConverter]::ToUInt32($taskIds,$taskOffset+8) -eq $taskRole.row+1 -and [BitConverter]::ToUInt32($taskIds,$taskOffset+12) -ne 0){$taskOldMatches++}
    }
    $taskResults+=@{role=$taskRole.role;oldWrongPredicateMatches=$taskOldMatches;correctedInteriorCount=$taskCount;returnedIndex=$taskIndex;screenRequired=($taskRole.role -ne 'target-slot1')}
}
$taskPassed=($taskResults.Where({$_.role -eq 'target-slot0'})[0].correctedInteriorCount -eq 66 -and
    $taskResults.Where({$_.role -eq 'control'})[0].correctedInteriorCount -eq 10947 -and
    $taskResults.Where({$_.role -eq 'target-slot1'})[0].returnedIndex -eq -1 -and
    $taskResults.Where({$_.oldWrongPredicateMatches -ne 0}).Count -eq 0)
$taskReport=@{passed=$taskPassed;scope='Actual live pure selector against saved01 frame158; no historical159 admission/event created';roles=$taskResults;
    sourceSha256=(Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash.ToLowerInvariant();
    identitySha256=(Get-FileHash -LiteralPath $taskIdentityPath -Algorithm SHA256).Hash.ToLowerInvariant();
    geometrySha256=(Get-FileHash -LiteralPath $taskGeometryPath -Algorithm SHA256).Hash.ToLowerInvariant()}
$taskReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskOut 'saved-selector-check.json') -Encoding utf8
$taskReport | ConvertTo-Json -Depth 8
if(!$taskPassed){exit 1}
