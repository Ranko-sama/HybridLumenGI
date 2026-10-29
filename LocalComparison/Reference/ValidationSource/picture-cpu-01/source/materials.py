"""Nominal stock-Lit diffuse inputs, independently interpreted from source only."""
from __future__ import annotations
import numpy as np
from geometry import array, property_map, scalar, material_support
from loader import InputError


class UnsupportedInput(ValueError):
    """A valid source whose lighting meaning this version does not implement."""


def srgb_to_linear(rgb):
    rgb = np.asarray(rgb, dtype=np.float64)
    if not np.isfinite(rgb).all() or np.any(rgb < 0) or np.any(rgb > 1):
        raise UnsupportedInput("ordinary-authoring-color-outside-unit-range")
    return np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)


def texture_bound(texture):
    if texture is None: return False
    if not isinstance(texture, dict): raise InputError("Texture metadata")
    # JsonUtility emits an empty object-shaped value for a null texture.
    return any(texture.get(k) not in (None, "", 0, False) for k in
               ("name", "width", "height", "dimension", "graphicsFormat", "rawFile", "rawSha256"))


def color(props, name, hdr):
    if name not in props: raise InputError("Missing color property: " + name)
    prop = props[name]
    rgba = array(prop.get("value"), (4,), name)
    if np.any(rgba < 0): raise UnsupportedInput("negative-color:" + name)
    flags = {x.strip() for x in prop.get("flags", "").split(",")}
    if ("HDR" in flags) != hdr or "Gamma" in flags:
        raise UnsupportedInput("unmodeled-color-flags:" + name)
    origin = prop.get("origin")
    if origin in ("property-block-material-slot", "property-block-renderer"):
        rgb = rgba[:3].copy()  # source convention explicitly says shader-space vector
    elif origin == "material":
        rgb = rgba[:3].copy() if hdr else srgb_to_linear(rgba[:3])
    else: raise UnsupportedInput("unmodeled-color-origin:" + name)
    return rgb


def interpret(material):
    cull, props, reasons = material_support(material)
    if reasons: raise UnsupportedInput(";".join(reasons))
    if scalar(props, "_WorkflowMode") != 1 or "_SPECULAR_SETUP" in material["keywords"]:
        raise UnsupportedInput("non-metallic-workflow")
    supported_keywords = {"_EMISSION", "_RECEIVE_SHADOWS_OFF", "_SPECULARHIGHLIGHTS_OFF", "_ENVIRONMENTREFLECTIONS_OFF"}
    if set(material["keywords"]) - supported_keywords:
        raise UnsupportedInput("unmodeled-Lit-keyword:" + ",".join(sorted(set(material["keywords"]) - supported_keywords)))
    for prop in props.values():
        if prop.get("type") == "Texture" and texture_bound(prop.get("texture")):
            raise UnsupportedInput("nonconstant-texture:" + prop["name"])
    base = color(props, "_BaseColor", False)
    metallic, smoothness = scalar(props, "_Metallic"), scalar(props, "_Smoothness")
    if np.any(base > 1) or not 0 <= metallic <= 1 or not 0 <= smoothness <= 1:
        raise UnsupportedInput("nonpassive-or-out-of-range-material")
    emission = color(props, "_EmissionColor", True) if "_EMISSION" in material["keywords"] else np.zeros(3)
    # Metallic stock-Lit diffuse term. No product transport/cache implementation used.
    rho = base * .96 * (1 - metallic)
    return dict(key=material["key"], name=material.get("name", ""), baseLinear=base,
                rho=rho, emission=emission, metallic=metallic, smoothness=smoothness,
                cull=cull, ao=1.0, receivesShadows="_RECEIVE_SHADOWS_OFF" not in material["keywords"],
                model="opaque constant metallic stock-Lit diffuse/emission; nominal float64")
