// Temporary input copy only. No temporal validity, radiance, or source selection oracle.
StructuredBuffer<uint2> _CameraTaaPixels;
RWStructuredBuffer<float4> _CameraTaaRows;
int _CameraTaaPixelCount;
[numthreads(64,1,1)]
void CSCameraMotionTaaCopy(uint3 id:SV_DispatchThreadID)
{
    if(id.x==0)
    {
        _CameraTaaRows[0]=float4(_HLGI_HistoryValid,_HLGI_GlobalReactive,_HLGI_GlobalGeometryChange,_HLGI_ChangeCount);
        _CameraTaaRows[1]=float4(_HLGI_CurrentWeight,_HLGI_MaxHistory,_HLGI_HasMotion,_HLGI_FrameIndex);
        _CameraTaaRows[2]=float4(_HLGI_Size.xy,_HLGI_FullSize.xy);
        _CameraTaaRows[3]=float4(_HLGI_DepthThreshold,_HLGI_NormalThreshold,_HLGI_RayBias,_HLGI_IdentityObjectCount);
        [unroll]for(uint matrixRow=0;matrixRow<4;matrixRow++)
        {
            _CameraTaaRows[4+matrixRow]=_NonJitteredViewProjMatrix[matrixRow];
            _CameraTaaRows[8+matrixRow]=_PrevViewProjMatrix[matrixRow];
        }
    }
    if(id.x>=(uint)_CameraTaaPixelCount)return;
    uint2 pixel=_CameraTaaPixels[id.x];uint row=12+id.x*45;
    [unroll]for(uint clear=0;clear<45;clear++)_CameraTaaRows[row+clear]=0;
    _CameraTaaRows[row]=asfloat(uint4(pixel,id.x,0));
    if(any(pixel>=(uint2)_HLGI_Size.xy))return;
    float2 uv=(float2(pixel)+.5)/_HLGI_FullSize.xy;
    float2 motion=_HLGI_Motion.Load(int3(pixel,0));
    float2 motionUV=uv-motion+_HLGI_JitterDelta.xy;
    float4 geometry=_HLGI_Geometry.Load(int3(pixel,0));
    float clipW;float2 poseUV=ProjectUV(WorldPosition(uv,geometry.w,_HLGI_InvVP),_HLGI_PreviousVP,clipW);
    _CameraTaaRows[row+1]=float4(motion,motionUV);
    _CameraTaaRows[row+2]=float4(poseUV,clipW,0);
    _CameraTaaRows[row+3]=geometry;
    _CameraTaaRows[row+4]=_HLGI_Material.Load(int3(pixel,0));
    _CameraTaaRows[row+5]=_HLGI_Input.Load(int3(pixel,0));
    _CameraTaaRows[row+6]=_HLGI_Output[pixel];
    _CameraTaaRows[row+7]=_HLGI_MomentsOut[pixel];
    _CameraTaaRows[row+8]=asfloat(_HLGI_IdentityCurrent.Load(int3(pixel,0)));
    uint3 candidate=_HLGI_IdentityCandidates[pixel.y*(uint)_HLGI_FullSize.x+pixel.x];
    _CameraTaaRows[row+9]=asfloat(uint4(candidate,_HLGI_IdentityObjectCount));
    if(candidate.x>0u&&candidate.x<=_HLGI_IdentityObjectCount)
    {
        HLGIReceiverIdentityObject objectRow=_HLGI_IdentityObjects[candidate.x-1u];
        _CameraTaaRows[row+10]=objectRow.currentToPrevious[0];
        _CameraTaaRows[row+11]=objectRow.currentToPrevious[1];
        _CameraTaaRows[row+12]=objectRow.currentToPrevious[2];
        _CameraTaaRows[row+13]=objectRow.currentToPrevious[3];
        _CameraTaaRows[row+14]=asfloat(uint4(objectRow.key,objectRow.flags,objectRow.reserved));
    }
    if(!all(isfinite(motionUV)))return;
    int2 nearest=(int2)floor(motionUV*_HLGI_Size.xy);
    int2 lower=(int2)floor(motionUV*_HLGI_Size.xy-.5);
    [unroll]for(uint slot=0;slot<5;slot++)
    {
        int2 previous=slot==0?nearest:lower+int2((slot-1)&1,(slot-1)>>1);
        bool inside=all(previous>=0)&&all(previous<(int2)_HLGI_Size.xy);
        uint destination=row+15+slot*6;
        _CameraTaaRows[destination]=asfloat(uint4((uint2)previous,slot,inside?1u:0u));
        if(!inside)continue;
        _CameraTaaRows[destination+1]=_HLGI_PreviousGeometry.Load(int3(previous,0));
        _CameraTaaRows[destination+2]=_HLGI_PreviousMaterial.Load(int3(previous,0));
        _CameraTaaRows[destination+3]=asfloat(_HLGI_IdentityPrevious.Load(int3(previous,0)));
        _CameraTaaRows[destination+4]=_HLGI_History.Load(int3(previous,0));
        _CameraTaaRows[destination+5]=_HLGI_PreviousMoments.Load(int3(previous,0));
    }
}
