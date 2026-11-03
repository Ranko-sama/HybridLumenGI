"""Read one fixed seam observation; no Unity launch or input mutation."""
import argparse
import json
from pathlib import Path

import numpy as np


def vec(value, names):
    return np.array([value[n] for n in names], dtype=np.float64)


def expected_xy(matrix, rect, width, height):
    yy, xx = np.mgrid[:height, :width]
    uv = np.stack(((xx + .5) / width, (yy + .5) / height), -1)
    card_xy = (uv - rect[:2]) / rect[2:]
    return (card_xy - matrix[:2, 3]) @ np.linalg.inv(matrix[:2, :2]).T


def source_uv(xy, side):
    return np.stack((xy[..., 0] + 1, xy[..., 1]), -1) if side == 0 else np.stack((xy[..., 1], 1 - xy[..., 0]), -1)


def sample(texture, uv):
    size = np.array([texture.shape[1], texture.shape[0]])
    address = np.clip(np.floor(uv * size).astype(int), 0, size - 1)
    return texture[address[..., 1], address[..., 0], :3] * .96


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    manifest = args.capture / "capture.json"
    if not manifest.exists():
        manifest = args.capture / "result.json"
    r = json.loads(manifest.read_text(encoding="utf-8-sig"))
    assert r["status"] == "collected" and r["restored"], "Collection incomplete"
    assert r["sourceReloaded"] and r["captureSubassetReloaded"], "Missing persisted source reload"
    assert r["reopenedProject"] and r["prepareProcessId"] != r["captureProcessId"]
    assert r["api"] == "Direct3D12" and r["colorSpace"] == "Linear"
    assert np.allclose(np.array(r["localToWorld"]).reshape(4, 4), np.eye(4), rtol=0, atol=0)
    assert r["patchGrid"] == 4 and r["tileResolution"] == 64 and len(r["charts"]) == 2
    assert len(r["submeshes"]) == 2 and len(r["bindings"]) == 4
    if (args.capture / "signals.npz").exists():
        with np.load(args.capture / "signals.npz") as saved:
            planes = {"diffuse": saved["diffuse"], "position": saved["position"], "emissionValidity": saved["emission"]}
            packed_anchors = saved["anchors"]
    else:
        planes = {p["file"].split(".")[0]: np.fromfile(args.capture / p["file"], dtype="<f4").reshape(p["height"], p["width"], 4) for p in r["atlases"]}
        packed_anchors = np.fromfile(args.capture / r["anchorsFile"], dtype="<i4").reshape(-1, 2)
    diffuse, position, emission = (planes[key] for key in ("diffuse", "position", "emissionValidity"))
    height, width, _ = diffuse.shape
    assert all(p.shape == diffuse.shape for p in planes.values())
    textures = []
    for material in r["materials"]:
        assert material["shader"] == "Universal Render Pipeline/Lit"
        assert material["filterMode"] == "Point" and not material["isDataSRGB"] and material["mips"] == 1
        assert material["width"] == material["height"] == 8
        assert material["metallic"] == 0 and material["cull"] == 2 and material["alphaClip"] == 0
        assert np.all(vec(material["baseColor"], "rgba") == 1)
        assert "_SPECULAR_SETUP" not in material["keywords"]
        textures.append(np.array([vec(p, "rgba") for p in material["pixelsMip0"]]).reshape(8, 8, 4) / 255)
    palettes = [np.array([[1, 0, 0, 1], [0, 1, 0, 1]]), np.array([[0, 0, 1, 1], [1, 1, 0, 1]])]
    for side in range(2):
        assert np.array_equal(textures[side], np.broadcast_to(palettes[side][np.arange(8) // 4], (8, 8, 4)))
    # Fixture identity comes from source arrays, independently of atlas color/validity.
    vertices = np.array([vec(v, "xyz") for v in r["vertices"]])
    uv = np.array([vec(v, "xy") for v in r["uv"]])
    assert np.array_equal(vertices, [[-1, 0, 0], [0, 0, 0], [0, 1, 0], [-1, 1, 0], [0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0]])
    assert np.array_equal(np.array([vec(v, "xyz") for v in r["normals"]]), np.tile([0, 0, 1], (8, 1)))
    for side in range(2):
        indices = np.array(r["submeshes"][side]["indices"])
        assert indices.size == 6 and set(indices) == set(range(side * 4, side * 4 + 4))
        assert np.array_equal(uv[side * 4:(side + 1) * 4], source_uv(vertices[side * 4:(side + 1) * 4, :2], side))
    anchors = np.array([vec(p, "xy") for p in r["anchors"]], dtype=int)
    assert np.array_equal(anchors, packed_anchors)
    covered = np.isfinite(emission).all(-1) & (emission[..., 3] >= 1) & (emission[..., 3] <= 1024) & (emission[..., 3] == np.rint(emission[..., 3]))
    covered &= np.isfinite(position).all(-1) & np.isfinite(diffuse).all(-1) & (position[..., 3] >= 0) & (position[..., 3] <= 1)
    yy, xx = np.mgrid[:height, :width]
    binding_values_recorded = all("value" in binding for binding in r["bindings"])
    result = {"status": "observed" if binding_values_recorded else "insufficient-binding-values", "scope": "One static identity-transform two-submesh point-textured Lit material/UV seam; atlas and anchors only.", "bindingValuesRecorded": binding_values_recorded, "positionTolerance": 2e-5, "diffuseTolerance": 2 / 255, "sides": []}
    masks = {}
    for side in range(2):
        bindings = [b for b in r["bindings"] if b["submesh"] == side]
        assert len(bindings) == 2 and {b["primitive"] for b in bindings} == {0, 1} and all(b["available"] for b in bindings)
        chart = next(c for c in r["charts"] if c["sourceSubmesh"] == side)
        if binding_values_recorded:
            assert len({b["value"]["cardIndex"] for b in bindings}) == 1
            card_index = bindings[0]["value"]["cardIndex"]
        else:
            # Missing collector fields cannot be reconstructed as actual binding
            # results. Existing metadata only locates this source chart's atlas
            # for the remaining sub-observations; full-contract status stays unknown.
            candidates = [c["index"] for c in r["metadata"] if c["chartId"] == chart["stableId"] and c["ready"] != 0 and c["ownerSlot"] == r["ownerSlot"]]
            assert len(candidates) == 1, "Cannot associate recorded metadata with this source chart"
            card_index = candidates[0]
        card = r["metadata"][card_index]
        identity_ok = card["ownerSlot"] == r["ownerSlot"] and card["chartId"] == chart["stableId"] and card["ready"] != 0
        if binding_values_recorded:
            identity_ok &= all(b["value"]["chartId"] == chart["stableId"] and b["value"]["layoutGeneration"] == card["layoutGeneration"] for b in bindings)
        matrix = np.array(card["worldToCard"]).reshape(4, 4)
        identity_ok &= np.array_equal(matrix, np.array(chart["localToCard"]).reshape(4, 4))
        rect = vec(card["atlasRect"], "xyzw")
        minimum = np.rint(rect[:2] * [width, height]).astype(int)
        count = np.rint(rect[2:] * [width, height]).astype(int)
        xy = expected_xy(matrix, rect, width, height)
        source = source_uv(xy, side)
        tile = (xx >= minimum[0]) & (xx < minimum[0] + count[0]) & (yy >= minimum[1]) & (yy < minimum[1] + count[1])
        geometric = tile & (source[..., 0] > 1e-5) & (source[..., 0] < 1 - 1e-5) & (source[..., 1] > 1e-5) & (source[..., 1] < 1 - 1e-5)
        stripe_ties = geometric & (np.abs(source[..., 0] - .5) <= 1e-5)
        domain = geometric & ~stripe_ties
        expected_position = np.concatenate((xy, np.zeros((height, width, 1))), axis=-1)
        expected_diffuse = sample(textures[side], source)
        position_error = np.max(np.abs(position[..., :3] - expected_position), axis=-1)
        color_error = np.max(np.abs(diffuse[..., :3] - expected_diffuse), axis=-1)
        good = covered & (position_error <= 2e-5) & (color_error <= 2 / 255)
        distances = np.abs(xy[..., 0])
        nearest = np.unique(np.round(distances[domain], 7))[:2]
        near_seam = domain & (distances <= nearest[-1] + 1e-7)
        wrong_slot = sample(textures[1 - side], source)
        wrong_uv = sample(textures[side], np.stack((xy[..., 0], xy[..., 1]), -1))
        anchor_rows = []
        for cy in range(4):
            for cx in range(4):
                begin = minimum + np.array([cx, cy]) * count // 4
                end = minimum + (np.array([cx, cy]) + 1) * count // 4
                cell_mask = geometric & (xx >= begin[0]) & (xx < end[0]) & (yy >= begin[1]) & (yy < end[1])
                ax, ay = anchors[card_index * 16 + cy * 4 + cx]
                inside = bool(np.all([ax, ay] >= begin) and np.all([ax, ay] < end))
                occupied = bool(np.any(cell_mask))
                valid = inside and bool(geometric[ay, ax]) and bool(covered[ay, ax]) and position_error[ay, ax] <= 2e-5
                color_tie = valid and bool(stripe_ties[ay, ax])
                valid &= color_tie or (inside and color_error[ay, ax] <= 2 / 255)
                anchor_rows.append({"cell": [cx, cy], "pixel": [int(ax), int(ay)], "sourceCellOccupied": occupied, "insideHalfOpenCell": inside, "stripeTie": bool(color_tie), "sourceMatches": bool(valid) if occupied else bool(ax == ay == -1)})
        side_result = {"submesh": side, "cardIndex": card_index, "chartId": card["chartId"], "identityMatches": bool(identity_ok), "sourceDomainPixels": int(domain.sum()), "stripeTieExclusions": int(stripe_ties.sum()), "uncoveredPixels": int(np.sum(domain & ~covered)), "positionMismatchPixels": int(np.sum(domain & (position_error > 2e-5))), "colorMismatchPixels": int(np.sum(domain & (color_error > 2 / 255))), "maxPositionError": float(np.max(position_error[domain])), "maxDiffuseError": float(np.max(color_error[domain])), "sourceColorCounts": np.unique(expected_diffuse[domain], axis=0, return_counts=True)[1].tolist(), "nearSeamPixels": int(near_seam.sum()), "nearSeamMismatches": int(np.sum(near_seam & ~good)), "nearSeamMaxWorldDistance": float(np.max(distances[near_seam])), "swappedSlotDiscriminatingPixels": int(np.sum(domain & (np.max(np.abs(wrong_slot - expected_diffuse), -1) > 2 / 255))), "ignoredUvRotationDiscriminatingPixels": int(np.sum(domain & (np.max(np.abs(wrong_uv - expected_diffuse), -1) > 2 / 255))) if side == 1 else None, "anchors": anchor_rows}
        side_result["metadataAssociationMatches"] = side_result.pop("identityMatches")
        side_result["bindingIdentityMatches"] = bool(identity_ok) if binding_values_recorded else None
        side_result["atlasAnchorSatisfied"] = bool(identity_ok and domain.sum() > 0 and np.all(good[domain]) and len(side_result["sourceColorCounts"]) == 2 and all(a["sourceMatches"] for a in anchor_rows))
        side_result["satisfied"] = side_result["atlasAnchorSatisfied"] if binding_values_recorded else None
        result["sides"].append(side_result)
        masks[f"domain{side}"] = domain
        masks[f"near_seam{side}"] = near_seam
    distinct_cards = result["sides"][0]["cardIndex"] != result["sides"][1]["cardIndex"]
    result["atlasAnchorSatisfied"] = distinct_cards and all(s["atlasAnchorSatisfied"] for s in result["sides"])
    result["satisfied"] = result["atlasAnchorSatisfied"] if binding_values_recorded else None
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    np.savez_compressed(args.output / "signals.npz", diffuse=diffuse, position=position, emission=emission, anchors=anchors, **masks)
    print(json.dumps({"satisfied": result["satisfied"], "sides": [{k: v for k, v in side.items() if k != "anchors"} for side in result["sides"]]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
