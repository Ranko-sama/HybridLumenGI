#ifndef HLGI_RECEIVER_IDENTITY_INCLUDED
#define HLGI_RECEIVER_IDENTITY_INCLUDED

// 80 bytes. CPU record indices retain holes; index+1 is a transient draw owner,
// while key is the non-reused source-generation identity. Flags are consumed by
// later temporal transport, never by current-frame identity resolution.
struct HLGIReceiverIdentityObject
{
    float4x4 currentToPrevious;
    uint2 key;
    uint flags;
    uint reserved;
};

#endif
