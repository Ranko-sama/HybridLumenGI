#ifndef HLGI_EMISSIVE_RECORDS_INCLUDED
#define HLGI_EMISSIVE_RECORDS_INCLUDED

// 32 bytes per physical surface card. Only a directional-proposal summary:
// sphere bounds captured emitting texels; data.x is an importance score, not power.
// A record has no authority without matching ready/published card metadata.
struct HLGIEmissiveRecord
{
    float4 sphere;
    float4 data;
};

#endif
