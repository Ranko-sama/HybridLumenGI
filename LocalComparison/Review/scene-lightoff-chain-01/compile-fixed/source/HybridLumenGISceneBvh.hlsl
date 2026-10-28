#ifndef HLGI_SCENE_BVH_INCLUDED
#define HLGI_SCENE_BVH_INCLUDED
// Broad phase only. A returned stable slot must still pass the mesh-SDF/triangle/analytic intersection.
struct HLGISceneBvhNode
{
    float3 minimum; uint skipIndex;
    float3 maximum; int proxySlot;
};
StructuredBuffer<HLGISceneBvhNode> _HLGI_SceneBvh;
int _HLGI_SceneBvhCount;

bool HLGIBvhBounds(float3 origin, float3 direction, float3 minimum, float3 maximum, float limit)
{
    float enter = 0, leave = limit;
    if (limit < 0) return false;
    [unroll] for (int axis = 0; axis < 3; axis++)
    {
        if (abs(direction[axis]) < 1e-12)
        {
            if (origin[axis] < minimum[axis] || origin[axis] > maximum[axis]) return false;
        }
        else
        {
            float a = (minimum[axis]-origin[axis])/direction[axis];
            float b = (maximum[axis]-origin[axis])/direction[axis];
            enter = max(enter,min(a,b)); leave = min(leave,max(a,b));
            if (leave < enter) return false;
        }
    }
    return true;
}

int HLGIBvhNextLeaf(inout uint cursor, float3 origin, float3 direction, float limit)
{
    [loop] while (cursor < (uint)_HLGI_SceneBvhCount)
    {
        HLGISceneBvhNode node = _HLGI_SceneBvh[cursor];
        if (!HLGIBvhBounds(origin,direction,node.minimum,node.maximum,limit))
        {
            cursor = max(cursor+1u,node.skipIndex);
            continue;
        }
        cursor++;
        if (node.proxySlot >= 0) return node.proxySlot;
    }
    return -1;
}
#endif
