Shader "Hidden/HybridLumenGI/CardCapture"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _MetallicGlossMap("Metallic", 2D) = "white" {}
        _Metallic("Metallic", Range(0,1)) = 0
        _SpecGlossMap("Specular", 2D) = "white" {}
        _SpecColor("Specular", Color) = (0.2,0.2,0.2,1)
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        _SmoothnessTextureChannel("Smoothness Channel", Float) = 0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Float) = 1
        _ParallaxMap("Height", 2D) = "black" {}
        _Parallax("Height Scale", Float) = 0.005
        _OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0,1)) = 1
        _EmissionMap("Emission", 2D) = "white" {}
        [HDR] _EmissionColor("Emission", Color) = (0,0,0,1)
        _DetailMask("Detail Mask", 2D) = "white" {}
        _DetailAlbedoMap("Detail Albedo", 2D) = "linearGrey" {}
        _DetailAlbedoMapScale("Detail Albedo Scale", Float) = 1
        _DetailNormalMap("Detail Normal", 2D) = "bump" {}
        _DetailNormalMapScale("Detail Normal Scale", Float) = 1
        _WorkflowMode("Workflow Mode", Float) = 1
        _AlphaClip("Alpha Clip", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
        _Surface("Surface", Float) = 0
        _Cull("Cull", Float) = 2
        [HideInInspector] _ClearCoatMask("Clear Coat", Float) = 0
        [HideInInspector] _ClearCoatSmoothness("Clear Coat Smoothness", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            Name "CaptureCard"
            Tags { "LightMode"="HybridLumenGICard" }
            ZWrite On ZTest LEqual Cull Off
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex CardVert
            #pragma fragment CardFrag
            #pragma multi_compile_local _ _NORMALMAP
            #pragma multi_compile_local _ _PARALLAXMAP
            #pragma multi_compile_local_fragment _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma multi_compile_local_fragment _ _ALPHATEST_ON
            #pragma multi_compile_local_fragment _ _EMISSION
            #pragma multi_compile_local_fragment _ _METALLICSPECGLOSSMAP
            #pragma multi_compile_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_local_fragment _ _OCCLUSIONMAP
            #pragma multi_compile_local_fragment _ _SPECULAR_SETUP
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"

            float4x4 _HLGI_CardWorldToCard;
            float4 _HLGI_CardRect, _HLGI_CardDirection, _HLGI_CardGeometryDirection, _HLGI_CardTint, _HLGI_CardExtraEmission;
            float _HLGI_CardCull, _HLGI_CardObjectDeterminantSign;
            TEXTURE2D(_HLGI_CardShadowmask); SAMPLER(sampler_HLGI_CardShadowmask);
            float4 _HLGI_CardShadowmaskST;
            float _HLGI_CardUseShadowmask;
            struct CardAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };
            struct CardVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float3 cardPosition : TEXCOORD4;
                float2 shadowmaskUV : TEXCOORD5;
            };
            struct CardOutput
            {
                half4 diffuseOcclusion : SV_Target0;
                half4 emissionValidity : SV_Target1;
                float4 positionDepth : SV_Target2;
                half4 normalRoughness : SV_Target3;
                half4 bakedVisibility : SV_Target4;
            };
            half PackCardGeometricNormal(float3 normal)
            {
                normal /= max(dot(abs(normal),1.0),1e-8);
                float2 oct = normal.xy;
                if(normal.z<0) oct = (1-abs(oct.yx))*float2(oct.x>=0?1:-1,oct.y>=0?1:-1);
                uint2 quantized = (uint2)round(saturate(oct*0.5+0.5)*31);
                // FP16 represents every integer from 1 to 1024 exactly; zero is
                // reserved for uncovered pixels. This is a 10-bit oct normal.
                return (half)(1u+quantized.x+(quantized.y<<5));
            }
            CardVaryings CardVert(CardAttributes input)
            {
                CardVaryings output;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w * GetOddNegativeScale());
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.shadowmaskUV = input.lightmapUV * _HLGI_CardShadowmaskST.xy + _HLGI_CardShadowmaskST.zw;
                output.cardPosition = mul(_HLGI_CardWorldToCard, float4(output.positionWS,1)).xyz;
                float2 atlasUV = _HLGI_CardRect.xy + output.cardPosition.xy * _HLGI_CardRect.zw;
                float2 clipXY = atlasUV * 2 - 1;
                #if UNITY_UV_STARTS_AT_TOP
                    clipXY.y = -clipXY.y;
                #endif
                float depth = output.cardPosition.z;
                #if UNITY_REVERSED_Z
                    depth = 1 - depth;
                #endif
                output.positionCS = float4(clipXY,depth,1);
                return output;
            }
            CardOutput CardFrag(CardVaryings input, FRONT_FACE_TYPE rasterFrontFace : FRONT_FACE_SEMANTIC)
            {
                clip(min(input.cardPosition, 1-input.cardPosition));
                clip(0.5h-_Surface);
                // Keep stock Lit's interpolated/normal-mapped Ns even if an
                // authored vertex normal points against the triangle winding.
                half3 shadingBasisNormal = normalize(input.normalWS);
                float3 derivativeX=ddx(input.positionWS),derivativeY=ddy(input.positionWS);
                float scaleX=max(abs(derivativeX.x),max(abs(derivativeX.y),abs(derivativeX.z)));
                float scaleY=max(abs(derivativeY.x),max(abs(derivativeY.y),abs(derivativeY.z)));
                // Degenerate derivatives cannot establish geometric identity.
                // Never repair them with Ns, which is an independent attribute.
                // Normalize scale before taking the cross, so tiny valid charts
                // do not fail an arbitrary world-area threshold or overflow it.
                if(!all(isfinite(derivativeX)) || !all(isfinite(derivativeY)) || scaleX<=0 || scaleY<=0) discard;
                float3 facet=cross(derivativeX/scaleX,derivativeY/scaleY);
                float facetScale=max(abs(facet.x),max(abs(facet.y),abs(facet.z)));
                if(!all(isfinite(facet)) || facetScale<=0) discard;
                facet/=facetScale;
                facet*=rsqrt(dot(facet,facet));
                if(_HLGI_CardGeometryDirection.w>0.5)
                {
                    // All members face the baked projection ray. Its world-space
                    // direction fixes the derivative sign even when scaling folds
                    // the member's normal away from the seed triangle's normal.
                    if(dot(facet,_HLGI_CardGeometryDirection.xyz)<0) facet=-facet;
                }
                else
                {
                    // DX12 custom-capture contract: default Unity raster winding.
                    // Projection/UV flips change derivatives and FRONT_FACE together.
                    // Undo object reflection to obtain inverse-transpose source Ng,
                    // not the determinant-flipped cross of transformed triangle edges.
                    // An external, unrestored invert-culling state is unsupported.
                    facet*=IS_FRONT_VFACE(rasterFrontFace,1.0,-1.0)*_HLGI_CardObjectDeterminantSign;
                }
                float facing = dot(facet,_HLGI_CardDirection.xyz);
                // Independent of the card projection's screen winding. Preserve
                // the source material's one-/two-sided geometry convention.
                if (_HLGI_CardCull > 1.5) clip(facing);
                else if (_HLGI_CardCull > 0.5) clip(-facing);
                #if defined(_NORMALMAP) || defined(_DETAIL) || defined(_PARALLAXMAP)
                float3 projectedTangent = input.tangentWS.xyz - shadingBasisNormal * dot(input.tangentWS.xyz,shadingBasisNormal);
                bool hasTangent = dot(projectedTangent,projectedTangent) > 1e-8;
                #endif
                float2 uv = input.uv;
                #if defined(_PARALLAXMAP)
                if(hasTangent)
                {
                    half3 tangent = normalize(projectedTangent);
                    half3 bitangent = (input.tangentWS.w < 0 ? -1 : 1) * cross(shadingBasisNormal,tangent);
                    half3x3 tangentToWorld = half3x3(tangent,bitangent,shadingBasisNormal);
                    // The chart facing score can exceed half range. URP normalizes
                    // its half3 argument, so remove the scale before narrowing.
                    float3 viewWS=_HLGI_CardDirection.xyz;
                    float largest=max(abs(viewWS.x),max(abs(viewWS.y),abs(viewWS.z)));
                    ApplyPerPixelDisplacement(mul(tangentToWorld,viewWS/max(1.0,largest)),uv);
                }
                #endif
                SurfaceData surface;
                InitializeStandardLitSurfaceData(uv,surface);
                BRDFData brdf;
                InitializeBRDFData(surface,brdf);
                half3 normal = shadingBasisNormal;
                #if defined(_NORMALMAP) || defined(_DETAIL)
                if(hasTangent)
                {
                    // Match Lit and exact hits: transform with the original interpolants,
                    // then normalize the mapped normal, not the tangent frame.
                    float3 bitangent = input.tangentWS.w * cross(input.normalWS,input.tangentWS.xyz);
                    half3x3 tangentToWorld = half3x3(input.tangentWS.xyz,bitangent,input.normalWS);
                    float3 mappedNormal = TransformTangentToWorld(surface.normalTS,tangentToWorld);
                    if(all(isfinite(mappedNormal)) && dot(mappedNormal,mappedNormal)>1e-16)
                        normal = NormalizeNormalPerPixel(mappedNormal);
                }
                #endif
                CardOutput output;
                output.diffuseOcclusion = half4(saturate(brdf.diffuse*_HLGI_CardTint.rgb),saturate(surface.occlusion));
                output.emissionValidity = half4(max(0,(surface.emission+_HLGI_CardExtraEmission.rgb)*_HLGI_CardExtraEmission.w),PackCardGeometricNormal(facet));
                output.positionDepth = float4(input.positionWS,input.cardPosition.z);
                output.normalRoughness = half4(normal,saturate(1-surface.smoothness));
                output.bakedVisibility = 1;
                if (_HLGI_CardUseShadowmask > 0.5)
                    output.bakedVisibility = SAMPLE_TEXTURE2D(_HLGI_CardShadowmask, sampler_HLGI_CardShadowmask, input.shadowmaskUV);
                return output;
            }
            ENDHLSL
        }
        Pass
        {
            Name "ClearCardTile"
            ZWrite On ZTest Always Cull Off
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex CardClearVert
            #pragma fragment CardClearFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            float4 _HLGI_CardRect;
            struct ClearVaryings { float4 positionCS : SV_POSITION; };
            struct ClearOutput
            {
                float4 a : SV_Target0;
                float4 b : SV_Target1;
                float4 c : SV_Target2;
                float4 d : SV_Target3;
                float4 bakedVisibility : SV_Target4;
                float depth : SV_Depth;
            };
            ClearVaryings CardClearVert(uint vertexID:SV_VertexID)
            {
                // Two triangles, bounded to this tile. A scaled fullscreen
                // triangle would spill into neighboring resident atlas pages.
                static const float2 vertices[6] = { float2(0,0),float2(1,0),float2(0,1),float2(0,1),float2(1,0),float2(1,1) };
                float2 xy = (_HLGI_CardRect.xy + vertices[vertexID] * _HLGI_CardRect.zw) * 2 - 1;
                #if UNITY_UV_STARTS_AT_TOP
                    xy.y = -xy.y;
                #endif
                ClearVaryings output;
                output.positionCS = float4(xy,0,1);
                return output;
            }
            ClearOutput CardClearFrag(ClearVaryings input)
            {
                ClearOutput output = (ClearOutput)0;
                output.bakedVisibility = 1;
                #if !UNITY_REVERSED_Z
                    output.depth = 1;
                #endif
                return output;
            }
            ENDHLSL
        }
    }
    Fallback Off
}
