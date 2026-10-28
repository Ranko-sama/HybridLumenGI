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
