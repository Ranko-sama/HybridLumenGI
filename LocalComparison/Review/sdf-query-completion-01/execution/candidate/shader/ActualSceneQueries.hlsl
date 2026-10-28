bool IntersectProxy(float3 o, float3 d, HLGIProxy p, float limit, out float t, out float3 n)
{
    t = limit; n = 0;
    float3 local = o - p.centerShape.xyz;
    if (p.centerShape.w > 0.5)
    {
        float radius = max(p.extentsRoughness.x, max(p.extentsRoughness.y,p.extentsRoughness.z));
        float b = dot(local,d), c = dot(local,local) - radius*radius;
        float disc = b*b-c;
        if (disc < 0) return false;
        float root = sqrt(disc); t = -b-root;
        if (t <= 1e-4) t = -b+root;
        if (t <= 1e-4 || t >= limit) return false;
        n = normalize(local + d*t); return true;
    }
    float enter = -1e20, leave = 1e20;
    float3 enterN = 0, leaveN = 0;
    [unroll] for (int axis=0; axis<3; axis++)
    {
        if (abs(d[axis]) < 1e-7)
        {
            if (abs(local[axis]) > p.extentsRoughness[axis]) return false;
            continue;
        }
        float a = (-p.extentsRoughness[axis]-local[axis])/d[axis];
        float b = ( p.extentsRoughness[axis]-local[axis])/d[axis];
        float3 axisN = 0; axisN[axis] = d[axis]>0 ? -1 : 1;
        if (min(a,b)>enter) { enter=min(a,b); enterN=axisN; }
        if (max(a,b)<leave) { leave=max(a,b); leaveN=-axisN; }
    }
    if (leave < max(enter,0)) return false;
    bool inside = enter <= 1e-4;
    t = inside ? leave : enter; n = inside ? leaveN : enterN;
    return t > 1e-4 && t < limit;
}
HLGIRayFootprint HLGIPointQueryFootprint()
{ HLGIRayFootprint value;HLGITryMakeRayFootprint(0,0,value);return value; }
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{
    result=HLGIEmptyHit(maxT);
#if defined(HLGI_INLINE_RT)
    HLGIHardwareTraceQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,
        footprint.valid==1u?footprint.radius:-1,footprint.slope,materialView,result);
#elif defined(HLGI_SOFTWARE_TRIANGLES)
    HLGISoftwareTraceQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,
        footprint.valid==1u?footprint.radius:-1,footprint.slope,materialView,result);
#endif
    uint cursor=0;
    [loop] while(cursor<(uint)_HLGI_SceneBvhCount)
    {
        int i=HLGIBvhNextLeaf(cursor,o,d,result.t);
        if(i<0) break;
        if(_HLGI_Proxies[i].identity.w < 0.5 || _HLGI_Proxies[i].identity.w >= 1.5) continue;
        if(shadowQuery && !HLGIShadowOwnerAllowed((uint)i,cullingMask,shadowRenderingLayers,useRenderingLayers)) continue;
#if defined(HLGI_INLINE_RT) || defined(HLGI_SOFTWARE_TRIANGLES)
        if (HLGIHardwareHasMesh(i)) continue;
#endif
        HLGIHit candidate=HLGIEmptyHit(result.t);
        bool found;
        if(HLGIHasMeshSdf(i)) found=HLGITraceMeshSdfHit(o,d,result.t,i,candidate);
        else
        {
            float distanceHit;float3 normal;
            found=IntersectProxy(o,d,_HLGI_Proxies[i],result.t,distanceHit,normal);
            if(found)
            {
                candidate.t=distanceHit;candidate.position=o+d*distanceHit;
                candidate.rawNg=candidate.shadingNormal=normal;
                candidate.ownerSlot=(uint)i;
                candidate.stableId=(uint)_HLGI_Proxies[i].identity.x;
                candidate.ownerRevision=(uint)_HLGI_Proxies[i].identity.y;
                candidate.representation=HLGI_REPRESENTATION_ANALYTIC;
                candidate.flags=HLGI_HIT_VALID|HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG|HLGI_HIT_FRONT_FACE_KNOWN;
                if(dot(normal,d)<0) candidate.flags|=HLGI_HIT_FRONT_FACE;
            }
        }
        if(found)
        {
            // Software geometry already matched the current scene owner/revision.
            // Carry that owner's current surface geometry version if resident;
            // this version is not a primitive/front-face/material identity.
            uint4 surfaceRange;
            if(!HLGIHitQueryUnresolved(candidate) && HLGISurfaceOwnerRange(i,surfaceRange)) candidate.geometryRevision=surfaceRange.w;
            result=candidate;
        }
    }
    return HLGIHitHas(result.flags,HLGI_HIT_VALID);
}
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{
    float detailLimit=_HLGI_GlobalSdfEnabled!=0?min(maxT,_HLGI_DetailTraceDistance):maxT;
    float advance=0;
    HLGIRayFootprint queryFootprint=footprint;
    // Keep one detailed traversal call site. DXC inlines this entire geometry /
    // material query; separate fast/near/far call sites multiplied it at every
    // visibility and radiance caller, exceeding Unity's compiler timeout.
    [loop] for(int segment=0;segment<2;segment++)
    {
        float limit=segment==0?detailLimit:maxT-advance;
        if(TraceSceneDetailQuery(o+d*advance,d,limit,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,queryFootprint,materialView,result))
        { result.t+=advance;if(!HLGIHitQueryUnresolved(result))result.position=o+d*result.t;return true; }
        if(segment==1 || detailLimit>=maxT) break;
        // Retain the near/far overlap and conservative empty-space guards.
        advance=max(0,detailLimit-0.001);
        [loop] for(int step=0;step<8 && advance<maxT;step++)
        {
            float emptyDistance;
            if(!HLGIGlobalSdfEmptyDistance(o+d*advance,emptyDistance) || emptyDistance<=0) break;
            if(emptyDistance>=maxT-advance) { result=HLGIEmptyHit(maxT);return false; }
            float guard=max(0.001,abs(advance)*2e-6);
            float next=advance+max(0,emptyDistance-guard);
            if(next<=advance) break;
            advance=next;
        }
        if(advance>=maxT) break;
        HLGIAdvanceRayFootprint(footprint,advance,queryFootprint);
    }
    result=HLGIEmptyHit(maxT);return false;
}
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneDetailQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),result); }
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,bool resolveMaterial,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,shadowQuery,resolveMaterial,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),result); }
bool TraceSceneDetailQuery(float3 o,float3 d,float maxT,bool shadowQuery,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneDetailQuery(o,d,maxT,shadowQuery,!shadowQuery,cullingMask,shadowRenderingLayers,useRenderingLayers,result); }
bool TraceSceneQuery(float3 o,float3 d,float maxT,bool shadowQuery,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,shadowQuery,!shadowQuery,cullingMask,shadowRenderingLayers,useRenderingLayers,result); }
bool TraceSceneHit(float3 o,float3 d,float maxT,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,true,0xffffffffu,0xffffffffu,false,result); }
bool TraceSceneHit(float3 o,float3 d,float maxT,HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,true,0xffffffffu,0xffffffffu,false,footprint,materialView,result); }
bool TraceSceneVisibilityHit(float3 o,float3 d,float maxT,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,false,0xffffffffu,0xffffffffu,false,result); }
bool TraceSceneVisibilityHit(float3 o,float3 d,float maxT,HLGIRayFootprint footprint,float4 materialView,out HLGIHit result)
{ return TraceSceneQuery(o,d,maxT,false,false,0xffffffffu,0xffffffffu,false,footprint,materialView,result); }
bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    HLGIRayFootprint footprint,float4 materialView,out bool known)
{
    HLGIHit result;
    bool blocked=TraceSceneQuery(o,d,maxT,true,false,cullingMask,shadowRenderingLayers,useRenderingLayers,footprint,materialView,result);
    known=!blocked || HLGIHitMaterialKnown(result);
    return blocked;
}
bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,out bool known)
{ return TraceShadow(o,d,maxT,cullingMask,shadowRenderingLayers,useRenderingLayers,HLGIPointQueryFootprint(),float4(o,1),known); }
bool TraceShadow(float3 o,float3 d,float maxT,uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers)
{ bool known;return TraceShadow(o,d,maxT,cullingMask,shadowRenderingLayers,useRenderingLayers,known); }
