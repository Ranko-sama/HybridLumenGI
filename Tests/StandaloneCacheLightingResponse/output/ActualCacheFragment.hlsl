    float3 tag=float3(p.identity.xy,_HLGI_Epoch);
    float2 change=HLGIChangeAt(surface.position);
    if(any(e.tag.xyz!=tag) || e.tag.w!=(float)surface.generation || change.x>0.5 || !HLGIHasCacheMeasurement(e.irradiance,e.guide))
        e=(HLGICacheEntry)0;
    // Positive age below one keeps a valid old measurement available, but marks
    // it for replacement after a global light change. Persist across budget
    // waits and unknown updates; only a committed known estimate consumes it.
    if(_HLGI_GlobalReactive>0.5) e.irradiance.a=min(e.irradiance.a,0.5);
    // Nearby changes retain an estimate but shorten its history, even if this patch awaits budget.
    if(change.y>0.5) e.irradiance.a=min(e.irradiance.a,1);
    e.tag=float4(tag,surface.generation);

        HLGICommitCacheEstimate(estimateKnown,sum,guide,guidePower,_HLGI_CacheRays,n,e.irradiance,e.guide);