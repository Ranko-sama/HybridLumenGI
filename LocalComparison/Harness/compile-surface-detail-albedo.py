"""Compile changed Surface variants and the two staged capture-read kernels only."""
import json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];S=ROOT/'Runtime/Resources/HybridLumenGI'
PACKAGE=ROOT/'LocalComparison/Review/surface-detail-albedo-01';OUT=PACKAGE/'compile';OUT.mkdir(exist_ok=False)
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe');rows=[]
def compile(name,source,entry,stage,profile,defines=[]):
    args=[str(DXC),'-HV','2018','-T',profile,'-E',entry,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_'+stage+'=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',str(INC/'Adapters'),'-I',str(INC),'-I',str(S),'-Fo',str(OUT/(name+'.dxil'))]
    for d in defines:args+=['-D',d+'=1']
    args+=[str(source)];r=subprocess.run(args,capture_output=True,text=True)
    (OUT/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8');rows.append(dict(name=name,exitCode=r.returncode,arguments=args))
code=re.search(r'HLSLPROGRAM(.*?)ENDHLSL',(S/'HybridLumenGISurface.shader').read_text(),re.S)[1]
source=OUT/'Surface.hlsl';source.write_text(code,encoding='utf-8')
compile('Surface-vertex',source,'Vert','VERTEX','vs_6_0')
for name,defines in [('off',[]),('mulx2',['_DETAIL_MULX2']),('scaled',['_DETAIL_SCALED'])]:compile('Surface-'+name,source,'Frag','FRAGMENT','ps_6_0',defines)
staged=PACKAGE/'instrumentation/prepared/Assets/HybridLumenGI/Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl'
for name,file,profile in [('software','HybridLumenGI.compute','cs_6_0'),('hardware','HybridLumenGIHardware.compute','cs_6_5')]:
    text=(S/file).read_text().replace('"HybridLumenGIKernels.hlsl"','"'+staged.as_posix()+'"');path=OUT/file;path.write_text(text,encoding='utf-8');compile(name,path,'CSTrace','COMPUTE',profile)
report={'passed':all(r['exitCode']==0 for r in rows),'scope':'Source variants and staged read-only kernel binding only; engine keyword transfer awaits Player','checks':rows}
(OUT/'analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps({r['name']:r['exitCode'] for r in rows}));raise SystemExit(0 if report['passed'] else 1)
