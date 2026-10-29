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
; shader hash: 5dae339eb3b2ea80bed713277f95627d
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
; EntryFunctionName: CSSurfaceParallax
;
;
; Buffer Definitions:
;
; cbuffer TestCounts
; {
;
;   struct TestCounts
;   {
;
;       uint _Count;                                  ; Offset:    0
;   
;   } TestCounts;                                     ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _Inputs
; {
;
;   struct struct.RadianceInput
;   {
;
;       float4 incoming;                              ; Offset:    0
;       float4 control;                               ; Offset:   16
;       float4 initialSum;                            ; Offset:   32
;       float4 irradiance;                            ; Offset:   48
;       float4 guide;                                 ; Offset:   64
;       float4 history;                               ; Offset:   80
;       float4 moments;                               ; Offset:   96
;       uint4 hitSpec;                                ; Offset:  112
;       float4 guideSumPower;                         ; Offset:  128
;       float4 normal;                                ; Offset:  144
;       uint4 purpose;                                ; Offset:  160
;       float4 footprint;                             ; Offset:  176
;       float4 connection;                            ; Offset:  192
;   
;   } $Element;                                       ; Offset:    0 Size:   208
;
; }
;
; Resource bind info for _Outputs
; {
;
;   struct struct.RadianceOutput
;   {
;
;       float4 sum;                                   ; Offset:    0
;       float4 irradiance;                            ; Offset:   16
;       float4 guide;                                 ; Offset:   32
;       float4 history;                               ; Offset:   48
;       float4 moments;                               ; Offset:   64
;       float4 screen;                                ; Offset:   80
;       float4 proxy;                                 ; Offset:   96
;       float4 direct;                                ; Offset:  112
;       uint4 predicates;                             ; Offset:  128
;       uint4 validity;                               ; Offset:  144
;       float4 propagatedIrradiance;                  ; Offset:  160
;       float4 propagatedGuide;                       ; Offset:  176
;       float4 unshadowedDirect;                      ; Offset:  192
;       uint4 coverage;                               ; Offset:  208
;       uint4 resolved;                               ; Offset:  224
;       float4 resolvedMaterial;                      ; Offset:  240
;       float4 forwardedOrigin;                       ; Offset:  256
;       float4 forwardedDirection;                    ; Offset:  272
;       float4 forwardedFootprint;                    ; Offset:  288
;       float4 forwardedView;                         ; Offset:  304
;       float4 footprintDirect;                       ; Offset:  320
;       float4 wrappers;                              ; Offset:  336
;       float4 proxyPrimary;                          ; Offset:  352
;   
;   } $Element;                                       ; Offset:    0 Size:   368
;
; }
;
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; TestCounts                        cbuffer      NA          NA     CB0            cb0     1
; _Inputs                           texture  struct         r/o      T0             t0     1
; _Outputs                              UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.StructuredBuffer<RadianceInput>" = type { %struct.RadianceInput }
%struct.RadianceInput = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x i32>, <4 x float>, <4 x float>, <4 x i32>, <4 x float>, <4 x float> }
%"class.RWStructuredBuffer<RadianceOutput>" = type { %struct.RadianceOutput }
%struct.RadianceOutput = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x i32>, <4 x i32>, <4 x float>, <4 x float>, <4 x float>, <4 x i32>, <4 x i32>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%TestCounts = type { i32 }

define void @CSSurfaceParallax() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %5 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %6 = extractvalue %dx.types.CBufRet.i32 %5, 0
  %7 = icmp ult i32 %4, %6
  br i1 %7, label %8, label %61

; <label>:8                                       ; preds = %0
  %9 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 16)  ; BufferLoad(srv,index,wot)
  %10 = extractvalue %dx.types.ResRet.f32 %9, 0
  %11 = fmul fast float %10, 0x3FA6B87DE0000000
  %12 = fmul fast float %10, 0x3F9CD0F0A0000000
  %13 = fadd fast float %11, 0x3FDD4CCA20000000
  %14 = fadd fast float %12, 0x3FD8B31220000000
  %15 = fmul fast float %10, 0x3FA22D3180000000
  %16 = fadd fast float %15, 0x3FD770A1C0000000
  %17 = fmul fast float %10, 0x3F914A2A00000000
  %18 = fadd fast float %17, 0x3FCDA3AF60000000
  %19 = fmul fast float %10, 0x3F8472D7A0000000
  %20 = fadd fast float %19, 0x3FD4FE13E0000000
  %21 = fmul fast float %10, 0x3F8CD0F0A0000000
  %22 = fadd fast float %21, 0x3FDC598900000000
  %23 = fmul fast float %10, 0x3F96B87DE0000000
  %24 = fmul fast float %10, 0x3F959CB480000000
  %25 = fadd fast float %23, 0x3FDEA66500000000
  %26 = fadd fast float %24, 0x3FD8ECB400000000
  %27 = fmul fast float %10, 0x3F86B87DE0000000
  %28 = fmul fast float %10, 0x3F759CB480000000
  %29 = fadd fast float %27, 0xBFD0ACCD80000000
  %30 = fadd fast float %28, 0x3FB8ECB3A0000000
  %31 = fsub fast float 0x3FD0ACCD80000000, %27
  %32 = fmul fast float %22, %29
  %33 = fmul fast float %22, %30
  %34 = fmul fast float %22, %31
  %35 = fadd fast float %32, 1.000000e+00
  %36 = fadd fast float %33, 1.000000e+00
  %37 = fadd fast float %34, 1.000000e+00
  %38 = fadd fast float %27, 0x3FD7533280000000
  %39 = call float @dx.op.unary.f32(i32 7, float %38)  ; Saturate(value)
  %40 = fsub fast float 1.000000e+00, %39
  %41 = fmul fast float %40, 0x3FEEB851E0000000
  %42 = fmul fast float %10, 0x3F859CB480000000
  %43 = fadd fast float %42, 0x3FE2A19360000000
  %44 = fadd fast float %27, 0x3FBD4CCA20000000
  %45 = fadd fast float %28, 0x3FB2864DA0000000
  %46 = fmul fast float %10, 0x3F56B87DE0000000
  %47 = fadd fast float %46, 0x3FA7533280000000
  %48 = call float @dx.op.binary.f32(i32 35, float 0.000000e+00, float %44)  ; FMax(a,b)
  %49 = call float @dx.op.binary.f32(i32 35, float 0.000000e+00, float %45)  ; FMax(a,b)
  %50 = call float @dx.op.binary.f32(i32 35, float 0.000000e+00, float %47)  ; FMax(a,b)
  %51 = fmul fast float %41, %16
  %52 = fmul fast float %51, %35
  %53 = fmul fast float %41, %18
  %54 = fmul fast float %53, %36
  %55 = fmul fast float %41, %20
  %56 = fmul fast float %55, %37
  %57 = call float @dx.op.unary.f32(i32 7, float %52)  ; Saturate(value)
  %58 = call float @dx.op.unary.f32(i32 7, float %54)  ; Saturate(value)
  %59 = call float @dx.op.unary.f32(i32 7, float %56)  ; Saturate(value)
  %60 = call float @dx.op.unary.f32(i32 7, float %43)  ; Saturate(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %57, float %58, float %59, float %60, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %48, float %49, float %50, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %13, float %14, float 5.000000e-01, float 1.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %13, float %14, float %13, float %14, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 64, float %13, float %14, float %13, float %14, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 80, float %13, float %14, float %25, float %26, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 96, float 0x3FDEB85200000000, float 0x3FD99999A0000000, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 112, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %4, i32 128, i32 1, i32 1, i32 1, i32 1, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %4, i32 144, i32 0, i32 0, i32 0, i32 0, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 160, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 176, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 192, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %4, i32 208, i32 0, i32 0, i32 0, i32 0, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.i32(i32 69, %dx.types.Handle %1, i32 %4, i32 224, i32 0, i32 0, i32 0, i32 0, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 240, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 256, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 272, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 288, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 304, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 320, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 336, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 352, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %61

; <label>:61                                      ; preds = %8, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readnone
declare float @dx.op.binary.f32(i32, float, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #1

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32, %dx.types.Handle, i32, i32) #1

; Function Attrs: nounwind
declare void @dx.op.bufferStore.f32(i32, %dx.types.Handle, i32, i32, float, float, float, float, i8) #2

; Function Attrs: nounwind
declare void @dx.op.bufferStore.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32, i32, i8) #2

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind readonly }
attributes #2 = { nounwind }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.entryPoints = !{!13}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !8, !11, null}
!5 = !{!6}
!6 = !{i32 0, %"class.StructuredBuffer<RadianceInput>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 208}
!8 = !{!9}
!9 = !{i32 0, %"class.RWStructuredBuffer<RadianceOutput>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !10}
!10 = !{i32 1, i32 368}
!11 = !{!12}
!12 = !{i32 0, %TestCounts* undef, !"", i32 0, i32 0, i32 1, i32 4, null}
!13 = !{void ()* @CSSurfaceParallax, !"CSSurfaceParallax", null, !4, !14}
!14 = !{i32 0, i64 16, i32 4, !15}
!15 = !{i32 64, i32 1, i32 1}
