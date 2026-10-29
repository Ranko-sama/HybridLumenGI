using System.Collections.Generic;
using UnityEngine;

namespace HybridLumenGI
{
    [CreateAssetMenu(menuName = "Hybrid Lumen GI/Scene Streaming Manifest")]
    public sealed class HybridLumenGIStreamingManifest : ScriptableObject
    {
        [SerializeField] private List<HybridLumenGIChunkStreaming.Definition> chunks = new List<HybridLumenGIChunkStreaming.Definition>();
        public IReadOnlyList<HybridLumenGIChunkStreaming.Definition> Chunks => chunks;
    }
}
