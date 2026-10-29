using System;
using UnityEngine;

namespace HybridLumenGI
{
    [CreateAssetMenu(menuName="Hybrid Lumen GI/Asset Page Manifest")]
    public sealed class HybridLumenGIAssetPageManifest : ScriptableObject
    {
        [SerializeField] private string relativeRoot="HybridLumenGIAssetPages";
        [SerializeField] private string targetPlatform;
        [SerializeField] private HybridLumenGIAssetPageStreaming.Definition[] pages=Array.Empty<HybridLumenGIAssetPageStreaming.Definition>();
        public string RelativeRoot => relativeRoot;
        public string TargetPlatform => targetPlatform;
        public HybridLumenGIAssetPageStreaming.Definition[] Pages => pages;
        public void SetBuiltPages(string root,string platform,HybridLumenGIAssetPageStreaming.Definition[] value)
        {
            if(!HybridLumenGIAssetPageStreaming.RelativePath(root) || value==null)throw new ArgumentException("Invalid built asset manifest.");
            relativeRoot=root;targetPlatform=platform;pages=value;
        }
    }
}
