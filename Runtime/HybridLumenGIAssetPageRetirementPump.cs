using UnityEngine;

namespace HybridLumenGI
{
    // One process-wide main-thread owner, including while an authoring streamer is disabled or
    // destroyed. Native requests and unproven GPU consumers outlive scene/component teardown.
    internal sealed class HybridLumenGIAssetPageRetirementPump : MonoBehaviour
    {
        private static HybridLumenGIAssetPageRetirementPump instance;
        internal static void EnsureExists()
        {
            if(instance!=null)return;
            var go=new GameObject("HybridLumenGI Asset Page Retirement") { hideFlags=HybridLumenGIResourceRetirementPump.HostFlags };
            DontDestroyOnLoad(go);instance=go.AddComponent<HybridLumenGIAssetPageRetirementPump>();
        }
        private void Update()
        {HybridLumenGIStreamedRepresentation.PollRetirements();HybridLumenGIAssetPageStreamer.Pump();}
    }
}
