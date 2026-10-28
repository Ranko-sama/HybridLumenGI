"""Compile only the two affected capture variants and their screen consumers."""
import hashlib,json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];S=ROOT/'Runtime/Resources/HybridLumenGI'
OUT=ROOT/'LocalComparison/Review/screen-receive-shadows-01/compile';OUT.mkdir(exist_ok=False)
INC=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
DXC=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
rows=[]
def compile(name,source,entry,stage,profile,defines=[]):
    args=[str(DXC),'-HV','2018','-T',profile,'-E',entry,'-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_'+stage+'=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000','-I',str(INC/'Adapters'),'-I',str(INC),'-I',str(S),'-Fo',str(OUT/(name+'.dxil'))]
    for d in defines:args+=['-D',d+'=1']
    args+=[str(source)];r=subprocess.run(args,capture_output=True,text=True)
    (OUT/(name+'.log')).write_text(r.stdout+r.stderr,encoding='utf-8');rows.append(dict(name=name,exitCode=r.returncode,arguments=args))
for name,vertex,fragment in [('Surface','Vert','Frag'),('NativeDiffuseCapture','LitPassVertex','HLGICaptureNativeDiffuse'),('Composite','Vert','Frag')]:
    src=S/('HybridLumenGI'+name+'.shader');text=src.read_text();code=re.search(r'HLSL(?:PROGRAM|INCLUDE)(.*?)ENDHLSL',text,re.S)[1]
    tmp=OUT/(name+'.hlsl');tmp.write_text(code,encoding='utf-8')
    for off in ([False] if name=='Composite' else [False,True]):
        keywords=['_RECEIVE_SHADOWS_OFF'] if off else []
        for entry,stage,profile in [(vertex,'VERTEX','vs_6_0'),(fragment,'FRAGMENT','ps_6_0')]:compile(f'{name}-{off}-{stage}',tmp,entry,stage,profile,keywords)
for backend,file,profile in [('software','HybridLumenGI.compute','cs_6_0'),('hardware','HybridLumenGIHardware.compute','cs_6_5')]:compile(backend+'-CSTrace',S/file,'CSTrace','COMPUTE',profile)
result=dict(passed=all(r['exitCode']==0 for r in rows),checks=rows,scope='Affected On/Off capture variants and screen consumers only; Unity keyword selection still unproven.')
(OUT/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps({r['name']:r['exitCode'] for r in rows}));raise SystemExit(0 if result['passed'] else 1)
