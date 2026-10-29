bool ValidDepth(float d)
{
#if UNITY_REVERSED_Z
    return d > 1e-6;
#else
    return d < 1-1e-6;
#endif
}

float3 WorldPosition(float2 uv,float depth,float4x4 invVP)
{
    // uv is already the exact center of the full-resolution depth sample.
    // GI/history callers use HLGIGiSampleUv; do not snap a second time here.
#if !UNITY_REVERSED_Z
    depth=lerp(UNITY_NEAR_CLIP_VALUE,1,depth);
#endif
    // ComputeWorldSpacePosition includes the UV-origin transform needed by Unity GPU matrices.
    return ComputeWorldSpacePosition(uv,depth,invVP);
}

float3 NormalAt(float2 uv)
{
    float3 n=_HLGI_Normals.SampleLevel(sampler_PointClamp,uv,0).xyz;
    if(_HLGI_NormalsOct!=0) n=UnpackNormalOctQuadEncode(Unpack888ToFloat2(n)*2-1);
    return dot(n,n)>0.01 ? normalize(n) : float3(0,1,0);
}

bool HLGIScreenDepthDelta(int2 pixel,int2 axis,float depth,float3 position,out float3 derivative)
{
    derivative=0;
    int2 size=(int2)_HLGI_FullSize.xy;
    float bestError=1e20,bestDepth=0,bestPrediction=0;int bestSide=0;
    // The raw-depth slope selection follows URP's ReconstructNormalTap9 at
    // Graphics feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53. Unlike that shading
    // helper, reject missing/ambiguous support instead of clamping edge samples.
    [unroll] for(int side=-1;side<=1;side+=2)
    {
        int2 nearPixel=pixel+axis*side,farPixel=pixel+axis*(side*2);
        if(any(nearPixel<0)||any(nearPixel>=size)||any(farPixel<0)||any(farPixel>=size)) continue;
        float nearDepth=_HLGI_Depth.Load(int3(nearPixel,0)),farDepth=_HLGI_Depth.Load(int3(farPixel,0));
        if(!isfinite(nearDepth)||!isfinite(farDepth)||nearDepth<0||nearDepth>1||farDepth<0||farDepth>1||
            !ValidDepth(nearDepth)||!ValidDepth(farDepth)) continue;
        float predictedDepth=2*nearDepth-farDepth;
        float error=abs(predictedDepth-depth);
        if(predictedDepth<0||predictedDepth>1||error>=bestError) continue;
        bestError=error;bestSide=side;bestDepth=nearDepth;bestPrediction=predictedDepth;
    }
    if(bestSide==0) return false;
    float2 uv=HLGIFullPixelCenterUv((uint2)pixel,(uint2)_HLGI_FullSize.xy);
    float3 predictedPosition=WorldPosition(uv,bestPrediction,_HLGI_InvVP);
    float tolerance=max(0.002,abs(mul(_HLGI_View,float4(position,1)).z)*1e-4);
    if(!all(isfinite(predictedPosition))||distance(predictedPosition,position)>tolerance) return false;
    float2 neighborUv=HLGIFullPixelCenterUv((uint2)(pixel+axis*bestSide),(uint2)_HLGI_FullSize.xy);
    derivative=(WorldPosition(neighborUv,bestDepth,_HLGI_InvVP)-position)*bestSide;
    float lengthSquared=dot(derivative,derivative);
    if(!all(isfinite(derivative))||!isfinite(lengthSquared)||lengthSquared<1e-16) return false;
    return true;
}

bool HLGIScreenDepthDerivative(int2 pixel,int2 axis,float depth,float3 position,out float3 derivative)
{
    if(!HLGIScreenDepthDelta(pixel,axis,depth,position,derivative)) return false;
    derivative*=rsqrt(dot(derivative,derivative));return true;
}

bool HLGITryScreenRayFootprint(float2 uv,float depth,float3 position,float3 direction,out HLGIRayFootprint footprint)
{
    footprint=(HLGIRayFootprint)0;
    if(!isfinite(depth)||depth<0||depth>1||!ValidDepth(depth)||!all(isfinite(position))||!all(isfinite(uv))) return false;
    int2 pixel=(int2)floor(uv*_HLGI_FullSize.xy);
    if(any(pixel<0)||any(pixel>=(int2)_HLGI_FullSize.xy)) return false;
    float3 dx,dy;
    if(!HLGIScreenDepthDelta(pixel,int2(1,0),depth,position,dx)||
        !HLGIScreenDepthDelta(pixel,int2(0,1),depth,position,dy)) return false;
    // Delta retains world units per full pixel. The GI grid selects a full-pixel
    // center; it does not represent a larger pixel footprint at lower GI scales.
    return HLGITryScreenFootprint(position,position+dx,position+dy,float2(1,1),float2(1,1),direction,footprint);
}

bool HLGITryScreenGeometricNormal(float2 uv,float depth,float3 position,out float3 geometricNormal)
{
    geometricNormal=0;
    if(!isfinite(depth)||depth<0||depth>1||!ValidDepth(depth)||!all(isfinite(position))) return false;
    int2 pixel=(int2)floor(uv*_HLGI_FullSize.xy);
    if(any(pixel<0)||any(pixel>=(int2)_HLGI_FullSize.xy)) return false;
    float3 horizontal,vertical;
    if(!HLGIScreenDepthDerivative(pixel,int2(1,0),depth,position,horizontal)||
        !HLGIScreenDepthDerivative(pixel,int2(0,1),depth,position,vertical)) return false;
    float3 crossNormal=cross(horizontal,vertical);
    float lengthSquared=dot(crossNormal,crossNormal);
    if(!all(isfinite(crossNormal))||!isfinite(lengthSquared)||lengthSquared<1e-6) return false;
    geometricNormal=crossNormal*rsqrt(lengthSquared);
    // An inverse-projected near point supplies the camera-facing orientation for
    // perspective/orthographic matrices and either UV origin. Ns is never used
    // to infer geometric orientation. This remains a depth estimate, not mesh Ng.
#if UNITY_REVERSED_Z
    const float nearDepth=1;
#else
    const float nearDepth=0;
#endif
    float3 towardCamera=WorldPosition(HLGIFullPixelCenterUv((uint2)pixel,(uint2)_HLGI_FullSize.xy),nearDepth,_HLGI_InvVP)-position;
    float facing=dot(geometricNormal,towardCamera);
    if(!all(isfinite(towardCamera))||!isfinite(facing)||abs(facing)<1e-8) { geometricNormal=0;return false; }
    if(facing<0) geometricNormal=-geometricNormal;
    return true;
}

bool HLGITryScreenWorldMatch(float2 uv,float depth,float3 position,float3 estimatedGeometricNormal,out HLGIHit hit)
{
    float probeDistance=max(_HLGI_RayBias*2,0.03);
    HLGIRayFootprint footprint;
    HLGITryScreenRayFootprint(uv,depth,position,-estimatedGeometricNormal,footprint);
    if(!TraceSceneVisibilityHit(position+estimatedGeometricNormal*probeDistance,-estimatedGeometricNormal,probeDistance*2,
        footprint,_HLGI_MaterialView,hit)) return false;
    if(!HLGIHitMaterialKnown(hit) || !HLGIHitHas(hit.flags,HLGI_HIT_GEOMETRIC_NORMAL) ||
        abs(hit.t-probeDistance)>max(0.002,min(_HLGI_RayBias,0.03)) ||
        abs(dot(hit.rawNg,estimatedGeometricNormal))<0.85) return false;
    // The screen estimate faces the camera. A CullOff/CullFront triangle's raw
    // source winding may face away; preserve it in hit for exact card lookup.
    return true;
}
