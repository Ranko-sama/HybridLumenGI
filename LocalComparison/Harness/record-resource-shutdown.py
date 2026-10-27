"""Preserve the finite attribution control; no lifecycle mutation."""
import hashlib,json,re,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2];source=Path('I:/Unity test/Comparison/Evidence/resource-shutdown-01');out=root/'LocalComparison/Review/resource-shutdown-01';out.mkdir(exist_ok=True)
result={'baselineCommit':'4610cc2','scope':'Twelve-frame Functional scene control, existing direct EditorApplication.Exit path, attribution-only instrumentation. Not normal Play exit or resource fix validation.','runs':{}}
for label in ['on-before','off-before']:
    directory=source/label;runpath=next(directory.glob('*/run.json'));run=json.loads(runpath.read_text());assert run['renderedFrames']==12 and run['errors']==0 and run['status']=='incomplete-probe'
    dest=out/label;shutil.copytree(directory,dest,dirs_exist_ok=True)
    log=Path('I:/Unity test/Logs')/f'ResourceShutdown01-{label}.log';shutil.copy2(log,out/log.name);text=log.read_text(encoding='utf-8-sig');assert 'RESOURCE_TRACE_WRITE_FAILED' not in text
    rows=[json.loads(s) for s in (directory/'retirement-timeline.jsonl').read_text().splitlines()];finish=next(x for x in rows if x['stage']=='capture-finish-before-exit');index=rows.index(finish);tail=rows[index:];late=[x for x in tail if x['stage']=='enqueue'];groups=[]
    for s in text.split('Found ')[1:]:
        if 'leak(s) from callstack:' not in s[:80]:continue
        lines=s.splitlines();product=next((x for x in lines if 'HybridLumenGI.' in x),'unknown');groups.append({'count':int(lines[0].split()[0]),'firstProductFrame':product,'stack': '\n'.join(lines[:12])})
    diag=[json.loads(x) for x in finish['diagnostics'].splitlines() if x]
    if label=='on-before':assert any(x['exactSoftwareGeometry'] and x['softwareGeometryBytes']>0 for x in diag)
    result['runs'][label]={'run':run,'allocationStackGroups':groups,'nativeAllocationCount':sum(x['count'] for x in groups),'d3d12UnreleasedCount':text.count('[d3d12] Unreleased'),
      'finishPending':finish['pendingCount'],'finishOwned':finish['ownedCount'],'finishDiagnostics':diag,
      'lateEnqueues':[{'ticket':x['ticket'],'stage':x['phase'],'callback':x['callback'],'resources':x['resources'],'logicalBytes':x['logicalBytes'],'submitted':x['submitted']} for x in late],
      'postFinishSubmissionCount':sum(x['stage']=='submitted' for x in tail),'postFinishDestroyCount':sum(x['stage']=='destroy-returned' for x in tail),'lateOwnedBufferBytes':sum(x['logicalBytes'] for x in late)}
m=json.loads((out/'instrumentation/manifest.json').read_text());restored=[]
for label in ['retirement','feature','capture']:
    h=hashlib.sha256(Path(m[label]['path']).read_bytes()).hexdigest();assert h==m[label]['originalSha256'];restored.append({'file':m[label]['path'],'sha256':h})
result['restored']=restored
result['interpretation']='Allocation stacks attribute six backend attribute buffers and two software BVH buffers to late generic retirement; the two RayTexturePool arena allocations are a separate cache owner. No one-to-one attribution is inferred merely from equal allocation counts. The disabled feature still leaves a deformation snapshot late in the generic queue, despite no corresponding ten native buffer warnings.'
(out/'attribution.json').write_text(json.dumps(result,indent=2))
print(json.dumps({k:{f:v[f] for f in ['nativeAllocationCount','d3d12UnreleasedCount','finishPending','finishOwned','lateOwnedBufferBytes','postFinishSubmissionCount','postFinishDestroyCount']} for k,v in result['runs'].items()},indent=2))
