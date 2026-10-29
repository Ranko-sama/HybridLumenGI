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
; shader hash: c16d1922828d5807ab7e98c19b358a1f
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
; EntryFunctionName: CSReferenceAtlas
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
; Resource bind info for _ReferenceActiveCards
; {
;
;   uint2 $Element;                                   ; Offset:    0 Size:     8
;
; }
;
; Resource bind info for _ReferenceAtlasRows
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
; _HLGI_SurfacePosition             texture     f32          2d      T1             t1     1
; _HLGI_SurfaceNormal               texture     f32          2d      T2             t2     1
; _HLGI_SurfaceEmission             texture     f32          2d      T3             t3     1
; _ReferenceActiveCards             texture  struct         r/o      T4             t4     1
; _ReferenceAtlasRows                   UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.i32 = type { i32, i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%"hostlayout.class.StructuredBuffer<HLGISurfaceCard>" = type { %hostlayout.struct.HLGISurfaceCard }
%hostlayout.struct.HLGISurfaceCard = type { [4 x <4 x float>], <4 x float>, <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32 }
%"class.Texture2D<vector<float, 4> >" = type { <4 x float>, %"class.Texture2D<vector<float, 4> >::mips_type" }
%"class.Texture2D<vector<float, 4> >::mips_type" = type { i32 }
%"class.StructuredBuffer<vector<unsigned int, 2> >" = type { <2 x i32> }
%"class.RWStructuredBuffer<vector<float, 4> >" = type { <4 x float> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32, float, float, float, float, float, i32, i32, i32, i32, i32, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], i32, i32, i32 }

define void @CSReferenceAtlas() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 4, i32 4, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 3, i32 3, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %8 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %9 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %7, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %10 = extractvalue %dx.types.CBufRet.i32 %9, 1
  %11 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %7, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %12 = extractvalue %dx.types.CBufRet.i32 %11, 0
  %13 = mul nsw i32 %12, %10
  %14 = icmp ult i32 %8, %13
  br i1 %14, label %15, label %134

; <label>:15                                      ; preds = %0
  %16 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %7, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %17 = extractvalue %dx.types.CBufRet.i32 %16, 0
  %18 = udiv i32 %8, %17
  %19 = urem i32 %8, %17
  %20 = mul i32 %8, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %20, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %21 = add i32 %20, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %21, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %22 = add i32 %20, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %22, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %23 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %2, i32 %18, i32 0)  ; BufferLoad(srv,index,wot)
  %24 = extractvalue %dx.types.ResRet.i32 %23, 0
  %25 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %7, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %26 = extractvalue %dx.types.CBufRet.i32 %25, 1
  %27 = icmp ult i32 %24, %26
  br i1 %27, label %28, label %134

; <label>:28                                      ; preds = %15
  %29 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %6, i32 %24, i32 64)  ; BufferLoad(srv,index,wot)
  %30 = extractvalue %dx.types.ResRet.f32 %29, 0
  %31 = extractvalue %dx.types.ResRet.f32 %29, 1
  %32 = extractvalue %dx.types.ResRet.f32 %29, 2
  %33 = extractvalue %dx.types.ResRet.f32 %29, 3
  %34 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %30)  ; IsFinite(value)
  %35 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %31)  ; IsFinite(value)
  %36 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %32)  ; IsFinite(value)
  %37 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %33)  ; IsFinite(value)
  %38 = and i1 %34, %35
  %39 = and i1 %38, %36
  %40 = and i1 %39, %37
  %41 = xor i1 %40, true
  %42 = fcmp fast olt float %30, 0.000000e+00
  %43 = fcmp fast olt float %31, 0.000000e+00
  %44 = fcmp fast olt float %32, 0.000000e+00
  %45 = fcmp fast olt float %33, 0.000000e+00
  %46 = or i1 %42, %43
  %47 = or i1 %44, %46
  %48 = or i1 %45, %47
  %49 = or i1 %48, %41
  %50 = fcmp fast ogt float %30, 1.000000e+00
  %51 = fcmp fast ogt float %31, 1.000000e+00
  %52 = fcmp fast ogt float %32, 1.000000e+00
  %53 = fcmp fast ogt float %33, 1.000000e+00
  %54 = or i1 %50, %51
  %55 = or i1 %52, %54
  %56 = or i1 %53, %55
  %57 = or i1 %56, %49
  %58 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %59 = extractvalue %dx.types.CBufRet.f32 %58, 0
  %60 = extractvalue %dx.types.CBufRet.f32 %58, 1
  %61 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %59)  ; IsFinite(value)
  %62 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %60)  ; IsFinite(value)
  %63 = and i1 %61, %62
  %64 = xor i1 %63, true
  %65 = or i1 %57, %64
  %66 = fcmp fast olt float %59, 1.000000e+00
  %67 = fcmp fast olt float %60, 1.000000e+00
  %68 = or i1 %66, %67
  %69 = or i1 %68, %65
  %70 = fcmp fast ogt float %59, 3.276800e+04
  %71 = fcmp fast ogt float %60, 3.276800e+04
  %72 = or i1 %70, %71
  %73 = or i1 %72, %69
  br i1 %73, label %106, label %74

; <label>:74                                      ; preds = %28
  %75 = call float @dx.op.unary.f32(i32 26, float %59)  ; Round_ne(value)
  %76 = call float @dx.op.unary.f32(i32 26, float %60)  ; Round_ne(value)
  %77 = fptosi float %75 to i32
  %78 = fptosi float %76 to i32
  %79 = sitofp i32 %77 to float
  %80 = sitofp i32 %78 to float
  %81 = fmul fast float %79, %30
  %82 = fmul fast float %80, %31
  %83 = call float @dx.op.unary.f32(i32 26, float %81)  ; Round_ne(value)
  %84 = call float @dx.op.unary.f32(i32 26, float %82)  ; Round_ne(value)
  %85 = fptosi float %83 to i32
  %86 = fptosi float %84 to i32
  %87 = fmul fast float %79, %32
  %88 = fmul fast float %80, %33
  %89 = call float @dx.op.unary.f32(i32 26, float %87)  ; Round_ne(value)
  %90 = call float @dx.op.unary.f32(i32 26, float %88)  ; Round_ne(value)
  %91 = fptosi float %89 to i32
  %92 = fptosi float %90 to i32
  %93 = icmp sgt i32 %91, 0
  %94 = icmp sgt i32 %92, 0
  %95 = and i1 %93, %94
  %96 = or i32 %86, %85
  %97 = icmp sgt i32 %96, -1
  %98 = and i1 %97, %95
  %99 = add i32 %91, %85
  %100 = add i32 %92, %86
  %101 = icmp sle i32 %99, %77
  %102 = icmp sle i32 %100, %78
  %103 = and i1 %101, %102
  %104 = and i1 %98, %103
  %105 = xor i1 %104, true
  br label %106

; <label>:106                                     ; preds = %74, %28
  %107 = phi i1 [ %105, %74 ], [ true, %28 ]
  %108 = phi i32 [ %85, %74 ], [ 0, %28 ]
  %109 = phi i32 [ %86, %74 ], [ 0, %28 ]
  %110 = phi i32 [ %91, %74 ], [ 0, %28 ]
  %111 = phi i32 [ %92, %74 ], [ 0, %28 ]
  %112 = mul nsw i32 %111, %110
  %113 = icmp uge i32 %19, %112
  %114 = or i1 %107, %113
  br i1 %114, label %134, label %115

; <label>:115                                     ; preds = %106
  %116 = urem i32 %19, %110
  %117 = udiv i32 %19, %110
  %118 = add i32 %116, %108
  %119 = add i32 %117, %109
  %120 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %5, i32 0, i32 %118, i32 %119, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %121 = extractvalue %dx.types.ResRet.f32 %120, 0
  %122 = extractvalue %dx.types.ResRet.f32 %120, 1
  %123 = extractvalue %dx.types.ResRet.f32 %120, 2
  %124 = extractvalue %dx.types.ResRet.f32 %120, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %20, i32 0, float %121, float %122, float %123, float %124, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %125 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %118, i32 %119, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %126 = extractvalue %dx.types.ResRet.f32 %125, 0
  %127 = extractvalue %dx.types.ResRet.f32 %125, 1
  %128 = extractvalue %dx.types.ResRet.f32 %125, 2
  %129 = extractvalue %dx.types.ResRet.f32 %125, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %21, i32 0, float %126, float %127, float %128, float %129, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %130 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %3, i32 0, i32 %118, i32 %119, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %131 = extractvalue %dx.types.ResRet.f32 %130, 3
  %132 = sitofp i32 %118 to float
  %133 = sitofp i32 %119 to float
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %22, i32 0, float %131, float %132, float %133, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %134

; <label>:134                                     ; preds = %115, %106, %15, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i32) #1

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

; Function Attrs: nounwind
declare void @dx.op.bufferStore.f32(i32, %dx.types.Handle, i32, i32, float, float, float, float, i8) #2

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32, %dx.types.Handle, i32, i32) #1

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
!dx.entryPoints = !{!18}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !13, !16, null}
!5 = !{!6, !8, !10, !11, !12}
!6 = !{i32 0, %"hostlayout.class.StructuredBuffer<HLGISurfaceCard>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 128}
!8 = !{i32 1, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 1, i32 1, i32 2, i32 0, !9}
!9 = !{i32 0, i32 9}
!10 = !{i32 2, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 2, i32 1, i32 2, i32 0, !9}
!11 = !{i32 3, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 3, i32 1, i32 2, i32 0, !9}
!12 = !{i32 4, %"class.StructuredBuffer<vector<unsigned int, 2> >"* undef, !"", i32 0, i32 4, i32 1, i32 12, i32 0, !2}
!13 = !{!14}
!14 = !{i32 0, %"class.RWStructuredBuffer<vector<float, 4> >"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !15}
!15 = !{i32 1, i32 16}
!16 = !{!17}
!17 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2332, null}
!18 = !{void ()* @CSReferenceAtlas, !"CSReferenceAtlas", null, !4, !19}
!19 = !{i32 0, i64 16, i32 4, !20}
!20 = !{i32 64, i32 1, i32 1}
