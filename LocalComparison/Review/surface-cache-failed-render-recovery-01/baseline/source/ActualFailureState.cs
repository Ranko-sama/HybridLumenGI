using HybridLumenGI;
sealed class SdfCounter { internal int calls; internal void InvalidateAll(){calls++;} }
sealed class ActualFailureState {
 internal readonly HybridLumenGISurfaceCache surfaceCache;
 internal readonly SdfCounter globalSdf=new SdfCounter();
 internal ulong uploadedSoftwareVersion=9;internal int historyCalls,feedbackCalls;
 internal ActualFailureState(HybridLumenGISurfaceCache cache){surfaceCache=cache;}
 internal void InvalidateScreenHistory(){historyCalls++;} internal void InvalidateGpuFeedback(){feedbackCalls++;}
        internal void InvalidateFailedRender()
            { uploadedSoftwareVersion=0;globalSdf.InvalidateAll();InvalidateScreenHistory();InvalidateGpuFeedback(); }
}
