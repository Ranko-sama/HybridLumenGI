param(
    [Parameter(Mandatory=$true)]$Report,
    [Parameter(Mandatory=$true)][hashtable]$SourceHashes,
    [string]$SourceRoot='',
    # A subset is only for auditing real standalone reports. The aggregate verifier
    # always calls the default complete set; this parameter cannot relax its stages.
    [ValidateSet('HardwareNormals','HardwareSurface','HardwareMaterials','HitMaterials','RayTextures','RayTextureCopy','RayFootprint','RadianceValidity','RayQueryPropagation')]
    [string[]]$Stages=@('HardwareNormals','HardwareSurface','HardwareMaterials','HitMaterials','RayTextures','RayTextureCopy','RayFootprint','RadianceValidity','RayQueryPropagation')
)
$ErrorActionPreference='Stop'
if(!$SourceRoot){$SourceRoot=Split-Path -Parent $PSScriptRoot}
function HM-Fail([string]$Message){throw ('Hit material evidence: '+$Message)}
function HM-Path([string]$Path){
    if([string]::IsNullOrWhiteSpace($Path) -or ![IO.Path]::IsPathRooted($Path)){HM-Fail 'artifact path must be absolute.'}
    return [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
}
function HM-SamePath([string]$A,[string]$B){return (HM-Path $A) -eq (HM-Path $B)}
function HM-Child([string]$Root,[string]$Path){
    $base=(HM-Path $Root)+[IO.Path]::DirectorySeparatorChar;$full=HM-Path $Path
    if(!$full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){HM-Fail 'artifact escaped its run directory.'}
    return $full.Substring($base.Length).Replace('\','/')
}
function HM-File([string]$Path,[string]$Hash,[long]$Bytes=-1){
    if($Hash -notmatch '^[0-9A-Fa-f]{64}$' -or !(Test-Path -LiteralPath $Path -PathType Leaf)){HM-Fail ('actual artifact missing or invalid hash: '+$Path)}
    $item=Get-Item -LiteralPath $Path
    if(($Bytes -ge 0 -and $item.Length -ne $Bytes) -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Hash){HM-Fail ('actual artifact bytes/hash mismatch: '+$Path)}
}
function HM-SourceSet($Entries,[string[]]$Expected){
    $seen=@{}
    foreach($s in $Entries){
        if(!$s.file -or $seen.ContainsKey($s.file) -or $Expected -notcontains $s.file -or !$SourceHashes.ContainsKey($s.file) -or
            $s.sha256 -notmatch '^[0-9A-Fa-f]{64}$' -or $s.sha256 -ne $SourceHashes[$s.file]){HM-Fail ('source identity mismatch: '+$s.file)}
        $seen[$s.file]=$true
    }
    if($seen.Count -ne $Expected.Count){HM-Fail 'source coverage incomplete.'}
}
function HM-Arg($Check,[string]$Option){
    $args=@($Check.arguments);$indices=@();for($i=0;$i -lt $args.Count;$i++){if($args[$i] -eq $Option){$indices+=@($i)}}
    if($indices.Count -ne 1 -or $indices[0]+1 -ge $args.Count){HM-Fail ('missing/duplicate command option '+$Option+' in '+$Check.name)}
    return [string]$args[$indices[0]+1]
}
function HM-Sequence($Actual,$Expected,[string]$Label){
    $a=@($Actual);$b=@($Expected);if($a.Count -ne $b.Count){HM-Fail ($Label+' argument count mismatch.')}
    for($i=0;$i -lt $a.Count;$i++){if([string]$a[$i] -ne [string]$b[$i]){HM-Fail ($Label+' argument mismatch.')}}
}
function HM-Canonical($Value){
    # PS5 parses ordinary decimal JSON and exponent JSON into different numeric
    # CLR types. Compare their exact binary64 values, never their display syntax.
    if($null -eq $Value){return 'null'}
    if($Value -is [bool]){return 'bool:'+([string]$Value)}
    if($Value -is [string]){return 'str:'+($Value|ConvertTo-Json -Compress)}
    if($Value -is [double] -or $Value -is [single] -or $Value -is [decimal] -or $Value -is [int] -or $Value -is [long] -or $Value -is [uint32] -or $Value -is [uint64]){
        return 'num:'+([double]$Value).ToString('R',[Globalization.CultureInfo]::InvariantCulture)
    }
    if($Value -is [DateTime]){return 'time:'+$Value.ToUniversalTime().ToString('o')}
    if($Value -is [Collections.IList]){return 'array:['+((@($Value|ForEach-Object {HM-Canonical $_})) -join ',')+']'}
    $members=@();foreach($property in @($Value.PSObject.Properties|Sort-Object Name)){$members+=@(($property.Name|ConvertTo-Json -Compress)+':'+(HM-Canonical $property.Value))}
    return 'object:{'+($members -join ',')+'}'
}
function HM-Json($A,$B,[string]$Label){
    if((HM-Canonical $A) -cne (HM-Canonical $B)){HM-Fail ($Label+' differs from actual JSON artifact.')}
}
function HM-ExtractFunction([string]$Text,[string]$Pattern){
    $m=[regex]::Match($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::Multiline)
    if(!$m.Success){HM-Fail ('missing source function '+$Pattern)}
    $open=$Text.IndexOf('{',$m.Index);$depth=0
    for($i=$open;$i -lt $Text.Length;$i++){if($Text[$i] -eq '{'){$depth++}elseif($Text[$i] -eq '}'){$depth--;if($depth -eq 0){return $Text.Substring($m.Index,$i-$m.Index+1)}}}
    HM-Fail 'unterminated source function.'
}
$specs=@{
    HardwareNormals=@{stem='hardware-normals';count=4183;checks=16666;entry='CSHardwareNormalsTest';outputStride=48;extra=@('HardwareNormals','HardwareTrace','ExactMesh')}
    HardwareSurface=@{stem='hardware-surface';count=790;checks=18173;entry='CSHardwareSurfaceTest';outputStride=96;extra=@('HardwareSurface','HardwareNormals')}
    HardwareMaterials=@{stem='hardware-materials';variants=@('rgag-full','rgag-coverage','rgag-shadow','rgb-full','rgb-coverage','rgb-shadow','ag-full','ag-coverage','ag-shadow');outputStride=112;extra=@('HardwareMaterials','ExactMesh','HitMaterials','RayTextures','HardwareSurface','HardwareNormals')}
    HitMaterials=@{stem='hit-materials';variants=@('rgag','rgb','ag');count=3150;checks=75600;entry='CSHitMaterialsTest';outputStride=96;extra=@('HitMaterials','RayTextures')}
    RayTextures=@{stem='ray-textures';count=36934;checks=110802;entry='CSRayTexturesTest';inputStride=32;outputStride=32;extra=@('RayTextures')}
    RayTextureCopy=@{stem='ray-texture-copy';count=103;checks=40823;entries=@('CSBeginRayTextureCopy','CSCopyRayTextureMip','CSFinishRayTextureCopy','CSCopyRayTextureRange');extra=@('RayTextureCopy')}
    RayFootprint=@{stem='ray-footprint';count=1530;checks=19891;entry='CSRayFootprintTest';outputStride=48;extra=@('RayFootprint')}
    RadianceValidity=@{stem='radiance-validity';count=2534;checks=293944;entry='CSRadianceValidityTest';inputStride=208;outputStride=368;extra=@('RadianceValidity','Hit','Transport','Kernels','HardwareTrace','ExactMesh','RayFootprint')}
    RayQueryPropagation=@{stem='ray-query-propagation';count=1676;checks=154192;entry='CSRayQueryPropagationTest';inputStride=160;outputStride=368;extra=@('RayFootprint','Hit','Transport')}
}
$run=HM-Path $Report.runDirectory
$envelopes=@{};$artifactRoots=@{}
foreach($e in $Report.hitMaterialReports){
    if(!$e.stage -or $Stages -notcontains $e.stage -or $envelopes.ContainsKey($e.stage)){HM-Fail ('unexpected/duplicate report stage '+$e.stage)}
    $stageRun=$run
    # A disclosed consolidation may retain a repaired stage's real invocation
    # directory. Its exact -ReportPath, times, hashes and artifacts are still
    # checked below; copying it into the old run must not invent an invocation.
    if($Report.consolidation -and $Report.consolidation.stageRunDirectories){
        $override=$Report.consolidation.stageRunDirectories.PSObject.Properties[$e.stage]
        if($override){$stageRun=HM-Path ([string]$override.Value)}
    }
    if(!(HM-SamePath $e.reportPath (Join-Path $stageRun ($e.stage+'-results.json')))){HM-Fail ('report path is not its declared run stage: '+$e.stage)}
    HM-File $e.reportPath $e.reportSha256
    $actual=Get-Content -LiteralPath $e.reportPath -Raw -Encoding utf8|ConvertFrom-Json
    HM-Json $e.report $actual 'embedded report'
    $envelopes[$e.stage]=$e
}
if($envelopes.Count -ne $Stages.Count -or @($Stages|Select-Object -Unique).Count -ne $Stages.Count){HM-Fail 'report stage coverage incomplete.'}
$totalDxc=0;$totalFiles=0
foreach($name in $Stages){
    $r=$envelopes[$name].report;$spec=$specs[$name];$base=HM-Path $r.artifactDirectory
    if($artifactRoots.ContainsKey($base)){HM-Fail 'standalone artifact directories must be unique.'};$artifactRoots[$base]=$true
    if(($r.schemaVersion -isnot [int] -and $r.schemaVersion -isnot [long]) -or $r.schemaVersion -ne 1 -or $r.kind -ne ($name+'ActualWarpValidation') -or $r.status -ne 'passed' -or !$r.startedUtc -or !$r.completedUtc -or
        $r.error -or $r.sourceChanges -or $r.warpExecuted -isnot [bool] -or $r.unityExecuted -isnot [bool] -or $r.physicalGpuExecuted -isnot [bool] -or
        $r.warpExecuted -ne $true -or $r.unityExecuted -ne $false -or $r.physicalGpuExecuted -ne $false){HM-Fail ($name+' missing, stale, failed or not actual WARP.')}
    $start=[DateTimeOffset]::Parse($r.startedUtc);$end=[DateTimeOffset]::Parse($r.completedUtc)
    if($end -lt $start){HM-Fail 'invalid report time range.'}
    $parent=@($Report.checks|Where-Object name -eq $name)
    if($parent.Count -ne 1 -or $parent[0].exitCode -ne 0 -or !$parent[0].startedUtc -or !$parent[0].completedUtc -or
        $start -lt [DateTimeOffset]::Parse($parent[0].startedUtc) -or $end -gt [DateTimeOffset]::Parse($parent[0].completedUtc) -or
        (HM-Arg $parent[0] '-File').Replace('\','/') -ne ('Tests/Validate-'+$name+'.ps1') -or
        !(HM-SamePath (HM-Arg $parent[0] '-ReportPath') $envelopes[$name].reportPath)){HM-Fail ($name+' is not bound to its unique suite invocation.')}
    if($name -eq 'HardwareMaterials' -and ($r.selectedDxcEntries -ne 9 -or $r.softwareFenceWaitLimitMs -ne 180000)){HM-Fail 'hardware material split-entry execution contract mismatch.'}
    $sources=@($spec.extra|ForEach-Object {'Runtime/Resources/HybridLumenGI/HybridLumenGI'+$_+'.hlsl'})
    $sources+=@("Tests/Standalone$name/${name}Warp.cpp.txt","Tests/Standalone$name/${name}Oracle.mjs","Tests/Standalone$name/CMakeLists.txt",'Tests/Invoke-OfflineCheck.ps1',"Tests/Validate-$name.ps1")
    if($name -eq 'RayTextureCopy'){$sources+=@('Runtime/Resources/HybridLumenGI/HybridLumenGIRayTextureCopy.compute')}
    else{$sources+=@('Tests/Standalone'+$name+'/'+$name+'Harness.hlsl')}
    HM-SourceSet $r.sources $sources;HM-SourceSet $r.sourcesAfter $sources
    foreach($source in $sources){HM-File (Join-Path $SourceRoot $source) $SourceHashes[$source]}
    if($name -eq 'RayQueryPropagation'){
        # The standalone runner may diagnose edits outside its extracted function.
        # Aggregate acceptance still requires the entire before/after source set
        # above to match, and every actual compiler snapshot to have those bytes.
        if($r.currentFunctionMatchesSnapshot -isnot [bool] -or !$r.currentFunctionMatchesSnapshot -or
            $r.transportOutsideFunctionChanged -isnot [bool] -or $r.transportOutsideFunctionChanged){HM-Fail 'ray query source snapshot changed.'}
        foreach($s in @($r.sources)+@($r.sourcesAfter)){
            if(!(HM-SamePath $s.snapshotPath (Join-Path $base ('snapshot/'+$s.file)))){HM-Fail 'ray query source snapshot path mismatch.'}
            HM-File $s.snapshotPath $s.sha256
        }
    }
    if($r.tools.CMAKE_CXX_COMPILER_ID -ne 'MSVC' -or !$r.tools.CMAKE_CXX_COMPILER_VERSION -or !$r.tools.CMAKE_CXX_COMPILER -or !$r.tools.dxc -or !$r.tools.cmake -or !$r.tools.node){HM-Fail 'toolchain evidence incomplete.'}
    $variants=if($spec.variants){@($spec.variants)}else{@('')}
    $expectedChecks=@('vswhere','cmake-version','dxc-version','cmake-configure','cmake-build')
    $required=@('build/Release/'+$name+'Warp.exe')
    foreach($v in $variants){
        $suffix=if($v){'-'+$v}else{''};$prefix=if($v){$v+'/'}else{''}
        $expectedChecks+=@("oracle-prepare$suffix","warp-execute$suffix","oracle-verify$suffix")
        if($spec.entries){foreach($entry in $spec.entries){$expectedChecks+=@('dxc-'+$entry);$required+=@("$entry.dxil","$entry.ll")}}
        else{$expectedChecks+=@(if($v){'dxc-actual-material-'+$v}else{'dxc-actual-helper'});$required+=@("${prefix}$($spec.stem).dxil","${prefix}$($spec.stem).ll")}
        $required+=@("${prefix}inputs.bin","${prefix}outputs.bin","${prefix}oracle.json","${prefix}oracle-results.json")
    }
    if($name -eq 'RadianceValidity'){$required+=@('ActualTransportFunctions.hlsl')}
    if($name -eq 'RayQueryPropagation'){$required+=@('snapshot/Runtime/Resources/HybridLumenGI/ActualTraceSceneQuery.hlsl')}
    $files=@{}
    foreach($a in $r.artifacts){
        $rel=HM-Child $base $a.path
        if($required -notcontains $rel -or $files.ContainsKey($rel) -or $a.bytes -le 0){HM-Fail ('unexpected/duplicate/empty binary artifact '+$rel)}
        HM-File $a.path $a.sha256 $a.bytes;$files[$rel]=$a;$totalFiles++
    }
    if($files.Count -ne $required.Count){HM-Fail ($name+' binary artifact coverage incomplete.')}
    $steps=@{}
    foreach($c in $r.checks){
        if(!$c.name -or $expectedChecks -notcontains $c.name -or $steps.ContainsKey($c.name) -or $c.exitCode -ne 0 -or !$c.executable -or @($c.arguments).Count -eq 0 -or
            !$c.startedUtc -or !$c.completedUtc -or [DateTimeOffset]::Parse($c.startedUtc) -lt $start -or [DateTimeOffset]::Parse($c.completedUtc) -gt $end -or
            [DateTimeOffset]::Parse($c.completedUtc) -lt [DateTimeOffset]::Parse($c.startedUtc)){HM-Fail ('invalid/duplicate execution step '+$c.name)}
        if(!(HM-SamePath $c.log (Join-Path $base ($c.name+'.log'))) -or !(Test-Path -LiteralPath $c.log -PathType Leaf)){HM-Fail 'actual execution log missing.'}
        if(([IO.File]::ReadAllText($c.log)).Trim() -ne ([string]$c.output).Trim()){HM-Fail ('execution log/output mismatch '+$c.name)}
        if($c.name -notlike 'dxc-*' -and [string]::IsNullOrWhiteSpace($c.output)){HM-Fail ('execution output absent '+$c.name)}
        $steps[$c.name]=$c
    }
    if($steps.Count -ne $expectedChecks.Count){HM-Fail ($name+' execution step coverage incomplete.')}
    $exe=$files['build/Release/'+$name+'Warp.exe'].path
    $pe=[IO.File]::ReadAllBytes($exe)
    if($pe.Length -lt 64 -or $pe[0] -ne 77 -or $pe[1] -ne 90){HM-Fail 'actual host is not PE.'}
    $peOffset=[BitConverter]::ToInt32($pe,60)
    if($peOffset -lt 64 -or $peOffset+6 -gt $pe.Length -or [BitConverter]::ToUInt32($pe,$peOffset) -ne 17744 -or [BitConverter]::ToUInt16($pe,$peOffset+4) -ne 34404){HM-Fail 'actual host is not x64 PE.'}
    HM-Sequence @($steps['cmake-build'].arguments) @('--build',(Join-Path $base 'build'),'--config','Release','--target',($name+'Warp')) 'host build'
    if(!(HM-SamePath $steps['cmake-build'].executable $r.tools.cmake) -or (HM-Arg $steps['cmake-configure'] '-A') -ne 'x64' -or (HM-Arg $steps['cmake-configure'] '-G') -ne 'Visual Studio 17 2022' -or
        !(HM-SamePath (HM-Arg $steps['cmake-configure'] '-S') (Join-Path $base 'source')) -or !(HM-SamePath (HM-Arg $steps['cmake-configure'] '-B') (Join-Path $base 'build'))){HM-Fail 'host build/configure identity mismatch.'}
    HM-File (Join-Path $base ('source/'+$name+'Warp.cpp')) $SourceHashes['Tests/Standalone'+$name+'/'+$name+'Warp.cpp.txt']
    HM-File (Join-Path $base 'source/CMakeLists.txt') $SourceHashes['Tests/Standalone'+$name+'/CMakeLists.txt']
    $oracles=@($r.oracle);if($oracles.Count -ne $variants.Count){HM-Fail 'oracle variant coverage incomplete.'}
    for($vi=0;$vi -lt $variants.Count;$vi++){
        $v=$variants[$vi];$suffix=if($v){'-'+$v}else{''};$prefix=if($v){$v+'/'}else{''};$vroot=if($v){Join-Path $base $v}else{$base}
        $count=$spec.count;$checkCount=$spec.checks;$entry=$spec.entry
        $encoding=if($v){$v.Split('-')[0]}else{''}
        $mode=if($name -eq 'HardwareMaterials'){$v.Split('-')[1]}else{''}
        if($name -eq 'HardwareMaterials'){
            $count=if($mode -eq 'full'){248}elseif($mode -eq 'coverage'){149}else{152};$checkCount=$count*28
            $entry=if($mode -eq 'full'){'CSHardwareMaterialsFull'}elseif($mode -eq 'coverage'){'CSHardwareMaterialsCoverage'}else{'CSHardwareMaterialsShadow'}
        }
        $oraclePath=$files[$prefix+'oracle-results.json'].path;$oracle=Get-Content -LiteralPath $oraclePath -Raw|ConvertFrom-Json
        HM-Json $oracles[$vi] $oracle 'oracle result'
        if($oracle.status -ne 'passed' -or $oracle.count -ne $count -or $oracle.checks -ne $checkCount -or
            ($v -and $oracle.encoding -ne $encoding) -or ($mode -and $oracle.kind -ne $mode)){HM-Fail ('oracle result coverage mismatch '+$name+'/'+$v)}
        $fixture=Get-Content -LiteralPath $files[$prefix+'oracle.json'].path -Raw|ConvertFrom-Json
        if($fixture.count -ne $count -or ($v -and $fixture.encoding -ne $encoding) -or ($mode -and $fixture.kind -ne $mode)){HM-Fail 'input oracle identity mismatch.'}
        $input=$files[$prefix+'inputs.bin'];$output=$files[$prefix+'outputs.bin'];$stream=[IO.File]::OpenRead($input.path)
        try{$header=New-Object byte[] 4;if($stream.Read($header,0,4) -ne 4 -or [BitConverter]::ToUInt32($header,0) -ne $count){HM-Fail 'input binary case count mismatch.'}}finally{$stream.Dispose()}
        if($name -eq 'RayTextures'){
            # The case array follows a three-word header, metadata rows and the
            # texture arena. Its 32-byte stride is not the whole file layout.
            $stream=[IO.File]::OpenRead($input.path)
            try{
                $header=New-Object byte[] 12
                if($stream.Read($header,0,12) -ne 12 -or
                    [BitConverter]::ToUInt32($header,4) -ne $fixture.metadataCount -or
                    [BitConverter]::ToUInt32($header,8) -ne $fixture.texelCount -or
                    $input.bytes -ne 12+[long]$fixture.metadataCount*64+[long]$fixture.texelCount*16+[long]$count*$spec.inputStride){
                    HM-Fail 'texture input metadata/arena/case coverage mismatch.'
                }
            }finally{$stream.Dispose()}
        }elseif($spec.inputStride -and $input.bytes -ne 4+[long]$count*$spec.inputStride){HM-Fail 'input binary stride/coverage mismatch.'}
        if($spec.outputStride -and $output.bytes -ne [long]$count*$spec.outputStride){HM-Fail 'output binary stride/coverage mismatch.'}
        $oracleSource=$SourceHashes['Tests/Standalone'+$name+'/'+$name+'Oracle.mjs']
        foreach($operation in @('prepare','verify')){
            $step=$steps['oracle-'+$operation+$suffix];$args=@($step.arguments)
            HM-File $args[0] $oracleSource
            $expected=@($args[0],$operation,$vroot);if($v){$expected+=@($encoding)};if($mode){$expected+=@($mode)}
            HM-Sequence $args $expected ('oracle-'+$operation)
            if(!(HM-SamePath $step.executable $r.tools.node)){HM-Fail 'oracle executable identity mismatch.'}
        }
        $dxilPaths=@()
        $compileEntries=if($spec.entries){@($spec.entries)}else{@($entry)}
        foreach($ce in $compileEntries){
            $compileName=if($spec.entries){'dxc-'+$ce}elseif($v){'dxc-actual-material-'+$v}else{'dxc-actual-helper'}
            $step=$steps[$compileName];$stem=if($spec.entries){$ce}else{$spec.stem}
            $dxil=$files[$prefix+$stem+'.dxil'].path;$listing=$files[$prefix+$stem+'.ll'].path;$dxilPaths+=@($dxil)
            if((HM-Arg $step '-E') -ne $ce -or (HM-Arg $step '-T') -ne 'cs_6_0' -or (HM-Arg $step '-HV') -ne '2018' -or
                !(HM-SamePath (HM-Arg $step '-Fo') $dxil) -or !(HM-SamePath (HM-Arg $step '-Fc') $listing) -or !(HM-SamePath $step.executable $r.tools.dxc) -or
                @($step.arguments|Where-Object {$_ -in @('-Od','-O0','-O1','-O2','-O3')}).Count){HM-Fail ('compiler identity/options mismatch '+$compileName)}
            $shaderSource=if($spec.entries){'Runtime/Resources/HybridLumenGI/HybridLumenGIRayTextureCopy.hlsl'}else{'Tests/Standalone'+$name+'/'+$name+'Harness.hlsl'}
            HM-File @($step.arguments)[-1] $SourceHashes[$shaderSource]
            # A separately preserved, byte-identical source snapshot can be audited
            # after the workspace evolves. Includes remain bound to the actual
            # recorded input's source root, not a newly invented compiler root.
            $compiledInput=(HM-Path @($step.arguments)[-1]).Replace('\','/')
            if(!$compiledInput.EndsWith('/'+$shaderSource,[StringComparison]::OrdinalIgnoreCase)){HM-Fail 'compiler input source path mismatch.'}
            $compiledSourceRoot=$compiledInput.Substring(0,$compiledInput.Length-$shaderSource.Length-1)
            $expectedArgs=@('-HV','2018','-T','cs_6_0','-E',$ce)
            if($v){$expectedArgs+=@('-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',(Join-Path $base 'includes'))}
            $expectedArgs+=@('-I',(Join-Path $compiledSourceRoot 'Runtime/Resources/HybridLumenGI'))
            if($name -eq 'RadianceValidity'){$expectedArgs+=@('-I',$base)}
            $expectedArgs+=@('-Fo',$dxil,'-Fc',$listing)
            if($encoding -eq 'rgb'){$expectedArgs+=@('-D','UNITY_NO_DXT5nm=1')}
            if($encoding -eq 'ag'){$expectedArgs+=@('-D','UNITY_ASTC_NORMALMAP_ENCODING=1')}
            $expectedArgs+=@((Join-Path $compiledSourceRoot $shaderSource))
            HM-Sequence $step.arguments $expectedArgs 'compiler'
            $bytes=[IO.File]::ReadAllBytes($dxil);if($bytes.Length -lt 32 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'DXBC'){HM-Fail 'invalid actual DXIL container.'}
            $assembly=[IO.File]::ReadAllText($listing);if($assembly -notmatch [regex]::Escape($ce)){HM-Fail 'compiled entry absent in actual listing.'}
            if($name -eq 'RayTextureCopy' -and ($assembly -notmatch '(?s)HLGIRayTextureCopyParameters.*?Size:\s+24' -or
                $assembly -notmatch '_HLGI_CopyTextureCapacity;\s*; Offset:\s+12' -or
                $assembly -notmatch '_HLGI_CopyRangeStart;\s*; Offset:\s+16' -or
                $assembly -notmatch '_HLGI_CopyRangeCount;\s*; Offset:\s+20')){HM-Fail 'copy parameter ABI mismatch.'}
            if($v){
                foreach($define in @('SHADER_API_D3D11=1','SHADER_STAGE_COMPUTE=1','UNITY_COMPILER_DXC=1','UNITY_VERSION=600000')){if(@($step.arguments) -notcontains $define){HM-Fail 'required material compiler definition missing.'}}
                $rgb=@($step.arguments) -contains 'UNITY_NO_DXT5nm=1';$ag=@($step.arguments) -contains 'UNITY_ASTC_NORMALMAP_ENCODING=1'
                if($rgb -ne ($encoding -eq 'rgb') -or $ag -ne ($encoding -eq 'ag')){HM-Fail 'normal encoding compiler mismatch.'}
            }
            $totalDxc++
        }
        $warp=$steps['warp-execute'+$suffix]
        if(!(HM-SamePath $warp.executable $exe)){HM-Fail 'executed host differs from actual binary artifact.'}
        HM-Sequence $warp.arguments @($dxilPaths+@($input.path,$output.path)) 'WARP'
        if([DateTimeOffset]::Parse($warp.startedUtc) -lt [DateTimeOffset]::Parse($steps['cmake-build'].completedUtc) -or
            [DateTimeOffset]::Parse($steps['oracle-verify'+$suffix].startedUtc) -lt [DateTimeOffset]::Parse($warp.completedUtc)){HM-Fail 'execution/oracle ordering mismatch.'}
    }
    if($name -eq 'RayTextureCopy'){
        $seen=@{};foreach($c in $r.compilerEntries){
            if($spec.entries -notcontains $c.entry -or $seen.ContainsKey($c.entry) -or $c.profile -ne 'cs_6_0' -or $c.exitCode -ne 0 -or
                !(HM-SamePath $c.dxilPath $files[$c.entry+'.dxil'].path) -or !(HM-SamePath $c.listingPath $files[$c.entry+'.ll'].path)){HM-Fail 'copy compiler entry mismatch.'};$seen[$c.entry]=$true
        };if($seen.Count -ne 4){HM-Fail 'copy compiler coverage incomplete.'}
    }
    if($spec.variants){
        if($r.unityGraphicsRevision -ne 'feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53'){HM-Fail 'fixed Unity include revision mismatch.'}
        $pins=@{
            'Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl'='D2A0D8FC95539837EC612E768F80284DF0A50ACA39A50E1D5E91A827DAD4F0C0'
            'Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl'='DF21B00C1457CE5C8C1AE6069FB4E6E4B4E15B3334ECE98A28B7D2E8F302082E'
            'Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl'='1025EFB7D34F4F73864944624490684CA11E5D35DFA5435895D7BD6D2D640B74'
            'Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl'='9EE9A26C9D8245AA7B2A8C44F2D92CCDC055F86BE9E366BDBD9D217D831E3ACD'
        }
        $includeRoot=Join-Path $base 'includes';$seen=@{}
        foreach($inc in $r.includes){
            $key=([string]$inc.file).Replace('\','/');if(!$key.StartsWith('Packages/') -or $key.Contains('..') -or $seen.ContainsKey($key)){HM-Fail 'invalid/duplicate include identity.'}
            HM-File (Join-Path $includeRoot $key) $inc.sha256;$seen[$key]=$inc.sha256
        }
        $actualIncludes=@(Get-ChildItem -LiteralPath (Join-Path $includeRoot 'Packages') -File -Recurse)
        if($seen.Count -ne $actualIncludes.Count){HM-Fail 'actual include coverage incomplete.'}
        foreach($pin in $pins.Keys){if($seen[$pin] -ne $pins[$pin]){HM-Fail ('required fixed include mismatch '+$pin)}}
        if($Report.shaderReports){foreach($inc in $Report.shaderReports[0].includes){$key=$inc.file.Replace('\','/');if($seen[$key] -ne $inc.sha256){HM-Fail 'material/core include identity mismatch.'}}}
    }
    if($name -eq 'HardwareMaterials'){
        $x=$r.extractedTypes;$source='Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl'
        if($x.source -ne $source -or !(HM-SamePath $x.path (Join-Path $base 'includes/HardwareTraceTypes.hlsl'))){HM-Fail 'extracted hardware types identity mismatch.'}
        HM-Sequence $x.types @('HLGIHardwareInstance','HLGITriangleNormals') 'extracted hardware types';HM-File $x.path $x.sha256
        $trace=[IO.File]::ReadAllText((Join-Path $SourceRoot $source));$expected=''
        foreach($type in $x.types){$matches=[regex]::Matches($trace,'(?s)struct\s+'+[regex]::Escape($type)+'\s*\{.*?\};');if($matches.Count -ne 1){HM-Fail 'hardware source type missing/duplicate.'};$expected+=$matches[0].Value+"`n"}
        if([IO.File]::ReadAllText($x.path) -cne $expected){HM-Fail 'extracted hardware types are not exact source bodies.'}
    }
    if($name -eq 'RadianceValidity'){
        $transport=[IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl'))
        $kernels=[IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'))
        $hardware=[IO.File]::ReadAllText((Join-Path $SourceRoot 'Runtime/Resources/HybridLumenGI/HybridLumenGIExactMesh.hlsl'))
        $functions=@((HM-ExtractFunction $hardware '^void HLGIHardwareResolveCommittedMaterial\('),
            (HM-ExtractFunction $transport '^HLGIRayFootprint HLGIPointQueryFootprint\('),
            (HM-ExtractFunction $transport '^bool TraceShadow\([^\r\n]*useRenderingLayers,\r?\n'),
            (HM-ExtractFunction $transport '^bool TraceShadow\([^\r\n]*out bool known\)'),
            (HM-ExtractFunction $transport '^bool TraceShadow\([^\r\n]*bool useRenderingLayers\)'),
            (HM-ExtractFunction $transport '^bool HLGIHitOwnerCurrent\('),
            (HM-ExtractFunction $transport '^float3 DirectIrradiance\([^\r\n]*bool receivesShadows,\r?\n'),
            (HM-ExtractFunction $transport '^float3 DirectIrradiance\([^\r\n]*bool receivesShadows,out bool known\)'),
            (HM-ExtractFunction $transport '^float3 DirectIrradiance\(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers,out bool known\)'),
            (HM-ExtractFunction $transport '^float3 DirectIrradiance\(float3 p,float3 n,float3 biasNormal,uint2 receiverLayers\)'),
            (HM-ExtractFunction $transport '^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,[^\r\n]*float emissionWeight,'),
            (HM-ExtractFunction $transport '^float3 ProxyRadiance\(HLGIHit hit,float3 incomingDirection,HLGIRayFootprint hitFootprint,out float confidence\)'),
            (HM-ExtractFunction $transport '^float3 ProxyRadiance\(HLGIHit hit,out float confidence\)'),
            (HM-ExtractFunction $kernels '^bool TraceScreen\('))
        if([IO.File]::ReadAllText($files['ActualTransportFunctions.hlsl'].path) -cne ($functions -join ([Environment]::NewLine+[Environment]::NewLine))){HM-Fail 'extracted transport functions are not exact source bodies.'}
    }
    if($name -eq 'RayQueryPropagation'){
        $source='Runtime/Resources/HybridLumenGI/HybridLumenGITransport.hlsl';$x=$r.extractedFunction
        $extracted=$files['snapshot/Runtime/Resources/HybridLumenGI/ActualTraceSceneQuery.hlsl'].path
        if($x.name -ne 'TraceSceneQuery' -or !(HM-SamePath $x.path $extracted) -or
            !(HM-SamePath $x.transportSnapshot (Join-Path $base ('snapshot/'+$source))) -or
            $x.transportSnapshotSha256 -ne $SourceHashes[$source]){HM-Fail 'extracted ray query identity mismatch.'}
        HM-File $x.path $x.sha256;HM-File $x.transportSnapshot $x.transportSnapshotSha256
        $query=HM-ExtractFunction ([IO.File]::ReadAllText((Join-Path $SourceRoot $source))) '^bool TraceSceneQuery\('
        if($query -notmatch 'HLGIRayFootprint footprint,float4 materialView,out HLGIHit result' -or
            [IO.File]::ReadAllText($extracted) -cne $query){HM-Fail 'extracted ray query is not the exact primary source body.'}
    }
}
Write-Output ('PASS: '+$Stages.Count+' actual material-chain report(s), '+$totalDxc+' DXC entries, '+$totalFiles+' actual binary/input/output artifacts; sources and execution links verified. No shader rerun or Unity/physical-GPU acceptance.')
