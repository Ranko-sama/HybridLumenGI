"""Extend the existing finite observer with CPU cadence and existing DXGI memory."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
s = (ROOT / "LocalComparison/Harness/UnifiedSampleGpuCost.cs").read_text(encoding="utf-8-sig")


def replace(old, new):
    global s
    if s.count(old) != 1:
        raise RuntimeError("Ambiguous existing observer anchor: " + old)
    s = s.replace(old, new)


replace("    double startupTime;Frame anchor;bool finishing,finished,subscribed;",
        "    double startupTime;Frame anchor;bool finishing,finished,subscribed;\n"
        "    HybridLumenGIVideoMemory.Snapshot memoryWindow;bool memoryWindowCaptured;")
replace("        public int index,engineFrame,giFrame,width,height,fullWidth,fullHeight,generation,stage;",
        "        public double callbackSeconds;\n        public int index,engineFrame,giFrame,width,height,fullWidth,fullHeight,generation,stage;")
replace("        public bool measureOnly,adaptive;public float targetMs;",
        "        public bool measureOnly,adaptive;public float targetMs;\n"
        "        public bool memoryWindowCaptured;public HybridLumenGIVideoMemory.Snapshot memoryWindow;\n"
        '        public string cadenceMeaning="CPU time between consecutive target-camera endCameraRendering callbacks; not CPU busy time, actual Present timing or full-frame GPU duration.";')
replace("            host.sample.ShowControls=false;", "            host.sample.ShowControls=false;host.sample.MeasureVideoMemory=false;")
replace("        if(camera!=targetCamera||finishing||finished)return;",
        "        if(camera!=targetCamera||finishing||finished)return;\n        double callbackSeconds=Time.realtimeSinceStartupAsDouble;")
replace("            var r=new Frame{index=count,engineFrame=Time.frameCount,", "            var r=new Frame{callbackSeconds=callbackSeconds,index=count,engineFrame=Time.frameCount,")
replace("if(readyStreak==16){start=Time.frameCount+1;end=start+Window-1;startLedger=sample.CaptureLedger();}",
        "if(readyStreak==16){start=Time.frameCount+1;end=start+Window-1;startLedger=sample.CaptureLedger();sample.MeasureVideoMemory=true;}")
replace("                if(Time.frameCount==end+Drain)finishing=true;",
        "                if(Time.frameCount==end)\n"
        "                { memoryWindow=sample.CaptureLedger().processVideoMemory;memoryWindowCaptured=true;sample.MeasureVideoMemory=false; }\n"
        "                if(Time.frameCount==end+Drain)finishing=true;")
replace("                outputDirectory=directory,frames=count,", "                memoryWindowCaptured=memoryWindowCaptured,memoryWindow=memoryWindow,\n                outputDirectory=directory,frames=count,")
replace("        finally{Application.Quit(failure==null?0:1);}", "        finally{if(sample)sample.MeasureVideoMemory=false;Application.Quit(failure==null?0:1);}")
s = s.replace("whole-app GPU time and total driver VRAM", "whole-app GPU time, actual Present timing, instantaneous VRAM peak and GI-exclusive allocation")
s = s.replace("existing native ReceiverCapture/Transport/Composite completions only. No image or per-frame file IO.",
              "existing native ReceiverCapture/Transport/Composite completions, CPU callback cadence and existing DXGI process-memory sampling. No image or per-frame file IO.")
observer = HERE / "UnifiedSampleGpuCost.cs"
if observer.exists():
    raise RuntimeError("Preserve existing observer")
observer.write_text(s, encoding="utf-8")

build = (ROOT / "LocalComparison/Implementation/BuildUnifiedSampleGpuCost.ps1").read_text(encoding="utf-8-sig")
build = build.replace("UnifiedRelease75Cost", "LocalRelease83Baseline").replace("hlgi-release75-cost-settings-", "hlgi-release83-baseline-")
build = build.replace("../Harness/UnifiedSampleGpuCost.cs", "UnifiedSampleGpuCost.cs")
build = build.replace("finally {", "finally {\n    if (Get-Process Unity -ErrorAction SilentlyContinue) { throw \"Unity still owns this project; preserve the temporary observer and backup at $backup.\" }")
(HERE / "build.ps1").write_text(build, encoding="utf-8")
print("Prepared current-product observer/build adaptation. No build or Player started.")
