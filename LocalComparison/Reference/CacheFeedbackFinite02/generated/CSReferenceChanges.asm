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
; shader hash: e895aa402b37ee9299b7584ed72868fd
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
; EntryFunctionName: CSReferenceChanges
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
; Resource bind info for _HLGI_ChangeRegions
; {
;
;   struct struct.HLGIChangeRegion
;   {
;
;       float4 minimum;                               ; Offset:    0
;       float4 maximum;                               ; Offset:   16
;       float4 receiver;                              ; Offset:   32
;   
;   } $Element;                                       ; Offset:    0 Size:    48
;
; }
;
; Resource bind info for _ReferenceChanges
; {
;
;   struct struct.HLGIChangeRegion
;   {
;
;       float4 minimum;                               ; Offset:    0
;       float4 maximum;                               ; Offset:   16
;       float4 receiver;                              ; Offset:   32
;   
;   } $Element;                                       ; Offset:    0 Size:    48
;
; }
;
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; $Globals                          cbuffer      NA          NA     CB0            cb0     1
; _HLGI_ChangeRegions               texture  struct         r/o      T0             t0     1
; _ReferenceChanges                     UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.StructuredBuffer<HLGIChangeRegion>" = type { %struct.HLGIChangeRegion }
%struct.HLGIChangeRegion = type { <4 x float>, <4 x float>, <4 x float> }
%"class.RWStructuredBuffer<HLGIChangeRegion>" = type { %struct.HLGIChangeRegion }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32, float, float, float, float, float, i32, i32, i32, i32, i32, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], i32, i32, i32 }

define void @CSReferenceChanges() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %5 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %3, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %6 = extractvalue %dx.types.CBufRet.i32 %5, 1
  %7 = icmp ult i32 %4, %6
  br i1 %7, label %8, label %29

; <label>:8                                       ; preds = %0
  %9 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %3, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %10 = extractvalue %dx.types.CBufRet.i32 %9, 3
  %11 = icmp ult i32 %4, %10
  br i1 %11, label %12, label %28

; <label>:12                                      ; preds = %8
  %13 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 0)  ; BufferLoad(srv,index,wot)
  %14 = extractvalue %dx.types.ResRet.f32 %13, 0
  %15 = extractvalue %dx.types.ResRet.f32 %13, 1
  %16 = extractvalue %dx.types.ResRet.f32 %13, 2
  %17 = extractvalue %dx.types.ResRet.f32 %13, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %14, float %15, float %16, float %17, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %18 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 16)  ; BufferLoad(srv,index,wot)
  %19 = extractvalue %dx.types.ResRet.f32 %18, 0
  %20 = extractvalue %dx.types.ResRet.f32 %18, 1
  %21 = extractvalue %dx.types.ResRet.f32 %18, 2
  %22 = extractvalue %dx.types.ResRet.f32 %18, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %19, float %20, float %21, float %22, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %23 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 32)  ; BufferLoad(srv,index,wot)
  %24 = extractvalue %dx.types.ResRet.f32 %23, 0
  %25 = extractvalue %dx.types.ResRet.f32 %23, 1
  %26 = extractvalue %dx.types.ResRet.f32 %23, 2
  %27 = extractvalue %dx.types.ResRet.f32 %23, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %24, float %25, float %26, float %27, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %29

; <label>:28                                      ; preds = %8
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %29

; <label>:29                                      ; preds = %28, %12, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32, %dx.types.Handle, i32, i32) #1

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
!dx.entryPoints = !{!12}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !8, !10, null}
!5 = !{!6}
!6 = !{i32 0, %"class.StructuredBuffer<HLGIChangeRegion>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 48}
!8 = !{!9}
!9 = !{i32 0, %"class.RWStructuredBuffer<HLGIChangeRegion>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !7}
!10 = !{!11}
!11 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2332, null}
!12 = !{void ()* @CSReferenceChanges, !"CSReferenceChanges", null, !4, !13}
!13 = !{i32 0, i64 16, i32 4, !14}
!14 = !{i32 64, i32 1, i32 1}
