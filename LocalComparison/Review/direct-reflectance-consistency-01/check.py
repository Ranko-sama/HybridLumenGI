"""Bounded equation check using the existing paired-function WARP adapter/host.

No Unity traversal, raster proof, hashes, new host, or parameter sweep.
"""
import importlib.util
import json
import math
from pathlib import Path
import struct
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASELINE = "128a62b"
prior_path = HERE.parent / "zero-diffuse-known-radiance-01/check.py"
spec = importlib.util.spec_from_file_location("existing_adapter", prior_path)
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)


def main():
    out = HERE / "output"
    out.mkdir(exist_ok=False)
    report = dict(baseline=BASELINE, status="running", observations=[], commands=[],
                  scope="Actual ProxyRadiance/TraceScreen bodies with fixed known material/direct/cache inputs. No raster, traversal or full-scene claim.")

    def command(name, args):
        result = subprocess.run([str(x) for x in args], cwd=ROOT, capture_output=True, timeout=300)
        (out / (name + ".log")).write_bytes(result.stdout + result.stderr)
        report["commands"].append(dict(name=name, exitCode=result.returncode))
        if result.returncode:
            raise RuntimeError(name + " failed")
        return result.stdout.decode("utf-8-sig")

    try:
        functions = []
        for filename, name, kind in [("HybridLumenGITransport.hlsl", "ProxyRadiance", "float3"),
                                      ("HybridLumenGIKernels.hlsl", "TraceScreen", "bool")]:
            old = command("baseline-" + name, ["git", "show", BASELINE + ":Runtime/Resources/HybridLumenGI/" + filename])
            new = (prior.GPU / filename).read_text(encoding="utf-8-sig")
            for suffix, source in [("Old", old), ("New", new)]:
                body = prior.extract_function(source, name, kind)
                functions.append(body.replace(name + "(", name + suffix + "(", 1))
            if name == "ProxyRadiance":
                structures = prior.extract_struct(new, "HLGIProxy") + "\n" + prior.extract_struct(new, "HLGICacheEntry")
        fixture = prior.ADAPTER.replace("__STRUCTURES__", structures).replace("__FUNCTIONS__", "\n".join(functions))
        fixture = fixture.replace("active=Inputs[id.x];Output o=(Output)0;",
                                  "active=Inputs[id.x];_HLGI_BounceFeedback=active.options.z;Output o=(Output)0;")
        (out / "Fixture.hlsl").write_text(fixture, encoding="utf-8")
        rows = []
        # Unit rho direct reflection must match the screen path. Only feedback
        # retains the 0.98 cap. These fixed input values are not scene truth.
        cases = [
            ("direct-only", (1, .99, .96), (0, 0, 0), True, True),
            ("direct-and-cache", (1, .99, .96), (1, 2, 4), True, True),
            ("ordinary-reflectance", (.5, .25, .125), (1, 2, 4), True, True),
            ("zero-retains-emission", (0, 0, 0), (1, 2, 4), False, False),
            ("unknown-direct", (1, .99, .96), (1, 2, 4), False, True),
            ("unknown-cache", (1, .99, .96), (1, 2, 4), True, False),
        ]
        le, direct = (.125, .25, .5), (2, 4, 8)
        for name, rho, cache, direct_known, cache_known in cases:
            nonanalytic = tuple(x * .5 for x in cache)
            feedback = 0 if name == "direct-only" else 1
            for consumer in (0, 1):
                zero = all(x == 0 for x in rho)
                known = zero or (direct_known and cache_known)
                vectors = [(consumer, int(direct_known), int(cache_known), 1),
                           (*le, 1), (*rho, 1), (*direct, 0), (*cache, 0),
                           (*nonanalytic, 0), (1, 1, feedback, 0)] + [(0, 0, 0, 0)] * 4
                # Baseline world incorrectly caps the direct term; baseline
                # screen leaves the feedback uncapped. Candidate must agree.
                old_rho = [min(x, .98) if consumer == 0 else x for x in rho]
                expected_old = [le[i] + old_rho[i] * (direct[i] + cache[i]) for i in range(3)] if known else [0] * 3
                expected_new = [le[i] + rho[i] * direct[i] + min(rho[i], .98) * cache[i] for i in range(3)] if known else [0] * 3
                expected_nonanalytic = [le[i] + min(rho[i], .98) * nonanalytic[i] for i in range(3)] if known else [0] * 3
                rows.append(dict(name=name, consumer="world" if consumer == 0 else "screen",
                                 input=[v for vector in vectors for v in vector],
                                 old=expected_old + [int(known)], new=expected_new + [int(known)],
                                 nonAnalytic=expected_nonanalytic))
        (out / "inputs.bin").write_bytes(struct.pack("<I", len(rows)) + b"".join(struct.pack("<44f", *r["input"]) for r in rows))
        (out / "fixed-inputs.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
        host = Path(json.loads(prior.HOST_RECEIPT.read_text(encoding="utf-8-sig"))["files"]["exe"]["path"])
        if not host.is_file():
            raise FileNotFoundError(host)
        command("compile", [prior.DXC, "-HV", "2018", "-T", "cs_6_0", "-E", "CSZeroDiffuse", "-O3",
                            "-I", prior.GPU, "-Fo", out / "fixture.dxil", out / "Fixture.hlsl"])
        command("dispatch", [host, out / "fixture.dxil", out / "inputs.bin", out / "outputs.bin"])
        raw = (out / "outputs.bin").read_bytes()
        if len(raw) != len(rows) * 64:
            raise ValueError("Unexpected output length")
        close = lambda a, b: math.isfinite(a) and abs(a - b) <= 2e-6 * max(1, abs(b))
        for i, row in enumerate(rows):
            actual = struct.unpack_from("<16f", raw, i * 64)
            expected = row["old"] + row["new"]
            passed = all(close(a, b) for a, b in zip(actual[:8], expected))
            if row["consumer"] == "world":
                passed = passed and all(close(a, b) for a, b in zip(actual[8:11], row["nonAnalytic"]))
            # The dependency mask checks the called set, not call order/count.
            passed = passed and actual[12] == actual[13]
            report["observations"].append(dict(name=row["name"], consumer=row["consumer"],
                                               expected=expected, actual=actual, passed=passed))
        report["status"] = "passed" if all(r["passed"] for r in report["observations"]) else "failed"
        if report["status"] != "passed":
            raise AssertionError([r["name"] + ":" + r["consumer"] for r in report["observations"] if not r["passed"]])
    except Exception as error:
        report["status"] = "failed"
        report["error"] = repr(error)
        raise
    finally:
        (out / "result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(str(out / "result.json"))


if __name__ == "__main__":
    main()
