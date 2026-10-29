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
; shader hash: b6f2260a8f7d40e56373f404f81af331
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
; EntryFunctionName: CSReferenceGatherInputs
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
; Resource bind info for _ReferencePixels
; {
;
;   uint2 $Element;                                   ; Offset:    0 Size:     8
;
; }
;
; Resource bind info for _ReferenceGatherRows
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
; sampler_PointClamp                sampler      NA          NA      S0             s0     1
; _HLGI_Depth                       texture     f32          2d      T0             t0     1
; _HLGI_Normals                     texture     f32          2d      T1             t1     1
; _ReferencePixels                  texture  struct         r/o      T2             t2     1
; _ReferenceGatherRows                  UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%dx.types.ResRet.i32 = type { i32, i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.Texture2D<float>" = type { float, %"class.Texture2D<float>::mips_type" }
%"class.Texture2D<float>::mips_type" = type { i32 }
%"class.Texture2D<vector<float, 4> >" = type { <4 x float>, %"class.Texture2D<vector<float, 4> >::mips_type" }
%"class.Texture2D<vector<float, 4> >::mips_type" = type { i32 }
%"class.StructuredBuffer<vector<unsigned int, 2> >" = type { <2 x i32> }
%"class.RWStructuredBuffer<vector<float, 4> >" = type { <4 x float> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32, float, float, float, float, float, i32, i32, i32, i32, i32, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], i32, i32, i32 }
%struct.SamplerState = type { i32 }

define void @CSReferenceGatherInputs() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %8 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %9 = extractvalue %dx.types.CBufRet.i32 %8, 2
  %10 = icmp ult i32 %7, %9
  br i1 %10, label %11, label %895

; <label>:11                                      ; preds = %0
  %12 = mul i32 %7, 48
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %12, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %13 = or i32 %12, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %13, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %14 = or i32 %12, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %14, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %15 = or i32 %12, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %15, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %16 = or i32 %12, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %16, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %17 = or i32 %12, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %17, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %18 = or i32 %12, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %18, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %19 = or i32 %12, 7
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %19, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %20 = or i32 %12, 8
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %20, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %21 = or i32 %12, 9
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %21, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %22 = or i32 %12, 10
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %22, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %23 = or i32 %12, 11
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %23, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %24 = or i32 %12, 12
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %24, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %25 = or i32 %12, 13
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %25, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %26 = or i32 %12, 14
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %26, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %27 = or i32 %12, 15
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %27, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %28 = add i32 %12, 16
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %28, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %29 = add i32 %12, 17
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %29, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %30 = add i32 %12, 18
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %30, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %31 = add i32 %12, 19
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %31, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %32 = add i32 %12, 20
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %32, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %33 = add i32 %12, 21
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %33, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %34 = add i32 %12, 22
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %34, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %35 = add i32 %12, 23
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %35, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %36 = add i32 %12, 24
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %36, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %37 = add i32 %12, 25
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %37, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %38 = add i32 %12, 26
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %38, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %39 = add i32 %12, 27
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %39, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %40 = add i32 %12, 28
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %40, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %41 = add i32 %12, 29
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %41, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %42 = add i32 %12, 30
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %42, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %43 = add i32 %12, 31
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %43, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %44 = add i32 %12, 32
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %44, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %45 = add i32 %12, 33
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %45, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %46 = add i32 %12, 34
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %46, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %47 = add i32 %12, 35
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %47, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %48 = add i32 %12, 36
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %48, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %49 = add i32 %12, 37
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %49, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %50 = add i32 %12, 38
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %50, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %51 = add i32 %12, 39
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %51, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %52 = add i32 %12, 40
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %52, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %53 = add i32 %12, 41
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %53, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %54 = add i32 %12, 42
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %54, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %55 = add i32 %12, 43
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %55, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %56 = add i32 %12, 44
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %56, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %57 = add i32 %12, 45
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %57, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %58 = add i32 %12, 46
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %58, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %59 = add i32 %12, 47
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %59, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %60 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %61 = extractvalue %dx.types.CBufRet.i32 %60, 1
  %62 = icmp ne i32 %61, 8
  %63 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %64 = extractvalue %dx.types.CBufRet.f32 %63, 2
  %65 = fcmp fast une float %64, 0.000000e+00
  %66 = or i1 %62, %65
  br i1 %66, label %895, label %67

; <label>:67                                      ; preds = %11
  %68 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %2, i32 %7, i32 0)  ; BufferLoad(srv,index,wot)
  %69 = extractvalue %dx.types.ResRet.i32 %68, 0
  %70 = extractvalue %dx.types.ResRet.i32 %68, 1
  %71 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 135)  ; CBufferLoadLegacy(handle,regIndex)
  %72 = extractvalue %dx.types.CBufRet.f32 %71, 0
  %73 = extractvalue %dx.types.CBufRet.f32 %71, 1
  %74 = fptoui float %72 to i32
  %75 = fptoui float %73 to i32
  %76 = icmp uge i32 %69, %74
  %77 = icmp uge i32 %70, %75
  %78 = or i1 %76, %77
  br i1 %78, label %895, label %79

; <label>:79                                      ; preds = %67
  %80 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 136)  ; CBufferLoadLegacy(handle,regIndex)
  %81 = extractvalue %dx.types.CBufRet.f32 %80, 0
  %82 = extractvalue %dx.types.CBufRet.f32 %80, 1
  %83 = fptoui float %81 to i32
  %84 = fptoui float %82 to i32
  %85 = shl i32 %69, 1
  %86 = shl i32 %70, 1
  %87 = or i32 %85, 1
  %88 = or i32 %86, 1
  %89 = mul i32 %83, %87
  %90 = mul i32 %84, %88
  %91 = shl i32 %74, 1
  %92 = shl i32 %75, 1
  %93 = udiv i32 %89, %91
  %94 = udiv i32 %90, %92
  %95 = uitofp i32 %93 to float
  %96 = uitofp i32 %94 to float
  %97 = fadd fast float %95, 5.000000e-01
  %98 = fadd fast float %96, 5.000000e-01
  %99 = uitofp i32 %83 to float
  %100 = uitofp i32 %84 to float
  %101 = fdiv fast float %97, %99
  %102 = fdiv fast float %98, %100
  %103 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %93, i32 %94, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %104 = extractvalue %dx.types.ResRet.f32 %103, 0
  %105 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %104)  ; IsFinite(value)
  %106 = xor i1 %105, true
  %107 = fcmp ule float %104, 0x3EB0C6F7A0000000
  %108 = or i1 %107, %106
  br i1 %108, label %895, label %109

; <label>:109                                     ; preds = %79
  %110 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 137)  ; CBufferLoadLegacy(handle,regIndex)
  %111 = extractvalue %dx.types.CBufRet.f32 %110, 0
  %112 = extractvalue %dx.types.CBufRet.f32 %110, 1
  %113 = extractvalue %dx.types.CBufRet.f32 %110, 2
  %114 = extractvalue %dx.types.CBufRet.f32 %110, 3
  %115 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 138)  ; CBufferLoadLegacy(handle,regIndex)
  %116 = extractvalue %dx.types.CBufRet.f32 %115, 0
  %117 = extractvalue %dx.types.CBufRet.f32 %115, 1
  %118 = extractvalue %dx.types.CBufRet.f32 %115, 2
  %119 = extractvalue %dx.types.CBufRet.f32 %115, 3
  %120 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %121 = extractvalue %dx.types.CBufRet.f32 %120, 0
  %122 = extractvalue %dx.types.CBufRet.f32 %120, 1
  %123 = extractvalue %dx.types.CBufRet.f32 %120, 2
  %124 = extractvalue %dx.types.CBufRet.f32 %120, 3
  %125 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 140)  ; CBufferLoadLegacy(handle,regIndex)
  %126 = extractvalue %dx.types.CBufRet.f32 %125, 0
  %127 = extractvalue %dx.types.CBufRet.f32 %125, 1
  %128 = extractvalue %dx.types.CBufRet.f32 %125, 2
  %129 = extractvalue %dx.types.CBufRet.f32 %125, 3
  %130 = fmul fast float %101, 2.000000e+00
  %131 = fmul fast float %102, 2.000000e+00
  %132 = fadd fast float %130, -1.000000e+00
  %133 = fadd fast float %131, -1.000000e+00
  %134 = fsub fast float -0.000000e+00, %133
  %135 = fmul fast float %111, %132
  %136 = call float @dx.op.tertiary.f32(i32 46, float %116, float %134, float %135)  ; FMad(a,b,c)
  %137 = call float @dx.op.tertiary.f32(i32 46, float %121, float %104, float %136)  ; FMad(a,b,c)
  %138 = fadd fast float %137, %126
  %139 = fmul fast float %112, %132
  %140 = call float @dx.op.tertiary.f32(i32 46, float %117, float %134, float %139)  ; FMad(a,b,c)
  %141 = call float @dx.op.tertiary.f32(i32 46, float %122, float %104, float %140)  ; FMad(a,b,c)
  %142 = fadd fast float %141, %127
  %143 = fmul fast float %113, %132
  %144 = call float @dx.op.tertiary.f32(i32 46, float %118, float %134, float %143)  ; FMad(a,b,c)
  %145 = call float @dx.op.tertiary.f32(i32 46, float %123, float %104, float %144)  ; FMad(a,b,c)
  %146 = fadd fast float %145, %128
  %147 = fmul fast float %114, %132
  %148 = call float @dx.op.tertiary.f32(i32 46, float %119, float %134, float %147)  ; FMad(a,b,c)
  %149 = call float @dx.op.tertiary.f32(i32 46, float %124, float %104, float %148)  ; FMad(a,b,c)
  %150 = fadd fast float %149, %129
  %151 = fdiv fast float %138, %150
  %152 = fdiv fast float %142, %150
  %153 = fdiv fast float %146, %150
  %154 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %3, %dx.types.Handle %5, float %101, float %102, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %155 = extractvalue %dx.types.ResRet.f32 %154, 0
  %156 = extractvalue %dx.types.ResRet.f32 %154, 1
  %157 = extractvalue %dx.types.ResRet.f32 %154, 2
  %158 = extractvalue %dx.types.CBufRet.i32 %60, 0
  %159 = icmp eq i32 %158, 0
  br i1 %159, label %201, label %160

; <label>:160                                     ; preds = %109
  %161 = fmul fast float %155, 2.555000e+02
  %162 = fmul fast float %156, 2.555000e+02
  %163 = fmul fast float %157, 2.555000e+02
  %164 = fptoui float %161 to i32
  %165 = fptoui float %162 to i32
  %166 = fptoui float %163 to i32
  %167 = lshr i32 %166, 4
  %168 = shl i32 %166, 8
  %169 = and i32 %168, 3840
  %170 = shl i32 %167, 8
  %171 = or i32 %169, %164
  %172 = or i32 %170, %165
  %173 = uitofp i32 %171 to float
  %174 = uitofp i32 %172 to float
  %175 = fmul fast float %173, 0x3F40010020000000
  %176 = fmul fast float %174, 0x3F40010020000000
  %177 = fadd fast float %175, -1.000000e+00
  %178 = fadd fast float %176, -1.000000e+00
  %179 = fcmp fast olt float %177, 0.000000e+00
  %180 = fsub fast float -0.000000e+00, %177
  %181 = select i1 %179, float %180, float %177
  %182 = fsub fast float 1.000000e+00, %181
  %183 = fcmp fast olt float %178, 0.000000e+00
  %184 = fsub fast float -0.000000e+00, %178
  %185 = select i1 %183, float %184, float %178
  %186 = fsub fast float %182, %185
  %187 = fsub fast float -0.000000e+00, %186
  %188 = call float @dx.op.binary.f32(i32 35, float %187, float 0.000000e+00)  ; FMax(a,b)
  %189 = fcmp fast oge float %177, 0.000000e+00
  %190 = fsub fast float -0.000000e+00, %188
  %191 = select i1 %189, float %190, float %188
  %192 = fcmp fast oge float %178, 0.000000e+00
  %193 = select i1 %192, float %190, float %188
  %194 = fadd fast float %191, %177
  %195 = fadd fast float %193, %178
  %196 = call float @dx.op.dot3.f32(i32 55, float %194, float %195, float %186, float %194, float %195, float %186)  ; Dot3(ax,ay,az,bx,by,bz)
  %197 = call float @dx.op.unary.f32(i32 25, float %196)  ; Rsqrt(value)
  %198 = fmul fast float %194, %197
  %199 = fmul fast float %195, %197
  %200 = fmul fast float %197, %186
  br label %201

; <label>:201                                     ; preds = %160, %109
  %202 = phi float [ %198, %160 ], [ %155, %109 ]
  %203 = phi float [ %199, %160 ], [ %156, %109 ]
  %204 = phi float [ %200, %160 ], [ %157, %109 ]
  %205 = call float @dx.op.dot3.f32(i32 55, float %202, float %203, float %204, float %202, float %203, float %204)  ; Dot3(ax,ay,az,bx,by,bz)
  %206 = fcmp fast ogt float %205, 0x3F847AE140000000
  %207 = call float @dx.op.unary.f32(i32 25, float %205)  ; Rsqrt(value)
  %208 = fmul fast float %207, %202
  %209 = fmul fast float %207, %203
  %210 = fmul fast float %207, %204
  %211 = select i1 %206, float %208, float 0.000000e+00
  %212 = select i1 %206, float %209, float 1.000000e+00
  %213 = select i1 %206, float %210, float 0.000000e+00
  %214 = fcmp fast olt float %104, 0.000000e+00
  %215 = fcmp fast ogt float %104, 1.000000e+00
  %216 = or i1 %215, %214
  %217 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %151)  ; IsFinite(value)
  %218 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %152)  ; IsFinite(value)
  %219 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %153)  ; IsFinite(value)
  %220 = and i1 %217, %218
  %221 = and i1 %220, %219
  %222 = xor i1 %221, true
  %223 = or i1 %216, %222
  br i1 %223, label %757, label %224

; <label>:224                                     ; preds = %201
  %225 = fmul fast float %101, %81
  %226 = fmul fast float %102, %82
  %227 = call float @dx.op.unary.f32(i32 27, float %225)  ; Round_ni(value)
  %228 = call float @dx.op.unary.f32(i32 27, float %226)  ; Round_ni(value)
  %229 = fptosi float %227 to i32
  %230 = fptosi float %228 to i32
  %231 = or i32 %230, %229
  %232 = icmp slt i32 %231, 0
  %233 = fptosi float %81 to i32
  %234 = fptosi float %82 to i32
  %235 = icmp sge i32 %229, %233
  %236 = icmp sge i32 %230, %234
  %237 = or i1 %235, %236
  %238 = or i1 %232, %237
  br i1 %238, label %757, label %239

; <label>:239                                     ; preds = %224
  %240 = add i32 %229, -1
  %241 = add i32 %229, -2
  %242 = icmp sge i32 %240, %233
  %243 = or i32 %241, %230
  %244 = or i32 %243, %240
  %245 = icmp slt i32 %244, 0
  %246 = or i1 %242, %245
  %247 = icmp sge i32 %241, %233
  %248 = or i1 %247, %246
  br i1 %248, label %285, label %249

; <label>:249                                     ; preds = %239
  %250 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %240, i32 %230, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %251 = extractvalue %dx.types.ResRet.f32 %250, 0
  %252 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %241, i32 %230, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %253 = extractvalue %dx.types.ResRet.f32 %252, 0
  %254 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %251)  ; IsFinite(value)
  %255 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %253)  ; IsFinite(value)
  %256 = and i1 %254, %255
  %257 = xor i1 %256, true
  %258 = fcmp fast olt float %251, 0.000000e+00
  %259 = or i1 %258, %257
  %260 = fcmp fast ogt float %251, 1.000000e+00
  %261 = or i1 %260, %259
  %262 = fcmp fast olt float %253, 0.000000e+00
  %263 = or i1 %262, %261
  %264 = fcmp fast ogt float %253, 1.000000e+00
  %265 = or i1 %264, %263
  %266 = fcmp ule float %251, 0x3EB0C6F7A0000000
  %267 = or i1 %266, %265
  %268 = fcmp ule float %253, 0x3EB0C6F7A0000000
  %269 = or i1 %268, %267
  br i1 %269, label %285, label %270

; <label>:270                                     ; preds = %249
  %271 = fmul fast float %251, 2.000000e+00
  %272 = fsub fast float %271, %253
  %273 = fsub fast float %272, %104
  %274 = call float @dx.op.unary.f32(i32 6, float %273)  ; FAbs(value)
  %275 = fcmp fast olt float %272, 0.000000e+00
  %276 = fcmp fast ogt float %272, 1.000000e+00
  %277 = or i1 %275, %276
  %278 = fcmp fast oge float %274, 0x4415AF1D80000000
  %279 = or i1 %277, %278
  %280 = select i1 %279, float 0x4415AF1D80000000, float %274
  %281 = select i1 %279, float 0.000000e+00, float %251
  %282 = select i1 %279, float 0.000000e+00, float %272
  %283 = xor i1 %279, true
  %284 = sext i1 %283 to i32
  br label %285

; <label>:285                                     ; preds = %270, %249, %239
  %286 = phi float [ 0x4415AF1D80000000, %239 ], [ 0x4415AF1D80000000, %249 ], [ %280, %270 ]
  %287 = phi float [ 0.000000e+00, %239 ], [ 0.000000e+00, %249 ], [ %281, %270 ]
  %288 = phi float [ 0.000000e+00, %239 ], [ 0.000000e+00, %249 ], [ %282, %270 ]
  %289 = phi i32 [ 0, %239 ], [ 0, %249 ], [ %284, %270 ]
  %290 = add i32 %229, 1
  %291 = add i32 %229, 2
  %292 = icmp sge i32 %290, %233
  %293 = or i32 %291, %230
  %294 = or i32 %293, %290
  %295 = icmp slt i32 %294, 0
  %296 = or i1 %292, %295
  %297 = icmp sge i32 %291, %233
  %298 = or i1 %297, %296
  br i1 %298, label %333, label %299

; <label>:299                                     ; preds = %285
  %300 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %290, i32 %230, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %301 = extractvalue %dx.types.ResRet.f32 %300, 0
  %302 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %291, i32 %230, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %303 = extractvalue %dx.types.ResRet.f32 %302, 0
  %304 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %301)  ; IsFinite(value)
  %305 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %303)  ; IsFinite(value)
  %306 = and i1 %304, %305
  %307 = xor i1 %306, true
  %308 = fcmp fast olt float %301, 0.000000e+00
  %309 = or i1 %308, %307
  %310 = fcmp fast ogt float %301, 1.000000e+00
  %311 = or i1 %310, %309
  %312 = fcmp fast olt float %303, 0.000000e+00
  %313 = or i1 %312, %311
  %314 = fcmp fast ogt float %303, 1.000000e+00
  %315 = or i1 %314, %313
  %316 = fcmp ule float %301, 0x3EB0C6F7A0000000
  %317 = or i1 %316, %315
  %318 = fcmp ule float %303, 0x3EB0C6F7A0000000
  %319 = or i1 %318, %317
  br i1 %319, label %333, label %320

; <label>:320                                     ; preds = %299
  %321 = fmul fast float %301, 2.000000e+00
  %322 = fsub fast float %321, %303
  %323 = fsub fast float %322, %104
  %324 = call float @dx.op.unary.f32(i32 6, float %323)  ; FAbs(value)
  %325 = fcmp fast olt float %322, 0.000000e+00
  %326 = fcmp fast ogt float %322, 1.000000e+00
  %327 = or i1 %325, %326
  %328 = fcmp fast oge float %324, %286
  %329 = or i1 %327, %328
  %330 = select i1 %329, float %287, float %301
  %331 = select i1 %329, float %288, float %322
  %332 = select i1 %329, i32 %289, i32 1
  br label %333

; <label>:333                                     ; preds = %320, %299, %285
  %334 = phi float [ %287, %285 ], [ %287, %299 ], [ %330, %320 ]
  %335 = phi float [ %288, %285 ], [ %288, %299 ], [ %331, %320 ]
  %336 = phi i32 [ %289, %285 ], [ %289, %299 ], [ %332, %320 ]
  %337 = icmp eq i32 %336, 0
  br i1 %337, label %444, label %338

; <label>:338                                     ; preds = %333
  %339 = uitofp i32 %229 to float
  %340 = uitofp i32 %230 to float
  %341 = fadd fast float %339, 5.000000e-01
  %342 = fadd fast float %340, 5.000000e-01
  %343 = fdiv fast float %341, %99
  %344 = fdiv fast float %342, %100
  %345 = fmul fast float %343, 2.000000e+00
  %346 = fmul fast float %344, 2.000000e+00
  %347 = fadd fast float %345, -1.000000e+00
  %348 = fadd fast float %346, -1.000000e+00
  %349 = fsub fast float -0.000000e+00, %348
  %350 = fmul fast float %347, %111
  %351 = call float @dx.op.tertiary.f32(i32 46, float %116, float %349, float %350)  ; FMad(a,b,c)
  %352 = call float @dx.op.tertiary.f32(i32 46, float %121, float %335, float %351)  ; FMad(a,b,c)
  %353 = fadd fast float %352, %126
  %354 = fmul fast float %347, %112
  %355 = call float @dx.op.tertiary.f32(i32 46, float %117, float %349, float %354)  ; FMad(a,b,c)
  %356 = call float @dx.op.tertiary.f32(i32 46, float %122, float %335, float %355)  ; FMad(a,b,c)
  %357 = fadd fast float %356, %127
  %358 = fmul fast float %347, %113
  %359 = call float @dx.op.tertiary.f32(i32 46, float %118, float %349, float %358)  ; FMad(a,b,c)
  %360 = call float @dx.op.tertiary.f32(i32 46, float %123, float %335, float %359)  ; FMad(a,b,c)
  %361 = fadd fast float %360, %128
  %362 = fmul fast float %347, %114
  %363 = call float @dx.op.tertiary.f32(i32 46, float %119, float %349, float %362)  ; FMad(a,b,c)
  %364 = call float @dx.op.tertiary.f32(i32 46, float %124, float %335, float %363)  ; FMad(a,b,c)
  %365 = fadd fast float %364, %129
  %366 = fdiv fast float %353, %365
  %367 = fdiv fast float %357, %365
  %368 = fdiv fast float %361, %365
  %369 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %370 = extractvalue %dx.types.CBufRet.f32 %369, 2
  %371 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 142)  ; CBufferLoadLegacy(handle,regIndex)
  %372 = extractvalue %dx.types.CBufRet.f32 %371, 2
  %373 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 143)  ; CBufferLoadLegacy(handle,regIndex)
  %374 = extractvalue %dx.types.CBufRet.f32 %373, 2
  %375 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 144)  ; CBufferLoadLegacy(handle,regIndex)
  %376 = extractvalue %dx.types.CBufRet.f32 %375, 2
  %377 = fmul fast float %370, %151
  %378 = call float @dx.op.tertiary.f32(i32 46, float %372, float %152, float %377)  ; FMad(a,b,c)
  %379 = call float @dx.op.tertiary.f32(i32 46, float %374, float %153, float %378)  ; FMad(a,b,c)
  %380 = fadd fast float %379, %376
  %381 = call float @dx.op.unary.f32(i32 6, float %380)  ; FAbs(value)
  %382 = fmul fast float %381, 0x3F1A36E2E0000000
  %383 = call float @dx.op.binary.f32(i32 35, float 0x3F60624DE0000000, float %382)  ; FMax(a,b)
  %384 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %366)  ; IsFinite(value)
  %385 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %367)  ; IsFinite(value)
  %386 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %368)  ; IsFinite(value)
  %387 = and i1 %384, %385
  %388 = and i1 %387, %386
  %389 = xor i1 %388, true
  %390 = fsub fast float %366, %151
  %391 = fsub fast float %367, %152
  %392 = fsub fast float %368, %153
  %393 = fmul fast float %390, %390
  %394 = fmul fast float %391, %391
  %395 = fadd fast float %394, %393
  %396 = fmul fast float %392, %392
  %397 = fadd fast float %395, %396
  %398 = call float @dx.op.unary.f32(i32 24, float %397)  ; Sqrt(value)
  %399 = fcmp fast ogt float %398, %383
  %400 = or i1 %399, %389
  br i1 %400, label %444, label %401

; <label>:401                                     ; preds = %338
  %402 = add i32 %336, %229
  %403 = uitofp i32 %402 to float
  %404 = fadd fast float %403, 5.000000e-01
  %405 = fdiv fast float %404, %99
  %406 = fmul fast float %405, 2.000000e+00
  %407 = fadd fast float %406, -1.000000e+00
  %408 = fmul fast float %407, %111
  %409 = call float @dx.op.tertiary.f32(i32 46, float %116, float %349, float %408)  ; FMad(a,b,c)
  %410 = call float @dx.op.tertiary.f32(i32 46, float %121, float %334, float %409)  ; FMad(a,b,c)
  %411 = fadd fast float %410, %126
  %412 = fmul fast float %407, %112
  %413 = call float @dx.op.tertiary.f32(i32 46, float %117, float %349, float %412)  ; FMad(a,b,c)
  %414 = call float @dx.op.tertiary.f32(i32 46, float %122, float %334, float %413)  ; FMad(a,b,c)
  %415 = fadd fast float %414, %127
  %416 = fmul fast float %407, %113
  %417 = call float @dx.op.tertiary.f32(i32 46, float %118, float %349, float %416)  ; FMad(a,b,c)
  %418 = call float @dx.op.tertiary.f32(i32 46, float %123, float %334, float %417)  ; FMad(a,b,c)
  %419 = fadd fast float %418, %128
  %420 = fmul fast float %407, %114
  %421 = call float @dx.op.tertiary.f32(i32 46, float %119, float %349, float %420)  ; FMad(a,b,c)
  %422 = call float @dx.op.tertiary.f32(i32 46, float %124, float %334, float %421)  ; FMad(a,b,c)
  %423 = fadd fast float %422, %129
  %424 = fdiv fast float %411, %423
  %425 = fdiv fast float %415, %423
  %426 = fdiv fast float %419, %423
  %427 = fsub fast float %424, %151
  %428 = fsub fast float %425, %152
  %429 = fsub fast float %426, %153
  %430 = sitofp i32 %336 to float
  %431 = fmul fast float %427, %430
  %432 = fmul fast float %428, %430
  %433 = fmul fast float %429, %430
  %434 = call float @dx.op.dot3.f32(i32 55, float %431, float %432, float %433, float %431, float %432, float %433)  ; Dot3(ax,ay,az,bx,by,bz)
  %435 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %431)  ; IsFinite(value)
  %436 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %432)  ; IsFinite(value)
  %437 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %433)  ; IsFinite(value)
  %438 = and i1 %435, %436
  %439 = and i1 %438, %437
  %440 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %434)  ; IsFinite(value)
  %441 = and i1 %439, %440
  %442 = fcmp uge float %434, 0x3C9CD2B2A0000000
  %443 = and i1 %442, %441
  br label %444

; <label>:444                                     ; preds = %401, %338, %333
  %445 = phi float [ 0.000000e+00, %333 ], [ 0.000000e+00, %338 ], [ %431, %401 ]
  %446 = phi float [ 0.000000e+00, %333 ], [ 0.000000e+00, %338 ], [ %432, %401 ]
  %447 = phi float [ 0.000000e+00, %333 ], [ 0.000000e+00, %338 ], [ %433, %401 ]
  %448 = phi i1 [ false, %333 ], [ false, %338 ], [ %443, %401 ]
  br i1 %448, label %449, label %455

; <label>:449                                     ; preds = %444
  %450 = call float @dx.op.dot3.f32(i32 55, float %445, float %446, float %447, float %445, float %446, float %447)  ; Dot3(ax,ay,az,bx,by,bz)
  %451 = call float @dx.op.unary.f32(i32 25, float %450)  ; Rsqrt(value)
  %452 = fmul fast float %451, %445
  %453 = fmul fast float %451, %446
  %454 = fmul fast float %451, %447
  br label %455

; <label>:455                                     ; preds = %449, %444
  %456 = phi float [ %452, %449 ], [ %445, %444 ]
  %457 = phi float [ %453, %449 ], [ %446, %444 ]
  %458 = phi float [ %454, %449 ], [ %447, %444 ]
  %459 = phi i1 [ false, %449 ], [ true, %444 ]
  %460 = add i32 %230, -1
  %461 = add i32 %230, -2
  %462 = or i32 %460, %229
  %463 = icmp sge i32 %460, %234
  %464 = or i32 %462, %461
  %465 = icmp slt i32 %464, 0
  %466 = or i1 %463, %465
  %467 = icmp sge i32 %461, %234
  %468 = or i1 %467, %466
  br i1 %468, label %505, label %469

; <label>:469                                     ; preds = %455
  %470 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %229, i32 %460, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %471 = extractvalue %dx.types.ResRet.f32 %470, 0
  %472 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %229, i32 %461, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %473 = extractvalue %dx.types.ResRet.f32 %472, 0
  %474 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %471)  ; IsFinite(value)
  %475 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %473)  ; IsFinite(value)
  %476 = and i1 %474, %475
  %477 = xor i1 %476, true
  %478 = fcmp fast olt float %471, 0.000000e+00
  %479 = or i1 %478, %477
  %480 = fcmp fast ogt float %471, 1.000000e+00
  %481 = or i1 %480, %479
  %482 = fcmp fast olt float %473, 0.000000e+00
  %483 = or i1 %482, %481
  %484 = fcmp fast ogt float %473, 1.000000e+00
  %485 = or i1 %484, %483
  %486 = fcmp ule float %471, 0x3EB0C6F7A0000000
  %487 = or i1 %486, %485
  %488 = fcmp ule float %473, 0x3EB0C6F7A0000000
  %489 = or i1 %488, %487
  br i1 %489, label %505, label %490

; <label>:490                                     ; preds = %469
  %491 = fmul fast float %471, 2.000000e+00
  %492 = fsub fast float %491, %473
  %493 = fsub fast float %492, %104
  %494 = call float @dx.op.unary.f32(i32 6, float %493)  ; FAbs(value)
  %495 = fcmp fast olt float %492, 0.000000e+00
  %496 = fcmp fast ogt float %492, 1.000000e+00
  %497 = or i1 %495, %496
  %498 = fcmp fast oge float %494, 0x4415AF1D80000000
  %499 = or i1 %497, %498
  %500 = select i1 %499, float 0x4415AF1D80000000, float %494
  %501 = select i1 %499, float 0.000000e+00, float %471
  %502 = select i1 %499, float 0.000000e+00, float %492
  %503 = xor i1 %499, true
  %504 = sext i1 %503 to i32
  br label %505

; <label>:505                                     ; preds = %490, %469, %455
  %506 = phi float [ 0x4415AF1D80000000, %455 ], [ 0x4415AF1D80000000, %469 ], [ %500, %490 ]
  %507 = phi float [ 0.000000e+00, %455 ], [ 0.000000e+00, %469 ], [ %501, %490 ]
  %508 = phi float [ 0.000000e+00, %455 ], [ 0.000000e+00, %469 ], [ %502, %490 ]
  %509 = phi i32 [ 0, %455 ], [ 0, %469 ], [ %504, %490 ]
  %510 = add i32 %230, 1
  %511 = add i32 %230, 2
  %512 = or i32 %510, %229
  %513 = icmp sge i32 %510, %234
  %514 = or i32 %512, %511
  %515 = icmp slt i32 %514, 0
  %516 = or i1 %513, %515
  %517 = icmp sge i32 %511, %234
  %518 = or i1 %517, %516
  br i1 %518, label %553, label %519

; <label>:519                                     ; preds = %505
  %520 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %229, i32 %510, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %521 = extractvalue %dx.types.ResRet.f32 %520, 0
  %522 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %229, i32 %511, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %523 = extractvalue %dx.types.ResRet.f32 %522, 0
  %524 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %521)  ; IsFinite(value)
  %525 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %523)  ; IsFinite(value)
  %526 = and i1 %524, %525
  %527 = xor i1 %526, true
  %528 = fcmp fast olt float %521, 0.000000e+00
  %529 = or i1 %528, %527
  %530 = fcmp fast ogt float %521, 1.000000e+00
  %531 = or i1 %530, %529
  %532 = fcmp fast olt float %523, 0.000000e+00
  %533 = or i1 %532, %531
  %534 = fcmp fast ogt float %523, 1.000000e+00
  %535 = or i1 %534, %533
  %536 = fcmp ule float %521, 0x3EB0C6F7A0000000
  %537 = or i1 %536, %535
  %538 = fcmp ule float %523, 0x3EB0C6F7A0000000
  %539 = or i1 %538, %537
  br i1 %539, label %553, label %540

; <label>:540                                     ; preds = %519
  %541 = fmul fast float %521, 2.000000e+00
  %542 = fsub fast float %541, %523
  %543 = fsub fast float %542, %104
  %544 = call float @dx.op.unary.f32(i32 6, float %543)  ; FAbs(value)
  %545 = fcmp fast olt float %542, 0.000000e+00
  %546 = fcmp fast ogt float %542, 1.000000e+00
  %547 = or i1 %545, %546
  %548 = fcmp fast oge float %544, %506
  %549 = or i1 %547, %548
  %550 = select i1 %549, float %507, float %521
  %551 = select i1 %549, float %508, float %542
  %552 = select i1 %549, i32 %509, i32 1
  br label %553

; <label>:553                                     ; preds = %540, %519, %505
  %554 = phi float [ %507, %505 ], [ %507, %519 ], [ %550, %540 ]
  %555 = phi float [ %508, %505 ], [ %508, %519 ], [ %551, %540 ]
  %556 = phi i32 [ %509, %505 ], [ %509, %519 ], [ %552, %540 ]
  %557 = icmp eq i32 %556, 0
  br i1 %557, label %661, label %558

; <label>:558                                     ; preds = %553
  %559 = uitofp i32 %229 to float
  %560 = uitofp i32 %230 to float
  %561 = fadd fast float %559, 5.000000e-01
  %562 = fadd fast float %560, 5.000000e-01
  %563 = fdiv fast float %561, %99
  %564 = fdiv fast float %562, %100
  %565 = fmul fast float %563, 2.000000e+00
  %566 = fmul fast float %564, 2.000000e+00
  %567 = fadd fast float %565, -1.000000e+00
  %568 = fadd fast float %566, -1.000000e+00
  %569 = fsub fast float -0.000000e+00, %568
  %570 = fmul fast float %567, %111
  %571 = call float @dx.op.tertiary.f32(i32 46, float %116, float %569, float %570)  ; FMad(a,b,c)
  %572 = call float @dx.op.tertiary.f32(i32 46, float %121, float %555, float %571)  ; FMad(a,b,c)
  %573 = fadd fast float %572, %126
  %574 = fmul fast float %567, %112
  %575 = call float @dx.op.tertiary.f32(i32 46, float %117, float %569, float %574)  ; FMad(a,b,c)
  %576 = call float @dx.op.tertiary.f32(i32 46, float %122, float %555, float %575)  ; FMad(a,b,c)
  %577 = fadd fast float %576, %127
  %578 = fmul fast float %567, %113
  %579 = call float @dx.op.tertiary.f32(i32 46, float %118, float %569, float %578)  ; FMad(a,b,c)
  %580 = call float @dx.op.tertiary.f32(i32 46, float %123, float %555, float %579)  ; FMad(a,b,c)
  %581 = fadd fast float %580, %128
  %582 = fmul fast float %567, %114
  %583 = call float @dx.op.tertiary.f32(i32 46, float %119, float %569, float %582)  ; FMad(a,b,c)
  %584 = call float @dx.op.tertiary.f32(i32 46, float %124, float %555, float %583)  ; FMad(a,b,c)
  %585 = fadd fast float %584, %129
  %586 = fdiv fast float %573, %585
  %587 = fdiv fast float %577, %585
  %588 = fdiv fast float %581, %585
  %589 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %590 = extractvalue %dx.types.CBufRet.f32 %589, 2
  %591 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 142)  ; CBufferLoadLegacy(handle,regIndex)
  %592 = extractvalue %dx.types.CBufRet.f32 %591, 2
  %593 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 143)  ; CBufferLoadLegacy(handle,regIndex)
  %594 = extractvalue %dx.types.CBufRet.f32 %593, 2
  %595 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 144)  ; CBufferLoadLegacy(handle,regIndex)
  %596 = extractvalue %dx.types.CBufRet.f32 %595, 2
  %597 = fmul fast float %590, %151
  %598 = call float @dx.op.tertiary.f32(i32 46, float %592, float %152, float %597)  ; FMad(a,b,c)
  %599 = call float @dx.op.tertiary.f32(i32 46, float %594, float %153, float %598)  ; FMad(a,b,c)
  %600 = fadd fast float %599, %596
  %601 = call float @dx.op.unary.f32(i32 6, float %600)  ; FAbs(value)
  %602 = fmul fast float %601, 0x3F1A36E2E0000000
  %603 = call float @dx.op.binary.f32(i32 35, float 0x3F60624DE0000000, float %602)  ; FMax(a,b)
  %604 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %586)  ; IsFinite(value)
  %605 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %587)  ; IsFinite(value)
  %606 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %588)  ; IsFinite(value)
  %607 = and i1 %604, %605
  %608 = and i1 %607, %606
  %609 = xor i1 %608, true
  %610 = fsub fast float %586, %151
  %611 = fsub fast float %587, %152
  %612 = fsub fast float %588, %153
  %613 = fmul fast float %610, %610
  %614 = fmul fast float %611, %611
  %615 = fadd fast float %614, %613
  %616 = fmul fast float %612, %612
  %617 = fadd fast float %615, %616
  %618 = call float @dx.op.unary.f32(i32 24, float %617)  ; Sqrt(value)
  %619 = fcmp fast ogt float %618, %603
  %620 = or i1 %619, %609
  br i1 %620, label %661, label %621

; <label>:621                                     ; preds = %558
  %622 = add i32 %556, %230
  %623 = uitofp i32 %622 to float
  %624 = fadd fast float %623, 5.000000e-01
  %625 = fdiv fast float %624, %100
  %626 = fmul fast float %625, 2.000000e+00
  %627 = fadd fast float %626, -1.000000e+00
  %628 = fsub fast float -0.000000e+00, %627
  %629 = call float @dx.op.tertiary.f32(i32 46, float %116, float %628, float %570)  ; FMad(a,b,c)
  %630 = call float @dx.op.tertiary.f32(i32 46, float %121, float %554, float %629)  ; FMad(a,b,c)
  %631 = fadd fast float %630, %126
  %632 = call float @dx.op.tertiary.f32(i32 46, float %117, float %628, float %574)  ; FMad(a,b,c)
  %633 = call float @dx.op.tertiary.f32(i32 46, float %122, float %554, float %632)  ; FMad(a,b,c)
  %634 = fadd fast float %633, %127
  %635 = call float @dx.op.tertiary.f32(i32 46, float %118, float %628, float %578)  ; FMad(a,b,c)
  %636 = call float @dx.op.tertiary.f32(i32 46, float %123, float %554, float %635)  ; FMad(a,b,c)
  %637 = fadd fast float %636, %128
  %638 = call float @dx.op.tertiary.f32(i32 46, float %119, float %628, float %582)  ; FMad(a,b,c)
  %639 = call float @dx.op.tertiary.f32(i32 46, float %124, float %554, float %638)  ; FMad(a,b,c)
  %640 = fadd fast float %639, %129
  %641 = fdiv fast float %631, %640
  %642 = fdiv fast float %634, %640
  %643 = fdiv fast float %637, %640
  %644 = fsub fast float %641, %151
  %645 = fsub fast float %642, %152
  %646 = fsub fast float %643, %153
  %647 = sitofp i32 %556 to float
  %648 = fmul fast float %644, %647
  %649 = fmul fast float %645, %647
  %650 = fmul fast float %646, %647
  %651 = call float @dx.op.dot3.f32(i32 55, float %648, float %649, float %650, float %648, float %649, float %650)  ; Dot3(ax,ay,az,bx,by,bz)
  %652 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %648)  ; IsFinite(value)
  %653 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %649)  ; IsFinite(value)
  %654 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %650)  ; IsFinite(value)
  %655 = and i1 %652, %653
  %656 = and i1 %655, %654
  %657 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %651)  ; IsFinite(value)
  %658 = and i1 %656, %657
  %659 = fcmp uge float %651, 0x3C9CD2B2A0000000
  %660 = and i1 %659, %658
  br label %661

; <label>:661                                     ; preds = %621, %558, %553
  %662 = phi float [ 0.000000e+00, %553 ], [ 0.000000e+00, %558 ], [ %648, %621 ]
  %663 = phi float [ 0.000000e+00, %553 ], [ 0.000000e+00, %558 ], [ %649, %621 ]
  %664 = phi float [ 0.000000e+00, %553 ], [ 0.000000e+00, %558 ], [ %650, %621 ]
  %665 = phi i1 [ false, %553 ], [ false, %558 ], [ %660, %621 ]
  br i1 %665, label %666, label %672

; <label>:666                                     ; preds = %661
  %667 = call float @dx.op.dot3.f32(i32 55, float %662, float %663, float %664, float %662, float %663, float %664)  ; Dot3(ax,ay,az,bx,by,bz)
  %668 = call float @dx.op.unary.f32(i32 25, float %667)  ; Rsqrt(value)
  %669 = fmul fast float %668, %662
  %670 = fmul fast float %668, %663
  %671 = fmul fast float %668, %664
  br label %672

; <label>:672                                     ; preds = %666, %661
  %673 = phi float [ %669, %666 ], [ %662, %661 ]
  %674 = phi float [ %670, %666 ], [ %663, %661 ]
  %675 = phi float [ %671, %666 ], [ %664, %661 ]
  %676 = phi i1 [ false, %666 ], [ true, %661 ]
  %677 = or i1 %459, %676
  br i1 %677, label %757, label %678

; <label>:678                                     ; preds = %672
  %679 = fmul fast float %675, %457
  %680 = fmul fast float %674, %458
  %681 = fsub fast float %679, %680
  %682 = fmul fast float %673, %458
  %683 = fmul fast float %675, %456
  %684 = fsub fast float %682, %683
  %685 = fmul fast float %674, %456
  %686 = fmul fast float %673, %457
  %687 = fsub fast float %685, %686
  %688 = call float @dx.op.dot3.f32(i32 55, float %681, float %684, float %687, float %681, float %684, float %687)  ; Dot3(ax,ay,az,bx,by,bz)
  %689 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %681)  ; IsFinite(value)
  %690 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %684)  ; IsFinite(value)
  %691 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %687)  ; IsFinite(value)
  %692 = and i1 %689, %690
  %693 = and i1 %692, %691
  %694 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %688)  ; IsFinite(value)
  %695 = and i1 %693, %694
  %696 = xor i1 %695, true
  %697 = fcmp fast olt float %688, 0x3EB0C6F7A0000000
  %698 = or i1 %697, %696
  br i1 %698, label %757, label %699

; <label>:699                                     ; preds = %678
  %700 = call float @dx.op.unary.f32(i32 25, float %688)  ; Rsqrt(value)
  %701 = fmul fast float %700, %681
  %702 = fmul fast float %700, %684
  %703 = fmul fast float %700, %687
  %704 = uitofp i32 %229 to float
  %705 = uitofp i32 %230 to float
  %706 = fadd fast float %704, 5.000000e-01
  %707 = fadd fast float %705, 5.000000e-01
  %708 = fdiv fast float %706, %99
  %709 = fdiv fast float %707, %100
  %710 = fmul fast float %708, 2.000000e+00
  %711 = fmul fast float %709, 2.000000e+00
  %712 = fadd fast float %710, -1.000000e+00
  %713 = fadd fast float %711, -1.000000e+00
  %714 = fsub fast float -0.000000e+00, %713
  %715 = fmul fast float %712, %111
  %716 = call float @dx.op.tertiary.f32(i32 46, float %116, float %714, float %715)  ; FMad(a,b,c)
  %717 = fadd fast float %126, %121
  %718 = fadd fast float %717, %716
  %719 = fmul fast float %712, %112
  %720 = call float @dx.op.tertiary.f32(i32 46, float %117, float %714, float %719)  ; FMad(a,b,c)
  %721 = fadd fast float %127, %122
  %722 = fadd fast float %721, %720
  %723 = fmul fast float %712, %113
  %724 = call float @dx.op.tertiary.f32(i32 46, float %118, float %714, float %723)  ; FMad(a,b,c)
  %725 = fadd fast float %128, %123
  %726 = fadd fast float %725, %724
  %727 = fmul fast float %712, %114
  %728 = call float @dx.op.tertiary.f32(i32 46, float %119, float %714, float %727)  ; FMad(a,b,c)
  %729 = fadd fast float %129, %124
  %730 = fadd fast float %729, %728
  %731 = fdiv fast float %718, %730
  %732 = fdiv fast float %722, %730
  %733 = fdiv fast float %726, %730
  %734 = fsub fast float %731, %151
  %735 = fsub fast float %732, %152
  %736 = fsub fast float %733, %153
  %737 = call float @dx.op.dot3.f32(i32 55, float %701, float %702, float %703, float %734, float %735, float %736)  ; Dot3(ax,ay,az,bx,by,bz)
  %738 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %734)  ; IsFinite(value)
  %739 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %735)  ; IsFinite(value)
  %740 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %736)  ; IsFinite(value)
  %741 = and i1 %738, %739
  %742 = and i1 %741, %740
  %743 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %737)  ; IsFinite(value)
  %744 = and i1 %742, %743
  %745 = xor i1 %744, true
  %746 = call float @dx.op.unary.f32(i32 6, float %737)  ; FAbs(value)
  %747 = fcmp fast olt float %746, 0x3E45798EE0000000
  %748 = or i1 %747, %745
  br i1 %748, label %757, label %749

; <label>:749                                     ; preds = %699
  %750 = fcmp fast olt float %737, 0.000000e+00
  %751 = fsub fast float -0.000000e+00, %701
  %752 = fsub fast float -0.000000e+00, %702
  %753 = fsub fast float -0.000000e+00, %703
  %754 = select i1 %750, float %751, float %701
  %755 = select i1 %750, float %752, float %702
  %756 = select i1 %750, float %753, float %703
  br label %757

; <label>:757                                     ; preds = %749, %699, %678, %672, %224, %201
  %758 = phi float [ 0.000000e+00, %201 ], [ 0.000000e+00, %224 ], [ 0.000000e+00, %672 ], [ 0.000000e+00, %678 ], [ 0.000000e+00, %699 ], [ %754, %749 ]
  %759 = phi float [ 0.000000e+00, %201 ], [ 0.000000e+00, %224 ], [ 0.000000e+00, %672 ], [ 0.000000e+00, %678 ], [ 0.000000e+00, %699 ], [ %755, %749 ]
  %760 = phi float [ 0.000000e+00, %201 ], [ 0.000000e+00, %224 ], [ 0.000000e+00, %672 ], [ 0.000000e+00, %678 ], [ 0.000000e+00, %699 ], [ %756, %749 ]
  %761 = phi i1 [ false, %201 ], [ false, %224 ], [ false, %672 ], [ false, %678 ], [ false, %699 ], [ true, %749 ]
  %762 = call float @dx.op.dot3.f32(i32 55, float %758, float %759, float %760, float %211, float %212, float %213)  ; Dot3(ax,ay,az,bx,by,bz)
  %763 = fcmp fast olt float %762, 0.000000e+00
  %764 = fsub fast float -0.000000e+00, %758
  %765 = fsub fast float -0.000000e+00, %759
  %766 = fsub fast float -0.000000e+00, %760
  %767 = select i1 %763, float %764, float %758
  %768 = select i1 %763, float %765, float %759
  %769 = select i1 %763, float %766, float %760
  %770 = select i1 %761, float %767, float %211
  %771 = select i1 %761, float %768, float %212
  %772 = select i1 %761, float %769, float %213
  %773 = extractvalue %dx.types.CBufRet.f32 %63, 0
  %774 = fmul fast float %770, %773
  %775 = fmul fast float %771, %773
  %776 = fmul fast float %772, %773
  %777 = fadd fast float %774, %151
  %778 = fadd fast float %775, %152
  %779 = fadd fast float %776, %153
  %780 = mul i32 %74, %70
  %781 = add i32 %780, %69
  %782 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %783 = extractvalue %dx.types.CBufRet.i32 %782, 2
  %784 = add i32 %783, 1
  %785 = lshr i32 %784, 16
  %786 = xor i32 %785, %784
  %787 = mul i32 %786, 2146121005
  %788 = lshr i32 %787, 15
  %789 = xor i32 %788, %787
  %790 = mul i32 %789, -2073254261
  %791 = lshr i32 %790, 16
  %792 = xor i32 %791, %790
  %793 = add i32 %781, %792
  %794 = xor i32 %793, 1675113877
  %795 = lshr i32 %794, 16
  %796 = xor i32 %795, %794
  %797 = mul i32 %796, 2146121005
  %798 = lshr i32 %797, 15
  %799 = xor i32 %798, %797
  %800 = mul i32 %799, -2073254261
  %801 = lshr i32 %800, 16
  %802 = xor i32 %801, %800
  br label %803

; <label>:803                                     ; preds = %803, %757
  %804 = phi i32 [ %825, %803 ], [ %802, %757 ]
  %805 = phi i32 [ %890, %803 ], [ 0, %757 ]
  %806 = lshr i32 %804, 16
  %807 = xor i32 %806, %804
  %808 = mul i32 %807, 2146121005
  %809 = lshr i32 %808, 15
  %810 = xor i32 %809, %808
  %811 = mul i32 %810, -1674769041
  %812 = lshr i32 %811, 15
  %813 = xor i32 %812, %811
  %814 = mul i32 %813, -2073254261
  %815 = lshr i32 %814, 16
  %816 = xor i32 %815, %814
  %817 = lshr i32 %816, 8
  %818 = uitofp i32 %817 to float
  %819 = fmul fast float %818, 0x3E70000000000000
  %820 = mul i32 %813, -1674769041
  %821 = lshr i32 %820, 15
  %822 = xor i32 %821, %820
  %823 = mul i32 %822, -2073254261
  %824 = lshr i32 %823, 16
  %825 = xor i32 %824, %823
  %826 = lshr i32 %825, 8
  %827 = uitofp i32 %826 to float
  %828 = call float @dx.op.unary.f32(i32 24, float %819)  ; Sqrt(value)
  %829 = fmul fast float %827, 0x3E9921FB60000000
  %830 = call float @dx.op.unary.f32(i32 6, float %213)  ; FAbs(value)
  %831 = fcmp fast olt float %830, 0x3FEFF7CEE0000000
  %832 = select i1 %831, float 0.000000e+00, float 1.000000e+00
  %833 = select i1 %831, float 1.000000e+00, float 0.000000e+00
  %834 = fmul fast float %832, %213
  %835 = fmul fast float %833, %212
  %836 = fsub fast float %834, %835
  %837 = fmul fast float %833, %211
  %838 = fmul fast float %211, %832
  %839 = fsub fast float -0.000000e+00, %838
  %840 = call float @dx.op.dot3.f32(i32 55, float %836, float %837, float %839, float %836, float %837, float %839)  ; Dot3(ax,ay,az,bx,by,bz)
  %841 = call float @dx.op.unary.f32(i32 25, float %840)  ; Rsqrt(value)
  %842 = fmul fast float %836, %841
  %843 = fmul fast float %837, %841
  %844 = fmul fast float %841, %839
  %845 = call float @dx.op.unary.f32(i32 12, float %829)  ; Cos(value)
  %846 = fmul fast float %845, %828
  %847 = fmul fast float %842, %846
  %848 = fmul fast float %843, %846
  %849 = fmul fast float %844, %846
  %850 = fmul fast float %844, %212
  %851 = fmul fast float %843, %213
  %852 = fsub fast float %850, %851
  %853 = fmul fast float %842, %213
  %854 = fmul fast float %844, %211
  %855 = fsub fast float %853, %854
  %856 = fmul fast float %843, %211
  %857 = fmul fast float %842, %212
  %858 = fsub fast float %856, %857
  %859 = call float @dx.op.unary.f32(i32 13, float %829)  ; Sin(value)
  %860 = fmul fast float %859, %828
  %861 = fmul fast float %852, %860
  %862 = fmul fast float %855, %860
  %863 = fmul fast float %858, %860
  %864 = fsub fast float 1.000000e+00, %819
  %865 = call float @dx.op.unary.f32(i32 24, float %864)  ; Sqrt(value)
  %866 = fmul fast float %865, %211
  %867 = fmul fast float %865, %212
  %868 = fmul fast float %865, %213
  %869 = fadd fast float %866, %847
  %870 = fadd fast float %869, %861
  %871 = fadd fast float %867, %848
  %872 = fadd fast float %871, %862
  %873 = fadd fast float %868, %849
  %874 = fadd fast float %873, %863
  %875 = shl i32 %7, 3
  %876 = add i32 %805, %875
  %877 = mul i32 %876, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %877, i32 0, float %777, float %778, float %779, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %878 = or i32 %877, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %878, i32 0, float %870, float %872, float %874, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %879 = add i32 %877, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %879, i32 0, float %151, float %152, float %153, float %104, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %880 = add i32 %877, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %880, i32 0, float %211, float %212, float %213, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %881 = select i1 %761, float 1.000000e+00, float 0.000000e+00
  %882 = add i32 %877, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %882, i32 0, float %758, float %759, float %760, float %881, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %883 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %884 = extractvalue %dx.types.CBufRet.i32 %883, 2
  %885 = bitcast i32 %69 to float
  %886 = bitcast i32 %70 to float
  %887 = bitcast i32 %884 to float
  %888 = bitcast i32 %805 to float
  %889 = add i32 %877, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %889, i32 0, float %885, float %886, float %887, float %888, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %890 = add nuw nsw i32 %805, 1
  %891 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %892 = extractvalue %dx.types.CBufRet.i32 %891, 1
  %893 = icmp slt i32 %890, %892
  br i1 %893, label %803, label %894, !llvm.loop !20

; <label>:894                                     ; preds = %803
  br label %895

; <label>:895                                     ; preds = %894, %79, %67, %11, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind readnone
declare i1 @dx.op.isSpecialFloat.f32(i32, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32, %dx.types.Handle, %dx.types.Handle, float, float, float, float, i32, i32, i32, float) #1

; Function Attrs: nounwind readnone
declare float @dx.op.dot3.f32(i32, float, float, float, float, float, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.binary.f32(i32, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readnone
declare float @dx.op.tertiary.f32(i32, float, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #1

; Function Attrs: nounwind
declare void @dx.op.bufferStore.f32(i32, %dx.types.Handle, i32, i32, float, float, float, float, i8) #2

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32, %dx.types.Handle, i32, i32) #1

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind readonly }
attributes #2 = { nounwind }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.entryPoints = !{!17}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !10, !13, !15}
!5 = !{!6, !8, !9}
!6 = !{i32 0, %"class.Texture2D<float>"* undef, !"", i32 0, i32 0, i32 1, i32 2, i32 0, !7}
!7 = !{i32 0, i32 9}
!8 = !{i32 1, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 1, i32 1, i32 2, i32 0, !7}
!9 = !{i32 2, %"class.StructuredBuffer<vector<unsigned int, 2> >"* undef, !"", i32 0, i32 2, i32 1, i32 12, i32 0, !2}
!10 = !{!11}
!11 = !{i32 0, %"class.RWStructuredBuffer<vector<float, 4> >"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !12}
!12 = !{i32 1, i32 16}
!13 = !{!14}
!14 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2332, null}
!15 = !{!16}
!16 = !{i32 0, %struct.SamplerState* undef, !"", i32 0, i32 0, i32 1, i32 0, null}
!17 = !{void ()* @CSReferenceGatherInputs, !"CSReferenceGatherInputs", null, !4, !18}
!18 = !{i32 0, i64 16, i32 4, !19}
!19 = !{i32 64, i32 1, i32 1}
!20 = distinct !{!20, !21}
!21 = !{!"llvm.loop.unroll.disable"}
