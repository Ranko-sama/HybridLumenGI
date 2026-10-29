"""Separate qualification of warmup source generations; original code is frozen.

Only the two-line whole-source equality gate is adapted. The original sampler,
geometric model, temporal expectations, selection, coverage and result functions
are imported unchanged. Root owns the subsequent same-data analysis invocation.
"""
import argparse
import hashlib
import importlib.util
import inspect
import json
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
PACKAGE=HERE.parent
ROOT=HERE.parents[3]
ORIGINAL=PACKAGE/'qualification-ties'
ORIGINAL_ANALYZER_SHA='232adf8da40cbdb444891c42706e54aaae46c7c1ac34989ccdbe0cee016ebf3d'
ORIGINAL_MODEL_SHA='086977019baa6a0e8f475182f1b0486894f1a2bbb67b320974bb9e444d13a26b'
FIRST_FAIL_SHA='50fffff61d28f66ab1da8da1d72d773da378bacad78a990e220dc3f788feda0a'
ORIGINAL_GATE="        if frozen_sources is None:frozen_sources=r['sources']\n        require(r['sources']==frozen_sources,'Static geometry/material source changed')"
QUALIFIED_GATE="        frozen_sources=initialization_gate(frozen_sources,r['sources'],logical)"

def require(value,message):
    if not value:raise AssertionError(message)
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def physical_sources(sources):
    # Do not discard any physical, identity, material or future receipt field.
    # The only exempt pre-observation values are the two generation counters.
    return [{key:value for key,value in source.items() if key not in ('revision','geometryRevision')} for source in sources]

def initialization_gate(baseline,current,logical):
    require(0<=logical<48,'Frozen 48-frame sequence changed')
    if baseline is None:baseline=current
    require(physical_sources(current)==physical_sources(baseline),'Static physical source changed during warmup or observation')
    # The first observed temporal frame is31. Frame30 owns its f-1 history,
    # so bind full source metadata before the declared observation window.
    if logical==30:baseline=current
    if logical>=30:require(current==baseline,'Source metadata changed in the observation/predecessor window')
    return baseline

def original_module():
    require(sha(ORIGINAL/'analyze.py')==ORIGINAL_ANALYZER_SHA,'Original tie analyzer changed')
    require(sha(ORIGINAL/'model.py')==ORIGINAL_MODEL_SHA,'Original tie mathematical model changed')
    sys.path.insert(0,str(ORIGINAL))
    spec=importlib.util.spec_from_file_location('frozen_camera_ties_analysis',ORIGINAL/'analyze.py')
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    require(Path(module.m.__file__).resolve()==(ORIGINAL/'model.py').resolve(),'Unexpected imported mathematical model')
    return module

def adapted_analyze(original):
    source=inspect.getsource(original.analyze)
    require(source.count(ORIGINAL_GATE)==1,'Original source gate is not unique')
    adapted=source.replace(ORIGINAL_GATE,QUALIFIED_GATE)
    namespace=dict(vars(original),initialization_gate=initialization_gate)
    exec(compile(adapted,'<initialization-qualified original analyze>', 'exec'),namespace)
    return namespace['analyze'],dict(originalFunctionSha256=hashlib.sha256(source.encode()).hexdigest(),
                                     adaptedFunctionSha256=hashlib.sha256(adapted.encode()).hexdigest(),
                                     replacedOriginalLines=2,replacement=QUALIFIED_GATE.strip())

def source_closure():
    manifest=load(HERE/'source-manifest.json')
    require(manifest['schema']=='camera-taa-initialization-qualification-v1','Qualification schema differs')
    for name,digest in manifest['sources'].items():require(sha(ROOT/name)==digest,'Qualification source changed: '+name)
    for name,digest in manifest['evidence'].items():require(sha(ROOT/name)==digest,'Original source/input evidence changed: '+name)
    require(sha(PACKAGE/'analysis-first.json')==FIRST_FAIL_SHA,'Original first failure changed')
    first=load(PACKAGE/'analysis-first.json')
    require(first.get('passed') is False and first.get('executionOrSourceFailure')=='Static geometry/material source changed' and first.get('context')=={'logicalFrame':1},'Original failure is outside this source-gate qualification')
    report=load(ROOT/manifest['independentSourceReport'])
    require(report.get('sourceWindowQualified') is True and report.get('radianceOrPerPixelRowsRead') is False and
            report.get('originalAnalysisAccepted') is False and report.get('overallExecutionOrImageQualityAccepted') is False and
            report.get('fullSourceRecordsStableRequiredFrames')==[30,47] and
            report.get('physicalSourceFieldsStableFrames')==[0,47] and report.get('observationFrames')==[31,47],
            'Independent input-only source qualification failed or changed scope')
    return dict(manifestSha256=sha(HERE/'source-manifest.json'),independentSourceReport=manifest['independentSourceReport'],
                independentSourceReportSha256=sha(ROOT/manifest['independentSourceReport']),originalFirstFailureSha256=FIRST_FAIL_SHA,
                originalAnalyzerSha256=ORIGINAL_ANALYZER_SHA,originalModelSha256=ORIGINAL_MODEL_SHA)

def analyze(package):
    require(package.resolve()==PACKAGE.resolve(),'Qualification must use the original native package')
    closure=source_closure()
    original=original_module();function,patch=adapted_analyze(original)
    # The unchanged original source closure is still executed inside function.
    result=function(package)
    result['initializationQualification']=dict(**closure,**patch,
        scope='Physical fields fixed for all48; complete metadata fixed for30..47; no change to original mathematical/output/coverage predicates',
        effectiveAnalysis=(HERE/'analyze.py').relative_to(ROOT).as_posix())
    result['sourceClosure']['previousEffectiveAnalysis']=result['sourceClosure']['effectiveAnalysis']
    result['sourceClosure']['effectiveAnalysis']=(HERE/'analyze.py').relative_to(ROOT).as_posix()
    result['sourceClosure']['initializationManifestSha256']=closure['manifestSha256']
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve all earlier analysis results')
    try:result=analyze(args.package)
    except Exception as error:
        original=sys.modules.get('frozen_camera_ties_analysis')
        result=dict(passed=False,executionOrSourceFailure=str(error),effectiveAnalysis=(HERE/'analyze.py').relative_to(ROOT).as_posix(),
                    context=getattr(original,'CONTEXT',{}))
    with args.output.open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps({k:result.get(k) for k in ('passed','distinctEvents','nonzeroJitterFrames','executionOrSourceFailure')}))
    sys.exit(0 if result['passed'] else 1)
