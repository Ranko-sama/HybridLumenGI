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
; shader hash: 84b14f8928ce7d5f012f06c0c4575697
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
; EntryFunctionName: CSReferenceCacheInputs
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
; Resource bind info for _ReferenceActiveCards
; {
;
;   uint2 $Element;                                   ; Offset:    0 Size:     8
;
; }
;
; Resource bind info for _ReferenceCacheRows
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
; _HLGI_SurfaceCards                texture  struct         r/o      T0             t0     1
; _HLGI_CacheUpdateMask             texture  struct         r/o      T1             t1     1
; _HLGI_SurfaceAnchors              texture  struct         r/o      T2             t2     1
; _HLGI_SurfacePosition             texture     f32          2d      T3             t3     1
; _HLGI_SurfaceNormal               texture     f32          2d      T4             t4     1
; _HLGI_SurfaceEmission             texture     f32          2d      T5             t5     1
; _ReferenceActiveCards             texture  struct         r/o      T6             t6     1
; _ReferenceCacheRows                   UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.i32 = type { i32, i32, i32, i32, i32 }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"hostlayout.class.StructuredBuffer<HLGISurfaceCard>" = type { %hostlayout.struct.HLGISurfaceCard }
%hostlayout.struct.HLGISurfaceCard = type { [4 x <4 x float>], <4 x float>, <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32 }
%"class.StructuredBuffer<unsigned int>" = type { i32 }
%"class.StructuredBuffer<vector<int, 2> >" = type { <2 x i32> }
%"class.Texture2D<vector<float, 4> >" = type { <4 x float>, %"class.Texture2D<vector<float, 4> >::mips_type" }
%"class.Texture2D<vector<float, 4> >::mips_type" = type { i32 }
%"class.StructuredBuffer<vector<unsigned int, 2> >" = type { <2 x i32> }
%"class.RWStructuredBuffer<vector<float, 4> >" = type { <4 x float> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32, float, float, float, float, float, i32, i32, i32, i32, i32, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], i32, i32, i32 }

define void @CSReferenceCacheInputs() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 6, i32 6, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 5, i32 5, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 4, i32 4, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 3, i32 3, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %8 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %9 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %10 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %11 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %12 = extractvalue %dx.types.CBufRet.i32 %11, 1
  %13 = icmp ult i32 %10, %12
  br i1 %13, label %14, label %375

; <label>:14                                      ; preds = %0
  %15 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %2, i32 %10, i32 0)  ; BufferLoad(srv,index,wot)
  %16 = extractvalue %dx.types.ResRet.i32 %15, 0
  %17 = extractvalue %dx.types.ResRet.i32 %15, 1
  %18 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %19 = extractvalue %dx.types.CBufRet.i32 %18, 1
  %20 = icmp sgt i32 %19, 0
  br i1 %20, label %21, label %35

; <label>:21                                      ; preds = %14
  br label %22

; <label>:22                                      ; preds = %22, %21
  %23 = phi i32 [ %29, %22 ], [ 0, %21 ]
  %24 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %25 = extractvalue %dx.types.CBufRet.i32 %24, 1
  %26 = shl i32 %10, 3
  %27 = mul i32 %26, %25
  %28 = add i32 %27, %23
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %28, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %29 = add nuw nsw i32 %23, 1
  %30 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %31 = extractvalue %dx.types.CBufRet.i32 %30, 1
  %32 = shl nsw i32 %31, 3
  %33 = icmp slt i32 %29, %32
  br i1 %33, label %22, label %34, !llvm.loop !24

; <label>:34                                      ; preds = %22
  br label %35

; <label>:35                                      ; preds = %34, %14
  %36 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %37 = extractvalue %dx.types.CBufRet.i32 %36, 0
  %38 = icmp ne i32 %37, 1
  %39 = extractvalue %dx.types.CBufRet.i32 %36, 1
  %40 = add i32 %39, -1
  %41 = icmp ugt i32 %40, 31
  %42 = or i1 %41, %38
  %43 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %44 = extractvalue %dx.types.CBufRet.f32 %43, 2
  %45 = fcmp fast une float %44, 0.000000e+00
  %46 = or i1 %45, %42
  %47 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %48 = extractvalue %dx.types.CBufRet.i32 %47, 1
  %49 = icmp uge i32 %16, %48
  %50 = or i1 %49, %46
  br i1 %50, label %375, label %51

; <label>:51                                      ; preds = %35
  %52 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %8, i32 %16, i32 64)  ; BufferLoad(srv,index,wot)
  %53 = extractvalue %dx.types.ResRet.f32 %52, 0
  %54 = extractvalue %dx.types.ResRet.f32 %52, 1
  %55 = extractvalue %dx.types.ResRet.f32 %52, 2
  %56 = extractvalue %dx.types.ResRet.f32 %52, 3
  %57 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %8, i32 %16, i32 104)  ; BufferLoad(srv,index,wot)
  %58 = extractvalue %dx.types.ResRet.i32 %57, 0
  %59 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %8, i32 %16, i32 112)  ; BufferLoad(srv,index,wot)
  %60 = extractvalue %dx.types.ResRet.i32 %59, 0
  %61 = icmp eq i32 %60, %17
  br i1 %61, label %62, label %375

; <label>:62                                      ; preds = %51
  %63 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %53)  ; IsFinite(value)
  %64 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %65 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %66 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %67 = and i1 %63, %64
  %68 = and i1 %67, %65
  %69 = and i1 %68, %66
  %70 = xor i1 %69, true
  %71 = fcmp fast olt float %53, 0.000000e+00
  %72 = fcmp fast olt float %54, 0.000000e+00
  %73 = fcmp fast olt float %55, 0.000000e+00
  %74 = fcmp fast olt float %56, 0.000000e+00
  %75 = or i1 %71, %72
  %76 = or i1 %73, %75
  %77 = or i1 %74, %76
  %78 = or i1 %77, %70
  %79 = fcmp fast ogt float %53, 1.000000e+00
  %80 = fcmp fast ogt float %54, 1.000000e+00
  %81 = fcmp fast ogt float %55, 1.000000e+00
  %82 = fcmp fast ogt float %56, 1.000000e+00
  %83 = or i1 %79, %80
  %84 = or i1 %81, %83
  %85 = or i1 %82, %84
  %86 = or i1 %85, %78
  %87 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %88 = extractvalue %dx.types.CBufRet.f32 %87, 0
  %89 = extractvalue %dx.types.CBufRet.f32 %87, 1
  %90 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %88)  ; IsFinite(value)
  %91 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %89)  ; IsFinite(value)
  %92 = and i1 %90, %91
  %93 = xor i1 %92, true
  %94 = or i1 %86, %93
  %95 = fcmp fast olt float %88, 1.000000e+00
  %96 = fcmp fast olt float %89, 1.000000e+00
  %97 = or i1 %95, %96
  %98 = or i1 %97, %94
  %99 = fcmp fast ogt float %88, 3.276800e+04
  %100 = fcmp fast ogt float %89, 3.276800e+04
  %101 = or i1 %99, %100
  %102 = or i1 %101, %98
  br i1 %102, label %134, label %103

; <label>:103                                     ; preds = %62
  %104 = call float @dx.op.unary.f32(i32 26, float %88)  ; Round_ne(value)
  %105 = call float @dx.op.unary.f32(i32 26, float %89)  ; Round_ne(value)
  %106 = fptosi float %104 to i32
  %107 = fptosi float %105 to i32
  %108 = sitofp i32 %106 to float
  %109 = sitofp i32 %107 to float
  %110 = fmul fast float %108, %53
  %111 = fmul fast float %109, %54
  %112 = call float @dx.op.unary.f32(i32 26, float %110)  ; Round_ne(value)
  %113 = call float @dx.op.unary.f32(i32 26, float %111)  ; Round_ne(value)
  %114 = fptosi float %112 to i32
  %115 = fptosi float %113 to i32
  %116 = fmul fast float %108, %55
  %117 = fmul fast float %109, %56
  %118 = call float @dx.op.unary.f32(i32 26, float %116)  ; Round_ne(value)
  %119 = call float @dx.op.unary.f32(i32 26, float %117)  ; Round_ne(value)
  %120 = fptosi float %118 to i32
  %121 = fptosi float %119 to i32
  %122 = icmp sgt i32 %120, 0
  %123 = icmp sgt i32 %121, 0
  %124 = and i1 %122, %123
  %125 = or i32 %115, %114
  %126 = icmp sgt i32 %125, -1
  %127 = and i1 %126, %124
  %128 = add i32 %120, %114
  %129 = add i32 %121, %115
  %130 = icmp sle i32 %128, %106
  %131 = icmp sle i32 %129, %107
  %132 = and i1 %130, %131
  %133 = and i1 %127, %132
  br label %134

; <label>:134                                     ; preds = %103, %62
  %135 = phi i32 [ %120, %103 ], [ 0, %62 ]
  %136 = phi i32 [ %121, %103 ], [ 0, %62 ]
  %137 = phi i32 [ %114, %103 ], [ 0, %62 ]
  %138 = phi i32 [ %115, %103 ], [ 0, %62 ]
  %139 = phi i1 [ %133, %103 ], [ false, %62 ]
  br i1 %139, label %140, label %375

; <label>:140                                     ; preds = %134
  %141 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %6, i32 %16, i32 0)  ; BufferLoad(srv,index,wot)
  %142 = extractvalue %dx.types.ResRet.i32 %141, 0
  %143 = extractvalue %dx.types.ResRet.i32 %141, 1
  %144 = icmp slt i32 %142, %137
  %145 = icmp slt i32 %143, %138
  %146 = or i1 %144, %145
  %147 = add i32 %137, %135
  %148 = add i32 %138, %136
  %149 = icmp sge i32 %142, %147
  %150 = icmp sge i32 %143, %148
  %151 = or i1 %149, %150
  %152 = or i1 %146, %151
  br i1 %152, label %375, label %153

; <label>:153                                     ; preds = %140
  %154 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %5, i32 0, i32 %142, i32 %143, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %155 = extractvalue %dx.types.ResRet.f32 %154, 0
  %156 = extractvalue %dx.types.ResRet.f32 %154, 1
  %157 = extractvalue %dx.types.ResRet.f32 %154, 2
  %158 = extractvalue %dx.types.ResRet.f32 %154, 3
  %159 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %142, i32 %143, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %160 = extractvalue %dx.types.ResRet.f32 %159, 0
  %161 = extractvalue %dx.types.ResRet.f32 %159, 1
  %162 = extractvalue %dx.types.ResRet.f32 %159, 2
  %163 = extractvalue %dx.types.ResRet.f32 %159, 3
  %164 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %3, i32 0, i32 %142, i32 %143, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %165 = extractvalue %dx.types.ResRet.f32 %164, 3
  %166 = call float @dx.op.dot3.f32(i32 55, float %160, float %161, float %162, float %160, float %161, float %162)  ; Dot3(ax,ay,az,bx,by,bz)
  %167 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %155)  ; IsFinite(value)
  %168 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %156)  ; IsFinite(value)
  %169 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %157)  ; IsFinite(value)
  %170 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %158)  ; IsFinite(value)
  %171 = and i1 %167, %168
  %172 = and i1 %171, %169
  %173 = and i1 %172, %170
  %174 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %160)  ; IsFinite(value)
  %175 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %161)  ; IsFinite(value)
  %176 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %162)  ; IsFinite(value)
  %177 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %163)  ; IsFinite(value)
  %178 = and i1 %174, %175
  %179 = and i1 %178, %176
  %180 = and i1 %179, %177
  %181 = and i1 %173, %180
  %182 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %165)  ; IsFinite(value)
  %183 = and i1 %182, %181
  %184 = xor i1 %183, true
  %185 = fcmp fast olt float %165, 1.000000e+00
  %186 = or i1 %185, %184
  %187 = fcmp fast ogt float %165, 1.024000e+03
  %188 = or i1 %187, %186
  %189 = call float @dx.op.unary.f32(i32 26, float %165)  ; Round_ne(value)
  %190 = fcmp fast une float %165, %189
  %191 = or i1 %190, %188
  %192 = fcmp fast olt float %166, 2.500000e-01
  %193 = or i1 %192, %191
  %194 = fcmp fast olt float %158, 0.000000e+00
  %195 = or i1 %194, %193
  %196 = fcmp fast ogt float %158, 1.000000e+00
  %197 = or i1 %196, %195
  br i1 %197, label %375, label %198

; <label>:198                                     ; preds = %153
  %199 = call float @dx.op.unary.f32(i32 25, float %166)  ; Rsqrt(value)
  %200 = fmul fast float %199, %160
  %201 = fmul fast float %199, %161
  %202 = fmul fast float %199, %162
  %203 = fptoui float %189 to i32
  %204 = add i32 %203, -1
  %205 = and i32 %204, 31
  %206 = uitofp i32 %205 to float
  %207 = lshr i32 %204, 5
  %208 = and i32 %207, 31
  %209 = uitofp i32 %208 to float
  %210 = fmul fast float %206, 0x3FB0842100000000
  %211 = fmul fast float %209, 0x3FB0842100000000
  %212 = fadd fast float %210, -1.000000e+00
  %213 = fadd fast float %211, -1.000000e+00
  %214 = call float @dx.op.unary.f32(i32 6, float %212)  ; FAbs(value)
  %215 = fsub fast float 1.000000e+00, %214
  %216 = call float @dx.op.unary.f32(i32 6, float %213)  ; FAbs(value)
  %217 = fsub fast float %215, %216
  %218 = fcmp fast olt float %217, 0.000000e+00
  br i1 %218, label %219, label %227

; <label>:219                                     ; preds = %198
  %220 = fsub fast float 1.000000e+00, %216
  %221 = fcmp fast oge float %212, 0.000000e+00
  %222 = select i1 %221, float 1.000000e+00, float -1.000000e+00
  %223 = fcmp fast oge float %213, 0.000000e+00
  %224 = select i1 %223, float 1.000000e+00, float -1.000000e+00
  %225 = fmul fast float %220, %222
  %226 = fmul fast float %215, %224
  br label %227

; <label>:227                                     ; preds = %219, %198
  %228 = phi float [ %225, %219 ], [ %212, %198 ]
  %229 = phi float [ %226, %219 ], [ %213, %198 ]
  %230 = call float @dx.op.dot3.f32(i32 55, float %228, float %229, float %217, float %228, float %229, float %217)  ; Dot3(ax,ay,az,bx,by,bz)
  %231 = call float @dx.op.unary.f32(i32 25, float %230)  ; Rsqrt(value)
  %232 = fmul fast float %231, %228
  %233 = fmul fast float %231, %229
  %234 = fmul fast float %231, %217
  %235 = call float @dx.op.dot3.f32(i32 55, float %232, float %233, float %234, float %200, float %201, float %202)  ; Dot3(ax,ay,az,bx,by,bz)
  %236 = fcmp fast olt float %235, 0.000000e+00
  %237 = fsub fast float -0.000000e+00, %232
  %238 = fsub fast float -0.000000e+00, %233
  %239 = fsub fast float -0.000000e+00, %234
  %240 = select i1 %236, float %237, float %232
  %241 = select i1 %236, float %238, float %233
  %242 = select i1 %236, float %239, float %234
  %243 = extractvalue %dx.types.CBufRet.f32 %43, 0
  %244 = fmul fast float %240, %243
  %245 = fmul fast float %241, %243
  %246 = fmul fast float %242, %243
  %247 = fadd fast float %244, %155
  %248 = fadd fast float %245, %156
  %249 = fadd fast float %246, %157
  %250 = extractvalue %dx.types.CBufRet.i32 %47, 2
  %251 = add i32 %250, 1
  %252 = lshr i32 %251, 16
  %253 = xor i32 %252, %251
  %254 = mul i32 %253, 2146121005
  %255 = lshr i32 %254, 15
  %256 = xor i32 %255, %254
  %257 = mul i32 %256, -2073254261
  %258 = lshr i32 %257, 16
  %259 = xor i32 %258, %257
  %260 = add i32 %259, %16
  %261 = xor i32 %260, -1525552717
  %262 = lshr i32 %261, 16
  %263 = xor i32 %262, %261
  %264 = mul i32 %263, 2146121005
  %265 = lshr i32 %264, 15
  %266 = xor i32 %265, %264
  %267 = mul i32 %266, -2073254261
  %268 = icmp sgt i32 %39, 0
  br i1 %268, label %269, label %375

; <label>:269                                     ; preds = %227
  %270 = lshr i32 %267, 16
  %271 = xor i32 %270, %267
  br label %272

; <label>:272                                     ; preds = %272, %269
  %273 = phi i32 [ %294, %272 ], [ %271, %269 ]
  %274 = phi i32 [ %370, %272 ], [ 0, %269 ]
  %275 = lshr i32 %273, 16
  %276 = xor i32 %275, %273
  %277 = mul i32 %276, 2146121005
  %278 = lshr i32 %277, 15
  %279 = xor i32 %278, %277
  %280 = mul i32 %279, -1674769041
  %281 = lshr i32 %280, 15
  %282 = xor i32 %281, %280
  %283 = mul i32 %282, -2073254261
  %284 = lshr i32 %283, 16
  %285 = xor i32 %284, %283
  %286 = lshr i32 %285, 8
  %287 = uitofp i32 %286 to float
  %288 = fmul fast float %287, 0x3E70000000000000
  %289 = mul i32 %282, -1674769041
  %290 = lshr i32 %289, 15
  %291 = xor i32 %290, %289
  %292 = mul i32 %291, -2073254261
  %293 = lshr i32 %292, 16
  %294 = xor i32 %293, %292
  %295 = lshr i32 %294, 8
  %296 = uitofp i32 %295 to float
  %297 = call float @dx.op.unary.f32(i32 24, float %288)  ; Sqrt(value)
  %298 = fmul fast float %296, 0x3E9921FB60000000
  %299 = call float @dx.op.unary.f32(i32 6, float %202)  ; FAbs(value)
  %300 = fcmp fast olt float %299, 0x3FEFF7CEE0000000
  %301 = select i1 %300, float 0.000000e+00, float 1.000000e+00
  %302 = select i1 %300, float 1.000000e+00, float 0.000000e+00
  %303 = fmul fast float %301, %202
  %304 = fmul fast float %302, %201
  %305 = fsub fast float %303, %304
  %306 = fmul fast float %302, %200
  %307 = fmul fast float %200, %301
  %308 = fsub fast float -0.000000e+00, %307
  %309 = call float @dx.op.dot3.f32(i32 55, float %305, float %306, float %308, float %305, float %306, float %308)  ; Dot3(ax,ay,az,bx,by,bz)
  %310 = call float @dx.op.unary.f32(i32 25, float %309)  ; Rsqrt(value)
  %311 = fmul fast float %305, %310
  %312 = fmul fast float %306, %310
  %313 = fmul fast float %310, %308
  %314 = call float @dx.op.unary.f32(i32 12, float %298)  ; Cos(value)
  %315 = fmul fast float %314, %297
  %316 = fmul fast float %311, %315
  %317 = fmul fast float %312, %315
  %318 = fmul fast float %313, %315
  %319 = fmul fast float %313, %201
  %320 = fmul fast float %312, %202
  %321 = fsub fast float %319, %320
  %322 = fmul fast float %311, %202
  %323 = fmul fast float %313, %200
  %324 = fsub fast float %322, %323
  %325 = fmul fast float %312, %200
  %326 = fmul fast float %311, %201
  %327 = fsub fast float %325, %326
  %328 = call float @dx.op.unary.f32(i32 13, float %298)  ; Sin(value)
  %329 = fmul fast float %328, %297
  %330 = fmul fast float %321, %329
  %331 = fmul fast float %324, %329
  %332 = fmul fast float %327, %329
  %333 = fsub fast float 1.000000e+00, %288
  %334 = call float @dx.op.unary.f32(i32 24, float %333)  ; Sqrt(value)
  %335 = fmul fast float %334, %200
  %336 = fmul fast float %334, %201
  %337 = fmul fast float %334, %202
  %338 = fadd fast float %335, %316
  %339 = fadd fast float %338, %330
  %340 = fadd fast float %336, %317
  %341 = fadd fast float %340, %331
  %342 = fadd fast float %337, %318
  %343 = fadd fast float %342, %332
  %344 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %345 = extractvalue %dx.types.CBufRet.i32 %344, 1
  %346 = mul i32 %345, %10
  %347 = add i32 %346, %274
  %348 = shl i32 %347, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %348, i32 0, float %247, float %248, float %249, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %349 = or i32 %348, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %349, i32 0, float %339, float %341, float %343, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %350 = or i32 %348, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %350, i32 0, float %155, float %156, float %157, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %351 = or i32 %348, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %351, i32 0, float %200, float %201, float %202, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %352 = or i32 %348, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %352, i32 0, float %232, float %233, float %234, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %353 = bitcast i32 %16 to float
  %354 = or i32 %348, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %354, i32 0, float %353, float %353, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %355 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %356 = extractvalue %dx.types.CBufRet.i32 %355, 2
  %357 = extractvalue %dx.types.CBufRet.i32 %355, 3
  %358 = bitcast i32 %17 to float
  %359 = bitcast i32 %356 to float
  %360 = bitcast i32 %357 to float
  %361 = bitcast i32 %274 to float
  %362 = or i32 %348, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %362, i32 0, float %358, float %359, float %360, float %361, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %363 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %7, i32 %16, i32 0)  ; BufferLoad(srv,index,wot)
  %364 = extractvalue %dx.types.ResRet.i32 %363, 0
  %365 = bitcast i32 %142 to float
  %366 = bitcast i32 %143 to float
  %367 = bitcast i32 %58 to float
  %368 = bitcast i32 %364 to float
  %369 = or i32 %348, 7
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %369, i32 0, float %365, float %366, float %367, float %368, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %370 = add nuw nsw i32 %274, 1
  %371 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %372 = extractvalue %dx.types.CBufRet.i32 %371, 1
  %373 = icmp slt i32 %370, %372
  br i1 %373, label %272, label %374, !llvm.loop !26

; <label>:374                                     ; preds = %272
  br label %375

; <label>:375                                     ; preds = %374, %227, %153, %140, %134, %51, %35, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind readnone
declare float @dx.op.dot3.f32(i32, float, float, float, float, float, float) #0

; Function Attrs: nounwind readnone
declare i1 @dx.op.isSpecialFloat.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32, %dx.types.Handle, i32, i32) #1

; Function Attrs: nounwind
declare void @dx.op.bufferStore.f32(i32, %dx.types.Handle, i32, i32, float, float, float, float, i8) #2

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32, %dx.types.Handle, i32, i32) #1

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind readonly }
attributes #2 = { nounwind }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.entryPoints = !{!21}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !16, !19, null}
!5 = !{!6, !8, !10, !11, !13, !14, !15}
!6 = !{i32 0, %"hostlayout.class.StructuredBuffer<HLGISurfaceCard>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 128}
!8 = !{i32 1, %"class.StructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 1, i32 1, i32 12, i32 0, !9}
!9 = !{i32 1, i32 4}
!10 = !{i32 2, %"class.StructuredBuffer<vector<int, 2> >"* undef, !"", i32 0, i32 2, i32 1, i32 12, i32 0, !2}
!11 = !{i32 3, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 3, i32 1, i32 2, i32 0, !12}
!12 = !{i32 0, i32 9}
!13 = !{i32 4, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 4, i32 1, i32 2, i32 0, !12}
!14 = !{i32 5, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 5, i32 1, i32 2, i32 0, !12}
!15 = !{i32 6, %"class.StructuredBuffer<vector<unsigned int, 2> >"* undef, !"", i32 0, i32 6, i32 1, i32 12, i32 0, !2}
!16 = !{!17}
!17 = !{i32 0, %"class.RWStructuredBuffer<vector<float, 4> >"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !18}
!18 = !{i32 1, i32 16}
!19 = !{!20}
!20 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2332, null}
!21 = !{void ()* @CSReferenceCacheInputs, !"CSReferenceCacheInputs", null, !4, !22}
!22 = !{i32 0, i64 16, i32 4, !23}
!23 = !{i32 64, i32 1, i32 1}
!24 = distinct !{!24, !25}
!25 = !{!"llvm.loop.unroll.disable"}
!26 = distinct !{!26, !25}
