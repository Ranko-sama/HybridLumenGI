struct HLGIProxy { float4 centerShape, extentsRoughness, albedo, emission, identity; };

struct HLGICacheEntry { float4 irradiance; float4 tag; float4 anchor; float4 normal; float4 guide; };

struct HLGISurfaceSample
{
    float3 position, normal, geometricNormal, diffuse, emission;
    float occlusion, roughness, confidence;
    uint cardIndex, generation, ownerSlot;
    uint2 atlasPixel;
};
