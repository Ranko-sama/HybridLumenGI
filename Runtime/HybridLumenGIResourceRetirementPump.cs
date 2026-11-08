using System.Collections.Generic;
using UnityEngine;
using UnityEngine.LowLevel;

namespace HybridLumenGI
{
    // Both callbacks run outside the synchronous render-context dispatch. The root
    // tail covers the final render after an Update requested Application.Quit.
    [DefaultExecutionOrder(-32000)]
    internal sealed class HybridLumenGIResourceRetirementPump : MonoBehaviour
    {
#if UNITY_EDITOR
        // The Play-only root lives in DontDestroyOnLoad's scene. Let the Editor
        // unload it with that scene when Play ends.
        internal const HideFlags HostFlags = HideFlags.HideInHierarchy;
#else
        internal const HideFlags HostFlags = HideFlags.HideAndDontSave;
#endif
        private static HybridLumenGIResourceRetirementPump instance;
        internal static void EnsureExists()
        {
            InstallFrameBoundary();
            if(instance!=null)return;
            var go=new GameObject("HybridLumenGI Resource Retirement"){hideFlags=HostFlags};
            DontDestroyOnLoad(go);instance=go.AddComponent<HybridLumenGIResourceRetirementPump>();
        }
        private void Update()=>HybridLumenGIResourceRetirement.IdleUpdate();
        private struct FrameBoundary { }
        private static void InstallFrameBoundary()
        {
            // Keep the current loop, including other packages' systems/delegates.
            // Replace only our own root node, also with domain reload disabled.
            var loop=PlayerLoop.GetCurrentPlayerLoop();
            var systems=new List<PlayerLoopSystem>(loop.subSystemList??new PlayerLoopSystem[0]);
            systems.RemoveAll(system=>system.type==typeof(FrameBoundary));
            systems.Add(new PlayerLoopSystem{type=typeof(FrameBoundary),updateDelegate=EndFrame});
            loop.subSystemList=systems.ToArray();PlayerLoop.SetPlayerLoop(loop);
        }
        private static void EndFrame()=>HybridLumenGIResourceRetirement.IdleUpdate(atFrameEnd: true);
    }
}
