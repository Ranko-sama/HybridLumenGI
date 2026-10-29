"""Generate source-only primary visibility. Never opens a candidate manifest/RGB."""
from __future__ import annotations
import argparse
import json
import pathlib
import sys
import numpy as np
from loader import load, digest
from geometry import Camera, Scene, render_primary, LABELS


def write_json(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as file:
        json.dump(value, file, ensure_ascii=False, indent=2, allow_nan=False)
        file.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="Explicit physical source.json, not candidate.json")
    parser.add_argument("--state", required=True, help="Explicit source-only frame state containing CameraDescriptor")
    parser.add_argument("--input-root", help="Manifest-relative artifact root; defaults to source parent")
    parser.add_argument("--source-sha256")
    parser.add_argument("--state-sha256")
    parser.add_argument("--grid-width", type=int)
    parser.add_argument("--grid-height", type=int)
    parser.add_argument("--output", required=True, help="Fresh external directory; never overwritten")
    args = parser.parse_args(argv)
    output = pathlib.Path(args.output).resolve()
    root = pathlib.Path(args.input_root or pathlib.Path(args.source).parent).resolve()
    if output.is_relative_to(root) or root.is_relative_to(output):
        parser.error("Output and input root must be disjoint")
    output.mkdir(parents=True, exist_ok=False)
    try:
        inputs = load(args.source, args.state, root, args.source_sha256, args.state_sha256)
        camera = Camera(inputs["state"]["camera"])
        if (args.grid_width is None) != (args.grid_height is None):
            raise ValueError("Specify both grid dimensions, or neither")
        width, height = (args.grid_width, args.grid_height) if args.grid_width is not None else (camera.width, camera.height)
        scene = Scene(inputs["state"]["dynamicState"])
        result = render_primary(scene, camera, width, height, inputs["unsupported"])
        array_path = output / "primary.npz"
        with array_path.open("xb") as file: np.savez_compressed(file, **result)
        write_json(output / "geometry-index.json", dict(objects=scene.objects, triangles=scene.records,
                    excluded=scene.excluded, unsupported=scene.unsupported))
        write_json(output / "input-accesses.json", inputs["accesses"])
        implementation = []
        for name in ("loader.py", "geometry.py", "primary.py"):
            path = pathlib.Path(__file__).parent / name
            implementation.append(dict(path=str(path.resolve()), sha256=digest(path.read_bytes())))
        counts = {label: int(np.count_nonzero(result["classification"] == index)) for index, label in enumerate(LABELS)}
        owner_counts = []
        for index, obj in enumerate(scene.objects):
            center = result["owner"] == index
            owner_counts.append(dict(key=obj["key"], name=obj["name"], centerHits=int(center.sum()),
                                     receiver=int(np.count_nonzero(center & (result["classification"] == 1)))))
        report = dict(schema="hlgi-validation-source-primary-v1", status="generated-source-domain",
                      qualityVerdict=None, physicalReference=False, gpuRasterEquivalence=False,
                      sourceSha256=inputs["source_sha256"], stateSha256=inputs["state_sha256"],
                      logicalFrame=inputs["state"]["logicalFrame"], camera=inputs["state"]["camera"],
                      width=width, height=height, fullWidth=camera.width, fullHeight=camera.height,
                      vpConditionNumber=camera.condition, sourceUnsupported=inputs["unsupported"],
                      geometryUnsupported=scene.unsupported, counts=counts, owners=owner_counts,
                      primaryReprojectionMaxUvResidual=float(result["reprojectionUvResidual"].max()),
                      sampling="integer fullPixel=floor((2*gridPixel+1)*fullSize/(2*gridSize)); full pixel center; no jitter added twice",
                      scope="Opaque stock Lit static MeshRenderer primary visibility from source geometry. No candidate RGB, mask, support or HLGI cache is an input.",
                      boundary="half-full-pixel Euclidean band around all homogeneous-clipped source triangle edges, including hidden edges/diagonals; closest-hit float64 ties retained",
                      numericScope="float64 source-pinhole result, not a certified GPU float32/raster/depth error envelope; fixed 64/128 float64-epsilon degeneracy/tie guards; no quality threshold",
                      noHitEncoding="triangle=-1, owner=-1, finite zero position/normal/uv/depth/distance placeholders; classification is mandatory",
                      rowOrder=inputs["state"]["camera"]["rowOrder"], displayTransform="none; no raw flip from appearance or m11 sign",
                      implementation=implementation, artifacts=[])
        for name in ("primary.npz", "geometry-index.json", "input-accesses.json"):
            path = output / name
            report["artifacts"].append(dict(file=name, sha256=digest(path.read_bytes()), bytes=path.stat().st_size))
        write_json(output / "report.json", report)
        print(json.dumps(dict(status=report["status"], logicalFrame=report["logicalFrame"], counts=counts,
                              sourceSha256=report["sourceSha256"], output=str(output), qualityVerdict=None)))
        return 0
    except Exception as error:
        write_json(output / "failure.json", dict(status="invalid-input-or-tool-failure", error=type(error).__name__ + ": " + str(error), qualityVerdict=None))
        raise


if __name__ == "__main__":
    sys.exit(main())
