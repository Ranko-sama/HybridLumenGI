"""Independent double-precision arithmetic/triangle oracle for saved actual gather events.
Does not launch Unity or change evidence. Identity comparisons are exact.
"""
import argparse,json,math,collections
from pathlib import Path
import numpy as np
SAMPLES=[0,1,3,7,15,31,63,95,119]
PIXELS=[(160,45),(100,90),(220,90),(100,30)]
def vec(v):return np.array([v[k] for k in ('x','y','z')],dtype=np.float64)
def mat(v):return np.array([[v[f'e{r}{c}'] for c in range(4)] for r in range(4)],dtype=np.float64)
def unit(v):return v/np.linalg.norm(v)
def decode_oct(v):
 n=np.array([v[0],v[1],1-abs(v[0])-abs(v[1])],dtype=np.float64)
 if n[2]<0:n[:2]=(1-np.abs(n[1::-1]))*np.where(n[:2]>=0,1,-1)
 return unit(n)
def offset(n,toward):return -n if np.dot(n,toward)<0 else n
class Oracle:
 def __init__(self,path):
  self.triangles=[];self.unsupported=[]
  for mesh in json.loads(path.read_text(encoding='utf-8'))['meshes']:
   m=mat(mesh['localToWorld']);normal=mat(mesh['normalToWorld'])[:3,:3]
   local=np.array([vec(v) for v in mesh['vertices']],dtype=np.float64)
   world=(m@np.column_stack((local,np.ones(len(local)))).T).T[:,:3]
   for sm in mesh['submeshes']:
    supported=(mesh['rendererType']=='MeshRenderer' and sm['topology']=='Triangles' and sm['shader']=='Universal Render Pipeline/Lit' and
      not sm['propertyBlock'] and not sm['alphaKeyword'] and sm['alphaClip']==0 and sm['surface']==0 and sm['cull'] in [0,1,2])
    if not supported:self.unsupported.append({'owner':mesh['name'],'material':sm['name'],'properties':sm})
    if sm['topology']!='Triangles':continue
    for primitive,inds in enumerate(np.array(sm['indices']).reshape(-1,3)):
     a,b,c=local[inds];ng=normal@np.cross(b-a,c-a)
     self.triangles.append((world[inds],ng,sm['cull'],supported,mesh['name'],sm['submesh'],primitive))
 def trace(self,o,d,max_t,min_t=.0001):
  hits=[];near_misses=[]
  for vertices,ng,cull,supported,owner,sub,prim in self.triangles:
   front=float(np.dot(ng,d))<0
   if supported and not(cull==0 or cull==1 and not front or cull==2 and front):continue
   a,b,c=vertices;e1=b-a;e2=c-a;p=np.cross(d,e2);det=float(np.dot(e1,p))
   if abs(det)<1e-14:continue
   q=o-a;u=float(np.dot(q,p))/det;cross=np.cross(q,e1);v=float(np.dot(d,cross))/det;t=float(np.dot(e2,cross))/det
   if u<0 or v<0 or u+v>1 or t<min_t or t>max_t:
    # A rejected hit can still sit within the predeclared edge/end tolerance.
    # In particular the recorded floor receiver may be a few float ULPs below
    # the wall's bottom edge. Never certify that miss as a robust physical gap.
    area=np.linalg.norm(np.cross(e1,e2))
    heights=np.array([area/max(np.linalg.norm(c-b),1e-30),area/max(np.linalg.norm(c-a),1e-30),area/max(np.linalg.norm(b-a),1e-30)])
    if np.all(np.array([1-u-v,u,v])*heights>=-2e-5) and min_t-2e-5<=t<=max_t+2e-5:
     near_misses.append({'t':t,'owner':owner,'submesh':sub,'primitive':prim,'reason':'rejected triangle within predeclared 2e-5 edge/end tolerance'})
    continue
   point=o+d*t
   edge=min(np.linalg.norm(np.cross(point-x,y-x))/max(np.linalg.norm(y-x),1e-30) for x,y in [(a,b),(b,c),(c,a)])
   ambiguous=edge<=2e-5 or min(abs(t-min_t),abs(t-max_t))<=2e-5
   hits.append({'t':t,'owner':owner,'submesh':sub,'primitive':prim,'supported':supported,'ambiguous':bool(ambiguous),'edgeDistance':float(edge)})
  hits.sort(key=lambda h:h['t'])
  if not hits:return {'blocked':False,'covered':not self.unsupported,'ambiguous':bool(near_misses),'nearMisses':near_misses}
  h=hits[0];near_misses=[m for m in near_misses if m['t']<=h['t']+2e-5]
  return {'blocked':True,'covered':h['supported'] and not self.unsupported,'ambiguous':h['ambiguous'] or bool(near_misses),'hit':h,'nearMisses':near_misses}

class Analysis:
 def __init__(self,directory,geometry):
  self.directory=directory;self.oracle=Oracle(geometry);self.fail=[];self.ambiguous=[];self.coverage=collections.Counter();self.connections=[];self.pixels=[];self.max_error=collections.defaultdict(float)
 def check(self,yes,label,**detail):
  if not yes:self.fail.append({'check':label,**detail})
 def near(self,a,b,label,**detail):
  a=np.asarray(a,dtype=np.float64);b=np.asarray(b,dtype=np.float64);error=np.abs(a-b)
  self.max_error[label]=max(self.max_error[label],float(np.max(error)))
  self.check(bool(np.all(np.isfinite(a)) and np.all(np.isfinite(b)) and np.all(error<=2e-6+5e-5*np.abs(b))),label,actual=a.tolist(),reference=b.tolist(),**detail)
 def exact(self,a,b,label,**detail):self.check(bool(np.array_equal(a,b)),label,actual=np.asarray(a).tolist(),reference=np.asarray(b).tolist(),**detail)
 def cache(self,events,cards,ranges,owners,where):
  start=events[0];p,ng,ns=start['f'][0,:3],start['f'][1,:3],start['f'][2,:3];bias=float(start['f'][0,3]);expected=start['f'][3];ids=start['u'][4]
  card,generation,owner,epoch=map(int,ids);result={'call':start['call'],'context':start['context'],'accepted':0,'irradiance':[0]*4,'returned':False}
  self.check(owner in owners,'cache owner exists',**where)
  if owner in owners:
   self.exact(expected[:2],[owners[owner]['stableId'],owners[owner]['revision']],'owner identity',**where)
   self.check(owners[owner]['published'],'cache owner published',**where)
  end=next((e for e in events if e['code']==120),None);self.check(end is not None,'cache terminal',**where)
  if end is None:return result
  returned=bool(end['u'][0,0]);result['returned']=returned
  uv_event=next((e for e in events if e['code']==101),None)
  if uv_event is None:
   self.coverage['card-uv-rejected']+=1;return result
  self.check(card<len(cards),'card bounds',**where)
  if card>=len(cards):return result
  card_f,card_u=cards[card];cm=card_f[:16].reshape(4,4,order='F');projection=cm@np.append(p,1)
  self.exact(card_u[24:28],[expected[0],expected[1],generation,1],'card identity/generation/ready',**where)
  self.exact(card_u[28],owner,'card owner',**where)
  self.exact(card_u[30],ranges[owner,2],'card layout generation',**where)
  uv,fraction=uv_event['f'][0,:2],uv_event['f'][0,2:];base=uv_event['f'][1,:2];grid=int(uv_event['f'][1,2])
  self.near(uv,projection[:2],'card projection',**where)
  patch=uv*grid-.5;self.exact(base,np.floor(patch),'cache base cell',**where);self.near(fraction,patch-np.floor(patch),'cache fraction',**where)
  weighted_i=np.zeros(4);weighted_g=np.zeros(4);total=0.;cursor=events.index(uv_event)+1
  for tap in range(4):
   part=[]
   while cursor<len(events):
    e=events[cursor];cursor+=1;part.append(e)
    if e['code']==114:break
   if not part or part[-1]['code']!=114:self.check(False,'missing tap rejection/acceptance',tap=tap,**where);break
   reason=int(part[-1]['u'][0,1]);self.exact(part[-1]['u'][0,0],tap,'tap order',**where);self.coverage['tap-reason-'+str(reason)]+=1
   cell=base+np.array([tap&1,tap>>1]);in_range=bool(np.all(cell>=0) and np.all(cell<grid))
   if not in_range:self.exact(reason,1,'tap out of range reason',**where);continue
   entry=next((e for e in part if e['code']==110),None);self.check(entry is not None,'tap entry exists',**where)
   if entry is None:continue
   irr,tag,anchor,normal,guide=entry['f'][:5];entry_ids=entry['u'][5]
   self.exact(entry_ids,[card*grid*grid+cell[1]*grid+cell[0],tap,*cell],'entry address',**where)
   identity=bool(np.array_equal(tag[:3],[expected[0],expected[1],epoch]));measurement=bool(np.all(np.isfinite(irr)) and irr[3]>0 and np.all(np.isfinite(guide)))
   if not identity or not measurement:self.exact(reason,2,'tag or measurement rejection',**where);continue
   if tag[3]!=generation:self.exact(reason,3,'generation rejection',**where);continue
   self.check(np.all(np.isfinite(np.concatenate((anchor,normal)))),'finite valid anchor/normal',**where)
   anchor_ng=decode_oct([anchor[3],normal[3]]);delta=p-anchor[:3]
   geom=next((e for e in part if e['code']==111),None)
   self.check(geom is not None,'tap geometry record',**where)
   if geom:self.near(geom['f'][1,:3],anchor_ng,'oct normal',**where);self.near(geom['f'][0,:3],delta,'anchor delta',**where)
   plane=abs(float(np.dot(delta,anchor_ng)));shade=float(np.dot(ns,normal[:3]));orient=float(np.dot(ng,anchor_ng));limit=max(bias*2,.03)
   boundary=min(abs(shade-.85),abs(orient-.85),abs(plane-limit))<=2e-6
   reject=shade<.85 or orient<.85 or plane>limit
   if boundary:self.ambiguous.append({'kind':'tap threshold','tap':tap,**where})
   if reject and not boundary:self.exact(reason,4,'normal/plane rejection',**where);continue
   if reason==4:continue
   vis=next((e for e in part if e['code']==112),None);self.check(vis is not None,'visibility inputs',**where)
   if vis is None:continue
   origin,target=vis['f'][0,:3],vis['f'][1,:3];separation=float(vis['f'][0,3]);queried=bool(vis['u'][2,1])
   self.near(origin,p+offset(ng,ns)*bias,'biased origin',**where);self.near(target,anchor[:3]+offset(anchor_ng,ns)*bias,'biased target',**where)
   self.near(separation,np.linalg.norm(target-origin),'connection length',**where)
   self.exact(queried,separation>.0002,'short-segment branch',**where)
   if queried:
    query=next((e for e in part if e['code']==116),None);hit=next((e for e in part if e['code']==113),None)
    self.check(query is not None and hit is not None,'query result presence',**where)
    if query is not None and hit is not None:
     direction=query['f'][0,:3];max_t=float(query['f'][0,3]);self.near(direction,(target-origin)/separation,'query direction',**where);self.near(max_t,separation-.0001,'query bound',**where)
     blocked=bool(hit['u'][0,0]);ref=self.oracle.trace(origin,direction,max_t)
     physical_delta=anchor[:3]-p;distance=float(np.linalg.norm(physical_delta));physical=self.oracle.trace(p,physical_delta/distance,distance-1e-8,1e-8) if distance>2e-8 else {'skipped':'zero physical length'}
     item={'frame':where['frame'],'lane':where['lane'],'call':result['call'],'tap':tap,'physicalOrigin':p.tolist(),'physicalTarget':anchor[:3].tolist(),'actualOrigin':origin.tolist(),'actualTarget':target.tolist(),'direction':direction.tolist(),'maxT':max_t,'gpuBlocked':blocked,'reference':ref,'physicalReference':physical}
     if blocked:
      slot=int(hit['u'][0,1]);item['gpuHit']={'ownerSlot':slot,'owner':owners.get(slot,{}).get('name'),'submesh':int(hit['u'][1,1]),'primitive':int(hit['u'][1,2]),'flags':int(hit['u'][2,1]),'t':float(hit['f'][3,3])}
     self.connections.append(item);self.coverage['visibility-queried']+=1
     if ref['covered'] and not ref['ambiguous']:
      self.exact(blocked,ref['blocked'],'ordinary visibility',**where)
      if blocked and ref['blocked']:
       self.check(item['gpuHit']['owner']==ref['hit']['owner'],'visibility owner',**where)
       actual_t=item['gpuHit']['t'];ref_t=ref['hit']['t'];self.check(abs(actual_t-ref_t)<=2e-5+2e-5*abs(ref_t),'visibility distance',actual=actual_t,reference=ref_t,**where)
      self.coverage['visibility-reference-covered']+=1
     else:self.coverage['visibility-reference-ambiguous' if ref['ambiguous'] else 'visibility-reference-uncovered']+=1
     self.exact(reason==5,blocked,'visibility rejection reason',**where)
   else:self.coverage['visibility-skipped-short']+=1
   if reason!=6:continue
   accepted=next((e for e in part if e['code']==115),None);self.check(accepted is not None,'accepted weight',**where)
   if accepted is None:continue
   weight=(fraction[0] if tap&1 else 1-fraction[0])*(fraction[1] if tap>>1 else 1-fraction[1]);total+=weight;weighted_i+=irr*weight;weighted_g+=guide*weight
   self.near(accepted['f'][0,:2],[weight,total],'tap weight/total',**where);self.near(accepted['f'][1],weighted_i,'tap weighted irradiance',**where);self.near(accepted['f'][2],weighted_g,'tap weighted guide',**where);result['accepted']+=1
  normalized=next((e for e in events if e['code']==121),None);self.check(normalized is not None,'cache result structure',**where)
  self.exact(returned,total>1e-5,'cache return boolean',**where)
  if returned:
   weighted_i/=total;weighted_g/=total
   if np.dot(weighted_g[:3],weighted_g[:3])>1e-6:weighted_g[:3]=unit(weighted_g[:3])
  if normalized:
   self.near(normalized['f'][0],weighted_i,'cache irradiance result',**where);self.near(normalized['f'][1],weighted_g,'cache guide result',**where);self.near(normalized['f'][2,0],total,'cache result total',**where)
   result['irradiance']=normalized['f'][0].tolist();result['guide']=normalized['f'][1].tolist()
  return result
 def run(self):
  for frame in SAMPLES:
   prefix=self.directory/f'gather-{frame:04d}';source=json.loads(Path(str(prefix)+'-sources.json').read_text(encoding='utf-8'));owners={o['slot']:o for o in source['owners']}
   raw=np.fromfile(str(prefix)+'-raw-selected.bin',dtype='<f4').reshape(4,4).astype(np.float64)
   data=Path(str(prefix)+'-events.bin').read_bytes();fu=np.frombuffer(data,dtype='<u4').reshape(4,256,32);ff=fu.view('<f4').astype(np.float64)
   cb=Path(str(prefix)+'-cards.bin').read_bytes();cu=np.frombuffer(cb,dtype='<u4').reshape(-1,32);cf=cu.view('<f4').astype(np.float64);cards=list(zip(cf,cu));ranges=np.fromfile(str(prefix)+'-ranges.bin',dtype='<u4').reshape(-1,4)
   for lane in range(4):
    where={'frame':frame,'lane':lane};header=fu[lane,0];count=int(header[1]);self.exact(header[:4],[0,count,1,0],'stream completed',**where);self.exact(header[4:8],[frame,source['giFrame'],lane,0x47434131],'stream provenance',**where)
    events=[{'code':int(fu[lane,i,0]),'context':int(fu[lane,i,2]),'call':int(fu[lane,i,3]),'u':fu[lane,i,4:].reshape(7,4),'f':ff[lane,i,4:].reshape(7,4)} for i in range(1,count)]
    self.exact(fu[lane,1:count,1],np.arange(1,count),'sequence',**where);self.check(events[-1]['code']==1,'terminal event',**where)
    terminal=events[-1]['f'][0];reason=int(events[-1]['u'][1,0]);classification='unknown' if reason==2 else 'no-receiver' if reason==0 else 'measured-black' if terminal[3]>0 and np.all(terminal[:3]==0) else 'valid' if terminal[3]>0 else 'no-measurement'
    self.coverage[classification]+=1
    half=terminal.astype(np.float16);ulp=np.abs(np.nextafter(half,np.float16(np.inf)).astype(np.float64)-half.astype(np.float64));self.check(np.all(np.abs(raw[lane]-terminal)<=ulp+1e-7),'raw half quantization',**where,actual=raw[lane].tolist(),reference=terminal.tolist())
    calls={}
    for index,event in enumerate(events):
     if event['code']!=100:continue
     end=next((j for j in range(index+1,len(events)) if events[j]['code']==120),len(events)-1)
     calls[event['call']]=self.cache(events[index:end+1],cards,ranges,owners,where)
    receiver=next((e for e in events if e['code']==10),None)
    item={**where,'pixel':PIXELS[lane],'classification':classification,'raw':raw[lane].tolist(),'cacheCalls':list(calls.values()),'consumedCalls':[]}
    if receiver:
     rays=int(receiver['f'][5,0]);feedback=receiver['f'][5,2];running=np.zeros(3);confidence=0.
     guide_calls=[call for call in calls.values() if call['context']==1]
     self.near(receiver['f'][4],guide_calls[-1].get('guide',[0,0,0,0]) if guide_calls else [0,0,0,0],'receiver guide consumption',**where)
     for ray in range(rays):
      part=[e for e in events if 100+ray*10<=e['context']<=102+ray*10];winner=next((e for e in part if e['code']==23),None);acc=next((e for e in part if e['code']==24),None);after=next((e for e in part if e['code']==25),None)
      if acc is None:continue
      incoming=acc['f'][0,:3];sample_conf=acc['f'][0,3];weight=float(acc['f'][1,3]);self.near(acc['f'][1,:3],running,'gather before accumulation',**where)
      world=next((e for e in part if e['code']==50),None);screen=next((e for e in part if e['code']==32 and e['context']==100+ray*10),None)
      if winner is not None:
       branch=int(winner['u'][0,0]);self.coverage['winner-'+str(branch)]+=1
       endpoint=None;coefficient=np.zeros(3)
       if branch==2 and world is not None:
        a,b,c,cache,value=world['f'][:5];expected=np.maximum(b[:3],0)*b[3]+np.clip(a[:3],0,.98)*(c[:3]+a[3]*c[3]*np.maximum(cache[:3],0));self.near(value[:3],expected,'world endpoint radiance',**where);self.near(incoming,value[:3],'world incoming',**where)
        endpoint=world;coefficient=np.clip(a[:3],0,.98)*a[3]*c[3]
       if branch==1:
        base=next((e for e in part if e['code']==30 and e['context']==100+ray*10),None)
        if base is not None and base['f'][5,3]>0:
         expected=base['f'][4,:3]+base['f'][3,:3]*base['f'][5,:3]
         if screen is not None:
          expected+=base['f'][3,:3]*screen['f'][0,3]*screen['f'][1,3]*screen['f'][0,:3];endpoint=screen;coefficient=base['f'][3,:3]*screen['f'][0,3]*screen['f'][1,3]
         self.near(incoming,expected,'screen endpoint radiance',**where)
       if endpoint is not None and endpoint['call'] in calls and calls[endpoint['call']]['context']==endpoint['context']:
        cached=calls[endpoint['call']];cache_value=np.asarray(cached['irradiance'])
        # CachedIrradiance returns zero on false, while ProxyRadiance consumes the actual structure.
        observed=world['f'][3] if branch==2 else screen['f'][0,:3]
        expected_cache=cache_value if branch==2 else np.maximum(cache_value[:3],0) if cached['returned'] else np.zeros(3)
        self.near(observed,expected_cache,'endpoint cached value',**where)
        consumed=classification in ['valid','measured-black'] and weight>0 and np.any(coefficient!=0) and cached['accepted']>0 and (branch==2 or cached['returned'])
        if consumed:item['consumedCalls'].append(endpoint['call']);self.coverage['final-radiance-cache-consumed']+=1
      if after is not None:
       self.check(receiver['f'][6,2]==0,'fixed radiance clamp disabled',**where)
       running+=incoming*weight;self.near(after['f'][0,:3],running,'direction accumulation',**where)
      area=next((e for e in part if e['code']==43),None);area_after=next((e for e in part if e['code']==46),None)
      if area is not None:
       self.near(area['f'][1,:3],running,'area before accumulation',**where)
       if any(e['code']==42 for e in part):self.exact(area['f'][0,:3],np.zeros(3),'area screen suppression',**where);self.coverage['area-screen-suppression']+=1
       if area_after is not None:running+=area['f'][0,:3];self.near(area_after['f'][0,:3],running,'area accumulation',**where)
      end=next((e for e in part if e['code']==26),None)
      if end is not None:confidence+=sample_conf;self.near(end['f'][0],np.append(running,confidence),'ray terminal sum',**where)
     if reason==1:self.near(terminal,np.append(running,confidence)/max(rays,1),'raw reconstruction',**where)
     if reason==2:self.exact(terminal,[0,0,0,-1],'unknown raw sentinel',**where)
    self.pixels.append(item)
  return {'passed':not self.fail and self.coverage['final-radiance-cache-consumed']>0,'failures':self.fail,'coverage':dict(self.coverage),'ambiguous':self.ambiguous,'maxAbsoluteErrors':dict(self.max_error),'unsupportedGeometry':self.oracle.unsupported,'pixels':self.pixels,'connections':self.connections,'scope':'Actual bounded A gather calls only; missing branches remain open. No full-image, performance, feedback-convergence or DXR acceptance.'}

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path);parser.add_argument('--geometry',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 result=Analysis(args.directory,args.geometry).run();args.output.write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps({k:result[k] for k in ['passed','coverage','failures']}));raise SystemExit(0 if result['passed'] else 1)
