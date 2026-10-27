param(
    [Parameter(Mandatory=$true)][string]$EvidenceManifestPath,
    [string]$SourceRoot='',
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
if(!$SourceRoot){$SourceRoot=Split-Path -Parent $PSScriptRoot}
$SourceRoot=(Resolve-Path -LiteralPath $SourceRoot).Path
$verifier=Join-Path $PSScriptRoot 'Verify-HitMaterialReports.ps1'
$run=Join-Path $env:TEMP ('hlgi-hit-material-report-negative-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run|Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$manifest=Get-Content -LiteralPath $EvidenceManifestPath -Raw -Encoding utf8|ConvertFrom-Json
$manifest=@($manifest) # PS5 ConvertFrom-Json emits a JSON array as one pipeline object.
$stages=@($manifest.stage);$hashes=@{};$originals=@{};$results=New-Object 'Collections.Generic.List[object]'
foreach($required in @('RayFootprint','RayTextureCopy','HitMaterials')){if($stages -notcontains $required){throw ('Real baseline manifest must include '+$required)}}
function Save-Json([string]$Path,$Value){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 40),$utf8)}
function Remember([string]$Path){
    if(!$originals.ContainsKey($Path)){$item=Get-Item -LiteralPath $Path;$originals[$Path]=[pscustomobject]@{path=$item.FullName;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}}
}
$reports=@{}
foreach($item in $manifest){
    if($reports.ContainsKey($item.stage)){throw 'Duplicate baseline stage.'}
    $r=Get-Content -LiteralPath $item.path -Raw -Encoding utf8|ConvertFrom-Json
    if($r.status -ne 'passed'){throw 'A failed standalone report cannot be a positive baseline.'}
    $reports[$item.stage]=$r;Remember $item.path
    foreach($s in $r.sources){$path=Join-Path $SourceRoot $s.file;$hashes[$s.file]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;Remember $path}
    foreach($a in $r.artifacts){Remember $a.path}
    foreach($c in $r.checks){Remember $c.log}
    foreach($inc in $r.includes){Remember (Join-Path (Join-Path $r.artifactDirectory 'includes') $inc.file)}
    foreach($file in @((Join-Path $r.artifactDirectory ('source/'+$item.stage+'Warp.cpp')),(Join-Path $r.artifactDirectory 'source/CMakeLists.txt'))){Remember $file}
    if($r.extractedTypes){Remember $r.extractedTypes.path}
}
Remember $verifier;Remember $PSCommandPath
$aggregateVerifier=Join-Path $PSScriptRoot 'Verify-OfflineReport.ps1'
$aggregateRunner=Join-Path $PSScriptRoot 'Validate-Offline.ps1'
Remember $aggregateVerifier;Remember $aggregateRunner
function Make-Fixture([string]$Name){
    $dir=Join-Path $run $Name;New-Item -ItemType Directory -Path $dir|Out-Null
    $main=[pscustomobject]@{kind='VerifierOnlyFixtureNotASuiteResult';runDirectory=$dir;hitMaterialReports=@();checks=@()}
    foreach($item in $manifest){
        # Exact byte copies are used for positive controls. Synthetic parent
        # invocation envelopes exercise linkage only; no suite run is claimed.
        $path=Join-Path $dir ($item.stage+'-results.json');Copy-Item -LiteralPath $item.path -Destination $path
        $r=Get-Content -LiteralPath $path -Raw -Encoding utf8|ConvertFrom-Json
        $main.hitMaterialReports+=@([pscustomobject]@{stage=$item.stage;reportPath=$path;reportSha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;report=$r})
        $main.checks+=@([pscustomobject]@{name=$item.stage;exitCode=0;startedUtc=$r.startedUtc;completedUtc=$r.completedUtc;
            arguments=@('-File',('Tests/Validate-'+$item.stage+'.ps1'),'-ReportPath',$path)})
    }
    return $main
}
function Entry($Main,[string]$Stage){return @($Main.hitMaterialReports|Where-Object stage -eq $Stage)[0]}
function Sync-Children($Main){
    foreach($e in $Main.hitMaterialReports){
        # Never use a mutated reportPath to write; all fixtures stay in new TEMP.
        $path=Join-Path $Main.runDirectory ($e.stage+'-results.json')
        Save-Json $path $e.report;$e.reportSha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}
function Control([string]$Name){
    $m=Make-Fixture $Name;$text=& $verifier -Report $m -SourceHashes $hashes -SourceRoot $SourceRoot -Stages $stages
    Save-Json (Join-Path $m.runDirectory 'fixture.json') $m
    [IO.File]::WriteAllText((Join-Path $m.runDirectory 'verification.log'),($text -join "`n"),$utf8)
    $results.Add([pscustomobject]@{name=$Name;type='positive-control';passed=$true;output=($text -join "`n")})
}
function Negative([string]$Name,[string]$Stage,[scriptblock]$Mutate,[string]$Expected,[switch]$AfterSync){
    $m=Make-Fixture $Name;$e=Entry $m $Stage
    if($AfterSync){Sync-Children $m;& $Mutate $m $e}else{& $Mutate $m $e;Sync-Children $m}
    Save-Json (Join-Path $m.runDirectory 'fixture.json') $m
    $rejected=$false;$message=''
    try { $message=(& $verifier -Report $m -SourceHashes $hashes -SourceRoot $SourceRoot -Stages $stages | Out-String) }
    catch { $rejected=$true;$message=$_.Exception.Message }
    $ok=$rejected -and $message -match $Expected
    [IO.File]::WriteAllText((Join-Path $m.runDirectory 'verification.log'),$message,$utf8)
    $results.Add([pscustomobject]@{name=$Name;type='negative';passed=$ok;rejected=$rejected;expectedReason=$Expected;actualReason=$message})
    if(!$ok){throw ($Name+' did not reject for its expected reason: '+$message)}
}
function Clone-Artifacts($Main,$Envelope){
    $old=$Envelope.report.artifactDirectory;$next=Join-Path $Main.runDirectory 'artifact-copy';New-Item -ItemType Directory -Path $next|Out-Null
    $paths=@($Envelope.report.artifacts.path)+@($Envelope.report.checks.log)+@((Join-Path $old ('source/'+$Envelope.stage+'Warp.cpp')),(Join-Path $old 'source/CMakeLists.txt'))
    foreach($path in $paths){$relative=$path.Substring($old.Length).TrimStart('\','/');$target=Join-Path $next $relative;New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;Copy-Item -LiteralPath $path -Destination $target}
    $json=$Envelope.report|ConvertTo-Json -Depth 40
    $Envelope.report=$json.Replace($old.Replace('\','\\'),$next.Replace('\','\\'))|ConvertFrom-Json
}
function Aggregate-StageNegatives {
    $tokens=$null;$errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($aggregateVerifier,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw 'Aggregate verifier parse errors.'}
    $assignment=$ast.Find({param($n)$n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$expected'},$true)
    $names=@($assignment.Right.FindAll({param($n)$n -is [System.Management.Automation.Language.StringConstantExpressionAst]},$true)|ForEach-Object Value)
    $required=@('RayTexturePool','HitMaterialLayout','HitMaterialBatch','HitMaterialPass','HardwareNormals','HardwareSurface','HardwareMaterials','HitMaterials','RayTextures','RayTextureCopy','RayFootprint','RadianceValidity')
    if($names.Count -ne 70 -or @($names|Select-Object -Unique).Count -ne 70){throw 'Aggregate exact 70-stage declaration mismatch.'}
    $runnerAst=[System.Management.Automation.Language.Parser]::ParseFile($aggregateRunner,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw 'Aggregate runner parse errors.'}
    $registered=@($runnerAst.FindAll({param($n)$n -is [System.Management.Automation.Language.ForEachStatementAst] -and $n.Variable.Extent.Text -in @('$test','$stage')},$true)|ForEach-Object {
        $_.Condition.FindAll({param($n)$n -is [System.Management.Automation.Language.StringConstantExpressionAst]},$true)|ForEach-Object Value
    })
    # Keep the existing negative matrix unchanged; the new stage is also checked
    # against the actual runner/verifier declarations before those cases run.
    if($names -notcontains 'RayQueryPropagation' -or $registered -notcontains 'RayQueryPropagation'){throw 'Missing runner/verifier declaration RayQueryPropagation'}
    $captureCalls=@($runnerAst.FindAll({param($n)$n -is [System.Management.Automation.Language.CommandAst] -and
        $n.GetCommandName() -eq 'Check' -and $n.CommandElements.Count -gt 1 -and $n.CommandElements[1].Extent.Text.Trim('"',"'") -eq 'CaptureComparator'},$true))
    if($names -notcontains 'CaptureComparator' -or $captureCalls.Count -ne 1 -or
        $captureCalls[0].Extent.Text -notmatch '^Check "CaptureComparator" "node" @\("Tests/compare-validation-captures\.mjs","--self-test"\)$'){throw 'Missing capture comparator self-test declaration.'}
    foreach($stage in $required){
        if($names -notcontains $stage -or $registered -notcontains $stage){throw ('Missing runner/verifier declaration '+$stage)}
        $dir=Join-Path $run ('aggregate-missing-'+$stage);New-Item -ItemType Directory -Path $dir|Out-Null
        # Deliberately incomplete NEGATIVE fixture. It must fail at stage coverage
        # before sources/artifacts are considered; never presented as passed evidence.
        $fixture=[ordered]@{schemaVersion=1;kind='ExpectedRejectedMissingStageFixture';status='passed';completedUtc=[DateTime]::UtcNow.ToString('o');
            sourceChanges=@();artifactErrors=@();sources=@();checks=@($names|Where-Object {$_ -ne $stage}|ForEach-Object {[pscustomobject]@{name=$_;exitCode=0;output='Synthetic negative fixture, no test execution'}})}
        $path=Join-Path $dir 'fixture.json';Save-Json $path $fixture;$rejected=$false;$message=''
        try{$message=(& $aggregateVerifier -ReportPath $path -SourceRoot $SourceRoot|Out-String)}catch{$rejected=$true;$message=$_.Exception.Message}
        $ok=$rejected -and $message -match '^Offline stage coverage is incomplete'
        [IO.File]::WriteAllText((Join-Path $dir 'verification.log'),$message,$utf8)
        $results.Add([pscustomobject]@{name='aggregate-missing-'+$stage;type='negative';passed=$ok;rejected=$rejected;expectedReason='Offline stage coverage is incomplete';actualReason=$message})
        if(!$ok){throw ('Aggregate missing-stage guard failed: '+$stage+' '+$message)}
    }
}
$final=[ordered]@{schemaVersion=1;kind='HitMaterialReportVerifierValidation';status='running';startedUtc=[DateTime]::UtcNow.ToString('o');
    evidenceManifest=[IO.Path]::GetFullPath($EvidenceManifestPath);stages=$stages;scope='Existing actual standalone reports and files only; verifier negative fixtures, not a unified suite or GPU rerun.'}
try {
    Control 'positive-before'
    Aggregate-StageNegatives
    Negative 'missing-report' 'RayFootprint' {param($m,$e)$m.hitMaterialReports=@($m.hitMaterialReports|Where-Object stage -ne 'RayFootprint')} 'report stage coverage incomplete'
    Negative 'duplicate-report' 'RayFootprint' {param($m,$e)$m.hitMaterialReports+=@($e)} 'duplicate report stage'
    Negative 'wrong-report-path' 'RayFootprint' {param($m,$e)$e.reportPath=Join-Path $m.runDirectory 'old-results.json'} 'report path is not this run stage' -AfterSync
    Negative 'report-digest' 'RayFootprint' {param($m,$e)$e.reportSha256='0'*64} 'actual artifact bytes/hash mismatch' -AfterSync
    Negative 'embedded-report' 'RayFootprint' {param($m,$e)$e.report.status='failed'} 'embedded report differs' -AfterSync
    foreach($field in @('schemaVersion','kind','status','warpExecuted','unityExecuted','physicalGpuExecuted')){
        $property=$field
        Negative ('envelope-'+$field) 'RayFootprint' {param($m,$e)
            switch($property){'schemaVersion'{$e.report.schemaVersion=2}'kind'{$e.report.kind='Other'}'status'{$e.report.status='failed'}'warpExecuted'{$e.report.warpExecuted=$false}'unityExecuted'{$e.report.unityExecuted=$true}'physicalGpuExecuted'{$e.report.physicalGpuExecuted=$true}}
        } 'missing, stale, failed or not actual WARP'
    }
    Negative 'schema-numeric-string' 'RayFootprint' {param($m,$e)$e.report.schemaVersion='1'} 'missing, stale, failed or not actual WARP'
    Negative 'warp-string-boolean' 'RayFootprint' {param($m,$e)$e.report.warpExecuted='true'} 'missing, stale, failed or not actual WARP'
    Negative 'source-changes' 'RayFootprint' {param($m,$e)$e.report|Add-Member -NotePropertyName sourceChanges -NotePropertyValue @('changed') -Force} 'missing, stale, failed or not actual WARP'
    Negative 'source-before-missing' 'RayFootprint' {param($m,$e)$e.report.sources=@()} 'source coverage incomplete'
    Negative 'source-after-missing' 'RayFootprint' {param($m,$e)$e.report.sourcesAfter=@()} 'source coverage incomplete'
    Negative 'source-before-stale' 'RayFootprint' {param($m,$e)$e.report.sources[0].sha256='0'*64} 'source identity mismatch'
    Negative 'source-after-stale' 'RayFootprint' {param($m,$e)$e.report.sourcesAfter[0].sha256='0'*64} 'source identity mismatch'
    Negative 'source-duplicate' 'RayFootprint' {param($m,$e)$e.report.sources+=@($e.report.sources[0])} 'source identity mismatch'
    Negative 'runner-stale' 'RayFootprint' {param($m,$e)($e.report.sources|Where-Object file -eq 'Tests/Validate-RayFootprint.ps1').sha256='0'*64} 'source identity mismatch'
    Negative 'stage-missing' 'RayFootprint' {param($m,$e)$e.report.checks=@($e.report.checks|Where-Object name -ne 'warp-execute')} 'execution step coverage incomplete'
    Negative 'stage-duplicate' 'RayFootprint' {param($m,$e)$e.report.checks+=@($e.report.checks[0])} 'invalid/duplicate execution step'
    Negative 'stage-failed' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'warp-execute').exitCode=1} 'invalid/duplicate execution step'
    Negative 'stage-log-output' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'warp-execute').output='invented'} 'execution log/output mismatch'
    Negative 'parent-not-current-invocation' 'RayFootprint' {param($m,$e)($m.checks|Where-Object name -eq 'RayFootprint').arguments[-1]=Join-Path $m.runDirectory 'old.json'} 'not bound to its unique suite invocation'
    Negative 'parent-start-after-artifact' 'RayFootprint' {param($m,$e)($m.checks|Where-Object name -eq 'RayFootprint').startedUtc=[DateTime]::UtcNow.AddDays(1).ToString('o')} 'not bound to its unique suite invocation'
    Negative 'artifact-missing-entry' 'RayFootprint' {param($m,$e)$e.report.artifacts=@($e.report.artifacts|Where-Object path -notlike '*.dxil')} 'binary artifact coverage incomplete'
    Negative 'artifact-duplicate' 'RayFootprint' {param($m,$e)$e.report.artifacts+=@($e.report.artifacts[0])} 'duplicate/empty binary artifact'
    Negative 'artifact-empty-hash' 'RayFootprint' {param($m,$e)$e.report.artifacts[0].sha256=''} 'actual artifact missing or invalid hash'
    Negative 'artifact-bad-hash' 'RayFootprint' {param($m,$e)$e.report.artifacts[0].sha256='0'*64} 'actual artifact bytes/hash mismatch'
    Negative 'artifact-byte-length' 'RayFootprint' {param($m,$e)$e.report.artifacts[0].bytes++} 'actual artifact bytes/hash mismatch'
    Negative 'actual-binary-changed' 'RayFootprint' {param($m,$e)
        Clone-Artifacts $m $e;$p=($e.report.artifacts|Where-Object path -like '*.exe').path;$b=[IO.File]::ReadAllBytes($p);$b[$b.Length-1]=$b[$b.Length-1] -bxor 1;[IO.File]::WriteAllBytes($p,$b)
    } 'actual artifact bytes/hash mismatch'
    Negative 'actual-binary-missing' 'RayFootprint' {param($m,$e)
        Clone-Artifacts $m $e;$p=($e.report.artifacts|Where-Object path -like '*.exe').path
        $full=[IO.Path]::GetFullPath($p);if(!$full.StartsWith($m.runDirectory+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'fixture path escaped'}
        Remove-Item -LiteralPath $full
    } 'actual artifact missing or invalid hash'
    Negative 'oracle-count' 'RayFootprint' {param($m,$e)$e.report.oracle.count--} 'oracle result differs'
    Negative 'oracle-checks' 'RayFootprint' {param($m,$e)$e.report.oracle.checks--} 'oracle result differs'
    Negative 'oracle-missing' 'RayFootprint' {param($m,$e)$e.report.oracle=$null} 'oracle result differs|oracle variant coverage incomplete'
    Negative 'host-not-tested-binary' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'warp-execute').executable=$e.report.tools.node} 'executed host differs'
    Negative 'warp-wrong-dxil' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'warp-execute').arguments[0]=Join-Path $e.report.artifactDirectory 'other.dxil'} 'WARP argument mismatch'
    Negative 'warp-missing-input' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'warp-execute').arguments=@('missing')} 'WARP argument count mismatch'
    Negative 'compiler-profile' 'RayFootprint' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'dxc-actual-helper';$c.arguments[[Array]::IndexOf($c.arguments,'-T')+1]='cs_6_6'} 'compiler identity/options mismatch'
    Negative 'compiler-entry' 'RayFootprint' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'dxc-actual-helper';$c.arguments[[Array]::IndexOf($c.arguments,'-E')+1]='Fake'} 'compiler identity/options mismatch'
    Negative 'compiler-output' 'RayFootprint' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'dxc-actual-helper';$c.arguments[[Array]::IndexOf($c.arguments,'-Fo')+1]=Join-Path $e.report.artifactDirectory 'other.dxil'} 'compiler identity/options mismatch'
    Negative 'compiler-optimization' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'dxc-actual-helper').arguments+=@('-Od')} 'compiler identity/options mismatch'
    Negative 'compiler-missing-option' 'RayFootprint' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'dxc-actual-helper';$c.arguments=@($c.arguments|Where-Object {$_ -ne '-T'})} 'missing/duplicate command option'
    Negative 'compiler-unbound-includes' 'RayFootprint' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'dxc-actual-helper';$c.arguments[[Array]::IndexOf($c.arguments,'-I')+1]=Join-Path $m.runDirectory 'other-includes'} 'compiler argument mismatch'
    Negative 'host-build-target' 'RayFootprint' {param($m,$e)($e.report.checks|Where-Object name -eq 'cmake-build').arguments[-1]='Other'} 'host build argument mismatch'
    Negative 'copy-entry-missing' 'RayTextureCopy' {param($m,$e)$e.report.compilerEntries=@($e.report.compilerEntries|Select-Object -First 2)} 'copy compiler coverage incomplete'
    Negative 'copy-entry-duplicate' 'RayTextureCopy' {param($m,$e)$e.report.compilerEntries+=@($e.report.compilerEntries[0])} 'copy compiler entry mismatch'
    Negative 'copy-entry-profile' 'RayTextureCopy' {param($m,$e)$e.report.compilerEntries[0].profile='cs_6_6'} 'copy compiler entry mismatch'
    Negative 'copy-resolve-not-executed' 'RayTextureCopy' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'warp-execute';$c.arguments[2]=$c.arguments[1]} 'WARP argument mismatch'
    Negative 'includes-revision' 'HitMaterials' {param($m,$e)$e.report.unityGraphicsRevision='other'} 'fixed Unity include revision mismatch'
    Negative 'includes-missing' 'HitMaterials' {param($m,$e)$e.report.includes=@()} 'actual include coverage incomplete'
    Negative 'includes-duplicate' 'HitMaterials' {param($m,$e)$e.report.includes+=@($e.report.includes[0])} 'invalid/duplicate include identity'
    Negative 'includes-hash' 'HitMaterials' {param($m,$e)$e.report.includes[0].sha256='0'*64} 'actual artifact bytes/hash mismatch'
    Negative 'includes-required-omitted' 'HitMaterials' {param($m,$e)$e.report.includes=@($e.report.includes|Where-Object file -notlike '*Packing.hlsl')} 'actual include coverage incomplete'
    Negative 'material-variant-absent' 'HitMaterials' {param($m,$e)$e.report.checks=@($e.report.checks|Where-Object name -ne 'warp-execute-ag')} 'execution step coverage incomplete'
    Negative 'material-variant-oracle-absent' 'HitMaterials' {param($m,$e)$e.report.oracle=@($e.report.oracle|Select-Object -First 2)} 'oracle variant coverage incomplete'
    Negative 'material-variant-definition' 'HitMaterials' {param($m,$e)$c=$e.report.checks|Where-Object name -eq 'dxc-actual-material-rgb';$c.arguments=@($c.arguments|Where-Object {$_ -ne 'UNITY_NO_DXT5nm=1'})} 'compiler argument count mismatch'
    if($stages -contains 'RadianceValidity'){
        Negative 'radiance-extraction-missing' 'RadianceValidity' {param($m,$e)$e.report.artifacts=@($e.report.artifacts|Where-Object path -notlike '*ActualTransportFunctions.hlsl')} 'binary artifact coverage incomplete'
    }
    if($stages -contains 'HardwareMaterials'){
        Negative 'hardware-purpose-entry-missing' 'HardwareMaterials' {param($m,$e)$e.report.checks=@($e.report.checks|Where-Object name -ne 'dxc-actual-material-ag-coverage')} 'execution step coverage incomplete'
        Negative 'hardware-purpose-missing' 'HardwareMaterials' {param($m,$e)$e.report.selectedDxcEntries=3} 'split-entry execution contract mismatch'
        Negative 'hardware-extracted-type-source' 'HardwareMaterials' {param($m,$e)$e.report.extractedTypes.source='wrong'} 'extracted hardware types identity mismatch'
        Negative 'hardware-extracted-type-hash' 'HardwareMaterials' {param($m,$e)$e.report.extractedTypes.sha256='0'*64} 'actual artifact bytes/hash mismatch'
        Negative 'hardware-shadow-not-executed' 'HardwareMaterials' {param($m,$e)$e.report.checks=@($e.report.checks|Where-Object name -ne 'warp-execute-ag-shadow')} 'execution step coverage incomplete'
        Negative 'hardware-shadow-oracle-kind' 'HardwareMaterials' {param($m,$e)$e.report.oracle[2].kind='coverage'} 'oracle result differs'
    }
    Control 'positive-after'
    foreach($original in $originals.Values){if((Get-Item -LiteralPath $original.path).Length -ne $original.bytes -or (Get-FileHash -LiteralPath $original.path -Algorithm SHA256).Hash -ne $original.sha256){throw ('Original evidence modified: '+$original.path)}}
    $final.status='passed'
} catch {$final.status='failed';$final.error=$_.Exception.Message}
finally {
    $auditPath=Join-Path $run 'input-file-audit.json';Save-Json $auditPath @($originals.Values|Sort-Object path)
    $final.completedUtc=[DateTime]::UtcNow.ToString('o');$final.results=@($results.ToArray());$final.negativeCount=@($results|Where-Object type -eq 'negative').Count
    $final.positiveControls=@($results|Where-Object type -eq 'positive-control').Count;$final.inputFileAudit=[ordered]@{path=$auditPath;count=$originals.Count;sha256=(Get-FileHash -LiteralPath $auditPath -Algorithm SHA256).Hash}
    $destination=if($ReportPath){[IO.Path]::GetFullPath($ReportPath)}else{Join-Path $run 'verifier-results.json'}
    Save-Json $destination $final
    Write-Output ('Verifier '+$final.status+': '+$final.negativeCount+' negative cases, '+$final.positiveControls+' controls; report: '+$destination)
    if($final.error){Write-Output $final.error}
}
if($final.status -ne 'passed'){exit 1}
