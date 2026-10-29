
    if(any(id.xy>=(uint2)_HLGI_Size.xy)) return;
    uint2 fullPixel=HLGIFullPixelForGiPixel(id.xy,(uint2)_HLGI_Size.xy,(uint2)_HLGI_FullSize.xy);
    float2 uv=HLGIFullPixelCenterUv(fullPixel,(uint2)_HLGI_FullSize.xy);
    float depth=_HLGI_Depth.Load(int3(fullPixel,0));
    float4 material=_HLGI_Diffuse.Load(int3(fullPixel,0));
    float capturedDepth=_HLGI_CaptureDepth.Load(int3(fullPixel,0));
    bool sameSurface=ValidDepth(capturedDepth) && distance(WorldPosition(uv,depth,_HLGI_InvVP),WorldPosition(uv,capturedDepth,_HLGI_InvVP))<0.03;
    if(!ValidDepth(depth) || !sameSurface || !HLGIHasScreenMaterial(_HLGI_Emission.Load(int3(fullPixel,0)).a))
    {
        capturedOutput=0; capturedGeometry=0; capturedMaterial=0; return;
    }
    float3 p=WorldPosition(uv,depth,_HLGI_InvVP), n=NormalAt(uv);
    capturedMaterial=material;
    uint rng=HLGIHash((id.x+id.y*(uint)_HLGI_Size.x+HLGIHash((uint)_HLGI_FrameIndex+1))^0x63D83595u);
    HLGICacheEntry receiverCache=(HLGICacheEntry)0;
    float3 geometricNormal;
    bool hasGeometry=HLGITryScreenGeometricNormal(uv,depth,p,geometricNormal);
    if(hasGeometry)
    {
        HLGIHit receiverHit;
        if(HLGITryScreenWorldMatch(uv,depth,p,geometricNormal,receiverHit))
        {
            geometricNormal=HLGIOffsetNormal(receiverHit.rawNg,geometricNormal);
            if(_HLGI_GuideWeight>0) HLGICachedSample(receiverHit,n,receiverCache);
        }
    }
    capturedGeometry=HLGIPackScreenGeometry(n,geometricNormal,hasGeometry,depth);
