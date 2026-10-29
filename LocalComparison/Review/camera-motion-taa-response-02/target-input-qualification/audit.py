"""Exact source-expression audit. Reads JSON only, never native BIN/EXR/RGB.

Expected target/path values are built from authored literals before receipts open.
Integer quotient/remainder implements binary32 round-to-nearest, ties-to-even.
This does not identify the native JIT's arithmetic implementation.
"""
import argparse
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
PACKAGE=HERE.parent
ROOT=PACKAGE.parents[2]
SPEC='https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/types#837-floating-point-types'
TARGET_EXPRESSION='new Vector3(group==0?.8f+.05f*i:2f+.2f*i,0,.5f+.1f*j)'
PATH_EXPRESSIONS=['float displacement=.075f*Mathf.Clamp(result.cameraEnds-31,0,8);',
                  'targetCamera.transform.position=cameraPosition+Vector3.right*displacement;']


def require(ok,message):
    if not ok:raise AssertionError(message)


def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def pow2(e):return F(2)**e


def rn32_bits(value):
    """Integer rounding for finite authored normal binary32 inputs (plus zero)."""
    value=F(value)
    if not value:return 0
    sign=0x80000000 if value<0 else 0;value=abs(value)
    e=value.numerator.bit_length()-value.denominator.bit_length()
    if value<pow2(e):e-=1
    require(-126<=e<=127,'Audit scope requires finite normal target/path values')
    scaled=value/pow2(e-23)
    mantissa,remainder=divmod(scaled.numerator,scaled.denominator)
    if 2*remainder>scaled.denominator or (2*remainder==scaled.denominator and mantissa&1):mantissa+=1
    if mantissa==1<<24:mantissa>>=1;e+=1
    require(e<=127,'Unexpected normal overflow')
    return sign|((e+127)<<23)|(mantissa-(1<<23))


def fraction_from_bits(bits):
    if bits&0x7fffffff==0:return F(0)
    e=(bits>>23)&255;require(0<e<255,'Normal finite float expected')
    return (-1 if bits>>31 else 1)*F((bits&0x7fffff)|(1<<23))*pow2(e-127-23)


def literal(text):return fraction_from_bits(rn32_bits(F(text)))
def stored(value):return fraction_from_bits(rn32_bits(value))
def hexes(bits):return [f'0x{v:08x}' for v in bits]


def expected_inputs():
    # These literal values and loop order come only from the frozen C# source.
    targets=[]
    for group in range(2):
        base,step=(literal('.8'),literal('.05')) if group==0 else (literal('2'),literal('.2'))
        for j in range(11):
            for i in range(21 if group==0 else 3):
                exact=[base+step*i,F(0),literal('.5')+literal('.1')*j]
                stepwise=[base+stored(step*i),F(0),literal('.5')+stored(literal('.1')*j)]
                targets.append(dict(index=len(targets),cohort='event' if group==0 else 'continued',
                                    i=i,j=j,exact=exact,wide=[rn32_bits(x) for x in exact],stepwise=[rn32_bits(x) for x in stepwise]))
    paths=[]
    for logical in range(48):
        k=min(max(logical-31,0),8)
        wide=[rn32_bits(F(3)+literal('.075')*k),rn32_bits(3),rn32_bits(-3)]
        stepwise=[rn32_bits(F(3)+stored(literal('.075')*k)),rn32_bits(3),rn32_bits(-3)]
        paths.append(dict(logicalFrame=logical,wide=wide,stepwise=stepwise))
    return targets,paths


def self_check():
    cases=[(F(0),0),(F(1),0x3f800000),(F(-3),0xc0400000),(F('.8'),0x3f4ccccd),
           (F('.05'),0x3d4ccccd),(F(1)+pow2(-24),0x3f800000),
           (F(1)+3*pow2(-24),0x3f800002)]
    for value,bits in cases:require(rn32_bits(value)==bits,'Integer RN32 self-check failed')
    return len(cases)


def audit():
    self_checks=self_check()
    targets,paths=expected_inputs()  # No native input has been read at this point.
    require(len(targets)==264,'Authored target count differs')
    host=ROOT/'LocalComparison/Harness/CameraMotionTaaTap.cs'
    scene=ROOT/'LocalComparison/Harness/CameraMotionTaaScene.cs'
    require(TARGET_EXPRESSION in host.read_text(),'Frozen target expression differs')
    require(all(expression in scene.read_text() for expression in PATH_EXPRESSIONS),'Frozen path expression differs')
    freeze=load(PACKAGE/'source-freeze.json')
    for path in (host,scene):require(sha(path)==freeze['sources'][path.relative_to(ROOT).as_posix()],'Frozen authored source changed')
    first=PACKAGE/'analysis-first.json';second=PACKAGE/'analysis-initialization-qualified.json'
    require(load(first)['executionOrSourceFailure']=='Static geometry/material source changed','First failure differs')
    require(load(second)['executionOrSourceFailure']=='Authored selection order/target differs' and
            load(second)['context']==dict(logicalFrame=31,sampleIndex=3,pixel=[338,174]),'Target failure differs')
    receipts={};timeline=[];json_roundtrips=0
    for logical in range(48):
        path=PACKAGE/'native'/f'frame-{logical:03}.json';r=load(path);receipts[path.relative_to(ROOT).as_posix()]=sha(path)
        require(r['logicalFrame']==logical and len(r['selection'])==264,'Receipt frame/count differs')
        step_mismatches=0
        for actual,expected in zip(r['selection'],targets):
            require(actual['index']==expected['index'] and actual['cohort']==expected['cohort'],'Authored ordering/cohort differs')
            values=[actual['worldTarget'][axis] for axis in 'xyz']
            expected_values=[float(fraction_from_bits(bits)) for bits in expected['wide']]
            require(values==expected_values,'Target is not the exact wide-expression stored binary32 value')
            require([rn32_bits(F(v)) for v in values]==expected['wide'],'Target JSON roundtrip differs')
            json_roundtrips+=3
            if expected['wide']!=expected['stepwise']:step_mismatches+=1
        expected=paths[logical];values=[r['cameraPosition'][axis] for axis in 'xyz']
        require(expected['wide']==expected['stepwise'],'Path requires a separate expression-precision qualification')
        require(values==[float(fraction_from_bits(bits)) for bits in expected['wide']],'Camera path source differs')
        json_roundtrips+=3
        timeline.append(dict(logicalFrame=logical,targetChecks=264,wideExpressionMismatches=0,
                             strictIntermediateMismatchCount=step_mismatches,cameraPositionBits=hexes(expected['wide']),
                             cameraPathStrictAndWideAgree=True))
    table=[dict(index=t['index'],cohort=t['cohort'],i=t['i'],j=t['j'],exactWideExpression=[str(x) for x in t['exact']],
                wideBits=hexes(t['wide']),strictIntermediateBits=hexes(t['stepwise'])) for t in targets]
    pins={path.relative_to(ROOT).as_posix():sha(path) for path in
          (Path(__file__),HERE/'basis.txt',host,scene,PACKAGE/'contract.txt',PACKAGE/'source-freeze.json',
           PACKAGE/'qualification-ties/analyze.py',PACKAGE/'qualification-initialization/analyze.py',first,second)}
    return dict(schema='camera-motion-taa-exact-authored-input-audit-v1',targetInputsQualified=True,
                cameraPathInputsQualified=True,postRunQualification=True,rawOrHistoryRgbRead=False,nativeBinsOpened=False,
                originalFailuresAccepted=False,temporalQualityAccepted=False,additionalNativeExecution=False,
                scope='Only exact authored target/path and JSON value representation. Uploaded/projected pixels and original geometric/history/output/coverage predicates remain unproven here.',
                sourceExpression=TARGET_EXPRESSION,cameraPathExpressions=PATH_EXPRESSIONS,
                specification=dict(url=SPEC,section='8.3.7',relevance='C# permits floating-point operations at greater precision than the result type; the source has no explicit intermediate precision casts.'),
                implementationClaim='All captured inputs match the exact rational wide-expression RN32 result; this does not identify JIT instructions, FMA use, or the execution mechanism.',
                numericMethod='Decimal float literals rounded by integer RN32; multiply/add performed as exact Fraction; final storage rounded by integer quotient/remainder ties-to-even. Strict-per-operation reference is retained separately.',
                fixedRoundingSelfChecks=self_checks,frames=48,targetsPerFrame=264,targetChecks=48*264,
                targetOrCameraJsonComponentsExactBinary32=json_roundtrips,wideExpressionMismatches=0,
                strictIntermediateTargetMismatchCountPerFrame=len([t for t in targets if t['wide']!=t['stepwise']]),
                timeline=timeline,independentExpectedTargets=table,receiptSha256=receipts,sourceSha256=pins)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    require(not args.output.exists(),'Preserve all previous results')
    result=audit()
    with args.output.open('x',encoding='utf-8') as stream:json.dump(result,stream,indent=2,sort_keys=True);stream.write('\n')
    print(json.dumps({k:result[k] for k in ('targetInputsQualified','cameraPathInputsQualified','targetChecks','wideExpressionMismatches','strictIntermediateTargetMismatchCountPerFrame','nativeBinsOpened')}))
