"""One portable PresentMon invocation, targeting the root-owned ordinary Player."""
import datetime
import json
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
OUTPUT = Path("I:/Unity test/Comparison/Release93MotionPresent01")
TOOL = Path("I:/Unity test/Tools/PresentMon-2.6.0/PresentMon-2.6.0-x64.exe")
player = json.loads((HERE / "player-attempt.json").read_text())
if (OUTPUT / "present.csv").exists() or (HERE / "capture-exit.json").exists():
    raise RuntimeError("Preserve the first capture")
before = json.loads((HERE / "before-ledger.json").read_text(encoding="utf-8"))
assert before["targetProcessId"] == player["processId"]
ledger = before["ledger"]
assert ledger["featureEnabled"] and ledger["actualBackend"] == "DXR" and ledger["cameraGi"]["hardwareBackend"]
assert ledger["visibleMembers"] > 0 and ledger["pagesLoading"] == 0 and ledger["pagesFailed"] == 0
assert ledger["cameraGi"]["warmingInstances"] == 0 and ledger["cameraGi"]["pendingCapacity"] == 0
assert not ledger["requestedMeasureGpuCost"] and not ledger["requestedAdaptiveGpuBudget"]
command = [str(TOOL), "--process_id", str(player["processId"]), "--output_file", str(OUTPUT / "present.csv"),
    "--session_name", "HLGI-Release93-motion-present-01", "--delay", "10", "--timed", "30",
    "--terminate_after_timed", "--no_console_stats", "--no_track_display", "--no_track_input", "--no_track_gpu", "--v1_metrics"]
now = lambda: datetime.datetime.now(datetime.timezone.utc).isoformat()
record = dict(startedUtc=now(), command=command, targetProcessId=player["processId"], watchdogTerminated=False,
    context="Same ordinary Release93 process: M requests ordinary door motion; F2 ledger reports ready default DXR; CPU state only, not screenshot or per-frame proof. Application Present timing only; no display tracking. Camera remains fixed; the ordinary door motion loop stays requested throughout the capture. No input or logging during the timed window.")
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

