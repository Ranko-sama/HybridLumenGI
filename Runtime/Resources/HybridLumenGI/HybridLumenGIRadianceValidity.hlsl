#ifndef HLGI_RADIANCE_VALIDITY_INCLUDED
#define HLGI_RADIANCE_VALIDITY_INCLUDED

// Positive confidence proves a measurement, including measured black. Raw -1
// means an unknown current estimate; temporal/filter zero means no valid value.
bool HLGIHasRadianceMeasurement(float4 value)
{
    return all(isfinite(value)) && value.a>0;
}

// A zero-weight direction is an exactly known zero contribution. Never query
// its material or renormalize the estimate by only its accepted samples.
bool HLGIAccumulateRadianceSample(float3 incoming,float confidence,float weight,inout float3 sum)
{
    if(!isfinite(weight) || weight<0) return false;
    if(weight==0) return true;
    if(!HLGIHasRadianceMeasurement(float4(incoming,confidence))) return false;
    float3 next=sum+incoming*weight;
    if(!all(isfinite(next))) return false;
    sum=next;return true;
}

bool HLGIHasCacheMeasurement(float4 irradiance,float4 guide)
{
    return HLGIHasRadianceMeasurement(irradiance) && all(isfinite(guide));
}
bool HLGIHasSourceCacheMeasurement(float4 irradiance,float4 guide,float4 nonAnalyticIrradiance)
{
    return HLGIHasCacheMeasurement(irradiance,guide) && all(isfinite(nonAnalyticIrradiance));
}

// Call after identity/epoch/geometry invalidation. Failure keeps only a still
// valid old estimate, including its guide and sample count; invalid old data
// cannot be resurrected by a failed update.
bool HLGICommitCacheEstimate(bool known,float3 sum,float3 guideSum,float guidePower,
    int rayCount,float3 normal,inout float4 irradiance,inout float4 guide)
{
    if(!HLGIHasCacheMeasurement(irradiance,guide)) { irradiance=0;guide=0; }
    if(!known || rayCount<=0 || !all(isfinite(sum)) || !all(isfinite(guideSum)) ||
        !isfinite(guidePower) || guidePower<0 || !all(isfinite(normal))) return false;
    float3 estimate=sum/rayCount;
    // A positive fractional age marks the old reactive age-one measurement
    // pending replacement. Preserve its existing next-age-two/readiness rule;
    // this is a capped history weight, not a count of independent samples.
    // Unknown input returns above without consuming the pending replacement.
    float samples=irradiance.a>0?min(max(irradiance.a,1)+1,32):1;
    float alpha=max(1/samples,0.1);
    float4 next=float4(irradiance.a>=1?lerp(irradiance.rgb,estimate,alpha):estimate,samples);
    float lengthSquared=dot(guideSum,guideSum);
    float4 nextGuide=float4(lengthSquared>1e-12?guideSum*rsqrt(lengthSquared):normal,guidePower/rayCount);
    if(!HLGIHasCacheMeasurement(next,nextGuide) || !isfinite(lengthSquared)) return false;
    irradiance=next;guide=nextGuide;return true;
}

// Both source classes use the same accepted rays, validity, age and temporal
// weight. Keep the established total-D commit unchanged; never recover the
// non-analytic component by subtracting two nearly equal bright estimates.
bool HLGICommitSourceCacheEstimate(bool known,float3 sum,float3 nonAnalyticSum,
    float3 guideSum,float guidePower,int rayCount,float3 normal,
    inout float4 irradiance,inout float4 guide,inout float4 nonAnalyticIrradiance)
{
    if(!HLGIHasSourceCacheMeasurement(irradiance,guide,nonAnalyticIrradiance))
    { irradiance=0;guide=0;nonAnalyticIrradiance=0; }
    if(!known || !all(isfinite(nonAnalyticSum))) return false;
    float4 next=irradiance,nextGuide=guide;
    // The pending visibility refresh keeps the stored age for display and
    // readiness. Apply replacement weighting only to a successful commit.
    if(nonAnalyticIrradiance.w>0.5) next.a=min(next.a,0.5);
    bool blend=next.a>=1;
    if(!HLGICommitCacheEstimate(known,sum,guideSum,guidePower,rayCount,normal,next,nextGuide)) return false;
    float3 estimate=nonAnalyticSum/rayCount;
    float alpha=max(1/next.a,0.1);
    float4 nextNonAnalytic=float4(blend?lerp(nonAnalyticIrradiance.rgb,estimate,alpha):estimate,0);
    if(!all(isfinite(nextNonAnalytic))) return false;
    irradiance=next;guide=nextGuide;nonAnalyticIrradiance=nextNonAnalytic;return true;
}

bool HLGIHasTemporalHistory(float4 history,float4 moments)
{
    return HLGIHasRadianceMeasurement(history) && all(isfinite(moments)) && moments.z>0;
}

// The caller must first perform the complete reprojection, identity, geometry,
// material and change-region rejection. This function never invents validity.
void HLGIResolveUnknownHistory(bool validated,float4 history,float4 moments,
    out float4 output,out float4 outputMoments)
{
    output=0;outputMoments=0;
    if(validated && HLGIHasTemporalHistory(history,moments))
    { output=history;outputMoments=moments; }
}
#endif
