"""One portable PresentMon invocation, targeting the root-owned ordinary Player."""
import datetime
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
OUTPUT = Path("I:/Unity test/Comparison/Release83PresentApi02")
TOOL = Path("I:/Unity test/Tools/PresentMon-2.6.0/PresentMon-2.6.0-x64.exe")
player = json.loads((HERE / "player-attempt.json").read_text())
if (OUTPUT / "present.csv").exists() or (HERE / "capture-exit.json").exists():
    raise RuntimeError("Preserve the first capture")
command = [str(TOOL), "--process_id", str(player["processId"]), "--output_file", str(OUTPUT / "present.csv"),
    "--session_name", "HLGI-Release83-present-api-02", "--delay", "10", "--timed", "30",
    "--terminate_after_timed", "--no_console_stats", "--no_track_display", "--no_track_input", "--no_track_gpu", "--v1_metrics"]
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
record = dict(startedUtc=now(), command=command, targetProcessId=player["processId"], watchdogTerminated=False,
    context="User-confirmed normal 3D scene in ordinary Release83. Application Present timing only; no display tracking. Requested unchanged camera/scene during the fixed capture.")
(HERE / "capture-attempt.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
with (OUTPUT / "presentmon.log").open("wb") as log:
    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    record["processId"] = process.pid
    print(f"PresentMon PID {process.pid}; target Player {player['processId']}; 10s delay + 30s capture", flush=True)
    try:
        record["exitCode"] = process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        record["watchdogTerminated"] = True
        process.kill()
        record["exitCode"] = process.wait(timeout=30)
record["endedUtc"] = now()
(HERE / "capture-exit.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps(record, indent=2), flush=True)
raise SystemExit(0 if record["exitCode"] == 0 and not record["watchdogTerminated"] else 1)

