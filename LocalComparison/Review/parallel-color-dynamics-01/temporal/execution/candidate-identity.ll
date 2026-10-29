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
; shader hash: b2f6cbf0ab10cdf0573c4614eeeea4d4
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
; EntryFunctionName: CSTemporalReactionTest
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
;   struct struct.TemporalReactionInput
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
;   struct struct.TemporalReactionOutput
;   {
;
;       float4 eventHistory;                          ; Offset:    0
;       float4 eventMoments;                          ; Offset:   16
;       float4 recoveryHistory;                       ; Offset:   32
;       float4 recoveryMoments;                       ; Offset:   48
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
; TestCounts                        cbuffer      NA          NA     CB0            cb0     1
; _Inputs                           texture  struct         r/o      T0             t0     1
; _Outputs                              UAV  struct         r/w      U0             u0     1
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.StructuredBuffer<TemporalReactionInput>" = type { %struct.TemporalReactionInput }
%struct.TemporalReactionInput = type { <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%"class.RWStructuredBuffer<TemporalReactionOutput>" = type { %struct.TemporalReactionOutput }
%struct.TemporalReactionOutput = type { <4 x float>, <4 x float>, <4 x float>, <4 x float> }
%TestCounts = type { i32 }

@_HLGI_IdentityObjects.2 = internal unnamed_addr global [1 x i32] zeroinitializer, align 4
@_HLGI_IdentityObjects.1.0 = internal unnamed_addr global [1 x i32] zeroinitializer, align 4
@_HLGI_IdentityObjects.1.1 = internal unnamed_addr global [1 x i32] zeroinitializer, align 4
@_HLGI_IdentityObjects.0.v.v.1dim = internal global [16 x float] zeroinitializer, align 16

define void @CSTemporalReactionTest() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %5 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %6 = extractvalue %dx.types.CBufRet.i32 %5, 0
  %7 = icmp ult i32 %4, %6
  br i1 %7, label %8, label %365

; <label>:8                                       ; preds = %0
  %9 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 0)  ; BufferLoad(srv,index,wot)
  %10 = extractvalue %dx.types.ResRet.f32 %9, 0
  %11 = extractvalue %dx.types.ResRet.f32 %9, 1
  %12 = extractvalue %dx.types.ResRet.f32 %9, 2
  %13 = extractvalue %dx.types.ResRet.f32 %9, 3
  %14 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 16)  ; BufferLoad(srv,index,wot)
  %15 = extractvalue %dx.types.ResRet.f32 %14, 0
  %16 = extractvalue %dx.types.ResRet.f32 %14, 1
  %17 = extractvalue %dx.types.ResRet.f32 %14, 2
  %18 = extractvalue %dx.types.ResRet.f32 %14, 3
  %19 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 32)  ; BufferLoad(srv,index,wot)
  %20 = extractvalue %dx.types.ResRet.f32 %19, 0
  %21 = extractvalue %dx.types.ResRet.f32 %19, 1
  %22 = extractvalue %dx.types.ResRet.f32 %19, 2
  %23 = extractvalue %dx.types.ResRet.f32 %19, 3
  %24 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 48)  ; BufferLoad(srv,index,wot)
  %25 = extractvalue %dx.types.ResRet.f32 %24, 0
  %26 = extractvalue %dx.types.ResRet.f32 %24, 1
  %27 = extractvalue %dx.types.ResRet.f32 %24, 2
  %28 = extractvalue %dx.types.ResRet.f32 %24, 3
  %29 = call %dx.types.ResRet.f32 @dx.op.bufferLoad.f32(i32 68, %dx.types.Handle %2, i32 %4, i32 64)  ; BufferLoad(srv,index,wot)
  %30 = extractvalue %dx.types.ResRet.f32 %29, 0
  %31 = extractvalue %dx.types.ResRet.f32 %29, 1
  %32 = extractvalue %dx.types.ResRet.f32 %29, 2
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
  %33 = call i32 @dx.op.legacyF32ToF16(i32 130, float %10)  ; LegacyF32ToF16(value)
  %34 = call i32 @dx.op.legacyF32ToF16(i32 130, float %11)  ; LegacyF32ToF16(value)
  %35 = call i32 @dx.op.legacyF32ToF16(i32 130, float %12)  ; LegacyF32ToF16(value)
  %36 = call i32 @dx.op.legacyF32ToF16(i32 130, float %13)  ; LegacyF32ToF16(value)
  %37 = call float @dx.op.legacyF16ToF32(i32 131, i32 %33)  ; LegacyF16ToF32(value)
  %38 = call float @dx.op.legacyF16ToF32(i32 131, i32 %34)  ; LegacyF16ToF32(value)
  %39 = call float @dx.op.legacyF16ToF32(i32 131, i32 %35)  ; LegacyF16ToF32(value)
  %40 = call float @dx.op.legacyF16ToF32(i32 131, i32 %36)  ; LegacyF16ToF32(value)
  %41 = call i32 @dx.op.legacyF32ToF16(i32 130, float %20)  ; LegacyF32ToF16(value)
  %42 = call i32 @dx.op.legacyF32ToF16(i32 130, float %21)  ; LegacyF32ToF16(value)
  %43 = call i32 @dx.op.legacyF32ToF16(i32 130, float %22)  ; LegacyF32ToF16(value)
  %44 = call i32 @dx.op.legacyF32ToF16(i32 130, float %23)  ; LegacyF32ToF16(value)
  %45 = call float @dx.op.legacyF16ToF32(i32 131, i32 %41)  ; LegacyF16ToF32(value)
  %46 = call float @dx.op.legacyF16ToF32(i32 131, i32 %42)  ; LegacyF16ToF32(value)
  %47 = call float @dx.op.legacyF16ToF32(i32 131, i32 %43)  ; LegacyF16ToF32(value)
  %48 = call float @dx.op.legacyF16ToF32(i32 131, i32 %44)  ; LegacyF16ToF32(value)
  %49 = fptosi float %32 to i32
  %50 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %45)  ; IsFinite(value)
  %51 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %46)  ; IsFinite(value)
  %52 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %47)  ; IsFinite(value)
  %53 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %48)  ; IsFinite(value)
  %54 = and i1 %50, %51
  %55 = and i1 %54, %52
  %56 = and i1 %55, %53
  %57 = fcmp fast ogt float %48, 0.000000e+00
  %58 = and i1 %57, %56
  %59 = call float @dx.op.dot3.f32(i32 55, float %45, float %46, float %47, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %60 = select i1 %58, float %59, float 0.000000e+00
  %61 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %60)  ; IsFinite(value)
  %62 = and i1 %58, %61
  %63 = fmul fast float %60, %60
  %64 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %63)  ; IsFinite(value)
  %65 = and i1 %62, %64
  %66 = fmul fast float %45, %45
  %67 = fmul fast float %46, %46
  %68 = fmul fast float %47, %47
  %69 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %66)  ; IsFinite(value)
  %70 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %67)  ; IsFinite(value)
  %71 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %68)  ; IsFinite(value)
  %72 = and i1 %69, %70
  %73 = and i1 %72, %71
  %74 = and i1 %65, %73
  %75 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 5.000000e-01)  ; IsFinite(value)
  %76 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %77 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %78 = and i1 %75, %77
  %79 = and i1 %76, %78
  %80 = icmp ne i32 %49, 0
  %81 = and i1 %80, %79
  %82 = fcmp fast olt float %31, 5.000000e-01
  %83 = and i1 %82, %81
  %84 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %37)  ; IsFinite(value)
  %85 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %38)  ; IsFinite(value)
  %86 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %39)  ; IsFinite(value)
  %87 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %40)  ; IsFinite(value)
  %88 = and i1 %84, %85
  %89 = and i1 %88, %86
  %90 = and i1 %89, %87
  %91 = fcmp fast ogt float %40, 0.000000e+00
  %92 = and i1 %91, %90
  %93 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %15)  ; IsFinite(value)
  %94 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %16)  ; IsFinite(value)
  %95 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %17)  ; IsFinite(value)
  %96 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %97 = and i1 %93, %94
  %98 = and i1 %97, %95
  %99 = and i1 %98, %96
  %100 = and i1 %92, %99
  %101 = fcmp fast ogt float %17, 0.000000e+00
  %102 = and i1 %101, %100
  %103 = and i1 %83, %102
  br i1 %74, label %116, label %104

; <label>:104                                     ; preds = %8
  %105 = select i1 %103, float %37, float 0.000000e+00
  %106 = select i1 %103, float %38, float 0.000000e+00
  %107 = select i1 %103, float %39, float 0.000000e+00
  %108 = select i1 %103, float %40, float 0.000000e+00
  %109 = select i1 %103, float %15, float 0.000000e+00
  %110 = select i1 %103, float %16, float 0.000000e+00
  %111 = select i1 %103, float %17, float 0.000000e+00
  %112 = select i1 %103, float %18, float 0.000000e+00
  %113 = fcmp fast ogt float %30, 5.000000e-01
  br i1 %113, label %114, label %192

; <label>:114                                     ; preds = %104
  %115 = call float @dx.op.binary.f32(i32 36, float %111, float 2.000000e+00)  ; FMin(a,b)
  br label %192

; <label>:116                                     ; preds = %8
  %117 = select i1 %103, float %40, float %48
  %118 = select i1 %103, float %15, float %60
  %119 = select i1 %103, float %16, float %63
  %120 = fcmp fast ogt float %30, 5.000000e-01
  %121 = select i1 %103, float %39, float %47
  %122 = select i1 %103, float %38, float %46
  %123 = select i1 %103, float %37, float %45
  %124 = fadd fast float %45, 0x3FA47AE140000000
  %125 = fadd fast float %46, 0x3FA47AE140000000
  %126 = fadd fast float %47, 0x3FA47AE140000000
  %127 = fadd fast float %45, 0xBFA47AE140000000
  %128 = fadd fast float %46, 0xBFA47AE140000000
  %129 = fadd fast float %47, 0xBFA47AE140000000
  %130 = call float @dx.op.binary.f32(i32 35, float %123, float %127)  ; FMax(a,b)
  %131 = call float @dx.op.binary.f32(i32 35, float %122, float %128)  ; FMax(a,b)
  %132 = call float @dx.op.binary.f32(i32 35, float %121, float %129)  ; FMax(a,b)
  %133 = call float @dx.op.binary.f32(i32 36, float %130, float %124)  ; FMin(a,b)
  %134 = call float @dx.op.binary.f32(i32 36, float %131, float %125)  ; FMin(a,b)
  %135 = call float @dx.op.binary.f32(i32 36, float %132, float %126)  ; FMin(a,b)
  %136 = select i1 %120, float 2.000000e+00, float 3.200000e+01
  %137 = fadd fast float %17, 1.000000e+00
  %138 = select i1 %103, float %137, float 1.000000e+00
  %139 = call float @dx.op.binary.f32(i32 36, float %138, float %136)  ; FMin(a,b)
  %140 = select i1 %103, float %139, float 1.000000e+00
  %141 = fdiv fast float 1.000000e+00, %140
  %142 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %141)  ; FMax(a,b)
  %143 = select i1 %103, float %142, float 1.000000e+00
  %144 = fsub fast float %48, %117
  %145 = call float @dx.op.unary.f32(i32 6, float %144)  ; FAbs(value)
  %146 = fmul fast float %145, 2.500000e-01
  %147 = select i1 %103, float %146, float 1.000000e+00
  %148 = call float @dx.op.binary.f32(i32 35, float %143, float %147)  ; FMax(a,b)
  %149 = fsub fast float %60, %118
  %150 = fsub fast float %63, %119
  %151 = fmul fast float %148, %149
  %152 = fmul fast float %148, %150
  %153 = fadd fast float %151, %118
  %154 = fadd fast float %152, %119
  %155 = fsub fast float %45, %133
  %156 = fsub fast float %46, %134
  %157 = fsub fast float %47, %135
  %158 = fmul fast float %148, %155
  %159 = fmul fast float %148, %156
  %160 = fmul fast float %148, %157
  %161 = fmul fast float %148, %144
  %162 = fadd fast float %158, %133
  %163 = fadd fast float %159, %134
  %164 = fadd fast float %160, %135
  %165 = fadd fast float %161, %117
  %166 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %162)  ; IsFinite(value)
  %167 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %163)  ; IsFinite(value)
  %168 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %164)  ; IsFinite(value)
  %169 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %165)  ; IsFinite(value)
  %170 = and i1 %166, %167
  %171 = and i1 %170, %168
  %172 = and i1 %171, %169
  %173 = fcmp fast ogt float %165, 0.000000e+00
  %174 = and i1 %173, %172
  %175 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %153)  ; IsFinite(value)
  %176 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %154)  ; IsFinite(value)
  %177 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %140)  ; IsFinite(value)
  %178 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %179 = and i1 %175, %176
  %180 = and i1 %179, %177
  %181 = and i1 %180, %178
  %182 = and i1 %174, %181
  %183 = fcmp fast ogt float %140, 0.000000e+00
  %184 = and i1 %183, %182
  %185 = select i1 %184, float %162, float 0.000000e+00
  %186 = select i1 %184, float %163, float 0.000000e+00
  %187 = select i1 %184, float %164, float 0.000000e+00
  %188 = select i1 %184, float %165, float 0.000000e+00
  %189 = select i1 %184, float %153, float 0.000000e+00
  %190 = select i1 %184, float %154, float 0.000000e+00
  %191 = select i1 %184, float %140, float 0.000000e+00
  br label %192

; <label>:192                                     ; preds = %116, %114, %104
  %193 = phi float [ %105, %114 ], [ %105, %104 ], [ %185, %116 ]
  %194 = phi float [ %106, %114 ], [ %106, %104 ], [ %186, %116 ]
  %195 = phi float [ %107, %114 ], [ %107, %104 ], [ %187, %116 ]
  %196 = phi float [ %108, %114 ], [ %108, %104 ], [ %188, %116 ]
  %197 = phi float [ %109, %114 ], [ %109, %104 ], [ %189, %116 ]
  %198 = phi float [ %110, %114 ], [ %110, %104 ], [ %190, %116 ]
  %199 = phi float [ %115, %114 ], [ %111, %104 ], [ %191, %116 ]
  %200 = phi float [ %112, %114 ], [ %112, %104 ], [ 0.000000e+00, %116 ]
  %201 = call i32 @dx.op.legacyF32ToF16(i32 130, float %193)  ; LegacyF32ToF16(value)
  %202 = call i32 @dx.op.legacyF32ToF16(i32 130, float %194)  ; LegacyF32ToF16(value)
  %203 = call i32 @dx.op.legacyF32ToF16(i32 130, float %195)  ; LegacyF32ToF16(value)
  %204 = call i32 @dx.op.legacyF32ToF16(i32 130, float %196)  ; LegacyF32ToF16(value)
  %205 = call float @dx.op.legacyF16ToF32(i32 131, i32 %201)  ; LegacyF16ToF32(value)
  %206 = call float @dx.op.legacyF16ToF32(i32 131, i32 %202)  ; LegacyF16ToF32(value)
  %207 = call float @dx.op.legacyF16ToF32(i32 131, i32 %203)  ; LegacyF16ToF32(value)
  %208 = call float @dx.op.legacyF16ToF32(i32 131, i32 %204)  ; LegacyF16ToF32(value)
  %209 = call i32 @dx.op.legacyF32ToF16(i32 130, float %25)  ; LegacyF32ToF16(value)
  %210 = call i32 @dx.op.legacyF32ToF16(i32 130, float %26)  ; LegacyF32ToF16(value)
  %211 = call i32 @dx.op.legacyF32ToF16(i32 130, float %27)  ; LegacyF32ToF16(value)
  %212 = call i32 @dx.op.legacyF32ToF16(i32 130, float %28)  ; LegacyF32ToF16(value)
  %213 = call float @dx.op.legacyF16ToF32(i32 131, i32 %209)  ; LegacyF16ToF32(value)
  %214 = call float @dx.op.legacyF16ToF32(i32 131, i32 %210)  ; LegacyF16ToF32(value)
  %215 = call float @dx.op.legacyF16ToF32(i32 131, i32 %211)  ; LegacyF16ToF32(value)
  %216 = call float @dx.op.legacyF16ToF32(i32 131, i32 %212)  ; LegacyF16ToF32(value)
  %217 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %213)  ; IsFinite(value)
  %218 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %214)  ; IsFinite(value)
  %219 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %215)  ; IsFinite(value)
  %220 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %216)  ; IsFinite(value)
  %221 = and i1 %217, %218
  %222 = and i1 %221, %219
  %223 = and i1 %222, %220
  %224 = fcmp fast ogt float %216, 0.000000e+00
  %225 = and i1 %224, %223
  %226 = call float @dx.op.dot3.f32(i32 55, float %213, float %214, float %215, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %227 = select i1 %225, float %226, float 0.000000e+00
  %228 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %227)  ; IsFinite(value)
  %229 = and i1 %225, %228
  %230 = fmul fast float %227, %227
  %231 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %230)  ; IsFinite(value)
  %232 = and i1 %229, %231
  %233 = fmul fast float %213, %213
  %234 = fmul fast float %214, %214
  %235 = fmul fast float %215, %215
  %236 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %233)  ; IsFinite(value)
  %237 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %234)  ; IsFinite(value)
  %238 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %235)  ; IsFinite(value)
  %239 = and i1 %236, %237
  %240 = and i1 %239, %238
  %241 = and i1 %232, %240
  %242 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %243 = and i1 %75, %242
  %244 = and i1 %76, %243
  %245 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %205)  ; IsFinite(value)
  %246 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %206)  ; IsFinite(value)
  %247 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %207)  ; IsFinite(value)
  %248 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %208)  ; IsFinite(value)
  %249 = and i1 %245, %246
  %250 = and i1 %249, %247
  %251 = and i1 %250, %248
  %252 = fcmp fast ogt float %208, 0.000000e+00
  %253 = and i1 %252, %251
  %254 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %197)  ; IsFinite(value)
  %255 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %198)  ; IsFinite(value)
  %256 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %199)  ; IsFinite(value)
  %257 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %200)  ; IsFinite(value)
  %258 = and i1 %254, %255
  %259 = and i1 %258, %256
  %260 = and i1 %259, %257
  %261 = and i1 %253, %260
  %262 = fcmp fast ogt float %199, 0.000000e+00
  %263 = and i1 %262, %261
  %264 = and i1 %244, %263
  br i1 %241, label %274, label %265

; <label>:265                                     ; preds = %192
  %266 = select i1 %264, float %205, float 0.000000e+00
  %267 = select i1 %264, float %206, float 0.000000e+00
  %268 = select i1 %264, float %207, float 0.000000e+00
  %269 = select i1 %264, float %208, float 0.000000e+00
  %270 = select i1 %264, float %197, float 0.000000e+00
  %271 = select i1 %264, float %198, float 0.000000e+00
  %272 = select i1 %264, float %199, float 0.000000e+00
  %273 = select i1 %264, float %200, float 0.000000e+00
  br label %348

; <label>:274                                     ; preds = %192
  %275 = select i1 %264, float %208, float %216
  %276 = select i1 %264, float %197, float %227
  %277 = select i1 %264, float %198, float %230
  %278 = select i1 %264, float %207, float %215
  %279 = select i1 %264, float %206, float %214
  %280 = select i1 %264, float %205, float %213
  %281 = fadd fast float %213, 0x3FA47AE140000000
  %282 = fadd fast float %214, 0x3FA47AE140000000
  %283 = fadd fast float %215, 0x3FA47AE140000000
  %284 = fadd fast float %213, 0xBFA47AE140000000
  %285 = fadd fast float %214, 0xBFA47AE140000000
  %286 = fadd fast float %215, 0xBFA47AE140000000
  %287 = call float @dx.op.binary.f32(i32 35, float %280, float %284)  ; FMax(a,b)
  %288 = call float @dx.op.binary.f32(i32 35, float %279, float %285)  ; FMax(a,b)
  %289 = call float @dx.op.binary.f32(i32 35, float %278, float %286)  ; FMax(a,b)
  %290 = call float @dx.op.binary.f32(i32 36, float %287, float %281)  ; FMin(a,b)
  %291 = call float @dx.op.binary.f32(i32 36, float %288, float %282)  ; FMin(a,b)
  %292 = call float @dx.op.binary.f32(i32 36, float %289, float %283)  ; FMin(a,b)
  %293 = fadd fast float %199, 1.000000e+00
  %294 = select i1 %264, float %293, float 1.000000e+00
  %295 = call float @dx.op.binary.f32(i32 36, float %294, float 3.200000e+01)  ; FMin(a,b)
  %296 = select i1 %264, float %295, float 1.000000e+00
  %297 = fdiv fast float 1.000000e+00, %296
  %298 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %297)  ; FMax(a,b)
  %299 = select i1 %264, float %298, float 1.000000e+00
  %300 = fsub fast float %216, %275
  %301 = call float @dx.op.unary.f32(i32 6, float %300)  ; FAbs(value)
  %302 = fmul fast float %301, 2.500000e-01
  %303 = select i1 %264, float %302, float 1.000000e+00
  %304 = call float @dx.op.binary.f32(i32 35, float %299, float %303)  ; FMax(a,b)
  %305 = fsub fast float %227, %276
  %306 = fsub fast float %230, %277
  %307 = fmul fast float %304, %305
  %308 = fmul fast float %304, %306
  %309 = fadd fast float %307, %276
  %310 = fadd fast float %308, %277
  %311 = fsub fast float %213, %290
  %312 = fsub fast float %214, %291
  %313 = fsub fast float %215, %292
  %314 = fmul fast float %304, %311
  %315 = fmul fast float %304, %312
  %316 = fmul fast float %304, %313
  %317 = fmul fast float %304, %300
  %318 = fadd fast float %314, %290
  %319 = fadd fast float %315, %291
  %320 = fadd fast float %316, %292
  %321 = fadd fast float %317, %275
  %322 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %318)  ; IsFinite(value)
  %323 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %319)  ; IsFinite(value)
  %324 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %320)  ; IsFinite(value)
  %325 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %321)  ; IsFinite(value)
  %326 = and i1 %322, %323
  %327 = and i1 %326, %324
  %328 = and i1 %327, %325
  %329 = fcmp fast ogt float %321, 0.000000e+00
  %330 = and i1 %329, %328
  %331 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %309)  ; IsFinite(value)
  %332 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %310)  ; IsFinite(value)
  %333 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %296)  ; IsFinite(value)
  %334 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %335 = and i1 %331, %332
  %336 = and i1 %335, %333
  %337 = and i1 %336, %334
  %338 = and i1 %330, %337
  %339 = fcmp fast ogt float %296, 0.000000e+00
  %340 = and i1 %339, %338
  %341 = select i1 %340, float %318, float 0.000000e+00
  %342 = select i1 %340, float %319, float 0.000000e+00
  %343 = select i1 %340, float %320, float 0.000000e+00
  %344 = select i1 %340, float %321, float 0.000000e+00
  %345 = select i1 %340, float %309, float 0.000000e+00
  %346 = select i1 %340, float %310, float 0.000000e+00
  %347 = select i1 %340, float %296, float 0.000000e+00
  br label %348

; <label>:348                                     ; preds = %274, %265
  %349 = phi float [ %266, %265 ], [ %341, %274 ]
  %350 = phi float [ %267, %265 ], [ %342, %274 ]
  %351 = phi float [ %268, %265 ], [ %343, %274 ]
  %352 = phi float [ %269, %265 ], [ %344, %274 ]
  %353 = phi float [ %270, %265 ], [ %345, %274 ]
  %354 = phi float [ %271, %265 ], [ %346, %274 ]
  %355 = phi float [ %272, %265 ], [ %347, %274 ]
  %356 = phi float [ %273, %265 ], [ 0.000000e+00, %274 ]
  %357 = call i32 @dx.op.legacyF32ToF16(i32 130, float %349)  ; LegacyF32ToF16(value)
  %358 = call i32 @dx.op.legacyF32ToF16(i32 130, float %350)  ; LegacyF32ToF16(value)
  %359 = call i32 @dx.op.legacyF32ToF16(i32 130, float %351)  ; LegacyF32ToF16(value)
  %360 = call i32 @dx.op.legacyF32ToF16(i32 130, float %352)  ; LegacyF32ToF16(value)
  %361 = call float @dx.op.legacyF16ToF32(i32 131, i32 %357)  ; LegacyF16ToF32(value)
  %362 = call float @dx.op.legacyF16ToF32(i32 131, i32 %358)  ; LegacyF16ToF32(value)
  %363 = call float @dx.op.legacyF16ToF32(i32 131, i32 %359)  ; LegacyF16ToF32(value)
  %364 = call float @dx.op.legacyF16ToF32(i32 131, i32 %360)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %205, float %206, float %207, float %208, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %197, float %198, float %199, float %200, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %361, float %362, float %363, float %364, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %353, float %354, float %355, float %356, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %365

; <label>:365                                     ; preds = %348, %0
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
declare float @dx.op.dot3.f32(i32, float, float, float, float, float, float) #0

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
!dx.entryPoints = !{!13}

!0 = !{!"dxcoob 1.8.2502.11 (239921522)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 8}
!3 = !{!"cs", i32 6, i32 0}
!4 = !{!5, !8, !11, null}
!5 = !{!6}
!6 = !{i32 0, %"class.StructuredBuffer<TemporalReactionInput>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i32 0, !7}
!7 = !{i32 1, i32 176}
!8 = !{!9}
!9 = !{i32 0, %"class.RWStructuredBuffer<TemporalReactionOutput>"* undef, !"", i32 0, i32 0, i32 1, i32 12, i1 false, i1 false, i1 false, !10}
!10 = !{i32 1, i32 64}
!11 = !{!12}
!12 = !{i32 0, %TestCounts* undef, !"", i32 0, i32 0, i32 1, i32 4, null}
!13 = !{void ()* @CSTemporalReactionTest, !"CSTemporalReactionTest", null, !4, !14}
!14 = !{i32 0, i64 16, i32 4, !15}
!15 = !{i32 64, i32 1, i32 1}
