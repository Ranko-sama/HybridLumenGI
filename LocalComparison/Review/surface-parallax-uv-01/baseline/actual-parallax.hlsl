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


static RadianceInput active;
// Fixed identity transform/perspective camera and affine texture fixtures.
// Actual product structs/Vert/Frag and locked URP view/parallax helpers follow.
#include "HybridLumenGIScreenMaterial.hlsl"
#define UNITY_VERTEX_INPUT_INSTANCE_ID
#define UNITY_VERTEX_OUTPUT_STEREO
#define UNITY_SETUP_INSTANCE_ID(x)
#define UNITY_TRANSFER_INSTANCE_ID(x,y)
#define UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(x)
#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(x)
#define real float
#define real3 float3
#define TRANSFORM_TEX(uv,name) ((uv)*name##_ST.xy+name##_ST.zw)
#define TEXTURE2D_PARAM(tex,smp) uint tex
#define TEXTURE2D_ARGS(tex,smp) tex
#define SAMPLE_TEXTURE2D(tex,smp,uv) FixtureSample(tex,uv)
static uint _BaseMap=0,_MetallicGlossMap=1,_SpecGlossMap=2,_OcclusionMap=3;
static uint _EmissionMap=4,_DetailMask=5,_DetailAlbedoMap=6,_ParallaxMap=7;
static float2 sampledUv[7];
static float4 _BaseMap_ST=float4(2,1,.16,.15),_DetailAlbedoMap_ST=float4(.5,.75,.25,.1);
static float4 _BaseColor=float4(.8,.6,.9,1),_SpecColor=.04,_EmissionColor=float4(.5,.75,.25,1);
static float _Metallic=.4,_OcclusionStrength=.75,_WorkflowMode=1,_AlphaClip=0,_Cutoff=.5;
static float _Surface=0,_SmoothnessTextureChannel=0,_DetailAlbedoMapScale=.5,_Parallax=.08;
static bool discarded;
static uint clipCalls;
static float minimumClip;
void RecordClip(float value) { discarded=discarded || value<0;minimumClip=min(minimumClip,value);clipCalls++; }
#define clip(value) RecordClip(value)
float4 FixtureSample(uint textureId,float2 uv)
{
    if(textureId<7) sampledUv[textureId]=uv;
    switch(textureId)
    {
        case 0:return float4(uv.x,uv.y,.25+.25*uv.x,1);
        case 1:return float4(.25+.25*uv.x,0,0,1);
        case 2:return float4(.1+.1*uv.x,.1+.1*uv.y,.2,1);
        case 3:return float4(0,.25+.5*uv.y,0,1);
        case 4:return float4(.5*uv.x,.25*uv.y,.125+.125*uv.x,1);
        case 5:return float4(0,0,0,.25+.5*uv.y);
        case 6:return float4(.25+.25*uv.x,.5+.125*uv.y,.75-.25*uv.x,1);
        default:return float4(0,active.control.x,0,1);
    }
}
struct VertexPositionInputs {float3 positionWS,positionVS;float4 positionCS,positionNDC;};
struct VertexNormalInputs {float3 tangentWS,bitangentWS,normalWS;};
static float4 _ProjectionParams=float4(1,0,0,0);
float3 TransformObjectToWorld(float3 p) {return p;}
float3 TransformWorldToView(float3 p) {return p-float3(1,1,1);}
float4 TransformWorldToHClip(float3 p) {return float4((p.xy-1)*.5,.5,1);}
float4 TransformObjectToHClip(float3 p) {return TransformWorldToHClip(p);}
float3 TransformObjectToWorldNormal(float3 n) {return normalize(n);}
float3 TransformObjectToWorldDir(float3 t) {return normalize(t);}
float GetOddNegativeScale() {return 1;}
bool IsPerspectiveProjection() {return true;}
float3 GetCurrentViewPosition() {return float3(1,1,1);}
float3 GetViewForwardDir() {return float3(0,0,-1);}
uint2 HLGICaptureReceiverPolicy() {return uint2(1,1);}
#include "ActualViewHelpers.hlsl"
#include "ParallaxMapping.hlsl"
#include "ActualSurface.hlsl"

[numthreads(64,1,1)] void CSSurfaceParallax(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    active=_Inputs[id.x];discarded=false;clipCalls=0;minimumClip=3.402823466e+38;
    [unroll] for(int j=0;j<7;j++)sampledUv[j]=0;
    float3 positions[3]={float3(-.5,-.5,0),float3(.5,-.5,0),float3(-.5,.5,0)};
    float3 normals[3]={float3(0,0,1),float3(.6,0,.8),float3(0,.6,.8)};
    float4 tangents[3]={float4(1,0,0,1),float4(.8,0,-.6,1),float4(1,0,0,1)};
    float2 uvs[3]={float2(.1,.15),float2(.3,.15),float2(.1,.35)};
    float weights[3]={.2,.3,.5};
    Varyings mapped=(Varyings)0;
    [unroll] for(int vertex=0;vertex<3;vertex++)
    {
        Attributes input=(Attributes)0;
        input.positionOS=float4(positions[vertex],1);input.uv=uvs[vertex];
#if defined(HLGI_SURFACE_HAS_PARALLAX) && defined(_PARALLAXMAP)
        input.normalOS=normals[vertex];input.tangentOS=tangents[vertex];
#endif
        Varyings output=Vert(input);
        mapped.positionCS+=output.positionCS*weights[vertex];
        mapped.uv+=output.uv*weights[vertex];
#if defined(HLGI_SURFACE_HAS_PARALLAX) && defined(_PARALLAXMAP)
        mapped.viewDirTS+=output.viewDirTS*weights[vertex];
#endif
    }
    SurfaceOutput captured=Frag(mapped);
    RadianceOutput result=(RadianceOutput)0;
    if(!discarded){result.sum=captured.diffuseOcclusion;result.irradiance=captured.emissionValidity;}
    result.guide=float4(sampledUv[0],minimumClip,clipCalls);
    result.history=float4(sampledUv[1],sampledUv[2]);
    result.moments=float4(sampledUv[3],sampledUv[4]);
    result.screen=float4(sampledUv[5],sampledUv[6]);
    result.proxy=float4(mapped.uv,0,0);
    result.predicates=uint4(discarded?0u:1u,clipCalls,discarded?uint2(0,0):captured.receiverPolicy);
    _Outputs[id.x]=result;
}
