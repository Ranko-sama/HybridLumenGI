"""Exact authored-target qualification composed with the frozen source gate.

The one admitted model is source float literals -> exact rational multiply/add
-> integer ties-to-even binary32 storage. No epsilon or alternative target set.
"""
import argparse
import hashlib
import importlib.util
import inspect
import json
from pathlib import Path
import struct
import sys

HERE=Path(__file__).resolve().parent
PACKAGE=HERE.parent
ROOT=HERE.parents[3]
SECOND_FAILURE_SHA='19abacd2a0e7b25ef3e892c1d80dd8bc5cba41f5a412bcd51945f573e0fea831'
OLD_TARGET="    cohort,target=targets()[index]\n    require(selected['index']==node['index']==index and selected['cohort']==cohort and vec(selected['worldTarget'])==target,'Authored selection order/target differs')"
NEW_TARGET="    cohort,target=qualified_author_target(selected,node,index)"

def require(ok,message):
    if not ok:raise AssertionError(message)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def module_at(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module)
    return module

def adapted_selected_source(original,expression):
    # This computes expectations from frozen C# literals before any selection
    # receipt is opened. The independent audit's captured-value table is not
    # used as an expected-value lookup.
    expected,_=expression.expected_inputs()
    require(len(expected)==264,'Authored target count changed')
    def qualified_author_target(selected,node,index):
        require(0<=index<264,'Authored target index outside fixed set')
        target=expected[index];actual=original.vec(selected['worldTarget'])
        require(selected['index']==node['index']==index and selected['cohort']==target['cohort'],'Authored selection order/cohort differs')
        expected_values=[float(expression.fraction_from_bits(bits)) for bits in target['wide']]
        require(actual==expected_values and [struct.unpack('<I',struct.pack('<f',v))[0] for v in actual]==target['wide'],
                'Authored target differs from exact wide-expression binary32 result')
        # Pass the proven actual authored point to the unchanged projection.
        return target['cohort'],actual
    source=inspect.getsource(original.selected_source)
    require(source.count(OLD_TARGET)==1,'Original authored-target gate is not unique')
    adapted=source.replace(OLD_TARGET,NEW_TARGET)
    namespace=dict(vars(original),qualified_author_target=qualified_author_target)
    exec(compile(adapted,'<source-expression-qualified original selected_source>','exec'),namespace)
    return namespace['selected_source'],dict(originalSelectionFunctionSha256=hashlib.sha256(source.encode()).hexdigest(),
        adaptedSelectionFunctionSha256=hashlib.sha256(adapted.encode()).hexdigest(),replacedOriginalSelectionLines=2,
        expressionModel='binary32 source literals, exact rational multiply/add, integer RN32 final storage'),qualified_author_target

def source_closure():
    manifest=load(HERE/'source-manifest.json')
    require(manifest['schema']=='camera-taa-source-expression-qualification-v1','Source-expression schema differs')
    for field in ('sources','evidence'):
        for name,digest in manifest[field].items():require(sha(ROOT/name)==digest,'Frozen source/input evidence changed: '+name)
    require(sha(PACKAGE/'analysis-initialization-qualified.json')==SECOND_FAILURE_SHA,'Second original failure changed')
    failure=load(PACKAGE/'analysis-initialization-qualified.json')
    require(failure.get('passed') is False and failure.get('executionOrSourceFailure')=='Authored selection order/target differs' and
            failure.get('context')==dict(logicalFrame=31,sampleIndex=3,pixel=[338,174]),'Failure differs from qualified author-input mismatch')
    report=load(ROOT/manifest['independentTargetReport'])
    require(report.get('targetInputsQualified') is True and report.get('cameraPathInputsQualified') is True and
            report.get('targetChecks')==48*264 and report.get('wideExpressionMismatches')==0 and
            report.get('rawOrHistoryRgbRead') is False and report.get('nativeBinsOpened') is False and
            report.get('temporalQualityAccepted') is False and report.get('originalFailuresAccepted') is False,
            'Independent authored-input proof failed or changed scope')
    return dict(manifestSha256=sha(HERE/'source-manifest.json'),independentTargetReport=manifest['independentTargetReport'],
                independentTargetReportSha256=sha(ROOT/manifest['independentTargetReport']),originalSecondFailureSha256=SECOND_FAILURE_SHA)

def prepare_adapter():
    initialization=module_at('frozen_initialization_qualification',PACKAGE/'qualification-initialization/analyze.py')
    original=initialization.original_module()
    expression=module_at('frozen_exact_author_expression',PACKAGE/'target-input-qualification/audit.py')
    function,init_patch=initialization.adapted_analyze(original)
    selected,target_patch,qualifier=adapted_selected_source(original,expression)
    function.__globals__['selected_source']=selected
    return initialization,original,function,init_patch,target_patch,qualifier

def analyze(package):
    require(package.resolve()==PACKAGE.resolve(),'Qualification must use the preserved native package')
    closure=source_closure()
    initialization,original,function,init_patch,target_patch,_=prepare_adapter()
    init_closure=initialization.source_closure()
    result=function(package)
    result['initializationQualification']=dict(**init_closure,**init_patch)
    result['sourceExpressionQualification']=dict(**closure,**target_patch,
        scope='Authored target source only; actual index/cohort/pixel, mathematical model, output and coverage predicates unchanged',
        effectiveAnalysis=(HERE/'analyze.py').relative_to(ROOT).as_posix())
    result['sourceClosure']['previousEffectiveAnalysis']=result['sourceClosure']['effectiveAnalysis']
    result['sourceClosure']['effectiveAnalysis']=(HERE/'analyze.py').relative_to(ROOT).as_posix()
    result['sourceClosure']['initializationManifestSha256']=init_closure['manifestSha256']
    result['sourceClosure']['sourceExpressionManifestSha256']=closure['manifestSha256']
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('package',type=Path);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve all earlier results')
    try:result=analyze(args.package)
    except Exception as error:
        original=sys.modules.get('frozen_camera_ties_analysis')
        result=dict(passed=False,executionOrSourceFailure=str(error),context=getattr(original,'CONTEXT',{}),
                    effectiveAnalysis=(HERE/'analyze.py').relative_to(ROOT).as_posix())
    with args.output.open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps({k:result.get(k) for k in ('passed','distinctEvents','nonzeroJitterFrames','executionOrSourceFailure')}))
    sys.exit(0 if result['passed'] else 1)
