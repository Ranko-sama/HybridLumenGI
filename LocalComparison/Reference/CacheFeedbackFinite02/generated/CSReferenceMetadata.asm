;
; Input signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; no parameters
;
; Output signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; no parameters
; shader hash: 64e41ed2d01d58354738dc554f80a9ae
;
; Pipeline Runtime Information: 
;
;PSVRuntimeInfo:
; Compute Shader
; NumThreads=(64,1,1)
; MinimumExpectedWaveLaneCount: 0
; MaximumExpectedWaveLaneCount: 4294967295
; UsesViewID: false
; SigInputElements: 0
; SigOutputElements: 0
; SigPatchConstOrPrimElements: 0
; SigInputVectors: 0
; SigOutputVectors[0]: 0
; SigOutputVectors[1]: 0
; SigOutputVectors[2]: 0
; SigOutputVectors[3]: 0
; EntryFunctionName: CSReferenceMetadata
;
;
; Buffer Definitions:
;
; cbuffer $Globals
; {
;
;   struct hostlayout.$Globals
;   {
;
;       float4 _GlossyEnvironmentColor;               ; Offset:    0
;       float4 _SubtractiveShadowColor;               ; Offset:   16
;       float4 _GlossyEnvironmentCubeMap_HDR;         ; Offset:   32
;       float4 _ScaledScreenParams;                   ; Offset:   48
;       float2 _GlobalMipBias;                        ; Offset:   64
;       float _AlphaToMaskAvailable;                  ; Offset:   72
;       float4 _MainLightPosition;                    ; Offset:   80
;       float4 _MainLightColor;                       ; Offset:   96
;       float4 _MainLightOcclusionProbes;             ; Offset:  112
;       uint _MainLightLayerMask;                     ; Offset:  128
;       float4 _AmbientOcclusionParam;                ; Offset:  144
;       float4 _AdditionalLightsCount;                ; Offset:  160
;       uint _RenderingLayerMaxInt;                   ; Offset:  176
;       float _RenderingLayerRcpMaxInt;               ; Offset:  180
;       float4 _ScreenCoordScaleBias;                 ; Offset:  192
;       float4 _ScreenSizeOverride;                   ; Offset:  208
;       uint _EnableProbeVolumes;                     ; Offset:  224
;       float4 _Time;                                 ; Offset:  240
;       float4 _SinTime;                              ; Offset:  256
;       float4 _CosTime;                              ; Offset:  272
;       float4 unity_DeltaTime;                       ; Offset:  288
;       float4 _TimeParameters;                       ; Offset:  304
;       float4 _LastTimeParameters;                   ; Offset:  320
;       float3 _WorldSpaceCameraPos;                  ; Offset:  336
;       float4 _ProjectionParams;                     ; Offset:  352
;       float4 _ScreenParams;                         ; Offset:  368
;       float4 _ZBufferParams;                        ; Offset:  384
;       float4 unity_OrthoParams;                     ; Offset:  400
;       float4 _ScaleBias;                            ; Offset:  416
;       float4 _ScaleBiasRt;                          ; Offset:  432
;       float4 _RTHandleScale;                        ; Offset:  448
;       float4 unity_CameraWorldClipPlanes[6];        ; Offset:  464
;       column_major float4x4 unity_CameraProjection; ; Offset:  560
;       column_major float4x4 unity_CameraInvProjection;; Offset:  624
;       column_major float4x4 unity_WorldToCamera;    ; Offset:  688
;       column_major float4x4 unity_CameraToWorld;    ; Offset:  752
;       column_major float4x4 glstate_matrix_transpose_modelview0;; Offset:  816
;       float4 glstate_lightmodel_ambient;            ; Offset:  880
;       float4 unity_AmbientSky;                      ; Offset:  896
;       float4 unity_AmbientEquator;                  ; Offset:  912
;       float4 unity_AmbientGround;                   ; Offset:  928
;       float4 unity_IndirectSpecColor;               ; Offset:  944
;       float4 unity_FogParams;                       ; Offset:  960
;       float4 unity_FogColor;                        ; Offset:  976
;       column_major float4x4 glstate_matrix_projection;; Offset:  992
;       column_major float4x4 unity_MatrixV;          ; Offset: 1056
;       column_major float4x4 unity_MatrixInvV;       ; Offset: 1120
;       column_major float4x4 unity_MatrixInvP;       ; Offset: 1184
;       column_major float4x4 unity_MatrixVP;         ; Offset: 1248
;       column_major float4x4 unity_MatrixInvVP;      ; Offset: 1312
;       float4 unity_StereoScaleOffset;               ; Offset: 1376
;       int unity_StereoEyeIndex;                     ; Offset: 1392
;       float4 unity_ShadowColor;                     ; Offset: 1408
;       column_major float4x4 _PrevViewProjMatrix;    ; Offset: 1424
;       column_major float4x4 _NonJitteredViewProjMatrix;; Offset: 1488
;       column_major float4x4 _ViewProjMatrix;        ; Offset: 1552
;       column_major float4x4 _ViewMatrix;            ; Offset: 1616
;       column_major float4x4 _ProjMatrix;            ; Offset: 1680
;       column_major float4x4 _InvViewProjMatrix;     ; Offset: 1744
;       column_major float4x4 _InvViewMatrix;         ; Offset: 1808
;       column_major float4x4 _InvProjMatrix;         ; Offset: 1872
;       float4 _InvProjParam;                         ; Offset: 1936
;       float4 _ScreenSize;                           ; Offset: 1952
;       float4 _FrustumPlanes[6];                     ; Offset: 1968
;       float4 _HLGI_SurfaceAtlasSize;                ; Offset: 2064
;       int _HLGI_ProxyCount;                         ; Offset: 2080
;       int _HLGI_SurfaceCardCount;                   ; Offset: 2084
;       int _HLGI_FrameIndex;                         ; Offset: 2088
;       int _HLGI_Epoch;                              ; Offset: 2092
;       int _HLGI_CacheGrid;                          ; Offset: 2096
;       int _HLGI_CacheRays;                          ; Offset: 2100
;       int _HLGI_LightCount;                         ; Offset: 2104
;       int _HLGI_ChangeCount;                        ; Offset: 2108
;       float _HLGI_RayBias;                          ; Offset: 2112
;       float _HLGI_BounceFeedback;                   ; Offset: 2116
;       float _HLGI_GuideWeight;                      ; Offset: 2120
;       float _HLGI_GlobalReactive;                   ; Offset: 2124
;       float _HLGI_GlobalGeometryChange;             ; Offset: 2128
;       int _ReferenceActiveCount;                    ; Offset: 2132
;       int _ReferenceLogical;                        ; Offset: 2136
;       int _ReferenceCacheReadIndex;                 ; Offset: 2140
;       int _ReferenceTileCapacity;                   ; Offset: 2144
;       int _ReferenceChangeCapacity;                 ; Offset: 2148
;       float4 _HLGI_Size;                            ; Offset: 2160
;       float4 _HLGI_FullSize;                        ; Offset: 2176
;       column_major float4x4 _HLGI_InvVP;            ; Offset: 2192
;       column_major float4x4 _HLGI_View;             ; Offset: 2256
;       int _HLGI_NormalsOct;                         ; Offset: 2320
;       int _HLGI_Rays;                               ; Offset: 2324
;       int _ReferencePixelCount;                     ; Offset: 2328
;   
;   } $Globals;                                       ; Offset:    0 Size:  2332
;
; }
;
; Resource bind info for _HLGI_Proxies
; {
;
;   struct struct.HLGIProxy
;   {
;
;       float4 centerShape;                           ; Offset:    0
;       float4 extentsRoughness;                      ; Offset:   16
;       float4 albedo;                                ; Offset:   32
;       float4 emission;                              ; Offset:   48
;       float4 identity;                              ; Offset:   64
;   
;   } $Element;                                       ; Offset:    0 Size:    80
;
; }
;
; Resource bind info for _HLGI_SurfaceCards
; {
;
;   struct hostlayout.struct.HLGISurfaceCard
;   {
;
;       column_major float4x4 worldToCard;            ; Offset:    0
;       float4 atlasRect;                             ; Offset:   64
;       float4 directionTolerance;                    ; Offset:   80
;       uint stableId;                                ; Offset:   96
;       uint revision;                                ; Offset:  100
;       uint generation;                              ; Offset:  104
;       uint ready;                                   ; Offset:  108
;       uint ownerSlot;                               ; Offset:  112
;       uint chartId;                                 ; Offset:  116
;       uint layoutGeneration;                        ; Offset:  120
;       uint flags;                                   ; Offset:  124
;   
;   } $Element;                                       ; Offset:    0 Size:   128
;
; }
;
; Resource bind info for _HLGI_SurfaceOwnerRanges
; {
;
;   uint4 $Element;                                   ; Offset:    0 Size:    16
;
; }
;
; Resource bind info for _HLGI_SurfaceCardIndices
; {
;
;   uint $Element;                                    ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _HLGI_CacheUpdateMask
; {
;
;   uint $Element;                                    ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _HLGI_SurfaceAnchors
; {
;
;   int2 $Element;                                    ; Offset:    0 Size:     8
;
; }
;
; Resource bind info for _ReferenceCacheRead
; {
;
;   struct struct.HLGICacheEntry
;   {
;
;       float4 irradiance;                            ; Offset:    0
;       float4 tag;                                   ; Offset:   16
;       float4 anchor;                                ; Offset:   32
;       float4 normal;                                ; Offset:   48
;       float4 guide;                                 ; Offset:   64
;   
;   } $Element;                                       ; Offset:    0 Size:    80
;
; }
;
; Resource bind info for _ReferenceCards
; {
;
;   struct hostlayout.struct.HLGISurfaceCard
;   {
;
;       column_major float4x4 worldToCard;            ; Offset:    0
;       float4 atlasRect;                             ; Offset:   64
;       float4 directionTolerance;                    ; Offset:   80
;       uint stableId;                                ; Offset:   96
;       uint revision;                                ; Offset:  100
;       uint generation;                              ; Offset:  104
;       uint ready;                                   ; Offset:  108
;       uint ownerSlot;                               ; Offset:  112
;       uint chartId;                                 ; Offset:  116
;       uint layoutGeneration;                        ; Offset:  120
;       uint flags;                                   ; Offset:  124
;   
;   } $Element;                                       ; Offset:    0 Size:   128
;
; }
;
; Resource bind info for _ReferenceOwnerRanges
; {
;
;   uint4 $Element;                                   ; Offset:    0 Size:    16
;
; }
;
; Resource bind info for _ReferenceCardIndices
; {
;
;   uint $Element;                                    ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _ReferenceMask
; {
;
;   uint $Element;                                    ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _ReferenceAnchors
; {
;
;   int2 $Element;                                    ; Offset:    0 Size:     8
;
; }
;
; Resource bind info for _ReferenceOwnerIdentities
; {
;
;   float4 $Element;                                  ; Offset:    0 Size:    16
;
; }
;
; Resource bind info for _ReferenceCacheState
; {
;
;   float4 $Element;                                  ; Offset:    0 Size:    16
;
; }
;
; Resource bind info for _ReferenceGlobals
; {
;
;   float4 $Element;                                  ; Offset:    0 Size:    16
;
; }
;
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; $Globals                          cbuffer      NA          NA     CB0            cb0     1
; _HLGI_Proxies                     texture  struct         r/o      T0             t0     1
; _HLGI_SurfaceCards                texture  struct         r/o      T1             t1     1
; _HLGI_SurfaceOwnerRanges          texture  struct         r/o      T2             t2     1
; _HLGI_SurfaceCardIndices          texture  struct         r/o      T3             t3     1
; _HLGI_CacheUpdateMask             texture  struct         r/o      T4             t4     1
; _HLGI_SurfaceAnchors              texture  struct         r/o      T5             t5     1
; _ReferenceCacheRead               texture  struct         r/o      T6             t6     1
; _ReferenceCards                       UAV  struct         r/w      U0             u0     1
; _ReferenceOwnerRanges                 UAV  struct         r/w      U1             u1     1
; _ReferenceCardIndices                 UAV  struct         r/w      U2             u2     1
; _ReferenceMask                        UAV  struct         r/w      U3             u3     1
; _ReferenceAnchors                     UAV  struct         r/w      U4             u4     1
; _ReferenceOwnerIdentities             UAV  struct         r/w      U5             u5     1
; _ReferenceCacheState                  UAV  struct         r/w      U6             u6     1
; _ReferenceGlobals                     UAV  struct         r/w      U7             u7     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%dx.types.ResRet.i32 = type { i32, i32, i32, i32, i32 }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%"class.StructuredBuffer<HLGIProxy>" = type { %struct.HLGIProxy }
%struct.HLGIProxy = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%"hostlayout.class.StructuredBuffer<HLGISurfaceCard>" = type { %hostlayout.struct.HLGISurfaceCard }
%hostlayout.struct.HLGISurfaceCard = type { [4 x <4 x float>], <4 x float>, <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32 }
%"class.StructuredBuffer<vector<unsigned int, 4> >" = type { <4 x i32> }
%"class.StructuredBuffer<unsigned int>" = type { i32 }
%"class.StructuredBuffer<vector<int, 2> >" = type { <2 x i32> }
%"class.StructuredBuffer<HLGICacheEntry>" = type { %struct.HLGICacheEntry }
%struct.HLGICacheEntry = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%"hostlayout.class.RWStructuredBuffer<HLGISurfaceCard>" = type { %hostlayout.struct.HLGISurfaceCard }
%"class.RWStructuredBuffer<vector<unsigned int, 4> >" = type { <4 x i32> }
%"class.RWStructuredBuffer<unsigned int>" = type { i32 }
%"class.RWStructuredBuffer<vector<int, 2> >" = type { <2 x i32> }
%"class.RWStructuredBuffer<vector<float, 4> >" = type { <4 x float> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32, float, float, float, float, float, i32, i32, i32, i32, i32, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], i32, i32, i32 }

define void @CSReferenceMetadata() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 7, i32 7, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 6, i32 6, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 5, i32 5, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 4, i32 4, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 3, i32 3, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %8 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %9 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 6, i32 6, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %10 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 5, i32 5, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %11 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 4, i32 4, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %12 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 3, i32 3, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %13 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %14 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %15 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %16 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %17 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %18 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %19 = extractvalue %dx.types.CBufRet.i32 %18, 1
  %20 = icmp ult i32 %17, %19
  br i1 %20, label %21, label %96

; <label>:21                                      ; preds = %0
  %22 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %14, i32 %17, i32 0)  ; BufferLoad(srv,index,wot)
  %23 = extractvalue %dx.types.ResRet.f32 %22, 0
  %24 = extractvalue %dx.types.ResRet.f32 %22, 1
  %25 = extractvalue %dx.types.ResRet.f32 %22, 2
  %26 = extractvalue %dx.types.ResRet.f32 %22, 3
  %27 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %14, i32 %17, i32 16)  ; BufferLoad(srv,index,wot)
  %28 = extractvalue %dx.types.ResRet.f32 %27, 0
  %29 = extractvalue %dx.types.ResRet.f32 %27, 1
  %30 = extractvalue %dx.types.ResRet.f32 %27, 2
  %31 = extractvalue %dx.types.ResRet.f32 %27, 3
  %32 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %14, i32 %17, i32 32)  ; BufferLoad(srv,index,wot)
  %33 = extractvalue %dx.types.ResRet.f32 %32, 0
  %34 = extractvalue %dx.types.ResRet.f32 %32, 1
  %35 = extractvalue %dx.types.ResRet.f32 %32, 2
  %36 = extractvalue %dx.types.ResRet.f32 %32, 3
  %37 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %14, i32 %17, i32 48)  ; BufferLoad(srv,index,wot)
  %38 = extractvalue %dx.types.ResRet.f32 %37, 0
  %39 = extractvalue %dx.types.ResRet.f32 %37, 1
  %40 = extractvalue %dx.types.ResRet.f32 %37, 2
  %41 = extractvalue %dx.types.ResRet.f32 %37, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %8, i32 %17, i32 0, float %23, float %24, float %25, float %26, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %8, i32 %17, i32 16, float %28, float %29, float %30, float %31, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %8, i32 %17, i32 32, float %33, float %34, float %35, float %36, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %8, i32 %17, i32 48, float %38, float %39, float %40, float %41, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %42 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %14, i32 %17, i32 64)  ; BufferLoad(srv,index,wot)
  %43 = extractvalue %dx.types.ResRet.f32 %42, 0
  %44 = extractvalue %dx.types.ResRet.f32 %42, 1
  %45 = extractvalue %dx.types.ResRet.f32 %42, 2
  %46 = extractvalue %dx.types.ResRet.f32 %42, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %8, i32 %17, i32 64, float %43, float %44, float %45, float %46, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %47 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %14, i32 %17, i32 80)  ; BufferLoad(srv,index,wot)
  %48 = extractvalue %dx.types.ResRet.f32 %47, 0
  %49 = extractvalue %dx.types.ResRet.f32 %47, 1
  %50 = extractvalue %dx.types.ResRet.f32 %47, 2
  %51 = extractvalue %dx.types.ResRet.f32 %47, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %8, i32 %17, i32 80, float %48, float %49, float %50, float %51, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %52 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 96)  ; BufferLoad(srv,index,wot)
  %53 = extractvalue %dx.types.ResRet.i32 %52, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 96, i32 %53, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %54 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 100)  ; BufferLoad(srv,index,wot)
  %55 = extractvalue %dx.types.ResRet.i32 %54, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 100, i32 %55, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %56 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 104)  ; BufferLoad(srv,index,wot)
  %57 = extractvalue %dx.types.ResRet.i32 %56, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 104, i32 %57, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %58 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 108)  ; BufferLoad(srv,index,wot)
  %59 = extractvalue %dx.types.ResRet.i32 %58, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 108, i32 %59, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %60 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 112)  ; BufferLoad(srv,index,wot)
  %61 = extractvalue %dx.types.ResRet.i32 %60, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 112, i32 %61, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %62 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 116)  ; BufferLoad(srv,index,wot)
  %63 = extractvalue %dx.types.ResRet.i32 %62, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 116, i32 %63, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %64 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 120)  ; BufferLoad(srv,index,wot)
  %65 = extractvalue %dx.types.ResRet.i32 %64, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 120, i32 %65, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %66 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %14, i32 %17, i32 124)  ; BufferLoad(srv,index,wot)
  %67 = extractvalue %dx.types.ResRet.i32 %66, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %8, i32 %17, i32 124, i32 %67, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %68 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %12, i32 %17, i32 0)  ; BufferLoad(srv,index,wot)
  %69 = extractvalue %dx.types.ResRet.i32 %68, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %6, i32 %17, i32 0, i32 %69, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %70 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %10, i32 %17, i32 0)  ; BufferLoad(srv,index,wot)
  %71 = extractvalue %dx.types.ResRet.i32 %70, 0
  %72 = extractvalue %dx.types.ResRet.i32 %70, 1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %4, i32 %17, i32 0, i32 %71, i32 %72, i32 undef, i32 undef, i8 3)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %73 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %11, i32 %17, i32 0)  ; BufferLoad(srv,index,wot)
  %74 = extractvalue %dx.types.ResRet.i32 %73, 0
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %5, i32 %17, i32 0, i32 %74, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %75 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %9, i32 %17, i32 0)  ; BufferLoad(srv,index,wot)
  %76 = extractvalue %dx.types.ResRet.f32 %75, 3
  %77 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %9, i32 %17, i32 16)  ; BufferLoad(srv,index,wot)
  %78 = extractvalue %dx.types.ResRet.f32 %77, 0
  %79 = extractvalue %dx.types.ResRet.f32 %77, 1
  %80 = extractvalue %dx.types.ResRet.f32 %77, 2
  %81 = extractvalue %dx.types.ResRet.f32 %77, 3
  %82 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %9, i32 %17, i32 32)  ; BufferLoad(srv,index,wot)
  %83 = extractvalue %dx.types.ResRet.f32 %82, 0
  %84 = extractvalue %dx.types.ResRet.f32 %82, 1
  %85 = extractvalue %dx.types.ResRet.f32 %82, 2
  %86 = extractvalue %dx.types.ResRet.f32 %82, 3
  %87 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %9, i32 %17, i32 48)  ; BufferLoad(srv,index,wot)
  %88 = extractvalue %dx.types.ResRet.f32 %87, 0
  %89 = extractvalue %dx.types.ResRet.f32 %87, 1
  %90 = extractvalue %dx.types.ResRet.f32 %87, 2
  %91 = extractvalue %dx.types.ResRet.f32 %87, 3
  %92 = shl i32 %17, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %2, i32 %92, i32 0, float %76, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %93 = or i32 %92, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %2, i32 %93, i32 0, float %78, float %79, float %80, float %81, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %94 = or i32 %92, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %2, i32 %94, i32 0, float %83, float %84, float %85, float %86, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %95 = or i32 %92, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %2, i32 %95, i32 0, float %88, float %89, float %90, float %91, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %96

; <label>:96                                      ; preds = %21, %0
  %97 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %98 = extractvalue %dx.types.CBufRet.i32 %97, 0
  %99 = icmp ult i32 %17, %98
  br i1 %99, label %100, label %111

; <label>:100                                     ; preds = %96
  %101 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %13, i32 %17, i32 0)  ; BufferLoad(srv,index,wot)
  %102 = extractvalue %dx.types.ResRet.i32 %101, 0
  %103 = extractvalue %dx.types.ResRet.i32 %101, 1
  %104 = extractvalue %dx.types.ResRet.i32 %101, 2
  %105 = extractvalue %dx.types.ResRet.i32 %101, 3
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %7, i32 %17, i32 0, i32 %102, i32 %103, i32 %104, i32 %105, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %106 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %15, i32 %17, i32 64)  ; BufferLoad(srv,index,wot)
  %107 = extractvalue %dx.types.ResRet.f32 %106, 0
  %108 = extractvalue %dx.types.ResRet.f32 %106, 1
  %109 = extractvalue %dx.types.ResRet.f32 %106, 2
  %110 = extractvalue %dx.types.ResRet.f32 %106, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %3, i32 %17, i32 0, float %107, float %108, float %109, float %110, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %111

; <label>:111                                     ; preds = %100, %96
  %112 = icmp eq i32 %17, 0
  br i1 %112, label %113, label %154

; <label>:113                                     ; preds = %111
  %114 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %115 = extractvalue %dx.types.CBufRet.i32 %114, 2
  %116 = extractvalue %dx.types.CBufRet.i32 %114, 3
  %117 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %118 = extractvalue %dx.types.CBufRet.i32 %117, 3
  %119 = extractvalue %dx.types.CBufRet.i32 %117, 2
  %120 = bitcast i32 %115 to float
  %121 = bitcast i32 %116 to float
  %122 = bitcast i32 %118 to float
  %123 = bitcast i32 %119 to float
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 0, i32 0, float %120, float %121, float %122, float %123, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %124 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %125 = extractvalue %dx.types.CBufRet.i32 %124, 0
  %126 = extractvalue %dx.types.CBufRet.i32 %124, 1
  %127 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %128 = extractvalue %dx.types.CBufRet.i32 %127, 0
  %129 = extractvalue %dx.types.CBufRet.i32 %127, 1
  %130 = bitcast i32 %125 to float
  %131 = bitcast i32 %126 to float
  %132 = bitcast i32 %128 to float
  %133 = bitcast i32 %129 to float
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 1, i32 0, float %130, float %131, float %132, float %133, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %134 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %16, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %135 = extractvalue %dx.types.CBufRet.f32 %134, 0
  %136 = extractvalue %dx.types.CBufRet.f32 %134, 1
  %137 = extractvalue %dx.types.CBufRet.f32 %134, 3
  %138 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %16, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %139 = extractvalue %dx.types.CBufRet.f32 %138, 0
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 2, i32 0, float %135, float %136, float %137, float %139, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %140 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %141 = extractvalue %dx.types.CBufRet.i32 %140, 3
  %142 = extractvalue %dx.types.CBufRet.i32 %140, 2
  %143 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %144 = extractvalue %dx.types.CBufRet.i32 %143, 1
  %145 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %16, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %146 = extractvalue %dx.types.CBufRet.i32 %145, 0
  %147 = bitcast i32 %141 to float
  %148 = bitcast i32 %142 to float
  %149 = bitcast i32 %144 to float
  %150 = bitcast i32 %146 to float
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 3, i32 0, float %147, float %148, float %149, float %150, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %151 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %16, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %152 = extractvalue %dx.types.CBufRet.f32 %151, 0
  %153 = extractvalue %dx.types.CBufRet.f32 %151, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 4, i32 0, float %152, float %153, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %154

; <label>:154                                     ; preds = %113, %111
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32, %dx.types.Handle, i32, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32, %dx.types.Handle, i32, i32) #1

; Function Attrs: nounwind
declare void @dx.op.bufferStore.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i8) #2

; Function Attrs: nounwind
declare void @dx.op.bufferStore.f32(i32, %dx.types.Handle, i32, i32, float, float, float, float, i8) #2

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind readonly }
attributes #2 = { nounwind }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.entryPoints = !{!28}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !17, !26, null}
!5 = !{!6, !8, !10, !12, !14, !15, !16}
!6 = !{i32 0, %"class.StructuredBuffer<HLGIProxy>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 80}
!8 = !{i32 1, %"hostlayout.class.StructuredBuffer<HLGISurfaceCard>"* undef, !"", i32 0, i32 1, i32 1, i32 12, i32 0, !9}
!9 = !{i32 1, i32 128}
!10 = !{i32 2, %"class.StructuredBuffer<vector<unsigned int, 4> >"* undef, !"", i32 0, i32 2, i32 1, i32 12, i32 0, !11}
!11 = !{i32 1, i32 16}
!12 = !{i32 3, %"class.StructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 3, i32 1, i32 12, i32 0, !13}
!13 = !{i32 1, i32 4}
!14 = !{i32 4, %"class.StructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 4, i32 1, i32 12, i32 0, !13}
!15 = !{i32 5, %"class.StructuredBuffer<vector<int, 2> >"* undef, !"", i32 0, i32 5, i32 1, i32 12, i32 0, !2}
!16 = !{i32 6, %"class.StructuredBuffer<HLGICacheEntry>"* undef, !"", i32 0, i32 6, i32 1, i32 12, i32 0, !7}
!17 = !{!18, !19, !20, !21, !22, !23, !24, !25}
!18 = !{i32 0, %"hostlayout.class.RWStructuredBuffer<HLGISurfaceCard>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !9}
!19 = !{i32 1, %"class.RWStructuredBuffer<vector<unsigned int, 4> >"* undef, !"", i32 0, i32 1, i32 1, i32 12, i1 false, i1 false, i1 false, !11}
!20 = !{i32 2, %"class.RWStructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 2, i32 1, i32 12, i1 false, i1 false, i1 false, !13}
!21 = !{i32 3, %"class.RWStructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 3, i32 1, i32 12, i1 false, i1 false, i1 false, !13}
!22 = !{i32 4, %"class.RWStructuredBuffer<vector<int, 2> >"* undef, !"", i32 0, i32 4, i32 1, i32 12, i1 false, i1 false, i1 false, !2}
!23 = !{i32 5, %"class.RWStructuredBuffer<vector<float, 4> >"* undef, !"", i32 0, i32 5, i32 1, i32 12, i1 false, i1 false, i1 false, !11}
!24 = !{i32 6, %"class.RWStructuredBuffer<vector<float, 4> >"* undef, !"", i32 0, i32 6, i32 1, i32 12, i1 false, i1 false, i1 false, !11}
!25 = !{i32 7, %"class.RWStructuredBuffer<vector<float, 4> >"* undef, !"", i32 0, i32 7, i32 1, i32 12, i1 false, i1 false, i1 false, !11}
!26 = !{!27}
!27 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2332, null}
!28 = !{void ()* @CSReferenceMetadata, !"CSReferenceMetadata", null, !4, !29}
!29 = !{i32 0, i64 16, i32 4, !30}
!30 = !{i32 64, i32 1, i32 1}
