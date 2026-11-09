using UnityEngine;

namespace HybridLumenGI
{
    // One process-wide main-thread owner. A disabled or destroyed owner stays
    // reachable until native requests and GPU consumers have finished retiring.
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
