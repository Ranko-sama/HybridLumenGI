"""One paired actual-body software-WARP run; no Unity or product mutation."""
import difflib, hashlib, json, re, shutil, struct, subprocess
from pathlib import Path

P=Path(__file__).resolve().parent; ROOT=P.parents[2]
OLD=P.parent/'temporal-reactive-history-limit-01'
GPU=ROOT/'Runtime/Resources/HybridLumenGI'
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,value):path.write_text(json.dumps(value,indent=2),encoding='utf-8')
def function(source,name):
    match=re.search(r'^(?:float[234]?|bool|void) '+name+r'\(',source,re.M);assert match
    begin=source.index('{',match.start());end=begin+1;depth=1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    return source[match.start():end]
def actual(source):
    begin=source.index('bool HLGITemporalTapMatches(');end=source.index('[numthreads(8,8,1)]\nvoid CSFilter(')
    body=source[begin:end].replace('[numthreads(8,8,1)]\n','')
    body=body.replace('_HLGI_Output[pixel]','adapterOutput').replace('_HLGI_MomentsOut[pixel]','adapterMoments')
    return '\n\n'.join(function(source,n) for n in ['WorldPosition','ProjectUV','LuminanceGI'])+'\n'+body

def main():
    out=P/'execution';assert not out.exists(),'Preserve the first execution';out.mkdir()
    source=GPU/'HybridLumenGIKernels.hlsl';before=sha(source);text=source.read_text()
    marker='    // Reconstruction may improve an already accepted known measurement only.'
    assert text.count(marker)==1
    addition=('    // A changed global light set makes old radiance obsolete. Unknown current\n'
              '    // measurements have already retained their qualified history above.\n'
              '    if(_HLGI_GlobalReactive>0.5) valid=false;\n')
    candidate=text.replace(marker,addition+marker)
    (P/'candidate.patch').write_text(''.join(difflib.unified_diff(text.splitlines(True),candidate.splitlines(True),
        fromfile='a/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl',tofile='b/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl')))
    cases=[
      dict(name='global-known-black',globalChange=1,reactive=1,current=0,known=True),
      dict(name='global-known-nonzero',globalChange=1,reactive=1,current=1.03125,known=True),
      dict(name='global-unknown',globalChange=1,reactive=1,current=0,known=False),
      dict(name='static-known',globalChange=0,reactive=0,current=1.03125,known=True),
      dict(name='local-motion-reactive-known',globalChange=0,reactive=1,current=1.03125,known=True),
      dict(name='static-known-black',globalChange=0,reactive=0,current=0,known=True)]
    adapter=(OLD/'TemporalReactionAdapters.hlsl').read_text()
    adapter=adapter.replace('static float2 activeChange;','static float2 activeChange;\nstatic float _HLGI_GlobalReactive;')
    adapter=adapter.replace('    activeChange=float2(input.control.y,input.control.x);','    activeChange=float2(input.control.y,input.control.x);\n    _HLGI_GlobalReactive=input.reserved0.x;')
    adapter=adapter.replace('activeChange=0;_HLGI_HistoryValid=1;','activeChange=0;_HLGI_GlobalReactive=0;_HLGI_HistoryValid=1;')
    (out/'Adapters.hlsl').write_text(adapter)
    for name in ['HybridLumenGIRadianceValidity.hlsl','HybridLumenGIScreenSampling.hlsl','HybridLumenGIReceiverTemporal.hlsl']:
        shutil.copyfile(GPU/name,out/name)
    for label,body in [('baseline',text),('candidate',candidate)]:
        (out/label).mkdir();(out/label/'HybridLumenGIKernels.hlsl').write_text(body)
        (out/label/'ActualTemporalBody.hlsl').write_text(actual(body))
    inputs=bytearray(struct.pack('<I',len(cases)))
    for case in cases:
        current=[case['current']]*3+[1 if case['known'] else -1]
        recovery=[case['current'] if case['known'] else 1.03125]*3+[1]
        values=[1,1,1,1,1,1,32,0]+current+recovery+[case['reactive'],0,1,32]+[case['globalChange']]+[0]*23
        assert len(values)==44;inputs.extend(struct.pack('<44f',*values))
    (out/'inputs.bin').write_bytes(inputs)
    host=json.loads((OLD/'host-reuse.json').read_text());exe=Path(host['files']['exe']['path'])
    assert sha(exe).lower()==host['files']['exe']['sha256'].lower()
    compiler=Path(r'C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
    report=dict(status='running',scope='Extracted actual CSTemporal legacy/identity; fixed resource/geometry/half conversion adapters, D3D12 software WARP. Not Unity texture binding, full scene or physical GPU proof.',cases=cases,
        expectation='Only global known rows change: exact current RGB/confidence and age1. Unknown/static/local-reactive rows and their dependent recovery outputs must remain byte-identical. Both preprocessor entries must agree.',
        productSourceSha256=before,hostSha256=sha(exe),commands=[],observations=[])
    dump(P/'pre-execution-contract.json',report)
    def run(label,command):
        result=subprocess.run([str(v) for v in command],capture_output=True)
        (out/(label+'.log')).write_bytes(result.stdout+result.stderr)
        report['commands'].append(dict(label=label,command=[str(v) for v in command],exitCode=result.returncode))
        assert result.returncode==0,label
    try:
        for label in ['baseline','candidate']:
            for mode in ['legacy','identity']:
                name=label+'-'+mode;binary=out/(name+'.dxil')
                cmd=[compiler,'-HV','2018','-T','cs_6_0','-E','CSTemporalReactionTest','-I',out,'-I',out/label,'-Fo',binary,'-Fc',out/(name+'.ll')]
                if mode=='identity':cmd+=['-D','HLGI_RECEIVER_IDENTITY=1']
                run('compile-'+name,cmd+[out/'Adapters.hlsl'])
        for label in ['baseline','candidate']:
            for mode in ['legacy','identity']:
                name=label+'-'+mode;run('warp-'+name,[exe,out/(name+'.dxil'),out/'inputs.bin',out/(name+'.bin')])
        for mode in ['legacy','identity']:
            old=(out/('baseline-'+mode+'.bin')).read_bytes();new=(out/('candidate-'+mode+'.bin')).read_bytes()
            assert len(old)==len(new)==len(cases)*64
            for i,case in enumerate(cases):
                a=old[i*64:(i+1)*64];b=new[i*64:(i+1)*64];av=struct.unpack('<16f',a);bv=struct.unpack('<16f',b)
                report['observations'].append(dict(name=case['name'],mode=mode,baseline=av,candidate=bv,byteIdentical=a==b))
                if i<2:
                    assert bv[:4]==tuple([case['current']]*3+[1]) and bv[6]==1
                    assert bv[8:12]==tuple([case['current']]*3+[1]) and bv[14]==2
                    assert av[6]==2 and av[0]!=bv[0]
                    if i==0:assert .0199<av[0]<.0201 and av[8]>0
                    if i==1:assert av[0]==1.015625
                else:assert a==b,case['name']
        for label in ['baseline','candidate']:assert (out/(label+'-legacy.bin')).read_bytes()==(out/(label+'-identity.bin')).read_bytes()
        assert sha(source)==before,'Product source changed'
        report['status']='passed'
    except Exception as error:
        report['status']='failed';report['error']=repr(error);raise
    finally:
        report['artifacts']={str(p.relative_to(P)):sha(p) for p in out.rglob('*') if p.is_file() and p.suffix not in ['.dxil','.ll']}
        dump(P/'result.json',report)
        print(json.dumps(dict(status=report['status'],result=str(P/'result.json'))))
if __name__=='__main__':main()
