"""Record the completed local denoise investigation without altering frozen evidence."""
import datetime
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from html import escape
import numpy as np

repo = Path(__file__).resolve().parents[2]
comparison = Path("I:/Unity test/Comparison")
project = Path("I:/Unity test/Project/Assets/HybridLumenGI")
evidence = comparison/"Evidence/local-denoise-01"
read = lambda p: json.loads(p.read_text(encoding="utf-8-sig"))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
ids = dict(diagnosticBaseline="20261027-152612-574958fa6ca74fe58416590f2e4c56ed",
           initialFix="20261027-152839-6d07e26d25944292a0c006b478319789",
           final="20261027-153457-43786b6cdf404df0bb43c9a24eafbb03")
runs = {}
for name, identifier in ids.items():
    path = comparison/"Results"/identifier
    data = read(path/"run.json")
    assert data["completedUtc"] and data["renderedFrames"] == data["requestedFrames"] and data["errors"] == 0
    assert data["status"] == "incomplete-probe" and not data["fullSequenceCompleted"]
    runs[name] = dict(path=str(path), **{k: data[k] for k in
        ["status", "requestedFrames", "renderedFrames", "captures", "errors", "fullSequenceCompleted", "firstRenderWaitSeconds"]})
baseline = comparison/"Results"/ids["diagnosticBaseline"]
final = comparison/"Results"/ids["final"]
receipts = [json.loads(line) for line in (final/"frames.jsonl").read_text(encoding="utf-8-sig").splitlines()]
diagnostics = [json.loads(row["diagnosticsJson"]) for row in receipts]
captures = list(final.glob("frame-*.rgba32f"))
integrity = dict(receipts=len(receipts), exactSoftwareFrames=sum(row["exactSoftwareGeometry"] for row in diagnostics),
                 captures=len(captures), allCapturesFinite=bool(all(np.isfinite(np.fromfile(path,dtype="<f4")).all() for path in captures)))
assert integrity["receipts"] == 420 and integrity["captures"] == 21 and integrity["allCapturesFinite"]
for name, before in [("paired", baseline), ("frozenEditor", comparison/"Results/20261027-142102-a159a5c31ae54f7e94b40c2b1cf6d20f")]:
    subprocess.run([sys.executable, str(repo/"LocalComparison/Harness/analyze-denoise.py"), str(before), str(final),
                    "--output", str(evidence/f"{name}-comparison.json")], check=True, stdout=subprocess.DEVNULL)
paired = read(evidence/"paired-comparison.json")
gpu = read(evidence/"gpu-regression.json")
assert gpu["passed"] and len(gpu["cases"]) == 5
product = []
changed = []
for item in read(repo/"Tests/runtime-validation-results.json")["productSources"]:
    filename = item["file"]
    value = sha(repo/filename)
    assert value == sha(project/filename), filename
    product.append(dict(file=filename, sha256=value))
    if value != item["sha256"]:
        changed.append(filename)
assert changed == ["Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl"], changed
source = repo/changed[0]
shutil.copy2(source, evidence/"HybridLumenGIKernels.final.hlsl")
(evidence/"product.patch").write_text("".join(difflib.unified_diff(
    (evidence/"HybridLumenGIKernels.before.hlsl").read_text().splitlines(True),
    source.read_text().splitlines(True), fromfile="candidate-16/"+changed[0], tofile="local-development/"+changed[0])), encoding="utf-8")
door = paired["frames"]["179"]["doorRoi"]
improvement = 1-door["after"]["neighborResidualRms"]/door["before"]["neighborResidualRms"]
mean_change = door["after"]["meanY"]/door["before"]["meanY"]-1
report = dict(revision="local-development-denoise-01", status="targeted-local-editor-validation",
    checkedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(), frozenBaseline="runtime-candidate-16",
    scope="Five actual CSTemporal GPU cases plus a 420-frame bounded Editor sequence, not a full 720-frame run or new Player build.",
    runs=runs, captureIntegrity=integrity, gpuRegression=gpu, pairedComparison=paired,
    priorEditorComparison=str(evidence/"frozenEditor-comparison.json"), productSources=product, changedProductFiles=changed,
    doorNeighborResidualReduction=improvement, doorMeanLuminanceRelativeChange=mean_change,
    playerBuildVerified=False, hardwareRunVerified=False, productionAccepted=False,
    limits=["Single-frame spatial noise metric is not temporal flicker/ghosting acceptance.",
            "Thin-wall ground truth, resource shutdown, GPU time/VRAM and broader support remain open.",
            "Final run stops at frame419; sealed-room/HLOD/old/off/SDF and frozen Player evidence were not rerun.",
            "Shader/driver startup and capture IO are not per-frame GI performance."])
for destination in [repo/"Tests/local-development-validation-results.json", evidence/"validation.json"]:
    destination.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
html = f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>本机动态GI降噪对照</title>
<style>body{{font:16px/1.65 system-ui;background:#11151b;color:#e5eaf1;max-width:1420px;margin:40px auto;padding:0 24px}}.pair{{display:grid;grid-template-columns:1fr 1fr;gap:20px}}img{{width:100%;display:block}}figure{{margin:0}}a{{color:#88c9ff}}small{{color:#a8b1c0}}</style>
<h1>本机动态GI降噪 · local-development-denoise-01</h1>
<p>相同设置、相同场景状态，第179帧。左：16版源码诊断运行；右：本轮修复。两侧均为真实Unity捕获，使用原有同一预览色调映射。</p>
<div class="pair"><figure><figcaption>修复前</figcaption><a href="{baseline.as_uri()}/frame-0179.png"><img src="{baseline.as_uri()}/frame-0179.png"></a></figure>
<figure><figcaption>修复后</figcaption><a href="{final.as_uri()}/frame-0179.png"><img src="{final.as_uri()}/frame-0179.png"></a></figure></div>
<p>灰板内部固定选区的邻域高频残差下降 {improvement:.1%}，平均线性亮度变化 {mean_change:+.2%}。滤波前GI历史最大绝对差为 {paired['frames']['179']['unfilteredHistoryMaxAbsDifference']}。</p>
<p>5项真实GPU回归通过；最终Editor按预定420帧完成，零采集错误。尚未验收时间闪烁、残影、薄壁物理正确性或生产性能。</p>
<p><a href="{(evidence/'paired-comparison.json').as_uri()}">配对统计</a> · <a href="{(evidence/'validation.json').as_uri()}">源码和运行证据</a></p>
<small>此前朋友包保持冻结；当前仅在本机开发，不重新交付。</small></html>'''
(evidence/"comparison.html").write_text(html, encoding="utf-8")
print(json.dumps(dict(changedProductFiles=changed, verifiedProductSources=len(product), runs=runs,
                     doorNeighborResidualReduction=improvement, doorMeanLuminanceRelativeChange=mean_change), indent=2))
