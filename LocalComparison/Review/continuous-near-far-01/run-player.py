"""One ordinary-window measurement Player; preserve every outcome, no retry."""
import datetime
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
COLD = sys.argv[1:] == ['--cold-crossing']
if sys.argv[1:] and not COLD:
    raise SystemExit('Expected no arguments or --cold-crossing')
if COLD:
    HERE = HERE.parent / 'cold-crossing-01'
BUILD = Path('I:/Unity test/Comparison/Builds') / ('LocalRelease103ColdCrossing01' if COLD else 'LocalRelease90ContinuousNearFar01')
OUTPUT = Path('I:/Unity test/Comparison') / ('ColdCrossing01' if COLD else 'ContinuousNearFar01')
report = json.loads((BUILD / "build-result.json").read_text(encoding="utf-8-sig"))
assert report["status"] == "Succeeded" and report["errors"] == 0 and report["actualOptions"] == "None"
if OUTPUT.exists() or (HERE / "native-exit.json").exists():
    raise RuntimeError("Preserve existing run outcome")
OUTPUT.mkdir()
command = [str(BUILD / "HybridLumenGIPlayer.exe"), "-force-d3d12", "-screen-fullscreen", "0",
           "-screen-width", "960", "-screen-height", "540", "-continuousNearFarOutput", str(OUTPUT),
           "-logFile", str(OUTPUT / "player.log")]
if COLD:
    command.append('-coldCrossing')
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
record = dict(startedUtc=now(), configuration="Release103, 960x540, half GI, 2 rays, filter4. Cold outside/near/outside. CPU page and group state." if COLD else "Release90 product55b5908; saved sample960x540/halfGI/2ray/default DXR; fixed hot near/far route20units/sec ten round trips; CPU publication and renderer state, no timing/feedback/memory/image capture; input/UI disabled",
              command=command, watchdogTerminated=False)
(HERE / "player-attempt.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 4  # A drawable window without requesting focus.
process = subprocess.Popen(command, cwd=BUILD, startupinfo=startup if COLD else None)
record["processId"] = process.pid
print(f"Continuous route Player PID {process.pid}; log {OUTPUT / 'player.log'}", flush=True)
try:
    record["exitCode"] = process.wait(timeout=180)
except subprocess.TimeoutExpired:
    record["watchdogTerminated"] = True
    process.kill()
    record["exitCode"] = process.wait(timeout=30)
finally:
    record["endedUtc"] = now()
    (HERE / "native-exit.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps(record, indent=2), flush=True)
raise SystemExit(0 if record["exitCode"] == 0 and not record["watchdogTerminated"] else 1)
