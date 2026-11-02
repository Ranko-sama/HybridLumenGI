using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace HybridLumenGI
{
    // Static lightmap UVs in Shadowmask quality mode. Probe occlusion and camera
    // shadow-distance blending have different inputs.
    internal static class HybridLumenGIShadowmask
    {
        internal struct Source
        {
            internal int textureId;
            internal uint version;
            internal Vector4 scaleOffset;
            internal bool captureUv;

            internal bool Matches(Source other) => textureId == other.textureId && version == other.version &&
                scaleOffset.Equals(other.scaleOffset) && captureUv == other.captureUv;
        }

        internal static LightmapData[] ActiveMaps()
        {
            if (QualitySettings.shadowmaskMode != ShadowmaskMode.Shadowmask ||
                !(GraphicsSettings.currentRenderPipeline is UniversalRenderPipelineAsset pipeline) || !pipeline.supportsMixedLighting)
                return null;
            var maps = LightmapSettings.lightmaps;
            if (maps != null)
                foreach (var map in maps)
                    if (map?.lightmapColor != null && map.shadowMask != null) return maps;
            return null;
        }

        internal static int ChannelPlusOne(Light light)
        {
            var bake = light.bakingOutput;
            return bake.isBaked && bake.lightmapBakeType == LightmapBakeType.Mixed &&
                bake.mixedLightingMode == MixedLightingMode.Shadowmask && (uint)bake.occlusionMaskChannel < 4u
                ? bake.occlusionMaskChannel + 1 : 0;
        }

        internal static Source Read(Renderer renderer, LightmapData[] maps, out Texture2D texture)
        {
            texture = null;
            if (maps == null || !(renderer is MeshRenderer meshRenderer)) return default;
            int index = renderer.lightmapIndex;
            if ((uint)index >= (uint)maps.Length || index >= 0xfffe || maps[index]?.lightmapColor == null) return default;
            texture = maps[index].shadowMask;
            if (texture == null) return default;
            Mesh mesh = HybridLumenGIDeformedMesh.GetSourceMesh(renderer);
            Mesh extra = meshRenderer.additionalVertexStreams;
            Vector4 st = renderer.lightmapScaleOffset;
            bool finiteUv = true;
            for (int i = 0; i < 4; i++) finiteUv &= !float.IsNaN(st[i]) && !float.IsInfinity(st[i]);
            return new Source
            {
                textureId = texture.GetInstanceID(), version = texture.updateCount, scaleOffset = st,
                // Explicit card DrawMesh uses the base streams. Do not claim a
                // baked UV for a different stream, a static batch or a deformed snapshot.
                captureUv = finiteUv && mesh != null && mesh.HasVertexAttribute(VertexAttribute.TexCoord1) &&
                    !renderer.isPartOfStaticBatch && !HybridLumenGIDeformedMesh.HasSnapshot(renderer) &&
                    (extra == null || !extra.HasVertexAttribute(VertexAttribute.TexCoord1))
            };
        }
    }
}
