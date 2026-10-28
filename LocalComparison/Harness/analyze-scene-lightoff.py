"""Offline chain checks for the one fixed real-scene run. Never launches Unity.

Double arithmetic uses the contract's gamma32 bound; textures additionally have
their declared half-storage quantization. No scene brightness acceptance bound.
"""
import argparse,collections,json,math,struct
from pathlib import Path
import numpy as np

SAMPLES=[119,120,121,123,127,135,151,239,359]
GAMMA=32*2**-24/(1-32*2**-24)
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def lines(path):return [json.loads(s) for s in path.read_text(encoding='utf-8').splitlines()]
def vector(v):return [v[k] for k in 'xyzw']
def pack_light(v):return struct.pack('<16f4I',*[x for key in ['positionType','directionRange','color','spot'] for x in vector(v[key])],*[v[k] for k in ['cullingMask','renderingLayers','shadowRenderingLayers','flags']])
def identity(p):return tuple(p[k] for k in ['entry','card','slot','stableId','revision','generation','layout','chart'])

class Analysis:
 def __init__(self,directory):
  self.d=directory;self.fail=[];self.count=collections.Counter();self.cache=[];self.pixels=[];self.maxerr=collections.defaultdict(float)
 def check(self,ok,label,**where):
  if not ok:self.fail.append({'check':label,**where})
 def exact(self,a,b,label,**where):self.check(np.array_equal(a,b),label,**where)
 def near(self,a,b,label,scale=None,**where):
  a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float);scale=np.abs(a)+np.abs(b) if scale is None else np.asarray(scale)
  err=np.abs(a-b);self.maxerr[label]=max(self.maxerr[label],float(np.max(err)))
  self.check(np.all(np.isfinite(a)) and np.all(np.isfinite(b)) and np.all(err<=GAMMA*scale+2**-120),label,actual=a.tolist(),reference=b.tolist(),**where)
 def bin(self,frame,stage,dtype='<f4'):return np.fromfile(self.d/f'lightoff-{frame:04d}-{stage}.bin',dtype=dtype)
 def run(self):
  run=read(self.d/'run.json');frames=lines(self.d/'frames.jsonl');commands=lines(self.d/'lightoff-commands.jsonl')
  self.check(run['renderedFrames']==360 and run['errors']==0,'360 rendered without errors')
  self.exact([f['logicalFrame'] for f in frames],list(range(360)),'render sequence')
  self.exact([c['logicalFrame'] for c in commands],list(range(360)),'controller sequence')
  self.check(read(self.d/'lightoff-summary.json')['passed'],'cache observation complete')
  self.check(read(self.d/'gather-summary.json')['passed'],'gather observation complete')
  lights={(r['logicalFrame'],r['phase']):r for r in lines(self.d/'lightoff-lights.jsonl')}
  bindings={r['logicalFrame']:r for r in lines(self.d/'lightoff-bindings.jsonl')}
  self.check(len(lights)==1080 and len(bindings)==360,'unique phase/binding coverage')
  frame_map={f['logicalFrame']:f for f in frames};command_map={c['logicalFrame']:c for c in commands}
  previous={};fixed=None;fixed_aliases=None;segment=None;segment_start=None;queue_frames=0
  for frame in sorted(frame_map):
   where={'frame':frame};f=frame_map[frame]
   required=[(frame,phase) for phase in ['before-update','after-update','uploaded-domains']]
   if frame not in command_map or frame not in bindings or any(key not in lights for key in required) or not (self.d/f'lightoff-schedule-{frame:04d}.json').exists():
    self.check(False,'partial frame source coverage',**where);continue
   cmd=command_map[frame];s=read(self.d/f'lightoff-schedule-{frame:04d}.json');binding=bindings[frame]
   if any(not (self.d/f'lightoff-{frame:04d}-{stage}.bin').exists() for stage in ['gpu-mask','gpu-lights','gpu-changes','cache-observed']):
    self.check(False,'partial GPU source coverage',**where);continue
   diag=json.loads(f['diagnosticsJson']);self.check(diag['exactSoftwareGeometry'] and not diag['hardwareBackend'],'actual software backend',**where)
   self.exact(cmd['enabled'],frame<120,'real source enabled',**where)
   self.exact(cmd['cameraPosition'],commands[0]['cameraPosition'],'static camera',**where);self.exact(cmd['doorPosition'],commands[0]['doorPosition'],'static door',**where)
   self.exact(cmd['lampInstance'],commands[0]['lampInstance'],'same Light instance',**where)
   before=lights[frame,'before-update'];after=lights[frame,'after-update'];uploaded=lights[frame,'uploaded-domains'];expected_count=int(frame<120)
   self.exact(after['count'],expected_count,'effective CPU light count',**where);self.exact(uploaded['count'],expected_count,'uploaded CPU count',**where)
   self.exact(binding['lightCount'],expected_count,'actual shader light count',**where)
   self.exact([binding['giFrame'],binding['cacheRead'],binding['cacheWrite'],binding['gatherRead']],
    [s['giFrame'],s['readBuffer'],s['writeBuffer'],s['writeBuffer']],'work buffer provenance',**where)
   self.check(binding['distinct'] and binding['exact'] and binding['cacheWrite']==1-binding['cacheRead'],'Jacobi distinct',**where)
   gpu=(self.d/f'lightoff-{frame:04d}-gpu-lights.bin').read_bytes()
   self.check(gpu[:80*expected_count]==b''.join(pack_light(v) for v in after['records']),'effective CPU/GPU Light bytes',**where)
   if frame==120:
    self.exact(before['count'],1,'old source before removal',**where)
    self.check(len(after['changes'])==1 and pack_light(after['changes'][0])==pack_light(before['records'][0]),'removed old Light record',**where)
   elif frame>0:self.check(not after['changes'],'no other source event',**where)
   domain=uploaded['domains'];changes=self.bin(frame,'gpu-changes').reshape(-1,12)
   for i,r in enumerate(domain['regions']):self.exact(changes[i],np.array(vector(r['minimum'])+vector(r['maximum'])+vector(r['receiver']),dtype=np.float32),'uploaded change bytes',**where)
   if frame>=119:
    self.exact(domain['globalGeometry'],0,'no global geometry invalidation',**where)
    self.check(not s['regionSources'],'no unrelated geometry/surface region',**where)
   if frame==120:
    self.exact(domain['globalLighting'],0,'point source local domain',**where);self.exact(domain['count'],1,'single removal domain',**where)
    if domain['count']==1:
     self.exact(vector(domain['regions'][0]['minimum']),[3,-3,-3,0],'removed Light lower domain',**where)
     self.exact(vector(domain['regions'][0]['maximum']),[13,7,7,18],'removed Light upper domain',**where)
   elif frame>120:self.exact(domain['count'],0,'no repeated removal domain',**where)
   mask=self.bin(frame,'gpu-mask','<u4');self.exact(mask,s['cpuMask'],'actual scheduler mask',**where)
   rows=s['candidates'];N=s['valid'];b=s['effectiveBudget'];q=min(b,(b+3)//4)
   self.check(len(rows)==N and sum(s['cpuMask'])==s['selected']==b and s['fairness']==q,'hard budget/count/quota',**where)
   self.check(len({r['entry'] for r in rows})==N,'unique candidates',**where)
   oldest=sorted(rows,key=lambda r:(r['previousService'],r['entry']))[:q]
   self.check(all(r['selected']==1 for r in oldest),'oldest quota actually selected',**where)
   owner={o['slot']:o for o in s['owners']};candidate_ids=[]
   for r in rows:
    card=r['entry']//(s['patchGrid']**2);slot=s['cardOwners'][card];o=owner[slot]
    self.check(s['readyCards'][card] and o['active'] and o['layout']>0 and s['cardGenerations'][card]>0,'candidate ready identity',entry=r['entry'],**where)
    candidate_ids.append((r['entry'],slot,o['stableId'],o['revision'],o['layout'],s['cardGenerations'][card]))
    self.exact(r['newService'],s['tick'] if r['selected'] else r['previousService'],'service clock transition',entry=r['entry'],**where)
   signature=(tuple(sorted(candidate_ids)),b)
   if signature!=segment:segment=signature;segment_start=s['tick']
   if b<N:queue_frames+=1
   if q and s['tick']-segment_start>=math.ceil(N/q):self.check(s['maxAge']<=math.ceil(N/q),'stable identity service bound',**where)
   if frame==119:fixed=[identity(p) for p in s['patches']];fixed_aliases=s.get('aliases')
   if frame>=119:
    self.exact([identity(p) for p in s['patches']],fixed,'frozen patch identities',**where)
    self.exact(s.get('aliases'),fixed_aliases,'frozen point aliases',**where)
   records=self.bin(frame,'cache-observed').reshape(4,20,4).astype(float);uint=self.bin(frame,'cache-observed','<u4').reshape(4,20,4)
   next_previous={}
   for lane,p in enumerate(s['patches']):
    loc={**where,'lane':lane};v=records[lane];u=uint[lane];old=v[:5];new=v[5:10];prepared=v[10];change=v[12];estimate=v[13];status=v[16];params=v[17]
    if p['entry']<0:self.count['unmapped']+=1;continue
    header_valid=np.array_equal(u[18],[p['entry'],frame,s['giFrame'],0x4c4f3031])
    self.check(header_valid,'actual cache observation header',**loc)
    if not header_valid:self.count['missing-observer-record']+=1;continue
    if not (self.d/f'lightoff-{frame:04d}-cache-actual-{lane}.bin').exists():self.check(False,'actual patch readback missing',**loc);continue
    actual=self.bin(frame,'cache-actual-'+str(lane)).reshape(5,4).astype(float)
    self.exact(new,actual,'private/actual new cache bytes',**loc)
    self.exact(u[19,3],s['giFrame'],'product sampling frame',**loc);self.exact(params[0],expected_count,'cache product Light count',**loc)
    if identity(p) in previous:self.exact(old,previous[identity(p)],'next read is previous write',**loc)
    next_previous[identity(p)]=new
    if not status[0]:
     self.count['uncovered']+=1;self.exact(new,np.zeros((5,4)),'uncovered writes zero',**loc);continue
    self.exact(u[19,:3],[p['card'],p['generation'],p['slot']],'covered patch identity',**loc)
    self.exact(new[1],[p['stableId'],p['revision'],s['epoch'],p['generation']],'new tag',**loc)
    oldvalid=np.all(np.isfinite(old[[0,4]])) and old[0,3]>0
    retain=oldvalid and np.array_equal(old[1],new[1]) and change[0]<=.5
    expected_pre=old[0].copy() if retain else np.zeros(4)
    if change[1]>.5:expected_pre[3]=min(expected_pre[3],1)
    self.exact(prepared,expected_pre,'actual history preparation',**loc)
    self.exact(change[2],mask[p['entry']],'patch actual mask',**loc)
    self.exact(change[3],int(mask[p['entry']]!=0),'attempt reflects actual mask',**loc)
    if not change[3]:self.count['not-scheduled']+=1
    elif not estimate[3]:self.count['attempt-estimate-unknown']+=1
    if status[1]:
     self.check(bool(change[3] and estimate[3]),'commit requires known attempt',**loc)
     ray_count=params[3];expected_samples=min(prepared[3]+1,32);alpha=max(1/expected_samples,.1);e=estimate[:3]/ray_count
     expected=(1-alpha)*prepared[:3]+alpha*e if prepared[3]>0 else e
     self.near(new[0,:3],expected,'committed irradiance',scale=np.abs(prepared[:3])+np.abs(e),**loc)
     self.exact(new[0,3],expected_samples,'committed samples',**loc)
     guide=v[14,:3];norm2=float(np.dot(guide,guide));g=guide/math.sqrt(norm2) if norm2>1e-12 else new[3,:3]
     self.near(new[4,:3],g,'committed guide',**loc);self.near(new[4,3],v[14,3]/ray_count,'committed guide power',**loc)
     self.count['committed']+=1
    else:self.exact(new[0],prepared,'unsuccessful attempt retains prepared measurement',**loc)
    valid=bool(np.all(np.isfinite(new[[0,4]])) and new[0,3]>0);self.exact(status[2],int(valid),'actual measurement validity',**loc)
    if valid:self.count['valid-black' if np.all(new[0,:3]==0) else 'valid-nonblack']+=1
    if frame>=120 and v[15,3]>0:self.exact(v[15,:3],[0,0,0],'known direct terms after removal',**loc);self.count['off-known-direct-calls']+=int(v[15,3])
    self.cache.append({**loc,'entry':p['entry'],'covered':bool(status[0]),'scheduled':bool(change[3]),'known':bool(estimate[3]),'committed':bool(status[1]),'valid':valid,'old':old[0].tolist(),'prepared':prepared.tolist(),'estimateSum':estimate[:3].tolist(),'new':new[0].tolist(),'change':change[:2].tolist()})
   previous=next_previous
   if frame in SAMPLES:
    if (self.d/f'gather-{frame:04d}-events.bin').exists() and (self.d/f'frame-{frame:04d}.rgba32f').exists():self.gather(frame,s)
    else:self.check(False,'partial gather/image coverage',**where)
  return {'passed':not self.fail,'failures':self.fail,'coverage':dict(self.count),'queueFrames':queue_frames,'fairnessQueueCovered':queue_frames>0,
   'observedFrames':sorted(frame_map),'missingFrames':sorted(set(range(360))-set(frame_map)),
   'maxAbsoluteErrors':dict(self.maxerr),'cache':self.cache,'pixels':self.pixels,'scope':'One source-removal scene only. Effective sources require actual inventory; no assumed zero-equilibrium, performance, general convergence, DXR or full-plan acceptance.'}
 def gather(self,frame,s):
  data=np.fromfile(self.d/f'gather-{frame:04d}-events.bin',dtype='<u4').reshape(4,256,32);floats=data.view('<f4').astype(float)
  stages={stage:self.bin(frame,stage).reshape(4,4).astype(float) for stage in ['raw','history','filtered']}
  other=np.fromfile(self.d/f'gather-{frame:04d}-raw-selected.bin',dtype='<f4').reshape(4,4)
  self.exact(stages['raw'],other,'same raw source readbacks',frame=frame)
  final=np.fromfile(self.d/f'frame-{frame:04d}.rgba32f',dtype='<f4').reshape(360,640,4)
  self.check(np.all(np.isfinite(final)),'finite final HDR',frame=frame)
  for lane in range(4):
   where={'frame':frame,'lane':lane};header=data[lane,0];count=int(header[1]);self.check(2<=count<=256,'gather record count',**where)
   self.exact(header[:4],[0,count,1,0],'gather complete',**where);self.exact(header[4:8],[frame,s['giFrame'],lane,0x47434131],'gather provenance',**where)
   self.exact(data[lane,1:count,1],np.arange(1,count),'gather sequence',**where)
   events=[{'code':int(data[lane,i,0]),'context':int(data[lane,i,2]),'f':floats[lane,i,4:].reshape(7,4),'u':data[lane,i,4:].reshape(7,4)} for i in range(1,count)]
   terminal=events[-1]['f'][0];reason=int(events[-1]['u'][1,0]);self.exact(events[-1]['code'],1,'gather terminal',**where)
   half=terminal.astype(np.float16);ulp=np.abs(np.nextafter(half,np.float16(np.inf)).astype(float)-half.astype(float))
   self.check(np.all(np.abs(stages['raw'][lane]-terminal)<=ulp+2**-120),'raw half storage',**where)
   receiver=next((e for e in events if e['code']==10),None);running=np.zeros(3);confidence=0.
   if receiver:
    rays=int(receiver['f'][5,0])
    for ray in range(rays):
     part=[e for e in events if 100+ray*10<=e['context']<=102+ray*10]
     get=lambda code:next((e for e in part if e['code']==code),None)
     acc=get(24);after=get(25)
     if acc is None:continue
     self.near(acc['f'][1,:3],running,'gather prior sum',**where)
     if after is not None:
      term=acc['f'][0,:3]*acc['f'][1,3];expected=running+term;self.near(after['f'][0,:3],expected,'gather direction sum',scale=np.abs(running)+np.abs(term),**where);running=after['f'][0,:3]
     area=get(43);area_after=get(46)
     if area is not None:
      self.near(area['f'][1,:3],running,'gather area prior sum',**where)
      if area_after is not None:self.near(area_after['f'][0,:3],running+area['f'][0,:3],'gather area sum',**where);running=area_after['f'][0,:3];self.count['gather-area-add']+=1
     end=get(26)
     if end is not None:confidence+=acc['f'][0,3];self.near(end['f'][0],np.append(running,confidence),'gather ray sum',**where)
    if reason==1:self.near(terminal,np.append(running,confidence)/max(rays,1),'gather raw reconstruction',**where)
   if reason==2:self.exact(terminal,[0,0,0,-1],'unknown gather sentinel',**where)
   for e in events:
    if frame>=120 and e['code']==50:self.exact(e['f'][2,:3],[0,0,0],'gather world direct off',**where);self.count['gather-world-direct-off']+=1
    if frame>=120 and e['code']==30 and e['f'][5,3]>0:self.exact(e['f'][5,:3],[0,0,0],'gather screen direct off',**where);self.count['gather-screen-direct-off']+=1
    if e['code']==110:
     entry=int(e['u'][5,0]);p=next((p for p in s['patches'] if p['entry']==entry),None)
     if p is not None:self.exact(e['f'][:5],self.bin(frame,'cache-actual-'+str(p['lane'])).reshape(5,4),'gather reads actual written selected patch',**where);self.count['gather-selected-patch-byte-link']+=1
   for stage,v in stages.items():self.check(np.all(np.isfinite(v[lane])),'finite '+stage,**where)
   classification='unknown' if reason==2 else 'no-receiver' if reason==0 else 'measured-black' if terminal[3]>0 and np.all(terminal[:3]==0) else 'valid' if terminal[3]>0 else 'unmeasured'
   self.count['gather-'+classification]+=1
   self.pixels.append({**where,'classification':classification,**{stage:v[lane].tolist() for stage,v in stages.items()},'finalImageMeanRGB':final[:,:,:3].mean(axis=(0,1),dtype=float).tolist()})

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();analysis=Analysis(a.directory)
 try:result=analysis.run()
 except Exception as e:result={'passed':False,'exception':repr(e),'failures':analysis.fail,'coverage':dict(analysis.count),'cache':analysis.cache,'pixels':analysis.pixels}
 a.output.write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps({k:result.get(k) for k in ['passed','exception','coverage','queueFrames','failures']}));raise SystemExit(0 if result['passed'] else 1)
