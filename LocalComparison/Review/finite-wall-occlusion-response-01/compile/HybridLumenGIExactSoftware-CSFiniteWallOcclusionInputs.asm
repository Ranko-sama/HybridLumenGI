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
; shader hash: 18c35aee01267ab8f4bf3a687cc4fcbc
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
; EntryFunctionName: CSFiniteWallOcclusionInputs
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
;       int _HLGI_ProxyCount;                         ; Offset: 2064
;       int _HLGI_LightCount;                         ; Offset: 2068
;       int _HLGI_Epoch;                              ; Offset: 2072
;       int _HLGI_FrameIndex;                         ; Offset: 2076
;       int _HLGI_CacheGrid;                          ; Offset: 2080
;       int _HLGI_CacheRays;                          ; Offset: 2084
;       float _HLGI_GuideWeight;                      ; Offset: 2088
;       float _HLGI_MaxDistance;                      ; Offset: 2092
;       float _HLGI_ShadowDistance;                   ; Offset: 2096
;       float _HLGI_RayBias;                          ; Offset: 2100
;       float _HLGI_BounceFeedback;                   ; Offset: 2104
;       float4 _HLGI_Environment;                     ; Offset: 2112
;       int _HLGI_EnvironmentCubeEnabled;             ; Offset: 2128
;       int _HLGI_SdfSlotCount;                       ; Offset: 2132
;       int _HLGI_SdfVoxelCount;                      ; Offset: 2136
;       int _HLGI_SdfTraceSteps;                      ; Offset: 2140
;       int _HLGI_SceneBvhCount;                      ; Offset: 2144
;       int _HLGI_ChangeCount;                        ; Offset: 2148
;       float _HLGI_GlobalReactive;                   ; Offset: 2152
;       float _HLGI_GlobalGeometryChange;             ; Offset: 2156
;       float4 _HLGI_SurfaceAtlasSize;                ; Offset: 2160
;       int _HLGI_SurfaceCardCount;                   ; Offset: 2176
;       int _HLGI_GlobalSdfLevelCount;                ; Offset: 2180
;       int _HLGI_GlobalSdfBrickAxis;                 ; Offset: 2184
;       int _HLGI_GlobalSdfEnabled;                   ; Offset: 2188
;       float _HLGI_DetailTraceDistance;              ; Offset: 2192
;       float _HLGI_EmissiveWeight;                   ; Offset: 2196
;       int _HLGI_AreaEmitterCount;                   ; Offset: 2200
;       uint _HLGI_AreaMaterialGeneration;            ; Offset: 2204
;       int _HLGI_SoftwareBvhNodeCount;               ; Offset: 2208
;       int _HLGI_SoftwareBvhLeafCount;               ; Offset: 2212
;       float4 _HLGI_Size;                            ; Offset: 2224
;       float4 _HLGI_FullSize;                        ; Offset: 2240
;       column_major float4x4 _HLGI_VP;               ; Offset: 2256
;       column_major float4x4 _HLGI_InvVP;            ; Offset: 2320
;       column_major float4x4 _HLGI_PreviousVP;       ; Offset: 2384
;       column_major float4x4 _HLGI_PreviousInvVP;    ; Offset: 2448
;       column_major float4x4 _HLGI_View;             ; Offset: 2512
;       float4 _HLGI_JitterDelta;                     ; Offset: 2576
;       float4 _HLGI_MaterialView;                    ; Offset: 2592
;       int _HLGI_Rays;                               ; Offset: 2608
;       int _HLGI_ScreenSteps;                        ; Offset: 2612
;       int _HLGI_HistoryValid;                       ; Offset: 2616
;       int _HLGI_HasMotion;                          ; Offset: 2620
;       int _HLGI_NormalsOct;                         ; Offset: 2624
;       int _HLGI_NativeComposition;                  ; Offset: 2628
;       int _HLGI_FilterStep;                         ; Offset: 2632
;       int _HLGI_MaxHistory;                         ; Offset: 2636
;       float _HLGI_Thickness;                        ; Offset: 2640
;       float _HLGI_DepthThreshold;                   ; Offset: 2644
;       float _HLGI_NormalThreshold;                  ; Offset: 2648
;       float _HLGI_CurrentWeight;                    ; Offset: 2652
;       float _HLGI_RadianceClamp;                    ; Offset: 2656
;       int _OcclusionPixelCount;                     ; Offset: 2660
;       int _OcclusionCenterCount;                    ; Offset: 2664
;   
;   } $Globals;                                       ; Offset:    0 Size:  2668
;
; }
;
; Resource bind info for _OcclusionCenters
; {
;
;   uint2 $Element;                                   ; Offset:    0 Size:     8
;
; }
;
; Resource bind info for _OcclusionDirections
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
; _OcclusionCenters                 texture  struct         r/o      T2             t2     1
; _OcclusionDirections                  UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.i32 = type { i32, i32, i32, i32, i32 }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.Texture2D<float>" = type { float, %"class.Texture2D<float>::mips_type" }
%"class.Texture2D<float>::mips_type" = type { i32 }
%"class.Texture2D<vector<float, 4> >" = type { <4 x float>, %"class.Texture2D<vector<float, 4> >::mips_type" }
%"class.Texture2D<vector<float, 4> >::mips_type" = type { i32 }
%"class.StructuredBuffer<vector<unsigned int, 2> >" = type { <2 x i32> }
%"class.RWStructuredBuffer<vector<float, 4> >" = type { <4 x float> }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], i32, i32, i32, i32, i32, i32, float, float, float, float, float, <4 x float>, i32, i32, i32, i32, i32, i32, float, float, <4 x float>, i32, i32, i32, i32, float, float, i32, i32, i32, i32, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, i32, i32, i32, i32, i32, i32, i32, i32, float, float, float, float, float, i32, i32 }
%struct.SamplerState = type { i32 }

define void @CSFiniteWallOcclusionInputs() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 2, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %8 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 166)  ; CBufferLoadLegacy(handle,regIndex)
  %9 = extractvalue %dx.types.CBufRet.i32 %8, 2
  %10 = icmp ult i32 %7, %9
  br i1 %10, label %11, label %1206

; <label>:11                                      ; preds = %0
  %12 = call %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32 68, %dx.types.Handle %2, i32 %7, i32 0)  ; BufferLoad(srv,index,wot)
  %13 = extractvalue %dx.types.ResRet.i32 %12, 0
  %14 = extractvalue %dx.types.ResRet.i32 %12, 1
  %15 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 140)  ; CBufferLoadLegacy(handle,regIndex)
  %16 = extractvalue %dx.types.CBufRet.f32 %15, 0
  %17 = extractvalue %dx.types.CBufRet.f32 %15, 1
  %18 = fptoui float %16 to i32
  %19 = fptoui float %17 to i32
  %20 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 139)  ; CBufferLoadLegacy(handle,regIndex)
  %21 = extractvalue %dx.types.CBufRet.f32 %20, 0
  %22 = extractvalue %dx.types.CBufRet.f32 %20, 1
  %23 = fptoui float %21 to i32
  %24 = fptoui float %22 to i32
  %25 = shl i32 %13, 1
  %26 = shl i32 %14, 1
  %27 = or i32 %25, 1
  %28 = or i32 %26, 1
  %29 = mul i32 %27, %18
  %30 = mul i32 %28, %19
  %31 = shl i32 %23, 1
  %32 = shl i32 %24, 1
  %33 = udiv i32 %29, %31
  %34 = udiv i32 %30, %32
  %35 = uitofp i32 %33 to float
  %36 = uitofp i32 %34 to float
  %37 = fadd fast float %35, 5.000000e-01
  %38 = fadd fast float %36, 5.000000e-01
  %39 = uitofp i32 %18 to float
  %40 = uitofp i32 %19 to float
  %41 = fdiv fast float %37, %39
  %42 = fdiv fast float %38, %40
  %43 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %33, i32 %34, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %44 = extractvalue %dx.types.ResRet.f32 %43, 0
  %45 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 145)  ; CBufferLoadLegacy(handle,regIndex)
  %46 = extractvalue %dx.types.CBufRet.f32 %45, 0
  %47 = extractvalue %dx.types.CBufRet.f32 %45, 1
  %48 = extractvalue %dx.types.CBufRet.f32 %45, 2
  %49 = extractvalue %dx.types.CBufRet.f32 %45, 3
  %50 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 146)  ; CBufferLoadLegacy(handle,regIndex)
  %51 = extractvalue %dx.types.CBufRet.f32 %50, 0
  %52 = extractvalue %dx.types.CBufRet.f32 %50, 1
  %53 = extractvalue %dx.types.CBufRet.f32 %50, 2
  %54 = extractvalue %dx.types.CBufRet.f32 %50, 3
  %55 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 147)  ; CBufferLoadLegacy(handle,regIndex)
  %56 = extractvalue %dx.types.CBufRet.f32 %55, 0
  %57 = extractvalue %dx.types.CBufRet.f32 %55, 1
  %58 = extractvalue %dx.types.CBufRet.f32 %55, 2
  %59 = extractvalue %dx.types.CBufRet.f32 %55, 3
  %60 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 148)  ; CBufferLoadLegacy(handle,regIndex)
  %61 = extractvalue %dx.types.CBufRet.f32 %60, 0
  %62 = extractvalue %dx.types.CBufRet.f32 %60, 1
  %63 = extractvalue %dx.types.CBufRet.f32 %60, 2
  %64 = extractvalue %dx.types.CBufRet.f32 %60, 3
  %65 = fmul fast float %41, 2.000000e+00
  %66 = fmul fast float %42, 2.000000e+00
  %67 = fadd fast float %65, -1.000000e+00
  %68 = fadd fast float %66, -1.000000e+00
  %69 = fsub fast float -0.000000e+00, %68
  %70 = fmul fast float %46, %67
  %71 = call float @dx.op.tertiary.f32(i32 46, float %51, float %69, float %70)  ; FMad(a,b,c)
  %72 = call float @dx.op.tertiary.f32(i32 46, float %56, float %44, float %71)  ; FMad(a,b,c)
  %73 = fadd fast float %72, %61
  %74 = fmul fast float %47, %67
  %75 = call float @dx.op.tertiary.f32(i32 46, float %52, float %69, float %74)  ; FMad(a,b,c)
  %76 = call float @dx.op.tertiary.f32(i32 46, float %57, float %44, float %75)  ; FMad(a,b,c)
  %77 = fadd fast float %76, %62
  %78 = fmul fast float %48, %67
  %79 = call float @dx.op.tertiary.f32(i32 46, float %53, float %69, float %78)  ; FMad(a,b,c)
  %80 = call float @dx.op.tertiary.f32(i32 46, float %58, float %44, float %79)  ; FMad(a,b,c)
  %81 = fadd fast float %80, %63
  %82 = fmul fast float %49, %67
  %83 = call float @dx.op.tertiary.f32(i32 46, float %54, float %69, float %82)  ; FMad(a,b,c)
  %84 = call float @dx.op.tertiary.f32(i32 46, float %59, float %44, float %83)  ; FMad(a,b,c)
  %85 = fadd fast float %84, %64
  %86 = fdiv fast float %73, %85
  %87 = fdiv fast float %77, %85
  %88 = fdiv fast float %81, %85
  %89 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %3, %dx.types.Handle %5, float %41, float %42, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %90 = extractvalue %dx.types.ResRet.f32 %89, 0
  %91 = extractvalue %dx.types.ResRet.f32 %89, 1
  %92 = extractvalue %dx.types.ResRet.f32 %89, 2
  %93 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 164)  ; CBufferLoadLegacy(handle,regIndex)
  %94 = extractvalue %dx.types.CBufRet.i32 %93, 0
  %95 = icmp eq i32 %94, 0
  br i1 %95, label %137, label %96

; <label>:96                                      ; preds = %11
  %97 = fmul fast float %90, 2.555000e+02
  %98 = fmul fast float %91, 2.555000e+02
  %99 = fmul fast float %92, 2.555000e+02
  %100 = fptoui float %97 to i32
  %101 = fptoui float %98 to i32
  %102 = fptoui float %99 to i32
  %103 = lshr i32 %102, 4
  %104 = shl i32 %102, 8
  %105 = and i32 %104, 3840
  %106 = shl i32 %103, 8
  %107 = or i32 %105, %100
  %108 = or i32 %106, %101
  %109 = uitofp i32 %107 to float
  %110 = uitofp i32 %108 to float
  %111 = fmul fast float %109, 0x3F40010020000000
  %112 = fmul fast float %110, 0x3F40010020000000
  %113 = fadd fast float %111, -1.000000e+00
  %114 = fadd fast float %112, -1.000000e+00
  %115 = fcmp fast olt float %113, 0.000000e+00
  %116 = fsub fast float -0.000000e+00, %113
  %117 = select i1 %115, float %116, float %113
  %118 = fsub fast float 1.000000e+00, %117
  %119 = fcmp fast olt float %114, 0.000000e+00
  %120 = fsub fast float -0.000000e+00, %114
  %121 = select i1 %119, float %120, float %114
  %122 = fsub fast float %118, %121
  %123 = fsub fast float -0.000000e+00, %122
  %124 = call float @dx.op.binary.f32(i32 35, float %123, float 0.000000e+00)  ; FMax(a,b)
  %125 = fcmp fast oge float %113, 0.000000e+00
  %126 = fsub fast float -0.000000e+00, %124
  %127 = select i1 %125, float %126, float %124
  %128 = fcmp fast oge float %114, 0.000000e+00
  %129 = select i1 %128, float %126, float %124
  %130 = fadd fast float %127, %113
  %131 = fadd fast float %129, %114
  %132 = call float @dx.op.dot3.f32(i32 55, float %130, float %131, float %122, float %130, float %131, float %122)  ; Dot3(ax,ay,az,bx,by,bz)
  %133 = call float @dx.op.unary.f32(i32 25, float %132)  ; Rsqrt(value)
  %134 = fmul fast float %130, %133
  %135 = fmul fast float %131, %133
  %136 = fmul fast float %133, %122
  br label %137

; <label>:137                                     ; preds = %96, %11
  %138 = phi float [ %134, %96 ], [ %90, %11 ]
  %139 = phi float [ %135, %96 ], [ %91, %11 ]
  %140 = phi float [ %136, %96 ], [ %92, %11 ]
  %141 = call float @dx.op.dot3.f32(i32 55, float %138, float %139, float %140, float %138, float %139, float %140)  ; Dot3(ax,ay,az,bx,by,bz)
  %142 = fcmp fast ogt float %141, 0x3F847AE140000000
  br i1 %142, label %143, label %148

; <label>:143                                     ; preds = %137
  %144 = call float @dx.op.unary.f32(i32 25, float %141)  ; Rsqrt(value)
  %145 = fmul fast float %144, %138
  %146 = fmul fast float %144, %139
  %147 = fmul fast float %144, %140
  br label %148

; <label>:148                                     ; preds = %143, %137
  %149 = phi float [ %145, %143 ], [ 0.000000e+00, %137 ]
  %150 = phi float [ %146, %143 ], [ 1.000000e+00, %137 ]
  %151 = phi float [ %147, %143 ], [ 0.000000e+00, %137 ]
  %152 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %44)  ; IsFinite(value)
  %153 = xor i1 %152, true
  %154 = fcmp fast olt float %44, 0.000000e+00
  %155 = or i1 %154, %153
  %156 = fcmp fast ogt float %44, 1.000000e+00
  %157 = or i1 %156, %155
  %158 = xor i1 %157, true
  %159 = fcmp fast ogt float %44, 0x3EB0C6F7A0000000
  %160 = and i1 %159, %158
  br i1 %160, label %161, label %709

; <label>:161                                     ; preds = %148
  %162 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %86)  ; IsFinite(value)
  %163 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %87)  ; IsFinite(value)
  %164 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %88)  ; IsFinite(value)
  %165 = and i1 %162, %163
  %166 = and i1 %165, %164
  br i1 %166, label %167, label %709

; <label>:167                                     ; preds = %161
  %168 = fmul fast float %41, %16
  %169 = fmul fast float %42, %17
  %170 = call float @dx.op.unary.f32(i32 27, float %168)  ; Round_ni(value)
  %171 = call float @dx.op.unary.f32(i32 27, float %169)  ; Round_ni(value)
  %172 = fptosi float %170 to i32
  %173 = fptosi float %171 to i32
  %174 = or i32 %173, %172
  %175 = icmp slt i32 %174, 0
  br i1 %175, label %709, label %176

; <label>:176                                     ; preds = %167
  %177 = fptosi float %16 to i32
  %178 = fptosi float %17 to i32
  %179 = icmp sge i32 %172, %177
  %180 = icmp sge i32 %173, %178
  %181 = or i1 %179, %180
  br i1 %181, label %709, label %182

; <label>:182                                     ; preds = %176
  %183 = add i32 %172, -1
  %184 = add i32 %172, -2
  %185 = or i32 %183, %173
  %186 = icmp slt i32 %185, 0
  br i1 %186, label %231, label %187

; <label>:187                                     ; preds = %182
  %188 = or i32 %184, %173
  %189 = icmp slt i32 %183, %177
  %190 = icmp sgt i32 %188, -1
  %191 = and i1 %190, %189
  %192 = icmp slt i32 %184, %177
  %193 = and i1 %191, %192
  br i1 %193, label %194, label %231

; <label>:194                                     ; preds = %187
  %195 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %183, i32 %173, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %196 = extractvalue %dx.types.ResRet.f32 %195, 0
  %197 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %184, i32 %173, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %198 = extractvalue %dx.types.ResRet.f32 %197, 0
  %199 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %196)  ; IsFinite(value)
  br i1 %199, label %200, label %231

; <label>:200                                     ; preds = %194
  %201 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %198)  ; IsFinite(value)
  %202 = xor i1 %201, true
  %203 = fcmp fast olt float %196, 0.000000e+00
  %204 = or i1 %203, %202
  %205 = fcmp fast ogt float %196, 1.000000e+00
  %206 = or i1 %205, %204
  %207 = fcmp fast olt float %198, 0.000000e+00
  %208 = or i1 %207, %206
  %209 = fcmp fast ogt float %198, 1.000000e+00
  %210 = or i1 %209, %208
  %211 = xor i1 %210, true
  %212 = fcmp fast ogt float %196, 0x3EB0C6F7A0000000
  %213 = and i1 %212, %211
  %214 = fcmp fast ogt float %198, 0x3EB0C6F7A0000000
  %215 = and i1 %214, %213
  br i1 %215, label %216, label %231

; <label>:216                                     ; preds = %200
  %217 = fmul fast float %196, 2.000000e+00
  %218 = fsub fast float %217, %198
  %219 = fsub fast float %218, %44
  %220 = call float @dx.op.unary.f32(i32 6, float %219)  ; FAbs(value)
  %221 = fcmp fast olt float %218, 0.000000e+00
  %222 = fcmp fast ogt float %218, 1.000000e+00
  %223 = or i1 %221, %222
  %224 = fcmp fast oge float %220, 0x4415AF1D80000000
  %225 = or i1 %223, %224
  %226 = select i1 %225, float 0x4415AF1D80000000, float %220
  %227 = select i1 %225, float 0.000000e+00, float %196
  %228 = select i1 %225, float 0.000000e+00, float %218
  %229 = xor i1 %225, true
  %230 = sext i1 %229 to i32
  br label %231

; <label>:231                                     ; preds = %216, %200, %194, %187, %182
  %232 = phi float [ 0x4415AF1D80000000, %182 ], [ 0x4415AF1D80000000, %187 ], [ 0x4415AF1D80000000, %200 ], [ 0x4415AF1D80000000, %194 ], [ %226, %216 ]
  %233 = phi float [ 0.000000e+00, %182 ], [ 0.000000e+00, %187 ], [ 0.000000e+00, %200 ], [ 0.000000e+00, %194 ], [ %227, %216 ]
  %234 = phi float [ 0.000000e+00, %182 ], [ 0.000000e+00, %187 ], [ 0.000000e+00, %200 ], [ 0.000000e+00, %194 ], [ %228, %216 ]
  %235 = phi i32 [ 0, %182 ], [ 0, %187 ], [ 0, %200 ], [ 0, %194 ], [ %230, %216 ]
  %236 = add i32 %172, 1
  %237 = add i32 %172, 2
  %238 = or i32 %236, %173
  %239 = icmp slt i32 %238, 0
  br i1 %239, label %282, label %240

; <label>:240                                     ; preds = %231
  %241 = or i32 %237, %173
  %242 = icmp slt i32 %236, %177
  %243 = icmp sgt i32 %241, -1
  %244 = and i1 %243, %242
  %245 = icmp slt i32 %237, %177
  %246 = and i1 %244, %245
  br i1 %246, label %247, label %282

; <label>:247                                     ; preds = %240
  %248 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %236, i32 %173, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %249 = extractvalue %dx.types.ResRet.f32 %248, 0
  %250 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %237, i32 %173, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %251 = extractvalue %dx.types.ResRet.f32 %250, 0
  %252 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %249)  ; IsFinite(value)
  br i1 %252, label %253, label %282

; <label>:253                                     ; preds = %247
  %254 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %251)  ; IsFinite(value)
  %255 = xor i1 %254, true
  %256 = fcmp fast olt float %249, 0.000000e+00
  %257 = or i1 %256, %255
  %258 = fcmp fast ogt float %249, 1.000000e+00
  %259 = or i1 %258, %257
  %260 = fcmp fast olt float %251, 0.000000e+00
  %261 = or i1 %260, %259
  %262 = fcmp fast ogt float %251, 1.000000e+00
  %263 = or i1 %262, %261
  %264 = xor i1 %263, true
  %265 = fcmp fast ogt float %249, 0x3EB0C6F7A0000000
  %266 = and i1 %265, %264
  %267 = fcmp fast ogt float %251, 0x3EB0C6F7A0000000
  %268 = and i1 %267, %266
  br i1 %268, label %269, label %282

; <label>:269                                     ; preds = %253
  %270 = fmul fast float %249, 2.000000e+00
  %271 = fsub fast float %270, %251
  %272 = fsub fast float %271, %44
  %273 = call float @dx.op.unary.f32(i32 6, float %272)  ; FAbs(value)
  %274 = fcmp fast olt float %271, 0.000000e+00
  %275 = fcmp fast ogt float %271, 1.000000e+00
  %276 = or i1 %274, %275
  %277 = fcmp fast oge float %273, %232
  %278 = or i1 %276, %277
  %279 = select i1 %278, float %233, float %249
  %280 = select i1 %278, float %234, float %271
  %281 = select i1 %278, i32 %235, i32 1
  br label %282

; <label>:282                                     ; preds = %269, %253, %247, %240, %231
  %283 = phi float [ %233, %231 ], [ %233, %240 ], [ %233, %253 ], [ %233, %247 ], [ %279, %269 ]
  %284 = phi float [ %234, %231 ], [ %234, %240 ], [ %234, %253 ], [ %234, %247 ], [ %280, %269 ]
  %285 = phi i32 [ %235, %231 ], [ %235, %240 ], [ %235, %253 ], [ %235, %247 ], [ %281, %269 ]
  %286 = icmp eq i32 %285, 0
  br i1 %286, label %392, label %287

; <label>:287                                     ; preds = %282
  %288 = uitofp i32 %172 to float
  %289 = uitofp i32 %173 to float
  %290 = fadd fast float %288, 5.000000e-01
  %291 = fadd fast float %289, 5.000000e-01
  %292 = fdiv fast float %290, %39
  %293 = fdiv fast float %291, %40
  %294 = fmul fast float %292, 2.000000e+00
  %295 = fmul fast float %293, 2.000000e+00
  %296 = fadd fast float %294, -1.000000e+00
  %297 = fadd fast float %295, -1.000000e+00
  %298 = fsub fast float -0.000000e+00, %297
  %299 = fmul fast float %296, %46
  %300 = call float @dx.op.tertiary.f32(i32 46, float %51, float %298, float %299)  ; FMad(a,b,c)
  %301 = call float @dx.op.tertiary.f32(i32 46, float %56, float %284, float %300)  ; FMad(a,b,c)
  %302 = fadd fast float %301, %61
  %303 = fmul fast float %296, %47
  %304 = call float @dx.op.tertiary.f32(i32 46, float %52, float %298, float %303)  ; FMad(a,b,c)
  %305 = call float @dx.op.tertiary.f32(i32 46, float %57, float %284, float %304)  ; FMad(a,b,c)
  %306 = fadd fast float %305, %62
  %307 = fmul fast float %296, %48
  %308 = call float @dx.op.tertiary.f32(i32 46, float %53, float %298, float %307)  ; FMad(a,b,c)
  %309 = call float @dx.op.tertiary.f32(i32 46, float %58, float %284, float %308)  ; FMad(a,b,c)
  %310 = fadd fast float %309, %63
  %311 = fmul fast float %296, %49
  %312 = call float @dx.op.tertiary.f32(i32 46, float %54, float %298, float %311)  ; FMad(a,b,c)
  %313 = call float @dx.op.tertiary.f32(i32 46, float %59, float %284, float %312)  ; FMad(a,b,c)
  %314 = fadd fast float %313, %64
  %315 = fdiv fast float %302, %314
  %316 = fdiv fast float %306, %314
  %317 = fdiv fast float %310, %314
  %318 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %315)  ; IsFinite(value)
  %319 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %316)  ; IsFinite(value)
  %320 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %317)  ; IsFinite(value)
  %321 = and i1 %318, %319
  %322 = and i1 %321, %320
  br i1 %322, label %323, label %392

; <label>:323                                     ; preds = %287
  %324 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 160)  ; CBufferLoadLegacy(handle,regIndex)
  %325 = extractvalue %dx.types.CBufRet.f32 %324, 2
  %326 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 159)  ; CBufferLoadLegacy(handle,regIndex)
  %327 = extractvalue %dx.types.CBufRet.f32 %326, 2
  %328 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 158)  ; CBufferLoadLegacy(handle,regIndex)
  %329 = extractvalue %dx.types.CBufRet.f32 %328, 2
  %330 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 157)  ; CBufferLoadLegacy(handle,regIndex)
  %331 = extractvalue %dx.types.CBufRet.f32 %330, 2
  %332 = fmul fast float %331, %86
  %333 = call float @dx.op.tertiary.f32(i32 46, float %329, float %87, float %332)  ; FMad(a,b,c)
  %334 = call float @dx.op.tertiary.f32(i32 46, float %327, float %88, float %333)  ; FMad(a,b,c)
  %335 = fadd fast float %334, %325
  %336 = call float @dx.op.unary.f32(i32 6, float %335)  ; FAbs(value)
  %337 = fmul fast float %336, 0x3F1A36E2E0000000
  %338 = call float @dx.op.binary.f32(i32 35, float 0x3F60624DE0000000, float %337)  ; FMax(a,b)
  %339 = fsub fast float %315, %86
  %340 = fsub fast float %316, %87
  %341 = fsub fast float %317, %88
  %342 = fmul fast float %339, %339
  %343 = fmul fast float %340, %340
  %344 = fadd fast float %343, %342
  %345 = fmul fast float %341, %341
  %346 = fadd fast float %344, %345
  %347 = call float @dx.op.unary.f32(i32 24, float %346)  ; Sqrt(value)
  %348 = fcmp fast ogt float %347, %338
  br i1 %348, label %392, label %349

; <label>:349                                     ; preds = %323
  %350 = add i32 %285, %172
  %351 = uitofp i32 %350 to float
  %352 = fadd fast float %351, 5.000000e-01
  %353 = fdiv fast float %352, %39
  %354 = fmul fast float %353, 2.000000e+00
  %355 = fadd fast float %354, -1.000000e+00
  %356 = fmul fast float %355, %46
  %357 = call float @dx.op.tertiary.f32(i32 46, float %51, float %298, float %356)  ; FMad(a,b,c)
  %358 = call float @dx.op.tertiary.f32(i32 46, float %56, float %283, float %357)  ; FMad(a,b,c)
  %359 = fadd fast float %358, %61
  %360 = fmul fast float %355, %47
  %361 = call float @dx.op.tertiary.f32(i32 46, float %52, float %298, float %360)  ; FMad(a,b,c)
  %362 = call float @dx.op.tertiary.f32(i32 46, float %57, float %283, float %361)  ; FMad(a,b,c)
  %363 = fadd fast float %362, %62
  %364 = fmul fast float %355, %48
  %365 = call float @dx.op.tertiary.f32(i32 46, float %53, float %298, float %364)  ; FMad(a,b,c)
  %366 = call float @dx.op.tertiary.f32(i32 46, float %58, float %283, float %365)  ; FMad(a,b,c)
  %367 = fadd fast float %366, %63
  %368 = fmul fast float %355, %49
  %369 = call float @dx.op.tertiary.f32(i32 46, float %54, float %298, float %368)  ; FMad(a,b,c)
  %370 = call float @dx.op.tertiary.f32(i32 46, float %59, float %283, float %369)  ; FMad(a,b,c)
  %371 = fadd fast float %370, %64
  %372 = fdiv fast float %359, %371
  %373 = fdiv fast float %363, %371
  %374 = fdiv fast float %367, %371
  %375 = fsub fast float %372, %86
  %376 = fsub fast float %373, %87
  %377 = fsub fast float %374, %88
  %378 = sitofp i32 %285 to float
  %379 = fmul fast float %375, %378
  %380 = fmul fast float %376, %378
  %381 = fmul fast float %377, %378
  %382 = call float @dx.op.dot3.f32(i32 55, float %379, float %380, float %381, float %379, float %380, float %381)  ; Dot3(ax,ay,az,bx,by,bz)
  %383 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %379)  ; IsFinite(value)
  %384 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %380)  ; IsFinite(value)
  %385 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %381)  ; IsFinite(value)
  %386 = and i1 %383, %384
  %387 = and i1 %386, %385
  br i1 %387, label %388, label %392

; <label>:388                                     ; preds = %349
  %389 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %382)  ; IsFinite(value)
  %390 = fcmp uge float %382, 0x3C9CD2B2A0000000
  %391 = and i1 %390, %389
  br label %392

; <label>:392                                     ; preds = %388, %349, %323, %287, %282
  %393 = phi float [ 0.000000e+00, %282 ], [ 0.000000e+00, %323 ], [ 0.000000e+00, %287 ], [ %379, %349 ], [ %379, %388 ]
  %394 = phi float [ 0.000000e+00, %282 ], [ 0.000000e+00, %323 ], [ 0.000000e+00, %287 ], [ %380, %349 ], [ %380, %388 ]
  %395 = phi float [ 0.000000e+00, %282 ], [ 0.000000e+00, %323 ], [ 0.000000e+00, %287 ], [ %381, %349 ], [ %381, %388 ]
  %396 = phi i1 [ false, %282 ], [ false, %323 ], [ false, %287 ], [ false, %349 ], [ %391, %388 ]
  br i1 %396, label %397, label %403

; <label>:397                                     ; preds = %392
  %398 = call float @dx.op.dot3.f32(i32 55, float %393, float %394, float %395, float %393, float %394, float %395)  ; Dot3(ax,ay,az,bx,by,bz)
  %399 = call float @dx.op.unary.f32(i32 25, float %398)  ; Rsqrt(value)
  %400 = fmul fast float %399, %393
  %401 = fmul fast float %399, %394
  %402 = fmul fast float %399, %395
  br label %403

; <label>:403                                     ; preds = %397, %392
  %404 = phi float [ %400, %397 ], [ %393, %392 ]
  %405 = phi float [ %401, %397 ], [ %394, %392 ]
  %406 = phi float [ %402, %397 ], [ %395, %392 ]
  %407 = phi i1 [ true, %397 ], [ false, %392 ]
  br i1 %407, label %408, label %709

; <label>:408                                     ; preds = %403
  %409 = add i32 %173, -1
  %410 = add i32 %173, -2
  %411 = or i32 %409, %172
  %412 = icmp slt i32 %411, 0
  br i1 %412, label %457, label %413

; <label>:413                                     ; preds = %408
  %414 = or i32 %410, %172
  %415 = icmp slt i32 %409, %178
  %416 = icmp sgt i32 %414, -1
  %417 = and i1 %416, %415
  %418 = icmp slt i32 %410, %178
  %419 = and i1 %417, %418
  br i1 %419, label %420, label %457

; <label>:420                                     ; preds = %413
  %421 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %172, i32 %409, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %422 = extractvalue %dx.types.ResRet.f32 %421, 0
  %423 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %172, i32 %410, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %424 = extractvalue %dx.types.ResRet.f32 %423, 0
  %425 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %422)  ; IsFinite(value)
  br i1 %425, label %426, label %457

; <label>:426                                     ; preds = %420
  %427 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %424)  ; IsFinite(value)
  %428 = xor i1 %427, true
  %429 = fcmp fast olt float %422, 0.000000e+00
  %430 = or i1 %429, %428
  %431 = fcmp fast ogt float %422, 1.000000e+00
  %432 = or i1 %431, %430
  %433 = fcmp fast olt float %424, 0.000000e+00
  %434 = or i1 %433, %432
  %435 = fcmp fast ogt float %424, 1.000000e+00
  %436 = or i1 %435, %434
  %437 = xor i1 %436, true
  %438 = fcmp fast ogt float %422, 0x3EB0C6F7A0000000
  %439 = and i1 %438, %437
  %440 = fcmp fast ogt float %424, 0x3EB0C6F7A0000000
  %441 = and i1 %440, %439
  br i1 %441, label %442, label %457

; <label>:442                                     ; preds = %426
  %443 = fmul fast float %422, 2.000000e+00
  %444 = fsub fast float %443, %424
  %445 = fsub fast float %444, %44
  %446 = call float @dx.op.unary.f32(i32 6, float %445)  ; FAbs(value)
  %447 = fcmp fast olt float %444, 0.000000e+00
  %448 = fcmp fast ogt float %444, 1.000000e+00
  %449 = or i1 %447, %448
  %450 = fcmp fast oge float %446, 0x4415AF1D80000000
  %451 = or i1 %449, %450
  %452 = select i1 %451, float 0x4415AF1D80000000, float %446
  %453 = select i1 %451, float 0.000000e+00, float %422
  %454 = select i1 %451, float 0.000000e+00, float %444
  %455 = xor i1 %451, true
  %456 = sext i1 %455 to i32
  br label %457

; <label>:457                                     ; preds = %442, %426, %420, %413, %408
  %458 = phi float [ 0x4415AF1D80000000, %408 ], [ 0x4415AF1D80000000, %413 ], [ 0x4415AF1D80000000, %426 ], [ 0x4415AF1D80000000, %420 ], [ %452, %442 ]
  %459 = phi float [ 0.000000e+00, %408 ], [ 0.000000e+00, %413 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %420 ], [ %453, %442 ]
  %460 = phi float [ 0.000000e+00, %408 ], [ 0.000000e+00, %413 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %420 ], [ %454, %442 ]
  %461 = phi i32 [ 0, %408 ], [ 0, %413 ], [ 0, %426 ], [ 0, %420 ], [ %456, %442 ]
  %462 = add i32 %173, 1
  %463 = add i32 %173, 2
  %464 = or i32 %462, %172
  %465 = icmp slt i32 %464, 0
  br i1 %465, label %508, label %466

; <label>:466                                     ; preds = %457
  %467 = or i32 %463, %172
  %468 = icmp slt i32 %462, %178
  %469 = icmp sgt i32 %467, -1
  %470 = and i1 %469, %468
  %471 = icmp slt i32 %463, %178
  %472 = and i1 %470, %471
  br i1 %472, label %473, label %508

; <label>:473                                     ; preds = %466
  %474 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %172, i32 %462, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %475 = extractvalue %dx.types.ResRet.f32 %474, 0
  %476 = call %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32 66, %dx.types.Handle %4, i32 0, i32 %172, i32 %463, i32 undef, i32 undef, i32 undef, i32 undef)  ; TextureLoad(srv,mipLevelOrSampleCount,coord0,coord1,coord2,offset0,offset1,offset2)
  %477 = extractvalue %dx.types.ResRet.f32 %476, 0
  %478 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %475)  ; IsFinite(value)
  br i1 %478, label %479, label %508

; <label>:479                                     ; preds = %473
  %480 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %477)  ; IsFinite(value)
  %481 = xor i1 %480, true
  %482 = fcmp fast olt float %475, 0.000000e+00
  %483 = or i1 %482, %481
  %484 = fcmp fast ogt float %475, 1.000000e+00
  %485 = or i1 %484, %483
  %486 = fcmp fast olt float %477, 0.000000e+00
  %487 = or i1 %486, %485
  %488 = fcmp fast ogt float %477, 1.000000e+00
  %489 = or i1 %488, %487
  %490 = xor i1 %489, true
  %491 = fcmp fast ogt float %475, 0x3EB0C6F7A0000000
  %492 = and i1 %491, %490
  %493 = fcmp fast ogt float %477, 0x3EB0C6F7A0000000
  %494 = and i1 %493, %492
  br i1 %494, label %495, label %508

; <label>:495                                     ; preds = %479
  %496 = fmul fast float %475, 2.000000e+00
  %497 = fsub fast float %496, %477
  %498 = fsub fast float %497, %44
  %499 = call float @dx.op.unary.f32(i32 6, float %498)  ; FAbs(value)
  %500 = fcmp fast olt float %497, 0.000000e+00
  %501 = fcmp fast ogt float %497, 1.000000e+00
  %502 = or i1 %500, %501
  %503 = fcmp fast oge float %499, %458
  %504 = or i1 %502, %503
  %505 = select i1 %504, float %459, float %475
  %506 = select i1 %504, float %460, float %497
  %507 = select i1 %504, i32 %461, i32 1
  br label %508

; <label>:508                                     ; preds = %495, %479, %473, %466, %457
  %509 = phi float [ %459, %457 ], [ %459, %466 ], [ %459, %479 ], [ %459, %473 ], [ %505, %495 ]
  %510 = phi float [ %460, %457 ], [ %460, %466 ], [ %460, %479 ], [ %460, %473 ], [ %506, %495 ]
  %511 = phi i32 [ %461, %457 ], [ %461, %466 ], [ %461, %479 ], [ %461, %473 ], [ %507, %495 ]
  %512 = icmp eq i32 %511, 0
  br i1 %512, label %615, label %513

; <label>:513                                     ; preds = %508
  %514 = uitofp i32 %172 to float
  %515 = uitofp i32 %173 to float
  %516 = fadd fast float %514, 5.000000e-01
  %517 = fadd fast float %515, 5.000000e-01
  %518 = fdiv fast float %516, %39
  %519 = fdiv fast float %517, %40
  %520 = fmul fast float %518, 2.000000e+00
  %521 = fmul fast float %519, 2.000000e+00
  %522 = fadd fast float %520, -1.000000e+00
  %523 = fadd fast float %521, -1.000000e+00
  %524 = fsub fast float -0.000000e+00, %523
  %525 = fmul fast float %522, %46
  %526 = call float @dx.op.tertiary.f32(i32 46, float %51, float %524, float %525)  ; FMad(a,b,c)
  %527 = call float @dx.op.tertiary.f32(i32 46, float %56, float %510, float %526)  ; FMad(a,b,c)
  %528 = fadd fast float %527, %61
  %529 = fmul fast float %522, %47
  %530 = call float @dx.op.tertiary.f32(i32 46, float %52, float %524, float %529)  ; FMad(a,b,c)
  %531 = call float @dx.op.tertiary.f32(i32 46, float %57, float %510, float %530)  ; FMad(a,b,c)
  %532 = fadd fast float %531, %62
  %533 = fmul fast float %522, %48
  %534 = call float @dx.op.tertiary.f32(i32 46, float %53, float %524, float %533)  ; FMad(a,b,c)
  %535 = call float @dx.op.tertiary.f32(i32 46, float %58, float %510, float %534)  ; FMad(a,b,c)
  %536 = fadd fast float %535, %63
  %537 = fmul fast float %522, %49
  %538 = call float @dx.op.tertiary.f32(i32 46, float %54, float %524, float %537)  ; FMad(a,b,c)
  %539 = call float @dx.op.tertiary.f32(i32 46, float %59, float %510, float %538)  ; FMad(a,b,c)
  %540 = fadd fast float %539, %64
  %541 = fdiv fast float %528, %540
  %542 = fdiv fast float %532, %540
  %543 = fdiv fast float %536, %540
  %544 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %541)  ; IsFinite(value)
  %545 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %542)  ; IsFinite(value)
  %546 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %543)  ; IsFinite(value)
  %547 = and i1 %544, %545
  %548 = and i1 %547, %546
  br i1 %548, label %549, label %615

; <label>:549                                     ; preds = %513
  %550 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 160)  ; CBufferLoadLegacy(handle,regIndex)
  %551 = extractvalue %dx.types.CBufRet.f32 %550, 2
  %552 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 159)  ; CBufferLoadLegacy(handle,regIndex)
  %553 = extractvalue %dx.types.CBufRet.f32 %552, 2
  %554 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 158)  ; CBufferLoadLegacy(handle,regIndex)
  %555 = extractvalue %dx.types.CBufRet.f32 %554, 2
  %556 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 157)  ; CBufferLoadLegacy(handle,regIndex)
  %557 = extractvalue %dx.types.CBufRet.f32 %556, 2
  %558 = fmul fast float %557, %86
  %559 = call float @dx.op.tertiary.f32(i32 46, float %555, float %87, float %558)  ; FMad(a,b,c)
  %560 = call float @dx.op.tertiary.f32(i32 46, float %553, float %88, float %559)  ; FMad(a,b,c)
  %561 = fadd fast float %560, %551
  %562 = call float @dx.op.unary.f32(i32 6, float %561)  ; FAbs(value)
  %563 = fmul fast float %562, 0x3F1A36E2E0000000
  %564 = call float @dx.op.binary.f32(i32 35, float 0x3F60624DE0000000, float %563)  ; FMax(a,b)
  %565 = fsub fast float %541, %86
  %566 = fsub fast float %542, %87
  %567 = fsub fast float %543, %88
  %568 = fmul fast float %565, %565
  %569 = fmul fast float %566, %566
  %570 = fadd fast float %569, %568
  %571 = fmul fast float %567, %567
  %572 = fadd fast float %570, %571
  %573 = call float @dx.op.unary.f32(i32 24, float %572)  ; Sqrt(value)
  %574 = fcmp fast ogt float %573, %564
  br i1 %574, label %615, label %575

; <label>:575                                     ; preds = %549
  %576 = add i32 %511, %173
  %577 = uitofp i32 %576 to float
  %578 = fadd fast float %577, 5.000000e-01
  %579 = fdiv fast float %578, %40
  %580 = fmul fast float %579, 2.000000e+00
  %581 = fadd fast float %580, -1.000000e+00
  %582 = fsub fast float -0.000000e+00, %581
  %583 = call float @dx.op.tertiary.f32(i32 46, float %51, float %582, float %525)  ; FMad(a,b,c)
  %584 = call float @dx.op.tertiary.f32(i32 46, float %56, float %509, float %583)  ; FMad(a,b,c)
  %585 = fadd fast float %584, %61
  %586 = call float @dx.op.tertiary.f32(i32 46, float %52, float %582, float %529)  ; FMad(a,b,c)
  %587 = call float @dx.op.tertiary.f32(i32 46, float %57, float %509, float %586)  ; FMad(a,b,c)
  %588 = fadd fast float %587, %62
  %589 = call float @dx.op.tertiary.f32(i32 46, float %53, float %582, float %533)  ; FMad(a,b,c)
  %590 = call float @dx.op.tertiary.f32(i32 46, float %58, float %509, float %589)  ; FMad(a,b,c)
  %591 = fadd fast float %590, %63
  %592 = call float @dx.op.tertiary.f32(i32 46, float %54, float %582, float %537)  ; FMad(a,b,c)
  %593 = call float @dx.op.tertiary.f32(i32 46, float %59, float %509, float %592)  ; FMad(a,b,c)
  %594 = fadd fast float %593, %64
  %595 = fdiv fast float %585, %594
  %596 = fdiv fast float %588, %594
  %597 = fdiv fast float %591, %594
  %598 = fsub fast float %595, %86
  %599 = fsub fast float %596, %87
  %600 = fsub fast float %597, %88
  %601 = sitofp i32 %511 to float
  %602 = fmul fast float %598, %601
  %603 = fmul fast float %599, %601
  %604 = fmul fast float %600, %601
  %605 = call float @dx.op.dot3.f32(i32 55, float %602, float %603, float %604, float %602, float %603, float %604)  ; Dot3(ax,ay,az,bx,by,bz)
  %606 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %602)  ; IsFinite(value)
  %607 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %603)  ; IsFinite(value)
  %608 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %604)  ; IsFinite(value)
  %609 = and i1 %606, %607
  %610 = and i1 %609, %608
  br i1 %610, label %611, label %615

; <label>:611                                     ; preds = %575
  %612 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %605)  ; IsFinite(value)
  %613 = fcmp uge float %605, 0x3C9CD2B2A0000000
  %614 = and i1 %613, %612
  br label %615

; <label>:615                                     ; preds = %611, %575, %549, %513, %508
  %616 = phi float [ 0.000000e+00, %508 ], [ 0.000000e+00, %549 ], [ 0.000000e+00, %513 ], [ %602, %575 ], [ %602, %611 ]
  %617 = phi float [ 0.000000e+00, %508 ], [ 0.000000e+00, %549 ], [ 0.000000e+00, %513 ], [ %603, %575 ], [ %603, %611 ]
  %618 = phi float [ 0.000000e+00, %508 ], [ 0.000000e+00, %549 ], [ 0.000000e+00, %513 ], [ %604, %575 ], [ %604, %611 ]
  %619 = phi i1 [ false, %508 ], [ false, %549 ], [ false, %513 ], [ false, %575 ], [ %614, %611 ]
  br i1 %619, label %620, label %626

; <label>:620                                     ; preds = %615
  %621 = call float @dx.op.dot3.f32(i32 55, float %616, float %617, float %618, float %616, float %617, float %618)  ; Dot3(ax,ay,az,bx,by,bz)
  %622 = call float @dx.op.unary.f32(i32 25, float %621)  ; Rsqrt(value)
  %623 = fmul fast float %622, %616
  %624 = fmul fast float %622, %617
  %625 = fmul fast float %622, %618
  br label %626

; <label>:626                                     ; preds = %620, %615
  %627 = phi float [ %623, %620 ], [ %616, %615 ]
  %628 = phi float [ %624, %620 ], [ %617, %615 ]
  %629 = phi float [ %625, %620 ], [ %618, %615 ]
  %630 = phi i1 [ true, %620 ], [ false, %615 ]
  br i1 %630, label %631, label %709

; <label>:631                                     ; preds = %626
  %632 = fmul fast float %629, %405
  %633 = fmul fast float %628, %406
  %634 = fsub fast float %632, %633
  %635 = fmul fast float %627, %406
  %636 = fmul fast float %629, %404
  %637 = fsub fast float %635, %636
  %638 = fmul fast float %628, %404
  %639 = fmul fast float %627, %405
  %640 = fsub fast float %638, %639
  %641 = call float @dx.op.dot3.f32(i32 55, float %634, float %637, float %640, float %634, float %637, float %640)  ; Dot3(ax,ay,az,bx,by,bz)
  %642 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %634)  ; IsFinite(value)
  %643 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %637)  ; IsFinite(value)
  %644 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %640)  ; IsFinite(value)
  %645 = and i1 %642, %643
  %646 = and i1 %645, %644
  br i1 %646, label %647, label %709

; <label>:647                                     ; preds = %631
  %648 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %641)  ; IsFinite(value)
  %649 = xor i1 %648, true
  %650 = fcmp fast olt float %641, 0x3EB0C6F7A0000000
  %651 = or i1 %650, %649
  br i1 %651, label %709, label %652

; <label>:652                                     ; preds = %647
  %653 = call float @dx.op.unary.f32(i32 25, float %641)  ; Rsqrt(value)
  %654 = fmul fast float %653, %634
  %655 = fmul fast float %653, %637
  %656 = fmul fast float %653, %640
  %657 = uitofp i32 %172 to float
  %658 = uitofp i32 %173 to float
  %659 = fadd fast float %657, 5.000000e-01
  %660 = fadd fast float %658, 5.000000e-01
  %661 = fdiv fast float %659, %39
  %662 = fdiv fast float %660, %40
  %663 = fmul fast float %661, 2.000000e+00
  %664 = fmul fast float %662, 2.000000e+00
  %665 = fadd fast float %663, -1.000000e+00
  %666 = fadd fast float %664, -1.000000e+00
  %667 = fsub fast float -0.000000e+00, %666
  %668 = fmul fast float %665, %46
  %669 = call float @dx.op.tertiary.f32(i32 46, float %51, float %667, float %668)  ; FMad(a,b,c)
  %670 = fadd fast float %61, %56
  %671 = fadd fast float %670, %669
  %672 = fmul fast float %665, %47
  %673 = call float @dx.op.tertiary.f32(i32 46, float %52, float %667, float %672)  ; FMad(a,b,c)
  %674 = fadd fast float %62, %57
  %675 = fadd fast float %674, %673
  %676 = fmul fast float %665, %48
  %677 = call float @dx.op.tertiary.f32(i32 46, float %53, float %667, float %676)  ; FMad(a,b,c)
  %678 = fadd fast float %63, %58
  %679 = fadd fast float %678, %677
  %680 = fmul fast float %665, %49
  %681 = call float @dx.op.tertiary.f32(i32 46, float %54, float %667, float %680)  ; FMad(a,b,c)
  %682 = fadd fast float %64, %59
  %683 = fadd fast float %682, %681
  %684 = fdiv fast float %671, %683
  %685 = fdiv fast float %675, %683
  %686 = fdiv fast float %679, %683
  %687 = fsub fast float %684, %86
  %688 = fsub fast float %685, %87
  %689 = fsub fast float %686, %88
  %690 = call float @dx.op.dot3.f32(i32 55, float %654, float %655, float %656, float %687, float %688, float %689)  ; Dot3(ax,ay,az,bx,by,bz)
  %691 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %687)  ; IsFinite(value)
  %692 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %688)  ; IsFinite(value)
  %693 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %689)  ; IsFinite(value)
  %694 = and i1 %691, %692
  %695 = and i1 %694, %693
  br i1 %695, label %696, label %709

; <label>:696                                     ; preds = %652
  %697 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %690)  ; IsFinite(value)
  br i1 %697, label %698, label %709

; <label>:698                                     ; preds = %696
  %699 = call float @dx.op.unary.f32(i32 6, float %690)  ; FAbs(value)
  %700 = fcmp fast olt float %699, 0x3E45798EE0000000
  br i1 %700, label %709, label %701

; <label>:701                                     ; preds = %698
  %702 = fcmp fast olt float %690, 0.000000e+00
  %703 = fsub fast float -0.000000e+00, %654
  %704 = fsub fast float -0.000000e+00, %655
  %705 = fsub fast float -0.000000e+00, %656
  %706 = select i1 %702, float %703, float %654
  %707 = select i1 %702, float %704, float %655
  %708 = select i1 %702, float %705, float %656
  br label %709

; <label>:709                                     ; preds = %701, %698, %696, %652, %647, %631, %626, %403, %176, %167, %161, %148
  %710 = phi float [ 0.000000e+00, %148 ], [ 0.000000e+00, %161 ], [ 0.000000e+00, %176 ], [ 0.000000e+00, %167 ], [ 0.000000e+00, %626 ], [ 0.000000e+00, %403 ], [ 0.000000e+00, %647 ], [ 0.000000e+00, %631 ], [ 0.000000e+00, %698 ], [ 0.000000e+00, %696 ], [ 0.000000e+00, %652 ], [ %706, %701 ]
  %711 = phi float [ 0.000000e+00, %148 ], [ 0.000000e+00, %161 ], [ 0.000000e+00, %176 ], [ 0.000000e+00, %167 ], [ 0.000000e+00, %626 ], [ 0.000000e+00, %403 ], [ 0.000000e+00, %647 ], [ 0.000000e+00, %631 ], [ 0.000000e+00, %698 ], [ 0.000000e+00, %696 ], [ 0.000000e+00, %652 ], [ %707, %701 ]
  %712 = phi float [ 0.000000e+00, %148 ], [ 0.000000e+00, %161 ], [ 0.000000e+00, %176 ], [ 0.000000e+00, %167 ], [ 0.000000e+00, %626 ], [ 0.000000e+00, %403 ], [ 0.000000e+00, %647 ], [ 0.000000e+00, %631 ], [ 0.000000e+00, %698 ], [ 0.000000e+00, %696 ], [ 0.000000e+00, %652 ], [ %708, %701 ]
  %713 = phi i1 [ false, %148 ], [ false, %161 ], [ false, %176 ], [ false, %167 ], [ false, %626 ], [ false, %403 ], [ false, %647 ], [ false, %631 ], [ false, %698 ], [ false, %696 ], [ false, %652 ], [ true, %701 ]
  br i1 %713, label %714, label %723

; <label>:714                                     ; preds = %709
  %715 = call float @dx.op.dot3.f32(i32 55, float %710, float %711, float %712, float %149, float %150, float %151)  ; Dot3(ax,ay,az,bx,by,bz)
  %716 = fcmp fast olt float %715, 0.000000e+00
  %717 = fsub fast float -0.000000e+00, %710
  %718 = fsub fast float -0.000000e+00, %711
  %719 = fsub fast float -0.000000e+00, %712
  %720 = select i1 %716, float %717, float %710
  %721 = select i1 %716, float %718, float %711
  %722 = select i1 %716, float %719, float %712
  br label %723

; <label>:723                                     ; preds = %714, %709
  %724 = phi float [ %720, %714 ], [ %149, %709 ]
  %725 = phi float [ %721, %714 ], [ %150, %709 ]
  %726 = phi float [ %722, %714 ], [ %151, %709 ]
  %727 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %728 = extractvalue %dx.types.CBufRet.f32 %727, 1
  %729 = fmul fast float %728, %724
  %730 = fmul fast float %728, %725
  %731 = fmul fast float %728, %726
  %732 = fadd fast float %729, %86
  %733 = fadd fast float %730, %87
  %734 = fadd fast float %731, %88
  %735 = mul i32 %23, %14
  %736 = add i32 %735, %13
  %737 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %738 = extractvalue %dx.types.CBufRet.i32 %737, 3
  %739 = add i32 %738, 1
  %740 = lshr i32 %739, 16
  %741 = xor i32 %740, %739
  %742 = mul i32 %741, 2146121005
  %743 = lshr i32 %742, 15
  %744 = xor i32 %743, %742
  %745 = mul i32 %744, -2073254261
  %746 = lshr i32 %745, 16
  %747 = xor i32 %746, %745
  %748 = add i32 %736, %747
  %749 = xor i32 %748, 1675113877
  %750 = lshr i32 %749, 16
  %751 = xor i32 %750, %749
  %752 = mul i32 %751, 2146121005
  %753 = lshr i32 %752, 15
  %754 = xor i32 %753, %752
  %755 = mul i32 %754, -1674769041
  %756 = lshr i32 %755, 15
  %757 = xor i32 %756, %755
  %758 = mul i32 %757, -1674769041
  %759 = lshr i32 %758, 15
  %760 = xor i32 %759, %758
  %761 = mul i32 %760, -2073254261
  %762 = lshr i32 %761, 16
  %763 = xor i32 %762, %761
  %764 = lshr i32 %763, 8
  %765 = uitofp i32 %764 to float
  %766 = fmul fast float %765, 0x3E70000000000000
  %767 = mul i32 %760, -1674769041
  %768 = lshr i32 %767, 15
  %769 = xor i32 %768, %767
  %770 = mul i32 %769, -2073254261
  %771 = lshr i32 %770, 16
  %772 = xor i32 %771, %770
  %773 = lshr i32 %772, 8
  %774 = uitofp i32 %773 to float
  %775 = call float @dx.op.unary.f32(i32 24, float %766)  ; Sqrt(value)
  %776 = fmul fast float %774, 0x3E9921FB60000000
  %777 = call float @dx.op.unary.f32(i32 6, float %151)  ; FAbs(value)
  %778 = fcmp fast olt float %777, 0x3FEFF7CEE0000000
  %779 = select i1 %778, float 0.000000e+00, float 1.000000e+00
  %780 = select i1 %778, float 1.000000e+00, float 0.000000e+00
  %781 = fmul fast float %779, %151
  %782 = fmul fast float %780, %150
  %783 = fsub fast float %781, %782
  %784 = fmul fast float %780, %149
  %785 = fmul fast float %149, %779
  %786 = fsub fast float -0.000000e+00, %785
  %787 = call float @dx.op.dot3.f32(i32 55, float %783, float %784, float %786, float %783, float %784, float %786)  ; Dot3(ax,ay,az,bx,by,bz)
  %788 = call float @dx.op.unary.f32(i32 25, float %787)  ; Rsqrt(value)
  %789 = fmul fast float %783, %788
  %790 = fmul fast float %784, %788
  %791 = fmul fast float %788, %786
  %792 = call float @dx.op.unary.f32(i32 12, float %776)  ; Cos(value)
  %793 = fmul fast float %792, %775
  %794 = fmul fast float %789, %793
  %795 = fmul fast float %790, %793
  %796 = fmul fast float %791, %793
  %797 = fmul fast float %791, %150
  %798 = fmul fast float %790, %151
  %799 = fsub fast float %797, %798
  %800 = fmul fast float %789, %151
  %801 = fmul fast float %791, %149
  %802 = fsub fast float %800, %801
  %803 = fmul fast float %790, %149
  %804 = fmul fast float %789, %150
  %805 = fsub fast float %803, %804
  %806 = call float @dx.op.unary.f32(i32 13, float %776)  ; Sin(value)
  %807 = fmul fast float %806, %775
  %808 = fmul fast float %799, %807
  %809 = fmul fast float %802, %807
  %810 = fmul fast float %805, %807
  %811 = fsub fast float 1.000000e+00, %766
  %812 = call float @dx.op.unary.f32(i32 24, float %811)  ; Sqrt(value)
  %813 = fmul fast float %812, %149
  %814 = fmul fast float %812, %150
  %815 = fmul fast float %812, %151
  %816 = fadd fast float %813, %794
  %817 = fadd fast float %816, %808
  %818 = fadd fast float %814, %795
  %819 = fadd fast float %818, %809
  %820 = fadd fast float %815, %796
  %821 = fadd fast float %820, %810
  %822 = mul i32 %7, 48
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %822, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %823 = or i32 %822, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %823, i32 0, float %817, float %819, float %821, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %824 = or i32 %822, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %824, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %825 = or i32 %822, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %825, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %826 = select i1 %713, float 1.000000e+00, float 0.000000e+00
  %827 = or i32 %822, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %827, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %828 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %829 = extractvalue %dx.types.CBufRet.i32 %828, 3
  %830 = bitcast i32 %13 to float
  %831 = bitcast i32 %14 to float
  %832 = bitcast i32 %829 to float
  %833 = or i32 %822, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %833, i32 0, float %830, float %831, float %832, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %834 = mul i32 %769, -1674769041
  %835 = lshr i32 %834, 15
  %836 = xor i32 %835, %834
  %837 = mul i32 %836, -1674769041
  %838 = lshr i32 %837, 15
  %839 = xor i32 %838, %837
  %840 = mul i32 %839, -2073254261
  %841 = lshr i32 %840, 16
  %842 = xor i32 %841, %840
  %843 = lshr i32 %842, 8
  %844 = uitofp i32 %843 to float
  %845 = fmul fast float %844, 0x3E70000000000000
  %846 = mul i32 %839, -1674769041
  %847 = lshr i32 %846, 15
  %848 = xor i32 %847, %846
  %849 = mul i32 %848, -2073254261
  %850 = lshr i32 %849, 16
  %851 = xor i32 %850, %849
  %852 = lshr i32 %851, 8
  %853 = uitofp i32 %852 to float
  %854 = call float @dx.op.unary.f32(i32 24, float %845)  ; Sqrt(value)
  %855 = fmul fast float %853, 0x3E9921FB60000000
  %856 = call float @dx.op.unary.f32(i32 12, float %855)  ; Cos(value)
  %857 = fmul fast float %856, %854
  %858 = fmul fast float %857, %789
  %859 = fmul fast float %857, %790
  %860 = fmul fast float %857, %791
  %861 = call float @dx.op.unary.f32(i32 13, float %855)  ; Sin(value)
  %862 = fmul fast float %861, %854
  %863 = fmul fast float %862, %799
  %864 = fmul fast float %862, %802
  %865 = fmul fast float %862, %805
  %866 = fsub fast float 1.000000e+00, %845
  %867 = call float @dx.op.unary.f32(i32 24, float %866)  ; Sqrt(value)
  %868 = fmul fast float %867, %149
  %869 = fmul fast float %867, %150
  %870 = fmul fast float %867, %151
  %871 = fadd fast float %868, %858
  %872 = fadd fast float %871, %863
  %873 = fadd fast float %869, %859
  %874 = fadd fast float %873, %864
  %875 = fadd fast float %870, %860
  %876 = fadd fast float %875, %865
  %877 = shl i32 %7, 3
  %878 = or i32 %877, 1
  %879 = mul i32 %878, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %879, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %880 = or i32 %879, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %880, i32 0, float %872, float %874, float %876, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %881 = add i32 %879, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %881, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %882 = add i32 %879, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %882, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %883 = add i32 %879, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %883, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %884 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %885 = extractvalue %dx.types.CBufRet.i32 %884, 3
  %886 = bitcast i32 %885 to float
  %887 = add i32 %879, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %887, i32 0, float %830, float %831, float %886, float 0x36A0000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %888 = mul i32 %848, -1674769041
  %889 = lshr i32 %888, 15
  %890 = xor i32 %889, %888
  %891 = mul i32 %890, -1674769041
  %892 = lshr i32 %891, 15
  %893 = xor i32 %892, %891
  %894 = mul i32 %893, -2073254261
  %895 = lshr i32 %894, 16
  %896 = xor i32 %895, %894
  %897 = lshr i32 %896, 8
  %898 = uitofp i32 %897 to float
  %899 = fmul fast float %898, 0x3E70000000000000
  %900 = mul i32 %893, -1674769041
  %901 = lshr i32 %900, 15
  %902 = xor i32 %901, %900
  %903 = mul i32 %902, -2073254261
  %904 = lshr i32 %903, 16
  %905 = xor i32 %904, %903
  %906 = lshr i32 %905, 8
  %907 = uitofp i32 %906 to float
  %908 = call float @dx.op.unary.f32(i32 24, float %899)  ; Sqrt(value)
  %909 = fmul fast float %907, 0x3E9921FB60000000
  %910 = call float @dx.op.unary.f32(i32 12, float %909)  ; Cos(value)
  %911 = fmul fast float %910, %908
  %912 = fmul fast float %911, %789
  %913 = fmul fast float %911, %790
  %914 = fmul fast float %911, %791
  %915 = call float @dx.op.unary.f32(i32 13, float %909)  ; Sin(value)
  %916 = fmul fast float %915, %908
  %917 = fmul fast float %916, %799
  %918 = fmul fast float %916, %802
  %919 = fmul fast float %916, %805
  %920 = fsub fast float 1.000000e+00, %899
  %921 = call float @dx.op.unary.f32(i32 24, float %920)  ; Sqrt(value)
  %922 = fmul fast float %921, %149
  %923 = fmul fast float %921, %150
  %924 = fmul fast float %921, %151
  %925 = fadd fast float %922, %912
  %926 = fadd fast float %925, %917
  %927 = fadd fast float %923, %913
  %928 = fadd fast float %927, %918
  %929 = fadd fast float %924, %914
  %930 = fadd fast float %929, %919
  %931 = or i32 %877, 2
  %932 = mul i32 %931, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %932, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %933 = or i32 %932, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %933, i32 0, float %926, float %928, float %930, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %934 = or i32 %932, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %934, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %935 = or i32 %932, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %935, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %936 = add i32 %932, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %936, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %937 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %938 = extractvalue %dx.types.CBufRet.i32 %937, 3
  %939 = bitcast i32 %938 to float
  %940 = add i32 %932, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %940, i32 0, float %830, float %831, float %939, float 0x36B0000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %941 = mul i32 %902, -1674769041
  %942 = lshr i32 %941, 15
  %943 = xor i32 %942, %941
  %944 = mul i32 %943, -1674769041
  %945 = lshr i32 %944, 15
  %946 = xor i32 %945, %944
  %947 = mul i32 %946, -2073254261
  %948 = lshr i32 %947, 16
  %949 = xor i32 %948, %947
  %950 = lshr i32 %949, 8
  %951 = uitofp i32 %950 to float
  %952 = fmul fast float %951, 0x3E70000000000000
  %953 = mul i32 %946, -1674769041
  %954 = lshr i32 %953, 15
  %955 = xor i32 %954, %953
  %956 = mul i32 %955, -2073254261
  %957 = lshr i32 %956, 16
  %958 = xor i32 %957, %956
  %959 = lshr i32 %958, 8
  %960 = uitofp i32 %959 to float
  %961 = call float @dx.op.unary.f32(i32 24, float %952)  ; Sqrt(value)
  %962 = fmul fast float %960, 0x3E9921FB60000000
  %963 = call float @dx.op.unary.f32(i32 12, float %962)  ; Cos(value)
  %964 = fmul fast float %963, %961
  %965 = fmul fast float %964, %789
  %966 = fmul fast float %964, %790
  %967 = fmul fast float %964, %791
  %968 = call float @dx.op.unary.f32(i32 13, float %962)  ; Sin(value)
  %969 = fmul fast float %968, %961
  %970 = fmul fast float %969, %799
  %971 = fmul fast float %969, %802
  %972 = fmul fast float %969, %805
  %973 = fsub fast float 1.000000e+00, %952
  %974 = call float @dx.op.unary.f32(i32 24, float %973)  ; Sqrt(value)
  %975 = fmul fast float %974, %149
  %976 = fmul fast float %974, %150
  %977 = fmul fast float %974, %151
  %978 = fadd fast float %975, %965
  %979 = fadd fast float %978, %970
  %980 = fadd fast float %976, %966
  %981 = fadd fast float %980, %971
  %982 = fadd fast float %977, %967
  %983 = fadd fast float %982, %972
  %984 = or i32 %877, 3
  %985 = mul i32 %984, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %985, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %986 = or i32 %985, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %986, i32 0, float %979, float %981, float %983, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %987 = add i32 %985, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %987, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %988 = add i32 %985, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %988, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %989 = add i32 %985, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %989, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %990 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %991 = extractvalue %dx.types.CBufRet.i32 %990, 3
  %992 = bitcast i32 %991 to float
  %993 = add i32 %985, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %993, i32 0, float %830, float %831, float %992, float 0x36B8000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %994 = mul i32 %955, -1674769041
  %995 = lshr i32 %994, 15
  %996 = xor i32 %995, %994
  %997 = mul i32 %996, -1674769041
  %998 = lshr i32 %997, 15
  %999 = xor i32 %998, %997
  %1000 = mul i32 %999, -2073254261
  %1001 = lshr i32 %1000, 16
  %1002 = xor i32 %1001, %1000
  %1003 = lshr i32 %1002, 8
  %1004 = uitofp i32 %1003 to float
  %1005 = fmul fast float %1004, 0x3E70000000000000
  %1006 = mul i32 %999, -1674769041
  %1007 = lshr i32 %1006, 15
  %1008 = xor i32 %1007, %1006
  %1009 = mul i32 %1008, -2073254261
  %1010 = lshr i32 %1009, 16
  %1011 = xor i32 %1010, %1009
  %1012 = lshr i32 %1011, 8
  %1013 = uitofp i32 %1012 to float
  %1014 = call float @dx.op.unary.f32(i32 24, float %1005)  ; Sqrt(value)
  %1015 = fmul fast float %1013, 0x3E9921FB60000000
  %1016 = call float @dx.op.unary.f32(i32 12, float %1015)  ; Cos(value)
  %1017 = fmul fast float %1016, %1014
  %1018 = fmul fast float %1017, %789
  %1019 = fmul fast float %1017, %790
  %1020 = fmul fast float %1017, %791
  %1021 = call float @dx.op.unary.f32(i32 13, float %1015)  ; Sin(value)
  %1022 = fmul fast float %1021, %1014
  %1023 = fmul fast float %1022, %799
  %1024 = fmul fast float %1022, %802
  %1025 = fmul fast float %1022, %805
  %1026 = fsub fast float 1.000000e+00, %1005
  %1027 = call float @dx.op.unary.f32(i32 24, float %1026)  ; Sqrt(value)
  %1028 = fmul fast float %1027, %149
  %1029 = fmul fast float %1027, %150
  %1030 = fmul fast float %1027, %151
  %1031 = fadd fast float %1028, %1018
  %1032 = fadd fast float %1031, %1023
  %1033 = fadd fast float %1029, %1019
  %1034 = fadd fast float %1033, %1024
  %1035 = fadd fast float %1030, %1020
  %1036 = fadd fast float %1035, %1025
  %1037 = or i32 %877, 4
  %1038 = mul i32 %1037, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1038, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1039 = or i32 %1038, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1039, i32 0, float %1032, float %1034, float %1036, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1040 = or i32 %1038, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1040, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1041 = or i32 %1038, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1041, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1042 = or i32 %1038, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1042, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1043 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %1044 = extractvalue %dx.types.CBufRet.i32 %1043, 3
  %1045 = bitcast i32 %1044 to float
  %1046 = or i32 %1038, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1046, i32 0, float %830, float %831, float %1045, float 0x36C0000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1047 = mul i32 %1008, -1674769041
  %1048 = lshr i32 %1047, 15
  %1049 = xor i32 %1048, %1047
  %1050 = mul i32 %1049, -1674769041
  %1051 = lshr i32 %1050, 15
  %1052 = xor i32 %1051, %1050
  %1053 = mul i32 %1052, -2073254261
  %1054 = lshr i32 %1053, 16
  %1055 = xor i32 %1054, %1053
  %1056 = lshr i32 %1055, 8
  %1057 = uitofp i32 %1056 to float
  %1058 = fmul fast float %1057, 0x3E70000000000000
  %1059 = mul i32 %1052, -1674769041
  %1060 = lshr i32 %1059, 15
  %1061 = xor i32 %1060, %1059
  %1062 = mul i32 %1061, -2073254261
  %1063 = lshr i32 %1062, 16
  %1064 = xor i32 %1063, %1062
  %1065 = lshr i32 %1064, 8
  %1066 = uitofp i32 %1065 to float
  %1067 = call float @dx.op.unary.f32(i32 24, float %1058)  ; Sqrt(value)
  %1068 = fmul fast float %1066, 0x3E9921FB60000000
  %1069 = call float @dx.op.unary.f32(i32 12, float %1068)  ; Cos(value)
  %1070 = fmul fast float %1069, %1067
  %1071 = fmul fast float %1070, %789
  %1072 = fmul fast float %1070, %790
  %1073 = fmul fast float %1070, %791
  %1074 = call float @dx.op.unary.f32(i32 13, float %1068)  ; Sin(value)
  %1075 = fmul fast float %1074, %1067
  %1076 = fmul fast float %1075, %799
  %1077 = fmul fast float %1075, %802
  %1078 = fmul fast float %1075, %805
  %1079 = fsub fast float 1.000000e+00, %1058
  %1080 = call float @dx.op.unary.f32(i32 24, float %1079)  ; Sqrt(value)
  %1081 = fmul fast float %1080, %149
  %1082 = fmul fast float %1080, %150
  %1083 = fmul fast float %1080, %151
  %1084 = fadd fast float %1081, %1071
  %1085 = fadd fast float %1084, %1076
  %1086 = fadd fast float %1082, %1072
  %1087 = fadd fast float %1086, %1077
  %1088 = fadd fast float %1083, %1073
  %1089 = fadd fast float %1088, %1078
  %1090 = or i32 %877, 5
  %1091 = mul i32 %1090, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1091, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1092 = or i32 %1091, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1092, i32 0, float %1085, float %1087, float %1089, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1093 = add i32 %1091, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1093, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1094 = add i32 %1091, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1094, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1095 = add i32 %1091, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1095, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1096 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %1097 = extractvalue %dx.types.CBufRet.i32 %1096, 3
  %1098 = bitcast i32 %1097 to float
  %1099 = add i32 %1091, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1099, i32 0, float %830, float %831, float %1098, float 0x36C4000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1100 = mul i32 %1061, -1674769041
  %1101 = lshr i32 %1100, 15
  %1102 = xor i32 %1101, %1100
  %1103 = mul i32 %1102, -1674769041
  %1104 = lshr i32 %1103, 15
  %1105 = xor i32 %1104, %1103
  %1106 = mul i32 %1105, -2073254261
  %1107 = lshr i32 %1106, 16
  %1108 = xor i32 %1107, %1106
  %1109 = lshr i32 %1108, 8
  %1110 = uitofp i32 %1109 to float
  %1111 = fmul fast float %1110, 0x3E70000000000000
  %1112 = mul i32 %1105, -1674769041
  %1113 = lshr i32 %1112, 15
  %1114 = xor i32 %1113, %1112
  %1115 = mul i32 %1114, -2073254261
  %1116 = lshr i32 %1115, 16
  %1117 = xor i32 %1116, %1115
  %1118 = lshr i32 %1117, 8
  %1119 = uitofp i32 %1118 to float
  %1120 = call float @dx.op.unary.f32(i32 24, float %1111)  ; Sqrt(value)
  %1121 = fmul fast float %1119, 0x3E9921FB60000000
  %1122 = call float @dx.op.unary.f32(i32 12, float %1121)  ; Cos(value)
  %1123 = fmul fast float %1122, %1120
  %1124 = fmul fast float %1123, %789
  %1125 = fmul fast float %1123, %790
  %1126 = fmul fast float %1123, %791
  %1127 = call float @dx.op.unary.f32(i32 13, float %1121)  ; Sin(value)
  %1128 = fmul fast float %1127, %1120
  %1129 = fmul fast float %1128, %799
  %1130 = fmul fast float %1128, %802
  %1131 = fmul fast float %1128, %805
  %1132 = fsub fast float 1.000000e+00, %1111
  %1133 = call float @dx.op.unary.f32(i32 24, float %1132)  ; Sqrt(value)
  %1134 = fmul fast float %1133, %149
  %1135 = fmul fast float %1133, %150
  %1136 = fmul fast float %1133, %151
  %1137 = fadd fast float %1134, %1124
  %1138 = fadd fast float %1137, %1129
  %1139 = fadd fast float %1135, %1125
  %1140 = fadd fast float %1139, %1130
  %1141 = fadd fast float %1136, %1126
  %1142 = fadd fast float %1141, %1131
  %1143 = or i32 %877, 6
  %1144 = mul i32 %1143, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1144, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1145 = or i32 %1144, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1145, i32 0, float %1138, float %1140, float %1142, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1146 = or i32 %1144, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1146, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1147 = or i32 %1144, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1147, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1148 = add i32 %1144, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1148, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1149 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %1150 = extractvalue %dx.types.CBufRet.i32 %1149, 3
  %1151 = bitcast i32 %1150 to float
  %1152 = add i32 %1144, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1152, i32 0, float %830, float %831, float %1151, float 0x36C8000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1153 = mul i32 %1114, -1674769041
  %1154 = lshr i32 %1153, 15
  %1155 = xor i32 %1154, %1153
  %1156 = mul i32 %1155, -1674769041
  %1157 = lshr i32 %1156, 15
  %1158 = xor i32 %1157, %1156
  %1159 = mul i32 %1158, -2073254261
  %1160 = lshr i32 %1159, 16
  %1161 = xor i32 %1160, %1159
  %1162 = lshr i32 %1161, 8
  %1163 = uitofp i32 %1162 to float
  %1164 = fmul fast float %1163, 0x3E70000000000000
  %1165 = mul i32 %1158, -1674769041
  %1166 = lshr i32 %1165, 15
  %1167 = xor i32 %1166, %1165
  %1168 = mul i32 %1167, -2073254261
  %1169 = lshr i32 %1168, 16
  %1170 = xor i32 %1169, %1168
  %1171 = lshr i32 %1170, 8
  %1172 = uitofp i32 %1171 to float
  %1173 = call float @dx.op.unary.f32(i32 24, float %1164)  ; Sqrt(value)
  %1174 = fmul fast float %1172, 0x3E9921FB60000000
  %1175 = call float @dx.op.unary.f32(i32 12, float %1174)  ; Cos(value)
  %1176 = fmul fast float %1175, %1173
  %1177 = fmul fast float %1176, %789
  %1178 = fmul fast float %1176, %790
  %1179 = fmul fast float %1176, %791
  %1180 = call float @dx.op.unary.f32(i32 13, float %1174)  ; Sin(value)
  %1181 = fmul fast float %1180, %1173
  %1182 = fmul fast float %1181, %799
  %1183 = fmul fast float %1181, %802
  %1184 = fmul fast float %1181, %805
  %1185 = fsub fast float 1.000000e+00, %1164
  %1186 = call float @dx.op.unary.f32(i32 24, float %1185)  ; Sqrt(value)
  %1187 = fmul fast float %1186, %149
  %1188 = fmul fast float %1186, %150
  %1189 = fmul fast float %1186, %151
  %1190 = fadd fast float %1187, %1177
  %1191 = fadd fast float %1190, %1182
  %1192 = fadd fast float %1188, %1178
  %1193 = fadd fast float %1192, %1183
  %1194 = fadd fast float %1189, %1179
  %1195 = fadd fast float %1194, %1184
  %1196 = or i32 %877, 7
  %1197 = mul i32 %1196, 6
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1197, i32 0, float %732, float %733, float %734, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1198 = or i32 %1197, 1
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1198, i32 0, float %1191, float %1193, float %1195, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1199 = add i32 %1197, 2
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1199, i32 0, float %86, float %87, float %88, float %44, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1200 = add i32 %1197, 3
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1200, i32 0, float %149, float %150, float %151, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1201 = add i32 %1197, 4
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1201, i32 0, float %710, float %711, float %712, float %826, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %1202 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %1203 = extractvalue %dx.types.CBufRet.i32 %1202, 3
  %1204 = bitcast i32 %1203 to float
  %1205 = add i32 %1197, 5
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %1205, i32 0, float %830, float %831, float %1204, float 0x36CC000000000000, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %1206

; <label>:1206                                    ; preds = %723, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.textureLoad.f32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32, %dx.types.Handle, %dx.types.Handle, float, float, float, float, i32, i32, i32, float) #1

; Function Attrs: nounwind readnone
declare float @dx.op.dot3.f32(i32, float, float, float, float, float, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.binary.f32(i32, float, float) #0

; Function Attrs: nounwind readnone
declare i1 @dx.op.isSpecialFloat.f32(i32, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readnone
declare float @dx.op.tertiary.f32(i32, float, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.i32 @dx.op.bufferLoad.i32(i32, %dx.types.Handle, i32, i32) #1

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
!14 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2668, null}
!15 = !{!16}
!16 = !{i32 0, %struct.SamplerState* undef, !"", i32 0, i32 0, i32 1, i32 0, null}
!17 = !{void ()* @CSFiniteWallOcclusionInputs, !"CSFiniteWallOcclusionInputs", null, !4, !18}
!18 = !{i32 0, i64 16, i32 4, !19}
!19 = !{i32 64, i32 1, i32 1}
