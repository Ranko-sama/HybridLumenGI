using UnityEngine; using HybridLumenGI; public partial class FeatureContext {
            private void AddLightChange(CameraState state,HybridLumenGILights.Data light)
            {
                if(light.positionType.w<0.5f) state.changes.MarkGlobalLightingChange();
                else
                {
                    var bounds=new Bounds((Vector3)light.positionType,Vector3.one*Mathf.Max(0,light.directionRange.w)*2);
                    float influence=Mathf.Max(1,s.traceDistance);
                    state.changes.Add(bounds,false,influence);
                    // Old and new records share the existing change domain. This
                    // conservative expansion affects priority, never eligibility.
                    bounds.Expand(influence*2);
                    state.localLightChangeBounds.Add(bounds);
                }
            }
}