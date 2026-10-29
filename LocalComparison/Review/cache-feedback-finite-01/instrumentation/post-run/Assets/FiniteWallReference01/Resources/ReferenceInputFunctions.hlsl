uint HLGIHash(uint x)
{
    x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; return x ^ (x >> 16);
}

float Random(inout uint s) { s = HLGIHash(s); return (s >> 8) * (1.0 / 16777216.0); }

float3 CosineHemisphere(float3 n, float2 xi)
{
    float r = sqrt(xi.x), phi = TWO_PI * xi.y;
    float3 t = normalize(cross(abs(n.z) < 0.999 ? float3(0,0,1) : float3(0,1,0), n));
    return t * (r * cos(phi)) + cross(n,t) * (r * sin(phi)) + n * sqrt(1-xi.x);
}

float3 HLGISampleDirection(float3 n,float4 guide,inout uint rng,out float weight)
{
    float mixture=guide.w>1e-6 && dot(guide.xyz,guide.xyz)>0.5 ? _HLGI_GuideWeight:0;
    float3 axis=mixture>0 ? normalize(guide.xyz):n;
    float branch=Random(rng);
    float2 xi=float2(Random(rng),Random(rng));
    float3 direction=CosineHemisphere(branch<mixture?axis:n,xi);
    float cosine=saturate(dot(n,direction)), guidedCosine=saturate(dot(axis,direction));
    // One-sample mixture estimator: full mixture PDF, including the branch not chosen.
    // Samples below the receiver hemisphere have zero contribution, never get resampled.
    weight=cosine/max((1-mixture)*cosine+mixture*guidedCosine,1e-8);
    return direction;
}
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
bool HLGISurfaceAtlasRect(float4 rect,out int2 minimum,out int2 count)
{
    minimum=0;count=0;
    if(!all(isfinite(rect)) || any(rect<0) || any(rect>1) ||
        !all(isfinite(_HLGI_SurfaceAtlasSize.xy)) || any(_HLGI_SurfaceAtlasSize.xy<1) ||
        any(_HLGI_SurfaceAtlasSize.xy>32768)) return false;
    int2 dimensions=(int2)round(_HLGI_SurfaceAtlasSize.xy);
    minimum=(int2)round(rect.xy*dimensions);
    count=(int2)round(rect.zw*dimensions);
    return all(count>0) && all(minimum>=0) && all(minimum+count<=dimensions);
}

float3 HLGIDecodeSurfaceGeometricNormal(float packed)
{
    uint code=(uint)round(packed)-1u;
    float2 oct=float2(code&31u,(code>>5)&31u)*(2.0/31.0)-1;
    float3 normal=float3(oct,1-abs(oct.x)-abs(oct.y));
    if(normal.z<0) normal.xy=(1-abs(normal.yx))*float2(normal.x>=0?1:-1,normal.y>=0?1:-1);
    return normalize(normal);
}
