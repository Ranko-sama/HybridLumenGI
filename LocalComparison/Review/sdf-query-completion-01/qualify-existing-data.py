"""One bounded post-review qualification of existing bytes; never runs WARP.
The original candidate report and frozen judge remain FAILED and unchanged.
Only the two near controls' independent-query fields get their explicit expected
change; all other original assertions and tolerances execute verbatim.
"""
import ast, hashlib, json, re, struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
PACKAGE=Path(__file__).resolve().parent
EVIDENCE=PACKAGE/'execution'
out=PACKAGE/'qualification';out.mkdir(exist_ok=False)
sha=lambda b:hashlib.sha256(b).hexdigest()
baseline=json.loads((EVIDENCE/'baseline/report.json').read_text(encoding='utf-8'))
candidate=json.loads((EVIDENCE/'candidate/report.json').read_text(encoding='utf-8'))
fixture=json.loads((EVIDENCE/'fixture.json').read_text(encoding='utf-8'))
report={'status':'running','originalCandidateStatus':candidate['status'],'additionalWarpExecutions':0,'unityExecuted':False}
try:
    assert candidate['status']=='failed' and candidate['error']=='nearer_known_after_sdf changed proven control extra'
    assert baseline['status']=='counterexample_confirmed'
    inputs=(EVIDENCE/'inputs.bin').read_bytes()
    assert sha(inputs)==baseline['inputSha256']==candidate['inputSha256']
    for name,digest in candidate['sources'].items():
        assert sha((EVIDENCE/'candidate/source'/name).read_bytes())==digest
        assert sha((ROOT/name).read_bytes())==digest
    script=Path('Tests/Validate-SdfQueryCompletion.py')
    original=(EVIDENCE/'candidate/source'/script).read_text(encoding='utf-8')
    assert (EVIDENCE/'baseline/source'/script).read_bytes()==(EVIDENCE/'candidate/source'/script).read_bytes()
    node=next(n for n in ast.parse(original).body if isinstance(n,ast.FunctionDef) and n.name=='judge')
    body='\n'.join(original.splitlines()[node.lineno-1:node.end_lineno])+'\n'
    old="                assert list(r[name][key]) == prior[name][key], name+' changed proven control '+key"
    new="""                if name in ('nearer_known_after_sdf','nearer_known_before_sdf') and key=='extra':
                    assert prior[name][key][:2]==[0,0], name+' baseline independent SDF did not miss'
                    assert tuple(r[name][key][:2])==(1,1|512|flags), name+' independent SDF did not become unresolved'
                    assert list(r[name][key][2:])==prior[name][key][2:], name+' changed scene representation/cache commit'
                else:
                    assert list(r[name][key]) == prior[name][key], name+' changed proven control '+key"""
    assert body.count(old)==1
    derived=body.replace(old,new,1)
    (out/'qualified-judge.py').write_text(derived,encoding='utf-8')
    namespace={'struct':struct};exec(compile(derived,'qualified-judge.py','exec'),namespace)
    header=(EVIDENCE/'candidate/source/Runtime/Resources/HybridLumenGI/HybridLumenGIHit.hlsl').read_text(encoding='utf-8')
    flag=int(re.search(r'#define HLGI_HIT_QUERY_UNRESOLVED\s+(\d+)u',header)[1])
    raw=(EVIDENCE/'candidate/outputs.bin').read_bytes()
    rows=namespace['judge'](raw,fixture,'candidate',baseline,flag)
    report.update(status='qualified_finite_contract',inputSha256=sha(inputs),outputSha256=sha(raw),
        originalJudgeSha256=sha(body.encode()),qualifiedJudgeSha256=sha(derived.encode()),rows=rows,
        scope='Only the two nearer controls distinguish independent full-range SDF fields extra.xy from unchanged scene fields extra.zw. All other original assertions/tolerances preserved. Original candidate FAIL unchanged; no new execution.')
    print('QUALIFIED existing source-bound bytes; original candidate FAIL retained; zero additional WARP/Unity.',flush=True)
except Exception as error:
    report.update(status='failed',error=str(error));raise
finally:(out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
