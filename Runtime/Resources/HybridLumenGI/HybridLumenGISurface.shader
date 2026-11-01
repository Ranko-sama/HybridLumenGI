Shader "Hidden/HybridLumenGI/SurfaceData"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1,1,1,1)
        _MetallicGlossMap("Metallic", 2D) = "white" {}
        _Metallic("Metallic", Range(0,1)) = 0
        _SpecGlossMap("Specular", 2D) = "white" {}
        _SpecColor("Specular", Color) = (0.2,0.2,0.2,1)
        _OcclusionMap("Occlusion", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0,1)) = 1
        _EmissionMap("Emission", 2D) = "white" {}
        [HDR] _EmissionColor("Emission", Color) = (0,0,0,1)
        _DetailMask("Detail Mask", 2D) = "white" {}
        _DetailAlbedoMap("Detail Albedo", 2D) = "linearGrey" {}
        _DetailAlbedoMapScale("Detail Albedo Scale", Float) = 1
        _ParallaxMap("Height Map", 2D) = "black" {}
        _Parallax("Height Scale", Range(0.005, 0.08)) = 0.005
        _WorkflowMode("Workflow Mode", Float) = 1
        _SmoothnessTextureChannel("Smoothness Texture Channel", Float) = 0
        _AlphaClip("Alpha Clip", Float) = 0
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
        _Surface("Surface", Float) = 0
        _Cull("Cull", Float) = 2
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        Pass
        {
            Name "HybridLumenGISurface"
            Tags { "LightMode"="HybridLumenGISurface" }
            ZWrite On ZTest LEqual Cull [_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            // Override shaders do not have their own material assets. Keep these
            // variants in players; shader_feature could strip required variants.
            #pragma multi_compile_fragment _ _METALLICSPECGLOSSMAP
            #pragma multi_compile_local_fragment _ _SPECULAR_SETUP
            #pragma multi_compile_fragment _ _EMISSION
            #pragma multi_compile_fragment _ _OCCLUSIONMAP
            #pragma multi_compile_local_fragment _ _ALPHATEST_ON
            #pragma multi_compile_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_local_fragment _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma multi_compile_local_fragment _ _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_local _ _PARALLAXMAP
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #if defined(LOD_FADE_CROSSFADE)
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
            #endif
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
            #include "HybridLumenGIReceiverPolicyCapture.hlsl"
            #include "HybridLumenGIScreenMaterial.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_SpecGlossMap); SAMPLER(sampler_SpecGlossMap);
            TEXTURE2D(_OcclusionMap); SAMPLER(sampler_OcclusionMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_DetailMask); SAMPLER(sampler_DetailMask);
            TEXTURE2D(_DetailAlbedoMap); SAMPLER(sampler_DetailAlbedoMap);
            TEXTURE2D(_ParallaxMap); SAMPLER(sampler_ParallaxMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _DetailAlbedoMap_ST;
                half4 _BaseColor, _SpecColor, _EmissionColor;
                half _Metallic, _OcclusionStrength, _WorkflowMode;
                half _AlphaClip, _Cutoff, _Surface, _SmoothnessTextureChannel;
                half _DetailAlbedoMapScale, _Parallax;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                #if defined(_PARALLAXMAP)
                    float3 normalOS : NORMAL;
                    float4 tangentOS : TANGENT;
                #endif
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                #if defined(_PARALLAXMAP)
                    half3 viewDirTS : TEXCOORD1;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            struct SurfaceOutput
            {
                // Linear diffuse reflectance, including dielectric/metal split.
                half4 diffuseOcclusion : SV_Target0;
                // Linear emitted radiance; alpha carries validity and shadow policy.
                half4 emissionValidity : SV_Target1;
                // R32G32_UInt: GameObject layer bit and Renderer rendering mask.
                uint2 receiverPolicy : SV_Target2;
            };
            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                #if defined(_PARALLAXMAP)
                    // Match Lit's per-vertex tangent-space view before interpolation.
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                    real sign = input.tangentOS.w * GetOddNegativeScale();
                    half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                    output.viewDirTS = GetViewDirectionTangentSpace(tangentWS, normalInput.normalWS, viewDirWS);
                #endif
                return output;
            }
            SurfaceOutput Frag(Varyings input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                clip(0.5h - _Surface);
                #if defined(_PARALLAXMAP)
                    // Base ST is already applied; every material read shares this offset.
                    input.uv += ParallaxMapping(TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap), input.viewDirTS, _Parallax, input.uv);
                #endif
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                // Lit's compiled keywords determine coverage; numeric uniforms
                // (including MPB overrides) do not switch shader variants.
                #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
                    half coverage = _BaseColor.a;
                #else
                    half coverage = baseSample.a * _BaseColor.a;
                #endif
                #if defined(_ALPHATEST_ON)
                    clip(coverage - _Cutoff);
                #endif
                #if defined(LOD_FADE_CROSSFADE)
                    LODFadeCrossFade(input.positionCS);
                #endif

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
                #if defined(_SPECULAR_SETUP)
                    half diffuseFraction = 1.0h - max(specular.r, max(specular.g, specular.b));
                #else
                    half diffuseFraction = 0.96h * (1.0h - metallic);
                #endif
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
                output.diffuseOcclusion = half4(saturate(albedo * diffuseFraction), saturate(occlusion));
                output.emissionValidity = half4(emission, HLGIEncodeScreenMaterial(1.0h, HLGICaptureReceivesShadows()));
                output.receiverPolicy = HLGICaptureReceiverPolicy();
                return output;
            }
            ENDHLSL
        }
    }
    Fallback Off
}
