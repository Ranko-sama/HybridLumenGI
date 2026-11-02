using UnityEngine;

namespace HybridLumenGI
{
    // Shared by exact-mesh material setup and the proxy's uniform fallback.
    internal static class HybridLumenGIUniformLighting
    {
        internal static float ReadFloat(Material source, MaterialPropertyBlock block, string name, float fallback)
        {
            int id = Shader.PropertyToID(name);
            return block != null && block.HasProperty(id) ? block.GetFloat(id) :
                source.HasProperty(id) ? source.GetFloat(id) : fallback;
        }

        internal static Vector4 ReadLinearColor(Material source, MaterialPropertyBlock block, string name, Color fallback, bool hdr)
        {
            int id = Shader.PropertyToID(name);
            // MPBs store shader-space vectors. Only ordinary serialized Material
            // colors require decoding; Lit's HDR emission is already linear.
            if (block != null && block.HasProperty(id)) return block.GetVector(id);
            Color color = source.HasProperty(id) ? source.GetColor(id) : fallback;
            if (!hdr) color = color.linear;
            return new Vector4(color.r, color.g, color.b, color.a);
        }
    }
}
