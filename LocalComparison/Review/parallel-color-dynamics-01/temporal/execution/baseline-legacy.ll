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
; shader hash: cf7584159ed1b2f34a7bb9d443694f98
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

define void @CSTemporalReactionTest() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call i32 @dx.op.threadId.i32(i32 93, i32 0)  ; ThreadId(component)
  %5 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %3, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %6 = extractvalue %dx.types.CBufRet.i32 %5, 0
  %7 = icmp ult i32 %4, %6
  br i1 %7, label %8, label %356

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
  %74 = icmp ne i32 %48, 0
  %75 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %76 = and i1 %74, %75
  %77 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 5.000000e-01)  ; IsFinite(value)
  %78 = and i1 %76, %77
  %79 = fcmp fast olt float %30, 5.000000e-01
  %80 = and i1 %79, %78
  %81 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %36)  ; IsFinite(value)
  %82 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %37)  ; IsFinite(value)
  %83 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %38)  ; IsFinite(value)
  %84 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %39)  ; IsFinite(value)
  %85 = and i1 %81, %82
  %86 = and i1 %85, %83
  %87 = and i1 %86, %84
  %88 = fcmp fast ogt float %39, 0.000000e+00
  %89 = and i1 %88, %87
  %90 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %15)  ; IsFinite(value)
  %91 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %16)  ; IsFinite(value)
  %92 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %17)  ; IsFinite(value)
  %93 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %94 = and i1 %90, %91
  %95 = and i1 %94, %92
  %96 = and i1 %95, %93
  %97 = and i1 %89, %96
  %98 = fcmp fast ogt float %17, 0.000000e+00
  %99 = and i1 %98, %97
  %100 = and i1 %80, %99
  %101 = select i1 %100, float %17, float 0.000000e+00
  br i1 %73, label %110, label %102

; <label>:102                                     ; preds = %8
  %103 = select i1 %100, float %18, float 0.000000e+00
  %104 = select i1 %100, float %36, float 0.000000e+00
  %105 = select i1 %100, float %37, float 0.000000e+00
  %106 = select i1 %100, float %38, float 0.000000e+00
  %107 = select i1 %100, float %39, float 0.000000e+00
  %108 = select i1 %100, float %15, float 0.000000e+00
  %109 = select i1 %100, float %16, float 0.000000e+00
  br label %186

; <label>:110                                     ; preds = %8
  %111 = extractvalue %dx.types.ResRet.f32 %29, 0
  %112 = select i1 %100, float %39, float %47
  %113 = select i1 %100, float %15, float %59
  %114 = select i1 %100, float %16, float %62
  %115 = select i1 %100, float %38, float %46
  %116 = select i1 %100, float %37, float %45
  %117 = select i1 %100, float %36, float %44
  %118 = fadd fast float %44, 0x3FA47AE140000000
  %119 = fadd fast float %45, 0x3FA47AE140000000
  %120 = fadd fast float %46, 0x3FA47AE140000000
  %121 = fadd fast float %44, 0xBFA47AE140000000
  %122 = fadd fast float %45, 0xBFA47AE140000000
  %123 = fadd fast float %46, 0xBFA47AE140000000
  %124 = call float @dx.op.binary.f32(i32 35, float %117, float %121)  ; FMax(a,b)
  %125 = call float @dx.op.binary.f32(i32 35, float %116, float %122)  ; FMax(a,b)
  %126 = call float @dx.op.binary.f32(i32 35, float %115, float %123)  ; FMax(a,b)
  %127 = call float @dx.op.binary.f32(i32 36, float %124, float %118)  ; FMin(a,b)
  %128 = call float @dx.op.binary.f32(i32 36, float %125, float %119)  ; FMin(a,b)
  %129 = call float @dx.op.binary.f32(i32 36, float %126, float %120)  ; FMin(a,b)
  %130 = fcmp fast ogt float %111, 5.000000e-01
  %131 = select i1 %130, float 2.000000e+00, float 3.200000e+01
  %132 = fadd fast float %101, 1.000000e+00
  %133 = call float @dx.op.binary.f32(i32 36, float %132, float %131)  ; FMin(a,b)
  %134 = select i1 %100, float %133, float 1.000000e+00
  %135 = fdiv fast float 1.000000e+00, %134
  %136 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %135)  ; FMax(a,b)
  %137 = select i1 %100, float %136, float 1.000000e+00
  %138 = fsub fast float %47, %112
  %139 = call float @dx.op.unary.f32(i32 6, float %138)  ; FAbs(value)
  %140 = fmul fast float %139, 2.500000e-01
  %141 = select i1 %100, float %140, float 1.000000e+00
  %142 = call float @dx.op.binary.f32(i32 35, float %137, float %141)  ; FMax(a,b)
  %143 = fsub fast float %59, %113
  %144 = fsub fast float %62, %114
  %145 = fmul fast float %142, %143
  %146 = fmul fast float %142, %144
  %147 = fadd fast float %145, %113
  %148 = fadd fast float %146, %114
  %149 = fsub fast float %44, %127
  %150 = fsub fast float %45, %128
  %151 = fsub fast float %46, %129
  %152 = fmul fast float %142, %149
  %153 = fmul fast float %142, %150
  %154 = fmul fast float %142, %151
  %155 = fmul fast float %142, %138
  %156 = fadd fast float %152, %127
  %157 = fadd fast float %153, %128
  %158 = fadd fast float %154, %129
  %159 = fadd fast float %155, %112
  %160 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %156)  ; IsFinite(value)
  %161 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %157)  ; IsFinite(value)
  %162 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %158)  ; IsFinite(value)
  %163 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %159)  ; IsFinite(value)
  %164 = and i1 %160, %161
  %165 = and i1 %164, %162
  %166 = and i1 %165, %163
  %167 = fcmp fast ogt float %159, 0.000000e+00
  %168 = and i1 %167, %166
  %169 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %147)  ; IsFinite(value)
  %170 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %148)  ; IsFinite(value)
  %171 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %134)  ; IsFinite(value)
  %172 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %173 = and i1 %169, %170
  %174 = and i1 %173, %171
  %175 = and i1 %174, %172
  %176 = and i1 %168, %175
  %177 = fcmp fast ogt float %134, 0.000000e+00
  %178 = and i1 %177, %176
  %179 = select i1 %178, float %156, float 0.000000e+00
  %180 = select i1 %178, float %157, float 0.000000e+00
  %181 = select i1 %178, float %158, float 0.000000e+00
  %182 = select i1 %178, float %159, float 0.000000e+00
  %183 = select i1 %178, float %147, float 0.000000e+00
  %184 = select i1 %178, float %148, float 0.000000e+00
  %185 = select i1 %178, float %134, float 0.000000e+00
  br label %186

; <label>:186                                     ; preds = %110, %102
  %187 = phi float [ %104, %102 ], [ %179, %110 ]
  %188 = phi float [ %105, %102 ], [ %180, %110 ]
  %189 = phi float [ %106, %102 ], [ %181, %110 ]
  %190 = phi float [ %107, %102 ], [ %182, %110 ]
  %191 = phi float [ %108, %102 ], [ %183, %110 ]
  %192 = phi float [ %109, %102 ], [ %184, %110 ]
  %193 = phi float [ %101, %102 ], [ %185, %110 ]
  %194 = phi float [ %103, %102 ], [ 0.000000e+00, %110 ]
  %195 = call i32 @dx.op.legacyF32ToF16(i32 130, float %187)  ; LegacyF32ToF16(value)
  %196 = call i32 @dx.op.legacyF32ToF16(i32 130, float %188)  ; LegacyF32ToF16(value)
  %197 = call i32 @dx.op.legacyF32ToF16(i32 130, float %189)  ; LegacyF32ToF16(value)
  %198 = call i32 @dx.op.legacyF32ToF16(i32 130, float %190)  ; LegacyF32ToF16(value)
  %199 = call float @dx.op.legacyF16ToF32(i32 131, i32 %195)  ; LegacyF16ToF32(value)
  %200 = call float @dx.op.legacyF16ToF32(i32 131, i32 %196)  ; LegacyF16ToF32(value)
  %201 = call float @dx.op.legacyF16ToF32(i32 131, i32 %197)  ; LegacyF16ToF32(value)
  %202 = call float @dx.op.legacyF16ToF32(i32 131, i32 %198)  ; LegacyF16ToF32(value)
  %203 = call i32 @dx.op.legacyF32ToF16(i32 130, float %25)  ; LegacyF32ToF16(value)
  %204 = call i32 @dx.op.legacyF32ToF16(i32 130, float %26)  ; LegacyF32ToF16(value)
  %205 = call i32 @dx.op.legacyF32ToF16(i32 130, float %27)  ; LegacyF32ToF16(value)
  %206 = call i32 @dx.op.legacyF32ToF16(i32 130, float %28)  ; LegacyF32ToF16(value)
  %207 = call float @dx.op.legacyF16ToF32(i32 131, i32 %203)  ; LegacyF16ToF32(value)
  %208 = call float @dx.op.legacyF16ToF32(i32 131, i32 %204)  ; LegacyF16ToF32(value)
  %209 = call float @dx.op.legacyF16ToF32(i32 131, i32 %205)  ; LegacyF16ToF32(value)
  %210 = call float @dx.op.legacyF16ToF32(i32 131, i32 %206)  ; LegacyF16ToF32(value)
  %211 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %207)  ; IsFinite(value)
  %212 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %208)  ; IsFinite(value)
  %213 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %209)  ; IsFinite(value)
  %214 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %210)  ; IsFinite(value)
  %215 = and i1 %211, %212
  %216 = and i1 %215, %213
  %217 = and i1 %216, %214
  %218 = fcmp fast ogt float %210, 0.000000e+00
  %219 = and i1 %218, %217
  %220 = call float @dx.op.dot3.f32(i32 55, float %207, float %208, float %209, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %221 = select i1 %219, float %220, float 0.000000e+00
  %222 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %221)  ; IsFinite(value)
  %223 = and i1 %219, %222
  %224 = fmul fast float %221, %221
  %225 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %224)  ; IsFinite(value)
  %226 = and i1 %223, %225
  %227 = fmul fast float %207, %207
  %228 = fmul fast float %208, %208
  %229 = fmul fast float %209, %209
  %230 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %227)  ; IsFinite(value)
  %231 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %228)  ; IsFinite(value)
  %232 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %229)  ; IsFinite(value)
  %233 = and i1 %230, %231
  %234 = and i1 %233, %232
  %235 = and i1 %226, %234
  %236 = and i1 %75, %77
  %237 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %199)  ; IsFinite(value)
  %238 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %200)  ; IsFinite(value)
  %239 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %201)  ; IsFinite(value)
  %240 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %202)  ; IsFinite(value)
  %241 = and i1 %237, %238
  %242 = and i1 %241, %239
  %243 = and i1 %242, %240
  %244 = fcmp fast ogt float %202, 0.000000e+00
  %245 = and i1 %244, %243
  %246 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %191)  ; IsFinite(value)
  %247 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %192)  ; IsFinite(value)
  %248 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %193)  ; IsFinite(value)
  %249 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %194)  ; IsFinite(value)
  %250 = and i1 %246, %247
  %251 = and i1 %250, %248
  %252 = and i1 %251, %249
  %253 = and i1 %245, %252
  %254 = fcmp fast ogt float %193, 0.000000e+00
  %255 = and i1 %254, %253
  %256 = and i1 %236, %255
  %257 = select i1 %256, float %193, float 0.000000e+00
  br i1 %235, label %266, label %258

; <label>:258                                     ; preds = %186
  %259 = select i1 %256, float %194, float 0.000000e+00
  %260 = select i1 %256, float %199, float 0.000000e+00
  %261 = select i1 %256, float %200, float 0.000000e+00
  %262 = select i1 %256, float %201, float 0.000000e+00
  %263 = select i1 %256, float %202, float 0.000000e+00
  %264 = select i1 %256, float %191, float 0.000000e+00
  %265 = select i1 %256, float %192, float 0.000000e+00
  br label %339

; <label>:266                                     ; preds = %186
  %267 = select i1 %256, float %202, float %210
  %268 = select i1 %256, float %191, float %221
  %269 = select i1 %256, float %192, float %224
  %270 = select i1 %256, float %201, float %209
  %271 = select i1 %256, float %200, float %208
  %272 = select i1 %256, float %199, float %207
  %273 = fadd fast float %207, 0x3FA47AE140000000
  %274 = fadd fast float %208, 0x3FA47AE140000000
  %275 = fadd fast float %209, 0x3FA47AE140000000
  %276 = fadd fast float %207, 0xBFA47AE140000000
  %277 = fadd fast float %208, 0xBFA47AE140000000
  %278 = fadd fast float %209, 0xBFA47AE140000000
  %279 = call float @dx.op.binary.f32(i32 35, float %272, float %276)  ; FMax(a,b)
  %280 = call float @dx.op.binary.f32(i32 35, float %271, float %277)  ; FMax(a,b)
  %281 = call float @dx.op.binary.f32(i32 35, float %270, float %278)  ; FMax(a,b)
  %282 = call float @dx.op.binary.f32(i32 36, float %279, float %273)  ; FMin(a,b)
  %283 = call float @dx.op.binary.f32(i32 36, float %280, float %274)  ; FMin(a,b)
  %284 = call float @dx.op.binary.f32(i32 36, float %281, float %275)  ; FMin(a,b)
  %285 = fadd fast float %257, 1.000000e+00
  %286 = call float @dx.op.binary.f32(i32 36, float %285, float 3.200000e+01)  ; FMin(a,b)
  %287 = select i1 %256, float %286, float 1.000000e+00
  %288 = fdiv fast float 1.000000e+00, %287
  %289 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %288)  ; FMax(a,b)
  %290 = select i1 %256, float %289, float 1.000000e+00
  %291 = fsub fast float %210, %267
  %292 = call float @dx.op.unary.f32(i32 6, float %291)  ; FAbs(value)
  %293 = fmul fast float %292, 2.500000e-01
  %294 = select i1 %256, float %293, float 1.000000e+00
  %295 = call float @dx.op.binary.f32(i32 35, float %290, float %294)  ; FMax(a,b)
  %296 = fsub fast float %221, %268
  %297 = fsub fast float %224, %269
  %298 = fmul fast float %295, %296
  %299 = fmul fast float %295, %297
  %300 = fadd fast float %298, %268
  %301 = fadd fast float %299, %269
  %302 = fsub fast float %207, %282
  %303 = fsub fast float %208, %283
  %304 = fsub fast float %209, %284
  %305 = fmul fast float %295, %302
  %306 = fmul fast float %295, %303
  %307 = fmul fast float %295, %304
  %308 = fmul fast float %295, %291
  %309 = fadd fast float %305, %282
  %310 = fadd fast float %306, %283
  %311 = fadd fast float %307, %284
  %312 = fadd fast float %308, %267
  %313 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %309)  ; IsFinite(value)
  %314 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %310)  ; IsFinite(value)
  %315 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %311)  ; IsFinite(value)
  %316 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %312)  ; IsFinite(value)
  %317 = and i1 %313, %314
  %318 = and i1 %317, %315
  %319 = and i1 %318, %316
  %320 = fcmp fast ogt float %312, 0.000000e+00
  %321 = and i1 %320, %319
  %322 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %300)  ; IsFinite(value)
  %323 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %301)  ; IsFinite(value)
  %324 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %287)  ; IsFinite(value)
  %325 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %326 = and i1 %322, %323
  %327 = and i1 %326, %324
  %328 = and i1 %327, %325
  %329 = and i1 %321, %328
  %330 = fcmp fast ogt float %287, 0.000000e+00
  %331 = and i1 %330, %329
  %332 = select i1 %331, float %309, float 0.000000e+00
  %333 = select i1 %331, float %310, float 0.000000e+00
  %334 = select i1 %331, float %311, float 0.000000e+00
  %335 = select i1 %331, float %312, float 0.000000e+00
  %336 = select i1 %331, float %300, float 0.000000e+00
  %337 = select i1 %331, float %301, float 0.000000e+00
  %338 = select i1 %331, float %287, float 0.000000e+00
  br label %339

; <label>:339                                     ; preds = %266, %258
  %340 = phi float [ %260, %258 ], [ %332, %266 ]
  %341 = phi float [ %261, %258 ], [ %333, %266 ]
  %342 = phi float [ %262, %258 ], [ %334, %266 ]
  %343 = phi float [ %263, %258 ], [ %335, %266 ]
  %344 = phi float [ %264, %258 ], [ %336, %266 ]
  %345 = phi float [ %265, %258 ], [ %337, %266 ]
  %346 = phi float [ %257, %258 ], [ %338, %266 ]
  %347 = phi float [ %259, %258 ], [ 0.000000e+00, %266 ]
  %348 = call i32 @dx.op.legacyF32ToF16(i32 130, float %340)  ; LegacyF32ToF16(value)
  %349 = call i32 @dx.op.legacyF32ToF16(i32 130, float %341)  ; LegacyF32ToF16(value)
  %350 = call i32 @dx.op.legacyF32ToF16(i32 130, float %342)  ; LegacyF32ToF16(value)
  %351 = call i32 @dx.op.legacyF32ToF16(i32 130, float %343)  ; LegacyF32ToF16(value)
  %352 = call float @dx.op.legacyF16ToF32(i32 131, i32 %348)  ; LegacyF16ToF32(value)
  %353 = call float @dx.op.legacyF16ToF32(i32 131, i32 %349)  ; LegacyF16ToF32(value)
  %354 = call float @dx.op.legacyF16ToF32(i32 131, i32 %350)  ; LegacyF16ToF32(value)
  %355 = call float @dx.op.legacyF16ToF32(i32 131, i32 %351)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %199, float %200, float %201, float %202, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %191, float %192, float %193, float %194, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %352, float %353, float %354, float %355, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %344, float %345, float %346, float %347, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %356

; <label>:356                                     ; preds = %339, %0
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
declare float @dx.op.binary.f32(i32, float, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

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
