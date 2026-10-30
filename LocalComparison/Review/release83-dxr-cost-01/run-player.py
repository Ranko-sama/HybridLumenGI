"""One ordinary-window measurement Player; preserve every outcome, no retry."""
import datetime
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
BUILD = Path("I:/Unity test/Comparison/Builds/LocalRelease83DxrCost01")
OUTPUT = Path("I:/Unity test/Comparison/Release83DxrCost01")
report = json.loads((BUILD / "build-result.json").read_text(encoding="utf-8-sig"))
assert report["status"] == "Succeeded" and report["errors"] == 0 and report["actualOptions"] == "None"
if OUTPUT.exists() or (HERE / "native-exit.json").exists():
    raise RuntimeError("Preserve existing run outcome")
OUTPUT.mkdir()
command = [str(BUILD / "HybridLumenGIPlayer.exe"), "-force-d3d12", "-screen-fullscreen", "0",
           "-screen-width", "960", "-screen-height", "540", "-gpuCostOutput", str(OUTPUT / "run"),
           "-logFile", str(OUTPUT / "player.log")]
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
record = dict(startedUtc=now(), configuration="Release83 product0181ef2; saved sample960x540/halfGI/DXR requested; actual DXR required in window; measurement only, feedback off; input/UI disabled; ordinary backbuffer window",
              command=command, watchdogTerminated=False)
(HERE / "player-attempt.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
process = subprocess.Popen(command, cwd=BUILD)
record["processId"] = process.pid
print(f"Measurement Player PID {process.pid}; log {OUTPUT / 'player.log'}", flush=True)
try:
    record["exitCode"] = process.wait(timeout=1200)
except subprocess.TimeoutExpired:
    record["watchdogTerminated"] = True
    process.kill()
    record["exitCode"] = process.wait(timeout=30)
finally:
    record["endedUtc"] = now()
    (HERE / "native-exit.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps(record, indent=2), flush=True)
raise SystemExit(0 if record["exitCode"] == 0 and not record["watchdogTerminated"] else 1)
