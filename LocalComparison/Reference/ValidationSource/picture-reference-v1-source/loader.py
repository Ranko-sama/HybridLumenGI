"""Strict source/state reader. Candidate images, masks and support are not inputs."""
from __future__ import annotations
import hashlib
import json
import math
import pathlib
import re


class InputError(ValueError):
    pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def _pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise InputError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def parse(data):
    try:
        value = json.loads(data.decode("utf-8-sig"), object_pairs_hook=_pairs,
                           parse_constant=lambda x: (_ for _ in ()).throw(InputError(f"Nonfinite JSON: {x}")))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise InputError(str(error)) from error
    def finite(x):
        if isinstance(x, float) and not math.isfinite(x):
            raise InputError("Nonfinite JSON number")
        if isinstance(x, dict):
            for v in x.values(): finite(v)
        if isinstance(x, list):
            for v in x: finite(v)
    finite(value)
    return value


def safe_path(root, relative):
    if not isinstance(relative, str) or not relative or "\\" in relative or ":" in relative:
        raise InputError(f"Unsafe relative artifact: {relative!r}")
    parts = relative.split("/")
    if any(p in ("", ".", "..") for p in parts):
        raise InputError(f"Unsafe relative artifact: {relative!r}")
    root = pathlib.Path(root).resolve(strict=True)
    result = root.joinpath(*parts).resolve(strict=True)
    if not result.is_relative_to(root) or not result.is_file():
        raise InputError(f"Artifact escapes root or is not a file: {relative}")
    return result


def sha(value):
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise InputError("Expected lowercase SHA256")
    return value


def load(source_path, state_path, input_root=None, expected_source=None, expected_state=None):
    source_path = pathlib.Path(source_path).resolve(strict=True)
    root = pathlib.Path(input_root).resolve(strict=True) if input_root else source_path.parent
    accesses = []
    def read(path, role, expected=None):
        path = pathlib.Path(path).resolve(strict=True)
        if not path.is_relative_to(root) or not path.is_file():
            raise InputError(f"Input outside explicit root: {path}")
        data = path.read_bytes()
        actual = digest(data)
        if expected is not None and actual != sha(expected):
            raise InputError(f"Hash mismatch: {path}")
        accesses.append(dict(path=str(path), relative=path.relative_to(root).as_posix(),
                             sha256=actual, bytes=len(data), role=role))
        return data, actual
    source_bytes, source_hash = read(source_path, "physical-source", expected_source)
    state_bytes, state_hash = read(state_path, "physical-frame-state", expected_state)
    source, state = parse(source_bytes), parse(state_bytes)
    if source.get("schema") != "hlgi-validation-source-v2" or state.get("schema") != "hlgi-validation-frame-state-v2":
        raise InputError("Unsupported source/state schema")
    if source.get("coordinateSystem") != "Unity-left-handed-y-up" or source.get("lengthUnit") != "metre":
        raise InputError("Unsupported coordinate system/unit")
    if state.get("sourceSha256") != source_hash:
        raise InputError("State is not bound to this source's exact bytes")
    logical = state.get("logicalFrame")
    if type(logical) is not int or logical < 0:
        raise InputError("Invalid logical frame")
    if not isinstance(source.get("sceneId"), str) or not source["sceneId"]:
        raise InputError("Missing scene identity")
    dynamic = state.get("dynamicState")
    if not isinstance(dynamic, dict):
        raise InputError("Missing source-only dynamicState")
    for document in (source, dynamic):
        for key in ("geometry", "materials", "lights", "assets", "unsupported"):
            if not isinstance(document.get(key), list):
                raise InputError(f"Missing source array: {key}")
        if not isinstance(document.get("rendering"), dict) or not isinstance(document.get("environment"), dict):
            raise InputError("Missing source rendering/environment")
        if not all(isinstance(x, str) and x for x in document["unsupported"]):
            raise InputError("Invalid unsupported reasons")
    if not isinstance(state.get("unsupported"), list) or not all(isinstance(x, str) and x for x in state["unsupported"]):
        raise InputError("Invalid frame unsupported reasons")
    # Assets are manifest-root relative even when source/state live in subfolders.
    seen = {}
    for document in (source, dynamic):
        local = set()
        for asset in document["assets"]:
            if not isinstance(asset, dict) or not isinstance(asset.get("role"), str) or not asset["role"]:
                raise InputError("Invalid physical asset role")
            name, expected = asset.get("path"), sha(asset.get("sha256"))
            if not isinstance(name, str) or name.casefold() in local:
                raise InputError("Repeated/invalid physical asset path")
            local.add(name.casefold())
            if name.casefold() in seen:
                if seen[name.casefold()] != expected:
                    raise InputError("Source/state asset identity conflict")
                continue
            path = safe_path(root, name)
            data, _ = read(path, "physical-asset:" + asset["role"], expected)
            if "bytes" in asset and (type(asset["bytes"]) is not int or asset["bytes"] != len(data)):
                raise InputError("Physical asset length mismatch")
            seen[name.casefold()] = expected
    reasons = sorted(set(source["unsupported"] + dynamic["unsupported"] + state["unsupported"]))
    return dict(root=root, source=source, state=state, source_sha256=source_hash,
                state_sha256=state_hash, accesses=accesses, unsupported=reasons)
