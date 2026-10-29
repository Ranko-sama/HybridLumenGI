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
; shader hash: 5deb74c298ba9a7f26be0b7c16619e9f
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
  br i1 %7, label %8, label %362

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
  %30 = extractvalue %dx.types.ResRet.f32 %29, 1
  %31 = extractvalue %dx.types.ResRet.f32 %29, 2
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
  %32 = call i32 @dx.op.legacyF32ToF16(i32 130, float %10)  ; LegacyF32ToF16(value)
  %33 = call i32 @dx.op.legacyF32ToF16(i32 130, float %11)  ; LegacyF32ToF16(value)
  %34 = call i32 @dx.op.legacyF32ToF16(i32 130, float %12)  ; LegacyF32ToF16(value)
  %35 = call i32 @dx.op.legacyF32ToF16(i32 130, float %13)  ; LegacyF32ToF16(value)
  %36 = call float @dx.op.legacyF16ToF32(i32 131, i32 %32)  ; LegacyF16ToF32(value)
  %37 = call float @dx.op.legacyF16ToF32(i32 131, i32 %33)  ; LegacyF16ToF32(value)
  %38 = call float @dx.op.legacyF16ToF32(i32 131, i32 %34)  ; LegacyF16ToF32(value)
  %39 = call float @dx.op.legacyF16ToF32(i32 131, i32 %35)  ; LegacyF16ToF32(value)
  %40 = call i32 @dx.op.legacyF32ToF16(i32 130, float %20)  ; LegacyF32ToF16(value)
  %41 = call i32 @dx.op.legacyF32ToF16(i32 130, float %21)  ; LegacyF32ToF16(value)
  %42 = call i32 @dx.op.legacyF32ToF16(i32 130, float %22)  ; LegacyF32ToF16(value)
  %43 = call i32 @dx.op.legacyF32ToF16(i32 130, float %23)  ; LegacyF32ToF16(value)
  %44 = call float @dx.op.legacyF16ToF32(i32 131, i32 %40)  ; LegacyF16ToF32(value)
  %45 = call float @dx.op.legacyF16ToF32(i32 131, i32 %41)  ; LegacyF16ToF32(value)
  %46 = call float @dx.op.legacyF16ToF32(i32 131, i32 %42)  ; LegacyF16ToF32(value)
  %47 = call float @dx.op.legacyF16ToF32(i32 131, i32 %43)  ; LegacyF16ToF32(value)
  %48 = fptosi float %31 to i32
  %49 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %44)  ; IsFinite(value)
  %50 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %45)  ; IsFinite(value)
  %51 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %46)  ; IsFinite(value)
  %52 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %47)  ; IsFinite(value)
  %53 = and i1 %49, %50
  %54 = and i1 %53, %51
  %55 = and i1 %54, %52
  %56 = fcmp fast ogt float %47, 0.000000e+00
  %57 = and i1 %56, %55
  %58 = call float @dx.op.dot3.f32(i32 55, float %44, float %45, float %46, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %59 = select i1 %57, float %58, float 0.000000e+00
  %60 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %59)  ; IsFinite(value)
  %61 = and i1 %57, %60
  %62 = fmul fast float %59, %59
  %63 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %62)  ; IsFinite(value)
  %64 = and i1 %61, %63
  %65 = fmul fast float %44, %44
  %66 = fmul fast float %45, %45
  %67 = fmul fast float %46, %46
  %68 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %65)  ; IsFinite(value)
  %69 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %66)  ; IsFinite(value)
  %70 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %67)  ; IsFinite(value)
  %71 = and i1 %68, %69
  %72 = and i1 %71, %70
  %73 = and i1 %64, %72
  %74 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 5.000000e-01)  ; IsFinite(value)
  %75 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %76 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %77 = and i1 %74, %76
  %78 = and i1 %75, %77
  %79 = icmp ne i32 %48, 0
  %80 = and i1 %79, %78
  %81 = fcmp fast olt float %30, 5.000000e-01
  %82 = and i1 %81, %80
  %83 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %36)  ; IsFinite(value)
  %84 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %37)  ; IsFinite(value)
  %85 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %38)  ; IsFinite(value)
  %86 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %39)  ; IsFinite(value)
  %87 = and i1 %83, %84
  %88 = and i1 %87, %85
  %89 = and i1 %88, %86
  %90 = fcmp fast ogt float %39, 0.000000e+00
  %91 = and i1 %90, %89
  %92 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %15)  ; IsFinite(value)
  %93 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %16)  ; IsFinite(value)
  %94 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %17)  ; IsFinite(value)
  %95 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %96 = and i1 %92, %93
  %97 = and i1 %96, %94
  %98 = and i1 %97, %95
  %99 = and i1 %91, %98
  %100 = fcmp fast ogt float %17, 0.000000e+00
  %101 = and i1 %100, %99
  %102 = and i1 %82, %101
  br i1 %73, label %112, label %103

; <label>:103                                     ; preds = %8
  %104 = select i1 %102, float %36, float 0.000000e+00
  %105 = select i1 %102, float %37, float 0.000000e+00
  %106 = select i1 %102, float %38, float 0.000000e+00
  %107 = select i1 %102, float %39, float 0.000000e+00
  %108 = select i1 %102, float %15, float 0.000000e+00
  %109 = select i1 %102, float %16, float 0.000000e+00
  %110 = select i1 %102, float %17, float 0.000000e+00
  %111 = select i1 %102, float %18, float 0.000000e+00
  br label %189

; <label>:112                                     ; preds = %8
  %113 = extractvalue %dx.types.ResRet.f32 %29, 0
  %114 = select i1 %102, float %39, float %47
  %115 = select i1 %102, float %15, float %59
  %116 = select i1 %102, float %16, float %62
  %117 = select i1 %102, float %38, float %46
  %118 = select i1 %102, float %37, float %45
  %119 = select i1 %102, float %36, float %44
  %120 = fadd fast float %44, 0x3FA47AE140000000
  %121 = fadd fast float %45, 0x3FA47AE140000000
  %122 = fadd fast float %46, 0x3FA47AE140000000
  %123 = fadd fast float %44, 0xBFA47AE140000000
  %124 = fadd fast float %45, 0xBFA47AE140000000
  %125 = fadd fast float %46, 0xBFA47AE140000000
  %126 = call float @dx.op.binary.f32(i32 35, float %119, float %123)  ; FMax(a,b)
  %127 = call float @dx.op.binary.f32(i32 35, float %118, float %124)  ; FMax(a,b)
  %128 = call float @dx.op.binary.f32(i32 35, float %117, float %125)  ; FMax(a,b)
  %129 = call float @dx.op.binary.f32(i32 36, float %126, float %120)  ; FMin(a,b)
  %130 = call float @dx.op.binary.f32(i32 36, float %127, float %121)  ; FMin(a,b)
  %131 = call float @dx.op.binary.f32(i32 36, float %128, float %122)  ; FMin(a,b)
  %132 = fcmp fast ogt float %113, 5.000000e-01
  %133 = select i1 %132, float 2.000000e+00, float 3.200000e+01
  %134 = fadd fast float %17, 1.000000e+00
  %135 = select i1 %102, float %134, float 1.000000e+00
  %136 = call float @dx.op.binary.f32(i32 36, float %135, float %133)  ; FMin(a,b)
  %137 = select i1 %102, float %136, float 1.000000e+00
  %138 = fdiv fast float 1.000000e+00, %137
  %139 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %138)  ; FMax(a,b)
  %140 = select i1 %102, float %139, float 1.000000e+00
  %141 = fsub fast float %47, %114
  %142 = call float @dx.op.unary.f32(i32 6, float %141)  ; FAbs(value)
  %143 = fmul fast float %142, 2.500000e-01
  %144 = select i1 %102, float %143, float 1.000000e+00
  %145 = call float @dx.op.binary.f32(i32 35, float %140, float %144)  ; FMax(a,b)
  %146 = fsub fast float %59, %115
  %147 = fsub fast float %62, %116
  %148 = fmul fast float %145, %146
  %149 = fmul fast float %145, %147
  %150 = fadd fast float %148, %115
  %151 = fadd fast float %149, %116
  %152 = fsub fast float %44, %129
  %153 = fsub fast float %45, %130
  %154 = fsub fast float %46, %131
  %155 = fmul fast float %145, %152
  %156 = fmul fast float %145, %153
  %157 = fmul fast float %145, %154
  %158 = fmul fast float %145, %141
  %159 = fadd fast float %155, %129
  %160 = fadd fast float %156, %130
  %161 = fadd fast float %157, %131
  %162 = fadd fast float %158, %114
  %163 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %159)  ; IsFinite(value)
  %164 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %160)  ; IsFinite(value)
  %165 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %161)  ; IsFinite(value)
  %166 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %162)  ; IsFinite(value)
  %167 = and i1 %163, %164
  %168 = and i1 %167, %165
  %169 = and i1 %168, %166
  %170 = fcmp fast ogt float %162, 0.000000e+00
  %171 = and i1 %170, %169
  %172 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %150)  ; IsFinite(value)
  %173 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %151)  ; IsFinite(value)
  %174 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %137)  ; IsFinite(value)
  %175 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %176 = and i1 %172, %173
  %177 = and i1 %176, %174
  %178 = and i1 %177, %175
  %179 = and i1 %171, %178
  %180 = fcmp fast ogt float %137, 0.000000e+00
  %181 = and i1 %180, %179
  %182 = select i1 %181, float %159, float 0.000000e+00
  %183 = select i1 %181, float %160, float 0.000000e+00
  %184 = select i1 %181, float %161, float 0.000000e+00
  %185 = select i1 %181, float %162, float 0.000000e+00
  %186 = select i1 %181, float %150, float 0.000000e+00
  %187 = select i1 %181, float %151, float 0.000000e+00
  %188 = select i1 %181, float %137, float 0.000000e+00
  br label %189

; <label>:189                                     ; preds = %112, %103
  %190 = phi float [ %104, %103 ], [ %182, %112 ]
  %191 = phi float [ %105, %103 ], [ %183, %112 ]
  %192 = phi float [ %106, %103 ], [ %184, %112 ]
  %193 = phi float [ %107, %103 ], [ %185, %112 ]
  %194 = phi float [ %108, %103 ], [ %186, %112 ]
  %195 = phi float [ %109, %103 ], [ %187, %112 ]
  %196 = phi float [ %110, %103 ], [ %188, %112 ]
  %197 = phi float [ %111, %103 ], [ 0.000000e+00, %112 ]
  %198 = call i32 @dx.op.legacyF32ToF16(i32 130, float %190)  ; LegacyF32ToF16(value)
  %199 = call i32 @dx.op.legacyF32ToF16(i32 130, float %191)  ; LegacyF32ToF16(value)
  %200 = call i32 @dx.op.legacyF32ToF16(i32 130, float %192)  ; LegacyF32ToF16(value)
  %201 = call i32 @dx.op.legacyF32ToF16(i32 130, float %193)  ; LegacyF32ToF16(value)
  %202 = call float @dx.op.legacyF16ToF32(i32 131, i32 %198)  ; LegacyF16ToF32(value)
  %203 = call float @dx.op.legacyF16ToF32(i32 131, i32 %199)  ; LegacyF16ToF32(value)
  %204 = call float @dx.op.legacyF16ToF32(i32 131, i32 %200)  ; LegacyF16ToF32(value)
  %205 = call float @dx.op.legacyF16ToF32(i32 131, i32 %201)  ; LegacyF16ToF32(value)
  %206 = call i32 @dx.op.legacyF32ToF16(i32 130, float %25)  ; LegacyF32ToF16(value)
  %207 = call i32 @dx.op.legacyF32ToF16(i32 130, float %26)  ; LegacyF32ToF16(value)
  %208 = call i32 @dx.op.legacyF32ToF16(i32 130, float %27)  ; LegacyF32ToF16(value)
  %209 = call i32 @dx.op.legacyF32ToF16(i32 130, float %28)  ; LegacyF32ToF16(value)
  %210 = call float @dx.op.legacyF16ToF32(i32 131, i32 %206)  ; LegacyF16ToF32(value)
  %211 = call float @dx.op.legacyF16ToF32(i32 131, i32 %207)  ; LegacyF16ToF32(value)
  %212 = call float @dx.op.legacyF16ToF32(i32 131, i32 %208)  ; LegacyF16ToF32(value)
  %213 = call float @dx.op.legacyF16ToF32(i32 131, i32 %209)  ; LegacyF16ToF32(value)
  %214 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %210)  ; IsFinite(value)
  %215 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %211)  ; IsFinite(value)
  %216 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %212)  ; IsFinite(value)
  %217 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %213)  ; IsFinite(value)
  %218 = and i1 %214, %215
  %219 = and i1 %218, %216
  %220 = and i1 %219, %217
  %221 = fcmp fast ogt float %213, 0.000000e+00
  %222 = and i1 %221, %220
  %223 = call float @dx.op.dot3.f32(i32 55, float %210, float %211, float %212, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %224 = select i1 %222, float %223, float 0.000000e+00
  %225 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %224)  ; IsFinite(value)
  %226 = and i1 %222, %225
  %227 = fmul fast float %224, %224
  %228 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %227)  ; IsFinite(value)
  %229 = and i1 %226, %228
  %230 = fmul fast float %210, %210
  %231 = fmul fast float %211, %211
  %232 = fmul fast float %212, %212
  %233 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %230)  ; IsFinite(value)
  %234 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %231)  ; IsFinite(value)
  %235 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %232)  ; IsFinite(value)
  %236 = and i1 %233, %234
  %237 = and i1 %236, %235
  %238 = and i1 %229, %237
  %239 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %240 = and i1 %74, %239
  %241 = and i1 %75, %240
  %242 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %202)  ; IsFinite(value)
  %243 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %203)  ; IsFinite(value)
  %244 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %204)  ; IsFinite(value)
  %245 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %205)  ; IsFinite(value)
  %246 = and i1 %242, %243
  %247 = and i1 %246, %244
  %248 = and i1 %247, %245
  %249 = fcmp fast ogt float %205, 0.000000e+00
  %250 = and i1 %249, %248
  %251 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %194)  ; IsFinite(value)
  %252 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %195)  ; IsFinite(value)
  %253 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %196)  ; IsFinite(value)
  %254 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %197)  ; IsFinite(value)
  %255 = and i1 %251, %252
  %256 = and i1 %255, %253
  %257 = and i1 %256, %254
  %258 = and i1 %250, %257
  %259 = fcmp fast ogt float %196, 0.000000e+00
  %260 = and i1 %259, %258
  %261 = and i1 %241, %260
  br i1 %238, label %271, label %262

; <label>:262                                     ; preds = %189
  %263 = select i1 %261, float %202, float 0.000000e+00
  %264 = select i1 %261, float %203, float 0.000000e+00
  %265 = select i1 %261, float %204, float 0.000000e+00
  %266 = select i1 %261, float %205, float 0.000000e+00
  %267 = select i1 %261, float %194, float 0.000000e+00
  %268 = select i1 %261, float %195, float 0.000000e+00
  %269 = select i1 %261, float %196, float 0.000000e+00
  %270 = select i1 %261, float %197, float 0.000000e+00
  br label %345

; <label>:271                                     ; preds = %189
  %272 = select i1 %261, float %205, float %213
  %273 = select i1 %261, float %194, float %224
  %274 = select i1 %261, float %195, float %227
  %275 = select i1 %261, float %204, float %212
  %276 = select i1 %261, float %203, float %211
  %277 = select i1 %261, float %202, float %210
  %278 = fadd fast float %210, 0x3FA47AE140000000
  %279 = fadd fast float %211, 0x3FA47AE140000000
  %280 = fadd fast float %212, 0x3FA47AE140000000
  %281 = fadd fast float %210, 0xBFA47AE140000000
  %282 = fadd fast float %211, 0xBFA47AE140000000
  %283 = fadd fast float %212, 0xBFA47AE140000000
  %284 = call float @dx.op.binary.f32(i32 35, float %277, float %281)  ; FMax(a,b)
  %285 = call float @dx.op.binary.f32(i32 35, float %276, float %282)  ; FMax(a,b)
  %286 = call float @dx.op.binary.f32(i32 35, float %275, float %283)  ; FMax(a,b)
  %287 = call float @dx.op.binary.f32(i32 36, float %284, float %278)  ; FMin(a,b)
  %288 = call float @dx.op.binary.f32(i32 36, float %285, float %279)  ; FMin(a,b)
  %289 = call float @dx.op.binary.f32(i32 36, float %286, float %280)  ; FMin(a,b)
  %290 = fadd fast float %196, 1.000000e+00
  %291 = select i1 %261, float %290, float 1.000000e+00
  %292 = call float @dx.op.binary.f32(i32 36, float %291, float 3.200000e+01)  ; FMin(a,b)
  %293 = select i1 %261, float %292, float 1.000000e+00
  %294 = fdiv fast float 1.000000e+00, %293
  %295 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %294)  ; FMax(a,b)
  %296 = select i1 %261, float %295, float 1.000000e+00
  %297 = fsub fast float %213, %272
  %298 = call float @dx.op.unary.f32(i32 6, float %297)  ; FAbs(value)
  %299 = fmul fast float %298, 2.500000e-01
  %300 = select i1 %261, float %299, float 1.000000e+00
  %301 = call float @dx.op.binary.f32(i32 35, float %296, float %300)  ; FMax(a,b)
  %302 = fsub fast float %224, %273
  %303 = fsub fast float %227, %274
  %304 = fmul fast float %301, %302
  %305 = fmul fast float %301, %303
  %306 = fadd fast float %304, %273
  %307 = fadd fast float %305, %274
  %308 = fsub fast float %210, %287
  %309 = fsub fast float %211, %288
  %310 = fsub fast float %212, %289
  %311 = fmul fast float %301, %308
  %312 = fmul fast float %301, %309
  %313 = fmul fast float %301, %310
  %314 = fmul fast float %301, %297
  %315 = fadd fast float %311, %287
  %316 = fadd fast float %312, %288
  %317 = fadd fast float %313, %289
  %318 = fadd fast float %314, %272
  %319 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %315)  ; IsFinite(value)
  %320 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %316)  ; IsFinite(value)
  %321 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %317)  ; IsFinite(value)
  %322 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %318)  ; IsFinite(value)
  %323 = and i1 %319, %320
  %324 = and i1 %323, %321
  %325 = and i1 %324, %322
  %326 = fcmp fast ogt float %318, 0.000000e+00
  %327 = and i1 %326, %325
  %328 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %306)  ; IsFinite(value)
  %329 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %307)  ; IsFinite(value)
  %330 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %293)  ; IsFinite(value)
  %331 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %332 = and i1 %328, %329
  %333 = and i1 %332, %330
  %334 = and i1 %333, %331
  %335 = and i1 %327, %334
  %336 = fcmp fast ogt float %293, 0.000000e+00
  %337 = and i1 %336, %335
  %338 = select i1 %337, float %315, float 0.000000e+00
  %339 = select i1 %337, float %316, float 0.000000e+00
  %340 = select i1 %337, float %317, float 0.000000e+00
  %341 = select i1 %337, float %318, float 0.000000e+00
  %342 = select i1 %337, float %306, float 0.000000e+00
  %343 = select i1 %337, float %307, float 0.000000e+00
  %344 = select i1 %337, float %293, float 0.000000e+00
  br label %345

; <label>:345                                     ; preds = %271, %262
  %346 = phi float [ %263, %262 ], [ %338, %271 ]
  %347 = phi float [ %264, %262 ], [ %339, %271 ]
  %348 = phi float [ %265, %262 ], [ %340, %271 ]
  %349 = phi float [ %266, %262 ], [ %341, %271 ]
  %350 = phi float [ %267, %262 ], [ %342, %271 ]
  %351 = phi float [ %268, %262 ], [ %343, %271 ]
  %352 = phi float [ %269, %262 ], [ %344, %271 ]
  %353 = phi float [ %270, %262 ], [ 0.000000e+00, %271 ]
  %354 = call i32 @dx.op.legacyF32ToF16(i32 130, float %346)  ; LegacyF32ToF16(value)
  %355 = call i32 @dx.op.legacyF32ToF16(i32 130, float %347)  ; LegacyF32ToF16(value)
  %356 = call i32 @dx.op.legacyF32ToF16(i32 130, float %348)  ; LegacyF32ToF16(value)
  %357 = call i32 @dx.op.legacyF32ToF16(i32 130, float %349)  ; LegacyF32ToF16(value)
  %358 = call float @dx.op.legacyF16ToF32(i32 131, i32 %354)  ; LegacyF16ToF32(value)
  %359 = call float @dx.op.legacyF16ToF32(i32 131, i32 %355)  ; LegacyF16ToF32(value)
  %360 = call float @dx.op.legacyF16ToF32(i32 131, i32 %356)  ; LegacyF16ToF32(value)
  %361 = call float @dx.op.legacyF16ToF32(i32 131, i32 %357)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %202, float %203, float %204, float %205, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %194, float %195, float %196, float %197, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %358, float %359, float %360, float %361, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %350, float %351, float %352, float %353, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %362

; <label>:362                                     ; preds = %345, %0
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
