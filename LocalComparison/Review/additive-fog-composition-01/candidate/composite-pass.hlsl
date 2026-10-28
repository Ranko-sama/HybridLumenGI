
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "HybridLumenGIScreenGeometry.hlsl"
        #include "HybridLumenGIScreenSampling.hlsl"
        #include "HybridLumenGIScreenMaterial.hlsl"
        Texture2D<float4> _HLGI_GITexture, _HLGI_Geometry, _HLGI_Diffuse, _HLGI_Emission, _HLGI_Normals, _HLGI_Moments;
        Texture2D<float> _HLGI_Depth, _HLGI_CaptureDepth;
        Texture2D<float4> _HLGI_NativeDiffuseFog;
        float4 _HLGI_Size;
        float4x4 _HLGI_InvVP;
        float _HLGI_Intensity, _HLGI_DepthThreshold;
        int _HLGI_Debug, _HLGI_NormalsOct, _HLGI_Composition;
        struct Attributes { uint vertexID:SV_VertexID; };
        struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };
        Varyings Vert(Attributes v)
        {
            Varyings o; o.positionCS=GetFullScreenTriangleVertexPosition(v.vertexID);
            o.uv=GetFullScreenTriangleTexCoord(v.vertexID); return o;
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
        #include "HybridLumenGIRadianceValidity.hlsl"
        float4 Resolve(float2 uv,out bool resolved)
        {
            resolved=false;
            uint fullWidth,fullHeight;_HLGI_Depth.GetDimensions(fullWidth,fullHeight);
            uint2 fullSize=uint2(fullWidth,fullHeight);
            uint2 fullPixel=HLGIFullPixelForUv(uv,fullSize);
            uv=HLGIFullPixelCenterUv(fullPixel,fullSize);
            float depth=_HLGI_Depth.Load(int3(fullPixel,0));
            float3 p=Reconstruct(uv,depth);
            float3 n=_HLGI_Normals.Load(int3(fullPixel,0)).xyz;
            if(_HLGI_NormalsOct!=0) n=UnpackNormalOctQuadEncode(Unpack888ToFloat2(n)*2-1);
            if(!all(isfinite(n))||dot(n,n)<0.01) return 0;
            n=normalize(n);
            uint2 lower,upper;float2 f;
            HLGIGiBilinearFootprint(uv,(uint2)_HLGI_Size.xy,fullSize,lower,upper,f);
            float4 sum=0; float total=0;
            [unroll] for(int y=0;y<2;y++) [unroll] for(int x=0;x<2;x++)
            {
                uint2 q=uint2(x==0?lower.x:upper.x,y==0?lower.y:upper.y);
                float4 sampleGI=_HLGI_GITexture.Load(int3(q,0));
                // Missing/unknown radiance is not measured black. In particular,
                // it cannot authorize subtracting the camera's native diffuse GI.
                if(!HLGIHasRadianceMeasurement(sampleGI)) continue;
                float4 g=_HLGI_Geometry.Load(int3(q,0));
                float3 shadingNormal,geometricNormal;bool hasGeometry;
                if(!HLGIDecodeScreenGeometry(g,shadingNormal,geometricNormal,hasGeometry)) continue;
                uint2 sampleFullPixel=HLGIFullPixelForGiPixel(q,(uint2)_HLGI_Size.xy,fullSize);
                float2 sampleUV=HLGIFullPixelCenterUv(sampleFullPixel,fullSize);
                bool sameFullPixel=all(sampleFullPixel==fullPixel);
                // Unknown Ng is a valid traced receiver, not an empty texel. Its
                // estimate may resolve its own full-resolution sample only.
                if(!hasGeometry)
                {
                    if(!sameFullPixel) continue;
                    // Its own fallback is authoritative: do not dilute it with
                    // already-visited neighbors whose geometry differs/was known.
                    resolved=true;return sampleGI;
                }
                float3 qp=Reconstruct(sampleUV,g.w);
                float weight=(x==0?1-f.x:f.x)*(y==0?1-f.y:f.y);
                float planeWeight=exp(-abs(dot(qp-p,geometricNormal))/max(_HLGI_DepthThreshold,0.001));
                weight*=pow(saturate(dot(n,shadingNormal)),32)*planeWeight;
                if(!isfinite(weight) || weight<=0) continue;
                sum+=sampleGI*weight; total+=weight;
            }
            float4 result=total>1e-5 && isfinite(total)?sum/total:0;
            resolved=HLGIHasRadianceMeasurement(result);
            return resolved?result:0;
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
        