
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        float4x4 _HLGI_IdentityObjectToWorld;
        float4x4 _HLGI_IdentityViewProjection;
        float4 _HLGI_IdentityBaseMapST;
        // Frozen (base color alpha, cutoff, alpha-test keyword, smoothness-alpha keyword).
        float4 _HLGI_IdentityAlphaParams;
        float _HLGI_IdentityHasBaseMap;
        uint _HLGI_IdentityOwnerIndexPlusOne;
        // MPB has SetVector but no integer-vector setter. Sizes <=16384 are exact floats.
        float4 _HLGI_IdentityFullSize;
        TEXTURE2D(_HLGI_IdentityBaseMap);
        SAMPLER(sampler_HLGI_IdentityBaseMap);
        Texture2D<float> _HLGI_IdentityCameraDepth;
        Texture2D<float> _HLGI_IdentityCaptureDepth;
        // A single dummy RT occupies slot 0. CPU binds this structured UAV at u1.
        RWStructuredBuffer<uint3> _HLGI_IdentityCandidates : register(u1);
        #include "C:/Users/Administrator/Desktop/test/HybridLumenGI/LocalComparison/Review/camera-identity-depth-diagnostic-01/instrumentation/prepared/Assets/CameraMotionTaa01/CameraIdentityDepthDiagnostic.hlsl"

        struct IdentityAttributes { float3 positionOS:POSITION; float2 uv:TEXCOORD0; };
        struct IdentityVaryings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };
        IdentityVaryings HLGIIdentityVertex(IdentityAttributes input)
        {
            IdentityVaryings output;
            output.positionCS=mul(_HLGI_IdentityViewProjection,
                mul(_HLGI_IdentityObjectToWorld,float4(input.positionOS,1)));
            output.uv=input.uv*_HLGI_IdentityBaseMapST.xy+_HLGI_IdentityBaseMapST.zw;
            return output;
        }

        float4 HLGIIdentityFragment(IdentityVaryings input,uint primitive:SV_PrimitiveID):SV_Target
        {
            HLGIIdentityProbeEntry(input.positionCS);
        #if defined(DEBUG_DISPLAY)
            // GPU keyword state may have been changed by an already queued command.
            // Debug coverage is not modeled; this variant has no UAV claim instructions.
            discard;
            return 0;
        #else
            // This global also affects stock Lit's clip threshold when material AlphaToMask
            // is disabled. A CPU Shader.GetGlobalFloat observation cannot replace this gate.
            if(_AlphaToMaskAvailable!=0) discard;
            // Sample before depth-divergent rejection: implicit UV derivatives and
            // Core's _GlobalMipBias match the supported ordinary Lit alpha path.
            half sampledAlpha=1;
            if(_HLGI_IdentityHasBaseMap!=0)
                sampledAlpha=(half)SAMPLE_TEXTURE2D(_HLGI_IdentityBaseMap,sampler_HLGI_IdentityBaseMap,input.uv).a;
            half alpha=_HLGI_IdentityAlphaParams.w!=0 ? (half)_HLGI_IdentityAlphaParams.x :
                sampledAlpha*(half)_HLGI_IdentityAlphaParams.x;
            if(!isfinite(alpha)||!all(isfinite(input.positionCS))||
                !all(isfinite(_HLGI_IdentityAlphaParams))) discard;
            if(_HLGI_IdentityAlphaParams.z!=0) clip(alpha-(half)_HLGI_IdentityAlphaParams.y);
            if(!all(isfinite(_HLGI_IdentityFullSize.xy))||any(_HLGI_IdentityFullSize.xy<1)||
                any(_HLGI_IdentityFullSize.xy>16384)||any(floor(_HLGI_IdentityFullSize.xy)!=_HLGI_IdentityFullSize.xy)) discard;
            uint2 fullSize=(uint2)_HLGI_IdentityFullSize.xy;
            if(any(input.positionCS.xy<0)||any(input.positionCS.xy>=(float2)fullSize)||
                _HLGI_IdentityOwnerIndexPlusOne==0||primitive==0xffffffffu) discard;
            uint2 pixel=(uint2)input.positionCS.xy;
            float cameraDepth=_HLGI_IdentityCameraDepth.Load(int3(pixel,0));
            float captureDepth=_HLGI_IdentityCaptureDepth.Load(int3(pixel,0));
            HLGIIdentityProbeDepth(input.positionCS,primitive,cameraDepth,captureDepth);
            if(!isfinite(cameraDepth)||!isfinite(captureDepth)||cameraDepth<0||cameraDepth>1||
                captureDepth<0||captureDepth>1||input.positionCS.z!=cameraDepth||cameraDepth!=captureDepth) discard;
            uint address=pixel.y*fullSize.x+pixel.x;
            uint previous;
            InterlockedCompareExchange(_HLGI_IdentityCandidates[address].x,0u,
                _HLGI_IdentityOwnerIndexPlusOne,previous);
            if(previous==0u)
                _HLGI_IdentityCandidates[address].z=primitive+1u; // Only the CAS winner writes this lane.
            else
                InterlockedOr(_HLGI_IdentityCandidates[address].y,1u); // Same owner is still ambiguous.
            // No in-pass reader. The resolve dispatch requires a full UAV dependency after all draws.
            return 0;
        #endif
        }
        