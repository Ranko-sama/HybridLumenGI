// Temporary observer entry included AFTER the unchanged product kernels.
// No transport, history-validity or change-region decision is evaluated here.
StructuredBuffer<uint2> _OcclusionPixels;
RWStructuredBuffer<float4> _OcclusionRows;
int _OcclusionPixelCount;
[numthreads(64,1,1)]
void CSFiniteWallOcclusionCopy(uint3 id:SV_DispatchThreadID)
{
    if(id.x==0)
    {
        _OcclusionRows[0]=float4(_HLGI_HistoryValid,_HLGI_GlobalReactive,_HLGI_GlobalGeometryChange,_HLGI_ChangeCount);
        _OcclusionRows[1]=float4(_HLGI_CurrentWeight,_HLGI_MaxHistory,_HLGI_HasMotion,_HLGI_FrameIndex);
        _OcclusionRows[2]=float4(_HLGI_Size.xy,_HLGI_FullSize.xy);
    }
    if(id.x>=(uint)_OcclusionPixelCount)return;
    int2 p=(int2)_OcclusionPixels[id.x];uint row=3+id.x*10;
    _OcclusionRows[row+0]=_HLGI_Input.Load(int3(p,0));
    _OcclusionRows[row+1]=_HLGI_Output[p];
    _OcclusionRows[row+2]=_HLGI_MomentsOut[p];
    _OcclusionRows[row+3]=_HLGI_History.Load(int3(p,0));
    _OcclusionRows[row+4]=_HLGI_PreviousMoments.Load(int3(p,0));
    _OcclusionRows[row+5]=_HLGI_Geometry.Load(int3(p,0));
    _OcclusionRows[row+6]=_HLGI_PreviousGeometry.Load(int3(p,0));
    _OcclusionRows[row+7]=_HLGI_Material.Load(int3(p,0));
    _OcclusionRows[row+8]=_HLGI_PreviousMaterial.Load(int3(p,0));
    _OcclusionRows[row+9]=float4(_HLGI_Motion.Load(int3(p,0)),0,0);
}

// Input-only replay, using unchanged product functions. No ray/cache/hit query.
StructuredBuffer<uint2> _OcclusionCenters;
RWStructuredBuffer<float4> _OcclusionDirections;
int _OcclusionCenterCount;
[numthreads(64,1,1)]
void CSFiniteWallOcclusionInputs(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=(uint)_OcclusionCenterCount)return;
    uint2 pixel=_OcclusionCenters[id.x];
    uint2 fullPixel=HLGIFullPixelForGiPixel(pixel,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float depth=_HLGI_Depth.Load(int3(fullPixel,0));
    float3 p=WorldPosition(uv,depth,_HLGI_InvVP),n=NormalAt(uv),ng;
    bool hasGeometry=HLGITryScreenGeometricNormal(uv,depth,p,ng);
    float3 origin=p+(hasGeometry?HLGIOffsetNormal(ng,n):n)*_HLGI_RayBias;
    uint rng=HLGIHash((pixel.x+pixel.y*(uint)_HLGI_Size.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0x63D83595u);
    [unroll] for(uint sample=0;sample<8;sample++)
    {
        float discardedWeight;float3 direction=HLGISampleDirection(n,0,rng,discardedWeight);
        uint offset=(id.x*8+sample)*6;
        _OcclusionDirections[offset]=float4(origin,1);
        _OcclusionDirections[offset+1]=float4(direction,0);
        _OcclusionDirections[offset+2]=float4(p,depth);
        _OcclusionDirections[offset+3]=float4(n,1);
        _OcclusionDirections[offset+4]=float4(ng,hasGeometry?1:0);
        _OcclusionDirections[offset+5]=asfloat(uint4(pixel,(uint)_HLGI_FrameIndex,sample));
    }
}
