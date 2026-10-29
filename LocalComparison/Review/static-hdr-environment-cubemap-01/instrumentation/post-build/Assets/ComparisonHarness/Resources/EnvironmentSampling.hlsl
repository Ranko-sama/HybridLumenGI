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
