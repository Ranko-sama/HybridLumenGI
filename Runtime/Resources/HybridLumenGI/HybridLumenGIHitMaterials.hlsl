#ifndef HYBRID_LUMEN_GI_HIT_MATERIALS_INCLUDED
#define HYBRID_LUMEN_GI_HIT_MATERIALS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "HybridLumenGIRayTextures.hlsl"

// 240B. CPU owns source eligibility and freezes shader-space colors. Texture
// contents are source SRV values; neither this evaluator nor the pool gamma-decodes
// them again. Handle validity alone never identifies an unassigned texture.
struct HLGIHitMaterialRecord
{
    uint4 identity; // generation, keyword flags, source Cull, assigned texture bits
    float4 baseColor, specColor, emissionColor;
    float4 surface; // metallic, smoothness, occlusion strength, bump scale
    float4 detail;  // cutoff, detail albedo scale, detail normal scale, parallax
    float4 baseST, detailST;
    float4 proxyTint, proxyEmission;
    uint4 textures0, textures1, textures2, textures3, textures4;
};
struct HLGIHitMaterialLods { float values[10]; };
struct HLGIHitMaterialSurface
{
    float3 diffuseReflectance, emission, normalTS, specular, albedo;
    float occlusion, smoothness, alpha;
    bool receivesShadows;
};

#define HLGI_MATERIAL_ALPHA_TEST 1u
#define HLGI_MATERIAL_SPECULAR 2u
#define HLGI_MATERIAL_METAL_SPEC_MAP 4u
#define HLGI_MATERIAL_SMOOTH_BASE_ALPHA 8u
#define HLGI_MATERIAL_NORMAL 16u
#define HLGI_MATERIAL_EMISSION 32u
#define HLGI_MATERIAL_OCCLUSION 64u
#define HLGI_MATERIAL_DETAIL 128u
#define HLGI_MATERIAL_DETAIL_SCALED 256u
#define HLGI_MATERIAL_PARALLAX 512u
#define HLGI_MATERIAL_RECEIVE_SHADOWS_OFF 1024u
#define HLGI_MATERIAL_SHADOW_CASTER_DISABLED 8192u

float4 HLGIHitDefaultPackedNormal()
{
#if defined(UNITY_ASTC_NORMALMAP_ENCODING)
    return float4(1,0.5,0,0.5);
#else
    return float4(0.5,0.5,1,1);
#endif
}

bool HLGIHitMaterialFlag(HLGIHitMaterialRecord r,uint flag) { return (r.identity.y&flag)!=0u; }
bool HLGIHitAlphaUsesBaseTexture(HLGIHitMaterialRecord r)
{
    // Unassigned Lit BaseMap is white, so UV displacement cannot change its alpha.
    return (r.identity.w&1u)!=0u && !HLGIHitMaterialFlag(r,HLGI_MATERIAL_SMOOTH_BASE_ALPHA);
}
bool HLGIHitMaterialHeaderValid(HLGIHitMaterialRecord r)
{
    // Bits 11/12 preserve Lit's specular/environment switches for later shading.
    // They do not change the BRDF diffuse share or the material's F0 itself.
    return r.identity.x!=0u && (r.identity.y&~16383u)==0u && r.identity.z<=2u &&
        (r.identity.w&~1023u)==0u;
}
uint2 HLGIHitTextureHandle(HLGIHitMaterialRecord r,uint map)
{
    uint4 pair=map<2u?r.textures0:map<4u?r.textures1:map<6u?r.textures2:map<8u?r.textures3:r.textures4;
    return (map&1u)==0u?pair.xy:pair.zw;
}
bool HLGIHitTexture(HLGIHitMaterialRecord r,uint map,float2 uv,HLGIHitMaterialLods lods,float4 defaultValue,out float4 value)
{
    value=defaultValue;
    if((r.identity.w&(1u<<map))==0u) return true;
    return HLGISampleRayTexture(HLGIHitTextureHandle(r,map),uv,lods.values[map],value);
}
float4 HLGIHitTextureDefault(uint map)
{
    if(map==3u || map==8u) return HLGIHitDefaultPackedNormal();
    if(map==7u) return float4(0.5,0.5,0.5,1);
    if(map==9u) return float4(0,0,0,1);
    return 1;
}
bool HLGIHitMaterialUv(HLGIHitMaterialRecord r,float2 uv,float3 viewDirTS,HLGIHitMaterialLods lods,out float2 mapped)
{
    mapped=uv*r.baseST.xy+r.baseST.zw;
    if(!all(isfinite(uv)) || !all(isfinite(r.baseST)) || !all(isfinite(mapped))) return false;
    if(!HLGIHitMaterialFlag(r,HLGI_MATERIAL_PARALLAX)) return true;
    float lengthSquared=dot(viewDirTS,viewDirTS);
    if(!all(isfinite(viewDirTS)) || !isfinite(lengthSquared) || lengthSquared<=0 || !isfinite(r.detail.w)) return false;
    float4 height;
    if(!HLGIHitTexture(r,9u,mapped,lods,float4(0,0,0,1),height)) return false;
    float3 v=viewDirTS*rsqrt(lengthSquared);v.z+=0.42;
    if(v.z==0 || !all(isfinite(v))) return false;
    // Fixed URP ParallaxOffset1Step: height G, centered displacement, normalized
    // tangent-space view direction. The caller must construct that TBN correctly.
    mapped+=(height.g*r.detail.w-r.detail.w*0.5)*(v.xy/v.z);
    return all(isfinite(mapped));
}

// A false return means unknown, with conservative covered=true. In particular a
// stale/missing alpha texture must not become a transparent candidate. Coverage
// reads only alpha dependencies: non-alpha and smooth-base-alpha need no UV/map.
bool HLGIEvaluateHitCoverage(HLGIHitMaterialRecord r,float2 uv,float3 viewDirTS,HLGIHitMaterialLods lods,out bool covered)
{
    covered=true;
    if(!HLGIHitMaterialHeaderValid(r)) return false;
    if(!HLGIHitMaterialFlag(r,HLGI_MATERIAL_ALPHA_TEST)) return true;
    if(!isfinite(r.baseColor.a) || !isfinite(r.detail.x)) return false;
    float alpha=r.baseColor.a;
    if(HLGIHitAlphaUsesBaseTexture(r))
    {
        float2 mapped;float4 base;
        if(!HLGIHitMaterialUv(r,uv,viewDirTS,lods,mapped) || !HLGIHitTexture(r,0u,mapped,lods,1,base)) return false;
        alpha*=base.a;
    }
    if(!isfinite(alpha)) return false;
    covered=alpha>=r.detail.x;
    return true;
}

bool HLGIEvaluateHitMaterial(HLGIHitMaterialRecord r,float2 uv,float3 viewDirTS,HLGIHitMaterialLods lods,out HLGIHitMaterialSurface surface)
{
    surface=(HLGIHitMaterialSurface)0;
    if(!HLGIHitMaterialHeaderValid(r) || !all(isfinite(r.baseColor)) || !all(isfinite(r.proxyTint)) ||
        !all(isfinite(r.proxyEmission)) || !isfinite(r.surface.y)) return false;
    HLGIHitMaterialSurface s=(HLGIHitMaterialSurface)0;
    float2 mapped;
    if(!HLGIHitMaterialUv(r,uv,viewDirTS,lods,mapped)) return false;
    bool specularWorkflow=HLGIHitMaterialFlag(r,HLGI_MATERIAL_SPECULAR);
    uint required=1u;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_METAL_SPEC_MAP)) required|=specularWorkflow?4u:2u;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_NORMAL)) required|=8u;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_OCCLUSION)) required|=16u;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_EMISSION)) required|=32u;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_DETAIL)) required|=448u;
    float2 detailUv=mapped;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_DETAIL))
    {
        detailUv=mapped*r.detailST.xy+r.detailST.zw;
        if(!all(isfinite(r.detailST)) || !all(isfinite(detailUv))) return false;
    }
    float4 samples[9];bool mapsKnown=true;
    // One bounded sampler loop avoids cloning metadata validation/filtering into
    // every material map call site. Unused maps never become dependencies.
    [loop] for(uint map=0u;map<9u;map++)
    {
        float4 defaultValue=HLGIHitTextureDefault(map),sampled=defaultValue;
        if((required&(1u<<map))!=0u)
        {
            float2 sampleUv=map>=7u?detailUv:mapped;
            bool mapKnown=HLGIHitTexture(r,map,sampleUv,lods,defaultValue,sampled);
            mapsKnown=mapsKnown && mapKnown;
        }
        samples[map]=sampled;
    }
    if(!mapsKnown) return false;
    float4 base=samples[0];
    s.albedo=base.rgb*r.baseColor.rgb;
    s.alpha=HLGIHitMaterialFlag(r,HLGI_MATERIAL_SMOOTH_BASE_ALPHA)?r.baseColor.a:base.a*r.baseColor.a;
    float4 specGloss;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_METAL_SPEC_MAP))
    {
        specGloss=specularWorkflow?samples[2]:samples[1];
    }
    else
    {
        if(specularWorkflow && !all(isfinite(r.specColor.rgb))) return false;
        if(!specularWorkflow && !isfinite(r.surface.x)) return false;
        specGloss=float4(specularWorkflow?r.specColor.rgb:r.surface.xxx,1);
    }
    s.smoothness=(HLGIHitMaterialFlag(r,HLGI_MATERIAL_SMOOTH_BASE_ALPHA)?base.a:specGloss.a)*r.surface.y;
    s.normalTS=float3(0,0,1);
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_NORMAL))
    {
        float4 packed=samples[3];
        if(!isfinite(r.surface.w)) return false;
#if BUMP_SCALE_NOT_SUPPORTED
        s.normalTS=UnpackNormal(packed);
#else
        s.normalTS=UnpackNormalScale(packed,r.surface.w);
#endif
    }
    s.occlusion=1;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_OCCLUSION))
    {
        if(!isfinite(r.surface.z)) return false;
        s.occlusion=1+r.surface.z*(samples[4].g-1);
    }
    float3 emission=0;
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_EMISSION))
    {
        if(!all(isfinite(r.emissionColor.rgb))) return false;
        emission=samples[5].rgb*r.emissionColor.rgb;
    }
    if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_DETAIL))
    {
        float4 mask=samples[6],detailAlbedo=samples[7],detailNormal=samples[8];
        if(!isfinite(r.detail.z)) return false;
        float3 factor=2*detailAlbedo.rgb;
        if(HLGIHitMaterialFlag(r,HLGI_MATERIAL_DETAIL_SCALED))
        {
            if(!isfinite(r.detail.y)) return false;
            factor=2*detailAlbedo.rgb*r.detail.y-r.detail.y+1;
        }
        s.albedo*=1+mask.a*(factor-1);
#if BUMP_SCALE_NOT_SUPPORTED
        float3 dn=UnpackNormal(detailNormal);
#else
        float3 dn=UnpackNormalScale(detailNormal,r.detail.z);
#endif
        float dnLength=dot(dn,dn);
        if(!all(isfinite(dn)) || !isfinite(dnLength) || dnLength<=0 || s.normalTS.z==-1) return false;
        dn*=rsqrt(dnLength);
        s.normalTS=lerp(s.normalTS,BlendNormalRNM(s.normalTS,dn),mask.a);
    }
    // Return Lit BRDF's diffuse share, not Lambert / PI. The transport caller owns
    // its energy cap. Proxy tint affects diffuse only, matching surface capture.
    float oneMinusReflectivity=specularWorkflow?1-max(specGloss.r,max(specGloss.g,specGloss.b)):0.96*(1-specGloss.r);
    s.diffuseReflectance=s.albedo*oneMinusReflectivity*r.proxyTint.rgb;
    s.specular=specularWorkflow?specGloss.rgb:lerp(float3(0.04,0.04,0.04),s.albedo,specGloss.r);
    float3 emitted=(emission+r.proxyEmission.rgb)*r.proxyEmission.w;
    if(!all(isfinite(emission)) || !all(isfinite(emitted))) return false;
    s.emission=max(0,emitted);
    s.receivesShadows=!HLGIHitMaterialFlag(r,HLGI_MATERIAL_RECEIVE_SHADOWS_OFF);
    float normalLength=dot(s.normalTS,s.normalTS);
    if(!all(isfinite(s.albedo)) || !all(isfinite(s.diffuseReflectance)) || !all(isfinite(s.specular)) ||
        !all(isfinite(s.emission)) || !all(isfinite(s.normalTS)) || !isfinite(normalLength) || normalLength<=0 ||
        !isfinite(s.alpha) || !isfinite(s.smoothness) || !isfinite(s.occlusion)) return false;
    // Deliberately not normalized: Lit normalizes after its interpolated TBN.
    surface=s;return true;
}
#endif
