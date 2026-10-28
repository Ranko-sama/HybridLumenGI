struct HLGIProxy { float4 centerShape, extentsRoughness, albedo, emission, identity; };

struct HLGILight
{
    float4 positionType; // 0 directional, 1 point, 2 spot
    float4 directionRange;
    float4 color;
    float4 spot; // cos outer, reciprocal(cos inner - cos outer), shadow strength, reserved
    uint4 masks; // GameObject culling, illumination layers, shadow layers, flags(bit0: layers enabled)
};

struct HLGICacheEntry { float4 irradiance; float4 tag; float4 anchor; float4 normal; float4 guide; };

struct HLGISurfaceCard
{
    column_major float4x4 worldToCard;
    float4 atlasRect;
    float4 directionTolerance;
    uint stableId, revision, generation, ready;
    uint ownerSlot, chartId, layoutGeneration, flags; // bit 0: real chart; bits 1..2: chart material Cull
};

struct HLGISurfaceSample
{
    float3 position, normal, geometricNormal, diffuse, emission;
    float occlusion, roughness, confidence;
    uint cardIndex, generation, ownerSlot;
    uint2 atlasPixel;
};
