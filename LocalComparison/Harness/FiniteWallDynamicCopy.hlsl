// Temporary observer entry included AFTER the unchanged product kernels.
// No transport, history-validity or change-region decision is evaluated here.
StructuredBuffer<uint2> _DynamicPixels;
RWStructuredBuffer<float4> _DynamicRows;
int _DynamicPixelCount;
[numthreads(64,1,1)]
void CSFiniteWallDynamicCopy(uint3 id:SV_DispatchThreadID)
{
    if(id.x==0)
    {
        _DynamicRows[0]=float4(_HLGI_HistoryValid,_HLGI_GlobalReactive,_HLGI_GlobalGeometryChange,_HLGI_ChangeCount);
        _DynamicRows[1]=float4(_HLGI_CurrentWeight,_HLGI_MaxHistory,_HLGI_HasMotion,_HLGI_FrameIndex);
        _DynamicRows[2]=float4(_HLGI_Size.xy,_HLGI_FullSize.xy);
    }
    if(id.x>=(uint)_DynamicPixelCount)return;
    int2 p=(int2)_DynamicPixels[id.x];uint row=3+id.x*10;
    _DynamicRows[row+0]=_HLGI_Input.Load(int3(p,0));
    _DynamicRows[row+1]=_HLGI_Output[p];
    _DynamicRows[row+2]=_HLGI_MomentsOut[p];
    _DynamicRows[row+3]=_HLGI_History.Load(int3(p,0));
    _DynamicRows[row+4]=_HLGI_PreviousMoments.Load(int3(p,0));
    _DynamicRows[row+5]=_HLGI_Geometry.Load(int3(p,0));
    _DynamicRows[row+6]=_HLGI_PreviousGeometry.Load(int3(p,0));
    _DynamicRows[row+7]=_HLGI_Material.Load(int3(p,0));
    _DynamicRows[row+8]=_HLGI_PreviousMaterial.Load(int3(p,0));
    _DynamicRows[row+9]=float4(_HLGI_Motion.Load(int3(p,0)),0,0);
}
