"""Interpret the single all-source-off observation; never launches Unity."""
import argparse
import json
from pathlib import Path
import numpy as np


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def need(ok, reason):
    if not ok:
        raise ValueError(reason)


def rgba(values):
    return np.array([[v[k] for k in "rgba"] for v in values], dtype=float)


def plane(folder, item):
    name = item["data"]["file"] if "data" in item else item["file"]
    return np.fromfile(folder/name, dtype="<f4").reshape(item["height"], item["width"], 4)


def capture(folder, logical):
    r = load(folder/f"frame-{logical:04d}-capture.json")
    need(r["status"] == "complete" and r["logicalFrame"] == logical, "Capture incomplete/source differs")
    return r, {p["signalId"]: p for p in r["samples"]}, {p["role"]: p for p in r["support"]}


def floor_support(folder, samples, support, camera, pixels):
    x, y = pixels.T
    before = plane(folder, samples["cameraBeforeHLGI"])[y, x]
    material = plane(folder, support["material"])[y, x]
    depth = plane(folder, support["depth"])[y, x, 0]
    need(np.isfinite(before).all() and np.max(abs(before[:, :3])) <= 1e-6, "Native contribution is not black")
    need(np.isfinite(material).all() and np.max(abs(material[:, :3]-.96)) <= 2/255, "Declared white receiver differs")
    need(camera["matrixOrder"] == "row-major" and camera["rowOrder"] == "top-to-bottom" and camera["uvOrigin"] == "top-left" and camera["clipDepth"] == "zero-to-one", "Camera conventions differ")
    vp = np.array(camera["projection"]).reshape(4,4) @ np.array(camera["view"]).reshape(4,4)
    clip = np.c_[(pixels+.5)/[960,540]*2-1, depth, np.ones(27)]
    clip[:,1] *= -1
    h = clip @ np.linalg.inv(vp).T
    xyz = h[:,:3]/h[:,3:]
    need(np.isfinite(xyz).all() and np.max(abs(xyz[:,1])) <= 1e-3 and np.all((xyz[:,0]>0)&(xyz[:,0]<5)&(xyz[:,2]>-3)&(xyz[:,2]<3)), "Point is not inside source floor")
    return dict(maxNativeAbs=float(np.max(abs(before[:,:3]))), maxFloorAbsY=float(np.max(abs(xyz[:,1]))))


def analyze(base, output):
    r = load(base/"scene-result.json")
    editor = load(base/"editor-result.json")
    need(r["status"] == editor["status"] == "collected" and editor["restored"], "Collection/restoration incomplete")
    need(r["lane"] == "GreenToOff" and (r["width"],r["height"]) == (960,540) and r["uvStartsAtTop"], "Input lane/dimensions differ")
    need(all(r[k] for k in ("baselineDrained","preEventReadbackCompleted","preEventHistoryReadbackCompleted","terminalCaptureDrained","readbacksDrained")) and r["pendingReadbacks"] == 0 and r["peakPendingReadbacks"] <= 8, "Pending observation or incomplete readback")
    settings = json.loads(r["settings"])
    expected = dict(resolutionScale=.5,raysPerPixel=2,filterIterations=4,temporalAccumulation=True,
                    temporalCurrentWeight=.08,maxHistory=32,bounceFeedback=1,cachePatchesPerFrame=256,
                    cachePatchGrid=4,cacheRaysPerFace=8,preferHardwareTracing=True,adaptiveGpuBudget=False,
                    receiverObjectHistory=True,debugView=0)
    need(all(np.float32(settings[k]) == np.float32(v) for k,v in expected.items()), "Released quality differs")
    need(not r["environmentCubemapPresent"] and all(settings["environmentRadiance"][k] == 0 for k in "rgb"), "Continuing environment source")
    selection = r["selection"]["points"]
    old = np.array([p["oldSampledFull"] for p in selection])
    mapped = np.floor((old+.5)*1.5).astype(int)
    pixels = np.array([p["full"] for p in selection])
    gi = np.array([p["gi"] for p in selection])
    need(pixels.shape == (27,2) and len(set(map(tuple,pixels))) == 27 and np.array_equal(mapped,np.array([p["mappedFull"] for p in selection])) and np.array_equal(pixels,2*(mapped//2)+1) and np.array_equal(gi,(pixels-1)//2), "Frozen GI-center mapping differs")
    frames = r["frames"]
    need([f["logicalFrame"] for f in frames] == list(range(r["requests"])) and frames[-1]["logicalFrame"] == r["finalLogical"], "Source sequence missing")
    need(all(frames[i]["engineFrame"] == frames[i-1]["engineFrame"]+1 for i in range(2,len(frames))), "Observer interrupted f-1 history")
    need(r["eventAfterLogical"] == 119 and r["eventEngine"] == frames[119]["engineFrame"], "Event engine frame differs")
    rows = frames[119:]
    need(all(f["readbackRequested"] and f["readbackCompleted"] and f["historyReadbackRequested"] and f["historyReadbackCompleted"] and not f.get("readbackError") and not f.get("historyReadbackError") for f in rows), "A Final/history source readback is missing")
    need(all(f["workFrame"] == f["logicalFrame"] and f["diagnostics"]["transportRecordedEngineFrame"] == f["engineFrame"] and f["historyRecordedWorkFrame"] == f["workFrame"] and f["historyRecordedEngineFrame"] == f["engineFrame"] and f["historyStateFrame"] == f["workFrame"]+1 and (f["historyWidth"],f["historyHeight"]) == (480,270) for f in rows), "Borrowed texture/source association differs")
    need(all(f["diagnostics"]["hardwareBackend"] and f["diagnostics"]["hardwareMeshes"] == 2 and f["diagnostics"]["hardwareFallbacks"] == 1 and f["diagnostics"]["publishedInstances"] == 3 and f["diagnostics"]["lightSelected"] == 0 for f in rows), "Actual source/backend differs")
    final = np.array([rgba(f["points"]) for f in rows])
    history = np.array([rgba(f["historyPoints"]) for f in rows])
    need(final.shape == history.shape == (len(rows),27,4) and np.isfinite(final).all(), "Final shape/nonfinite point")
    need(np.all(final[0,:,1] > 0) and np.max(abs(final[0,:,[0,2]])) <= 1e-6, "Pre-event source is not isolated positive green")
    for f in rows[1:]:
        need(f["response"] and all(f["inputEmission"][k] == 0 for k in "xyz"), "Response source is not black")
    times = np.array([f["elapsedSeconds"] for f in rows[1:]])
    need(np.all(np.diff(times)>0) and times[-1]>=2.6 and times[-1]<=3, "Source clock/end bound differs")
    temporal_valid = np.isfinite(history).all(-1) & (history[:,:,3]>0)
    point_ratio = final[1:,:,1]/final[0,:,1]
    mean_ratio = final[1:,:,1].mean(1)/final[0,:,1].mean()
    temporal_count = np.sum(~temporal_valid[1:],axis=1)
    response_qualified = temporal_count == 0
    floor0, sample0, support0 = capture(base/r["baselineDirectory"],0)
    need((sample0["filteredD"]["width"],sample0["filteredD"]["height"]) == (480,270), "Actual GI dimensions differ")
    baseline_support = floor_support(base/r["baselineDirectory"],sample0,support0,r["baselineCamera"],pixels)
    last = frames[-1]
    end_receipt, end_samples, end_support = capture(base/r["terminalDirectory"],r["finalLogical"])
    need(end_receipt["workFrame"] == last["workFrame"] and end_receipt["engineFrame"] == last["engineFrame"] and r["terminalCaptureLogical"] == r["finalLogical"] and r["terminalCaptureWorkFrame"] == last["workFrame"] and r["terminalCaptureEngineFrame"] == last["engineFrame"], "Terminal receipt differs from Final/history")
    need(r["terminalCamera"] == r["baselineCamera"], "Camera changed during observation")
    end_floor = floor_support(base/r["terminalDirectory"],end_samples,end_support,r["terminalCamera"],pixels)
    filtered = end_samples["filteredD"]
    need((filtered["width"],filtered["height"]) == (480,270), "Terminal filtered dimensions differ")
    gx,gy = gi.T
    fd = plane(base/r["terminalDirectory"],filtered)[gy,gx]
    mask = np.fromfile(base/r["terminalDirectory"]/filtered["validity"]["file"],dtype=np.uint8).reshape(270,480)[gy,gx]
    filtered_valid = np.isfinite(fd).all(-1)&(fd[:,3]>0)&(mask>0)
    source = r["terminalSource"]
    need(source["workFrame"] == last["workFrame"] and source["engineFrame"] == last["engineFrame"] and source["diagnostics"]["lightSelected"] == 0 and source["cpuReadbackSeconds"] >= r["drainEndSeconds"], "Final GPU source query differs")
    need(all(source[key][k] == 0 for key in ("gpuProxyEmission","gpuWallEmission","gpuFloorEmission") for k in "xyz"), "A GPU source remains lit")
    def row(i):
        return dict(logical=int(i+120), elapsed=float(times[i]), oldGreenMeanRatio=float(mean_ratio[i]),
                    oldGreenWorstPointRatio=float(np.max(point_ratio[i])), temporalUnknownPoints=int(temporal_count[i]),
                    temporalQualified=bool(response_qualified[i]))
    deadline = {}
    for second,limit in ((1,.05),(2,.01)):
        before = np.flatnonzero(times<=second); after = np.flatnonzero(times>=second)
        met = len(before)>0 and response_qualified[before[-1]] and mean_ratio[before[-1]]<=limit
        kept = met and np.all(response_qualified[before[-1]:]) and np.all(mean_ratio[before[-1]:]<=limit)
        deadline[str(second)] = dict(before=row(before[-1]) if len(before) else None,after=row(after[0]) if len(after) else None,
                                    observedBeforeLimit=bool(met),remainingSourcesBelowLimit=bool(kept))
    windows = []
    for first in np.flatnonzero(times<=2):
        end = np.searchsorted(times,times[first]+.5)
        if end<len(times) and np.all(response_qualified[first:end+1]) and np.all(mean_ratio[first:end+1]<=.01) and np.max(np.diff(times[first:end+1]))<=2/30:
            windows.append(dict(start=float(times[first]),end=float(times[end]),span=float(times[end]-times[first]),firstLogical=int(first+120),lastLogical=int(end+120)))
            break
    cadence_ok = np.max(np.diff(times)) <= 2/30
    qualified = bool(all(d["observedBeforeLimit"] for d in deadline.values()) and windows and np.all(filtered_valid) and cadence_ok)
    result = dict(status="observed-decay-and-terminal-valid" if qualified else "insufficient-or-target-not-observed",
                  fullFrozenInputVerified=False,
                  inputDescriptorDeviation="Frozen text called the wall white; retained executed source sets its MPB BaseColor to (.5,.25,.125,1). Adopt actual brown-wall/white-floor fixture metrics only; all-white-wall condition is unverified.",
                  scope="One local bounded emitter switched off; no continuing source, Final HDR response plus temporal and terminal filtered qualification",
                  currentRawFreshness="not-observed", intermediateFilteredValidity="not-directly-observed",
                  finalPhysicalSourceTerm="zero; no requirement of finite-time bitwise zero", sourceLastLogical=int(r["finalLogical"]),
                  deadlines=deadline, firstObservedTemporalQualifiedOnePercentWindow=windows[0] if windows else None,
                  temporalUnknownPointSamples=int(np.sum(~temporal_valid[1:])), terminalFilteredUnknownPoints=int(np.sum(~filtered_valid)),
                  terminalFilteredMeanRgb=fd[:,:3].mean(0).tolist(),terminalFilteredMinAlpha=float(fd[:,3].min()),
                  terminalFinalMeanRgb=final[-1,:,:3].mean(0).tolist(),last=row(len(times)-1),
                  finalOtherChannelsMaximum=float(np.max(abs(final[1:,:,[0,2]]))),
                  sourceHz=float((len(times)-1)/(times[-1]-times[0])),intervalMedian=float(np.median(np.diff(times))),
                  intervalP95=float(np.quantile(np.diff(times),.95)),intervalMax=float(np.max(np.diff(times))),
                  peakPending=r["peakPendingReadbacks"],earlyEngineGap=r["earlyEngineGap"],earlySourceGap=r["earlySourceGap"],
                  baselineSupport=baseline_support,terminalSupport=end_floor,
                  terminalCaptureReceipt=dict(logical=end_receipt["logicalFrame"],work=end_receipt["workFrame"],engine=end_receipt["engineFrame"]),
                  finalReadbackMedianLatency=float(np.median([f["completionSeconds"]-f["sourceSeconds"] for f in rows[1:]])),
                  historyReadbackMedianLatency=float(np.median([f["historyCompletionSeconds"]-f["sourceSeconds"] for f in rows[1:]])),
                  terminalDrainSeconds=r["drainEndSeconds"]-r["drainStartSeconds"],frames=[row(i) for i in range(len(times))])
    np.savez_compressed(output/"signals.npz", final=final,history=history,temporal_valid=temporal_valid,elapsed=times,
                        terminal_filteredD=fd,terminal_filtered_valid=filtered_valid,points=pixels,gi=gi)
    return result


def main():
    p = argparse.ArgumentParser();p.add_argument("capture",type=Path);p.add_argument("output",type=Path);args=p.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    try:
        result=analyze(args.capture,args.output)
    except (ValueError,KeyError,IndexError,OSError) as e:
        result=dict(status="insufficient-input-or-record",error=str(e))
    (args.output/"result.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in result.items() if k!="frames"},ensure_ascii=False))


if __name__ == "__main__":
    main()
