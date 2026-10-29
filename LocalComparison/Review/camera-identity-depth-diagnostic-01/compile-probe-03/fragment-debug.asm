;
; Input signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Position              0   xyzw        0      POS   float   xy  
; TEXCOORD                 0   xy          1     NONE   float       
; SV_PrimitiveID           0   x           2   PRIMID    uint       
;
;
; Output signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Target                0   xyzw        0   TARGET   float   xyzw
;
; shader hash: 3e5e76286d62dd6abe963dbe8cf418e0
;
; Pipeline Runtime Information: 
;
;PSVRuntimeInfo:
; Pixel Shader
; DepthOutput=0
; SampleFrequency=0
; MinimumExpectedWaveLaneCount: 0
; MaximumExpectedWaveLaneCount: 4294967295
; UsesViewID: false
; SigInputElements: 3
; SigOutputElements: 1
; SigPatchConstOrPrimElements: 0
; SigInputVectors: 3
; SigOutputVectors[0]: 1
; SigOutputVectors[1]: 0
; SigOutputVectors[2]: 0
; SigOutputVectors[3]: 0
; EntryFunctionName: HLGIIdentityFragment
;
;
; Input signature:
;
; Name                 Index             InterpMode DynIdx
; -------------------- ----- ---------------------- ------
; SV_Position              0          noperspective       
; TEXCOORD                 0                 linear       
; SV_PrimitiveID           0        nointerpolation       
;
; Output signature:
;
; Name                 Index             InterpMode DynIdx
; -------------------- ----- ---------------------- ------
; SV_Target                0                              
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
;       int _DebugMaterialMode;                       ; Offset: 2064
;       int _DebugVertexAttributeMode;                ; Offset: 2068
;       int _DebugMaterialValidationMode;             ; Offset: 2072
;       int _DebugFullScreenMode;                     ; Offset: 2076
;       int _DebugSceneOverrideMode;                  ; Offset: 2080
;       int _DebugMipInfoMode;                        ; Offset: 2084
;       int _DebugMipMapStatusMode;                   ; Offset: 2088
;       int _DebugMipMapShowStatusCode;               ; Offset: 2092
;       float _DebugMipMapOpacity;                    ; Offset: 2096
;       float _DebugMipMapRecentlyUpdatedCooldown;    ; Offset: 2100
;       int _DebugMipMapTerrainTextureMode;           ; Offset: 2104
;       int _DebugValidationMode;                     ; Offset: 2108
;       int _DebugLightingMode;                       ; Offset: 2112
;       int _DebugLightingFeatureFlags;               ; Offset: 2116
;       float _DebugValidateAlbedoMinLuminance;       ; Offset: 2120
;       float _DebugValidateAlbedoMaxLuminance;       ; Offset: 2124
;       float _DebugValidateAlbedoSaturationTolerance;; Offset: 2128
;       float _DebugValidateAlbedoHueTolerance;       ; Offset: 2132
;       float3 _DebugValidateAlbedoCompareColor;      ; Offset: 2144
;       uint _DebugRenderingLayerMask;                ; Offset: 2156
;       float _DebugValidateMetallicMinValue;         ; Offset: 2160
;       float _DebugValidateMetallicMaxValue;         ; Offset: 2164
;       float4 _DebugColor;                           ; Offset: 2176
;       float4 _DebugColorInvalidMode;                ; Offset: 2192
;       float4 _DebugValidateBelowMinThresholdColor;  ; Offset: 2208
;       float4 _DebugValidateAboveMaxThresholdColor;  ; Offset: 2224
;       float _DebugCurrentRealTime;                  ; Offset: 2240
;       column_major float4x4 _HLGI_IdentityObjectToWorld;; Offset: 2256
;       column_major float4x4 _HLGI_IdentityViewProjection;; Offset: 2320
;       float4 _HLGI_IdentityBaseMapST;               ; Offset: 2384
;       float4 _HLGI_IdentityAlphaParams;             ; Offset: 2400
;       float _HLGI_IdentityHasBaseMap;               ; Offset: 2416
;       uint _HLGI_IdentityOwnerIndexPlusOne;         ; Offset: 2420
;       float4 _HLGI_IdentityFullSize;                ; Offset: 2432
;       float _HLGI_IdentityProbeEnabled;             ; Offset: 2448
;   
;   } $Globals;                                       ; Offset:    0 Size:  2452
;
; }
;
; cbuffer UnityPerDraw
; {
;
;   struct hostlayout.UnityPerDraw
;   {
;
;       column_major float4x4 unity_ObjectToWorld;    ; Offset:    0
;       column_major float4x4 unity_WorldToObject;    ; Offset:   64
;       float4 unity_LODFade;                         ; Offset:  128
;       float4 unity_WorldTransformParams;            ; Offset:  144
;       float4 unity_RenderingLayer;                  ; Offset:  160
;       float4 unity_LightData;                       ; Offset:  176
;       float4 unity_LightIndices[2];                 ; Offset:  192
;       float4 unity_ProbesOcclusion;                 ; Offset:  224
;       float4 unity_SpecCube0_HDR;                   ; Offset:  240
;       float4 unity_SpecCube1_HDR;                   ; Offset:  256
;       float4 unity_SpecCube0_BoxMax;                ; Offset:  272
;       float4 unity_SpecCube0_BoxMin;                ; Offset:  288
;       float4 unity_SpecCube0_ProbePosition;         ; Offset:  304
;       float4 unity_SpecCube1_BoxMax;                ; Offset:  320
;       float4 unity_SpecCube1_BoxMin;                ; Offset:  336
;       float4 unity_SpecCube1_ProbePosition;         ; Offset:  352
;       float4 unity_LightmapST;                      ; Offset:  368
;       float4 unity_DynamicLightmapST;               ; Offset:  384
;       float4 unity_SHAr;                            ; Offset:  400
;       float4 unity_SHAg;                            ; Offset:  416
;       float4 unity_SHAb;                            ; Offset:  432
;       float4 unity_SHBr;                            ; Offset:  448
;       float4 unity_SHBg;                            ; Offset:  464
;       float4 unity_SHBb;                            ; Offset:  480
;       float4 unity_SHC;                             ; Offset:  496
;       float4 unity_RendererBounds_Min;              ; Offset:  512
;       float4 unity_RendererBounds_Max;              ; Offset:  528
;       column_major float4x4 unity_MatrixPreviousM;  ; Offset:  544
;       column_major float4x4 unity_MatrixPreviousMI; ; Offset:  608
;       float4 unity_MotionVectorsParams;             ; Offset:  672
;       float4 unity_SpriteColor;                     ; Offset:  688
;       float4 unity_SpriteProps;                     ; Offset:  704
;   
;   } UnityPerDraw;                                   ; Offset:    0 Size:   720
;
; }
;
; Resource bind info for _HLGI_IdentityProbeMap
; {
;
;   uint $Element;                                    ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _HLGI_IdentityProbeRows
; {
;
;   uint4 $Element;                                   ; Offset:    0 Size:    16
;
; }
;
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; $Globals                          cbuffer      NA          NA     CB0            cb0     1
; UnityPerDraw                      cbuffer      NA          NA     CB1            cb1     1
; _HLGI_IdentityProbeMap            texture  struct         r/o      T0             t0     1
; _HLGI_IdentityProbeRows               UAV  struct         r/w      U0             u2     1
;
;
; ViewId state:
;
; Number of inputs: 9, outputs: 4
; Outputs dependent on ViewId: {  }
; Inputs contributing to computation of Outputs:
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.i32 = type { i32, i32, i32, i32, i32 }
%"class.StructuredBuffer<unsigned int>" = type { i32 }
%"class.RWStructuredBuffer<vector<unsigned int, 4> >" = type { <4 x i32> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], i32, i32, i32, i32, i32, i32, i32, i32, float, float, i32, i32, i32, i32, float, float, float, float, <3 x float>, i32, float, float, <4 x float>, <4 x float>, <4 x float>, <4 x float>, float, [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, float, i32, <4 x float>, float }
%hostlayout.UnityPerDraw = type { [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, [2 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float> }

define void @HLGIIdentityFragment() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %6 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %7 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 153)  ; CBufferLoadLegacy(handle,regIndex)
  %8 = extractvalue %dx.types.CBufRet.f32 %7, 0
  %9 = fcmp fast oeq float %8, 0.000000e+00
  %10 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %5)  ; IsFinite(value)
  %11 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %6)  ; IsFinite(value)
  %12 = and i1 %10, %11
  %13 = xor i1 %12, true
  %14 = or i1 %9, %13
  %15 = fcmp fast olt float %5, 0.000000e+00
  %16 = fcmp fast olt float %6, 0.000000e+00
  %17 = or i1 %15, %16
  %18 = or i1 %17, %14
  %19 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 152)  ; CBufferLoadLegacy(handle,regIndex)
  %20 = extractvalue %dx.types.CBufRet.f32 %19, 0
  %21 = extractvalue %dx.types.CBufRet.f32 %19, 1
  %22 = fcmp fast oge float %5, %20
  %23 = fcmp fast oge float %6, %21
  %24 = or i1 %22, %23
  %25 = or i1 %18, %24
  %26 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 151)  ; CBufferLoadLegacy(handle,regIndex)
  %27 = extractvalue %dx.types.CBufRet.i32 %26, 1
  %28 = add i32 %27, -1
  %29 = icmp ugt i32 %28, 2
  %30 = or i1 %29, %25
  br i1 %30, label %51, label %31

; <label>:31                                      ; preds = %0
  %32 = fptoui float %5 to i32
  %33 = fptoui float %6 to i32
  %34 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 152)  ; CBufferLoadLegacy(handle,regIndex)
  %35 = extractvalue %dx.types.CBufRet.f32 %34, 0
  %36 = fptoui float %35 to i32
  %37 = mul i32 %36, %33
  %38 = add i32 %37, %32
  %39 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %2, i32 %38, i32 0)  ; BufferLoad(srv,index,wot)
  %40 = extractvalue %dx.types.ResRet.i32 %39, 0
  %41 = add i32 %40, -1
  %42 = icmp ugt i32 %41, 263
  br i1 %42, label %51, label %43

; <label>:43                                      ; preds = %31
  %44 = mul i32 %40, 3
  %45 = add i32 %44, -3
  %46 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 151)  ; CBufferLoadLegacy(handle,regIndex)
  %47 = extractvalue %dx.types.CBufRet.i32 %46, 1
  %48 = add i32 %45, %47
  %49 = mul i32 %48, 3
  %50 = add i32 %49, 54
  br label %51

; <label>:51                                      ; preds = %43, %31, %0
  %52 = phi i32 [ %50, %43 ], [ -1, %0 ], [ -1, %31 ]
  %53 = icmp eq i32 %52, -1
  br i1 %53, label %290, label %54

; <label>:54                                      ; preds = %51
  %55 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %1, i32 0, i32 %52, i32 0, i32 undef, i32 1)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  %56 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 151)  ; CBufferLoadLegacy(handle,regIndex)
  %57 = extractvalue %dx.types.CBufRet.i32 %56, 1
  %58 = mul i32 %57, 19
  %59 = add i32 %58, -19
  %60 = call i32 @dx.op.atomicCompareExchange.i32(i32 79, %dx.types.Handle %1, i32 %59, i32 0, i32 undef, i32 0, i32 1)  ; AtomicCompareExchange(handle,offset0,offset1,offset2,compareValue,newValue)
  %61 = icmp eq i32 %60, 0
  br i1 %61, label %62, label %290

; <label>:62                                      ; preds = %54
  %63 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 4)  ; CBufferLoadLegacy(handle,regIndex)
  %64 = extractvalue %dx.types.CBufRet.f32 %63, 2
  %65 = bitcast float %64 to i32
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %59, i32 4, i32 %65, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %66 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 151)  ; CBufferLoadLegacy(handle,regIndex)
  %67 = extractvalue %dx.types.CBufRet.f32 %66, 0
  %68 = bitcast float %67 to i32
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %59, i32 8, i32 %68, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %69 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 151)  ; CBufferLoadLegacy(handle,regIndex)
  %70 = extractvalue %dx.types.CBufRet.i32 %69, 1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %59, i32 12, i32 %70, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %71 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %72 = extractvalue %dx.types.CBufRet.f32 %71, 0
  %73 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %74 = extractvalue %dx.types.CBufRet.f32 %73, 0
  %75 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %76 = extractvalue %dx.types.CBufRet.f32 %75, 0
  %77 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %78 = extractvalue %dx.types.CBufRet.f32 %77, 0
  %79 = bitcast float %72 to i32
  %80 = bitcast float %74 to i32
  %81 = bitcast float %76 to i32
  %82 = bitcast float %78 to i32
  %83 = add i32 %58, -18
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %83, i32 0, i32 %79, i32 %80, i32 %81, i32 %82, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %84 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %85 = extractvalue %dx.types.CBufRet.f32 %84, 0
  %86 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 146)  ; CBufferLoadLegacy(handle,regIndex)
  %87 = extractvalue %dx.types.CBufRet.f32 %86, 0
  %88 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 147)  ; CBufferLoadLegacy(handle,regIndex)
  %89 = extractvalue %dx.types.CBufRet.f32 %88, 0
  %90 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 148)  ; CBufferLoadLegacy(handle,regIndex)
  %91 = extractvalue %dx.types.CBufRet.f32 %90, 0
  %92 = bitcast float %85 to i32
  %93 = bitcast float %87 to i32
  %94 = bitcast float %89 to i32
  %95 = bitcast float %91 to i32
  %96 = add i32 %58, -14
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %96, i32 0, i32 %92, i32 %93, i32 %94, i32 %95, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %97 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %98 = extractvalue %dx.types.CBufRet.f32 %97, 0
  %99 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %100 = extractvalue %dx.types.CBufRet.f32 %99, 0
  %101 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %102 = extractvalue %dx.types.CBufRet.f32 %101, 0
  %103 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %104 = extractvalue %dx.types.CBufRet.f32 %103, 0
  %105 = bitcast float %98 to i32
  %106 = bitcast float %100 to i32
  %107 = bitcast float %102 to i32
  %108 = bitcast float %104 to i32
  %109 = add i32 %58, -8
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %109, i32 0, i32 %105, i32 %106, i32 %107, i32 %108, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %110 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %111 = extractvalue %dx.types.CBufRet.f32 %110, 0
  %112 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 142)  ; CBufferLoadLegacy(handle,regIndex)
  %113 = extractvalue %dx.types.CBufRet.f32 %112, 0
  %114 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 143)  ; CBufferLoadLegacy(handle,regIndex)
  %115 = extractvalue %dx.types.CBufRet.f32 %114, 0
  %116 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 144)  ; CBufferLoadLegacy(handle,regIndex)
  %117 = extractvalue %dx.types.CBufRet.f32 %116, 0
  %118 = bitcast float %111 to i32
  %119 = bitcast float %113 to i32
  %120 = bitcast float %115 to i32
  %121 = bitcast float %117 to i32
  %122 = add i32 %58, -4
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %122, i32 0, i32 %118, i32 %119, i32 %120, i32 %121, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %123 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %124 = extractvalue %dx.types.CBufRet.f32 %123, 1
  %125 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %126 = extractvalue %dx.types.CBufRet.f32 %125, 1
  %127 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %128 = extractvalue %dx.types.CBufRet.f32 %127, 1
  %129 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %130 = extractvalue %dx.types.CBufRet.f32 %129, 1
  %131 = bitcast float %124 to i32
  %132 = bitcast float %126 to i32
  %133 = bitcast float %128 to i32
  %134 = bitcast float %130 to i32
  %135 = add i32 %58, -17
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %135, i32 0, i32 %131, i32 %132, i32 %133, i32 %134, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %136 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %137 = extractvalue %dx.types.CBufRet.f32 %136, 1
  %138 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 146)  ; CBufferLoadLegacy(handle,regIndex)
  %139 = extractvalue %dx.types.CBufRet.f32 %138, 1
  %140 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 147)  ; CBufferLoadLegacy(handle,regIndex)
  %141 = extractvalue %dx.types.CBufRet.f32 %140, 1
  %142 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 148)  ; CBufferLoadLegacy(handle,regIndex)
  %143 = extractvalue %dx.types.CBufRet.f32 %142, 1
  %144 = bitcast float %137 to i32
  %145 = bitcast float %139 to i32
  %146 = bitcast float %141 to i32
  %147 = bitcast float %143 to i32
  %148 = add i32 %58, -13
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %148, i32 0, i32 %144, i32 %145, i32 %146, i32 %147, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %149 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %150 = extractvalue %dx.types.CBufRet.f32 %149, 1
  %151 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %152 = extractvalue %dx.types.CBufRet.f32 %151, 1
  %153 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %154 = extractvalue %dx.types.CBufRet.f32 %153, 1
  %155 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %156 = extractvalue %dx.types.CBufRet.f32 %155, 1
  %157 = bitcast float %150 to i32
  %158 = bitcast float %152 to i32
  %159 = bitcast float %154 to i32
  %160 = bitcast float %156 to i32
  %161 = add i32 %58, -7
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %161, i32 0, i32 %157, i32 %158, i32 %159, i32 %160, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %162 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %163 = extractvalue %dx.types.CBufRet.f32 %162, 1
  %164 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 142)  ; CBufferLoadLegacy(handle,regIndex)
  %165 = extractvalue %dx.types.CBufRet.f32 %164, 1
  %166 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 143)  ; CBufferLoadLegacy(handle,regIndex)
  %167 = extractvalue %dx.types.CBufRet.f32 %166, 1
  %168 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 144)  ; CBufferLoadLegacy(handle,regIndex)
  %169 = extractvalue %dx.types.CBufRet.f32 %168, 1
  %170 = bitcast float %163 to i32
  %171 = bitcast float %165 to i32
  %172 = bitcast float %167 to i32
  %173 = bitcast float %169 to i32
  %174 = add i32 %58, -3
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %174, i32 0, i32 %170, i32 %171, i32 %172, i32 %173, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %175 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %176 = extractvalue %dx.types.CBufRet.f32 %175, 2
  %177 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %178 = extractvalue %dx.types.CBufRet.f32 %177, 2
  %179 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %180 = extractvalue %dx.types.CBufRet.f32 %179, 2
  %181 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %182 = extractvalue %dx.types.CBufRet.f32 %181, 2
  %183 = bitcast float %176 to i32
  %184 = bitcast float %178 to i32
  %185 = bitcast float %180 to i32
  %186 = bitcast float %182 to i32
  %187 = add i32 %58, -16
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %187, i32 0, i32 %183, i32 %184, i32 %185, i32 %186, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %188 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %189 = extractvalue %dx.types.CBufRet.f32 %188, 2
  %190 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 146)  ; CBufferLoadLegacy(handle,regIndex)
  %191 = extractvalue %dx.types.CBufRet.f32 %190, 2
  %192 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 147)  ; CBufferLoadLegacy(handle,regIndex)
  %193 = extractvalue %dx.types.CBufRet.f32 %192, 2
  %194 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 148)  ; CBufferLoadLegacy(handle,regIndex)
  %195 = extractvalue %dx.types.CBufRet.f32 %194, 2
  %196 = bitcast float %189 to i32
  %197 = bitcast float %191 to i32
  %198 = bitcast float %193 to i32
  %199 = bitcast float %195 to i32
  %200 = add i32 %58, -12
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %200, i32 0, i32 %196, i32 %197, i32 %198, i32 %199, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %201 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %202 = extractvalue %dx.types.CBufRet.f32 %201, 2
  %203 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %204 = extractvalue %dx.types.CBufRet.f32 %203, 2
  %205 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %206 = extractvalue %dx.types.CBufRet.f32 %205, 2
  %207 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %208 = extractvalue %dx.types.CBufRet.f32 %207, 2
  %209 = bitcast float %202 to i32
  %210 = bitcast float %204 to i32
  %211 = bitcast float %206 to i32
  %212 = bitcast float %208 to i32
  %213 = add i32 %58, -6
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %213, i32 0, i32 %209, i32 %210, i32 %211, i32 %212, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %214 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %215 = extractvalue %dx.types.CBufRet.f32 %214, 2
  %216 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 142)  ; CBufferLoadLegacy(handle,regIndex)
  %217 = extractvalue %dx.types.CBufRet.f32 %216, 2
  %218 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 143)  ; CBufferLoadLegacy(handle,regIndex)
  %219 = extractvalue %dx.types.CBufRet.f32 %218, 2
  %220 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 144)  ; CBufferLoadLegacy(handle,regIndex)
  %221 = extractvalue %dx.types.CBufRet.f32 %220, 2
  %222 = bitcast float %215 to i32
  %223 = bitcast float %217 to i32
  %224 = bitcast float %219 to i32
  %225 = bitcast float %221 to i32
  %226 = add i32 %58, -2
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %226, i32 0, i32 %222, i32 %223, i32 %224, i32 %225, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %227 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %228 = extractvalue %dx.types.CBufRet.f32 %227, 3
  %229 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %230 = extractvalue %dx.types.CBufRet.f32 %229, 3
  %231 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %232 = extractvalue %dx.types.CBufRet.f32 %231, 3
  %233 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %234 = extractvalue %dx.types.CBufRet.f32 %233, 3
  %235 = bitcast float %228 to i32
  %236 = bitcast float %230 to i32
  %237 = bitcast float %232 to i32
  %238 = bitcast float %234 to i32
  %239 = add i32 %58, -15
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %239, i32 0, i32 %235, i32 %236, i32 %237, i32 %238, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %240 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %241 = extractvalue %dx.types.CBufRet.f32 %240, 3
  %242 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 146)  ; CBufferLoadLegacy(handle,regIndex)
  %243 = extractvalue %dx.types.CBufRet.f32 %242, 3
  %244 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 147)  ; CBufferLoadLegacy(handle,regIndex)
  %245 = extractvalue %dx.types.CBufRet.f32 %244, 3
  %246 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 148)  ; CBufferLoadLegacy(handle,regIndex)
  %247 = extractvalue %dx.types.CBufRet.f32 %246, 3
  %248 = bitcast float %241 to i32
  %249 = bitcast float %243 to i32
  %250 = bitcast float %245 to i32
  %251 = bitcast float %247 to i32
  %252 = add i32 %58, -11
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %252, i32 0, i32 %248, i32 %249, i32 %250, i32 %251, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %253 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %254 = extractvalue %dx.types.CBufRet.f32 %253, 3
  %255 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %256 = extractvalue %dx.types.CBufRet.f32 %255, 3
  %257 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %258 = extractvalue %dx.types.CBufRet.f32 %257, 3
  %259 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %3, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %260 = extractvalue %dx.types.CBufRet.f32 %259, 3
  %261 = bitcast float %254 to i32
  %262 = bitcast float %256 to i32
  %263 = bitcast float %258 to i32
  %264 = bitcast float %260 to i32
  %265 = add i32 %58, -5
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %265, i32 0, i32 %261, i32 %262, i32 %263, i32 %264, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %266 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %267 = extractvalue %dx.types.CBufRet.f32 %266, 3
  %268 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 142)  ; CBufferLoadLegacy(handle,regIndex)
  %269 = extractvalue %dx.types.CBufRet.f32 %268, 3
  %270 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 143)  ; CBufferLoadLegacy(handle,regIndex)
  %271 = extractvalue %dx.types.CBufRet.f32 %270, 3
  %272 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 144)  ; CBufferLoadLegacy(handle,regIndex)
  %273 = extractvalue %dx.types.CBufRet.f32 %272, 3
  %274 = bitcast float %267 to i32
  %275 = bitcast float %269 to i32
  %276 = bitcast float %271 to i32
  %277 = bitcast float %273 to i32
  %278 = add i32 %58, -1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %278, i32 0, i32 %274, i32 %275, i32 %276, i32 %277, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %279 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 150)  ; CBufferLoadLegacy(handle,regIndex)
  %280 = extractvalue %dx.types.CBufRet.f32 %279, 0
  %281 = extractvalue %dx.types.CBufRet.f32 %279, 1
  %282 = extractvalue %dx.types.CBufRet.f32 %279, 2
  %283 = extractvalue %dx.types.CBufRet.f32 %279, 3
  %284 = bitcast float %280 to i32
  %285 = bitcast float %281 to i32
  %286 = bitcast float %282 to i32
  %287 = bitcast float %283 to i32
  %288 = add i32 %58, -10
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %288, i32 0, i32 %284, i32 %285, i32 %286, i32 %287, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %289 = add i32 %58, -9
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %289, i32 0, i32 1, i32 0, i32 0, i32 0, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %290

; <label>:290                                     ; preds = %62, %54, %51
  call void @dx.op.discard(i32 82, i1 true)  ; Discard(condition)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 0, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 1, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 2, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 3, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  ret void
}

; Function Attrs: nounwind readnone
declare float @dx.op.loadInput.f32(i32, i32, i32, i8, i32) #0

; Function Attrs: nounwind
declare void @dx.op.storeOutput.f32(i32, i32, i32, i8, float) #1

; Function Attrs: nounwind
declare void @dx.op.discard(i32, i1) #1

; Function Attrs: nounwind
declare i32 @dx.op.atomicCompareExchange.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind
declare i32 @dx.op.atomicBinOp.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind readnone
declare i1 @dx.op.isSpecialFloat.f32(i32, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #2

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #2

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #2

; Function Attrs: nounwind
declare void @dx.op.bufferStore.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i8) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32, %dx.types.Handle, i32, i32) #2

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind }
attributes #2 = { nounwind readonly }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.viewIdState = !{!14}
!dx.entryPoints = !{!15}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"ps", i32 6, i32 0}
!4 = !{!5, !8, !11, null}
!5 = !{!6}
!6 = !{i32 0, %"class.StructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 4}
!8 = !{!9}
!9 = !{i32 0, %"class.RWStructuredBuffer<vector<unsigned int, 4> >"* undef, !"", i32 0, i32 2, i32 1, i32 12, i1 false, i1 false, i1 false, !10}
!10 = !{i32 1, i32 16}
!11 = !{!12, !13}
!12 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2452, null}
!13 = !{i32 1, %hostlayout.UnityPerDraw* undef, !"", i32 0, i32 1, i32 1, i32 720, null}
!14 = !{[11 x i32] [i32 9, i32 4, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0]}
!15 = !{void ()* @HLGIIdentityFragment, !"HLGIIdentityFragment", !16, !4, !26}
!16 = !{!17, !23, null}
!17 = !{!18, !21, !22}
!18 = !{i32 0, !"SV_Position", i8 9, i8 3, !19, i8 4, i32 1, i8 4, i32 0, i8 0, !20}
!19 = !{i32 0}
!20 = !{i32 3, i32 3}
!21 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !19, i8 2, i32 1, i8 2, i32 1, i8 0, null}
!22 = !{i32 2, !"SV_PrimitiveID", i8 5, i8 10, !19, i8 1, i32 1, i8 1, i32 2, i8 0, null}
!23 = !{!24}
!24 = !{i32 0, !"SV_Target", i8 9, i8 16, !19, i8 0, i32 1, i8 4, i32 0, i8 0, !25}
!25 = !{i32 3, i32 15}
!26 = !{i32 0, i64 16}
