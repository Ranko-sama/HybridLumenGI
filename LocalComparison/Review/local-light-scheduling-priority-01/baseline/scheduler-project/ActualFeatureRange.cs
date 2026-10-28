using UnityEngine; using HybridLumenGI; public partial class FeatureContext {
            private void AddLightChange(CameraState state,HybridLumenGILights.Data light)
            {
                if(light.positionType.w<0.5f) state.changes.MarkGlobalLightingChange();
                else state.changes.Add(new Bounds((Vector3)light.positionType,Vector3.one*Mathf.Max(0,light.directionRange.w)*2),false,Mathf.Max(1,s.traceDistance));
            }
}