struct HLGIProxy { float4 centerShape, extentsRoughness, albedo, emission, identity; };
struct HLGICacheEntry { float4 irradiance; float4 tag; float4 anchor; float4 normal; float4 guide; };
struct HLGISurfaceCard
{
    column_major float4x4 worldToCard;
    float4 atlasRect;
    float4 directionTolerance;
    uint stableId, revision, generation, ready;
    uint ownerSlot, chartId, layoutGeneration, flags; // bit 0: real chart; bits 1..2: chart material Cull
};
struct HLGIChangeRegion { float4 minimum, maximum, receiver; };
