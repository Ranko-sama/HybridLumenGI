using UnityEngine;

namespace HybridLumenGI
{
    // This callback is the outside-render-loop boundary, including with no cameras.
    // It must precede ordinary Update-driven owner withdrawal and application exit.
    [DefaultExecutionOrder(-32000)]
    internal sealed class HybridLumenGIResourceRetirementPump : MonoBehaviour
    {
        private static HybridLumenGIResourceRetirementPump instance;
        internal static void EnsureExists()
        {
            if(instance!=null)return;
            var go=new GameObject("HybridLumenGI Resource Retirement"){hideFlags=HideFlags.HideAndDontSave};
            DontDestroyOnLoad(go);instance=go.AddComponent<HybridLumenGIResourceRetirementPump>();
        }
        private void Update()=>HybridLumenGIResourceRetirement.IdleUpdate();
    }
}
