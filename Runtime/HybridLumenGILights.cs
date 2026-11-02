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
        // Scratch only: each camera supplies its own prior effective table to Update.
        private Data[] previousData = Array.Empty<Data>();
        private bool[] currentMatched = Array.Empty<bool>();
        private Data[] relevantData = Array.Empty<Data>();
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
            => Update(engineFrame,useRenderingLayers,destination,maxLights,previousCount,changes,out hash,false,default,out _);

        public readonly struct SelectionDiagnostics
        {
            // -1 means not counted in disabled legacy mode, whose early exit is preserved.
            public readonly int ValidCandidates, OutsideDomain, Selected, CapacityOmitted;
            public readonly bool DomainValid;
            public readonly string Status;
            public SelectionDiagnostics(int valid,int outside,int selected,int omitted,bool domainValid,string status)
            { ValidCandidates=valid;OutsideDomain=outside;Selected=selected;CapacityOmitted=omitted;DomainValid=domainValid;Status=status; }
        }

        public int Update(int engineFrame,bool useRenderingLayers,Data[] destination,int maxLights,
            int previousCount,List<Data> changes,out int hash,bool spatialSelection,
            HybridLumenGILightRelevance.Domain domain,out SelectionDiagnostics diagnostics)
            => Update(engineFrame,useRenderingLayers,destination,maxLights,previousCount,changes,out hash,spatialSelection,
                domain,out diagnostics,RenderSettings.sun,true);

        internal int Update(int engineFrame,bool useRenderingLayers,Data[] destination,int maxLights,
            int previousCount,List<Data> changes,out int hash,bool spatialSelection,
            HybridLumenGILightRelevance.Domain domain,out SelectionDiagnostics diagnostics,Light mainLight,bool additionalRealtimeShadows)
        {
            changes.Clear(); hash = 17;
            int count = 0, limit = Math.Min(destination.Length, Math.Max(0, maxLights));
            if (previousData.Length < previousCount) previousData = new Data[previousCount];
            Array.Copy(destination, previousData, previousCount);
            uint definedLayers = GetDefinedLayers(useRenderingLayers);
            bool canFilter=spatialSelection && domain.IsValid;
            if(canFilter && relevantData.Length<limit) relevantData=new Data[limit];
            int valid=0,outside=0,relevant=0;
            foreach (var light in Snapshot(engineFrame))
            {
                if (!TryPack(light, useRenderingLayers, definedLayers, out Data value)) continue;
                // An empty receiver set cannot contribute at any hit. Leave its slot for a usable light.
                if (value.cullingMask == 0u || (useRenderingLayers && value.renderingLayers == 0u)) continue;
                if (value.spot.w > 0 && light != mainLight)
                    value.flags |= additionalRealtimeShadows ? 2u : 6u;
                if (!spatialSelection && count >= limit) break;
                valid++;
                if(count<limit) destination[count++]=value;
                if(canFilter)
                {
                    if(HybridLumenGILightRelevance.DefinitelyOutside(value,domain)) outside++;
                    else if(relevant<limit) relevantData[relevant++]=value;
                }
            }
            int written=count;
            bool filtered=canFilter && valid>limit;
            if(filtered) { count=relevant;Array.Copy(relevantData,destination,count); }
            else outside=0;
            for(int i=0;i<count;i++) unchecked { hash=hash*31+destination[i].GetHashCode(); }
            for (int i = count; i < Math.Max(previousCount,written); i++) destination[i] = default;
            // Table compaction is not a lighting change. Match each occurrence once:
            // numerically identical lights still contribute independently.
            if (currentMatched.Length < count) currentMatched = new bool[count];
            Array.Clear(currentMatched, 0, count);
            for (int old = 0; old < previousCount; old++)
            {
                int match = -1;
                for (int current = 0; current < count; current++)
                    if (!currentMatched[current] && previousData[old].Equals(destination[current]))
                    { match = current; break; }
                if (match >= 0) currentMatched[match] = true;
                else changes.Add(previousData[old]);
            }
            for (int current = 0; current < count; current++)
                if (!currentMatched[current]) changes.Add(destination[current]);
            hash ^= count;
            diagnostics=new SelectionDiagnostics(spatialSelection?valid:-1,outside,count,
                spatialSelection?Math.Max(0,valid-outside-count):-1,domain.IsValid,
                !spatialSelection?"Disabled":!domain.IsValid?"Unknown domain; legacy admission":filtered?"Conservative spatial admission":"Within capacity; legacy admission");
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
            if (light == null || !light.isActiveAndEnabled) return false;
            var bakeType = GetBakeType(light);
            if (bakeType == LightmapBakeType.Baked || !Finite(light.intensity) || light.intensity <= 0 ||
                (light.type != LightType.Directional && light.type != LightType.Point && light.type != LightType.Spot)) return false;
            float bounceIntensity = light.bounceIntensity;
            if (!Finite(bounceIntensity) || bounceIntensity <= 0f) return false;
            bool directional = light.type == LightType.Directional;
            Vector3 p = directional ? Vector3.zero : light.transform.position;
            Vector3 dir = light.type == LightType.Point ? Vector3.zero : light.transform.forward;
            if (directional) dir = -dir;
            Color color = (QualitySettings.activeColorSpace == ColorSpace.Linear ? light.color.linear : light.color) * light.intensity;
            if (GraphicsSettings.lightsUseColorTemperature && light.useColorTemperature)
                color *= Mathf.CorrelatedColorTemperatureToRGB(light.colorTemperature);
            // This table lights secondary hits. Apply the per-light indirect multiplier once at its source.
            color *= bounceIntensity;
            // A black light contributes nothing but would occupy a slot and keep the analytic cache alive.
            if (color.r == 0f && color.g == 0f && color.b == 0f) return false;
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
            int channel = bakeType == LightmapBakeType.Mixed ? HybridLumenGIShadowmask.ChannelPlusOne(light) : 0;
            // RGB is the source light. Alpha carries the baked shadow strength only
            // for a light with an assigned channel; realtime casting can be disabled separately.
            if (channel != 0) color.a = Finite(light.shadowStrength) ? Mathf.Clamp01(light.shadowStrength) : 0;
            value = new Data
            {
                positionType = new Vector4(p.x, p.y, p.z, directional ? 0 : light.type == LightType.Point ? 1 : 2),
                directionRange = new Vector4(dir.x, dir.y, dir.z, range), color = color,
                spot = new Vector4(outer, reciprocal, strength, channel),
                cullingMask = unchecked((uint)light.cullingMask), renderingLayers = layers, shadowRenderingLayers = shadowLayers,
                flags = useRenderingLayers ? 1u : 0u
            };
            return true;
        }
        private static bool Finite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
    }
}
