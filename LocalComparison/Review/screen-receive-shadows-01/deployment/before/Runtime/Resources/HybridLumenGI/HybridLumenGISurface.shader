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
            #pragma multi_compile_fragment _ _EMISSION
            #pragma multi_compile_fragment _ _OCCLUSIONMAP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "HybridLumenGIReceiverPolicyCapture.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_SpecGlossMap); SAMPLER(sampler_SpecGlossMap);
            TEXTURE2D(_OcclusionMap); SAMPLER(sampler_OcclusionMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor, _SpecColor, _EmissionColor;
                half _Metallic, _OcclusionStrength, _WorkflowMode;
                half _AlphaClip, _Cutoff, _Surface, _SmoothnessTextureChannel;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            struct SurfaceOutput
            {
                // Linear diffuse reflectance, including dielectric/metal split.
                half4 diffuseOcclusion : SV_Target0;
                // Linear emitted radiance; alpha is the valid-material marker.
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
                output.diffuseOcclusion = half4(saturate(baseSample.rgb * _BaseColor.rgb) * diffuseFraction, saturate(occlusion));
                output.emissionValidity = half4(emission, 1.0h);
                output.receiverPolicy = HLGICaptureReceiverPolicy();
                return output;
            }
            ENDHLSL
        }
    }
    Fallback Off
}
