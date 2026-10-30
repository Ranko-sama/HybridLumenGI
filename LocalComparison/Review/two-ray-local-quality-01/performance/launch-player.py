"""Launch the ordinary delivered Player once; the root closes it through Alt+F4."""
import datetime
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
BUILD = Path("I:/Unity test/Comparison/Builds/LocalRelease88")
OUTPUT = Path("I:/Unity test/Comparison/TwoRayLocalQualityPerformance01")
build = json.loads((BUILD / "build-result.json").read_text(encoding="utf-8-sig"))
assert build["status"] == "Succeeded" and build["actualOptions"] == "None" and build["errors"] == 0
if OUTPUT.exists() or (HERE / "native-exit.json").exists():
    raise RuntimeError("Preserve the first run")
OUTPUT.mkdir()
command = [str(BUILD / "HybridLumenGIPlayer.exe"), "-force-d3d12", "-screen-fullscreen", "0",
    "-screen-width", "960", "-screen-height", "540", "-logFile", str(OUTPUT / "player.log")]
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
record = dict(startedUtc=now(), command=command, product="Release88 candidate / Runtime e352921; local two-ray quality configuration; default DXR", watchdogTerminated=False)
process = subprocess.Popen(command, cwd=BUILD)
record["processId"] = process.pid
(HERE / "player-attempt.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(f"Ordinary Release88 PID {process.pid}; log {OUTPUT / 'player.log'}", flush=True)
try:
    record["exitCode"] = process.wait(timeout=600)
except subprocess.TimeoutExpired:
    record["watchdogTerminated"] = True
    process.kill()
    record["exitCode"] = process.wait(timeout=30)
finally:
    record["endedUtc"] = now()
    (HERE / "native-exit.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps(record, indent=2), flush=True)
raise SystemExit(0 if record["exitCode"] == 0 and not record["watchdogTerminated"] else 1)

