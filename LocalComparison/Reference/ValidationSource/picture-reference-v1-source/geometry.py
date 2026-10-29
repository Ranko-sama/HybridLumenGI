"""Independent source geometry and explicitly defined float64 pinhole sampling.

This is a source-domain tool, not a D3D rasterization equivalence certificate.
The conservative screen edge guard retains uncertainty; no RGB is read.
"""
from __future__ import annotations
import math
import numpy as np
from loader import InputError, parse

SKY, RECEIVER, BOUNDARY, UNSUPPORTED = range(4)
LABELS = ["sky", "receiver", "boundary", "unsupported"]
EPS = np.finfo(np.float64).eps


def array(value, shape, name):
    def numeric(x):
        if isinstance(x, (list, tuple, np.ndarray)):
            return all(numeric(v) for v in x)
        return not isinstance(x, (bool, np.bool_)) and isinstance(x, (int, float, np.integer, np.floating))
    if not numeric(value): raise InputError(f"Nonnumeric {name}")
    try: result = np.asarray(value, dtype=np.float64)
    except (ValueError, TypeError) as error: raise InputError(name) from error
    if result.shape != shape or not np.isfinite(result).all():
        raise InputError(f"Invalid {name}: expected {shape}")
    return result


def vectors(values, keys, name):
    if not isinstance(values, list): raise InputError(f"Invalid {name}")
    try: return array([[v[k] for k in keys] for v in values], (len(values), len(keys)), name)
    except (KeyError, TypeError) as error: raise InputError(f"Invalid {name}") from error


def unit(x):
    n = np.linalg.norm(x, axis=-1, keepdims=True)
    return np.divide(x, n, out=np.zeros_like(x), where=n > 0), n[..., 0]


class Camera:
    def __init__(self, descriptor):
        self.descriptor = descriptor
        required = {"matrixOrder": "row-major", "pixelCenter": "half-integer"}
        if any(descriptor.get(k) != v for k, v in required.items()): raise InputError("Camera convention")
        if descriptor.get("rowOrder") not in ("top-to-bottom", "bottom-to-top") or descriptor.get("uvOrigin") not in ("top-left", "bottom-left"):
            raise InputError("Camera row/UV convention")
        if descriptor.get("clipDepth") not in ("zero-to-one", "minus-one-to-one") or type(descriptor.get("reversedZ")) is not bool:
            raise InputError("Camera clip convention")
        viewport = descriptor.get("viewport")
        if not isinstance(viewport, list) or len(viewport) != 4 or any(type(v) is not int for v in viewport):
            raise InputError("Camera viewport")
        if viewport[0:2] != [0, 0] or not (1 <= viewport[2] <= 16384 and 1 <= viewport[3] <= 16384):
            raise InputError("This version supports only a full zero-origin viewport")
        self.width, self.height = viewport[2:]
        self.view = array(descriptor.get("view"), (16,), "view").reshape(4, 4)
        self.projection = array(descriptor.get("projection"), (16,), "projection").reshape(4, 4)
        array(descriptor.get("jitter"), (2,), "jitter")  # already included in projection
        self.vp = self.projection @ self.view
        try: self.inverse = np.linalg.inv(self.vp)
        except np.linalg.LinAlgError as error: raise InputError("Singular VP") from error
        self.condition = float(np.linalg.cond(self.vp))
        if not math.isfinite(self.condition) or self.condition * EPS > 1e-8:
            raise InputError("VP too ill-conditioned for this float64 domain tool")
        self.zmin = 0.0 if descriptor["clipDepth"] == "zero-to-one" else -1.0
        self.near = 1.0 if descriptor["reversedZ"] else self.zmin
        self.far = self.zmin if descriptor["reversedZ"] else 1.0

    def uv_for_grid(self, width, height):
        if not (type(width) is int and type(height) is int and 1 <= width <= self.width and 1 <= height <= self.height):
            raise InputError("Grid must be positive and no larger than camera viewport")
        x = ((2 * np.arange(width, dtype=np.int64) + 1) * self.width) // (2 * width)
        y = ((2 * np.arange(height, dtype=np.int64) + 1) * self.height) // (2 * height)
        xx, yy = np.meshgrid(x, y)
        # Raw row index to UV-v: rowOrder and uvOrigin are independent contracts.
        top_y = yy if self.descriptor["rowOrder"] == "top-to-bottom" else self.height - 1 - yy
        uv_y = top_y if self.descriptor["uvOrigin"] == "top-left" else self.height - 1 - top_y
        uv = np.stack(((xx + .5) / self.width, (uv_y + .5) / self.height), -1)
        return np.stack((xx, yy), -1).reshape(-1, 2), uv.reshape(-1, 2)

    def unproject(self, uv, depth):
        y = 1 - 2 * uv[:, 1] if self.descriptor["uvOrigin"] == "top-left" else 2 * uv[:, 1] - 1
        clip = np.stack((2 * uv[:, 0] - 1, y, np.broadcast_to(depth, len(uv)), np.ones(len(uv))), -1)
        world = clip @ self.inverse.T
        if np.any(np.abs(world[:, 3]) < np.finfo(float).tiny): raise InputError("Infinite unprojection endpoint")
        return world[:, :3] / world[:, 3:4]

    def rays(self, uv):
        origin, end = self.unproject(uv, self.near), self.unproject(uv, self.far)
        direction, length = unit(end - origin)
        if not np.isfinite(origin).all() or not np.isfinite(direction).all() or np.any(length <= 0):
            raise InputError("Invalid camera rays")
        return origin, direction, length

    def project(self, positions):
        clip = np.concatenate((positions, np.ones((len(positions), 1))), axis=1) @ self.vp.T
        ndc = clip[:, :3] / clip[:, 3:4]
        uv = np.stack(((ndc[:, 0] + 1) / 2, (1 - ndc[:, 1]) / 2 if self.descriptor["uvOrigin"] == "top-left" else (ndc[:, 1] + 1) / 2), -1)
        return uv, ndc[:, 2], clip[:, 3]


def property_map(material):
    values = {}
    for prop in material.get("properties", []):
        name = prop.get("name")
        if not isinstance(name, str) or name in values: raise InputError("Duplicate/invalid material property")
        values[name] = prop
    return values


def scalar(props, name):
    if name not in props: raise InputError(f"Missing Lit property {name}")
    return float(array(props[name].get("value"), (1,), name)[0])


def material_support(material):
    props = property_map(material)
    reasons = []
    if material.get("shader") != "Universal Render Pipeline/Lit": reasons.append("non-stock-Lit")
    cull = scalar(props, "_Cull") if "_Cull" in props else -1
    if cull not in (0, 1, 2): reasons.append("unsupported-cull")
    if "_Surface" not in props or scalar(props, "_Surface") != 0: reasons.append("non-opaque")
    if "_AlphaClip" not in props or scalar(props, "_AlphaClip") != 0: reasons.append("alpha-clip")
    if "_ZWrite" not in props or scalar(props, "_ZWrite") != 1: reasons.append("nonstandard-depth-write")
    if type(material.get("renderQueue")) is not int or not (0 <= material["renderQueue"] < 2501): reasons.append("non-opaque-queue")
    keywords = material.get("keywords")
    if not isinstance(keywords, list) or not all(isinstance(k, str) for k in keywords): raise InputError("Material keywords")
    # These branches change primary coverage or the requested reusable surface normals.
    forbidden = {"_ALPHATEST_ON", "_SURFACE_TYPE_TRANSPARENT", "_NORMALMAP", "_PARALLAXMAP", "_DETAIL_MULX2", "_DETAIL_SCALED"}
    reasons += ["unmodeled-keyword:" + k for k in keywords if k in forbidden]
    passes, enabled = material.get("passes"), material.get("passEnabled")
    if not isinstance(passes, list) or not isinstance(enabled, list) or len(passes) != len(enabled) or len(set(passes)) != len(passes) or any(type(x) is not bool for x in enabled):
        raise InputError("Material pass metadata")
    pass_map = dict(zip(passes, enabled))
    if not all(pass_map.get(name, False) for name in ("ForwardLit", "DepthOnly", "DepthNormals")):
        reasons.append("unqualified-primary-render-passes")
    return int(cull), props, reasons


class Scene:
    def __init__(self, snapshot, shadow_geometry=False):
        materials = snapshot["materials"]
        self.materials = {}
        for m in materials:
            if not isinstance(m.get("key"), str) or not m["key"] or m["key"] in self.materials: raise InputError("Material key")
            self.materials[m["key"]] = m
        self.vertices, self.normals, self.uvs, self.culls, self.records = [], [], [], [], []
        self.objects, self.excluded, self.unsupported = [], [], []
        mask = snapshot["rendering"].get("cameraCullingMask")
        if type(mask) is not int: raise InputError("Camera culling mask")
        urp = snapshot["rendering"].get("urp")
        if not isinstance(urp, dict):
            self.unsupported.append("missing-physical-urp-input")
        else:
            renderer_settings = {}
            for setting in urp.get("renderer", []):
                name = setting.get("name")
                if name in renderer_settings: raise InputError("Repeated renderer setting")
                renderer_settings[name] = setting.get("value")
            if renderer_settings.get("renderingMode") not in ("Forward", "ForwardPlus"):
                self.unsupported.append("unsupported-renderer-mode")
            try: mask &= int(renderer_settings["opaqueLayerMask"])
            except (KeyError, TypeError, ValueError): self.unsupported.append("missing-opaque-layer-mask")
            if urp.get("otherActiveFeatures") != []:
                self.unsupported.append("unmodeled-renderer-features")
            stencil = urp.get("stencil")
            if isinstance(stencil, str): stencil = parse(stencil.encode("utf-8"))
            if not isinstance(stencil, dict) or stencil.get("overrideStencilState") is not False:
                self.unsupported.append("unmodeled-or-missing-stencil-state")
        keys = set()
        for g in snapshot["geometry"]:
            key = g.get("key")
            if not isinstance(key, str) or not key or key in keys: raise InputError("Geometry key")
            keys.add(key)
            for field in ("enabled", "active", "forceRenderingOff", "staticBatch"):
                if type(g.get(field)) is not bool: raise InputError("Geometry flag: " + field)
            layer = g.get("layer")
            if type(layer) is not int or not 0 <= layer <= 31: raise InputError("Geometry layer")
            if not g["enabled"] or not g["active"] or g["forceRenderingOff"] or not ((mask & 0xffffffff) & (1 << layer)):
                self.excluded.append(dict(key=key, reason="source-disabled-or-camera-layer")); continue
            if g.get("shadowCasting") not in ("Off", "On", "TwoSided", "ShadowsOnly"):
                self.unsupported.append(key + ":missing-or-unmodeled-shadow-casting")
            if g.get("shadowCasting") == "ShadowsOnly" and not shadow_geometry:
                self.excluded.append(dict(key=key, reason="shadow-only-not-primary")); continue
            if g.get("rendererType") != "UnityEngine.MeshRenderer" or g["staticBatch"]:
                self.unsupported.append(key + ":renderer-type-or-static-batch"); continue
            matrix = array(g.get("localToWorld"), (16,), "localToWorld").reshape(4, 4)
            if not np.array_equal(matrix[3], [0, 0, 0, 1]): raise InputError("Non-affine object matrix")
            det = np.linalg.det(matrix[:3, :3])
            if not np.isfinite(det) or det <= 0:
                self.unsupported.append(key + ":singular-or-mirrored-transform"); continue
            mesh = g.get("mesh")
            if not isinstance(mesh, dict): raise InputError("Missing mesh")
            local = vectors(mesh.get("vertices"), "xyz", "vertices")
            normals = vectors(mesh.get("normals"), "xyz", "normals")
            if len(local) == 0 or normals.shape != local.shape: raise InputError("Mesh normals/vertices")
            world = local @ matrix[:3, :3].T + matrix[:3, 3]
            transformed_normals = normals @ np.linalg.inv(matrix[:3, :3])
            if not np.isfinite(world).all() or not np.isfinite(transformed_normals).all(): raise InputError("Object transform overflow")
            # Stock URP normalizes each transformed vertex normal before interpolation.
            transformed_normals, normal_lengths = unit(transformed_normals)
            if np.any(normal_lengths == 0): self.unsupported.append(key + ":zero-vertex-normal")
            uv_channels = mesh.get("uv")
            if not isinstance(uv_channels, list): raise InputError("UV channels")
            uv0 = next((x for x in uv_channels if x.get("channel") == 0), None)
            if uv0 is None: raise InputError("Missing UV0")
            uv = vectors(uv0.get("values"), "xyzw", "uv0")[:, :2]
            if len(uv) != len(local): raise InputError("UV0 length")
            slots = g.get("materialKeys")
            subs = mesh.get("submeshes")
            if not isinstance(slots, list) or not isinstance(subs, list) or len(slots) != len(subs):
                self.unsupported.append(key + ":non-one-to-one-submesh-materials"); continue
            owner = len(self.objects)
            self.objects.append(dict(key=key, name=g.get("name"), layer=layer))
            for slot, sub in enumerate(subs):
                if slots[slot] not in self.materials: raise InputError("Unknown material reference")
                material = self.materials[slots[slot]]
                cull, props, reasons = material_support(material)
                self.unsupported += [key + ":" + r for r in reasons]
                if sub.get("topology") != "Triangles": self.unsupported.append(key + ":non-triangle"); continue
                raw = sub.get("indices"); base = sub.get("baseVertex")
                if type(base) is not int or not isinstance(raw, list) or len(raw) % 3 or any(type(i) is not int or i < 0 for i in raw):
                    raise InputError("Submesh indices/baseVertex")
                indices = np.array(raw, dtype=np.int64).reshape(-1, 3) + base
                if np.any(indices < 0) or np.any(indices >= len(local)): raise InputError("Index outside mesh")
                for primitive, ids in enumerate(indices):
                    verts = world[ids]
                    if np.linalg.norm(np.cross(verts[1] - verts[0], verts[2] - verts[0])) == 0:
                        self.unsupported.append(key + ":degenerate-triangle"); continue
                    self.vertices.append(verts); self.normals.append(transformed_normals[ids]); self.uvs.append(uv[ids]); self.culls.append(cull)
                    self.records.append(dict(owner=owner, submesh=slot, primitive=primitive, materialKey=slots[slot]))
        self.vertices = np.array(self.vertices, dtype=np.float64).reshape(-1, 3, 3)
        self.normals = np.array(self.normals, dtype=np.float64).reshape(-1, 3, 3)
        self.uvs = np.array(self.uvs, dtype=np.float64).reshape(-1, 3, 2)
        self.culls = np.asarray(self.culls, dtype=np.int8)


def trace(scene, origin, direction, limit):
    """Streaming vectorized Moller-Trumbore. Returns actual triangle, not AABB hit."""
    count = len(origin)
    nearest = np.full(count, np.inf); ids = np.full(count, -1, dtype=np.int32)
    bary = np.zeros((count, 3)); uncertain = np.zeros(count, dtype=bool)
    for index, tri in enumerate(scene.vertices):
        e1, e2 = tri[1] - tri[0], tri[2] - tri[0]
        p = np.cross(direction, e2); det = p @ e1
        guard = 64 * EPS * np.linalg.norm(e1) * np.linalg.norm(e2)
        valid = np.abs(det) > guard
        if scene.culls[index] == 2: valid &= det > guard
        if scene.culls[index] == 1: valid &= det < -guard
        inv = np.divide(1.0, det, out=np.zeros_like(det), where=valid)
        tvec = origin - tri[0]; u = np.einsum("ij,ij->i", tvec, p) * inv
        q = np.cross(tvec, e1); v = np.einsum("ij,ij->i", direction, q) * inv
        distance = (q @ e2) * inv
        hit = valid & (u >= 0) & (v >= 0) & (u + v <= 1) & (distance >= 0) & (distance <= limit)
        tolerance = 128 * EPS * np.maximum(1, np.maximum(np.abs(distance), np.where(np.isfinite(nearest), np.abs(nearest), 1)))
        tie = hit & (ids >= 0) & (np.abs(distance - nearest) <= tolerance)
        closer = hit & (distance < nearest - tolerance)
        uncertain[closer] = False; uncertain[tie] = True
        nearest[closer] = distance[closer]; ids[closer] = index
        bary[closer] = np.stack((1 - u[closer] - v[closer], u[closer], v[closer]), -1)
    return ids, nearest, bary, uncertain


def clipped_polygon(camera, triangle):
    poly = [x for x in np.c_[triangle, np.ones(3)] @ camera.vp.T]
    # Homogeneous clipping before dividing by w, including near/far.
    planes = [np.array(p, float) for p in [(1,0,0,1),(-1,0,0,1),(0,1,0,1),(0,-1,0,1),(0,0,1,-camera.zmin),(0,0,-1,1)]]
    for plane in planes:
        if not poly: break
        output = []
        prev = poly[-1]; before = float(prev @ plane)
        for cur in poly:
            after = float(cur @ plane)
            if (after >= 0) != (before >= 0):
                output.append(prev + (cur - prev) * (before / (before - after)))
            if after >= 0: output.append(cur)
            prev, before = cur, after
        poly = output
    if len(poly) < 3: return np.empty((0, 2))
    clip = np.array(poly)
    if np.any(clip[:, 3] <= 0): raise InputError("Clipped polygon has nonpositive w")
    ndc = clip[:, :2] / clip[:, 3:4]
    # Top-origin pixel coordinates, independent of raw row storage or display.
    return np.c_[(ndc[:, 0] + 1) * .5 * camera.width, (1 - ndc[:, 1]) * .5 * camera.height]


def edge_guard(scene, camera, uv, radius=.5):
    """Retain a half-full-pixel band around every clipped source edge.

    Includes hidden edges and diagonals on purpose (over-conservative).
    Radius is a declared spatial footprint, not a fitted error tolerance.
    """
    top_v = uv[:, 1] if camera.descriptor["uvOrigin"] == "top-left" else 1 - uv[:, 1]
    pixels = np.c_[uv[:, 0] * camera.width, top_v * camera.height]
    boundary = np.zeros(len(uv), dtype=bool)
    for tri in scene.vertices:
        poly = clipped_polygon(camera, tri)
        for i in range(len(poly)):
            a, b = poly[i-1], poly[i]; delta = b - a
            lo, hi = np.minimum(a, b) - radius, np.maximum(a, b) + radius
            eligible = np.flatnonzero(~boundary & np.all(pixels >= lo, axis=1) & np.all(pixels <= hi, axis=1))
            if not len(eligible): continue
            d2 = float(delta @ delta)
            t = np.clip(((pixels[eligible] - a) @ delta) / d2, 0, 1) if d2 > 0 else np.zeros(len(eligible))
            d = pixels[eligible] - (a + t[:, None] * delta)
            boundary[eligible[np.einsum("ij,ij->i", d, d) <= radius * radius]] = True
    return boundary


def render_primary(scene, camera, width, height, source_unsupported=()):
    pixel, uv = camera.uv_for_grid(width, height)
    origin, direction, length = camera.rays(uv)
    ids, distance, bary, ties = trace(scene, origin, direction, length)
    hit = ids >= 0
    classification = np.where(hit, RECEIVER, SKY).astype(np.uint8)
    boundary = edge_guard(scene, camera, uv) | ties
    classification[boundary] = BOUNDARY
    # Unknown source geometry/coverage can affect every ray; never simply omit it.
    if source_unsupported or scene.unsupported: classification[:] = UNSUPPORTED
    position = np.zeros_like(origin); normal = np.zeros_like(origin); ng = np.zeros_like(origin); uv0 = np.zeros_like(uv); base_uv = np.zeros_like(uv)
    depth = np.zeros(len(ids)); owner = np.full(len(ids), -1, np.int32); residual = np.zeros(len(ids))
    position[hit] = origin[hit] + direction[hit] * distance[hit, None]
    for i in np.unique(ids[hit]):
        selected = ids == i; weights = bary[selected]
        normal[selected], normal_length = unit(weights @ scene.normals[i])
        ng[selected] = unit(np.cross(scene.vertices[i, 1] - scene.vertices[i, 0], scene.vertices[i, 2] - scene.vertices[i, 0])[None])[0][0]
        uv0[selected] = weights @ scene.uvs[i]
        props = property_map(scene.materials[scene.records[i]["materialKey"]])
        st = props.get("_BaseMap", {}).get("textureScaleOffset", [1, 1, 0, 0])
        st = array(st, (4,), "BaseMap ST")
        base_uv[selected] = uv0[selected] * st[:2] + st[2:]
        owner[selected] = scene.records[i]["owner"]
        bad = np.flatnonzero(selected)[normal_length == 0]; classification[bad] = UNSUPPORTED
    if hit.any():
        projected, depth[hit], _ = camera.project(position[hit])
        residual[hit] = np.max(np.abs(projected - uv[hit]), axis=1)
    distance[~hit] = 0
    return dict(classification=classification.reshape(height, width), sampledFullPixel=pixel.reshape(height, width, 2),
                uv=uv.reshape(height, width, 2), rayOrigin=origin.reshape(height, width, 3), rayDirection=direction.reshape(height, width, 3),
                rayLimit=length.reshape(height, width), triangle=ids.reshape(height, width), owner=owner.reshape(height, width),
                distance=distance.reshape(height, width), barycentric=bary.reshape(height, width, 3), position=position.reshape(height, width, 3),
                geometricNormal=ng.reshape(height, width, 3), shadingNormal=normal.reshape(height, width, 3), uv0=uv0.reshape(height, width, 2),
                baseUV=base_uv.reshape(height, width, 2), deviceDepth=depth.reshape(height, width), reprojectionUvResidual=residual.reshape(height, width))
