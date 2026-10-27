using UnityEditor;
using UnityEngine;

namespace HybridLumenGI
{
    public static class HybridLumenGIDiagnostics
    {
        [MenuItem("Tools/Hybrid Lumen GI/Validation/Log Runtime Diagnostics")]
        public static void Log()
        {
            int count=0;
            foreach(var feature in Resources.FindObjectsOfTypeAll<HybridLumenGIRendererFeature>())
            {
                if(feature.GetDiagnostics().Length==0) continue;
                feature.LogRuntimeDiagnostics();count++;
            }
            if(count==0) Debug.Log("[HybridLumenGI] No active camera diagnostics. Render a supported game camera with the feature enabled first.");
        }
    }
}
