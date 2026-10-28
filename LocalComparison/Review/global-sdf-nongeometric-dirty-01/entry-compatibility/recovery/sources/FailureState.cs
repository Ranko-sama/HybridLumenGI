using HybridLumenGI;
// Only dependencies of the verbatim product failure method are adapted here.
sealed class ActualFailureState
{
    internal readonly HybridLumenGIGlobalSdf globalSdf;
    internal ulong uploadedSoftwareVersion=9;
    internal int historyCalls,timingCalls;
    internal ActualFailureState(HybridLumenGIGlobalSdf global){globalSdf=global;}
    void InvalidateScreenHistory(){historyCalls++;}
    void InvalidateGpuFeedback(){timingCalls++;}
    internal void InvalidateFailedRender()
            { uploadedSoftwareVersion=0;globalSdf.InvalidateAll();InvalidateScreenHistory();InvalidateGpuFeedback(); }
}

