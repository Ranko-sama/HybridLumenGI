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


#include "HybridLumenGIScreenMaterial.hlsl"
#define UNITY_SETUP_INSTANCE_ID(x)
#define UNITY_TRANSFER_INSTANCE_ID(x,y)
#define UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(x)
#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(x)
// Source-decision adapter only: later color is invalid after any negative clip.
static bool discarded;
static uint clipCalls;
static float minimumClip;
void RecordClip(float value) { discarded=discarded || value<0; minimumClip=min(minimumClip,value); clipCalls++; }
#define clip(value) RecordClip(value)

#define TRANSFORM_TEX(uv,name) ((uv)*name##_ST.xy+name##_ST.zw)
#define SAMPLE_TEXTURE2D(tex,smp,uv) Sample##tex(uv)
struct Attributes {float4 positionOS;float2 uv;};
struct Varyings {float4 positionCS;float2 uv;};
struct SurfaceOutput {float4 diffuseOcclusion,emissionValidity;uint2 receiverPolicy;};
float4 TransformObjectToHClip(float3 p){return float4(p,1);}
uint2 HLGICaptureReceiverPolicy(){return uint2(1,1);}
static float4 _BaseMap_ST=float4(2,3,.1,.05),_DetailAlbedoMap_ST=float4(1.5,.5,.2,.3);
static float4 _BaseColor=float4(.5,.375,.25,1),_SpecColor=.04,_EmissionColor=float4(.125,.25,.5,1);
static float _Metallic=0,_OcclusionStrength=1,_WorkflowMode=1,_AlphaClip=0,_Cutoff=.5,_Surface=0,_SmoothnessTextureChannel=0,_DetailAlbedoMapScale=.5;
// Point-sampled linear 2x2 inputs. Non-target cells differ to expose wrong UV/mask semantics.
float4 Sample_BaseMap(float2 uv){return uv.x<.5&&uv.y<.5?float4(.5,.75,.25,.25):float4(.25,.5,.75,.25);}
float4 Sample_DetailMask(float2 uv){return float4(.125,.25,.5,uv.x<.5&&uv.y<.5?.75:.25);}
float4 Sample_DetailAlbedoMap(float2 uv){return uv.x>=.5&&uv.y>=.5?float4(.75,.25,.625,1):float4(.25,.75,.5,1);}
float4 Sample_OcclusionMap(float2 uv){return 1;}
float4 Sample_EmissionMap(float2 uv){return 1;}
            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }
            SurfaceOutput Frag(Varyings input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                clip(0.5h - _Surface);
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                // URP treats base-map alpha as smoothness rather than coverage
                // when the material selects the albedo alpha smoothness channel.
                half coverage = _SmoothnessTextureChannel > 0.5h ? _BaseColor.a : baseSample.a * _BaseColor.a;
                if (_AlphaClip > 0.5h) clip(coverage - _Cutoff);

                half3 albedo = baseSample.rgb * _BaseColor.rgb;
                #if defined(_DETAIL_MULX2) || defined(_DETAIL_SCALED)
                    // Lit applies detail ST to the already transformed base UV.
                    half mask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, input.uv).a;
                    float2 detailUV = input.uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
                    half3 detail = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUV).rgb;
                    #if defined(_DETAIL_SCALED)
                        detail = 2.0h * detail * _DetailAlbedoMapScale - _DetailAlbedoMapScale + 1.0h;
                    #else
                        detail *= 2.0h;
                    #endif
                    albedo *= 1.0h + mask * (detail - 1.0h);
                #endif

                half metallic = saturate(_Metallic);
                half3 specular = saturate(_SpecColor.rgb);
                #if defined(_METALLICSPECGLOSSMAP)
                    metallic = saturate(SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, input.uv).r);
                    specular = saturate(SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, input.uv).rgb);
                #endif
                // Matches standard URP Lit's diffuse BRDF split. This buffer is
                // reflectance, not irradiance or already-lit camera color.
                half diffuseFraction = _WorkflowMode < 0.5h
                    ? 1.0h - max(specular.r, max(specular.g, specular.b))
                    : 0.96h * (1.0h - metallic);
                half occlusion = 1.0h;
                #if defined(_OCCLUSIONMAP)
                    half ao = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, input.uv).g;
                    occlusion = lerp(1.0h, ao, saturate(_OcclusionStrength));
                #endif
                half3 emission = 0.0h;
                #if defined(_EMISSION)
                    emission = max(0.0h, _EmissionColor.rgb * SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv).rgb);
                #endif
                SurfaceOutput output;
                output.diffuseOcclusion = half4(saturate(albedo) * diffuseFraction, saturate(occlusion));
                output.emissionValidity = half4(emission, HLGIEncodeScreenMaterial(1.0h, HLGICaptureReceivesShadows()));
                output.receiverPolicy = HLGICaptureReceiverPolicy();
                return output;
            }
[numthreads(64,1,1)] void CSSurfaceAlpha(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=_Count)return;
    discarded=false;clipCalls=0;minimumClip=3.402823466e+38;
    _AlphaClip=_Inputs[id.x].control.x;
    _SmoothnessTextureChannel=_Inputs[id.x].control.y;
    Attributes input;input.positionOS=float4(0,0,0,1);input.uv=float2(.125,.125);
    Varyings mapped=Vert(input);SurfaceOutput captured=Frag(mapped);
    RadianceOutput result=(RadianceOutput)0;
    if(!discarded) { result.sum=captured.diffuseOcclusion;result.irradiance=captured.emissionValidity; }
    result.guide=float4(minimumClip,mapped.uv,0);
    result.predicates=uint4(discarded?0u:1u,clipCalls,discarded?uint2(0,0):captured.receiverPolicy);
    _Outputs[id.x]=result;
}
