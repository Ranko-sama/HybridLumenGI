#ifndef HLGI_GLOBAL_SDF_INCLUDED
#define HLGI_GLOBAL_SDF_INCLUDED

// Distances are conservative lower bounds, never visibility or surface-hit results.
// The extra value per brick stores the generation published after its voxel writes.
#define HLGI_GLOBAL_SDF_BRICK_AXIS 4
#define HLGI_GLOBAL_SDF_BRICK_VOXELS 64
#define HLGI_GLOBAL_SDF_BRICK_STORAGE 65
struct HLGIGlobalSdfPage
{
    int3 key;
    uint generation;
    uint ready, level, reserved0, reserved1;
};
struct HLGIGlobalSdfLevel
{
    int4 origin;
    float4 metric;
};
StructuredBuffer<HLGIGlobalSdfPage> _HLGI_GlobalSdfPages;
StructuredBuffer<HLGIGlobalSdfLevel> _HLGI_GlobalSdfLevels;
StructuredBuffer<float> _HLGI_GlobalSdfDistances;
int _HLGI_GlobalSdfLevelCount, _HLGI_GlobalSdfBrickAxis;

int3 HLGIGlobalSdfPositiveModulo(int3 value, int axis) { return ((value % axis) + axis) % axis; }
float HLGIGlobalSdfRoundoff(float3 position, float voxelSize)
{
    return max(1e-5, max(voxelSize * 1e-4, max(abs(position.x), max(abs(position.y), abs(position.z))) * 2e-6));
}

// false means UNKNOWN, including uninitialized, dirty, wrapped, out-of-coverage pages.
// Try a coarser level when the fine level is unknown. A valid zero bound is not a hit.
bool HLGIGlobalSdfEmptyDistance(float3 position, out float distance)
{
    distance = 0;
    if (!all(isfinite(position)) || _HLGI_GlobalSdfBrickAxis < 1) return false;
    int axis = _HLGI_GlobalSdfBrickAxis;
    [loop] for (int level = 0; level < min(_HLGI_GlobalSdfLevelCount, 4); level++)
    {
        HLGIGlobalSdfLevel data = _HLGI_GlobalSdfLevels[level];
        float3 keyFloat = floor(position / data.metric.y);
        if (any(abs(keyFloat) >= 2147483000.0)) continue;
        int3 key = (int3)keyFloat;
        int3 relative = key - data.origin.xyz;
        if (any(relative < 0) || any(relative >= axis)) continue;
        int3 physical = HLGIGlobalSdfPositiveModulo(key, axis);
        uint pageIndex = level * axis * axis * axis + physical.x + axis * (physical.y + axis * physical.z);
        HLGIGlobalSdfPage page = _HLGI_GlobalSdfPages[pageIndex];
        if (page.ready == 0 || page.generation == 0 || page.level != (uint)level || any(page.key != key)) continue;
        uint baseIndex = pageIndex * HLGI_GLOBAL_SDF_BRICK_STORAGE;
        if (asuint(_HLGI_GlobalSdfDistances[baseIndex + HLGI_GLOBAL_SDF_BRICK_VOXELS]) != page.generation) continue;
        float3 brickOrigin = (float3)key * data.metric.y;
        int3 voxel = clamp((int3)floor((position - brickOrigin) / data.metric.x), 0, HLGI_GLOBAL_SDF_BRICK_AXIS - 1);
        uint address = baseIndex + voxel.x + HLGI_GLOBAL_SDF_BRICK_AXIS * (voxel.y + HLGI_GLOBAL_SDF_BRICK_AXIS * voxel.z);
        float stored = _HLGI_GlobalSdfDistances[address];
        if (!isfinite(stored) || stored < 0) continue;
        float3 center = brickOrigin + ((float3)voxel + 0.5) * data.metric.x;
        // Distance to any surface is 1-Lipschitz. No interpolation across unready pages.
        distance = max(0, stored - length(position - center) - HLGIGlobalSdfRoundoff(position, data.metric.x));
        return true;
    }
    return false;
}
#endif
