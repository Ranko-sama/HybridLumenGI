"""Freeze current input functions and a geometry-only native input observer."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('single_bounce_input_extractor',HERE.parent/'ColorBounceRectangle/generate_sampler.py')
extractor=importlib.util.module_from_spec(spec);spec.loader.exec_module(extractor)


def struct_source(text,name):
    start=text.index('struct '+name)
    return text[start:text.index('};',start)+2]+'\n'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--compile',action='store_true');args=parser.parse_args()
    output=HERE/'generated'
    if output.exists(): assert not any(output.iterdir()), 'Existing generated evidence must not be overwritten'
    else: output.mkdir()
    names=['Transport','Kernels','SurfaceCache','Hit','ScreenSampling','Changes','EmissiveSampling']
    paths={name:ROOT/'Runtime/Resources/HybridLumenGI'/('HybridLumenGI'+name+'.hlsl') for name in names}
    texts={name:p.read_text(encoding='utf-8-sig') for name,p in paths.items()}
    functions=extractor.extract(texts['Transport'],['HLGIHash','Random','CosineHemisphere','HLGISampleDirection'])
    functions+=extractor.extract(texts['Kernels'],['ValidDepth','WorldPosition','NormalAt','HLGIScreenDepthDelta','HLGIScreenDepthDerivative','HLGITryScreenGeometricNormal'])
    functions+=extractor.extract(texts['SurfaceCache'],['HLGISurfaceAtlasRect','HLGIDecodeSurfaceGeometricNormal'])
    records=''.join(struct_source(texts['Transport'],name) for name in ('HLGIProxy','HLGICacheEntry'))
    records+=struct_source(texts['SurfaceCache'],'HLGISurfaceCard')+struct_source(texts['Changes'],'HLGIChangeRegion')
    (output/'ReferenceInputFunctions.hlsl').write_text(functions,encoding='utf8')
    (output/'ReferenceRecords.hlsl').write_text(records,encoding='utf8')
    for name in ('Hit','ScreenSampling'):(output/('Reference'+name+'.hlsl')).write_bytes(paths[name].read_bytes())
    (output/'CacheFeedbackFiniteInputs.compute').write_bytes((HERE/'native_sampler.template.compute').read_bytes())
    (output/'generator.executed.py.txt').write_bytes(Path(__file__).read_bytes())
    assert 'if(emissive<=0) return HLGISampleDirection(normal,guide,rng,weight);' in texts['EmissiveSampling']
    assert 'uint rng=HLGIHash((id.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0xA511E9B3u);' in texts['Transport']
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    manifest=dict(sourceSha256={p.relative_to(ROOT).as_posix():sha(p) for p in paths.values()},
                  generatedSha256={p.name:sha(p) for p in output.iterdir()},templateSha256=sha(HERE/'native_sampler.template.compute'),
                  readsProductHit=False,outputsRadianceOrPdfOrWeight=False,scope='Geometry/identity/history-count input observer; source emission alpha only, never emission/diffuse RGB',compile=[])
    if args.compile:
        dxc=Path('C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe')
        includes=Path(os.environ['TEMP'])/'HybridLumenGI-shader-validation'
        for kernel in ('CSReferenceMetadata','CSReferenceCacheInputs','CSReferenceAtlas','CSReferenceGatherInputs'):
            command=[str(dxc),'-HV','2018','-O3','-T','cs_6_0','-E',kernel,'-I',str(includes/'Adapters'),'-I',str(includes),'-I',str(output),
                     '-D','SHADER_API_D3D11=1','-D','SHADER_STAGE_COMPUTE=1','-D','UNITY_COMPILER_DXC=1','-D','UNITY_VERSION=600000',
                     '-Fo',str(output/(kernel+'.dxil')),str(output/'CacheFeedbackFiniteInputs.compute')]
            result=subprocess.run(command,capture_output=True,text=True)
            (output/(kernel+'.log')).write_text(result.stdout+result.stderr,encoding='utf8')
            manifest['compile'].append(dict(kernel=kernel,command=command,exitCode=result.returncode))
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    assert all(row['exitCode']==0 for row in manifest['compile']), 'First compile results retained'
    print(json.dumps(dict(output=str(output),compileEntries=len(manifest['compile']),nativeExecuted=False)))


if __name__=='__main__':main()
