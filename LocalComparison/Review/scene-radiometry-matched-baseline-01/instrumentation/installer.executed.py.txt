"""Prepare, install once, and restore the finite prospective baseline. No Unity launch."""
import argparse, hashlib, json, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path('I:/Unity test/Project')
PACKAGE = ROOT / 'LocalComparison/Review/scene-radiometry-matched-baseline-01'
OUT = PACKAGE / 'instrumentation'
OLD = ROOT / 'LocalComparison/Review/scene-lightoff-chain-02'
HARNESS = ROOT / 'LocalComparison/Harness'
sha = lambda b: hashlib.sha256(b).hexdigest()


def replace(text, old, new):
    assert text.count(old) == 1, (old[:110], text.count(old))
    return text.replace(old, new)


def adapt_cache(text):
    text = text.replace('-sceneLightoffProbe', '-sceneRadiometryProbe')
    text = replace(text, 'public static readonly int[] Samples={119,120,121,123,127,135,151,239,359};',
                   'public static readonly int[] Samples=Enumerable.Range(104,16).ToArray();')
    text = text.replace('logical<360', 'logical<120').replace('frame<360', 'frame<120')
    text = replace(text, 'if(logical>119)for', 'if(logical>103)for')
    text = text.replace('pointRules[119]', 'pointRules[103]').replace('pointAliases[119]', 'pointAliases[103]')
    text = replace(text, 'if(logical>119&&(regionSources.Count!=0||snapshot.domains.globalGeometry!=0))',
                   'if(logical>103&&(regionSources.Count!=0||snapshot.domains.globalGeometry!=0))')
    text = replace(text, 'Json(directory,"lightoff-schedule-"+logical.ToString("D4")+".json",snapshot);', '''
        // Warmup stores selected identities and scheduling receipts, not the full candidate population.
        if(logical<104){snapshot.candidates=rows.Where(r=>patches.Any(p=>p.entry==r.entry)).ToArray();
            snapshot.owners=owners.Where(o=>patches.Any(p=>p.slot==o.slot)).ToArray();snapshot.cpuMask=new uint[0];
            snapshot.readyCards=new bool[0];snapshot.cardOwners=new int[0];snapshot.cardGenerations=new uint[0];}
        Json(directory,"lightoff-schedule-"+logical.ToString("D4")+".json",snapshot);''')
    text = replace(text, 'receipt.bytes=data.Length;File.WriteAllBytes(Path.Combine(directory,"lightoff-"+key+".bin"),data);', '''receipt.bytes=data.Length;
        if(receipt.stage=="cache-observed")RadiometryObservation.LightweightCache(directory,receipt.logicalFrame,receipt.giFrame,data);
        if(receipt.logicalFrame>=104||receipt.stage!="cache-observed")File.WriteAllBytes(Path.Combine(directory,"lightoff-"+key+".bin"),data);''')
    start = text.index('    public static void Gate119()')
    end = text.index('    public static void Finish(bool collected)', start)
    text = text[:start] + '''    public static void Gate(int frame)
    {
        // Called from normal Update after the target-camera receipt, never inside graph recording.
        AsyncGPUReadback.WaitAllRequests();
        if(pending!=0||errors!=0||!selections.TryGetValue(frame,out var selected)||!observedCache.TryGetValue(frame,out var bytes))throw new Exception("Radiometry gate incomplete at "+frame);
        if(pointAliases[frame].Any(alias=>alias<0)||selected.Length!=2||selected.Select(p=>p.entry).Distinct().Count()!=2)throw new Exception("Unique fixed patches missing");
        foreach(var p in selected){int offset=p.lane*320;
            if(!p.ready||!p.published||p.generation==0||!actualCache.TryGetValue(frame+"/"+p.lane,out var value))throw new Exception("Patch source coverage missing");
            Validate(frame,p.lane);
            if(F(bytes,offset+256)!=1||F(bytes,offset+264)!=1||F(bytes,offset+92)<=0)throw new Exception("Patch geometric/measurement coverage missing");
            if(F(value,16)!=p.stableId||F(value,20)!=p.revision||F(value,28)!=p.generation)throw new Exception("Patch identity mismatch");
        }
        GatherCacheTap.Gate(frame);RadiometryObservation.RequireReceivers(frame);
        SceneRadiometryExport.CheckSources(frame);
        if(frame==103)warmupPassed=true;
        if(frame==119){if(!warmupPassed)throw new Exception("Missing warmup gate");RadiometryObservation.Targets((string)Field(capture,"directory"),selected,bytes,workFrames[frame]);}
        Json((string)Field(capture,"directory"),"radiometry-gate-"+frame.ToString("D4")+".json",new Summary{warmupPassed=warmupPassed,passed=true,pending=pending,errors=errors,files=completed.Count});
    }
''' + text[end:]
    return text


def adapt_gather(text):
    # This archived version already reserves completion before binding and safely coordinates disposal.
    text = replace(text, 'static readonly int[] Samples={119,120,121,123,127,135,151,239,359};',
                   'static readonly int[] Samples=Enumerable.Range(103,17).ToArray();')
    text = replace(text, 'receipt.bytes=data.Length;File.WriteAllBytes(Path.Combine(directory,"gather-"+key+".bin"),data);',
                   'receipt.bytes=data.Length;if(receipt.logicalFrame>=104)File.WriteAllBytes(Path.Combine(directory,"gather-"+key+".bin"),data);')
    text = replace(text, '        }catch(Exception error){errors++;Debug.LogError(error);}finally{pending--;}});\n        var rawReceipt=',
                   '            RadiometryObservation.Receivers(directory,logical,giFrame,bytes);\n        }catch(Exception error){errors++;Debug.LogError(error);}finally{pending--;}});\n        if(logical==103)return; // gate stores receiver identity only\n        var rawReceipt=')
    text = replace(text, 'Samples.SelectMany(f=>new[]{"events","raw-selected","cards","ranges"}.Select(s=>f.ToString("D4")+"-"+s))',
                   'Samples.SelectMany(f=>(f==103?new[]{"events"}:new[]{"events","raw-selected","cards","ranges"}).Select(s=>f.ToString("D4")+"-"+s))')
    text = replace(text, '    public static void Finish(bool collected)', '''    public static void Gate(int frame)
    {
        if(pending!=0||errors!=0||!completed.Contains(frame.ToString("D4")+"-events"))throw new Exception("Gather gate incomplete");
        if(frame==119)foreach(int f in Samples)foreach(string stage in f==103?new[]{"events"}:new[]{"events","raw-selected","cards","ranges"})
            if(!completed.Contains(f.ToString("D4")+"-"+stage))throw new Exception("Missing window gather receipt");
    }
    public static void Finish(bool collected)''')
    return text


def adapt_capture(text):
    text = replace(text, '        appliedEngine = Time.frameCount;',
                   '        appliedEngine = Time.frameCount;\n        if(SceneLightoffTap.Enabled){SceneLightoffTap.Apply(this,logicalFrame,doorOrigin);return;}')
    text = replace(text, '        if (logicalFrame == totalFrames - 1) { Finish(true); return; }', '''
        if(SceneLightoffTap.Enabled&&(logicalFrame==103||logicalFrame==119)){
            try{SceneLightoffTap.Gate(logicalFrame);}catch(Exception e){Fail(e.ToString());Finish(false);return;}}
        if (logicalFrame == totalFrames - 1) { Finish(true); return; }''')
    text = replace(text, '    static bool CaptureAt(int n) => n % 30 == 0',
                   '    static bool CaptureAt(int n) => SceneLightoffTap.Enabled ? (n==104||n==119) : n % 30 == 0')
    text = replace(text, '            if (pending) { readback.WaitForCompletion();', '''
            try{SceneLightoffTap.Finish(collected);}catch(Exception e){Fail("Radiometry observer close: "+e);}
            try{GatherCacheTap.Finish(collected);}catch(Exception e){Fail("Gather observer close: "+e);}
            if (pending) { readback.WaitForCompletion();''')
    return text


def prepare():
    assert not (OUT/'installed.json').exists(), 'Unique prospective native installation already started'
    old = json.loads((OLD/'instrumentation/manifest.json').read_text(encoding='utf-8'))
    prepared = {}
    for rel, digest in old['productSourceSha256'].items():
        assert sha((ROOT/rel).read_bytes()) == digest and sha((PROJECT/'Assets/HybridLumenGI'/rel).read_bytes()) == digest, rel
    for key, info in old['files'].items():
        path=Path(info['path']);assert sha(path.read_bytes()) == info['originalSha256'], path
        if key=='capture':data=adapt_capture(path.read_text(encoding='utf-8')).encode('utf-8')
        else:
            data=(OLD/'instrumentation'/f'{key}.instrumented.txt').read_bytes()
            assert sha(data)==info['instrumentedSha256']
        prepared[path]=data
    for name in ['LightOffCacheWriter.hlsl','GatherTraceWriter.hlsl','SceneLightoffTap.cs','LightoffPatchMap.cs','GatherCacheTap.cs']:
        info=old['helpers'][name];data=(OLD/'instrumentation'/(name+'.executed.txt')).read_bytes();assert sha(data)==info['sha256']
        if name=='SceneLightoffTap.cs':data=adapt_cache(data.decode('utf-8')).encode('utf-8')
        if name=='GatherCacheTap.cs':data=adapt_gather(data.decode('utf-8')).encode('utf-8')
        prepared[Path(info['path'])]=data
    for name in ['SceneRadiometryExport.cs','RadiometryObservation.cs']:
        prepared[PROJECT/'Assets/ComparisonHarness'/name]=(HARNESS/name).read_bytes()
    actual=OLD/'run/executed-assets'
    # Same scene structure plus explicitly adopted current-only materials is a NEW baseline.
    for path in old['assets']:
        if path.endswith('Validation.unity') or path.endswith('EditorBuildSettings.asset'):continue
        destination='Assets/RadiometryBaseline/Static.unity' if path.endswith('Static.unity') else path
        prepared[PROJECT/destination]=(actual/path.replace('/','_')).read_bytes()
    current=ROOT/'LocalComparison/Review/scene-radiometry-reference-01/snapshot/current-only'
    for source in current.iterdir():prepared[PROJECT/'Assets/ComparisonScene/Run'/source.name]=source.read_bytes()
    # Track changed files AND their adjacent metadata. New files are removed, existing files restored exactly.
    for path in list(prepared):
        if str(path).endswith('.meta') or not str(path).replace('\\','/').startswith(str(PROJECT/'Assets').replace('\\','/')+'/'):continue
        meta=Path(str(path)+'.meta')
        if meta.exists() and meta not in prepared:prepared[meta]=meta.read_bytes()
    OUT.mkdir(parents=True,exist_ok=True)
    manifest={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':[],
              'historicalSourceClosure':False,'nativeAttemptLimit':1,'productSourceSha256':old['productSourceSha256'],
              'hlslReuse':'Exact archived bytes; previous successful compiler evidence is not rerun.'}
    for index,(path,data) in enumerate(sorted(prepared.items(),key=lambda row:str(row[0]))):
        rel=path.relative_to(PROJECT).as_posix();original=path.read_bytes() if path.exists() else None
        if original is not None:(OUT/f'{index}.original').write_bytes(original)
        executed=OUT/'prepared'/rel;executed.parent.mkdir(parents=True,exist_ok=True);executed.write_bytes(data)
        manifest['files'].append({'path':rel,'original':f'{index}.original' if original is not None else None,
                                 'originalSha256':sha(original) if original is not None else None,'sha256':sha(data),'prepared':'prepared/'+rel})
    # Metadata Unity may create for new helpers/folder/scene is preserved then removed on restoration.
    manifest['newMetadata']=[p for p in ['Assets/RadiometryBaseline.meta','Assets/RadiometryBaseline/Static.unity.meta',
        'Assets/ComparisonHarness/SceneRadiometryExport.cs.meta','Assets/ComparisonHarness/RadiometryObservation.cs.meta'] if not (PROJECT/p).exists()]
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'installer.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    print(json.dumps({'action':'prepare','files':len(prepared),'RuntimeEdited':False,'UnityStarted':False}))


def install():
    assert not (OUT/'installed.json').exists(), 'Installation/run may not be repeated'
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    for f in m['files']:
        p=PROJECT/f['path'];assert (sha(p.read_bytes()) if p.exists() else None)==f['originalSha256'], f['path']
        assert sha((OUT/f['prepared']).read_bytes())==f['sha256']
    (OUT/'installed.json').write_text(json.dumps({'nativeAttemptLimit':1,'installationStarted':True}),encoding='utf-8')
    for f in m['files']:
        p=PROJECT/f['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((OUT/f['prepared']).read_bytes())
    print('Unique prospective baseline installed; no Unity process launched by installer')


def restore():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'));receipt=[]
    for f in m['files']:
        p=(PROJECT/f['path']).resolve();assert p.is_relative_to(PROJECT.resolve())
        if p.exists():
            target=OUT/'post-run'/f['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(p.read_bytes())
        if f['original'] is None:
            if p.exists():p.unlink()
        else:p.write_bytes((OUT/f['original']).read_bytes())
        receipt.append({'path':f['path'],'restored':(sha(p.read_bytes()) if p.exists() else None)==f['originalSha256']})
    for rel in m['newMetadata']:
        p=(PROJECT/rel).resolve();assert p.is_relative_to(PROJECT.resolve())
        if p.exists():
            target=OUT/'post-run'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(p.read_bytes());p.unlink()
    folder=PROJECT/'Assets/RadiometryBaseline'
    if folder.exists() and not any(folder.iterdir()):folder.rmdir()
    (OUT/'restoration.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    assert all(r['restored'] for r in receipt);print('All modified deployed files restored byte-for-byte; generated metadata archived')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','install','restore']);args=p.parse_args()
    {'prepare':prepare,'install':install,'restore':restore}[args.action]()
