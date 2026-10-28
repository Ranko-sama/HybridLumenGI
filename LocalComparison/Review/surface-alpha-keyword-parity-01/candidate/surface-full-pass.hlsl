
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
            #pragma multi_compile_local_fragment _ _ALPHATEST_ON
            #pragma multi_compile_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_local_fragment _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma multi_compile_local_fragment _ _RECEIVE_SHADOWS_OFF
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "HybridLumenGIReceiverPolicyCapture.hlsl"
            #include "HybridLumenGIScreenMaterial.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
            TEXTURE2D(_SpecGlossMap); SAMPLER(sampler_SpecGlossMap);
            TEXTURE2D(_OcclusionMap); SAMPLER(sampler_OcclusionMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_DetailMask); SAMPLER(sampler_DetailMask);
            TEXTURE2D(_DetailAlbedoMap); SAMPLER(sampler_DetailAlbedoMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _DetailAlbedoMap_ST;
                half4 _BaseColor, _SpecColor, _EmissionColor;
                half _Metallic, _OcclusionStrength, _WorkflowMode;
                half _AlphaClip, _Cutoff, _Surface, _SmoothnessTextureChannel;
                half _DetailAlbedoMapScale;
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
                return output;
            }
            SurfaceOutput Frag(Varyings input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                clip(0.5h - _Surface);
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
            