using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HybridLumenGI
{
    /// <summary>World-light snapshot. Independent of the camera's visible-light list.</summary>
    public sealed class HybridLumenGILights
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct Data : IEquatable<Data>
        {
            public Vector4 positionType, directionRange, color, spot;
            public uint cullingMask, renderingLayers, shadowRenderingLayers, flags;
            public bool Equals(Data other) => positionType.Equals(other.positionType) &&
                directionRange.Equals(other.directionRange) && color.Equals(other.color) && spot.Equals(other.spot) &&
                cullingMask == other.cullingMask && renderingLayers == other.renderingLayers &&
                shadowRenderingLayers == other.shadowRenderingLayers && flags == other.flags;
            public override bool Equals(object other) => other is Data value && Equals(value);
            public override int GetHashCode()
            {
                unchecked
                {
                    int h = positionType.GetHashCode(); h = h * 31 + directionRange.GetHashCode();
                    h = h * 31 + color.GetHashCode(); h = h * 31 + spot.GetHashCode();
                    h = h * 31 + (int)cullingMask; h = h * 31 + (int)renderingLayers;
                    h = h * 31 + (int)shadowRenderingLayers; return h * 31 + (int)flags;
                }
            }
        }
        public const int Stride = 80;
        private Light[] lights = Array.Empty<Light>();
        private int snapshotFrame;
        private bool hasSnapshot;

        public Light[] Snapshot(int engineFrame)
        {
            // Include inactive objects: activation after this scan is observed by TryPack.
            // Newly created objects are discovered on the next rendered engine frame at latest.
            // Repeated cameras in one frame reuse the allocation and deterministic ID ordering.
            if (!hasSnapshot || engineFrame != snapshotFrame)
            {
                lights = UnityEngine.Object.FindObjectsByType<Light>(FindObjectsInactive.Include, FindObjectsSortMode.InstanceID);
                snapshotFrame = engineFrame; hasSnapshot = true;
            }
            return lights;
        }

        public int Update(int engineFrame, bool useRenderingLayers, Data[] destination, int maxLights,
            int previousCount, List<Data> changes, out int hash)
        {
            changes.Clear(); hash = 17;
            int count = 0, limit = Math.Min(destination.Length, Math.Max(0, maxLights));
            uint definedLayers = GetDefinedLayers(useRenderingLayers);
            foreach (var light in Snapshot(engineFrame))
            {
                if (!TryPack(light, useRenderingLayers, definedLayers, out Data value)) continue;
                if (count >= limit) break;
                if (count >= previousCount || !destination[count].Equals(value))
                {
                    if (count < previousCount) changes.Add(destination[count]);
                    changes.Add(value);
                }
                destination[count++] = value;
                unchecked { hash = hash * 31 + value.GetHashCode(); }
            }
            for (int i = count; i < previousCount; i++) { changes.Add(destination[i]); destination[i] = default; }
            hash ^= count;
            return count;
        }

        public static bool TryPack(Light light, bool useRenderingLayers, out Data value)
            => TryPack(light, useRenderingLayers, GetDefinedLayers(useRenderingLayers), out value);

        public static LightmapBakeType GetBakeType(Light light)
        {
#if UNITY_EDITOR
            // The Inspector choice is available before a bake in the Editor.
            return light.lightmapBakeType;
#else
            // lightmapBakeType itself is Editor-only in Unity 6. Players expose
            // the serialized baking result, also used by URP ForwardLights.
            return light.bakingOutput.lightmapBakeType;
#endif
        }

        private static uint GetDefinedLayers(bool enabled)
        {
            // Match URP's internal RenderingLayerUtils without depending on an
            // inaccessible package type. Query once per camera update, not per light.
            return enabled && GraphicsSettings.GetSettingsForRenderPipeline(typeof(UniversalRenderPipeline)) != null
                ? RenderingLayerMask.GetDefinedRenderingLayersCombinedMaskValue() : uint.MaxValue;
        }

        private static bool TryPack(Light light, bool useRenderingLayers, uint definedLayers, out Data value)
        {
            value = default;
            if (light == null || !light.isActiveAndEnabled || GetBakeType(light) == LightmapBakeType.Baked ||
                !Finite(light.intensity) || light.intensity <= 0 ||
                (light.type != LightType.Directional && light.type != LightType.Point && light.type != LightType.Spot)) return false;
            bool directional = light.type == LightType.Directional;
            Vector3 p = directional ? Vector3.zero : light.transform.position;
            Vector3 dir = directional ? -light.transform.forward : light.transform.forward;
            Color color = (QualitySettings.activeColorSpace == ColorSpace.Linear ? light.color.linear : light.color) * light.intensity;
            if (GraphicsSettings.lightsUseColorTemperature && light.useColorTemperature)
                color *= Mathf.CorrelatedColorTemperatureToRGB(light.colorTemperature);
            float range = directional ? 0 : light.range;
            if (!Finite(p.x) || !Finite(p.y) || !Finite(p.z) || !Finite(dir.x) || !Finite(dir.y) || !Finite(dir.z) ||
                !Finite(color.r) || !Finite(color.g) || !Finite(color.b) || !Finite(range) || (!directional && range <= 0)) return false;
            float outer = 0, reciprocal = 1;
            if (light.type == LightType.Spot)
            {
                if (!Finite(light.spotAngle) || !Finite(light.innerSpotAngle)) return false;
                outer = Mathf.Cos(light.spotAngle * Mathf.Deg2Rad * 0.5f);
                float inner = Mathf.Cos(light.innerSpotAngle * Mathf.Deg2Rad * 0.5f);
                reciprocal = 1 / Mathf.Max(inner - outer, 0.001f);
            }
            float strength = light.shadows == LightShadows.None || !Finite(light.shadowStrength) ? 0 : Mathf.Clamp01(light.shadowStrength);
            uint layers = uint.MaxValue, shadowLayers = uint.MaxValue;
            if (useRenderingLayers)
            {
                // URP uses this component for illumination. Light.renderingLayerMask
                // is synchronized to the *shadow* mask when customShadowLayers is enabled.
                var extra = light.GetComponent<UniversalAdditionalLightData>();
                uint rawLayers = extra != null ? extra.renderingLayers : 1u;
                layers = rawLayers & definedLayers;
                // AdditionalLightData normally synchronizes its custom-shadow policy
                // here. Read the effective native value also used by ShadowDrawingSettings,
                // so a later explicit Light.renderingLayerMask edit is observed too.
                shadowLayers = unchecked((uint)light.renderingLayerMask);
            }
            value = new Data
            {
                positionType = new Vector4(p.x, p.y, p.z, directional ? 0 : light.type == LightType.Point ? 1 : 2),
                directionRange = new Vector4(dir.x, dir.y, dir.z, range), color = color,
                spot = new Vector4(outer, reciprocal, strength, 0),
                cullingMask = unchecked((uint)light.cullingMask), renderingLayers = layers, shadowRenderingLayers = shadowLayers,
                flags = useRenderingLayers ? 1u : 0u
            };
            return true;
        }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    }
}
