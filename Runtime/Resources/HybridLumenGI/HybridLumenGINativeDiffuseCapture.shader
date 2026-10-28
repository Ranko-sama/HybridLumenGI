Shader "Hidden/HybridLumenGI/NativeDiffuseCapture"
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
            Name "NativeDiffuseCapture"
            Tags { "LightMode"="HybridLumenGINativeDiffuse" }
            ZWrite On ZTest LEqual Cull [_Cull]
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex LitPassVertex
            #pragma fragment HLGICaptureNativeDiffuse

            // Preserve source Lit keyword names and variants. RendererList
            // overrideShader's local keyword parity still requires Unity testing;
            // DXC compilation does not validate the engine's variant selection.
            #pragma multi_compile_local _ _NORMALMAP
            #pragma multi_compile_local _ _PARALLAXMAP
            #pragma multi_compile_local _ _RECEIVE_SHADOWS_OFF
            #pragma multi_compile_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma multi_compile_local_fragment _ _SURFACE_TYPE_TRANSPARENT
            #pragma multi_compile_local_fragment _ _ALPHATEST_ON
            #pragma multi_compile_local_fragment _ _EMISSION
            #pragma multi_compile_local_fragment _ _METALLICSPECGLOSSMAP
            #pragma multi_compile_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_local_fragment _ _OCCLUSIONMAP
            #pragma multi_compile_local_fragment _ _SPECULAR_SETUP
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ USE_LEGACY_LIGHTMAPS
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            // Explicit failure variants prevent silent SH fallback when APV is on.
            #pragma multi_compile _ PROBE_VOLUMES_L1 PROBE_VOLUMES_L2
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            #include "HybridLumenGIReceiverPolicyCapture.hlsl"
            #include "HybridLumenGIScreenMaterial.hlsl"

            struct HLGIDiffuseCaptureOutput
            {
                // The first three targets require linear RGBA16F. BRDF diffuse must not
                // be quantized to UNorm before subtracting the native HDR term.
                half4 diffuseOcclusion : SV_Target0;
                half4 emissionValidity : SV_Target1;
                half4 nativeDiffuseFog : SV_Target2;
                // R32G32_UInt, preserving both complete 32-bit layer masks.
                uint2 receiverPolicy : SV_Target3;
            };

            HLGIDiffuseCaptureOutput HLGICaptureNativeDiffuse(Varyings input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                HLGIDiffuseCaptureOutput output = (HLGIDiffuseCaptureOutput)0;

                // This capture is the stock Lit Forward/Forward+ contract only.
                // Deferred is rejected by the renderer feature before this draw.
                // Subtractive can contain baked direct lighting which our GI
                // cannot recover independently. Debug color overrides are not PBR.
                #if defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2) || defined(_MIXED_LIGHTING_SUBTRACTIVE) || defined(DEBUG_DISPLAY) || defined(_SURFACE_TYPE_TRANSPARENT)
                    return output;
                #else
                    clip(0.5h - _Surface);
                    #if defined(_PARALLAXMAP)
                        #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                            half3 viewDirTS = input.viewDirTS;
                        #else
                            half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                            half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
                        #endif
                        ApplyPerPixelDisplacement(viewDirTS, input.uv);
                    #endif
                    SurfaceData surfaceData;
                    InitializeStandardLitSurfaceData(input.uv, surfaceData);
                    #ifdef LOD_FADE_CROSSFADE
                        LODFadeCrossFade(input.positionCS);
                    #endif
                    InputData inputData;
                    InitializeInputData(input, surfaceData.normalTS, inputData);
                    #if defined(_DBUFFER)
                        ApplyDecalToSurfaceData(input.positionCS, surfaceData, inputData);
                    #endif
                    InitializeBakedGIData(input, inputData);

                    // Same ordering as UniversalFragmentPBR at pinned Unity
                    // Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53.
                    BRDFData brdfData;
                    InitializeBRDFData(surfaceData, brdfData);
                    half4 shadowMask = CalculateShadowMask(inputData);
                    AmbientOcclusionFactor ao = CreateAmbientOcclusionFactor(inputData, surfaceData);
                    Light mainLight = GetMainLight(inputData, shadowMask, ao);
                    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);
                    half3 nativeDiffuse = inputData.bakedGI * brdfData.diffuse * ao.indirectAmbientOcclusion;

                    // MixFogColor(1,0) matches fog enable/debug and the no-fog
                    // branch. ComputeFogIntensity alone returns zero without fog.
                    half fogTransmission = MixFogColor(half3(1,1,1), half3(0,0,0), inputData.fogCoord).r;
                    output.diffuseOcclusion = half4(brdfData.diffuse, ao.indirectAmbientOcclusion);
                    // Magnitude [1,2] encodes valid + material-only AO; sign is
                    // Receive Shadows. Final receiver target0.a also includes
                    // native SSAO. Uncovered/rejected pixels remain zero.
                    output.emissionValidity = half4(surfaceData.emission, HLGIEncodeScreenMaterial(1 + saturate(surfaceData.occlusion), HLGICaptureReceivesShadows()));
                    output.nativeDiffuseFog = half4(nativeDiffuse, fogTransmission);
                    output.receiverPolicy = HLGICaptureReceiverPolicy();
                    return output;
                #endif
            }
            ENDHLSL
        }
    }
    Fallback Off
}
