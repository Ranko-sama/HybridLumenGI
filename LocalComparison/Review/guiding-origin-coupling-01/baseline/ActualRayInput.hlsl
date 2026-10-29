        float3 origin=p+(hasGeometry?HLGIOffsetNormal(geometricNormal,n):n)*_HLGI_RayBias;
        float3 dir=HLGISampleTransportDirection(origin,n,receiverCache.guide,rng,sampleWeight);