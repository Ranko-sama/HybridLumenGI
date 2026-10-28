#ifndef HLGI_SOFTWARE_TRIANGLE_BVH_INCLUDED
#define HLGI_SOFTWARE_TRIANGLE_BVH_INCLUDED
struct HLGISoftwareTriangleNode { float3 minimum;uint skipIndex;float3 maximum;int leaf; };
struct HLGISoftwareTriangleLeaf { float4 p0,p1,p2;uint4 identity; };
StructuredBuffer<HLGISoftwareTriangleNode> _HLGI_SoftwareTriangleNodes;
StructuredBuffer<HLGISoftwareTriangleLeaf> _HLGI_SoftwareTriangleLeaves;
int _HLGI_SoftwareBvhNodeCount,_HLGI_SoftwareBvhLeafCount;

bool HLGISoftwareBounds(float3 origin,float3 direction,float maxT,float3 minimum,float3 maximum,out float entry)
{
    entry=0.0001;float exitT=maxT;
    [unroll]for(uint axis=0u;axis<3u;axis++)
    {
        if(direction[axis]==0)
        {
            if(origin[axis]<minimum[axis] || origin[axis]>maximum[axis])return false;
        }
        else
        {
            float a=(minimum[axis]-origin[axis])/direction[axis],b=(maximum[axis]-origin[axis])/direction[axis];
            entry=max(entry,min(a,b));exitT=min(exitT,max(a,b));
            if(entry>exitT)return false;
        }
    }
    return entry<=maxT && exitT>=0.0001;
}

bool HLGISoftwareNextTriangle(float3 origin,float3 direction,float maxT,inout uint cursor,
    out HLGISoftwareTriangleLeaf leaf,out float entry)
{
    leaf=(HLGISoftwareTriangleLeaf)0;entry=0;
    uint nodeCount,nodeStride,leafCount,leafStride;
    _HLGI_SoftwareTriangleNodes.GetDimensions(nodeCount,nodeStride);
    _HLGI_SoftwareTriangleLeaves.GetDimensions(leafCount,leafStride);
    if(_HLGI_SoftwareBvhNodeCount<=0 || _HLGI_SoftwareBvhLeafCount<=0 || nodeStride!=32u || leafStride!=64u ||
        (uint)_HLGI_SoftwareBvhNodeCount>nodeCount || (uint)_HLGI_SoftwareBvhLeafCount>leafCount)return false;
    [loop]while(cursor<(uint)_HLGI_SoftwareBvhNodeCount)
    {
        HLGISoftwareTriangleNode node=_HLGI_SoftwareTriangleNodes[cursor];
        if(node.skipIndex<=cursor || node.skipIndex>(uint)_HLGI_SoftwareBvhNodeCount)
        {cursor=(uint)_HLGI_SoftwareBvhNodeCount;return false;}
        if(!HLGISoftwareBounds(origin,direction,maxT,node.minimum,node.maximum,entry)) {cursor=node.skipIndex;continue;}
        cursor++;
        if(node.leaf>=0 && (uint)node.leaf<(uint)_HLGI_SoftwareBvhLeafCount)
        {leaf=_HLGI_SoftwareTriangleLeaves[node.leaf];return true;}
    }
    return false;
}

// Compensated float pairs for the rare nearly parallel case. All operands were
// scaled into a normal range. No optional shader float64 capability is required.
float2 HLGISoftwarePairAdd(float2 a,float2 b)
{
    precise float s=a.x+b.x,bb=s-a.x,e=(a.x-(s-bb))+(b.x-bb)+a.y+b.y;
    precise float hi=s+e,lo=e-(hi-s);return float2(hi,lo);
}
float2 HLGISoftwarePairMul(float2 a,float2 b)
{
    precise float p=a.x*b.x;
    precise float sa=4097*a.x,sb=4097*b.x,ah=sa-(sa-a.x),bh=sb-(sb-b.x),al=a.x-ah,bl=b.x-bh;
    precise float e=((ah*bh-p)+ah*bl+al*bh)+al*bl+a.x*b.y+a.y*b.x+a.y*b.y;
    precise float hi=p+e,lo=e-(hi-p);return float2(hi,lo);
}
float HLGISoftwarePairDivide(float2 a,float2 b)
{
    precise float q=a.x/b.x;
    float2 remainder=HLGISoftwarePairAdd(a,-HLGISoftwarePairMul(b,float2(q,0)));
    precise float result=q+(remainder.x+remainder.y)/b.x;return result;
}
struct HLGISoftwarePairVector { float2 x,y,z; };
HLGISoftwarePairVector HLGISoftwarePairDifference(float3 a,float3 b)
{
    HLGISoftwarePairVector v;v.x=HLGISoftwarePairAdd(float2(a.x,0),float2(-b.x,0));
    v.y=HLGISoftwarePairAdd(float2(a.y,0),float2(-b.y,0));v.z=HLGISoftwarePairAdd(float2(a.z,0),float2(-b.z,0));return v;
}
HLGISoftwarePairVector HLGISoftwarePairCross(HLGISoftwarePairVector a,HLGISoftwarePairVector b)
{
    HLGISoftwarePairVector c;
    c.x=HLGISoftwarePairAdd(HLGISoftwarePairMul(a.y,b.z),-HLGISoftwarePairMul(a.z,b.y));
    c.y=HLGISoftwarePairAdd(HLGISoftwarePairMul(a.z,b.x),-HLGISoftwarePairMul(a.x,b.z));
    c.z=HLGISoftwarePairAdd(HLGISoftwarePairMul(a.x,b.y),-HLGISoftwarePairMul(a.y,b.x));return c;
}
float2 HLGISoftwarePairDot(HLGISoftwarePairVector a,HLGISoftwarePairVector b)
{
    return HLGISoftwarePairAdd(HLGISoftwarePairAdd(HLGISoftwarePairMul(a.x,b.x),HLGISoftwarePairMul(a.y,b.y)),HLGISoftwarePairMul(a.z,b.z));
}
uint HLGISoftwareCompensatedIntersection(float3 origin,float3 direction,float maxT,HLGISoftwareTriangleLeaf leaf,
    float factor,float exponent,out float distance,out float2 barycentrics)
{
    distance=maxT;barycentrics=0;
    HLGISoftwarePairVector e1=HLGISoftwarePairDifference(leaf.p1.xyz*factor,leaf.p0.xyz*factor);
    HLGISoftwarePairVector e2=HLGISoftwarePairDifference(leaf.p2.xyz*factor,leaf.p0.xyz*factor);
    HLGISoftwarePairVector s=HLGISoftwarePairDifference(origin*factor,leaf.p0.xyz*factor);
    HLGISoftwarePairVector d=HLGISoftwarePairDifference(direction,0),h=HLGISoftwarePairCross(d,e2),q=HLGISoftwarePairCross(s,e1);
    float2 determinant=HLGISoftwarePairDot(e1,h),u=HLGISoftwarePairDot(s,h),v=HLGISoftwarePairDot(d,q),t=HLGISoftwarePairDot(e2,q);
    if(determinant.x==0)return 0u;
    if(determinant.x<0){determinant=-determinant;u=-u;v=-v;t=-t;}
    float2 w=HLGISoftwarePairAdd(determinant,-HLGISoftwarePairAdd(u,v));
    if(u.x<0 || v.x<0 || w.x<0)return 0u;
    barycentrics=float2(HLGISoftwarePairDivide(u,determinant),HLGISoftwarePairDivide(v,determinant));
    distance=HLGISoftwarePairDivide(t,determinant)*exp2(exponent);
    if(!isfinite(distance)||!all(isfinite(barycentrics)))return 2u;
    barycentrics.x=saturate(barycentrics.x);barycentrics.y=clamp(barycentrics.y,0,1-barycentrics.x);
    return distance>=0.0001 && distance<=maxT?1u:0u;
}

// 0 = no intersection, 1 = a finite geometric intersection, 2 = numerical unknown.
// Dominant-axis shear and shared edge products avoid winding/determinant changes.
// A power-of-two coordinate scale controls overflow without moving the triangles.
uint HLGISoftwareTriangleIntersection(float3 origin,float3 direction,float maxT,HLGISoftwareTriangleLeaf leaf,
    out float distance,out float2 barycentrics)
{
    distance=maxT;barycentrics=0;
    if(!all(isfinite(origin)) || !all(isfinite(direction)) || !isfinite(maxT) ||
        !all(isfinite(leaf.p0)) || !all(isfinite(leaf.p1)) || !all(isfinite(leaf.p2)) ||
        leaf.p0.w!=1 || leaf.p1.w!=1 || leaf.p2.w!=1)return 2u;
    float3 absolute=abs(direction);uint kz=absolute.x>=absolute.y && absolute.x>=absolute.z?0u:absolute.y>=absolute.z?1u:2u;
    if(direction[kz]==0)return 2u;
    uint kx=(kz+1u)%3u,ky=(kx+1u)%3u;
    float3 a=leaf.p0.xyz-origin,b=leaf.p1.xyz-origin,c=leaf.p2.xyz-origin;
    if(!all(isfinite(a)) || !all(isfinite(b)) || !all(isfinite(c)))return 2u;
    float magnitude=max(max(max(abs(a.x),abs(a.y)),abs(a.z)),max(max(max(abs(b.x),abs(b.y)),abs(b.z)),max(max(abs(c.x),abs(c.y)),abs(c.z))));
    if(magnitude==0)return 0u;
    float exponent=clamp(floor(log2(magnitude)),-100,100),factor=exp2(-exponent);
    a*=factor;b*=factor;c*=factor;
    float3 face=cross(b-a,c-a);
    if(abs(dot(face,direction))<=0.01*sqrt(dot(face,face))*length(direction))
        return HLGISoftwareCompensatedIntersection(origin,direction,maxT,leaf,factor,exponent,distance,barycentrics);
    float sx=direction[kx]/direction[kz],sy=direction[ky]/direction[kz];
    precise float ax=a[kx]-sx*a[kz],ay=a[ky]-sy*a[kz];
    precise float bx=b[kx]-sx*b[kz],by=b[ky]-sy*b[kz];
    precise float cx=c[kx]-sx*c[kz],cy=c[ky]-sy*c[kz];
    precise float e0=bx*cy-by*cx,e1=cx*ay-cy*ax,e2=ax*by-ay*bx;
    if((e0<0 || e1<0 || e2<0) && (e0>0 || e1>0 || e2>0))return 0u;
    precise float determinant=e0+e1+e2;
    if(determinant==0)return 0u;
    precise float scaledT=(e0*a[kz]+e1*b[kz]+e2*c[kz])/determinant;
    distance=(scaledT/direction[kz])*exp2(exponent);
    barycentrics=float2(e1,e2)/determinant;
    if(!isfinite(distance) || !all(isfinite(barycentrics)))return 2u;
    // The edge tests already proved all three weights have one sign. Avoid an
    // extra one-ULP negative w0 in the material evaluator after division rounds.
    barycentrics.x=saturate(barycentrics.x);barycentrics.y=clamp(barycentrics.y,0,1-barycentrics.x);
    return distance>=0.0001 && distance<=maxT?1u:0u;
}

#if !defined(HLGI_SOFTWARE_GEOMETRY_ONLY)
#include "HybridLumenGIExactMesh.hlsl"
bool HLGISoftwareTraceQuery(float3 origin,float3 direction,float maxT,bool shadowQuery,bool resolveMaterial,
    uint cullingMask,uint shadowRenderingLayers,bool useRenderingLayers,
    float coneRadiusAtOrigin,float coneSlope,float4 materialView,out HLGIHit hit)
{
    hit=HLGIEmptyHit(maxT);
    if(!isfinite(maxT) || maxT<=0.0001 || !all(isfinite(origin)) || !all(isfinite(direction)) || dot(direction,direction)<1e-16)return false;
    bool found=false,numericUnknown=false;uint cursor=0u,instanceIndex=0u,primitive=0u;
    float2 barycentric=0;float3x4 objectToWorld=(float3x4)0;
    HLGISoftwareTriangleLeaf leaf;float entry;
    [loop]while(HLGISoftwareNextTriangle(origin,direction,hit.t,cursor,leaf,entry))
    {
        float candidateT;float2 candidateBary;
        uint geometric=HLGISoftwareTriangleIntersection(origin,direction,hit.t,leaf,candidateT,candidateBary);
        if(geometric==0u)continue;
        HLGIHardwareInstance candidate;HLGITriangleNormals attributes;float3 rawNg;
        if(!HLGIHardwareGeometry(leaf.identity.x,leaf.identity.y,candidate,attributes,rawNg))continue;
        if(shadowQuery && !HLGIShadowOwnerAllowed(candidate.geometry.x,cullingMask,shadowRenderingLayers,useRenderingLayers))continue;
        bool frontFace=dot(rawNg,direction)<0;
        if(dot(rawNg,rawNg)>=0.5 && !HLGIHardwareSideAllowed(candidate.identity.w,frontFace) &&
            !(shadowQuery && HLGIShadowTwoSided(candidate.geometry.x)))continue;
        float3x4 candidateMatrix;bool transformKnown=HLGIExactObjectToWorld(leaf.identity.x,candidateMatrix);
        if(geometric==2u)candidateT=entry;
        float radius=coneRadiusAtOrigin+coneSlope*candidateT;
        bool footprintKnown=isfinite(coneRadiusAtOrigin) && coneRadiusAtOrigin>=0 && isfinite(coneSlope) && isfinite(radius) && radius>=0;
        bool covered=true,coverageKnown=false;HLGIHitMaterialSurface material;float3 materialNormal;
        if(geometric==1u && transformKnown && footprintKnown)
            coverageKnown=HLGIHardwareEvaluateHit(leaf.identity.x,leaf.identity.y,candidate,attributes,candidateMatrix,candidateBary,
                materialView,direction,radius,true,shadowQuery,covered,material,materialNormal);
        // Unknown alpha/texture state blocks the nearest endpoint; only a known
        // transparent candidate may expose the farther triangle or SDF surface.
        if(!HLGIHitCoverageBlocks(coverageKnown,covered))continue;
        if(found && candidateT==hit.t && (leaf.identity.x>instanceIndex ||
            (leaf.identity.x==instanceIndex && leaf.identity.y>=primitive)))continue;
        found=true;hit.t=candidateT;instanceIndex=leaf.identity.x;primitive=leaf.identity.y;
        barycentric=candidateBary;objectToWorld=candidateMatrix;numericUnknown=geometric==2u || !transformKnown;
    }
    if(!found)return false;
    HLGIHardwareInstance instance;HLGITriangleNormals normals;float3 rawNg;
    if(!HLGIHardwareGeometry(instanceIndex,primitive,instance,normals,rawNg))return false;
    float3 weights=float3(1-barycentric.x-barycentric.y,barycentric.xy),shadingNormal=0;
    bool normalValid=!numericUnknown && normals.face.w>0.5 && HLGITryHardwareShadingNormal((float3x3)instance.normalToWorld,
        normals.a.xyz,normals.b.xyz,normals.c.xyz,weights,shadingNormal);
    hit.position=origin+direction*hit.t;hit.rawNg=rawNg;hit.shadingNormal=normalValid?shadingNormal:rawNg;
    hit.ownerSlot=instance.geometry.x;hit.submesh=instance.geometry.w;hit.primitive=primitive;hit.hardwareInstance=instanceIndex;
    hit.stableId=instance.identity.x;hit.ownerRevision=instance.identity.y;hit.geometryRevision=instance.identity.z;
    hit.barycentrics=barycentric;hit.representation=HLGI_REPRESENTATION_TRIANGLE;hit.flags=HLGI_HIT_VALID|HLGI_HIT_TRIANGLE;
    if(dot(rawNg,rawNg)>0.5)
    {
        hit.flags|=HLGI_HIT_GEOMETRIC_NORMAL|HLGI_HIT_ORIENTED_NG|HLGI_HIT_FRONT_FACE_KNOWN;
        if(dot(rawNg,direction)<0)hit.flags|=HLGI_HIT_FRONT_FACE;
    }
    if(normalValid)hit.flags|=HLGI_HIT_SHADING_NORMAL;
    if(numericUnknown)hit.flags|=HLGI_HIT_MATERIAL_UNKNOWN;
    else HLGIHardwareResolveCommittedMaterial(instanceIndex,primitive,instance,normals,objectToWorld,barycentric,
        materialView,direction,coneRadiusAtOrigin,coneSlope,shadowQuery,resolveMaterial,hit);
    float2 uv=float2(dot(float3(normals.a.w,normals.b.w,normals.c.w),weights),dot(normals.uvY.xyz,weights));
    if(!numericUnknown && normals.uvY.w>0.5 && all(isfinite(uv))){hit.uv=uv;hit.flags|=HLGI_HIT_UV;}
    uint count,stride;_HLGI_HardwareTriangleBindings.GetDimensions(count,stride);
    if(instance.geometry.y<count && primitive<count-instance.geometry.y)
    {
        uint4 binding=_HLGI_HardwareTriangleBindings[instance.geometry.y+primitive];
        if(binding.x!=0xffffffffu && binding.y!=0u && binding.z!=0u && binding.w==hit.geometryRevision)
        {hit.surfaceBinding=binding;hit.flags|=HLGI_HIT_SURFACE_BINDING;}
    }
    return true;
}
#endif
#endif
