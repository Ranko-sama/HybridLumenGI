"""Run the prepared workload with a drawable Win32 window, without requesting focus."""
import datetime
import json
from pathlib import Path
import subprocess


here = Path(__file__).resolve().parent
root = Path("I:/Unity test/Comparison")
build = root / "Builds/LocalRelease100StreamingSustained30m01"
output = root / "StreamingSustained30m01-windowed"
log = root / "StreamingSustained30m01-windowed-player.log"
attempt = here / "windowed-attempt.json"
receipt = here / "windowed-exit.json"
report = json.loads((build / "build-result.json").read_text(encoding="utf-8-sig"))
if report["status"] != "Succeeded" or report["actualOptions"] != "None" or report["errors"]:
    raise RuntimeError("Expected the existing ordinary measurement build")
if any(path.exists() for path in (output, log, attempt, receipt)):
    raise FileExistsError("Preserve the recorded windowed run")

command = [str(build / "HybridLumenGIPlayer.exe"), "-force-d3d12", "-screen-fullscreen", "0",
           "-screen-width", "960", "-screen-height", "540", "-hlgiStreamingSoak", str(output), "-logFile", str(log)]
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 4  # SW_SHOWNOACTIVATE. A hidden window ran Update without rendering.

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

with attempt.open("x", encoding="utf-8") as file:
    process = subprocess.Popen(command, cwd=build, startupinfo=startup)
    json.dump(dict(startedUtc=now(), pid=process.pid, command=command, showWindow="SW_SHOWNOACTIVATE"), file, indent=2)
print(f"Streaming Player PID {process.pid}; {output / 'endpoints.jsonl'}", flush=True)
watchdog = False
try:
    process.wait(timeout=2400)
except subprocess.TimeoutExpired:
    watchdog = True
    process.kill()
    process.wait()
with receipt.open("x", encoding="utf-8") as file:
    json.dump(dict(endedUtc=now(), exitCode=process.returncode, watchdogTerminated=watchdog), file, indent=2)
raise SystemExit(1 if watchdog else process.returncode)
