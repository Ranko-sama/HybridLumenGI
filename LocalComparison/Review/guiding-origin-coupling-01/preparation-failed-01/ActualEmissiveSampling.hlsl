#ifndef HLGI_EMISSIVE_SAMPLING_INCLUDED
#define HLGI_EMISSIVE_SAMPLING_INCLUDED
#include "HybridLumenGIEmissiveRecords.hlsl"

// Record 0 contains the count. Records 1..count contain immutable, contiguous
// float32 CDF intervals. The builder compacts empty intervals and ends at exactly 1.
// These spheres describe directional proposals, never intersection geometry or Le.
static HLGIEmissiveRecord _HLGI_EmissiveProposals[33];
float _HLGI_EmissiveWeight;

uint HLGIEmissiveProposalCount()
{
    float count=_HLGI_EmissiveProposals[0].data.x;
    return isfinite(count) && count>=1 && count<=32 && count==floor(count) ? (uint)count:0u;
}

// Shared by sampling and PDF evaluation. Any numerical degeneracy is the same
// normalized full-sphere distribution in both paths, not a dropped probability mass.
void HLGIEmissiveLobe(float3 origin,float4 sphere,out float3 axis,out float sharpness)
{
    axis=float3(0,0,1);sharpness=0;
    float3 offset=sphere.xyz-origin;
    float distanceSquared=dot(offset,offset),radiusSquared=sphere.w*sphere.w;
    if(!all(isfinite(origin)) || !all(isfinite(sphere)) || sphere.w<=0 ||
        !all(isfinite(offset)) || !isfinite(distanceSquared) || !isfinite(radiusSquared) ||
        distanceSquared<=radiusSquared || distanceSquared<=0) return;
    float3 coneAxis=offset*rsqrt(distanceSquared);
    if(!all(isfinite(coneAxis))) return;
    float sinSquared=saturate(radiusSquared/distanceSquared);
    // Stable 1-sqrt(1-sinSquared), avoiding cancellation for small distant emitters.
    float delta=sinSquared/(1+sqrt(max(0,1-sinSquared)));
    // The sphere subtends an angular scale, not hard PDF support. A finite vMF
    // concentration avoids both a delta proposal and fragile narrow-cone edges.
    axis=coneAxis;sharpness=1/max(delta,1e-4);
}

float HLGIEmissiveVmfPdf(float3 origin,float4 sphere,float3 direction)
{
    float3 axis;float sharpness;
    HLGIEmissiveLobe(origin,sphere,axis,sharpness);
    if(sharpness<=0) return 1/(4*PI);
    // vMF on S2, evaluated with chord distance rather than dot(direction,axis)-1.
    // Here kappa is in [1,10000], so 1-exp(-2*kappa) has no small-k cancellation.
    float3 chord=direction-axis;
    return sharpness*exp(-0.5*sharpness*dot(chord,chord))/(TWO_PI*(1-exp(-2*sharpness)));
}

float HLGIEmissionLogOnePlus(float x)
{
    // Independently derived degree-8 log(1+x) Taylor polynomial for x in [-1/8,0].
    // Omitted-series absolute remainder <= (1/8)^9/(9*(1-1/8)) < 9.5e-10.
    // It preserves tiny x that would be lost by rounding 1+x to 1.
    if(x>-0.125)
        return x*(1+x*(-0.5+x*(1.0/3+x*(-0.25+x*(0.2+x*(-1.0/6+x*(1.0/7-x*0.125)))))));
    return log(1+x);
}

float3 HLGISampleEmissiveVmf(float3 origin,float4 sphere,float2 xi)
{
    float3 axis;float sharpness;
    HLGIEmissiveLobe(origin,sphere,axis,sharpness);
    // Inverse CDF expressed as r=cos(theta)-1. Keep r while computing sin(theta)
    // so adding it to 1 cannot erase the angular spread of a sharp distribution.
    float r;
    if(sharpness>0)
    {
        float tail=exp(-2*sharpness);
        // Both expressions equal log1p(u*(tail-1)). Near u=0 preserve u;
        // away from zero preserve the complementary tail 1-u at the other end.
        float logarithm=xi.x<=0.125?HLGIEmissionLogOnePlus(xi.x*(tail-1)):
            log((1-xi.x)+xi.x*tail);
        r=logarithm/sharpness;
    }
    else r=-2*xi.x;
    float z=1+r;
    float radius=sqrt(max(0,-r*(r+2))),phi=TWO_PI*xi.y;
    float3 tangent=normalize(cross(abs(axis.z)<0.999?float3(0,0,1):float3(0,1,0),axis));
    return normalize(tangent*(radius*cos(phi))+cross(axis,tangent)*(radius*sin(phi))+axis*z);
}

float HLGIEmissiveDirectionalPdf(float3 origin,float3 direction,uint count)
{
    float pdf=0;
    [loop] for(uint index=1u;index<=count;index++)
    {
        HLGIEmissiveRecord record=_HLGI_EmissiveProposals[index];
        // Use the selection CDF's represented interval width, not its original power.
        float pmf=record.data.y-record.data.x;
        if(pmf>0) pdf+=pmf*HLGIEmissiveVmfPdf(origin,record.sphere,direction);
    }
    return pdf;
}

float3 HLGISampleEmissiveDirection(float3 origin,float selector,float2 xi,uint count)
{
    // The builder guarantees a contiguous complete CDF and Random returns [0,1).
    // Zero-width intervals cannot be selected, including rounded-away tiny powers.
    uint selected=count;
    [loop] for(uint index=1u;index<=count;index++)
    {
        float2 interval=_HLGI_EmissiveProposals[index].data.xy;
        if(selector>=interval.x && selector<interval.y) { selected=index;break; }
    }
    return HLGISampleEmissiveVmf(origin,_HLGI_EmissiveProposals[selected].sphere,xi);
}

// Density of the EXISTING direction proposal, for pairing an area-light technique
// with the same cosine/guide/vMF sampler. This is not merely cosine/pi when guiding
// is enabled. It consumes no random numbers and introduces no emitted-radiance term.
float HLGITransportDirectionPdf(float3 origin,float3 normal,float4 guide,float3 direction)
{
    uint count=HLGIEmissiveProposalCount();
    float emissive=count>0u && isfinite(_HLGI_EmissiveWeight)?clamp(_HLGI_EmissiveWeight,0,0.8):0;
    if(emissive<=0)
    {
        // Match HLGISampleDirection's original branch exactly. Config constrains
        // guide weight to [0,.8]; do not silently use a different selection PMF.
        float mixture=guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5?_HLGI_GuideWeight:0;
        float3 axis=mixture>0?normalize(guide.xyz):normal;
        return ((1-mixture)*saturate(dot(normal,direction))+mixture*saturate(dot(axis,direction)))/PI;
    }
    bool validGuide=all(isfinite(guide)) && guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5 && isfinite(dot(guide.xyz,guide.xyz));
    float guideFraction=validGuide && isfinite(_HLGI_GuideWeight)?clamp(_HLGI_GuideWeight,0,0.8):0;
    float3 guideAxis=guideFraction>0?normalize(guide.xyz):normal;
    return (1-emissive)*((1-guideFraction)*saturate(dot(normal,direction))+
        guideFraction*saturate(dot(guideAxis,direction)))/PI+
        emissive*HLGIEmissiveDirectionalPdf(origin,direction,count);
}

float3 HLGISampleTransportDirection(float3 origin,float3 normal,float4 guide,inout uint rng,out float weight)
{
    uint count=HLGIEmissiveProposalCount();
    float emissive=count>0u && isfinite(_HLGI_EmissiveWeight)?clamp(_HLGI_EmissiveWeight,0,0.8):0;
    // Preserve the existing two-lobe sampler and random sequence exactly when disabled.
    if(emissive<=0) return HLGISampleDirection(normal,guide,rng,weight);
    bool validGuide=all(isfinite(guide)) && guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5 && isfinite(dot(guide.xyz,guide.xyz));
    float guideFraction=validGuide && isfinite(_HLGI_GuideWeight)?clamp(_HLGI_GuideWeight,0,0.8):0;
    float guided=(1-emissive)*guideFraction;
    float cosineFraction=(1-emissive)*(1-guideFraction);
    float3 guideAxis=guideFraction>0?normalize(guide.xyz):normal;
    float branch=Random(rng),selector=Random(rng);
    float2 xi=float2(Random(rng),Random(rng));
    float3 direction;
    if(branch<emissive) direction=HLGISampleEmissiveDirection(origin,selector,xi,count);
    else direction=CosineHemisphere(branch<emissive+guided?guideAxis:normal,xi);
    float receiverCosine=saturate(dot(normal,direction));
    float guideCosine=saturate(dot(guideAxis,direction));
    // One-sample balance mixture. Sum every overlapping lobe, even if a different
    // proposal generated this ray. Li is evaluated once by the usual hit path.
    float pdf=(cosineFraction*receiverCosine+guided*guideCosine)/PI+
        emissive*HLGIEmissiveDirectionalPdf(origin,direction,count);
    weight=receiverCosine>0 && pdf>0 && isfinite(pdf)?receiverCosine/(PI*pdf):0;
    // No hemisphere rejection, successful-hit normalization or separate emissive term.
    return direction;
}
#endif
