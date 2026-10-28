"""Bounded source-attributed depth loads in optimized Gather DXIL (not GPU ISA)."""
import argparse,collections,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];PACKAGE=ROOT/'LocalComparison/Review/transport-hotspot-and-reuse-01'
p=argparse.ArgumentParser();p.add_argument('side',choices=['baseline','candidate']);args=p.parse_args();folder=PACKAGE/'compiler'/args.side
path=folder/'gather.asm';metadata={};loads=[];branches=[];labels={};block='';instructions=0
for number,line in enumerate(path.open(encoding='utf-8'),1):
    # Debug embedded source is a single enormous string. Never retain/print it.
    if len(line)>3000:continue
    m=re.match(r'!(\d+) = (.*)',line)
    if m:metadata[m[1]]=m[2].strip();continue
    m=re.match(r'([^ ;]+):',line)
    if m:block=m[1];labels[block]=number
    if re.match(r'  (?:%|br |ret |call )',line):instructions+=1
    m=re.search(r'!dbg !(\d+)',line)
    if m and '@dx.op.textureLoad.f32' in line and '%_HLGI_Depth_texture_2d' in line:loads.append((number,block,m[1]))
    if m and '!llvm.loop' in line and 'br i1 ' in line:branches.append((number,block,m[1],line.strip()))
def field(text,name):
    m=re.search(r'(?:^|[, (])'+name+r': !?(\d+)',text);return m[1] if m else None
def owner(identifier):
    for _ in range(30):
        value=metadata.get(identifier,'');m=re.search(r'!DISubprogram\(name: "([^"]+)"',value)
        if m:return m[1]
        identifier=field(value,'scope')
        if identifier is None:return '?'
    raise AssertionError('scope cycle')
def chain(identifier):
    result=[]
    while identifier:
        value=metadata[identifier];result.append({'function':owner(field(value,'scope')),'line':int(field(value,'line') or 0)})
        identifier=field(value,'inlinedAt')
    return result
source=(folder/'source/HybridLumenGIKernels.hlsl').read_text().splitlines()
loopline=next(i for i,t in enumerate(source,1) if 'for(int r=0;r<_HLGI_Rays;r++)' in t)
edges=[(n,b,d,t) for n,b,d,t in branches if chain(d)==[{'function':'CSTrace','line':loopline}]]
assert len(edges)==1,edges
end,_,_,branch=edges[0];header=re.search(r'label %([^, ]+)',branch)[1];start=labels[header]
groups=collections.defaultdict(list)
for number,block,debug in loads:
    trace=chain(debug)
    if trace[0]['function']!='HLGIScreenDepthDelta':continue
    # World match and TraceScreen are separately retained, never mislabeled receiver reuse.
    key=json.dumps(trace);groups[key].append({'assemblyLine':number,'block':block,'insideRayLoop':start<=number<=end})
rows=[{'chain':json.loads(key),'loads':values} for key,values in groups.items()]
receiver=[r for r in rows if len(r['chain'])==3 and r['chain'][1]['function'] in ['HLGITryScreenRayFootprint','HLGIPrepareReceiverFootprint'] and r['chain'][-1]['function']=='CSTrace']
report={'side':args.side,'scope':'Optimized DXC with pinned Unity includes/RayQuery adapter; not Unity driver ISA or physical register allocation.',
        'assemblySha256':hashlib.sha256(path.read_bytes()).hexdigest(),'instructionLines':instructions,
        'rayLoop':{'sourceLine':loopline,'header':header,'headerAssemblyLine':start,'backedgeAssemblyLine':end,'backedge':branch},
        'receiverDepthLoads':sum(len(r['loads']) for r in receiver),'receiverDepthLoadsInsideLoop':sum(v['insideRayLoop'] for r in receiver for v in r['loads']),
        'receiverGroups':receiver,'allDepthDeltaGroups':rows,
        'registerImplication':'Candidate explicitly keeps 6 delta floats and validity across the ray loop; physical register/spill count unavailable from this DXIL. Actual same-instrumentation GPU comparison is decisive.'}
(folder/'inspection.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
print(json.dumps({k:v for k,v in report.items() if k not in ['allDepthDeltaGroups','receiverGroups']}))
assert report['receiverDepthLoadsInsideLoop']>0 if args.side=='baseline' else report['receiverDepthLoadsInsideLoop']==0
