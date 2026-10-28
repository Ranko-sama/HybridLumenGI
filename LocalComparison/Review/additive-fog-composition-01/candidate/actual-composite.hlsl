struct RadianceInput
{
    float4 incoming,control,initialSum,irradiance,guide,history,moments;
    uint4 hitSpec;
    float4 guideSumPower,normal;
    uint4 purpose; // shadow, resolveMaterial, coverageKnown/covered/fullKnown bits, footprint case
    float4 footprint,connection; // incoming direction/radius; light position-or-direction/type
};
struct RadianceOutput
{
    float4 sum,irradiance,guide,history,moments,screen,proxy,direct;
    uint4 predicates,validity;
    float4 propagatedIrradiance,propagatedGuide;
    float4 unshadowedDirect;
    uint4 coverage;
    uint4 resolved;float4 resolvedMaterial;
    float4 forwardedOrigin,forwardedDirection,forwardedFootprint,forwardedView;
    float4 footprintDirect,wrappers,proxyPrimary;
};
StructuredBuffer<RadianceInput> _Inputs:register(t0);
RWStructuredBuffer<RadianceOutput> _Outputs:register(u0);
cbuffer TestCounts:register(b0) { uint _Count; }


#define real float
#define UNITY_REVERSED_Z 1
#define UNITY_UV_STARTS_AT_TOP 1
#define _FOG_FRAGMENT 1
static float4x4 _TestView=float4x4(1,0,0,0, 0,1,0,0, 0,0,1,-8, 0,0,0,1);
#define UNITY_MATRIX_V _TestView
static float4 _ProjectionParams=float4(1,2,18,1.0/18.0);
static float4 unity_FogParams=float4(0,0,-.125,1.25);
static float4 unity_FogColor=float4(3,5,7,1);
static float4x4 _HLGI_InvVP=float4x4(1,0,0,0, 0,1,0,0, 0,0,16,-10, 0,0,0,1);
static float4 _HLGI_Size=1;
static float _HLGI_Intensity;
static int _HLGI_Debug,_HLGI_Composition;
static RadianceInput active;
struct ScalarTexture {
    float value;
    float Load(int3 pixel) { return value; }
    void GetDimensions(out uint w,out uint h) { w=h=1; }
};
struct ColorTexture { float4 value;float4 Load(int3 pixel) { return value; } };
static ScalarTexture _HLGI_Depth,_HLGI_CaptureDepth;
static ColorTexture _HLGI_Diffuse,_HLGI_Emission,_HLGI_NativeDiffuseFog,_HLGI_Moments;
struct Varyings { float4 positionCS;float2 uv; };
// Explicit upstream resolve adapter: this contract begins at an already
// resolved measurement; spatial filtering/rasterization are not executed.
float4 Resolve(float2 uv,out bool resolved) { resolved=active.guide.z!=0;return active.incoming; }
#include "HybridLumenGIScreenSampling.hlsl"
#include "HybridLumenGIScreenMaterial.hlsl"
#include "HybridLumenGIRadianceValidity.hlsl"
bool IsFogEnabled()
{
    #if defined(DEBUG_DISPLAY)
    return (_DebugMaterialMode == DEBUGMATERIALMODE_NONE) &&
           (_DebugVertexAttributeMode == DEBUGVERTEXATTRIBUTEMODE_NONE) &&
           (_DebugMaterialValidationMode == DEBUGMATERIALVALIDATIONMODE_NONE) &&
           (_DebugSceneOverrideMode == DEBUGSCENEOVERRIDEMODE_NONE) &&
           (_DebugMipInfoMode == DEBUGMIPINFOMODE_NONE) &&
           (_DebugLightingMode == DEBUGLIGHTINGMODE_NONE) &&
           (_DebugLightingFeatureFlags == 0) &&
           (_DebugValidationMode == DEBUGVALIDATIONMODE_NONE);
    #else
    return true;
    #endif
}
float4 ComputeClipSpacePosition(float2 positionNDC, float deviceDepth)
{
    float4 positionCS = float4(positionNDC * 2.0 - 1.0, deviceDepth, 1.0);

#if UNITY_UV_STARTS_AT_TOP
    // Our world space, view space, screen space and NDC space are Y-up.
    // Our clip space is flipped upside-down due to poor legacy Unity design.
    // The flip is baked into the projection matrix, so we only have to flip
    // manually when going from CS to NDC and back.
    positionCS.y = -positionCS.y;
#endif

    return positionCS;
}
float3 ComputeWorldSpacePosition(float2 positionNDC, float deviceDepth, float4x4 invViewProjMatrix)
{
    float4 positionCS  = ComputeClipSpacePosition(positionNDC, deviceDepth);
    float4 hpositionWS = mul(invViewProjMatrix, positionCS);
    return hpositionWS.xyz / hpositionWS.w;
}
real ComputeFogFactorZ0ToFar(float z)
{
    #if defined(FOG_LINEAR)
    // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
    float fogFactor = saturate(z * unity_FogParams.z + unity_FogParams.w);
    return real(fogFactor);
    #elif defined(FOG_EXP) || defined(FOG_EXP2)
    // factor = exp(-(density*z)^2)
    // -density * z computed at vertex
    return real(unity_FogParams.x * z);
    #else
        return real(0.0);
    #endif
}
half ComputeFogIntensity(half fogFactor)
{
    half fogIntensity = half(0.0);
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        #if defined(FOG_EXP)
            // factor = exp(-density*z)
            // fogFactor = density*z compute at vertex
            fogIntensity = saturate(exp2(-fogFactor));
        #elif defined(FOG_EXP2)
            // factor = exp(-(density*z)^2)
            // fogFactor = density*z compute at vertex
            fogIntensity = saturate(exp2(-fogFactor * fogFactor));
        #elif defined(FOG_LINEAR)
            fogIntensity = fogFactor;
        #endif
    #endif
    return fogIntensity;
}
real InitializeInputDataFog(float4 positionWS, real vertFogFactor)
{
    real fogFactor = 0.0;
#if defined(_FOG_FRAGMENT)
    #if (defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2))
        // Compiler eliminates unused math --> matrix.column_z * vec
        float viewZ = -(mul(UNITY_MATRIX_V, positionWS).z);
        // View Z is 0 at camera pos, remap 0 to near plane.
        float nearToFarZ = max(viewZ - _ProjectionParams.y, 0);
        fogFactor = ComputeFogFactorZ0ToFar(nearToFarZ);
    #endif
#else
    fogFactor = vertFogFactor;
#endif
    return fogFactor;
}
half3 MixFogColor(half3 fragColor, half3 fogColor, half fogFactor)
{
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    if (IsFogEnabled())
    {
        half fogIntensity = ComputeFogIntensity(fogFactor);
        // Workaround for UUM-61728: using a manual lerp to avoid rendering artifacts on some GPUs when Vulkan is used
        fragColor = fragColor * fogIntensity + fogColor * (half(1.0) - fogIntensity);
    }
    #endif
    return fragColor;
}
half3 MixFog(half3 fragColor, half fogFactor)
{
    return MixFogColor(fragColor, half3(unity_FogColor.rgb), fogFactor);
}
        float3 Reconstruct(float2 uv,float depth)
        {
            // Every caller supplies the center of the full-resolution texel
            // that actually supplied this depth, including GI history samples.
        #if !UNITY_REVERSED_Z
            depth=lerp(UNITY_NEAR_CLIP_VALUE,1,depth);
        #endif
            return ComputeWorldSpacePosition(uv,depth,_HLGI_InvVP);
        }
        half4 Frag(Varyings v):SV_Target
        {
            uint fullWidth,fullHeight;_HLGI_Depth.GetDimensions(fullWidth,fullHeight);
            uint2 fullSize=uint2(fullWidth,fullHeight);
            uint2 fullPixel=HLGIFullPixelForUv(v.uv,fullSize);
            float2 uv=HLGIFullPixelCenterUv(fullPixel,fullSize);
            float4 material=_HLGI_Diffuse.Load(int3(fullPixel,0));
            float valid=_HLGI_Emission.Load(int3(fullPixel,0)).a;
            if(!HLGIHasScreenMaterial(valid)) return 0;
            float depth=_HLGI_Depth.Load(int3(fullPixel,0));
            float captureDepth=_HLGI_CaptureDepth.Load(int3(fullPixel,0));
            if(distance(Reconstruct(uv,depth),Reconstruct(uv,captureDepth))>0.03) return 0;
            bool resolved;float4 gi=Resolve(uv,resolved);
            // No trustworthy upsample support must preserve native lighting,
            // rather than interpreting an absent estimate as measured black GI.
            if(!resolved) return 0;
            if(!HLGIHasRadianceMeasurement(gi)) return 0;
            // Receiver diffuse reflectance is applied exactly once, after spatial filtering.
            float3 outgoing=max(gi.rgb,0)*material.rgb*material.a*_HLGI_Intensity;
            if(_HLGI_Debug==0 && _HLGI_Composition!=0)
            {
                float4 nativeDiffuseFog=_HLGI_NativeDiffuseFog.Load(int3(fullPixel,0));
                // Signed delta in an HDR target: native diffuse is already present in camera color.
                // Fog's source color remains untouched; only replace its attenuated diffuse contribution.
                outgoing=(outgoing-nativeDiffuseFog.rgb)*nativeDiffuseFog.a;
            }
            else if(_HLGI_Debug==0)
            {
                // Camera color already contains Lit's fog. Attenuate only the
                // added light; adding the fog color again would double count it.
                half fogCoord=InitializeInputDataFog(float4(Reconstruct(uv,depth),1),0);
                outgoing*=MixFogColor(half3(1,1,1),half3(0,0,0),fogCoord).r;
            }
            if(_HLGI_Debug==2) return float4(gi.aaa,1);
            if(_HLGI_Debug==3)
            {
                float variance=_HLGI_Moments.Load(int3(HLGIClosestGiPixel(uv,(uint2)_HLGI_Size.xy,fullSize),0)).w;
                // SpatialVariance: bounded grayscale v/(1+v), not history acceptance.
                float display=isfinite(variance) && variance>0?variance/(1+variance):0;
                return float4(display.xxx,1);
            }
            if(_HLGI_Debug==4) return float4(material.rgb,1);
            return float4(outgoing,_HLGI_Debug==0?0:1);
        }
[numthreads(64,1,1)] void CSCompositeFog(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];
    _HLGI_Depth.value=active.control.x;_HLGI_CaptureDepth.value=active.control.y;
    _HLGI_Emission.value=float4(0,0,0,active.control.z);_HLGI_Intensity=active.control.w;
    _HLGI_Diffuse.value=active.initialSum;_HLGI_NativeDiffuseFog.value=active.irradiance;
    _HLGI_Moments.value=float4(0,0,1,.25);
    _HLGI_Debug=(int)active.guide.x;_HLGI_Composition=(int)active.guide.y;
    Varyings v;v.positionCS=float4(.5,.5,0,1);v.uv=.5;
    RadianceOutput result=(RadianceOutput)0;
    result.sum=Frag(v);
    float3 world=Reconstruct(v.uv,active.control.x);
    real fogCoord=InitializeInputDataFog(float4(world,1),0);
    result.irradiance=float4(world,fogCoord);
    result.guide=float4(MixFogColor(half3(1,1,1),half3(0,0,0),fogCoord).r,0,0,0);
    _Outputs[id.x]=result;
}
