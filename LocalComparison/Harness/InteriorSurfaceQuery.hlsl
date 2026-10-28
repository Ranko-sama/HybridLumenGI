// Included after the actual product kernels; all geometry/material/cache calls are original.
float4 _ISC_Origins[4];
[numthreads(4,1,1)]
void CSInteriorSurfaceProbe(uint3 id:SV_DispatchThreadID)
{
    if(id.x>=4)return;
    ISC_Lane=id.x;
    float3 origin=_ISC_Origins[id.x].xyz,direction=float3(0,0,-1);
    float limit=_ISC_Origins[id.x].w;
    HLGIHit hit;
    bool found=TraceSceneQuery(origin,direction,limit,false,true,0xffffffffu,0xffffffffu,false,
        HLGIPointQueryFootprint(),float4(origin,1),hit);
    HLGISurfaceSample surface=(HLGISurfaceSample)0;
    HLGICacheEntry cached=(HLGICacheEntry)0;
    bool material=found && HLGITrySurfaceMaterialHit(hit,surface);
    bool cache=found && HLGICachedSample(hit,hit.shadingNormal,cached);
    ISW(0,float4(origin,limit));ISW(1,float4(direction,0));ISW(2,asfloat(uint4(found,material,cache,hit.hardwareInstance)));
    ISW(3,float4(hit.position,hit.t));ISW(4,float4(hit.rawNg,0));ISW(5,float4(hit.shadingNormal,0));
    ISW(6,asfloat(uint4(hit.ownerSlot,hit.stableId,hit.ownerRevision,hit.geometryRevision)));
    ISW(7,asfloat(uint4(hit.submesh,hit.primitive,hit.representation,hit.flags)));ISW(8,asfloat(hit.surfaceBinding));
    ISW(20,cached.irradiance);ISW(21,cached.guide);
    if(material)
    {
        HLGISurfaceCard card=_HLGI_SurfaceCards[surface.cardIndex];
        ISW(9,float4(surface.position,surface.confidence));ISW(10,float4(surface.geometricNormal,0));ISW(11,float4(surface.normal,0));
        ISW(12,asfloat(uint4(surface.cardIndex,surface.generation,surface.ownerSlot,0)));ISW(13,asfloat(uint4(surface.atlasPixel,0,0)));
        ISW(14,_HLGI_SurfacePosition.Load(int3(surface.atlasPixel,0)));ISW(15,_HLGI_SurfaceNormal.Load(int3(surface.atlasPixel,0)));
        ISW(16,_HLGI_SurfaceEmission.Load(int3(surface.atlasPixel,0)));
        ISW(17,asfloat(uint4(card.stableId,card.revision,card.generation,card.ready)));
        ISW(18,asfloat(uint4(card.ownerSlot,card.chartId,card.layoutGeneration,card.flags)));
        ISW(19,mul(card.worldToCard,float4(hit.position,1)));
        ISW(60,card.worldToCard[0]);ISW(61,card.worldToCard[1]);ISW(62,card.worldToCard[2]);ISW(63,card.worldToCard[3]);
        ISW(64,card.atlasRect);ISW(65,card.directionTolerance);ISW(66,asfloat(_HLGI_SurfaceOwnerRanges[hit.ownerSlot]));
        ISW(67,_HLGI_SurfaceDiffuse.Load(int3(surface.atlasPixel,0)));
    }
}
