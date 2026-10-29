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
; shader hash: 8f19e03b1c5dae3778d48eccaa4dd0c6
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
; EntryFunctionName: CSStationaryHistory
;
;
; Buffer Definitions:
;
; cbuffer Counts
; {
;
;   struct Counts
;   {
;
;       uint _Count;                                  ; Offset:    0
;   
;   } Counts;                                         ; Offset:    0 Size:     4
;
; }
;
; Resource bind info for _Inputs
; {
;
;   struct struct.Input
;   {
;
;       float4 history;                               ; Offset:    0
;       float4 moments;                               ; Offset:   16
;       float4 eventCurrent;                          ; Offset:   32
;       float4 recoveryCurrent;                       ; Offset:   48
;       float4 control;                               ; Offset:   64
;       float4 reserved0;                             ; Offset:   80
;       float4 reserved1;                             ; Offset:   96
;       float4 reserved2;                             ; Offset:  112
;       float4 reserved3;                             ; Offset:  128
;       float4 reserved4;                             ; Offset:  144
;       float4 reserved5;                             ; Offset:  160
;   
;   } $Element;                                       ; Offset:    0 Size:   176
;
; }
;
; Resource bind info for _Outputs
; {
;
;   struct struct.Output
;   {
;
;       float4 rawHistory;                            ; Offset:    0
;       float4 rawMoments;                            ; Offset:   16
;       float4 storedHistory;                         ; Offset:   32
;       float4 storedMoments;                         ; Offset:   48
;   
;   } $Element;                                       ; Offset:    0 Size:    64
;
; }
;
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; Counts                            cbuffer      NA          NA     CB0            cb0     1
; _Inputs                           texture  struct         r/o      T0             t0     1
; _Outputs                              UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.StructuredBuffer<Input>" = type { %struct.Input }
%struct.Input = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%"class.RWStructuredBuffer<Output>" = type { %struct.Output }
%struct.Output = type { <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%Counts = type { i32 }

@_HLGI_IdentityObjects.2 = internal unnamed_addr global [1 x i32] zeroinitializer, align 4
@_HLGI_IdentityObjects.1.0 = internal unnamed_addr global [1 x i32] zeroinitializer, align 4
@_HLGI_IdentityObjects.1.1 = internal unnamed_addr global [1 x i32] zeroinitializer, align 4
@_HLGI_IdentityObjects.0.v.v.1dim = internal global [16 x float] zeroinitializer, align 16

define void @CSStationaryHistory() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %5 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %6 = extractvalue %dx.types.CBufRet.i32 %5, 0
  %7 = icmp uge i32 %4, %6
  %8 = add i32 %4, -1
  %9 = icmp ult i32 %8, 31
  %10 = or i1 %9, %7
  br i1 %10, label %1691, label %11

; <label>:11                                      ; preds = %0
  %12 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 0)  ; BufferLoad(srv,index,wot)
  %13 = extractvalue %dx.types.ResRet.f32 %12, 0
  %14 = extractvalue %dx.types.ResRet.f32 %12, 1
  %15 = extractvalue %dx.types.ResRet.f32 %12, 2
  %16 = extractvalue %dx.types.ResRet.f32 %12, 3
  %17 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 16)  ; BufferLoad(srv,index,wot)
  %18 = extractvalue %dx.types.ResRet.f32 %17, 0
  %19 = extractvalue %dx.types.ResRet.f32 %17, 1
  %20 = extractvalue %dx.types.ResRet.f32 %17, 2
  %21 = extractvalue %dx.types.ResRet.f32 %17, 3
  %22 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 32)  ; BufferLoad(srv,index,wot)
  %23 = extractvalue %dx.types.ResRet.f32 %22, 0
  %24 = extractvalue %dx.types.ResRet.f32 %22, 1
  %25 = extractvalue %dx.types.ResRet.f32 %22, 2
  %26 = extractvalue %dx.types.ResRet.f32 %22, 3
  %27 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 64)  ; BufferLoad(srv,index,wot)
  %28 = extractvalue %dx.types.ResRet.f32 %27, 0
  %29 = extractvalue %dx.types.ResRet.f32 %27, 1
  %30 = extractvalue %dx.types.ResRet.f32 %27, 2
  %31 = extractvalue %dx.types.ResRet.f32 %27, 3
  %32 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 80)  ; BufferLoad(srv,index,wot)
  %33 = extractvalue %dx.types.ResRet.f32 %32, 0
  %34 = extractvalue %dx.types.ResRet.f32 %32, 1
  %35 = extractvalue %dx.types.ResRet.f32 %32, 2
  %36 = extractvalue %dx.types.ResRet.f32 %32, 3
  %37 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 96)  ; BufferLoad(srv,index,wot)
  %38 = extractvalue %dx.types.ResRet.f32 %37, 0
  %39 = extractvalue %dx.types.ResRet.f32 %37, 1
  %40 = extractvalue %dx.types.ResRet.f32 %37, 2
  %41 = fsub fast float -0.000000e+00, %35
  store float 1.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 0), align 16
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 1), align 4
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 2), align 8
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 3), align 4
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 4), align 16
  store float 1.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 5), align 4
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 6), align 8
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 7), align 4
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 8), align 16
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 9), align 4
  store float 1.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 10), align 8
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 11), align 4
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 12), align 16
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 13), align 4
  store float 0.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 14), align 8
  store float 1.000000e+00, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 15), align 4
  store i32 7, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.1.0, i32 0, i32 0), align 4
  store i32 11, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.1.1, i32 0, i32 0), align 4
  store i32 1, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.2, i32 0, i32 0), align 4
  %42 = call i32 @dx.op.legacyF32ToF16(i32 130, float %13)  ; LegacyF32ToF16(value)
  %43 = call i32 @dx.op.legacyF32ToF16(i32 130, float %14)  ; LegacyF32ToF16(value)
  %44 = call i32 @dx.op.legacyF32ToF16(i32 130, float %15)  ; LegacyF32ToF16(value)
  %45 = call i32 @dx.op.legacyF32ToF16(i32 130, float %16)  ; LegacyF32ToF16(value)
  %46 = call float @dx.op.legacyF16ToF32(i32 131, i32 %42)  ; LegacyF16ToF32(value)
  %47 = call float @dx.op.legacyF16ToF32(i32 131, i32 %43)  ; LegacyF16ToF32(value)
  %48 = call float @dx.op.legacyF16ToF32(i32 131, i32 %44)  ; LegacyF16ToF32(value)
  %49 = call float @dx.op.legacyF16ToF32(i32 131, i32 %45)  ; LegacyF16ToF32(value)
  %50 = call i32 @dx.op.legacyF32ToF16(i32 130, float %23)  ; LegacyF32ToF16(value)
  %51 = call i32 @dx.op.legacyF32ToF16(i32 130, float %24)  ; LegacyF32ToF16(value)
  %52 = call i32 @dx.op.legacyF32ToF16(i32 130, float %25)  ; LegacyF32ToF16(value)
  %53 = call i32 @dx.op.legacyF32ToF16(i32 130, float %26)  ; LegacyF32ToF16(value)
  %54 = call float @dx.op.legacyF16ToF32(i32 131, i32 %50)  ; LegacyF16ToF32(value)
  %55 = call float @dx.op.legacyF16ToF32(i32 131, i32 %51)  ; LegacyF16ToF32(value)
  %56 = call float @dx.op.legacyF16ToF32(i32 131, i32 %52)  ; LegacyF16ToF32(value)
  %57 = call float @dx.op.legacyF16ToF32(i32 131, i32 %53)  ; LegacyF16ToF32(value)
  %58 = fptosi float %31 to i32
  %59 = fptosi float %38 to i32
  %60 = fptosi float %39 to i32
  %61 = icmp eq i32 %4, 0
  br i1 %61, label %62, label %944

; <label>:62                                      ; preds = %11
  br label %63

; <label>:63                                      ; preds = %937, %62
  %64 = phi i32 [ %943, %937 ], [ 1, %62 ]
  %65 = phi i32 [ %942, %937 ], [ 11, %62 ]
  %66 = phi i32 [ %941, %937 ], [ 7, %62 ]
  %67 = phi float [ %940, %937 ], [ 1.000000e+00, %62 ]
  %68 = phi float [ %939, %937 ], [ 0.000000e+00, %62 ]
  %69 = phi float [ %938, %937 ], [ 0.000000e+00, %62 ]
  %70 = phi float [ %931, %937 ], [ %46, %62 ]
  %71 = phi float [ %932, %937 ], [ %47, %62 ]
  %72 = phi float [ %933, %937 ], [ %48, %62 ]
  %73 = phi float [ %934, %937 ], [ %49, %62 ]
  %74 = phi float [ %923, %937 ], [ %18, %62 ]
  %75 = phi float [ %924, %937 ], [ %19, %62 ]
  %76 = phi float [ %925, %937 ], [ %20, %62 ]
  %77 = phi float [ %926, %937 ], [ %21, %62 ]
  %78 = phi i32 [ %935, %937 ], [ 0, %62 ]
  %79 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %80 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %81 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %82 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %57)  ; IsFinite(value)
  %83 = and i1 %79, %80
  %84 = and i1 %83, %81
  %85 = and i1 %84, %82
  %86 = fcmp fast ogt float %57, 0.000000e+00
  %87 = and i1 %86, %85
  %88 = call float @dx.op.dot3.f32(i32 55, float %54, float %55, float %56, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %89 = select i1 %87, float %88, float 0.000000e+00
  %90 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %89)  ; IsFinite(value)
  %91 = and i1 %87, %90
  %92 = fmul fast float %89, %89
  %93 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %92)  ; IsFinite(value)
  %94 = and i1 %91, %93
  %95 = fmul fast float %54, %54
  %96 = fmul fast float %55, %55
  %97 = fmul fast float %56, %56
  %98 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %95)  ; IsFinite(value)
  %99 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %96)  ; IsFinite(value)
  %100 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %97)  ; IsFinite(value)
  %101 = and i1 %98, %99
  %102 = and i1 %101, %100
  %103 = and i1 %94, %102
  %104 = icmp ne i32 %66, 7
  %105 = icmp ne i32 %65, 11
  %106 = or i1 %105, %104
  %107 = and i32 %64, 1
  %108 = icmp eq i32 %107, 0
  %109 = or i1 %108, %106
  br i1 %109, label %162, label %110

; <label>:110                                     ; preds = %63
  %111 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 15), align 4
  %112 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 14), align 8
  %113 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 13), align 4
  %114 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 12), align 16
  %115 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 11), align 4
  %116 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 3), align 4
  %117 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 2), align 8
  %118 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 1), align 4
  %119 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 0), align 16
  %120 = fmul fast float %119, %41
  %121 = call float @dx.op.tertiary.f32(i32 46, float %69, float 5.000000e-01, float %120)  ; FMad(a,b,c)
  %122 = fadd fast float %121, %114
  %123 = fmul fast float %118, %41
  %124 = call float @dx.op.tertiary.f32(i32 46, float %68, float 5.000000e-01, float %123)  ; FMad(a,b,c)
  %125 = fadd fast float %124, %113
  %126 = fmul fast float %117, %41
  %127 = call float @dx.op.tertiary.f32(i32 46, float %67, float 5.000000e-01, float %126)  ; FMad(a,b,c)
  %128 = fadd fast float %127, %112
  %129 = fmul fast float %116, %41
  %130 = call float @dx.op.tertiary.f32(i32 46, float %115, float 5.000000e-01, float %129)  ; FMad(a,b,c)
  %131 = fadd fast float %130, %111
  %132 = call float @dx.op.dot3.f32(i32 55, float %69, float %68, float %67, float %69, float %68, float %67)  ; Dot3(ax,ay,az,bx,by,bz)
  %133 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %122)  ; IsFinite(value)
  %134 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %125)  ; IsFinite(value)
  %135 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %128)  ; IsFinite(value)
  %136 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %131)  ; IsFinite(value)
  %137 = and i1 %133, %134
  %138 = and i1 %137, %135
  %139 = and i1 %138, %136
  %140 = xor i1 %139, true
  %141 = fadd fast float %131, -1.000000e+00
  %142 = call float @dx.op.unary.f32(i32 6, float %141)  ; FAbs(value)
  %143 = fcmp fast ogt float %142, 0x3EE4F8B580000000
  %144 = or i1 %143, %140
  %145 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %69)  ; IsFinite(value)
  %146 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %68)  ; IsFinite(value)
  %147 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %67)  ; IsFinite(value)
  %148 = and i1 %145, %146
  %149 = and i1 %148, %147
  %150 = xor i1 %149, true
  %151 = or i1 %144, %150
  %152 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %132)  ; IsFinite(value)
  %153 = xor i1 %152, true
  %154 = or i1 %151, %153
  %155 = fcmp fast olt float %132, 0x3C9CD2B2A0000000
  %156 = or i1 %155, %154
  br i1 %156, label %162, label %157

; <label>:157                                     ; preds = %110
  %158 = call float @dx.op.unary.f32(i32 25, float %132)  ; Rsqrt(value)
  %159 = fmul fast float %158, %69
  %160 = fmul fast float %158, %68
  %161 = fmul fast float %158, %67
  br label %162

; <label>:162                                     ; preds = %157, %110, %63
  %163 = phi float [ %122, %157 ], [ %41, %63 ], [ %41, %110 ]
  %164 = phi float [ %125, %157 ], [ 0.000000e+00, %63 ], [ 0.000000e+00, %110 ]
  %165 = phi float [ %128, %157 ], [ 5.000000e-01, %63 ], [ 5.000000e-01, %110 ]
  %166 = phi float [ %159, %157 ], [ 0.000000e+00, %63 ], [ 0.000000e+00, %110 ]
  %167 = phi float [ %160, %157 ], [ 0.000000e+00, %63 ], [ 0.000000e+00, %110 ]
  %168 = phi float [ %161, %157 ], [ 1.000000e+00, %63 ], [ 1.000000e+00, %110 ]
  %169 = phi i32 [ 1, %157 ], [ 0, %63 ], [ 0, %110 ]
  %170 = fmul fast float %163, 5.000000e-01
  %171 = fmul fast float %164, 5.000000e-01
  %172 = fadd fast float %170, 5.000000e-01
  %173 = fadd fast float %171, 5.000000e-01
  %174 = icmp eq i32 %58, 0
  br i1 %174, label %191, label %175

; <label>:175                                     ; preds = %162
  %176 = fsub fast float 5.000000e-01, %33
  %177 = fsub fast float 5.000000e-01, %34
  %178 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %176)  ; IsFinite(value)
  %179 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %177)  ; IsFinite(value)
  %180 = and i1 %178, %179
  %181 = fsub fast float %176, %172
  %182 = fsub fast float %177, %173
  %183 = call float @dx.op.unary.f32(i32 6, float %181)  ; FAbs(value)
  %184 = call float @dx.op.unary.f32(i32 6, float %182)  ; FAbs(value)
  %185 = fcmp fast ole float %183, 1.000000e+00
  %186 = fcmp fast ole float %184, 1.000000e+00
  %187 = and i1 %185, %186
  %188 = and i1 %180, %187
  %189 = select i1 %188, float %176, float %172
  %190 = select i1 %188, float %177, float %173
  br label %191

; <label>:191                                     ; preds = %175, %162
  %192 = phi float [ %172, %162 ], [ %189, %175 ]
  %193 = phi float [ %173, %162 ], [ %190, %175 ]
  %194 = icmp ne i32 %59, 0
  %195 = icmp ne i32 %169, 0
  %196 = and i1 %194, %195
  %197 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %198 = and i1 %196, %197
  %199 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %192)  ; IsFinite(value)
  %200 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %193)  ; IsFinite(value)
  %201 = and i1 %199, %200
  %202 = and i1 %198, %201
  %203 = fcmp fast ogt float %192, 0.000000e+00
  %204 = fcmp fast ogt float %193, 0.000000e+00
  %205 = and i1 %203, %204
  %206 = and i1 %205, %202
  %207 = fcmp fast olt float %192, 1.000000e+00
  %208 = fcmp fast olt float %193, 1.000000e+00
  %209 = and i1 %207, %208
  %210 = and i1 %209, %206
  br i1 %210, label %211, label %266

; <label>:211                                     ; preds = %191
  %212 = call float @dx.op.unary.f32(i32 27, float %192)  ; Round_ni(value)
  %213 = call float @dx.op.unary.f32(i32 27, float %193)  ; Round_ni(value)
  %214 = fptosi float %212 to i32
  %215 = fptosi float %213 to i32
  %216 = call i32 @dx.op.binary.i32(i32 37, i32 %214, i32 0)  ; IMax(a,b)
  %217 = call i32 @dx.op.binary.i32(i32 37, i32 %215, i32 0)  ; IMax(a,b)
  %218 = call i32 @dx.op.binary.i32(i32 38, i32 %216, i32 0)  ; IMin(a,b)
  %219 = call i32 @dx.op.binary.i32(i32 38, i32 %217, i32 0)  ; IMin(a,b)
  %220 = add i32 %218, -1
  %221 = add i32 %219, -1
  %222 = call i32 @dx.op.binary.i32(i32 37, i32 %220, i32 0)  ; IMax(a,b)
  %223 = call i32 @dx.op.binary.i32(i32 37, i32 %221, i32 0)  ; IMax(a,b)
  %224 = and i32 %222, 2147483647
  %225 = and i32 %223, 2147483647
  %226 = uitofp i32 %224 to float
  %227 = uitofp i32 %225 to float
  %228 = fsub fast float 5.000000e-01, %192
  %229 = fadd fast float %226, %228
  %230 = fsub fast float 5.000000e-01, %193
  %231 = fadd fast float %227, %230
  %232 = call float @dx.op.unary.f32(i32 6, float %229)  ; FAbs(value)
  %233 = call float @dx.op.unary.f32(i32 6, float %231)  ; FAbs(value)
  %234 = call i32 @dx.op.binary.i32(i32 38, i32 %218, i32 0)  ; IMin(a,b)
  %235 = call i32 @dx.op.binary.i32(i32 38, i32 %219, i32 0)  ; IMin(a,b)
  %236 = and i32 %234, 2147483647
  %237 = and i32 %235, 2147483647
  %238 = uitofp i32 %236 to float
  %239 = uitofp i32 %237 to float
  %240 = fadd fast float %238, %228
  %241 = fadd fast float %239, %230
  %242 = call float @dx.op.unary.f32(i32 6, float %240)  ; FAbs(value)
  %243 = call float @dx.op.unary.f32(i32 6, float %241)  ; FAbs(value)
  %244 = fcmp fast olt float %242, %232
  %245 = select i1 %244, i32 %234, i32 %222
  %246 = select i1 %244, float %242, float %232
  %247 = fcmp fast olt float %243, %233
  %248 = select i1 %247, i32 %235, i32 %223
  %249 = select i1 %247, float %243, float %233
  %250 = add i32 %218, 1
  %251 = add i32 %219, 1
  %252 = call i32 @dx.op.binary.i32(i32 38, i32 %250, i32 0)  ; IMin(a,b)
  %253 = call i32 @dx.op.binary.i32(i32 38, i32 %251, i32 0)  ; IMin(a,b)
  %254 = and i32 %252, 2147483647
  %255 = and i32 %253, 2147483647
  %256 = uitofp i32 %254 to float
  %257 = uitofp i32 %255 to float
  %258 = fadd fast float %256, %228
  %259 = fadd fast float %257, %230
  %260 = call float @dx.op.unary.f32(i32 6, float %258)  ; FAbs(value)
  %261 = call float @dx.op.unary.f32(i32 6, float %259)  ; FAbs(value)
  %262 = fcmp fast olt float %260, %246
  %263 = select i1 %262, i32 %252, i32 %245
  %264 = fcmp fast olt float %261, %249
  %265 = select i1 %264, i32 %253, i32 %248
  br label %266

; <label>:266                                     ; preds = %211, %191
  %267 = phi i32 [ 0, %191 ], [ %263, %211 ]
  %268 = phi i32 [ 0, %191 ], [ %265, %211 ]
  %269 = and i32 %267, 2147483647
  %270 = and i32 %268, 2147483647
  %271 = uitofp i32 %269 to float
  %272 = uitofp i32 %270 to float
  %273 = fadd fast float %271, 5.000000e-01
  %274 = fadd fast float %272, 5.000000e-01
  %275 = fmul fast float %273, 2.000000e+00
  %276 = fmul fast float %274, 2.000000e+00
  %277 = call float @dx.op.dot3.f32(i32 55, float %166, float %167, float %168, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %278 = call float @dx.op.unary.f32(i32 6, float %277)  ; FAbs(value)
  %279 = call float @dx.op.dot3.f32(i32 55, float %166, float %167, float %168, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %280 = fcmp fast ogt float %279, 0x3FECCCCCC0000000
  %281 = fcmp fast ogt float %278, 0x3FEB333340000000
  %282 = and i1 %281, %280
  %283 = fadd fast float %163, 1.000000e+00
  %284 = fsub fast float %283, %275
  %285 = fadd fast float %164, 1.000000e+00
  %286 = fsub fast float %285, %276
  %287 = fsub fast float %165, %36
  %288 = call float @dx.op.dot3.f32(i32 55, float %284, float %286, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %289 = call float @dx.op.unary.f32(i32 6, float %288)  ; FAbs(value)
  %290 = fcmp fast olt float %289, 0x3F8EB851E0000000
  %291 = and i1 %282, %290
  %292 = call float @dx.op.dot3.f32(i32 55, float %284, float %286, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %293 = call float @dx.op.unary.f32(i32 6, float %292)  ; FAbs(value)
  %294 = fcmp fast olt float %293, 0x3F8EB851E0000000
  %295 = and i1 %291, %294
  %296 = fmul fast float %284, %284
  %297 = fmul fast float %286, %286
  %298 = fmul fast float %287, %287
  %299 = fadd fast float %296, %298
  %300 = fadd fast float %299, %297
  %301 = call float @dx.op.unary.f32(i32 24, float %300)  ; Sqrt(value)
  %302 = fcmp fast olt float %301, 0x3F8EB851E0000000
  %303 = and i1 %295, %302
  %304 = and i1 %210, %303
  %305 = fcmp fast olt float %29, 5.000000e-01
  %306 = and i1 %305, %304
  %307 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %70)  ; IsFinite(value)
  %308 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %71)  ; IsFinite(value)
  %309 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %72)  ; IsFinite(value)
  %310 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %73)  ; IsFinite(value)
  %311 = and i1 %307, %308
  %312 = and i1 %311, %309
  %313 = and i1 %312, %310
  %314 = fcmp fast ogt float %73, 0.000000e+00
  %315 = and i1 %314, %313
  %316 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %74)  ; IsFinite(value)
  %317 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %75)  ; IsFinite(value)
  %318 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %76)  ; IsFinite(value)
  %319 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %77)  ; IsFinite(value)
  %320 = and i1 %316, %317
  %321 = and i1 %320, %318
  %322 = and i1 %321, %319
  %323 = and i1 %315, %322
  %324 = fcmp fast ogt float %76, 0.000000e+00
  %325 = and i1 %324, %323
  %326 = and i1 %306, %325
  br i1 %103, label %339, label %327

; <label>:327                                     ; preds = %266
  %328 = select i1 %326, float %70, float 0.000000e+00
  %329 = select i1 %326, float %71, float 0.000000e+00
  %330 = select i1 %326, float %72, float 0.000000e+00
  %331 = select i1 %326, float %73, float 0.000000e+00
  %332 = select i1 %326, float %74, float 0.000000e+00
  %333 = select i1 %326, float %75, float 0.000000e+00
  %334 = select i1 %326, float %76, float 0.000000e+00
  %335 = select i1 %326, float %77, float 0.000000e+00
  %336 = fcmp fast ogt float %28, 5.000000e-01
  br i1 %336, label %337, label %918

; <label>:337                                     ; preds = %327
  %338 = call float @dx.op.binary.f32(i32 36, float %334, float 2.000000e+00)  ; FMin(a,b)
  br label %918

; <label>:339                                     ; preds = %266
  %340 = fcmp ule float %30, 5.000000e-01
  %341 = and i1 %326, %340
  %342 = fcmp fast olt float %28, 5.000000e-01
  %343 = and i1 %342, %341
  %344 = sitofp i32 %60 to float
  %345 = fcmp fast oge float %76, %344
  %346 = and i1 %345, %343
  %347 = or i32 %268, %267
  %348 = icmp eq i32 %347, 0
  %349 = and i1 %348, %346
  %350 = fcmp fast oeq float %192, 5.000000e-01
  %351 = fcmp fast oeq float %193, 5.000000e-01
  %352 = and i1 %350, %351
  %353 = and i1 %352, %349
  %354 = fcmp fast oeq float %33, 0.000000e+00
  %355 = fcmp fast oeq float %34, 0.000000e+00
  %356 = and i1 %354, %355
  %357 = or i1 %174, %356
  %358 = and i1 %357, %353
  %359 = fcmp fast oeq float %163, %41
  %360 = fcmp fast oeq float %164, 0.000000e+00
  %361 = fcmp fast oeq float %165, 5.000000e-01
  %362 = and i1 %359, %360
  %363 = and i1 %362, %361
  %364 = and i1 %363, %358
  %365 = fcmp fast oeq float %166, 0.000000e+00
  %366 = fcmp fast oeq float %167, 0.000000e+00
  %367 = fcmp fast oeq float %168, 1.000000e+00
  %368 = and i1 %365, %366
  %369 = and i1 %368, %367
  %370 = and i1 %369, %364
  %371 = fcmp fast oeq float %166, 0.000000e+00
  %372 = fcmp fast oeq float %167, 0.000000e+00
  %373 = fcmp fast oeq float %168, 1.000000e+00
  %374 = and i1 %371, %372
  %375 = and i1 %374, %373
  %376 = and i1 %375, %370
  %377 = fcmp fast oeq float %35, 0.000000e+00
  %378 = and i1 %377, %376
  %379 = fcmp fast oeq float %36, 5.000000e-01
  %380 = and i1 %379, %378
  %381 = xor i1 %380, true
  %382 = and i1 %341, %381
  br i1 %382, label %383, label %829

; <label>:383                                     ; preds = %339
  %384 = call float @dx.op.unary.f32(i32 27, float %192)  ; Round_ni(value)
  %385 = call float @dx.op.unary.f32(i32 27, float %193)  ; Round_ni(value)
  %386 = fptosi float %384 to i32
  %387 = fptosi float %385 to i32
  %388 = call i32 @dx.op.binary.i32(i32 37, i32 %386, i32 0)  ; IMax(a,b)
  %389 = call i32 @dx.op.binary.i32(i32 37, i32 %387, i32 0)  ; IMax(a,b)
  %390 = call i32 @dx.op.binary.i32(i32 38, i32 %388, i32 0)  ; IMin(a,b)
  %391 = call i32 @dx.op.binary.i32(i32 38, i32 %389, i32 0)  ; IMin(a,b)
  %392 = add i32 %390, -1
  %393 = add i32 %391, -1
  %394 = call i32 @dx.op.binary.i32(i32 37, i32 %392, i32 0)  ; IMax(a,b)
  %395 = call i32 @dx.op.binary.i32(i32 37, i32 %393, i32 0)  ; IMax(a,b)
  %396 = and i32 %394, 2147483647
  %397 = and i32 %395, 2147483647
  %398 = uitofp i32 %396 to float
  %399 = uitofp i32 %397 to float
  %400 = fsub fast float 5.000000e-01, %192
  %401 = fadd fast float %398, %400
  %402 = fsub fast float 5.000000e-01, %193
  %403 = fadd fast float %399, %402
  %404 = call float @dx.op.unary.f32(i32 6, float %401)  ; FAbs(value)
  %405 = call float @dx.op.unary.f32(i32 6, float %403)  ; FAbs(value)
  %406 = call i32 @dx.op.binary.i32(i32 38, i32 %390, i32 0)  ; IMin(a,b)
  %407 = call i32 @dx.op.binary.i32(i32 38, i32 %391, i32 0)  ; IMin(a,b)
  %408 = and i32 %406, 2147483647
  %409 = and i32 %407, 2147483647
  %410 = uitofp i32 %408 to float
  %411 = uitofp i32 %409 to float
  %412 = fadd fast float %410, %400
  %413 = fadd fast float %411, %402
  %414 = call float @dx.op.unary.f32(i32 6, float %412)  ; FAbs(value)
  %415 = call float @dx.op.unary.f32(i32 6, float %413)  ; FAbs(value)
  %416 = fcmp fast olt float %414, %404
  %417 = select i1 %416, i32 %406, i32 %394
  %418 = select i1 %416, float %414, float %404
  %419 = fcmp fast olt float %415, %405
  %420 = select i1 %419, i32 %407, i32 %395
  %421 = select i1 %419, float %415, float %405
  %422 = add i32 %390, 1
  %423 = add i32 %391, 1
  %424 = call i32 @dx.op.binary.i32(i32 38, i32 %422, i32 0)  ; IMin(a,b)
  %425 = call i32 @dx.op.binary.i32(i32 38, i32 %423, i32 0)  ; IMin(a,b)
  %426 = and i32 %424, 2147483647
  %427 = and i32 %425, 2147483647
  %428 = uitofp i32 %426 to float
  %429 = uitofp i32 %427 to float
  %430 = fadd fast float %428, %400
  %431 = fadd fast float %429, %402
  %432 = call float @dx.op.unary.f32(i32 6, float %430)  ; FAbs(value)
  %433 = call float @dx.op.unary.f32(i32 6, float %431)  ; FAbs(value)
  %434 = fcmp fast olt float %432, %418
  %435 = select i1 %434, i32 %424, i32 %417
  %436 = fcmp fast olt float %433, %421
  %437 = select i1 %436, i32 %425, i32 %420
  %438 = and i32 %435, 2147483647
  %439 = and i32 %437, 2147483647
  %440 = uitofp i32 %438 to float
  %441 = uitofp i32 %439 to float
  %442 = fadd fast float %440, 5.000000e-01
  %443 = fadd fast float %441, 5.000000e-01
  %444 = fcmp fast olt float %192, %442
  br i1 %444, label %445, label %448

; <label>:445                                     ; preds = %383
  %446 = add nsw i32 %435, -1
  %447 = call i32 @dx.op.binary.i32(i32 37, i32 %446, i32 0)  ; IMax(a,b)
  br label %451

; <label>:448                                     ; preds = %383
  %449 = add i32 %435, 1
  %450 = call i32 @dx.op.binary.i32(i32 40, i32 %449, i32 0)  ; UMin(a,b)
  br label %451

; <label>:451                                     ; preds = %448, %445
  %452 = phi i32 [ %435, %445 ], [ %450, %448 ]
  %453 = phi i32 [ %447, %445 ], [ %435, %448 ]
  %454 = fcmp fast olt float %193, %443
  br i1 %454, label %455, label %458

; <label>:455                                     ; preds = %451
  %456 = add nsw i32 %437, -1
  %457 = call i32 @dx.op.binary.i32(i32 37, i32 %456, i32 0)  ; IMax(a,b)
  br label %461

; <label>:458                                     ; preds = %451
  %459 = add i32 %437, 1
  %460 = call i32 @dx.op.binary.i32(i32 40, i32 %459, i32 0)  ; UMin(a,b)
  br label %461

; <label>:461                                     ; preds = %458, %455
  %462 = phi i32 [ %437, %455 ], [ %460, %458 ]
  %463 = phi i32 [ %457, %455 ], [ %437, %458 ]
  %464 = and i32 %453, 2147483647
  %465 = and i32 %463, 2147483647
  %466 = uitofp i32 %464 to float
  %467 = uitofp i32 %465 to float
  %468 = fadd fast float %466, 5.000000e-01
  %469 = fadd fast float %467, 5.000000e-01
  %470 = and i32 %452, 2147483647
  %471 = and i32 %462, 2147483647
  %472 = uitofp i32 %470 to float
  %473 = uitofp i32 %471 to float
  %474 = fadd fast float %472, 5.000000e-01
  %475 = fadd fast float %473, 5.000000e-01
  %476 = fcmp fast ogt float %474, %468
  %477 = fsub fast float %192, %468
  %478 = fsub fast float %474, %468
  %479 = fdiv fast float %477, %478
  %480 = call float @dx.op.unary.f32(i32 7, float %479)  ; Saturate(value)
  %481 = select i1 %476, float %480, float 0.000000e+00
  %482 = fcmp fast ogt float %475, %469
  %483 = fsub fast float %193, %469
  %484 = fsub fast float %475, %469
  %485 = fdiv fast float %483, %484
  %486 = call float @dx.op.unary.f32(i32 7, float %485)  ; Saturate(value)
  %487 = select i1 %482, float %486, float 0.000000e+00
  %488 = fsub fast float 1.000000e+00, %481
  %489 = fsub fast float 1.000000e+00, %487
  %490 = fmul fast float %489, %488
  %491 = fcmp fast ugt float %490, 0.000000e+00
  br i1 %491, label %505, label %541

; <label>:492                                     ; preds = %616, %604, %553, %541
  %493 = phi i1 [ true, %541 ], [ false, %553 ], [ true, %604 ], [ false, %616 ]
  %494 = phi i1 [ false, %541 ], [ true, %553 ], [ false, %604 ], [ %606, %616 ]
  %495 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %617, %616 ]
  %496 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %618, %616 ]
  %497 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %619, %616 ]
  %498 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %620, %616 ]
  %499 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %621, %616 ]
  %500 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %622, %616 ]
  %501 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %623, %616 ]
  %502 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %624, %616 ]
  %503 = phi float [ 0.000000e+00, %541 ], [ 0.000000e+00, %553 ], [ 0.000000e+00, %604 ], [ %625, %616 ]
  %504 = or i1 %493, %494
  br i1 %504, label %813, label %639

; <label>:505                                     ; preds = %461
  %506 = icmp ne i32 %453, %267
  %507 = icmp ne i32 %463, %268
  %508 = or i1 %506, %507
  br i1 %508, label %509, label %531

; <label>:509                                     ; preds = %505
  %510 = fmul fast float %468, 2.000000e+00
  %511 = fmul fast float %469, 2.000000e+00
  %512 = fsub fast float %283, %510
  %513 = fsub fast float %285, %511
  %514 = call float @dx.op.dot3.f32(i32 55, float %512, float %513, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %515 = call float @dx.op.unary.f32(i32 6, float %514)  ; FAbs(value)
  %516 = fcmp fast olt float %515, 0x3F8EB851E0000000
  %517 = and i1 %282, %516
  %518 = call float @dx.op.dot3.f32(i32 55, float %512, float %513, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %519 = call float @dx.op.unary.f32(i32 6, float %518)  ; FAbs(value)
  %520 = fcmp fast olt float %519, 0x3F8EB851E0000000
  %521 = and i1 %517, %520
  %522 = fmul fast float %512, %512
  %523 = fmul fast float %513, %513
  %524 = fadd fast float %522, %298
  %525 = fadd fast float %524, %523
  %526 = call float @dx.op.unary.f32(i32 24, float %525)  ; Sqrt(value)
  %527 = fcmp fast olt float %526, 0x3F8EB851E0000000
  %528 = and i1 %521, %527
  %529 = xor i1 %528, true
  %530 = xor i1 %325, true
  br label %531

; <label>:531                                     ; preds = %509, %505
  %532 = phi i1 [ %530, %509 ], [ false, %505 ]
  %533 = phi i1 [ %529, %509 ], [ false, %505 ]
  %534 = fmul fast float %490, %70
  %535 = fmul fast float %490, %71
  %536 = fmul fast float %490, %72
  %537 = fmul fast float %490, %73
  %538 = fmul fast float %490, %74
  %539 = fmul fast float %490, %75
  %540 = fmul fast float %490, %77
  br label %541

; <label>:541                                     ; preds = %531, %461
  %542 = phi i1 [ %532, %531 ], [ false, %461 ]
  %543 = phi i1 [ %533, %531 ], [ false, %461 ]
  %544 = phi float [ %534, %531 ], [ 0.000000e+00, %461 ]
  %545 = phi float [ %535, %531 ], [ 0.000000e+00, %461 ]
  %546 = phi float [ %536, %531 ], [ 0.000000e+00, %461 ]
  %547 = phi float [ %537, %531 ], [ 0.000000e+00, %461 ]
  %548 = phi float [ %538, %531 ], [ 0.000000e+00, %461 ]
  %549 = phi float [ %539, %531 ], [ 0.000000e+00, %461 ]
  %550 = phi float [ %540, %531 ], [ 0.000000e+00, %461 ]
  %551 = phi float [ %490, %531 ], [ 0.000000e+00, %461 ]
  %552 = phi float [ %76, %531 ], [ 0.000000e+00, %461 ]
  br i1 %542, label %492, label %553

; <label>:553                                     ; preds = %541
  br i1 %543, label %492, label %554

; <label>:554                                     ; preds = %553
  %555 = fmul fast float %489, %481
  %556 = fcmp fast ugt float %555, 0.000000e+00
  br i1 %556, label %557, label %604

; <label>:557                                     ; preds = %554
  %558 = icmp ne i32 %452, %267
  %559 = icmp ne i32 %463, %268
  %560 = or i1 %558, %559
  br i1 %560, label %561, label %583

; <label>:561                                     ; preds = %557
  %562 = fmul fast float %474, 2.000000e+00
  %563 = fmul fast float %469, 2.000000e+00
  %564 = fsub fast float %283, %562
  %565 = fsub fast float %285, %563
  %566 = call float @dx.op.dot3.f32(i32 55, float %564, float %565, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %567 = call float @dx.op.unary.f32(i32 6, float %566)  ; FAbs(value)
  %568 = fcmp fast olt float %567, 0x3F8EB851E0000000
  %569 = and i1 %282, %568
  %570 = call float @dx.op.dot3.f32(i32 55, float %564, float %565, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %571 = call float @dx.op.unary.f32(i32 6, float %570)  ; FAbs(value)
  %572 = fcmp fast olt float %571, 0x3F8EB851E0000000
  %573 = and i1 %569, %572
  %574 = fmul fast float %564, %564
  %575 = fmul fast float %565, %565
  %576 = fadd fast float %574, %298
  %577 = fadd fast float %576, %575
  %578 = call float @dx.op.unary.f32(i32 24, float %577)  ; Sqrt(value)
  %579 = fcmp fast olt float %578, 0x3F8EB851E0000000
  %580 = and i1 %573, %579
  %581 = xor i1 %580, true
  %582 = xor i1 %325, true
  br label %583

; <label>:583                                     ; preds = %561, %557
  %584 = phi i1 [ %582, %561 ], [ false, %557 ]
  %585 = phi i1 [ %581, %561 ], [ false, %557 ]
  %586 = fcmp fast oeq float %551, 0.000000e+00
  %587 = call float @dx.op.binary.f32(i32 36, float %552, float %76)  ; FMin(a,b)
  %588 = select i1 %586, float %76, float %587
  %589 = fmul fast float %555, %70
  %590 = fmul fast float %555, %71
  %591 = fmul fast float %555, %72
  %592 = fmul fast float %555, %73
  %593 = fadd fast float %544, %589
  %594 = fadd fast float %545, %590
  %595 = fadd fast float %546, %591
  %596 = fadd fast float %547, %592
  %597 = fmul fast float %555, %74
  %598 = fmul fast float %555, %75
  %599 = fmul fast float %555, %77
  %600 = fadd fast float %548, %597
  %601 = fadd fast float %549, %598
  %602 = fadd fast float %550, %599
  %603 = fadd fast float %551, %555
  br label %604

; <label>:604                                     ; preds = %583, %554
  %605 = phi i1 [ %584, %583 ], [ false, %554 ]
  %606 = phi i1 [ %585, %583 ], [ false, %554 ]
  %607 = phi float [ %593, %583 ], [ %544, %554 ]
  %608 = phi float [ %594, %583 ], [ %545, %554 ]
  %609 = phi float [ %595, %583 ], [ %546, %554 ]
  %610 = phi float [ %596, %583 ], [ %547, %554 ]
  %611 = phi float [ %600, %583 ], [ %548, %554 ]
  %612 = phi float [ %601, %583 ], [ %549, %554 ]
  %613 = phi float [ %602, %583 ], [ %550, %554 ]
  %614 = phi float [ %603, %583 ], [ %551, %554 ]
  %615 = phi float [ %588, %583 ], [ %552, %554 ]
  br i1 %605, label %492, label %616

; <label>:616                                     ; preds = %604
  %617 = select i1 %606, float 0.000000e+00, float %615
  %618 = select i1 %606, float 0.000000e+00, float %614
  %619 = select i1 %606, float 0.000000e+00, float %613
  %620 = select i1 %606, float 0.000000e+00, float %612
  %621 = select i1 %606, float 0.000000e+00, float %611
  %622 = select i1 %606, float 0.000000e+00, float %610
  %623 = select i1 %606, float 0.000000e+00, float %609
  %624 = select i1 %606, float 0.000000e+00, float %608
  %625 = select i1 %606, float 0.000000e+00, float %607
  br label %492

; <label>:626                                     ; preds = %764, %752, %701, %689
  %627 = phi i1 [ true, %689 ], [ false, %701 ], [ true, %752 ], [ false, %764 ]
  %628 = phi i1 [ false, %689 ], [ true, %701 ], [ false, %752 ], [ %754, %764 ]
  %629 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %765, %764 ]
  %630 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %766, %764 ]
  %631 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %767, %764 ]
  %632 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %768, %764 ]
  %633 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %769, %764 ]
  %634 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %770, %764 ]
  %635 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %771, %764 ]
  %636 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %772, %764 ]
  %637 = phi float [ 0.000000e+00, %689 ], [ 0.000000e+00, %701 ], [ 0.000000e+00, %752 ], [ %773, %764 ]
  %638 = or i1 %627, %628
  br i1 %638, label %813, label %774

; <label>:639                                     ; preds = %492
  %640 = fmul fast float %487, %488
  %641 = fcmp fast ugt float %640, 0.000000e+00
  br i1 %641, label %642, label %689

; <label>:642                                     ; preds = %639
  %643 = icmp ne i32 %453, %267
  %644 = icmp ne i32 %462, %268
  %645 = or i1 %643, %644
  br i1 %645, label %646, label %668

; <label>:646                                     ; preds = %642
  %647 = fmul fast float %468, 2.000000e+00
  %648 = fmul fast float %475, 2.000000e+00
  %649 = fsub fast float %283, %647
  %650 = fsub fast float %285, %648
  %651 = call float @dx.op.dot3.f32(i32 55, float %649, float %650, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %652 = call float @dx.op.unary.f32(i32 6, float %651)  ; FAbs(value)
  %653 = fcmp fast olt float %652, 0x3F8EB851E0000000
  %654 = and i1 %282, %653
  %655 = call float @dx.op.dot3.f32(i32 55, float %649, float %650, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %656 = call float @dx.op.unary.f32(i32 6, float %655)  ; FAbs(value)
  %657 = fcmp fast olt float %656, 0x3F8EB851E0000000
  %658 = and i1 %654, %657
  %659 = fmul fast float %649, %649
  %660 = fmul fast float %650, %650
  %661 = fadd fast float %659, %298
  %662 = fadd fast float %661, %660
  %663 = call float @dx.op.unary.f32(i32 24, float %662)  ; Sqrt(value)
  %664 = fcmp fast olt float %663, 0x3F8EB851E0000000
  %665 = and i1 %658, %664
  %666 = xor i1 %665, true
  %667 = xor i1 %325, true
  br label %668

; <label>:668                                     ; preds = %646, %642
  %669 = phi i1 [ %667, %646 ], [ false, %642 ]
  %670 = phi i1 [ %666, %646 ], [ false, %642 ]
  %671 = fcmp fast oeq float %496, 0.000000e+00
  %672 = call float @dx.op.binary.f32(i32 36, float %495, float %76)  ; FMin(a,b)
  %673 = select i1 %671, float %76, float %672
  %674 = fmul fast float %640, %70
  %675 = fmul fast float %640, %71
  %676 = fmul fast float %640, %72
  %677 = fmul fast float %640, %73
  %678 = fadd fast float %503, %674
  %679 = fadd fast float %502, %675
  %680 = fadd fast float %501, %676
  %681 = fadd fast float %500, %677
  %682 = fmul fast float %640, %74
  %683 = fmul fast float %640, %75
  %684 = fmul fast float %640, %77
  %685 = fadd fast float %499, %682
  %686 = fadd fast float %498, %683
  %687 = fadd fast float %497, %684
  %688 = fadd fast float %496, %640
  br label %689

; <label>:689                                     ; preds = %668, %639
  %690 = phi i1 [ %669, %668 ], [ false, %639 ]
  %691 = phi i1 [ %670, %668 ], [ false, %639 ]
  %692 = phi float [ %678, %668 ], [ %503, %639 ]
  %693 = phi float [ %679, %668 ], [ %502, %639 ]
  %694 = phi float [ %680, %668 ], [ %501, %639 ]
  %695 = phi float [ %681, %668 ], [ %500, %639 ]
  %696 = phi float [ %685, %668 ], [ %499, %639 ]
  %697 = phi float [ %686, %668 ], [ %498, %639 ]
  %698 = phi float [ %687, %668 ], [ %497, %639 ]
  %699 = phi float [ %688, %668 ], [ %496, %639 ]
  %700 = phi float [ %673, %668 ], [ %495, %639 ]
  br i1 %690, label %626, label %701

; <label>:701                                     ; preds = %689
  br i1 %691, label %626, label %702

; <label>:702                                     ; preds = %701
  %703 = fmul fast float %487, %481
  %704 = fcmp fast ugt float %703, 0.000000e+00
  br i1 %704, label %705, label %752

; <label>:705                                     ; preds = %702
  %706 = icmp ne i32 %452, %267
  %707 = icmp ne i32 %462, %268
  %708 = or i1 %706, %707
  br i1 %708, label %709, label %731

; <label>:709                                     ; preds = %705
  %710 = fmul fast float %474, 2.000000e+00
  %711 = fmul fast float %475, 2.000000e+00
  %712 = fsub fast float %283, %710
  %713 = fsub fast float %285, %711
  %714 = call float @dx.op.dot3.f32(i32 55, float %712, float %713, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %715 = call float @dx.op.unary.f32(i32 6, float %714)  ; FAbs(value)
  %716 = fcmp fast olt float %715, 0x3F8EB851E0000000
  %717 = and i1 %282, %716
  %718 = call float @dx.op.dot3.f32(i32 55, float %712, float %713, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %719 = call float @dx.op.unary.f32(i32 6, float %718)  ; FAbs(value)
  %720 = fcmp fast olt float %719, 0x3F8EB851E0000000
  %721 = and i1 %717, %720
  %722 = fmul fast float %712, %712
  %723 = fmul fast float %713, %713
  %724 = fadd fast float %722, %298
  %725 = fadd fast float %724, %723
  %726 = call float @dx.op.unary.f32(i32 24, float %725)  ; Sqrt(value)
  %727 = fcmp fast olt float %726, 0x3F8EB851E0000000
  %728 = and i1 %721, %727
  %729 = xor i1 %728, true
  %730 = xor i1 %325, true
  br label %731

; <label>:731                                     ; preds = %709, %705
  %732 = phi i1 [ %730, %709 ], [ false, %705 ]
  %733 = phi i1 [ %729, %709 ], [ false, %705 ]
  %734 = fcmp fast oeq float %699, 0.000000e+00
  %735 = call float @dx.op.binary.f32(i32 36, float %700, float %76)  ; FMin(a,b)
  %736 = select i1 %734, float %76, float %735
  %737 = fmul fast float %703, %70
  %738 = fmul fast float %703, %71
  %739 = fmul fast float %703, %72
  %740 = fmul fast float %703, %73
  %741 = fadd fast float %692, %737
  %742 = fadd fast float %693, %738
  %743 = fadd fast float %694, %739
  %744 = fadd fast float %695, %740
  %745 = fmul fast float %703, %74
  %746 = fmul fast float %703, %75
  %747 = fmul fast float %703, %77
  %748 = fadd fast float %696, %745
  %749 = fadd fast float %697, %746
  %750 = fadd fast float %698, %747
  %751 = fadd fast float %699, %703
  br label %752

; <label>:752                                     ; preds = %731, %702
  %753 = phi i1 [ %732, %731 ], [ false, %702 ]
  %754 = phi i1 [ %733, %731 ], [ false, %702 ]
  %755 = phi float [ %741, %731 ], [ %692, %702 ]
  %756 = phi float [ %742, %731 ], [ %693, %702 ]
  %757 = phi float [ %743, %731 ], [ %694, %702 ]
  %758 = phi float [ %744, %731 ], [ %695, %702 ]
  %759 = phi float [ %748, %731 ], [ %696, %702 ]
  %760 = phi float [ %749, %731 ], [ %697, %702 ]
  %761 = phi float [ %750, %731 ], [ %698, %702 ]
  %762 = phi float [ %751, %731 ], [ %699, %702 ]
  %763 = phi float [ %736, %731 ], [ %700, %702 ]
  br i1 %753, label %626, label %764

; <label>:764                                     ; preds = %752
  %765 = select i1 %754, float 0.000000e+00, float %763
  %766 = select i1 %754, float 0.000000e+00, float %762
  %767 = select i1 %754, float 0.000000e+00, float %761
  %768 = select i1 %754, float 0.000000e+00, float %760
  %769 = select i1 %754, float 0.000000e+00, float %759
  %770 = select i1 %754, float 0.000000e+00, float %758
  %771 = select i1 %754, float 0.000000e+00, float %757
  %772 = select i1 %754, float 0.000000e+00, float %756
  %773 = select i1 %754, float 0.000000e+00, float %755
  br label %626

; <label>:774                                     ; preds = %626
  %775 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %630)  ; IsFinite(value)
  %776 = xor i1 %775, true
  %777 = fcmp fast ole float %630, 0.000000e+00
  %778 = or i1 %777, %776
  br i1 %778, label %813, label %779

; <label>:779                                     ; preds = %774
  %780 = fdiv fast float %637, %630
  %781 = fdiv fast float %636, %630
  %782 = fdiv fast float %635, %630
  %783 = fdiv fast float %634, %630
  %784 = fdiv fast float %633, %630
  %785 = fdiv fast float %632, %630
  %786 = fdiv fast float %631, %630
  %787 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %780)  ; IsFinite(value)
  %788 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %781)  ; IsFinite(value)
  %789 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %782)  ; IsFinite(value)
  %790 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %783)  ; IsFinite(value)
  %791 = and i1 %787, %788
  %792 = and i1 %791, %789
  %793 = and i1 %792, %790
  %794 = fcmp fast ogt float %783, 0.000000e+00
  %795 = and i1 %794, %793
  %796 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %784)  ; IsFinite(value)
  %797 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %785)  ; IsFinite(value)
  %798 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %629)  ; IsFinite(value)
  %799 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %786)  ; IsFinite(value)
  %800 = and i1 %796, %797
  %801 = and i1 %800, %798
  %802 = and i1 %801, %799
  %803 = and i1 %795, %802
  %804 = fcmp fast ogt float %629, 0.000000e+00
  %805 = and i1 %804, %803
  %806 = select i1 %805, float %780, float %70
  %807 = select i1 %805, float %781, float %71
  %808 = select i1 %805, float %782, float %72
  %809 = select i1 %805, float %783, float %73
  %810 = select i1 %805, float %784, float %74
  %811 = select i1 %805, float %785, float %75
  %812 = select i1 %805, float %629, float %76
  br label %813

; <label>:813                                     ; preds = %779, %774, %626, %492
  %814 = phi i1 [ false, %774 ], [ %805, %779 ], [ false, %626 ], [ false, %492 ]
  %815 = phi float [ %70, %774 ], [ %806, %779 ], [ %70, %626 ], [ %70, %492 ]
  %816 = phi float [ %71, %774 ], [ %807, %779 ], [ %71, %626 ], [ %71, %492 ]
  %817 = phi float [ %72, %774 ], [ %808, %779 ], [ %72, %626 ], [ %72, %492 ]
  %818 = phi float [ %73, %774 ], [ %809, %779 ], [ %73, %626 ], [ %73, %492 ]
  %819 = phi float [ %74, %774 ], [ %810, %779 ], [ %74, %626 ], [ %74, %492 ]
  %820 = phi float [ %75, %774 ], [ %811, %779 ], [ %75, %626 ], [ %75, %492 ]
  %821 = phi float [ %76, %774 ], [ %812, %779 ], [ %76, %626 ], [ %76, %492 ]
  %822 = select i1 %814, float %815, float %70
  %823 = select i1 %814, float %816, float %71
  %824 = select i1 %814, float %817, float %72
  %825 = select i1 %814, float %818, float %73
  %826 = select i1 %814, float %819, float %74
  %827 = select i1 %814, float %820, float %75
  %828 = select i1 %814, float %821, float %76
  br label %829

; <label>:829                                     ; preds = %813, %339
  %830 = phi float [ %70, %339 ], [ %822, %813 ]
  %831 = phi float [ %71, %339 ], [ %823, %813 ]
  %832 = phi float [ %72, %339 ], [ %824, %813 ]
  %833 = phi float [ %73, %339 ], [ %825, %813 ]
  %834 = phi float [ %74, %339 ], [ %826, %813 ]
  %835 = phi float [ %75, %339 ], [ %827, %813 ]
  %836 = phi float [ %76, %339 ], [ %828, %813 ]
  %837 = select i1 %341, float %830, float %54
  %838 = select i1 %341, float %831, float %55
  %839 = select i1 %341, float %832, float %56
  %840 = select i1 %341, float %833, float %57
  %841 = select i1 %341, float %834, float %89
  %842 = select i1 %341, float %835, float %92
  br i1 %380, label %856, label %843

; <label>:843                                     ; preds = %829
  %844 = fadd fast float %54, 0x3FA47AE140000000
  %845 = fadd fast float %55, 0x3FA47AE140000000
  %846 = fadd fast float %56, 0x3FA47AE140000000
  %847 = fadd fast float %54, 0xBFA47AE140000000
  %848 = fadd fast float %55, 0xBFA47AE140000000
  %849 = fadd fast float %56, 0xBFA47AE140000000
  %850 = call float @dx.op.binary.f32(i32 35, float %837, float %847)  ; FMax(a,b)
  %851 = call float @dx.op.binary.f32(i32 35, float %838, float %848)  ; FMax(a,b)
  %852 = call float @dx.op.binary.f32(i32 35, float %839, float %849)  ; FMax(a,b)
  %853 = call float @dx.op.binary.f32(i32 36, float %850, float %844)  ; FMin(a,b)
  %854 = call float @dx.op.binary.f32(i32 36, float %851, float %845)  ; FMin(a,b)
  %855 = call float @dx.op.binary.f32(i32 36, float %852, float %846)  ; FMin(a,b)
  br label %856

; <label>:856                                     ; preds = %843, %829
  %857 = phi float [ %837, %829 ], [ %853, %843 ]
  %858 = phi float [ %838, %829 ], [ %854, %843 ]
  %859 = phi float [ %839, %829 ], [ %855, %843 ]
  %860 = fcmp fast ogt float %28, 5.000000e-01
  %861 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %344)  ; FMin(a,b)
  %862 = select i1 %860, float %861, float %344
  %863 = fadd fast float %836, 1.000000e+00
  %864 = select i1 %341, float %863, float 1.000000e+00
  %865 = call float @dx.op.binary.f32(i32 36, float %864, float %862)  ; FMin(a,b)
  %866 = select i1 %341, float %865, float 1.000000e+00
  %867 = fdiv fast float 1.000000e+00, %866
  %868 = call float @dx.op.binary.f32(i32 35, float %40, float %867)  ; FMax(a,b)
  %869 = select i1 %341, float %868, float 1.000000e+00
  %870 = fsub fast float %57, %840
  %871 = call float @dx.op.unary.f32(i32 6, float %870)  ; FAbs(value)
  %872 = fmul fast float %871, 2.500000e-01
  %873 = select i1 %341, float %872, float 1.000000e+00
  %874 = call float @dx.op.binary.f32(i32 35, float %869, float %873)  ; FMax(a,b)
  %875 = fsub fast float %89, %841
  %876 = fsub fast float %92, %842
  %877 = fmul fast float %874, %875
  %878 = fmul fast float %874, %876
  %879 = fadd fast float %877, %841
  %880 = fadd fast float %878, %842
  %881 = fsub fast float %54, %857
  %882 = fsub fast float %55, %858
  %883 = fsub fast float %56, %859
  %884 = fmul fast float %874, %881
  %885 = fmul fast float %874, %882
  %886 = fmul fast float %874, %883
  %887 = fmul fast float %874, %870
  %888 = fadd fast float %884, %857
  %889 = fadd fast float %885, %858
  %890 = fadd fast float %886, %859
  %891 = fadd fast float %887, %840
  %892 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %888)  ; IsFinite(value)
  %893 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %889)  ; IsFinite(value)
  %894 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %890)  ; IsFinite(value)
  %895 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %891)  ; IsFinite(value)
  %896 = and i1 %892, %893
  %897 = and i1 %896, %894
  %898 = and i1 %897, %895
  %899 = fcmp fast ogt float %891, 0.000000e+00
  %900 = and i1 %899, %898
  %901 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %879)  ; IsFinite(value)
  %902 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %880)  ; IsFinite(value)
  %903 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %866)  ; IsFinite(value)
  %904 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %905 = and i1 %901, %902
  %906 = and i1 %905, %903
  %907 = and i1 %906, %904
  %908 = and i1 %900, %907
  %909 = fcmp fast ogt float %866, 0.000000e+00
  %910 = and i1 %909, %908
  %911 = select i1 %910, float %888, float 0.000000e+00
  %912 = select i1 %910, float %889, float 0.000000e+00
  %913 = select i1 %910, float %890, float 0.000000e+00
  %914 = select i1 %910, float %891, float 0.000000e+00
  %915 = select i1 %910, float %879, float 0.000000e+00
  %916 = select i1 %910, float %880, float 0.000000e+00
  %917 = select i1 %910, float %866, float 0.000000e+00
  br label %918

; <label>:918                                     ; preds = %856, %337, %327
  %919 = phi float [ %328, %337 ], [ %328, %327 ], [ %911, %856 ]
  %920 = phi float [ %329, %337 ], [ %329, %327 ], [ %912, %856 ]
  %921 = phi float [ %330, %337 ], [ %330, %327 ], [ %913, %856 ]
  %922 = phi float [ %331, %337 ], [ %331, %327 ], [ %914, %856 ]
  %923 = phi float [ %332, %337 ], [ %332, %327 ], [ %915, %856 ]
  %924 = phi float [ %333, %337 ], [ %333, %327 ], [ %916, %856 ]
  %925 = phi float [ %338, %337 ], [ %334, %327 ], [ %917, %856 ]
  %926 = phi float [ %335, %337 ], [ %335, %327 ], [ 0.000000e+00, %856 ]
  %927 = call i32 @dx.op.legacyF32ToF16(i32 130, float %919)  ; LegacyF32ToF16(value)
  %928 = call i32 @dx.op.legacyF32ToF16(i32 130, float %920)  ; LegacyF32ToF16(value)
  %929 = call i32 @dx.op.legacyF32ToF16(i32 130, float %921)  ; LegacyF32ToF16(value)
  %930 = call i32 @dx.op.legacyF32ToF16(i32 130, float %922)  ; LegacyF32ToF16(value)
  %931 = call float @dx.op.legacyF16ToF32(i32 131, i32 %927)  ; LegacyF16ToF32(value)
  %932 = call float @dx.op.legacyF16ToF32(i32 131, i32 %928)  ; LegacyF16ToF32(value)
  %933 = call float @dx.op.legacyF16ToF32(i32 131, i32 %929)  ; LegacyF16ToF32(value)
  %934 = call float @dx.op.legacyF16ToF32(i32 131, i32 %930)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 0, float %919, float %920, float %921, float %922, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 16, float %923, float %924, float %925, float %926, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 32, float %931, float %932, float %933, float %934, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 48, float %923, float %924, float %925, float %926, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %935 = add nuw nsw i32 %78, 1
  %936 = icmp eq i32 %935, 32
  br i1 %936, label %1690, label %937, !llvm.loop !16

; <label>:937                                     ; preds = %918
  %938 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 8), align 16
  %939 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 9), align 4
  %940 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 10), align 8
  %941 = load i32, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.1.0, i32 0, i32 0), align 4
  %942 = load i32, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.1.1, i32 0, i32 0), align 4
  %943 = load i32, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.2, i32 0, i32 0), align 4
  br label %63

; <label>:944                                     ; preds = %11
  %945 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %946 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %947 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %948 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %57)  ; IsFinite(value)
  %949 = and i1 %945, %946
  %950 = and i1 %949, %947
  %951 = and i1 %950, %948
  %952 = fcmp fast ogt float %57, 0.000000e+00
  %953 = and i1 %952, %951
  %954 = call float @dx.op.dot3.f32(i32 55, float %54, float %55, float %56, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %955 = select i1 %953, float %954, float 0.000000e+00
  %956 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %955)  ; IsFinite(value)
  %957 = and i1 %953, %956
  %958 = fmul fast float %955, %955
  %959 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %958)  ; IsFinite(value)
  %960 = and i1 %957, %959
  %961 = fmul fast float %54, %54
  %962 = fmul fast float %55, %55
  %963 = fmul fast float %56, %56
  %964 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %961)  ; IsFinite(value)
  %965 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %962)  ; IsFinite(value)
  %966 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %963)  ; IsFinite(value)
  %967 = and i1 %964, %965
  %968 = and i1 %967, %966
  %969 = and i1 %960, %968
  %970 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %41)  ; IsFinite(value)
  %971 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %972 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 5.000000e-01)  ; IsFinite(value)
  %973 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %974 = and i1 %970, %971
  %975 = and i1 %974, %972
  %976 = and i1 %975, %973
  %977 = fmul fast float %35, -5.000000e-01
  %978 = fadd fast float %977, 5.000000e-01
  %979 = icmp eq i32 %58, 0
  br i1 %979, label %996, label %980

; <label>:980                                     ; preds = %944
  %981 = fsub fast float 5.000000e-01, %33
  %982 = fsub fast float 5.000000e-01, %34
  %983 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %981)  ; IsFinite(value)
  %984 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %982)  ; IsFinite(value)
  %985 = and i1 %983, %984
  %986 = fsub fast float %981, %978
  %987 = fsub fast float -0.000000e+00, %34
  %988 = call float @dx.op.unary.f32(i32 6, float %986)  ; FAbs(value)
  %989 = call float @dx.op.unary.f32(i32 6, float %987)  ; FAbs(value)
  %990 = fcmp fast ole float %988, 1.000000e+00
  %991 = fcmp fast ole float %989, 1.000000e+00
  %992 = and i1 %990, %991
  %993 = and i1 %985, %992
  %994 = select i1 %993, float %981, float %978
  %995 = select i1 %993, float %982, float 5.000000e-01
  br label %996

; <label>:996                                     ; preds = %980, %944
  %997 = phi float [ %978, %944 ], [ %994, %980 ]
  %998 = phi float [ 5.000000e-01, %944 ], [ %995, %980 ]
  %999 = icmp ne i32 %59, 0
  %1000 = and i1 %999, %976
  %1001 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %1002 = and i1 %1000, %1001
  %1003 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %997)  ; IsFinite(value)
  %1004 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %998)  ; IsFinite(value)
  %1005 = and i1 %1003, %1004
  %1006 = and i1 %1002, %1005
  %1007 = fcmp fast ogt float %997, 0.000000e+00
  %1008 = fcmp fast ogt float %998, 0.000000e+00
  %1009 = and i1 %1007, %1008
  %1010 = and i1 %1009, %1006
  %1011 = fcmp fast olt float %997, 1.000000e+00
  %1012 = fcmp fast olt float %998, 1.000000e+00
  %1013 = and i1 %1011, %1012
  %1014 = and i1 %1013, %1010
  br i1 %1014, label %1015, label %1070

; <label>:1015                                    ; preds = %996
  %1016 = call float @dx.op.unary.f32(i32 27, float %997)  ; Round_ni(value)
  %1017 = call float @dx.op.unary.f32(i32 27, float %998)  ; Round_ni(value)
  %1018 = fptosi float %1016 to i32
  %1019 = fptosi float %1017 to i32
  %1020 = call i32 @dx.op.binary.i32(i32 37, i32 %1018, i32 0)  ; IMax(a,b)
  %1021 = call i32 @dx.op.binary.i32(i32 37, i32 %1019, i32 0)  ; IMax(a,b)
  %1022 = call i32 @dx.op.binary.i32(i32 38, i32 %1020, i32 0)  ; IMin(a,b)
  %1023 = call i32 @dx.op.binary.i32(i32 38, i32 %1021, i32 0)  ; IMin(a,b)
  %1024 = add i32 %1022, -1
  %1025 = add i32 %1023, -1
  %1026 = call i32 @dx.op.binary.i32(i32 37, i32 %1024, i32 0)  ; IMax(a,b)
  %1027 = call i32 @dx.op.binary.i32(i32 37, i32 %1025, i32 0)  ; IMax(a,b)
  %1028 = and i32 %1026, 2147483647
  %1029 = and i32 %1027, 2147483647
  %1030 = uitofp i32 %1028 to float
  %1031 = uitofp i32 %1029 to float
  %1032 = fsub fast float 5.000000e-01, %997
  %1033 = fadd fast float %1030, %1032
  %1034 = fsub fast float 5.000000e-01, %998
  %1035 = fadd fast float %1031, %1034
  %1036 = call float @dx.op.unary.f32(i32 6, float %1033)  ; FAbs(value)
  %1037 = call float @dx.op.unary.f32(i32 6, float %1035)  ; FAbs(value)
  %1038 = call i32 @dx.op.binary.i32(i32 38, i32 %1022, i32 0)  ; IMin(a,b)
  %1039 = call i32 @dx.op.binary.i32(i32 38, i32 %1023, i32 0)  ; IMin(a,b)
  %1040 = and i32 %1038, 2147483647
  %1041 = and i32 %1039, 2147483647
  %1042 = uitofp i32 %1040 to float
  %1043 = uitofp i32 %1041 to float
  %1044 = fadd fast float %1042, %1032
  %1045 = fadd fast float %1043, %1034
  %1046 = call float @dx.op.unary.f32(i32 6, float %1044)  ; FAbs(value)
  %1047 = call float @dx.op.unary.f32(i32 6, float %1045)  ; FAbs(value)
  %1048 = fcmp fast olt float %1046, %1036
  %1049 = select i1 %1048, i32 %1038, i32 %1026
  %1050 = select i1 %1048, float %1046, float %1036
  %1051 = fcmp fast olt float %1047, %1037
  %1052 = select i1 %1051, i32 %1039, i32 %1027
  %1053 = select i1 %1051, float %1047, float %1037
  %1054 = add i32 %1022, 1
  %1055 = add i32 %1023, 1
  %1056 = call i32 @dx.op.binary.i32(i32 38, i32 %1054, i32 0)  ; IMin(a,b)
  %1057 = call i32 @dx.op.binary.i32(i32 38, i32 %1055, i32 0)  ; IMin(a,b)
  %1058 = and i32 %1056, 2147483647
  %1059 = and i32 %1057, 2147483647
  %1060 = uitofp i32 %1058 to float
  %1061 = uitofp i32 %1059 to float
  %1062 = fadd fast float %1060, %1032
  %1063 = fadd fast float %1061, %1034
  %1064 = call float @dx.op.unary.f32(i32 6, float %1062)  ; FAbs(value)
  %1065 = call float @dx.op.unary.f32(i32 6, float %1063)  ; FAbs(value)
  %1066 = fcmp fast olt float %1064, %1050
  %1067 = select i1 %1066, i32 %1056, i32 %1049
  %1068 = fcmp fast olt float %1065, %1053
  %1069 = select i1 %1068, i32 %1057, i32 %1052
  br label %1070

; <label>:1070                                    ; preds = %1015, %996
  %1071 = phi i32 [ 0, %996 ], [ %1067, %1015 ]
  %1072 = phi i32 [ 0, %996 ], [ %1069, %1015 ]
  %1073 = and i32 %1071, 2147483647
  %1074 = and i32 %1072, 2147483647
  %1075 = uitofp i32 %1073 to float
  %1076 = uitofp i32 %1074 to float
  %1077 = fadd fast float %1075, 5.000000e-01
  %1078 = fadd fast float %1076, 5.000000e-01
  %1079 = fmul fast float %1077, 2.000000e+00
  %1080 = fmul fast float %1078, 2.000000e+00
  %1081 = fadd fast float %1080, -1.000000e+00
  %1082 = fsub fast float 1.000000e+00, %35
  %1083 = fsub fast float %1082, %1079
  %1084 = fsub fast float -0.000000e+00, %1081
  %1085 = fsub fast float 5.000000e-01, %36
  %1086 = call float @dx.op.dot3.f32(i32 55, float %1083, float %1084, float %1085, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1087 = call float @dx.op.unary.f32(i32 6, float %1086)  ; FAbs(value)
  %1088 = fcmp fast olt float %1087, 0x3F8EB851E0000000
  %1089 = fmul fast float %1083, %1083
  %1090 = fmul fast float %1081, %1081
  %1091 = fmul fast float %1085, %1085
  %1092 = fadd fast float %1089, %1091
  %1093 = fadd fast float %1092, %1090
  %1094 = call float @dx.op.unary.f32(i32 24, float %1093)  ; Sqrt(value)
  %1095 = fcmp fast olt float %1094, 0x3F8EB851E0000000
  %1096 = and i1 %1088, %1095
  %1097 = and i1 %1014, %1096
  %1098 = fcmp fast olt float %29, 5.000000e-01
  %1099 = and i1 %1098, %1097
  %1100 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %46)  ; IsFinite(value)
  %1101 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %47)  ; IsFinite(value)
  %1102 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %48)  ; IsFinite(value)
  %1103 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %49)  ; IsFinite(value)
  %1104 = and i1 %1100, %1101
  %1105 = and i1 %1104, %1102
  %1106 = and i1 %1105, %1103
  %1107 = fcmp fast ogt float %49, 0.000000e+00
  %1108 = and i1 %1107, %1106
  %1109 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %1110 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %19)  ; IsFinite(value)
  %1111 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %20)  ; IsFinite(value)
  %1112 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %21)  ; IsFinite(value)
  %1113 = and i1 %1109, %1110
  %1114 = and i1 %1113, %1111
  %1115 = and i1 %1114, %1112
  %1116 = and i1 %1108, %1115
  %1117 = fcmp fast ogt float %20, 0.000000e+00
  %1118 = and i1 %1117, %1116
  %1119 = and i1 %1099, %1118
  br i1 %969, label %1132, label %1120

; <label>:1120                                    ; preds = %1070
  %1121 = select i1 %1119, float %46, float 0.000000e+00
  %1122 = select i1 %1119, float %47, float 0.000000e+00
  %1123 = select i1 %1119, float %48, float 0.000000e+00
  %1124 = select i1 %1119, float %49, float 0.000000e+00
  %1125 = select i1 %1119, float %18, float 0.000000e+00
  %1126 = select i1 %1119, float %19, float 0.000000e+00
  %1127 = select i1 %1119, float %20, float 0.000000e+00
  %1128 = select i1 %1119, float %21, float 0.000000e+00
  %1129 = fcmp fast ogt float %28, 5.000000e-01
  br i1 %1129, label %1130, label %1673

; <label>:1130                                    ; preds = %1120
  %1131 = call float @dx.op.binary.f32(i32 36, float %1127, float 2.000000e+00)  ; FMin(a,b)
  br label %1673

; <label>:1132                                    ; preds = %1070
  %1133 = fcmp ule float %30, 5.000000e-01
  %1134 = and i1 %1119, %1133
  %1135 = fcmp fast olt float %28, 5.000000e-01
  %1136 = and i1 %1135, %1134
  %1137 = sitofp i32 %60 to float
  %1138 = fcmp fast oge float %20, %1137
  %1139 = and i1 %1138, %1136
  %1140 = or i32 %1072, %1071
  %1141 = icmp eq i32 %1140, 0
  %1142 = and i1 %1141, %1139
  %1143 = fcmp fast oeq float %997, 5.000000e-01
  %1144 = fcmp fast oeq float %998, 5.000000e-01
  %1145 = and i1 %1143, %1144
  %1146 = and i1 %1145, %1142
  %1147 = fcmp fast oeq float %33, 0.000000e+00
  %1148 = fcmp fast oeq float %34, 0.000000e+00
  %1149 = and i1 %1147, %1148
  %1150 = or i1 %979, %1149
  %1151 = and i1 %1150, %1146
  %1152 = fcmp fast oeq float %35, 0.000000e+00
  %1153 = and i1 %1152, %1151
  %1154 = fcmp fast oeq float %36, 5.000000e-01
  %1155 = and i1 %1154, %1153
  %1156 = xor i1 %1155, true
  %1157 = and i1 %1134, %1156
  br i1 %1157, label %1158, label %1584

; <label>:1158                                    ; preds = %1132
  %1159 = call float @dx.op.unary.f32(i32 27, float %997)  ; Round_ni(value)
  %1160 = call float @dx.op.unary.f32(i32 27, float %998)  ; Round_ni(value)
  %1161 = fptosi float %1159 to i32
  %1162 = fptosi float %1160 to i32
  %1163 = call i32 @dx.op.binary.i32(i32 37, i32 %1161, i32 0)  ; IMax(a,b)
  %1164 = call i32 @dx.op.binary.i32(i32 37, i32 %1162, i32 0)  ; IMax(a,b)
  %1165 = call i32 @dx.op.binary.i32(i32 38, i32 %1163, i32 0)  ; IMin(a,b)
  %1166 = call i32 @dx.op.binary.i32(i32 38, i32 %1164, i32 0)  ; IMin(a,b)
  %1167 = add i32 %1165, -1
  %1168 = add i32 %1166, -1
  %1169 = call i32 @dx.op.binary.i32(i32 37, i32 %1167, i32 0)  ; IMax(a,b)
  %1170 = call i32 @dx.op.binary.i32(i32 37, i32 %1168, i32 0)  ; IMax(a,b)
  %1171 = and i32 %1169, 2147483647
  %1172 = and i32 %1170, 2147483647
  %1173 = uitofp i32 %1171 to float
  %1174 = uitofp i32 %1172 to float
  %1175 = fsub fast float 5.000000e-01, %997
  %1176 = fadd fast float %1173, %1175
  %1177 = fsub fast float 5.000000e-01, %998
  %1178 = fadd fast float %1174, %1177
  %1179 = call float @dx.op.unary.f32(i32 6, float %1176)  ; FAbs(value)
  %1180 = call float @dx.op.unary.f32(i32 6, float %1178)  ; FAbs(value)
  %1181 = call i32 @dx.op.binary.i32(i32 38, i32 %1165, i32 0)  ; IMin(a,b)
  %1182 = call i32 @dx.op.binary.i32(i32 38, i32 %1166, i32 0)  ; IMin(a,b)
  %1183 = and i32 %1181, 2147483647
  %1184 = and i32 %1182, 2147483647
  %1185 = uitofp i32 %1183 to float
  %1186 = uitofp i32 %1184 to float
  %1187 = fadd fast float %1185, %1175
  %1188 = fadd fast float %1186, %1177
  %1189 = call float @dx.op.unary.f32(i32 6, float %1187)  ; FAbs(value)
  %1190 = call float @dx.op.unary.f32(i32 6, float %1188)  ; FAbs(value)
  %1191 = fcmp fast olt float %1189, %1179
  %1192 = select i1 %1191, i32 %1181, i32 %1169
  %1193 = select i1 %1191, float %1189, float %1179
  %1194 = fcmp fast olt float %1190, %1180
  %1195 = select i1 %1194, i32 %1182, i32 %1170
  %1196 = select i1 %1194, float %1190, float %1180
  %1197 = add i32 %1165, 1
  %1198 = add i32 %1166, 1
  %1199 = call i32 @dx.op.binary.i32(i32 38, i32 %1197, i32 0)  ; IMin(a,b)
  %1200 = call i32 @dx.op.binary.i32(i32 38, i32 %1198, i32 0)  ; IMin(a,b)
  %1201 = and i32 %1199, 2147483647
  %1202 = and i32 %1200, 2147483647
  %1203 = uitofp i32 %1201 to float
  %1204 = uitofp i32 %1202 to float
  %1205 = fadd fast float %1203, %1175
  %1206 = fadd fast float %1204, %1177
  %1207 = call float @dx.op.unary.f32(i32 6, float %1205)  ; FAbs(value)
  %1208 = call float @dx.op.unary.f32(i32 6, float %1206)  ; FAbs(value)
  %1209 = fcmp fast olt float %1207, %1193
  %1210 = select i1 %1209, i32 %1199, i32 %1192
  %1211 = fcmp fast olt float %1208, %1196
  %1212 = select i1 %1211, i32 %1200, i32 %1195
  %1213 = and i32 %1210, 2147483647
  %1214 = and i32 %1212, 2147483647
  %1215 = uitofp i32 %1213 to float
  %1216 = uitofp i32 %1214 to float
  %1217 = fadd fast float %1215, 5.000000e-01
  %1218 = fadd fast float %1216, 5.000000e-01
  %1219 = fcmp fast olt float %997, %1217
  br i1 %1219, label %1220, label %1223

; <label>:1220                                    ; preds = %1158
  %1221 = add nsw i32 %1210, -1
  %1222 = call i32 @dx.op.binary.i32(i32 37, i32 %1221, i32 0)  ; IMax(a,b)
  br label %1226

; <label>:1223                                    ; preds = %1158
  %1224 = add i32 %1210, 1
  %1225 = call i32 @dx.op.binary.i32(i32 40, i32 %1224, i32 0)  ; UMin(a,b)
  br label %1226

; <label>:1226                                    ; preds = %1223, %1220
  %1227 = phi i32 [ %1210, %1220 ], [ %1225, %1223 ]
  %1228 = phi i32 [ %1222, %1220 ], [ %1210, %1223 ]
  %1229 = fcmp fast olt float %998, %1218
  br i1 %1229, label %1230, label %1233

; <label>:1230                                    ; preds = %1226
  %1231 = add nsw i32 %1212, -1
  %1232 = call i32 @dx.op.binary.i32(i32 37, i32 %1231, i32 0)  ; IMax(a,b)
  br label %1236

; <label>:1233                                    ; preds = %1226
  %1234 = add i32 %1212, 1
  %1235 = call i32 @dx.op.binary.i32(i32 40, i32 %1234, i32 0)  ; UMin(a,b)
  br label %1236

; <label>:1236                                    ; preds = %1233, %1230
  %1237 = phi i32 [ %1212, %1230 ], [ %1235, %1233 ]
  %1238 = phi i32 [ %1232, %1230 ], [ %1212, %1233 ]
  %1239 = and i32 %1228, 2147483647
  %1240 = and i32 %1238, 2147483647
  %1241 = uitofp i32 %1239 to float
  %1242 = uitofp i32 %1240 to float
  %1243 = fadd fast float %1241, 5.000000e-01
  %1244 = fadd fast float %1242, 5.000000e-01
  %1245 = and i32 %1227, 2147483647
  %1246 = and i32 %1237, 2147483647
  %1247 = uitofp i32 %1245 to float
  %1248 = uitofp i32 %1246 to float
  %1249 = fadd fast float %1247, 5.000000e-01
  %1250 = fadd fast float %1248, 5.000000e-01
  %1251 = fcmp fast ogt float %1249, %1243
  %1252 = fsub fast float %997, %1243
  %1253 = fsub fast float %1249, %1243
  %1254 = fdiv fast float %1252, %1253
  %1255 = call float @dx.op.unary.f32(i32 7, float %1254)  ; Saturate(value)
  %1256 = select i1 %1251, float %1255, float 0.000000e+00
  %1257 = fcmp fast ogt float %1250, %1244
  %1258 = fsub fast float %998, %1244
  %1259 = fsub fast float %1250, %1244
  %1260 = fdiv fast float %1258, %1259
  %1261 = call float @dx.op.unary.f32(i32 7, float %1260)  ; Saturate(value)
  %1262 = select i1 %1257, float %1261, float 0.000000e+00
  %1263 = fsub fast float 1.000000e+00, %1256
  %1264 = fsub fast float 1.000000e+00, %1262
  %1265 = fmul fast float %1264, %1263
  %1266 = fcmp fast ugt float %1265, 0.000000e+00
  br i1 %1266, label %1280, label %1311

; <label>:1267                                    ; preds = %1381, %1369, %1323, %1311
  %1268 = phi i1 [ true, %1311 ], [ false, %1323 ], [ true, %1369 ], [ false, %1381 ]
  %1269 = phi i1 [ false, %1311 ], [ true, %1323 ], [ false, %1369 ], [ %1371, %1381 ]
  %1270 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1382, %1381 ]
  %1271 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1383, %1381 ]
  %1272 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1384, %1381 ]
  %1273 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1385, %1381 ]
  %1274 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1386, %1381 ]
  %1275 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1387, %1381 ]
  %1276 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1388, %1381 ]
  %1277 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1389, %1381 ]
  %1278 = phi float [ 0.000000e+00, %1311 ], [ 0.000000e+00, %1323 ], [ 0.000000e+00, %1369 ], [ %1390, %1381 ]
  %1279 = or i1 %1268, %1269
  br i1 %1279, label %1568, label %1404

; <label>:1280                                    ; preds = %1236
  %1281 = icmp ne i32 %1228, %1071
  %1282 = icmp ne i32 %1238, %1072
  %1283 = or i1 %1281, %1282
  br i1 %1283, label %1284, label %1301

; <label>:1284                                    ; preds = %1280
  %1285 = fmul fast float %1243, 2.000000e+00
  %1286 = fmul fast float %1244, 2.000000e+00
  %1287 = fadd fast float %1286, -1.000000e+00
  %1288 = fsub fast float %1082, %1285
  %1289 = fsub fast float -0.000000e+00, %1287
  %1290 = call float @dx.op.dot3.f32(i32 55, float %1288, float %1289, float %1085, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1291 = call float @dx.op.unary.f32(i32 6, float %1290)  ; FAbs(value)
  %1292 = fmul fast float %1288, %1288
  %1293 = fmul fast float %1287, %1287
  %1294 = fadd fast float %1292, %1091
  %1295 = fadd fast float %1294, %1293
  %1296 = call float @dx.op.unary.f32(i32 24, float %1295)  ; Sqrt(value)
  %1297 = fcmp uge float %1291, 0x3F8EB851E0000000
  %1298 = fcmp uge float %1296, 0x3F8EB851E0000000
  %1299 = or i1 %1298, %1297
  %1300 = xor i1 %1118, true
  br label %1301

; <label>:1301                                    ; preds = %1284, %1280
  %1302 = phi i1 [ %1300, %1284 ], [ false, %1280 ]
  %1303 = phi i1 [ %1299, %1284 ], [ false, %1280 ]
  %1304 = fmul fast float %1265, %46
  %1305 = fmul fast float %1265, %47
  %1306 = fmul fast float %1265, %48
  %1307 = fmul fast float %1265, %49
  %1308 = fmul fast float %1265, %18
  %1309 = fmul fast float %1265, %19
  %1310 = fmul fast float %1265, %21
  br label %1311

; <label>:1311                                    ; preds = %1301, %1236
  %1312 = phi i1 [ %1302, %1301 ], [ false, %1236 ]
  %1313 = phi i1 [ %1303, %1301 ], [ false, %1236 ]
  %1314 = phi float [ %1304, %1301 ], [ 0.000000e+00, %1236 ]
  %1315 = phi float [ %1305, %1301 ], [ 0.000000e+00, %1236 ]
  %1316 = phi float [ %1306, %1301 ], [ 0.000000e+00, %1236 ]
  %1317 = phi float [ %1307, %1301 ], [ 0.000000e+00, %1236 ]
  %1318 = phi float [ %1308, %1301 ], [ 0.000000e+00, %1236 ]
  %1319 = phi float [ %1309, %1301 ], [ 0.000000e+00, %1236 ]
  %1320 = phi float [ %1310, %1301 ], [ 0.000000e+00, %1236 ]
  %1321 = phi float [ %1265, %1301 ], [ 0.000000e+00, %1236 ]
  %1322 = phi float [ %20, %1301 ], [ 0.000000e+00, %1236 ]
  br i1 %1312, label %1267, label %1323

; <label>:1323                                    ; preds = %1311
  br i1 %1313, label %1267, label %1324

; <label>:1324                                    ; preds = %1323
  %1325 = fmul fast float %1264, %1256
  %1326 = fcmp fast ugt float %1325, 0.000000e+00
  br i1 %1326, label %1327, label %1369

; <label>:1327                                    ; preds = %1324
  %1328 = icmp ne i32 %1227, %1071
  %1329 = icmp ne i32 %1238, %1072
  %1330 = or i1 %1328, %1329
  br i1 %1330, label %1331, label %1348

; <label>:1331                                    ; preds = %1327
  %1332 = fmul fast float %1249, 2.000000e+00
  %1333 = fmul fast float %1244, 2.000000e+00
  %1334 = fadd fast float %1333, -1.000000e+00
  %1335 = fsub fast float %1082, %1332
  %1336 = fsub fast float -0.000000e+00, %1334
  %1337 = call float @dx.op.dot3.f32(i32 55, float %1335, float %1336, float %1085, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1338 = call float @dx.op.unary.f32(i32 6, float %1337)  ; FAbs(value)
  %1339 = fmul fast float %1335, %1335
  %1340 = fmul fast float %1334, %1334
  %1341 = fadd fast float %1339, %1091
  %1342 = fadd fast float %1341, %1340
  %1343 = call float @dx.op.unary.f32(i32 24, float %1342)  ; Sqrt(value)
  %1344 = fcmp uge float %1338, 0x3F8EB851E0000000
  %1345 = fcmp uge float %1343, 0x3F8EB851E0000000
  %1346 = or i1 %1345, %1344
  %1347 = xor i1 %1118, true
  br label %1348

; <label>:1348                                    ; preds = %1331, %1327
  %1349 = phi i1 [ %1347, %1331 ], [ false, %1327 ]
  %1350 = phi i1 [ %1346, %1331 ], [ false, %1327 ]
  %1351 = fcmp fast oeq float %1321, 0.000000e+00
  %1352 = call float @dx.op.binary.f32(i32 36, float %1322, float %20)  ; FMin(a,b)
  %1353 = select i1 %1351, float %20, float %1352
  %1354 = fmul fast float %1325, %46
  %1355 = fmul fast float %1325, %47
  %1356 = fmul fast float %1325, %48
  %1357 = fmul fast float %1325, %49
  %1358 = fadd fast float %1314, %1354
  %1359 = fadd fast float %1315, %1355
  %1360 = fadd fast float %1316, %1356
  %1361 = fadd fast float %1317, %1357
  %1362 = fmul fast float %1325, %18
  %1363 = fmul fast float %1325, %19
  %1364 = fmul fast float %1325, %21
  %1365 = fadd fast float %1318, %1362
  %1366 = fadd fast float %1319, %1363
  %1367 = fadd fast float %1320, %1364
  %1368 = fadd fast float %1321, %1325
  br label %1369

; <label>:1369                                    ; preds = %1348, %1324
  %1370 = phi i1 [ %1349, %1348 ], [ false, %1324 ]
  %1371 = phi i1 [ %1350, %1348 ], [ false, %1324 ]
  %1372 = phi float [ %1358, %1348 ], [ %1314, %1324 ]
  %1373 = phi float [ %1359, %1348 ], [ %1315, %1324 ]
  %1374 = phi float [ %1360, %1348 ], [ %1316, %1324 ]
  %1375 = phi float [ %1361, %1348 ], [ %1317, %1324 ]
  %1376 = phi float [ %1365, %1348 ], [ %1318, %1324 ]
  %1377 = phi float [ %1366, %1348 ], [ %1319, %1324 ]
  %1378 = phi float [ %1367, %1348 ], [ %1320, %1324 ]
  %1379 = phi float [ %1368, %1348 ], [ %1321, %1324 ]
  %1380 = phi float [ %1353, %1348 ], [ %1322, %1324 ]
  br i1 %1370, label %1267, label %1381

; <label>:1381                                    ; preds = %1369
  %1382 = select i1 %1371, float 0.000000e+00, float %1380
  %1383 = select i1 %1371, float 0.000000e+00, float %1379
  %1384 = select i1 %1371, float 0.000000e+00, float %1378
  %1385 = select i1 %1371, float 0.000000e+00, float %1377
  %1386 = select i1 %1371, float 0.000000e+00, float %1376
  %1387 = select i1 %1371, float 0.000000e+00, float %1375
  %1388 = select i1 %1371, float 0.000000e+00, float %1374
  %1389 = select i1 %1371, float 0.000000e+00, float %1373
  %1390 = select i1 %1371, float 0.000000e+00, float %1372
  br label %1267

; <label>:1391                                    ; preds = %1519, %1507, %1461, %1449
  %1392 = phi i1 [ true, %1449 ], [ false, %1461 ], [ true, %1507 ], [ false, %1519 ]
  %1393 = phi i1 [ false, %1449 ], [ true, %1461 ], [ false, %1507 ], [ %1509, %1519 ]
  %1394 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1520, %1519 ]
  %1395 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1521, %1519 ]
  %1396 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1522, %1519 ]
  %1397 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1523, %1519 ]
  %1398 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1524, %1519 ]
  %1399 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1525, %1519 ]
  %1400 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1526, %1519 ]
  %1401 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1527, %1519 ]
  %1402 = phi float [ 0.000000e+00, %1449 ], [ 0.000000e+00, %1461 ], [ 0.000000e+00, %1507 ], [ %1528, %1519 ]
  %1403 = or i1 %1392, %1393
  br i1 %1403, label %1568, label %1529

; <label>:1404                                    ; preds = %1267
  %1405 = fmul fast float %1262, %1263
  %1406 = fcmp fast ugt float %1405, 0.000000e+00
  br i1 %1406, label %1407, label %1449

; <label>:1407                                    ; preds = %1404
  %1408 = icmp ne i32 %1228, %1071
  %1409 = icmp ne i32 %1237, %1072
  %1410 = or i1 %1408, %1409
  br i1 %1410, label %1411, label %1428

; <label>:1411                                    ; preds = %1407
  %1412 = fmul fast float %1243, 2.000000e+00
  %1413 = fmul fast float %1250, 2.000000e+00
  %1414 = fadd fast float %1413, -1.000000e+00
  %1415 = fsub fast float %1082, %1412
  %1416 = fsub fast float -0.000000e+00, %1414
  %1417 = call float @dx.op.dot3.f32(i32 55, float %1415, float %1416, float %1085, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1418 = call float @dx.op.unary.f32(i32 6, float %1417)  ; FAbs(value)
  %1419 = fmul fast float %1415, %1415
  %1420 = fmul fast float %1414, %1414
  %1421 = fadd fast float %1419, %1091
  %1422 = fadd fast float %1421, %1420
  %1423 = call float @dx.op.unary.f32(i32 24, float %1422)  ; Sqrt(value)
  %1424 = fcmp uge float %1418, 0x3F8EB851E0000000
  %1425 = fcmp uge float %1423, 0x3F8EB851E0000000
  %1426 = or i1 %1425, %1424
  %1427 = xor i1 %1118, true
  br label %1428

; <label>:1428                                    ; preds = %1411, %1407
  %1429 = phi i1 [ %1427, %1411 ], [ false, %1407 ]
  %1430 = phi i1 [ %1426, %1411 ], [ false, %1407 ]
  %1431 = fcmp fast oeq float %1271, 0.000000e+00
  %1432 = call float @dx.op.binary.f32(i32 36, float %1270, float %20)  ; FMin(a,b)
  %1433 = select i1 %1431, float %20, float %1432
  %1434 = fmul fast float %1405, %46
  %1435 = fmul fast float %1405, %47
  %1436 = fmul fast float %1405, %48
  %1437 = fmul fast float %1405, %49
  %1438 = fadd fast float %1278, %1434
  %1439 = fadd fast float %1277, %1435
  %1440 = fadd fast float %1276, %1436
  %1441 = fadd fast float %1275, %1437
  %1442 = fmul fast float %1405, %18
  %1443 = fmul fast float %1405, %19
  %1444 = fmul fast float %1405, %21
  %1445 = fadd fast float %1274, %1442
  %1446 = fadd fast float %1273, %1443
  %1447 = fadd fast float %1272, %1444
  %1448 = fadd fast float %1271, %1405
  br label %1449

; <label>:1449                                    ; preds = %1428, %1404
  %1450 = phi i1 [ %1429, %1428 ], [ false, %1404 ]
  %1451 = phi i1 [ %1430, %1428 ], [ false, %1404 ]
  %1452 = phi float [ %1438, %1428 ], [ %1278, %1404 ]
  %1453 = phi float [ %1439, %1428 ], [ %1277, %1404 ]
  %1454 = phi float [ %1440, %1428 ], [ %1276, %1404 ]
  %1455 = phi float [ %1441, %1428 ], [ %1275, %1404 ]
  %1456 = phi float [ %1445, %1428 ], [ %1274, %1404 ]
  %1457 = phi float [ %1446, %1428 ], [ %1273, %1404 ]
  %1458 = phi float [ %1447, %1428 ], [ %1272, %1404 ]
  %1459 = phi float [ %1448, %1428 ], [ %1271, %1404 ]
  %1460 = phi float [ %1433, %1428 ], [ %1270, %1404 ]
  br i1 %1450, label %1391, label %1461

; <label>:1461                                    ; preds = %1449
  br i1 %1451, label %1391, label %1462

; <label>:1462                                    ; preds = %1461
  %1463 = fmul fast float %1262, %1256
  %1464 = fcmp fast ugt float %1463, 0.000000e+00
  br i1 %1464, label %1465, label %1507

; <label>:1465                                    ; preds = %1462
  %1466 = icmp ne i32 %1227, %1071
  %1467 = icmp ne i32 %1237, %1072
  %1468 = or i1 %1466, %1467
  br i1 %1468, label %1469, label %1486

; <label>:1469                                    ; preds = %1465
  %1470 = fmul fast float %1249, 2.000000e+00
  %1471 = fmul fast float %1250, 2.000000e+00
  %1472 = fadd fast float %1471, -1.000000e+00
  %1473 = fsub fast float %1082, %1470
  %1474 = fsub fast float -0.000000e+00, %1472
  %1475 = call float @dx.op.dot3.f32(i32 55, float %1473, float %1474, float %1085, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1476 = call float @dx.op.unary.f32(i32 6, float %1475)  ; FAbs(value)
  %1477 = fmul fast float %1473, %1473
  %1478 = fmul fast float %1472, %1472
  %1479 = fadd fast float %1477, %1091
  %1480 = fadd fast float %1479, %1478
  %1481 = call float @dx.op.unary.f32(i32 24, float %1480)  ; Sqrt(value)
  %1482 = fcmp uge float %1476, 0x3F8EB851E0000000
  %1483 = fcmp uge float %1481, 0x3F8EB851E0000000
  %1484 = or i1 %1483, %1482
  %1485 = xor i1 %1118, true
  br label %1486

; <label>:1486                                    ; preds = %1469, %1465
  %1487 = phi i1 [ %1485, %1469 ], [ false, %1465 ]
  %1488 = phi i1 [ %1484, %1469 ], [ false, %1465 ]
  %1489 = fcmp fast oeq float %1459, 0.000000e+00
  %1490 = call float @dx.op.binary.f32(i32 36, float %1460, float %20)  ; FMin(a,b)
  %1491 = select i1 %1489, float %20, float %1490
  %1492 = fmul fast float %1463, %46
  %1493 = fmul fast float %1463, %47
  %1494 = fmul fast float %1463, %48
  %1495 = fmul fast float %1463, %49
  %1496 = fadd fast float %1452, %1492
  %1497 = fadd fast float %1453, %1493
  %1498 = fadd fast float %1454, %1494
  %1499 = fadd fast float %1455, %1495
  %1500 = fmul fast float %1463, %18
  %1501 = fmul fast float %1463, %19
  %1502 = fmul fast float %1463, %21
  %1503 = fadd fast float %1456, %1500
  %1504 = fadd fast float %1457, %1501
  %1505 = fadd fast float %1458, %1502
  %1506 = fadd fast float %1459, %1463
  br label %1507

; <label>:1507                                    ; preds = %1486, %1462
  %1508 = phi i1 [ %1487, %1486 ], [ false, %1462 ]
  %1509 = phi i1 [ %1488, %1486 ], [ false, %1462 ]
  %1510 = phi float [ %1496, %1486 ], [ %1452, %1462 ]
  %1511 = phi float [ %1497, %1486 ], [ %1453, %1462 ]
  %1512 = phi float [ %1498, %1486 ], [ %1454, %1462 ]
  %1513 = phi float [ %1499, %1486 ], [ %1455, %1462 ]
  %1514 = phi float [ %1503, %1486 ], [ %1456, %1462 ]
  %1515 = phi float [ %1504, %1486 ], [ %1457, %1462 ]
  %1516 = phi float [ %1505, %1486 ], [ %1458, %1462 ]
  %1517 = phi float [ %1506, %1486 ], [ %1459, %1462 ]
  %1518 = phi float [ %1491, %1486 ], [ %1460, %1462 ]
  br i1 %1508, label %1391, label %1519

; <label>:1519                                    ; preds = %1507
  %1520 = select i1 %1509, float 0.000000e+00, float %1518
  %1521 = select i1 %1509, float 0.000000e+00, float %1517
  %1522 = select i1 %1509, float 0.000000e+00, float %1516
  %1523 = select i1 %1509, float 0.000000e+00, float %1515
  %1524 = select i1 %1509, float 0.000000e+00, float %1514
  %1525 = select i1 %1509, float 0.000000e+00, float %1513
  %1526 = select i1 %1509, float 0.000000e+00, float %1512
  %1527 = select i1 %1509, float 0.000000e+00, float %1511
  %1528 = select i1 %1509, float 0.000000e+00, float %1510
  br label %1391

; <label>:1529                                    ; preds = %1391
  %1530 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1395)  ; IsFinite(value)
  %1531 = xor i1 %1530, true
  %1532 = fcmp fast ole float %1395, 0.000000e+00
  %1533 = or i1 %1532, %1531
  br i1 %1533, label %1568, label %1534

; <label>:1534                                    ; preds = %1529
  %1535 = fdiv fast float %1402, %1395
  %1536 = fdiv fast float %1401, %1395
  %1537 = fdiv fast float %1400, %1395
  %1538 = fdiv fast float %1399, %1395
  %1539 = fdiv fast float %1398, %1395
  %1540 = fdiv fast float %1397, %1395
  %1541 = fdiv fast float %1396, %1395
  %1542 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1535)  ; IsFinite(value)
  %1543 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1536)  ; IsFinite(value)
  %1544 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1537)  ; IsFinite(value)
  %1545 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1538)  ; IsFinite(value)
  %1546 = and i1 %1542, %1543
  %1547 = and i1 %1546, %1544
  %1548 = and i1 %1547, %1545
  %1549 = fcmp fast ogt float %1538, 0.000000e+00
  %1550 = and i1 %1549, %1548
  %1551 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1539)  ; IsFinite(value)
  %1552 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1540)  ; IsFinite(value)
  %1553 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1394)  ; IsFinite(value)
  %1554 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1541)  ; IsFinite(value)
  %1555 = and i1 %1551, %1552
  %1556 = and i1 %1555, %1553
  %1557 = and i1 %1556, %1554
  %1558 = and i1 %1550, %1557
  %1559 = fcmp fast ogt float %1394, 0.000000e+00
  %1560 = and i1 %1559, %1558
  %1561 = select i1 %1560, float %1535, float %46
  %1562 = select i1 %1560, float %1536, float %47
  %1563 = select i1 %1560, float %1537, float %48
  %1564 = select i1 %1560, float %1538, float %49
  %1565 = select i1 %1560, float %1539, float %18
  %1566 = select i1 %1560, float %1540, float %19
  %1567 = select i1 %1560, float %1394, float %20
  br label %1568

; <label>:1568                                    ; preds = %1534, %1529, %1391, %1267
  %1569 = phi i1 [ false, %1529 ], [ %1560, %1534 ], [ false, %1391 ], [ false, %1267 ]
  %1570 = phi float [ %46, %1529 ], [ %1561, %1534 ], [ %46, %1391 ], [ %46, %1267 ]
  %1571 = phi float [ %47, %1529 ], [ %1562, %1534 ], [ %47, %1391 ], [ %47, %1267 ]
  %1572 = phi float [ %48, %1529 ], [ %1563, %1534 ], [ %48, %1391 ], [ %48, %1267 ]
  %1573 = phi float [ %49, %1529 ], [ %1564, %1534 ], [ %49, %1391 ], [ %49, %1267 ]
  %1574 = phi float [ %18, %1529 ], [ %1565, %1534 ], [ %18, %1391 ], [ %18, %1267 ]
  %1575 = phi float [ %19, %1529 ], [ %1566, %1534 ], [ %19, %1391 ], [ %19, %1267 ]
  %1576 = phi float [ %20, %1529 ], [ %1567, %1534 ], [ %20, %1391 ], [ %20, %1267 ]
  %1577 = select i1 %1569, float %1570, float %46
  %1578 = select i1 %1569, float %1571, float %47
  %1579 = select i1 %1569, float %1572, float %48
  %1580 = select i1 %1569, float %1573, float %49
  %1581 = select i1 %1569, float %1574, float %18
  %1582 = select i1 %1569, float %1575, float %19
  %1583 = select i1 %1569, float %1576, float %20
  br label %1584

; <label>:1584                                    ; preds = %1568, %1132
  %1585 = phi float [ %46, %1132 ], [ %1577, %1568 ]
  %1586 = phi float [ %47, %1132 ], [ %1578, %1568 ]
  %1587 = phi float [ %48, %1132 ], [ %1579, %1568 ]
  %1588 = phi float [ %49, %1132 ], [ %1580, %1568 ]
  %1589 = phi float [ %18, %1132 ], [ %1581, %1568 ]
  %1590 = phi float [ %19, %1132 ], [ %1582, %1568 ]
  %1591 = phi float [ %20, %1132 ], [ %1583, %1568 ]
  %1592 = select i1 %1134, float %1585, float %54
  %1593 = select i1 %1134, float %1586, float %55
  %1594 = select i1 %1134, float %1587, float %56
  %1595 = select i1 %1134, float %1588, float %57
  %1596 = select i1 %1134, float %1589, float %955
  %1597 = select i1 %1134, float %1590, float %958
  br i1 %1155, label %1611, label %1598

; <label>:1598                                    ; preds = %1584
  %1599 = fadd fast float %54, 0x3FA47AE140000000
  %1600 = fadd fast float %55, 0x3FA47AE140000000
  %1601 = fadd fast float %56, 0x3FA47AE140000000
  %1602 = fadd fast float %54, 0xBFA47AE140000000
  %1603 = fadd fast float %55, 0xBFA47AE140000000
  %1604 = fadd fast float %56, 0xBFA47AE140000000
  %1605 = call float @dx.op.binary.f32(i32 35, float %1592, float %1602)  ; FMax(a,b)
  %1606 = call float @dx.op.binary.f32(i32 35, float %1593, float %1603)  ; FMax(a,b)
  %1607 = call float @dx.op.binary.f32(i32 35, float %1594, float %1604)  ; FMax(a,b)
  %1608 = call float @dx.op.binary.f32(i32 36, float %1605, float %1599)  ; FMin(a,b)
  %1609 = call float @dx.op.binary.f32(i32 36, float %1606, float %1600)  ; FMin(a,b)
  %1610 = call float @dx.op.binary.f32(i32 36, float %1607, float %1601)  ; FMin(a,b)
  br label %1611

; <label>:1611                                    ; preds = %1598, %1584
  %1612 = phi float [ %1592, %1584 ], [ %1608, %1598 ]
  %1613 = phi float [ %1593, %1584 ], [ %1609, %1598 ]
  %1614 = phi float [ %1594, %1584 ], [ %1610, %1598 ]
  %1615 = fcmp fast ogt float %28, 5.000000e-01
  %1616 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %1137)  ; FMin(a,b)
  %1617 = select i1 %1615, float %1616, float %1137
  %1618 = fadd fast float %1591, 1.000000e+00
  %1619 = select i1 %1134, float %1618, float 1.000000e+00
  %1620 = call float @dx.op.binary.f32(i32 36, float %1619, float %1617)  ; FMin(a,b)
  %1621 = select i1 %1134, float %1620, float 1.000000e+00
  %1622 = fdiv fast float 1.000000e+00, %1621
  %1623 = call float @dx.op.binary.f32(i32 35, float %40, float %1622)  ; FMax(a,b)
  %1624 = select i1 %1134, float %1623, float 1.000000e+00
  %1625 = fsub fast float %57, %1595
  %1626 = call float @dx.op.unary.f32(i32 6, float %1625)  ; FAbs(value)
  %1627 = fmul fast float %1626, 2.500000e-01
  %1628 = select i1 %1134, float %1627, float 1.000000e+00
  %1629 = call float @dx.op.binary.f32(i32 35, float %1624, float %1628)  ; FMax(a,b)
  %1630 = fsub fast float %955, %1596
  %1631 = fsub fast float %958, %1597
  %1632 = fmul fast float %1629, %1630
  %1633 = fmul fast float %1629, %1631
  %1634 = fadd fast float %1632, %1596
  %1635 = fadd fast float %1633, %1597
  %1636 = fsub fast float %54, %1612
  %1637 = fsub fast float %55, %1613
  %1638 = fsub fast float %56, %1614
  %1639 = fmul fast float %1629, %1636
  %1640 = fmul fast float %1629, %1637
  %1641 = fmul fast float %1629, %1638
  %1642 = fmul fast float %1629, %1625
  %1643 = fadd fast float %1639, %1612
  %1644 = fadd fast float %1640, %1613
  %1645 = fadd fast float %1641, %1614
  %1646 = fadd fast float %1642, %1595
  %1647 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1643)  ; IsFinite(value)
  %1648 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1644)  ; IsFinite(value)
  %1649 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1645)  ; IsFinite(value)
  %1650 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1646)  ; IsFinite(value)
  %1651 = and i1 %1647, %1648
  %1652 = and i1 %1651, %1649
  %1653 = and i1 %1652, %1650
  %1654 = fcmp fast ogt float %1646, 0.000000e+00
  %1655 = and i1 %1654, %1653
  %1656 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1634)  ; IsFinite(value)
  %1657 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1635)  ; IsFinite(value)
  %1658 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1621)  ; IsFinite(value)
  %1659 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %1660 = and i1 %1656, %1657
  %1661 = and i1 %1660, %1658
  %1662 = and i1 %1661, %1659
  %1663 = and i1 %1655, %1662
  %1664 = fcmp fast ogt float %1621, 0.000000e+00
  %1665 = and i1 %1664, %1663
  %1666 = select i1 %1665, float %1643, float 0.000000e+00
  %1667 = select i1 %1665, float %1644, float 0.000000e+00
  %1668 = select i1 %1665, float %1645, float 0.000000e+00
  %1669 = select i1 %1665, float %1646, float 0.000000e+00
  %1670 = select i1 %1665, float %1634, float 0.000000e+00
  %1671 = select i1 %1665, float %1635, float 0.000000e+00
  %1672 = select i1 %1665, float %1621, float 0.000000e+00
  br label %1673

; <label>:1673                                    ; preds = %1611, %1130, %1120
  %1674 = phi float [ %1121, %1130 ], [ %1121, %1120 ], [ %1666, %1611 ]
  %1675 = phi float [ %1122, %1130 ], [ %1122, %1120 ], [ %1667, %1611 ]
  %1676 = phi float [ %1123, %1130 ], [ %1123, %1120 ], [ %1668, %1611 ]
  %1677 = phi float [ %1124, %1130 ], [ %1124, %1120 ], [ %1669, %1611 ]
  %1678 = phi float [ %1125, %1130 ], [ %1125, %1120 ], [ %1670, %1611 ]
  %1679 = phi float [ %1126, %1130 ], [ %1126, %1120 ], [ %1671, %1611 ]
  %1680 = phi float [ %1131, %1130 ], [ %1127, %1120 ], [ %1672, %1611 ]
  %1681 = phi float [ %1128, %1130 ], [ %1128, %1120 ], [ 0.000000e+00, %1611 ]
  %1682 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1674)  ; LegacyF32ToF16(value)
  %1683 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1675)  ; LegacyF32ToF16(value)
  %1684 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1676)  ; LegacyF32ToF16(value)
  %1685 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1677)  ; LegacyF32ToF16(value)
  %1686 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1682)  ; LegacyF16ToF32(value)
  %1687 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1683)  ; LegacyF16ToF32(value)
  %1688 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1684)  ; LegacyF16ToF32(value)
  %1689 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1685)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %1674, float %1675, float %1676, float %1677, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %1678, float %1679, float %1680, float %1681, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %1686, float %1687, float %1688, float %1689, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %1678, float %1679, float %1680, float %1681, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %1691

; <label>:1690                                    ; preds = %918
  br label %1691

; <label>:1691                                    ; preds = %1690, %1673, %0
  ret void
}

; Function Attrs: nounwind readnone
declare i32 @dx.op.threadId.i32(i32, i32) #0

; Function Attrs: nounwind readnone
declare float @dx.op.legacyF16ToF32(i32, i32) #0

; Function Attrs: nounwind readnone
declare i32 @dx.op.legacyF32ToF16(i32, float) #0

; Function Attrs: nounwind readnone
declare i1 @dx.op.isSpecialFloat.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.binary.f32(i32, float, float) #0

; Function Attrs: nounwind readnone
declare i32 @dx.op.binary.i32(i32, i32, i32) #0

; Function Attrs: nounwind readnone
declare float @dx.op.dot3.f32(i32, float, float, float, float, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #1

; Function Attrs: nounwind readnone
declare float @dx.op.tertiary.f32(i32, float, float, float) #0

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
!dx.entryPoints = !{!13}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !8, !11, null}
!5 = !{!6}
!6 = !{i32 0, %"class.StructuredBuffer<Input>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 176}
!8 = !{!9}
!9 = !{i32 0, %"class.RWStructuredBuffer<Output>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !10}
!10 = !{i32 1, i32 64}
!11 = !{!12}
!12 = !{i32 0, %Counts* undef, !"", i32 0, i32 0, i32 1, i32 4, null}
!13 = !{void ()* @CSStationaryHistory, !"CSStationaryHistory", null, !4, !14}
!14 = !{i32 0, i64 16, i32 4, !15}
!15 = !{i32 64, i32 1, i32 1}
!16 = distinct !{!16, !17}
!17 = !{!"llvm.loop.unroll.disable"}
