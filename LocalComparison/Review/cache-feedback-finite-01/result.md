# First native feedback capture: observer failure

2026-10-29. Unity exited 1 after 32 requested black-warmup frames. The ordinary light-enable event and the two positive cache updates were not reached. No cache/color comparison was attempted.

Unity reported: `There are more uavs (9) than the maximum supported (8) in ComputeShader 'CacheFeedbackFiniteInputs' kernel 'CSReferenceMetadata'.` This occurred despite the explicit DXC pragma and successful standalone DXC compilation. The standalone shader compiler did not exercise Unity's resource limit.

The log, scene result, partial frame-031 observations, source freezes and temporary deployed files are preserved. The observer's presence and completed asynchronous readbacks do not qualify those observations for the independent reference. This is a capture harness failure, with no new product radiance conclusion.

Restoration passed: all 112 product sources, protected project settings and the Functional scene match; the owned temporary root was removed. The separate `cache-feedback-finite-02` attempt splits the metadata observer into eight-UAV metadata and one-UAV change-region kernels. The independent geometry, radiance arithmetic and numeric bounds remain byte-identical in its inherited reference. The first attempt is not overwritten.
