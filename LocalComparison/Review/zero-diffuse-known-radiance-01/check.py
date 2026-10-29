"""One fixed paired-function DXC/WARP check. Running this file creates output/ once.

No traversal, Unity run, new host, hashes, or full-shader compile matrix. The
original function bodies are extracted verbatim, changing only their names.
Unknown RGB has no numerical contract and is explicitly canonicalized to zero
inside the fixture; no NaN equality is used to pass an observation.
"""
import json
import math
from pathlib import Path
import re
import struct
import subprocess


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GPU = ROOT / "Runtime/Resources/HybridLumenGI"
BASELINE = "4af432f"
DXC = Path("C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/dxc.exe")
HOST_RECEIPT = ROOT / "LocalComparison/Review/temporal-reactive-history-limit-01/host-reuse.json"
ZERO = (0.0, 0.0, 0.0)
LE = (.125, .25, .5)
RHO = (.5, .25, .125)
TOTAL = (1.625, 1.75, 2.0)
NON_ANALYTIC = (.375, .5, .75)
HALF_LE = (.0625, .125, .25)


def extract_function(source, name, return_type):
    # The first ProxyRadiance overload is the six-argument main implementation.
    start = re.search(r"^" + return_type + r"\s+" + name + r"\(", source, re.M)
    if start is None:
        raise ValueError("Missing function: " + name)
    brace = source.index("{", start.start())
    depth = 0
    for end in range(brace, len(source)):
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
            if depth == 0:
                return source[start.start():end + 1]
    raise ValueError("Unclosed function: " + name)


def extract_struct(source, name):
    found = re.search(r"struct\s+" + name + r"\s*\{[^}]*\};", source)
    if found is None:
        raise ValueError("Missing structure: " + name)
    return found.group(0)


def fixed_cases():
    rows = []

    def add(name, consumer, old_rgb, old_conf, new_rgb, new_conf,
            old_mask, new_mask, *, diffuse=ZERO, emission=LE, direct=True,
            cache=True, qualified=True, ao=1.0, emission_weight=.5,
            resolve=True, new_non_analytic=ZERO, positive_control=False):
        # 11 float4 / 176 bytes: the existing host's input stride.
        emission_alpha = 1.0 if consumer == 0 or qualified else 0.0
        vectors = [
            (consumer, int(direct), int(cache), int(qualified)),
            (*emission, emission_alpha), (*diffuse, ao),
            (2.0, 4.0, 8.0, 0.0), (1.0, 2.0, 4.0, 0.0),
            (.5, 1.0, 2.0, 0.0), (int(resolve), emission_weight, 0.0, 0.0),
            (0.0,) * 4, (0.0,) * 4, (0.0,) * 4, (0.0,) * 4,
        ]
        if consumer == 0:
            detail = (*new_non_analytic, 0.0)
        else:
            hit = 1.0 if qualified else 0.0
            t = 1.0 if qualified else 4.0
            detail = (t, t, hit, hit)
        expected = (*old_rgb, old_conf, *new_rgb, new_conf,
                    *detail, old_mask, new_mask, 0.0, 0.0)
        rows.append(dict(name=name, consumer="world" if consumer == 0 else "screen",
                         input=[v for vector in vectors for v in vector],
                         expected=expected, positiveControl=positive_control))

    # Masks: material=1, screen-world match=2, direct=4, cache=8, owner=16.
    # World evaluates cache before direct; screen evaluates direct before cache.
    add("world-zero-direct-unknown", 0, ZERO, 0, HALF_LE, 1, 29, 17,
        direct=False, new_non_analytic=HALF_LE)
    add("world-zero-cache-unknown", 0, ZERO, 0, HALF_LE, 1, 25, 17,
        cache=False, new_non_analytic=HALF_LE)
    add("world-zero-known-black", 0, ZERO, 0, ZERO, 1, 29, 17,
        direct=False, emission=ZERO)
    add("world-positive-known", 0, TOTAL, 1, TOTAL, 1, 29, 29,
        diffuse=RHO, emission_weight=1, new_non_analytic=NON_ANALYTIC,
        positive_control=True)
    add("world-tiny-positive-unknown", 0, ZERO, 0, ZERO, 0, 29, 29,
        diffuse=(2 ** -20,) * 3, direct=False)
    add("world-material-unknown", 0, ZERO, 0, ZERO, 0, 16, 16,
        qualified=False)
    add("world-nonfinite-emission", 0, ZERO, 0, ZERO, 0, 29, 17,
        emission=(float("nan"), .25, .5))
    add("world-nonfinite-ao", 0, ZERO, 0, ZERO, 0, 29, 17,
        ao=float("nan"))
    add("world-negative-clamps-zero", 0, ZERO, 0, HALF_LE, 1, 29, 17,
        diffuse=(-.5, -.25, -.125), direct=False, new_non_analytic=HALF_LE)

    add("screen-zero-direct-unknown", 1, ZERO, 0, LE, 1, 6, 0, direct=False)
    add("screen-zero-cache-unknown", 1, ZERO, 0, LE, 1, 14, 0, cache=False)
    add("screen-zero-known-black", 1, ZERO, 0, ZERO, 1, 6, 0,
        direct=False, emission=ZERO)
    add("screen-positive-known", 1, TOTAL, 1, TOTAL, 1, 14, 14,
        diffuse=RHO, positive_control=True)
    add("screen-tiny-positive-unknown", 1, ZERO, 0, ZERO, 0, 6, 6,
        diffuse=(2 ** -20,) * 3, direct=False)
    add("screen-material-unqualified", 1, ZERO, 0, ZERO, 0, 0, 0,
        qualified=False)
    add("screen-nonfinite-emission", 1, ZERO, 0, ZERO, 0, 14, 0,
        emission=(float("nan"), .25, .5))
    # Endpoint-only output is intentionally unused radiance, not a black oracle.
    add("screen-endpoint-only", 1, ZERO, 1, ZERO, 1, 0, 0,
        direct=False, cache=False, resolve=False)
    add("screen-nonfinite-ao", 1, ZERO, 0, ZERO, 0, 14, 0,
        ao=float("nan"))
    return rows


ADAPTER = r'''
#include "HybridLumenGIHit.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
__STRUCTURES__
struct HLGIRayFootprint { float unused; };
struct HLGISurfaceSample {
    float3 diffuse,emission,normal,geometricNormal;
    float occlusion,confidence;
};
struct Input {
    float4 control,emission,diffuse,direct,cached,nonAnalyticCached,options;
    float4 reserved0,reserved1,reserved2,reserved3;
};
struct Output { float4 oldValue,newValue,detail,calls; };
StructuredBuffer<Input> Inputs:register(t0);
RWStructuredBuffer<Output> Outputs:register(u0);
cbuffer Counts:register(b0) { uint Count; }
static Input active;
static uint dependencyMask;
static HLGIProxy _HLGI_Proxies[1];
static uint4 _HLGI_LightingPolicies[1];
static int _HLGI_ScreenSteps=1,_HLGI_NativeComposition=0;
static float _HLGI_RayBias=.03125,_HLGI_Thickness=.15,_HLGI_BounceFeedback=1;
static float4 _HLGI_MaterialView=float4(0,0,0,1);
static float4x4 _HLGI_InvVP;
static float3 screenP;
SamplerState sampler_PointClamp;
struct ScalarTexture {
    float SampleLevel(SamplerState s,float2 uv,float mip) { return .5; }
};
struct EmissionTexture {
    float4 SampleLevel(SamplerState s,float2 uv,float mip) { return active.emission; }
};
struct DiffuseTexture {
    float4 SampleLevel(SamplerState s,float2 uv,float mip) { return active.diffuse; }
};
struct PolicyTexture {
    void GetDimensions(out uint width,out uint height) { width=height=1; }
    uint2 Load(int3 pixel) { return uint2(1,1); }
};
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static EmissionTexture _HLGI_Emission;
static DiffuseTexture _HLGI_Diffuse;
static PolicyTexture _HLGI_ReceiverPolicy;

bool HLGIHitOwnerCurrent(HLGIHit hit) { dependencyMask|=16u;return true; }
bool HLGITrySurfaceMaterialHit(HLGIHit hit,out HLGISurfaceSample surface) {
    dependencyMask|=1u;surface=(HLGISurfaceSample)0;
    surface.diffuse=active.diffuse.rgb;surface.emission=active.emission.rgb;
    surface.normal=surface.geometricNormal=float3(0,0,-1);
    surface.occlusion=active.diffuse.a;surface.confidence=1;return true;
}
bool HLGICachedSurface(int owner,float3 p,float3 ng,float3 ns,HLGISurfaceSample surface,
                      out HLGICacheEntry cached,out bool known) {
    dependencyMask|=8u;cached=(HLGICacheEntry)0;
    cached.irradiance=float4(active.cached.rgb,2);
    cached.nonAnalyticIrradiance=float4(active.nonAnalyticCached.rgb,0);
    known=active.control.z!=0;return true;
}
float3 DirectIrradiance(float3 p,float3 n,float3 ng,uint2 layers,bool shadows,
                        float3 ray,HLGIRayFootprint footprint,out bool known) {
    dependencyMask|=4u;known=active.control.y!=0;return active.direct.rgb;
}
float3 CachedIrradiance(HLGIHit hit,float3 n,out bool known) {
    dependencyMask|=8u;known=active.control.z!=0;return active.cached.rgb;
}
// Same ScreenPoint/texture adapter as StandaloneScreenEndpoint: one captured
// plane at t=1, identical marching and binary refinement for both functions.
bool ScreenPoint(float3 origin,float3 dir,float t,out float2 uv,out float delta,out float3 p) {
    screenP=origin+dir;uv=.5;delta=t-1;p=screenP;return true;
}
float3 NormalAt(float2 uv) { return float3(0,0,-1); }
bool ValidDepth(float d) { return d>0&&d<1; }
float3 WorldPosition(float2 uv,float depth,float4x4 matrix) { return screenP; }
bool HLGITryScreenGeometricNormal(float2 uv,float raw,float3 p,out float3 n) {
    n=NormalAt(uv);return true;
}
bool HLGITryScreenWorldMatch(float2 uv,float raw,float3 p,float3 n,out HLGIHit hit) {
    dependencyMask|=2u;hit=(HLGIHit)0;hit.rawNg=n;return true;
}
bool HLGITryScreenRayFootprint(float2 uv,float raw,float3 p,float3 ray,out HLGIRayFootprint footprint) {
    footprint.unused=0;return true;
}
__FUNCTIONS__
[numthreads(64,1,1)]
void CSZeroDiffuse(uint3 id:SV_DispatchThreadID) {
    if(id.x>=Count)return;
    active=Inputs[id.x];Output o=(Output)0;
    _HLGI_Proxies[0]=(HLGIProxy)0;
    _HLGI_Proxies[0].albedo=active.diffuse;
    _HLGI_Proxies[0].emission=active.emission;
    _HLGI_LightingPolicies[0]=uint4(1,1,0,0);
    if(active.control.x==0) {
        HLGIHit hit=(HLGIHit)0;
        hit.t=1;hit.position=float3(0,0,1);hit.rawNg=hit.shadingNormal=float3(0,0,-1);
        hit.ownerSlot=0;hit.stableId=hit.ownerRevision=hit.geometryRevision=1;
        hit.representation=HLGI_REPRESENTATION_TRIANGLE;
        hit.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE|HLGI_HIT_UV_MATERIAL|
                  HLGI_HIT_SHADING_NORMAL|HLGI_HIT_ORIENTED_NG;
        if(active.control.w==0)hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
        hit.materialDiffuse=active.diffuse.rgb;hit.materialEmission=active.emission.rgb;
        hit.materialOcclusion=active.diffuse.a;hit.materialReceivesShadows=1;
        HLGIRayFootprint footprint;footprint.unused=0;
        float oldConfidence,newConfidence;float3 oldN,newN;
        dependencyMask=0;
        float3 oldRGB=ProxyRadianceOld(hit,float3(0,0,1),footprint,active.options.y,oldConfidence,oldN);
        uint oldMask=dependencyMask;dependencyMask=0;
        float3 newRGB=ProxyRadianceNew(hit,float3(0,0,1),footprint,active.options.y,newConfidence,newN);
        // Unknown RGB is explicitly outside the product's numerical contract.
        if(!(oldConfidence>0))oldRGB=0;
        if(!(newConfidence>0)) { newRGB=0;newN=0; }
        o.oldValue=float4(oldRGB,oldConfidence);o.newValue=float4(newRGB,newConfidence);
        o.detail=float4(newN,0);o.calls=float4(oldMask,dependencyMask,0,0);
    } else {
        float3 oldRGB,newRGB;float oldT,newT;bool oldKnown,newKnown;
        dependencyMask=0;
        bool oldHit=TraceScreenOld(0,float3(0,0,1),4,oldRGB,oldT,oldKnown,active.options.x!=0);
        uint oldMask=dependencyMask;dependencyMask=0;
        bool newHit=TraceScreenNew(0,float3(0,0,1),4,newRGB,newT,newKnown,active.options.x!=0);
        if(!oldKnown||!oldHit)oldRGB=0;
        if(!newKnown||!newHit)newRGB=0;
        o.oldValue=float4(oldRGB,oldHit&&oldKnown?1:0);
        o.newValue=float4(newRGB,newHit&&newKnown?1:0);
        o.detail=float4(oldT,newT,oldHit?1:0,newHit?1:0);
        o.calls=float4(oldMask,dependencyMask,0,0);
    }
    Outputs[id.x]=o;
}
'''


def json_safe(value):
    if isinstance(value, float) and not math.isfinite(value):
        return "qNaN" if math.isnan(value) else str(value)
    if isinstance(value, dict):
        return {k: json_safe(v) for k, v in value.items()}
    if isinstance(value, (tuple, list)):
        return [json_safe(v) for v in value]
    return value


def main():
    out = HERE / "output"
    # The first run and any failure are retained; never overwrite or retry here.
    out.mkdir(exist_ok=False)
    report = dict(status="running", baseline=BASELINE, commands=[], observations=[],
                  scope="Fixed local material/direct/cache inputs; not traversal or Unity integration.",
                  outputLayout=["old RGB/confidence", "new RGB/confidence",
                                "world new nonAnalytic RGB/0 OR screen oldT/newT/oldHit/newHit",
                                "old dependency mask/new dependency mask/0/0"],
                  dependencyBits=dict(material=1, screenWorldMatch=2, direct=4, cache=8, owner=16),
                  unknownRGB="Explicit zero canonicalization in fixture; no numerical contract.",
                  screenConfidence="hit && known; endpoint-only RGB is unused, not measured black.")

    def save():
        (out / "result.json").write_text(json.dumps(json_safe(report), indent=2, allow_nan=False) + "\n", encoding="utf-8")

    def command(label, argv):
        argv = [str(x) for x in argv]
        receipt = dict(label=label, argv=argv, status="started")
        report["commands"].append(receipt)
        save()
        try:
            result = subprocess.run(argv, cwd=ROOT, capture_output=True, timeout=300)
        except subprocess.TimeoutExpired as error:
            (out / (label + ".log")).write_bytes((error.stdout or b"") + (error.stderr or b""))
            receipt["status"] = "timeout"
            save()
            raise
        (out / (label + ".log")).write_bytes(result.stdout + result.stderr)
        receipt.update(status="completed", exitCode=result.returncode)
        save()
        if result.returncode != 0:
            raise RuntimeError(label + " failed: " + str(result.returncode))
        return result.stdout.decode("utf-8-sig")

    try:
        functions = []
        structures = None
        for filename, name, return_type in [
            ("HybridLumenGITransport.hlsl", "ProxyRadiance", "float3"),
            ("HybridLumenGIKernels.hlsl", "TraceScreen", "bool"),
        ]:
            relative = "Runtime/Resources/HybridLumenGI/" + filename
            old = command("baseline-" + name, ["git", "show", BASELINE + ":" + relative])
            new = (GPU / filename).read_text(encoding="utf-8-sig")
            for suffix, source in [("Old", old), ("New", new)]:
                original = extract_function(source, name, return_type)
                if name == "ProxyRadiance" and "out float3 nonAnalytic)" not in original.split("{", 1)[0]:
                    raise ValueError("Expected the real six-argument ProxyRadiance overload")
                (out / (name + suffix + ".hlsl.txt")).write_text(original, encoding="utf-8")
                functions.append(original.replace(name + "(", name + suffix + "(", 1))
            if name == "ProxyRadiance":
                cache_struct = extract_struct(new, "HLGICacheEntry")
                if cache_struct != extract_struct(old, "HLGICacheEntry"):
                    raise ValueError("Baseline/candidate cache layout differs")
                structures = extract_struct(new, "HLGIProxy") + "\n" + cache_struct
        fixture = ADAPTER.replace("__STRUCTURES__", structures).replace("__FUNCTIONS__", "\n\n".join(functions))
        (out / "Fixture.hlsl").write_text(fixture, encoding="utf-8")
        cases = fixed_cases()
        if len(cases) != 18 or any(len(row["input"]) != 44 or len(row["expected"]) != 16 for row in cases):
            raise ValueError("Fixed case count or host ABI changed")
        (out / "fixed-inputs-and-expectations.json").write_text(json.dumps(json_safe(cases), indent=2, allow_nan=False) + "\n", encoding="utf-8")
        (out / "inputs.bin").write_bytes(struct.pack("<I", len(cases)) + b"".join(struct.pack("<44f", *row["input"]) for row in cases))
        exe = Path(json.loads(HOST_RECEIPT.read_text(encoding="utf-8-sig"))["files"]["exe"]["path"])
        if not exe.is_file():
            raise FileNotFoundError("The existing host is unavailable: " + str(exe))
        report["host"] = str(exe)
        report["rows"] = len(cases)
        command("fixture-compile", [DXC, "-HV", "2018", "-T", "cs_6_0", "-E", "CSZeroDiffuse",
                                    "-O3", "-I", GPU, "-Fo", out / "fixture.dxil", out / "Fixture.hlsl"])
        command("warp-dispatch", [exe, out / "fixture.dxil", out / "inputs.bin", out / "outputs.bin"])
        raw = (out / "outputs.bin").read_bytes()
        if len(raw) != len(cases) * 64:
            raise ValueError("Output length is not 18 x 64 bytes: " + str(len(raw)))
        for index, row in enumerate(cases):
            record = raw[index * 64:(index + 1) * 64]
            actual = struct.unpack("<16f", record)
            finite = all(math.isfinite(v) for v in actual)
            byte_equal = record[:16] == record[16:32]
            passed = finite and actual == tuple(row["expected"])
            if row["positiveControl"]:
                passed = passed and byte_equal and actual[12] == actual[13]
            report["observations"].append(dict(name=row["name"], expected=row["expected"], actual=actual,
                                              finite=finite, positiveControl=row["positiveControl"],
                                              oldNewValueByteEqual=byte_equal, passed=passed))
        failed = [row["name"] for row in report["observations"] if not row["passed"]]
        report["failedCases"] = failed
        if failed:
            report["firstFailure"] = failed[0]
            raise AssertionError("Fixed expectation failed: " + ", ".join(failed))
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = repr(error)
        raise
    finally:
        save()
        print(str(out / "result.json"))


if __name__ == "__main__":
    main()
