"""Pro62-authorized one-shot reinterpretation; preserve the original failed analyzer/data."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'LocalComparison/Review/local-light-move-response-01'
source=ROOT/'LocalComparison/Harness/analyze-light-move.py';frozen=P/'frozen/LocalComparison/Harness/analyze-light-move.py'
assert source.read_bytes()==frozen.read_bytes(),'Original analyzer changed'
out=P/'qualification-addendum';assert not out.exists(),'Single supplemental judgment already attempted';out.mkdir()
files=[source,P/'input.json',*sorted((P/'native-window').rglob('*'))];files=[p for p in files if p.is_file()]
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();before={str(p.relative_to(ROOT)):digest(p) for p in files}
text=source.read_text(encoding='utf-8')
old="    contract=load(P/'input.json');result="
new="    contract=load(P/'input.json')\n    for key in ['positionA','positionB']:contract[key]=[struct.unpack('<f',struct.pack('<f',value))[0] for value in contract[key]]\n    result="
assert text.count(old)==1 and text.count("out=N/'qualification.json'")==1
generated=text.replace(old,new).replace("out=N/'qualification.json'","out=N/'qualification-addendum.json'")
(out/'analyzer.executed.py.txt').write_text(generated,encoding='utf-8',newline='\n')
(out/'before.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
code=1
try:
    exec(compile(generated,str(out/'analyzer.executed.py.txt'),'exec'),{'__file__':str(source),'__name__':'__main__'})
except SystemExit as e:code=int(e.code or 0)
finally:
    after={str(p.relative_to(ROOT)):digest(p) for p in files};same=before==after
    (out/'evidence-integrity.json').write_text(json.dumps({'originalFilesUnchanged':same,'originalFiles':len(files),'originalAnalyzerSha256':digest(source),'generatedAnalyzerSha256':digest(out/'analyzer.executed.py.txt'),'exitCode':code,'changes':'Only frozen expected A/B converted to binary32 in memory, and a separate output path; all original assertions/data/tolerances retained'},indent=2),encoding='utf-8')
    assert same,'Original evidence changed'
raise SystemExit(code)
