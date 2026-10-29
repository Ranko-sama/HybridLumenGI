;
; Input signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; POSITION                 0   xyz         0     NONE   float   xyz 
; TEXCOORD                 0   xy          1     NONE   float   xy  
;
;
; Output signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Position              0   xyzw        0      POS   float   xyzw
; TEXCOORD                 0   xy          1     NONE   float   xy  
;
; shader hash: 978e4c99a7748650adfffad3be1eca1f
;
; Pipeline Runtime Information: 
;
;PSVRuntimeInfo:
; Vertex Shader
; OutputPositionPresent=1
; MinimumExpectedWaveLaneCount: 0
; MaximumExpectedWaveLaneCount: 4294967295
; UsesViewID: false
; SigInputElements: 2
; SigOutputElements: 2
; SigPatchConstOrPrimElements: 0
; SigInputVectors: 2
; SigOutputVectors[0]: 2
; SigOutputVectors[1]: 0
; SigOutputVectors[2]: 0
; SigOutputVectors[3]: 0
; EntryFunctionName: HLGIIdentityVertex
;
;
; Input signature:
;
; Name                 Index             InterpMode DynIdx
; -------------------- ----- ---------------------- ------
; POSITION                 0                              
; TEXCOORD                 0                              
;
; Output signature:
;
; Name                 Index             InterpMode DynIdx
; -------------------- ----- ---------------------- ------
; SV_Position              0          noperspective       
; TEXCOORD                 0                 linear       
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
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; $Globals                          cbuffer      NA          NA     CB0            cb0     1
;
;
; ViewId state:
;
; Number of inputs: 6, outputs: 6
; Outputs dependent on ViewId: {  }
; Inputs contributing to computation of Outputs:
;   output 0 depends on inputs: { 0, 1, 2 }
;   output 1 depends on inputs: { 0, 1, 2 }
;   output 2 depends on inputs: { 0, 1, 2 }
;   output 3 depends on inputs: { 0, 1, 2 }
;   output 4 depends on inputs: { 4 }
;   output 5 depends on inputs: { 5 }
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%"hostlayout.$Globals" = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <2 x float>, float, <4 x float>, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, i32, float, <4 x float>, <4 x float>, i32, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <3 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, i32, <4 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, [6 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <4 x float>, float, i32, <4 x float>, float }

define void @HLGIIdentityVertex() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %3 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %4 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %5 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %6 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %7 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 129)  ; CBufferLoadLegacy(handle,regIndex)
  %8 = extractvalue %dx.types.CBufRet.f32 %7, 0
  %9 = extractvalue %dx.types.CBufRet.f32 %7, 1
  %10 = extractvalue %dx.types.CBufRet.f32 %7, 2
  %11 = extractvalue %dx.types.CBufRet.f32 %7, 3
  %12 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 130)  ; CBufferLoadLegacy(handle,regIndex)
  %13 = extractvalue %dx.types.CBufRet.f32 %12, 0
  %14 = extractvalue %dx.types.CBufRet.f32 %12, 1
  %15 = extractvalue %dx.types.CBufRet.f32 %12, 2
  %16 = extractvalue %dx.types.CBufRet.f32 %12, 3
  %17 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 131)  ; CBufferLoadLegacy(handle,regIndex)
  %18 = extractvalue %dx.types.CBufRet.f32 %17, 0
  %19 = extractvalue %dx.types.CBufRet.f32 %17, 1
  %20 = extractvalue %dx.types.CBufRet.f32 %17, 2
  %21 = extractvalue %dx.types.CBufRet.f32 %17, 3
  %22 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 132)  ; CBufferLoadLegacy(handle,regIndex)
  %23 = extractvalue %dx.types.CBufRet.f32 %22, 0
  %24 = extractvalue %dx.types.CBufRet.f32 %22, 1
  %25 = extractvalue %dx.types.CBufRet.f32 %22, 2
  %26 = extractvalue %dx.types.CBufRet.f32 %22, 3
  %27 = fmul fast float %8, %4
  %28 = call float @dx.op.tertiary.f32(i32 46, float %13, float %5, float %27)  ; FMad(a,b,c)
  %29 = call float @dx.op.tertiary.f32(i32 46, float %18, float %6, float %28)  ; FMad(a,b,c)
  %30 = fadd fast float %29, %23
  %31 = fmul fast float %9, %4
  %32 = call float @dx.op.tertiary.f32(i32 46, float %14, float %5, float %31)  ; FMad(a,b,c)
  %33 = call float @dx.op.tertiary.f32(i32 46, float %19, float %6, float %32)  ; FMad(a,b,c)
  %34 = fadd fast float %33, %24
  %35 = fmul fast float %10, %4
  %36 = call float @dx.op.tertiary.f32(i32 46, float %15, float %5, float %35)  ; FMad(a,b,c)
  %37 = call float @dx.op.tertiary.f32(i32 46, float %20, float %6, float %36)  ; FMad(a,b,c)
  %38 = fadd fast float %37, %25
  %39 = fmul fast float %11, %4
  %40 = call float @dx.op.tertiary.f32(i32 46, float %16, float %5, float %39)  ; FMad(a,b,c)
  %41 = call float @dx.op.tertiary.f32(i32 46, float %21, float %6, float %40)  ; FMad(a,b,c)
  %42 = fadd fast float %41, %26
  %43 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 133)  ; CBufferLoadLegacy(handle,regIndex)
  %44 = extractvalue %dx.types.CBufRet.f32 %43, 0
  %45 = extractvalue %dx.types.CBufRet.f32 %43, 1
  %46 = extractvalue %dx.types.CBufRet.f32 %43, 2
  %47 = extractvalue %dx.types.CBufRet.f32 %43, 3
  %48 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 134)  ; CBufferLoadLegacy(handle,regIndex)
  %49 = extractvalue %dx.types.CBufRet.f32 %48, 0
  %50 = extractvalue %dx.types.CBufRet.f32 %48, 1
  %51 = extractvalue %dx.types.CBufRet.f32 %48, 2
  %52 = extractvalue %dx.types.CBufRet.f32 %48, 3
  %53 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 135)  ; CBufferLoadLegacy(handle,regIndex)
  %54 = extractvalue %dx.types.CBufRet.f32 %53, 0
  %55 = extractvalue %dx.types.CBufRet.f32 %53, 1
  %56 = extractvalue %dx.types.CBufRet.f32 %53, 2
  %57 = extractvalue %dx.types.CBufRet.f32 %53, 3
  %58 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 136)  ; CBufferLoadLegacy(handle,regIndex)
  %59 = extractvalue %dx.types.CBufRet.f32 %58, 0
  %60 = extractvalue %dx.types.CBufRet.f32 %58, 1
  %61 = extractvalue %dx.types.CBufRet.f32 %58, 2
  %62 = extractvalue %dx.types.CBufRet.f32 %58, 3
  %63 = fmul fast float %44, %30
  %64 = call float @dx.op.tertiary.f32(i32 46, float %49, float %34, float %63)  ; FMad(a,b,c)
  %65 = call float @dx.op.tertiary.f32(i32 46, float %54, float %38, float %64)  ; FMad(a,b,c)
  %66 = call float @dx.op.tertiary.f32(i32 46, float %59, float %42, float %65)  ; FMad(a,b,c)
  %67 = fmul fast float %45, %30
  %68 = call float @dx.op.tertiary.f32(i32 46, float %50, float %34, float %67)  ; FMad(a,b,c)
  %69 = call float @dx.op.tertiary.f32(i32 46, float %55, float %38, float %68)  ; FMad(a,b,c)
  %70 = call float @dx.op.tertiary.f32(i32 46, float %60, float %42, float %69)  ; FMad(a,b,c)
  %71 = fmul fast float %46, %30
  %72 = call float @dx.op.tertiary.f32(i32 46, float %51, float %34, float %71)  ; FMad(a,b,c)
  %73 = call float @dx.op.tertiary.f32(i32 46, float %56, float %38, float %72)  ; FMad(a,b,c)
  %74 = call float @dx.op.tertiary.f32(i32 46, float %61, float %42, float %73)  ; FMad(a,b,c)
  %75 = fmul fast float %47, %30
  %76 = call float @dx.op.tertiary.f32(i32 46, float %52, float %34, float %75)  ; FMad(a,b,c)
  %77 = call float @dx.op.tertiary.f32(i32 46, float %57, float %38, float %76)  ; FMad(a,b,c)
  %78 = call float @dx.op.tertiary.f32(i32 46, float %62, float %42, float %77)  ; FMad(a,b,c)
  %79 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %1, i32 137)  ; CBufferLoadLegacy(handle,regIndex)
  %80 = extractvalue %dx.types.CBufRet.f32 %79, 0
  %81 = extractvalue %dx.types.CBufRet.f32 %79, 1
  %82 = fmul fast float %80, %2
  %83 = fmul fast float %81, %3
  %84 = extractvalue %dx.types.CBufRet.f32 %79, 2
  %85 = extractvalue %dx.types.CBufRet.f32 %79, 3
  %86 = fadd fast float %82, %84
  %87 = fadd fast float %83, %85
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 0, float %66)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 1, float %70)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 2, float %74)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 3, float %78)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 0, float %86)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 1, float %87)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  ret void
}

; Function Attrs: nounwind readnone
declare float @dx.op.loadInput.f32(i32, i32, i32, i8, i32) #0

; Function Attrs: nounwind
declare void @dx.op.storeOutput.f32(i32, i32, i32, i8, float) #1

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #2

; Function Attrs: nounwind readnone
declare float @dx.op.tertiary.f32(i32, float, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #2

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind }
attributes #2 = { nounwind readonly }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.viewIdState = !{!7}
!dx.entryPoints = !{!8}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"vs", i32 6, i32 0}
!4 = !{null, null, !5, null}
!5 = !{!6}
!6 = !{i32 0, %"hostlayout.$Globals"* undef, !"", i32 0, i32 0, i32 1, i32 2260, null}
!7 = !{[8 x i32] [i32 6, i32 6, i32 15, i32 15, i32 15, i32 0, i32 16, i32 32]}
!8 = !{void ()* @HLGIIdentityVertex, !"HLGIIdentityVertex", !9, !4, null}
!9 = !{!10, !16, null}
!10 = !{!11, !14}
!11 = !{i32 0, !"POSITION", i8 9, i8 0, !12, i8 0, i32 1, i8 3, i32 0, i8 0, !13}
!12 = !{i32 0}
!13 = !{i32 3, i32 7}
!14 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !12, i8 0, i32 1, i8 2, i32 1, i8 0, !15}
!15 = !{i32 3, i32 3}
!16 = !{!17, !19}
!17 = !{i32 0, !"SV_Position", i8 9, i8 3, !12, i8 4, i32 1, i8 4, i32 0, i8 0, !18}
!18 = !{i32 3, i32 15}
!19 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !12, i8 2, i32 1, i8 2, i32 1, i8 0, !15}
