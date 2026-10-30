"""Summarize the one recorded route; no Player, image, GPU query or new acceptance thresholds."""
import collections
import json
from pathlib import Path

here = Path(__file__).resolve().parent
raw = Path("I:/Unity test/Comparison/ContinuousNearFar01/run.json")
run = json.loads(raw.read_text(encoding="utf-8-sig"))
native = json.loads((here / "native-exit.json").read_text(encoding="utf-8-sig"))
frames = run["frames"]
moving = [row for row in frames if row["phase"] == "moving"]
settling = [row for row in frames if row["phase"] == "settling"]
summary = {key: run[key] for key in ("outcome", "error", "oneWayDistance", "plannedMotionSeconds", "beginCallbacks", "endCallbacks",
    "targetChanges", "publicationChanges", "actualMotionIoObserved", "returnedNear", "completeNearRecovered")}
summary.update(product="Release90 / 55b5908", raw=str(raw), nativeExit=native["exitCode"], watchdogTerminated=native["watchdogTerminated"],
    scope="One resident hot Near/Far route; CPU renderer flags and current published group identities, not pixel coverage or GPU completion.",
    phaseRows=dict(collections.Counter(row["phase"] for row in frames)),
    motionBeginGroups=dict(collections.Counter(row["beginGroup"] for row in moving)),
    motionPublishedGroups=dict(collections.Counter(row["publishedGroup"] for row in moving)),
    motionTargetGroups=dict(collections.Counter(row["targetGroup"] for row in moving)),
    motionBackends=dict(collections.Counter(row["ledger"]["actualBackend"] for row in moving)),
    movingLegs=sorted(set(row["leg"] for row in moving)),
    motionTransitioningFrames=sum(row["transitioning"] for row in moving),
    motionIoFrames=sum(row["ledger"]["pageIoBytesStartedThisStep"] > 0 or row["ledger"]["pageIoBytesInFlight"] > 0 for row in moving),
    motionIoBytesStarted=sum(row["ledger"]["pageIoBytesStartedThisStep"] for row in moving),
    maxMovingPageActiveOperations=max((row["ledger"]["pageActiveOperations"] for row in moving), default=0),
    maxMovingPagePending=max((row["pagePending"] for row in moving), default=0),
    motionEngineFrames=[moving[0]["engineFrame"], moving[-1]["engineFrame"]] if moving else [],
    recoveryEngineFrames=[settling[0]["engineFrame"], settling[-1]["engineFrame"]] if settling else [],
    recoveryRecordedSpanSeconds=settling[-1]["endSeconds"] - settling[0]["beginSeconds"] if settling else None,
    recoveryMeaning="First settling begin to final end callback span, not exact IO/recovery latency.",
    recoveryFirstBeginGroup=settling[0]["beginGroup"] if settling else None,
    finalPublication=frames[-1]["publishedGroup"] if frames else None)
summary["finalLedger"] = {key: run["end"][key] for key in ("status", "pagesReady", "pagesLoading", "pagesReleasing", "pagesFailed",
    "pageConsumerReferences", "pageActiveOperations", "pageIoBytesInFlight", "pageRetiringLeases", "visibleMembers", "boundMembers", "actualBackend")}
settings = json.loads(run["settings"])
summary["settings"] = {key: settings[key] for key in ("raysPerPixel", "resolutionScale", "filterIterations", "cacheRaysPerFace",
    "preferHardwareTracing", "measureGpuCost", "adaptiveGpuBudget")}
with (here / "result.json").open("x", encoding="utf-8") as output:
    json.dump(summary, output, ensure_ascii=False, indent=2)
print(json.dumps({key: summary[key] for key in ("outcome", "nativeExit", "phaseRows", "targetChanges", "publicationChanges", "motionIoFrames", "completeNearRecovered")}, ensure_ascii=False))
