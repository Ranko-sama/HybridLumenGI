"""Preserve numeric comparisons and pre-comparison source qualification failures."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
output=P/'analysis-first.json'
log=P/'analysis-first.log'
receipt=P/'analysis-first-exit.json'
assert not any(p.exists() for p in (output,log,receipt)),'Preserve the first analysis and failure evidence'
command=[sys.executable,'-Xutf8','-B',str(ROOT/'LocalComparison/Reference/CacheFeedbackFinite02/compare_native.py'),
         '--native-outputdir',str(P/'native'),'--package',str(P),'--output',str(output)]
result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
log.write_bytes(result.stdout)
receipt.write_text(json.dumps(dict(exitCode=result.returncode,completedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                                  comparisonPresent=output.exists(),command=command,logSha256=hashlib.sha256(result.stdout).hexdigest()),indent=2)+'\n',encoding='utf-8')
print(result.stdout.decode('utf-8',errors='replace'))
raise SystemExit(result.returncode)
