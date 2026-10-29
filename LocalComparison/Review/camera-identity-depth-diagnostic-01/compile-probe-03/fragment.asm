;
; Input signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Position              0   xyzw        0      POS   float   xyzw
; TEXCOORD                 0   xy          1     NONE   float   xy  
; SV_PrimitiveID           0   x           2   PRIMID    uint   x   
;
;
; Output signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Target                0   xyzw        0   TARGET   float   xyzw
;
; shader hash: 82a61cc3e1b4bb6933a1e6d480f7e294
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
;       column_major float4x4 _HLGI_IdentityObjectToWorld;; Offset: 2064
;       column_major float4x4 _HLGI_IdentityViewProjection;; Offset: 2128
;       float4 _HLGI_IdentityBaseMapST;               ; Offset: 2192
;       float4 _HLGI_IdentityAlphaParams;             ; Offset: 2208
;       float _HLGI_IdentityHasBaseMap;               ; Offset: 2224
;       uint _HLGI_IdentityOwnerIndexPlusOne;         ; Offset: 2228
;       float4 _HLGI_IdentityFullSize;                ; Offset: 2240
;       float _HLGI_IdentityProbeEnabled;             ; Offset: 2256
;   
;   } $Globals;                                       ; Offset:    0 Size:  2260
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
; Resource bind info for _HLGI_IdentityCandidates
; {
;
;   uint3 $Element;                                   ; Offset:    0 Size:    12
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
; sampler_HLGI_IdentityBaseMap      sampler      NA          NA      S0             s0     1
; _HLGI_IdentityBaseMap             texture     f32          2d      T0             t0     1
; _HLGI_IdentityCameraDepth         texture     f32          2d      T1             t1     1
; _HLGI_IdentityCaptureDepth        texture     f32          2d      T2             t2     1
; _HLGI_IdentityProbeMap            texture  struct         r/o      T3             t3     1
; _HLGI_IdentityCandidates              UAV  struct         r/w      U0             u1     1
; _HLGI_IdentityProbeRows               UAV  struct         r/w      U1             u2     1
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
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.Texture2D<vector<float, 4> >" = type { <4 x float>, %"class.Texture2D<vector<float, 4> >::mips_type" }
%"class.Texture2D<vector<float, 4> >::mips_type" = type { i32 }
%"class.Texture2D<float>" = type { float, %"class.Texture2D<float>::mips_type" }
%"class.Texture2D<float>::mips_type" = type { i32 }
%"class.StructuredBuffer<unsigned int>" = type { i32 }
%"class.RWStructuredBuffer<vector<unsigned int, 3> >" = type { <3 x i32> }
%"class.RWStructuredBuffer<vector<unsigned int, 4> >" = type { <4 x i32> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, float, i32, <4 x float>, float }
%hostlayout.UnityPerDraw = type { [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, [2 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float> }
%struct.SamplerState = type { i32 }

define void @HLGIIdentityFragment() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 1, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 3, i32 3, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %8 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %9 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %10 = call i32 @dx.op.loadInput.i32(i32 4, i32 2, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %11 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %12 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %13 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %14 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %15 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %16 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 3, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %17 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %18 = extractvalue %dx.types.CBufRet.f32 %17, 0
  %19 = fcmp fast oeq float %18, 0.000000e+00
  %20 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %13)  ; IsFinite(value)
  %21 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %14)  ; IsFinite(value)
  %22 = and i1 %20, %21
  %23 = xor i1 %22, true
  %24 = or i1 %19, %23
  %25 = fcmp fast olt float %13, 0.000000e+00
  %26 = fcmp fast olt float %14, 0.000000e+00
  %27 = or i1 %25, %26
  %28 = or i1 %27, %24
  %29 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 140)  ; CBufferLoadLegacy(handle,regIndex)
  %30 = extractvalue %dx.types.CBufRet.f32 %29, 0
  %31 = extractvalue %dx.types.CBufRet.f32 %29, 1
  %32 = fcmp fast oge float %13, %30
  %33 = fcmp fast oge float %14, %31
  %34 = or i1 %32, %33
  %35 = or i1 %28, %34
  %36 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %37 = extractvalue %dx.types.CBufRet.i32 %36, 1
  %38 = add i32 %37, -1
  %39 = icmp ugt i32 %38, 2
  %40 = or i1 %39, %35
  br i1 %40, label %57, label %41

; <label>:41                                      ; preds = %0
  %42 = fptoui float %13 to i32
  %43 = fptoui float %14 to i32
  %44 = fptoui float %30 to i32
  %45 = mul i32 %44, %43
  %46 = add i32 %45, %42
  %47 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %3, i32 %46, i32 0)  ; BufferLoad(srv,index,wot)
  %48 = extractvalue %dx.types.ResRet.i32 %47, 0
  %49 = add i32 %48, -1
  %50 = icmp ugt i32 %49, 263
  br i1 %50, label %57, label %51

; <label>:51                                      ; preds = %41
  %52 = mul i32 %48, 3
  %53 = add i32 %37, -3
  %54 = add i32 %53, %52
  %55 = mul i32 %54, 3
  %56 = add i32 %55, 54
  br label %57

; <label>:57                                      ; preds = %51, %41, %0
  %58 = phi i32 [ %56, %51 ], [ -1, %0 ], [ -1, %41 ]
  %59 = icmp eq i32 %58, -1
  br i1 %59, label %296, label %60

; <label>:60                                      ; preds = %57
  %61 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %1, i32 0, i32 %58, i32 0, i32 undef, i32 1)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  %62 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %63 = extractvalue %dx.types.CBufRet.i32 %62, 1
  %64 = mul i32 %63, 19
  %65 = add i32 %64, -19
  %66 = call i32 @dx.op.atomicCompareExchange.i32(i32 79, %dx.types.Handle %1, i32 %65, i32 0, i32 undef, i32 0, i32 1)  ; AtomicCompareExchange(handle,offset0,offset1,offset2,compareValue,newValue)
  %67 = icmp eq i32 %66, 0
  br i1 %67, label %68, label %296

; <label>:68                                      ; preds = %60
  %69 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 4)  ; CBufferLoadLegacy(handle,regIndex)
  %70 = extractvalue %dx.types.CBufRet.f32 %69, 2
  %71 = bitcast float %70 to i32
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %65, i32 4, i32 %71, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %72 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %73 = extractvalue %dx.types.CBufRet.f32 %72, 0
  %74 = bitcast float %73 to i32
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %65, i32 8, i32 %74, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %75 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %76 = extractvalue %dx.types.CBufRet.i32 %75, 1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %65, i32 12, i32 %76, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %77 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %78 = extractvalue %dx.types.CBufRet.f32 %77, 0
  %79 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %80 = extractvalue %dx.types.CBufRet.f32 %79, 0
  %81 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %82 = extractvalue %dx.types.CBufRet.f32 %81, 0
  %83 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %84 = extractvalue %dx.types.CBufRet.f32 %83, 0
  %85 = bitcast float %78 to i32
  %86 = bitcast float %80 to i32
  %87 = bitcast float %82 to i32
  %88 = bitcast float %84 to i32
  %89 = add i32 %64, -18
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %89, i32 0, i32 %85, i32 %86, i32 %87, i32 %88, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %90 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %91 = extractvalue %dx.types.CBufRet.f32 %90, 0
  %92 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %93 = extractvalue %dx.types.CBufRet.f32 %92, 0
  %94 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 135)  ; CBufferLoadLegacy(handle,regIndex)
  %95 = extractvalue %dx.types.CBufRet.f32 %94, 0
  %96 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 136)  ; CBufferLoadLegacy(handle,regIndex)
  %97 = extractvalue %dx.types.CBufRet.f32 %96, 0
  %98 = bitcast float %91 to i32
  %99 = bitcast float %93 to i32
  %100 = bitcast float %95 to i32
  %101 = bitcast float %97 to i32
  %102 = add i32 %64, -14
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %102, i32 0, i32 %98, i32 %99, i32 %100, i32 %101, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %103 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %104 = extractvalue %dx.types.CBufRet.f32 %103, 0
  %105 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %106 = extractvalue %dx.types.CBufRet.f32 %105, 0
  %107 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %108 = extractvalue %dx.types.CBufRet.f32 %107, 0
  %109 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %110 = extractvalue %dx.types.CBufRet.f32 %109, 0
  %111 = bitcast float %104 to i32
  %112 = bitcast float %106 to i32
  %113 = bitcast float %108 to i32
  %114 = bitcast float %110 to i32
  %115 = add i32 %64, -8
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %115, i32 0, i32 %111, i32 %112, i32 %113, i32 %114, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %116 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %117 = extractvalue %dx.types.CBufRet.f32 %116, 0
  %118 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %119 = extractvalue %dx.types.CBufRet.f32 %118, 0
  %120 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %121 = extractvalue %dx.types.CBufRet.f32 %120, 0
  %122 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %123 = extractvalue %dx.types.CBufRet.f32 %122, 0
  %124 = bitcast float %117 to i32
  %125 = bitcast float %119 to i32
  %126 = bitcast float %121 to i32
  %127 = bitcast float %123 to i32
  %128 = add i32 %64, -4
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %128, i32 0, i32 %124, i32 %125, i32 %126, i32 %127, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %129 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %130 = extractvalue %dx.types.CBufRet.f32 %129, 1
  %131 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %132 = extractvalue %dx.types.CBufRet.f32 %131, 1
  %133 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %134 = extractvalue %dx.types.CBufRet.f32 %133, 1
  %135 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %136 = extractvalue %dx.types.CBufRet.f32 %135, 1
  %137 = bitcast float %130 to i32
  %138 = bitcast float %132 to i32
  %139 = bitcast float %134 to i32
  %140 = bitcast float %136 to i32
  %141 = add i32 %64, -17
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %141, i32 0, i32 %137, i32 %138, i32 %139, i32 %140, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %142 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %143 = extractvalue %dx.types.CBufRet.f32 %142, 1
  %144 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %145 = extractvalue %dx.types.CBufRet.f32 %144, 1
  %146 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 135)  ; CBufferLoadLegacy(handle,regIndex)
  %147 = extractvalue %dx.types.CBufRet.f32 %146, 1
  %148 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 136)  ; CBufferLoadLegacy(handle,regIndex)
  %149 = extractvalue %dx.types.CBufRet.f32 %148, 1
  %150 = bitcast float %143 to i32
  %151 = bitcast float %145 to i32
  %152 = bitcast float %147 to i32
  %153 = bitcast float %149 to i32
  %154 = add i32 %64, -13
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %154, i32 0, i32 %150, i32 %151, i32 %152, i32 %153, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %155 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %156 = extractvalue %dx.types.CBufRet.f32 %155, 1
  %157 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %158 = extractvalue %dx.types.CBufRet.f32 %157, 1
  %159 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %160 = extractvalue %dx.types.CBufRet.f32 %159, 1
  %161 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %162 = extractvalue %dx.types.CBufRet.f32 %161, 1
  %163 = bitcast float %156 to i32
  %164 = bitcast float %158 to i32
  %165 = bitcast float %160 to i32
  %166 = bitcast float %162 to i32
  %167 = add i32 %64, -7
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %167, i32 0, i32 %163, i32 %164, i32 %165, i32 %166, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %168 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %169 = extractvalue %dx.types.CBufRet.f32 %168, 1
  %170 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %171 = extractvalue %dx.types.CBufRet.f32 %170, 1
  %172 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %173 = extractvalue %dx.types.CBufRet.f32 %172, 1
  %174 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %175 = extractvalue %dx.types.CBufRet.f32 %174, 1
  %176 = bitcast float %169 to i32
  %177 = bitcast float %171 to i32
  %178 = bitcast float %173 to i32
  %179 = bitcast float %175 to i32
  %180 = add i32 %64, -3
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %180, i32 0, i32 %176, i32 %177, i32 %178, i32 %179, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %181 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %182 = extractvalue %dx.types.CBufRet.f32 %181, 2
  %183 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %184 = extractvalue %dx.types.CBufRet.f32 %183, 2
  %185 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %186 = extractvalue %dx.types.CBufRet.f32 %185, 2
  %187 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %188 = extractvalue %dx.types.CBufRet.f32 %187, 2
  %189 = bitcast float %182 to i32
  %190 = bitcast float %184 to i32
  %191 = bitcast float %186 to i32
  %192 = bitcast float %188 to i32
  %193 = add i32 %64, -16
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %193, i32 0, i32 %189, i32 %190, i32 %191, i32 %192, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %194 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %195 = extractvalue %dx.types.CBufRet.f32 %194, 2
  %196 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %197 = extractvalue %dx.types.CBufRet.f32 %196, 2
  %198 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 135)  ; CBufferLoadLegacy(handle,regIndex)
  %199 = extractvalue %dx.types.CBufRet.f32 %198, 2
  %200 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 136)  ; CBufferLoadLegacy(handle,regIndex)
  %201 = extractvalue %dx.types.CBufRet.f32 %200, 2
  %202 = bitcast float %195 to i32
  %203 = bitcast float %197 to i32
  %204 = bitcast float %199 to i32
  %205 = bitcast float %201 to i32
  %206 = add i32 %64, -12
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %206, i32 0, i32 %202, i32 %203, i32 %204, i32 %205, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %207 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %208 = extractvalue %dx.types.CBufRet.f32 %207, 2
  %209 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %210 = extractvalue %dx.types.CBufRet.f32 %209, 2
  %211 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %212 = extractvalue %dx.types.CBufRet.f32 %211, 2
  %213 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %214 = extractvalue %dx.types.CBufRet.f32 %213, 2
  %215 = bitcast float %208 to i32
  %216 = bitcast float %210 to i32
  %217 = bitcast float %212 to i32
  %218 = bitcast float %214 to i32
  %219 = add i32 %64, -6
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %219, i32 0, i32 %215, i32 %216, i32 %217, i32 %218, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %220 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %221 = extractvalue %dx.types.CBufRet.f32 %220, 2
  %222 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %223 = extractvalue %dx.types.CBufRet.f32 %222, 2
  %224 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %225 = extractvalue %dx.types.CBufRet.f32 %224, 2
  %226 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %227 = extractvalue %dx.types.CBufRet.f32 %226, 2
  %228 = bitcast float %221 to i32
  %229 = bitcast float %223 to i32
  %230 = bitcast float %225 to i32
  %231 = bitcast float %227 to i32
  %232 = add i32 %64, -2
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %232, i32 0, i32 %228, i32 %229, i32 %230, i32 %231, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %233 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 78)  ; CBufferLoadLegacy(handle,regIndex)
  %234 = extractvalue %dx.types.CBufRet.f32 %233, 3
  %235 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 79)  ; CBufferLoadLegacy(handle,regIndex)
  %236 = extractvalue %dx.types.CBufRet.f32 %235, 3
  %237 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 80)  ; CBufferLoadLegacy(handle,regIndex)
  %238 = extractvalue %dx.types.CBufRet.f32 %237, 3
  %239 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 81)  ; CBufferLoadLegacy(handle,regIndex)
  %240 = extractvalue %dx.types.CBufRet.f32 %239, 3
  %241 = bitcast float %234 to i32
  %242 = bitcast float %236 to i32
  %243 = bitcast float %238 to i32
  %244 = bitcast float %240 to i32
  %245 = add i32 %64, -15
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %245, i32 0, i32 %241, i32 %242, i32 %243, i32 %244, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %246 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %247 = extractvalue %dx.types.CBufRet.f32 %246, 3
  %248 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %249 = extractvalue %dx.types.CBufRet.f32 %248, 3
  %250 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 135)  ; CBufferLoadLegacy(handle,regIndex)
  %251 = extractvalue %dx.types.CBufRet.f32 %250, 3
  %252 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 136)  ; CBufferLoadLegacy(handle,regIndex)
  %253 = extractvalue %dx.types.CBufRet.f32 %252, 3
  %254 = bitcast float %247 to i32
  %255 = bitcast float %249 to i32
  %256 = bitcast float %251 to i32
  %257 = bitcast float %253 to i32
  %258 = add i32 %64, -11
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %258, i32 0, i32 %254, i32 %255, i32 %256, i32 %257, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %259 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %260 = extractvalue %dx.types.CBufRet.f32 %259, 3
  %261 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %262 = extractvalue %dx.types.CBufRet.f32 %261, 3
  %263 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %264 = extractvalue %dx.types.CBufRet.f32 %263, 3
  %265 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %8, i32 3)  ; CBufferLoadLegacy(handle,regIndex)
  %266 = extractvalue %dx.types.CBufRet.f32 %265, 3
  %267 = bitcast float %260 to i32
  %268 = bitcast float %262 to i32
  %269 = bitcast float %264 to i32
  %270 = bitcast float %266 to i32
  %271 = add i32 %64, -5
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %271, i32 0, i32 %267, i32 %268, i32 %269, i32 %270, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %272 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %273 = extractvalue %dx.types.CBufRet.f32 %272, 3
  %274 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %275 = extractvalue %dx.types.CBufRet.f32 %274, 3
  %276 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %277 = extractvalue %dx.types.CBufRet.f32 %276, 3
  %278 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %279 = extractvalue %dx.types.CBufRet.f32 %278, 3
  %280 = bitcast float %273 to i32
  %281 = bitcast float %275 to i32
  %282 = bitcast float %277 to i32
  %283 = bitcast float %279 to i32
  %284 = add i32 %64, -1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %284, i32 0, i32 %280, i32 %281, i32 %282, i32 %283, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %285 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 138)  ; CBufferLoadLegacy(handle,regIndex)
  %286 = extractvalue %dx.types.CBufRet.f32 %285, 0
  %287 = extractvalue %dx.types.CBufRet.f32 %285, 1
  %288 = extractvalue %dx.types.CBufRet.f32 %285, 2
  %289 = extractvalue %dx.types.CBufRet.f32 %285, 3
  %290 = bitcast float %286 to i32
  %291 = bitcast float %287 to i32
  %292 = bitcast float %288 to i32
  %293 = bitcast float %289 to i32
  %294 = add i32 %64, -10
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %294, i32 0, i32 %290, i32 %291, i32 %292, i32 %293, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %295 = add i32 %64, -9
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %295, i32 0, i32 0, i32 0, i32 0, i32 0, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %296

; <label>:296                                     ; preds = %68, %60, %57
  %297 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 4)  ; CBufferLoadLegacy(handle,regIndex)
  %298 = extractvalue %dx.types.CBufRet.f32 %297, 2
  %299 = fcmp fast une float %298, 0.000000e+00
  br i1 %299, label %300, label %301

; <label>:300                                     ; preds = %296
  call void @dx.op.discard(i32 82, i1 true)  ; Discard(condition)
  br label %301

; <label>:301                                     ; preds = %300, %296
  %302 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %303 = extractvalue %dx.types.CBufRet.f32 %302, 0
  %304 = fcmp fast une float %303, 0.000000e+00
  br i1 %304, label %305, label %310

; <label>:305                                     ; preds = %301
  %306 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 4)  ; CBufferLoadLegacy(handle,regIndex)
  %307 = extractvalue %dx.types.CBufRet.f32 %306, 0
  %308 = call %dx.types.ResRet.f32 @dx.op.sampleBias.f32(i32 61, %dx.types.Handle %6, %dx.types.Handle %7, float %11, float %12, float undef, float undef, i32 0, i32 0, i32 undef, float %307, float undef)  ; SampleBias(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,bias,clamp)
  %309 = extractvalue %dx.types.ResRet.f32 %308, 3
  br label %310

; <label>:310                                     ; preds = %305, %301
  %311 = phi float [ %309, %305 ], [ 1.000000e+00, %301 ]
  %312 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 138)  ; CBufferLoadLegacy(handle,regIndex)
  %313 = extractvalue %dx.types.CBufRet.f32 %312, 3
  %314 = fcmp fast une float %313, 0.000000e+00
  %315 = extractvalue %dx.types.CBufRet.f32 %312, 0
  %316 = fmul fast float %315, %311
  %317 = select i1 %314, float %315, float %316
  %318 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %317)  ; IsFinite(value)
  %319 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %15)  ; IsFinite(value)
  %320 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %16)  ; IsFinite(value)
  %321 = and i1 %22, %319
  %322 = and i1 %321, %320
  %323 = and i1 %318, %322
  %324 = extractvalue %dx.types.CBufRet.f32 %312, 1
  %325 = extractvalue %dx.types.CBufRet.f32 %312, 2
  %326 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %315)  ; IsFinite(value)
  %327 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %324)  ; IsFinite(value)
  %328 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %325)  ; IsFinite(value)
  %329 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %313)  ; IsFinite(value)
  %330 = and i1 %326, %327
  %331 = and i1 %330, %328
  %332 = and i1 %331, %329
  %333 = and i1 %323, %332
  br i1 %333, label %335, label %334

; <label>:334                                     ; preds = %310
  call void @dx.op.discard(i32 82, i1 true)  ; Discard(condition)
  br label %335

; <label>:335                                     ; preds = %334, %310
  %336 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 138)  ; CBufferLoadLegacy(handle,regIndex)
  %337 = extractvalue %dx.types.CBufRet.f32 %336, 2
  %338 = fcmp fast une float %337, 0.000000e+00
  br i1 %338, label %339, label %343

; <label>:339                                     ; preds = %335
  %340 = extractvalue %dx.types.CBufRet.f32 %336, 1
  %341 = fsub fast float %317, %340
  %342 = fcmp fast olt float %341, 0.000000e+00
  call void @dx.op.discard(i32 82, i1 %342)  ; Discard(condition)
  br label %343

; <label>:343                                     ; preds = %339, %335
  %344 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 140)  ; CBufferLoadLegacy(handle,regIndex)
  %345 = extractvalue %dx.types.CBufRet.f32 %344, 0
  %346 = extractvalue %dx.types.CBufRet.f32 %344, 1
  %347 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %345)  ; IsFinite(value)
  %348 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %346)  ; IsFinite(value)
  %349 = and i1 %347, %348
  %350 = xor i1 %349, true
  %351 = fcmp fast olt float %345, 1.000000e+00
  %352 = fcmp fast olt float %346, 1.000000e+00
  %353 = or i1 %351, %352
  %354 = or i1 %353, %350
  %355 = fcmp fast ogt float %345, 1.638400e+04
  %356 = fcmp fast ogt float %346, 1.638400e+04
  %357 = or i1 %355, %356
  %358 = or i1 %357, %354
  %359 = call float @dx.op.unary.f32(i32 27, float %345)  ; Round_ni(value)
  %360 = call float @dx.op.unary.f32(i32 27, float %346)  ; Round_ni(value)
  %361 = fcmp fast une float %359, %345
  %362 = fcmp fast une float %360, %346
  %363 = or i1 %361, %362
  %364 = or i1 %358, %363
  br i1 %364, label %365, label %366

; <label>:365                                     ; preds = %343
  call void @dx.op.discard(i32 82, i1 true)  ; Discard(condition)
  br label %366

; <label>:366                                     ; preds = %365, %343
  %367 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 140)  ; CBufferLoadLegacy(handle,regIndex)
  %368 = extractvalue %dx.types.CBufRet.f32 %367, 0
  %369 = extractvalue %dx.types.CBufRet.f32 %367, 1
  %370 = fptoui float %368 to i32
  %371 = fptoui float %369 to i32
  %372 = uitofp i32 %370 to float
  %373 = uitofp i32 %371 to float
  %374 = fcmp fast oge float %13, %372
  %375 = fcmp fast oge float %14, %373
  %376 = or i1 %374, %375
  %377 = or i1 %27, %376
  %378 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %379 = extractvalue %dx.types.CBufRet.i32 %378, 1
  %380 = icmp eq i32 %379, 0
  %381 = or i1 %380, %377
  %382 = icmp eq i32 %10, -1
  %383 = or i1 %382, %381
  br i1 %383, label %384, label %385

; <label>:384                                     ; preds = %366
  call void @dx.op.discard(i32 82, i1 true)  ; Discard(condition)
  br label %385

; <label>:385                                     ; preds = %384, %366
  %386 = fptoui float %13 to i32
  %387 = fptoui float %14 to i32
  %388 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %5, i32 0, i32 %386, i32 %387, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %389 = extractvalue %dx.types.ResRet.f32 %388, 0
  %390 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %386, i32 %387, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %391 = extractvalue %dx.types.ResRet.f32 %390, 0
  %392 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 141)  ; CBufferLoadLegacy(handle,regIndex)
  %393 = extractvalue %dx.types.CBufRet.f32 %392, 0
  %394 = fcmp fast oeq float %393, 0.000000e+00
  %395 = or i1 %394, %23
  %396 = or i1 %27, %395
  %397 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %9, i32 140)  ; CBufferLoadLegacy(handle,regIndex)
  %398 = extractvalue %dx.types.CBufRet.f32 %397, 0
  %399 = extractvalue %dx.types.CBufRet.f32 %397, 1
  %400 = fcmp fast oge float %13, %398
  %401 = fcmp fast oge float %14, %399
  %402 = or i1 %400, %401
  %403 = or i1 %396, %402
  %404 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %405 = extractvalue %dx.types.CBufRet.i32 %404, 1
  %406 = add i32 %405, -1
  %407 = icmp ugt i32 %406, 2
  %408 = or i1 %407, %403
  br i1 %408, label %423, label %409

; <label>:409                                     ; preds = %385
  %410 = fptoui float %398 to i32
  %411 = mul i32 %410, %387
  %412 = add i32 %411, %386
  %413 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %3, i32 %412, i32 0)  ; BufferLoad(srv,index,wot)
  %414 = extractvalue %dx.types.ResRet.i32 %413, 0
  %415 = add i32 %414, -1
  %416 = icmp ugt i32 %415, 263
  br i1 %416, label %423, label %417

; <label>:417                                     ; preds = %409
  %418 = mul i32 %414, 3
  %419 = add i32 %405, -3
  %420 = add i32 %419, %418
  %421 = mul i32 %420, 3
  %422 = add i32 %421, 54
  br label %423

; <label>:423                                     ; preds = %417, %409, %385
  %424 = phi i32 [ %422, %417 ], [ -1, %385 ], [ -1, %409 ]
  %425 = phi i32 [ %386, %417 ], [ 0, %385 ], [ %386, %409 ]
  %426 = phi i32 [ %387, %417 ], [ 0, %385 ], [ %387, %409 ]
  %427 = icmp eq i32 %424, -1
  br i1 %427, label %459, label %428

; <label>:428                                     ; preds = %423
  %429 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %1, i32 0, i32 %424, i32 4, i32 undef, i32 1)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  %430 = call i32 @dx.op.atomicCompareExchange.i32(i32 79, %dx.types.Handle %1, i32 %424, i32 8, i32 undef, i32 0, i32 1)  ; AtomicCompareExchange(handle,offset0,offset1,offset2,compareValue,newValue)
  %431 = icmp eq i32 %430, 0
  br i1 %431, label %432, label %459

; <label>:432                                     ; preds = %428
  %433 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %389)  ; IsFinite(value)
  %434 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %391)  ; IsFinite(value)
  %435 = and i1 %433, %434
  %436 = fcmp fast oge float %389, 0.000000e+00
  %437 = and i1 %436, %435
  %438 = fcmp fast ole float %389, 1.000000e+00
  %439 = and i1 %438, %437
  %440 = fcmp fast oge float %391, 0.000000e+00
  %441 = and i1 %440, %439
  %442 = fcmp fast ole float %391, 1.000000e+00
  %443 = and i1 %442, %441
  %444 = zext i1 %443 to i32
  %445 = fcmp fast oeq float %15, %389
  %446 = or i32 %444, 2
  %447 = select i1 %445, i32 %446, i32 %444
  %448 = fcmp fast oeq float %389, %391
  %449 = or i32 %447, 4
  %450 = select i1 %448, i32 %449, i32 %447
  %451 = add i32 %10, 1
  %452 = bitcast float %15 to i32
  %453 = bitcast float %389 to i32
  %454 = bitcast float %391 to i32
  %455 = add i32 %424, 1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %455, i32 0, i32 %451, i32 %452, i32 %453, i32 %454, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %456 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %457 = extractvalue %dx.types.CBufRet.i32 %456, 1
  %458 = add i32 %424, 2
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %458, i32 0, i32 %450, i32 %457, i32 %425, i32 %426, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %459

; <label>:459                                     ; preds = %432, %428, %423
  %460 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %389)  ; IsFinite(value)
  %461 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %391)  ; IsFinite(value)
  %462 = and i1 %460, %461
  %463 = xor i1 %462, true
  %464 = fcmp fast olt float %389, 0.000000e+00
  %465 = or i1 %464, %463
  %466 = fcmp fast ogt float %389, 1.000000e+00
  %467 = or i1 %466, %465
  %468 = fcmp fast olt float %391, 0.000000e+00
  %469 = or i1 %468, %467
  %470 = fcmp fast ogt float %391, 1.000000e+00
  %471 = or i1 %470, %469
  %472 = fcmp fast une float %15, %389
  %473 = or i1 %472, %471
  %474 = fcmp fast une float %389, %391
  %475 = or i1 %474, %473
  br i1 %475, label %476, label %477

; <label>:476                                     ; preds = %459
  call void @dx.op.discard(i32 82, i1 true)  ; Discard(condition)
  br label %477

; <label>:477                                     ; preds = %476, %459
  %478 = mul i32 %370, %387
  %479 = add i32 %478, %386
  %480 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %9, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %481 = extractvalue %dx.types.CBufRet.i32 %480, 1
  %482 = call i32 @dx.op.atomicCompareExchange.i32(i32 79, %dx.types.Handle %2, i32 %479, i32 0, i32 undef, i32 0, i32 %481)  ; AtomicCompareExchange(handle,offset0,offset1,offset2,compareValue,newValue)
  %483 = icmp eq i32 %482, 0
  br i1 %483, label %484, label %486

; <label>:484                                     ; preds = %477
  %485 = add i32 %10, 1
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %2, i32 %479, i32 8, i32 %485, i32 undef, i32 undef, i32 undef, i8 1)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %488

; <label>:486                                     ; preds = %477
  %487 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %2, i32 2, i32 %479, i32 4, i32 undef, i32 1)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %488

; <label>:488                                     ; preds = %486, %484
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 0, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 1, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 2, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 3, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  ret void
}

; Function Attrs: nounwind readnone
declare float @dx.op.loadInput.f32(i32, i32, i32, i8, i32) #0

; Function Attrs: nounwind readnone
declare i32 @dx.op.loadInput.i32(i32, i32, i32, i8, i32) #0

; Function Attrs: nounwind
declare void @dx.op.storeOutput.f32(i32, i32, i32, i8, float) #1

; Function Attrs: nounwind
declare void @dx.op.discard(i32, i1) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.sampleBias.f32(i32, %dx.types.Handle, %dx.types.Handle, float, float, float, float, i32, i32, i32, float, float) #2

; Function Attrs: nounwind readnone
declare i1 @dx.op.isSpecialFloat.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i32) #2

; Function Attrs: nounwind
declare i32 @dx.op.atomicCompareExchange.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind
declare i32 @dx.op.atomicBinOp.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32) #1

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
!dx.viewIdState = !{!22}
!dx.entryPoints = !{!23}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"ps", i32 6, i32 0}
!4 = !{!5, !12, !17, !20}
!5 = !{!6, !8, !9, !10}
!6 = !{i32 0, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 0, i32 1, i32 2, i32 0, !7}
!7 = !{i32 0, i32 9}
!8 = !{i32 1, %"class.Texture2D<float>"* undef, !"", i32 0, i32 1, i32 1, i32 2, i32 0, !7}
!9 = !{i32 2, %"class.Texture2D<float>"* undef, !"", i32 0, i32 2, i32 1, i32 2, i32 0, !7}
!10 = !{i32 3, %"class.StructuredBuffer<unsigned int>"* undef, !"", i32 0, i32 3, i32 1, i32 12, i32 0, !11}
!11 = !{i32 1, i32 4}
!12 = !{!13, !15}
!13 = !{i32 0, %"class.RWStructuredBuffer<vector<unsigned int, 3> >"* undef, !"", i32 0, i32 1, i32 1, i32 12, i1 false, i1 false, i1 false, !14}
!14 = !{i32 1, i32 12}
!15 = !{i32 1, %"class.RWStructuredBuffer<vector<unsigned int, 4> >"* undef, !"", i32 0, i32 2, i32 1, i32 12, i1 false, i1 false, i1 false, !16}
!16 = !{i32 1, i32 16}
!17 = !{!18, !19}
!18 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2260, null}
!19 = !{i32 1, %hostlayout.UnityPerDraw* undef, !"", i32 0, i32 1, i32 1, i32 720, null}
!20 = !{!21}
!21 = !{i32 0, %struct.SamplerState* undef, !"", i32 0, i32 0, i32 1, i32 0, null}
!22 = !{[11 x i32] [i32 9, i32 4, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0]}
!23 = !{void ()* @HLGIIdentityFragment, !"HLGIIdentityFragment", !24, !4, !35}
!24 = !{!25, !33, null}
!25 = !{!26, !29, !31}
!26 = !{i32 0, !"SV_Position", i8 9, i8 3, !27, i8 4, i32 1, i8 4, i32 0, i8 0, !28}
!27 = !{i32 0}
!28 = !{i32 3, i32 15}
!29 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !27, i8 2, i32 1, i8 2, i32 1, i8 0, !30}
!30 = !{i32 3, i32 3}
!31 = !{i32 2, !"SV_PrimitiveID", i8 5, i8 10, !27, i8 1, i32 1, i8 1, i32 2, i8 0, !32}
!32 = !{i32 3, i32 1}
!33 = !{!34}
!34 = !{i32 0, !"SV_Target", i8 9, i8 16, !27, i8 0, i32 1, i8 4, i32 0, i8 0, !28}
!35 = !{i32 0, i64 16}
