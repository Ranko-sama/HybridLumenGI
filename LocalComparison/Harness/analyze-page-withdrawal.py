"""Associate frozen inputs and original native-operation receipts; never drives Unity."""
import argparse,importlib.util,json,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'LocalComparison/Harness';PROJECT=Path('I:/Unity test/Project')
PACKAGE=ROOT/'LocalComparison/Review/asset-page-inflight-withdrawal-01';BUILD=Path('I:/Unity test/Comparison/Builds/PageWithdrawal27')
spec=importlib.util.spec_from_file_location('base',H/'analyze-player-smoke.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.PACKAGE=PACKAGE;base.BUILD=BUILD;load=base.load;sha=base.sha;save=base.save;lines=base.lines
def build():
    report={'currentSourceBuildVerified':False,'fullProductionAccepted':False}
    try:
        result=load(PACKAGE/'build-report.json');exit=load(PACKAGE/'build-exit.json');m=load(PACKAGE/'instrumentation/manifest.json')
        restore=load(PACKAGE/'instrumentation/restoration.json');report['nativeLogHits']=base.hits(PACKAGE/'build-unity.log')
        assert exit['exitCode']==0 and result['result']=='Succeeded' and result['errors']==0 and not report['nativeLogHits'],'Build/native failure'
        assert restore['currentProductRestored'] and all(x['restored'] for x in restore['files'])
        assert all(sha(ROOT/p)==v and sha(PROJECT/'Assets/HybridLumenGI'/p)==v for p,v in m['productSourceSha256'].items())
        expected={'Assets/HybridLumenGI/'+p:v for p,v in m['productSourceSha256'].items()};expected.update({f['path']:f['sha256'] for f in m['files']})
        actual={x['path']:x['sha256'] for x in result['inputs']};assert all(actual.get(p)==v for p,v in expected.items())
        frozen=load(PACKAGE/'input.json')
        assert all(actual.get(f['path'])==f['sha256'] and sha(PACKAGE/f['archive'])==f['sha256'] for f in frozen['files'])
        assert load(PACKAGE/'build-crc.json')['sixFrozenBundleCrcsVerified']
        assert result['scene']=='Assets/RuntimeAudit/Streaming.unity' and result['unity']=='6000.0.85f1'
        assert not (PACKAGE/'build-products.json').exists(),'Build inventory already frozen'
        files=[{'path':p.relative_to(BUILD).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(BUILD.rglob('*')) if p.is_file()]
        assert any(x['path'].endswith('/Managed/Assembly-CSharp.dll') for x in files)
        for p in frozen['pages']:
            path=BUILD/'HybridLumenGITest_Data/StreamingAssets'/frozen['relativeRoot']/p['bundlePath'];assert sha(path)==p['sha256']
        save(PACKAGE/'build-products.json',{'root':str(BUILD),'files':files})
        report.update(currentSourceBuildVerified=True,productSourceCount=len(m['productSourceSha256']),stagedFiles=len(m['files']),sourceCommit=m['baseline'],productFileCount=len(files),warnings=result['warnings'])
    except Exception as ex:report.update(failure=str(ex),traceback=traceback.format_exc())
    save(PACKAGE/'build-analysis.json',report);print(json.dumps(report));return report['currentSourceBuildVerified']
def run():
    native=PACKAGE/'native-window';report={k:False for k in ['inputClosureVerified','pendingWithdrawalCovered','nativeOperationRetained','lateCompletionHandled',
        'dependencyReleaseOrdered','pageReservationsReturned','nativeExitAccepted','fullProductionAccepted','productCounterexample']};report['coverageGaps']=[]
    try:
        report['productsSha256']=base.verify_products();frozen=load(PACKAGE/'input.json');defs={p['id']:p for p in frozen['pages']}
        folders=list((native/'run').glob('*/result.json'));assert len(folders)==1;folder=folders[0].parent;result=load(folders[0]);report['result']=result
        runtime=load(folder/'input.json');assert runtime['groupIds']==frozen['groupIds'] and runtime['pages']==frozen['pages'] and runtime['budgets']==frozen['budgets']
        report['inputClosureVerified']=True
        rows=lines(folder/'events.jsonl');assert [r['sequence'] for r in rows]==list(range(1,len(rows)+1))
        steps=[r for r in rows if r['stage']=='step-after'];assert [r['tick'] for r in steps]==list(range(1,len(steps)+1)) and len(steps)<=256
        before=[r for r in rows if r['stage']=='step-before'];assert len(before)==len(steps)
        assert all(a['tick']==b['tick'] and a['engine']==b['engine'] and a['sequence']<b['sequence'] for a,b in zip(before,steps))
        endpoints={stage:[r for r in rows if r['stage']==stage] for stage in ['initialized','request-accepted','closing']}
        assert all(len(v)==1 for v in endpoints.values()),'Missing/duplicate lifecycle endpoint receipt'
        assert endpoints['initialized'][0]['sequence']<endpoints['request-accepted'][0]['sequence']<before[0]['sequence']
        assert endpoints['closing'][0]['tick']==result['ticks']==steps[-1]['tick']
        assert endpoints['closing'][0]['sequence']>steps[-1]['sequence']
        assert all(r['engine']>=rows[i-1]['engine'] for i,r in enumerate(rows) if i)
        assert result['requestCalls']==result['withdrawCalls']==1 and result['ticks']<=256
        snapshots=[r for r in rows if r.get('pages')];budget=frozen['budgets'];edges=set()
        for r in snapshots:
            pages={p['id']:p for p in r['pages']};assert set(pages)==set(defs)
            assert all(p['refs']==p['pins']==0 and not p['error'] for p in pages.values())
            assert all(p['phase'] not in ['Failed','ReleaseFailed'] for p in pages.values())
            assert r['bundleBytes']==sum(defs[p['id']]['fileBytes'] for p in pages.values() if p['bundleReserved'])
            assert r['residentBytes']==sum(defs[p['id']]['residentBytes'] for p in pages.values() if p['residentReserved'])
            assert r['ioBytes']==sum(defs[p['id']]['fileBytes'] for p in pages.values() if p['phase']=='LoadingBundle')
            assert 0<=r['bundleBytes']<=budget['maxBundleBytes'] and 0<=r['residentBytes']<=budget['maxResidentBytes']
            assert r['ioStarted']<=budget['ioBytesPerStep'] and r['uploadStarted']<=budget['uploadBytesPerStep'] and r['starts']<=1
            assert sum(p['operation']!=0 for p in pages.values())<=1 and r['retiring']==0
            for p in pages.values():
                if p['bundleReserved']:
                    for d in p['dependencies']:
                        if pages[d]['bundleReserved']:edges.add((p['id'],d))
        withdrawals=[r for r in rows if r['stage'] in ['pending-withdrawal','uncovered-withdrawal']];assert len(withdrawals)==1;withdrawal=withdrawals[0]
        assert withdrawal['tick']<=64 and withdrawal['tick']==result['withdrawTick']
        covered=withdrawal['stage']=='pending-withdrawal';assert covered==result['pendingWithdrawalCovered'];report['pendingWithdrawalCovered']=covered
        starts={r['operation']:r for r in rows if r['stage'] in ['bundle-start','asset-start','release-start']}
        completed={r['operation']:r for r in rows if r['stage']=='poll-result'}
        release_by_page={r['page']:r for r in rows if r['stage']=='release-start'}
        release_done={r['page']:r for r in rows if r['stage']=='poll-result' and r['state']['phase']=='Releasing' and r['done'] and not r['error']}
        for r in rows:
            if r['stage']=='poll-result':assert r['done'] and not r['error'] and r['operation'] in starts
            if r['stage']=='poll-after' and r['state']['phase']=='Unloaded' and r['state']['generation']>0:
                assert r['page'] in release_done and release_done[r['page']]['sequence']<r['sequence'],'Reservation returned without successful original release poll'
        if covered:
            checks=[r for r in rows if r['stage']=='native-asset-check-link' and r['sequence']<withdrawal['sequence']];check=checks[-1]
            assert not check['done'] and check['tick']==withdrawal['tick'] and check['engine']==withdrawal['engine']
            op=check['operation'];start=starts[op];assert start['stage']=='asset-start' and start['native']==check['native'] and start['page']==check['page']
            page=next(p for p in withdrawal['pages'] if p['id']==check['page']);assert page['operation']==op and page['phase']=='LoadingAsset' and page['residentReserved']
            done=completed[op];assert done['sequence']>withdrawal['sequence'] and done['assetId']>0
            assert done['state']['generation']==page['generation'] and done['state']['phase']=='LoadingAsset'
            for r in snapshots:
                if withdrawal['sequence']<=r['sequence']<done['sequence']:
                    p=next(p for p in r['pages'] if p['id']==check['page']);assert p['operation']==op and p['residentReserved'] and p['bundleReserved']
            release=release_by_page[check['page']];assert release['sequence']>done['sequence'];assert check['page'] in release_done
            report.update(nativeOperationRetained=True,lateCompletionHandled=True,pendingOperation={'page':check['page'],'operation':op,'native':check['native'],'generation':page['generation'],'withdrawTick':withdrawal['tick'],'completionTick':done['tick']})
        else:report['coverageGaps'].append('No genuine pending native asset request observed before64 ticks; cleanup-only withdrawal')
        if edges:
            for parent,dependency in edges:
                assert parent in release_done and dependency in release_by_page
                assert release_done[parent]['sequence']<release_by_page[dependency]['sequence'],'Dependency released before parent completion'
            report['dependencyReleaseOrdered']=True
        else:report['coverageGaps'].append('No actual reserved parent/dependency release edge; complete input closure is not executed dependency coverage')
        report['observedDependencyEdges']=sorted(edges);report['loadedPages']=[r['page'] for r in rows if r['stage']=='asset-start']
        for op,start in starts.items():
            if start['stage']!='release-start':continue
            poll=completed[op];native_polls=[r for r in rows if r['stage']=='unload-async-poll' and r['operation']==op and r['done']]
            assert native_polls and native_polls[-1]['sequence']<poll['sequence']
            asset=poll['state']['asset']
            if asset:
                loaded=[r for r in rows if r['stage']=='poll-result' and r['state']['phase']=='LoadingAsset' and r['assetId']==asset and r['page']==start['page']]
                unload_before=[r for r in rows if r['stage']=='unload-asset-before' and r['operation']==op]
                unload_returned=[r for r in rows if r['stage']=='unload-asset-returned' and r['operation']==op]
                assert len(loaded)==len(unload_before)==len(unload_returned)==1 and unload_before[0]['assetId']==asset
                assert loaded[0]['sequence']<start['sequence']<unload_before[0]['sequence']<unload_returned[0]['sequence']<poll['sequence']
        assert result['status'] in ['collected','uncovered'] and not result['error'] and result['zeroTicks']>=8
        assert all(all(p['phase']=='Unloaded' and p['operation']==0 and not p['bundleReserved'] and not p['residentReserved'] for p in r['pages']) for r in steps[-8:])
        report['pageReservationsReturned']=True
        report['nativeExit']=load(native/'native-exit.json');report['nativeLogHits']=base.hits(native/'player.log')
        assert report['nativeExit']['exitCode']==0 and not report['nativeExit']['watchdogTerminated'] and not report['nativeLogHits']
        report['nativeExitAccepted']=True;report['status']='bounded-evidence-collected' if covered else 'pending-window-uncovered'
    except Exception as ex:report.update(status='analysis-failed',failure=str(ex),traceback=traceback.format_exc())
    save(native/'analysis.json',report);print(json.dumps(report));return report.get('status')!='analysis-failed'
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['build','products','run']);args=parser.parse_args()
    if args.action=='products':print(base.verify_products());ok=True
    else:ok=globals()[args.action]()
    raise SystemExit(0 if ok else 1)
