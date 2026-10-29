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
; shader hash: a2220b18c6403689df039fe2bebf057c
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
  br i1 %7, label %8, label %358

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
  %75 = icmp ne i32 %49, 0
  %76 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %77 = and i1 %75, %76
  %78 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 5.000000e-01)  ; IsFinite(value)
  %79 = and i1 %77, %78
  %80 = fcmp fast olt float %31, 5.000000e-01
  %81 = and i1 %80, %79
  %82 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %37)  ; IsFinite(value)
  %83 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %38)  ; IsFinite(value)
  %84 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %39)  ; IsFinite(value)
  %85 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %40)  ; IsFinite(value)
  %86 = and i1 %82, %83
  %87 = and i1 %86, %84
  %88 = and i1 %87, %85
  %89 = fcmp fast ogt float %40, 0.000000e+00
  %90 = and i1 %89, %88
  %91 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %15)  ; IsFinite(value)
  %92 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %16)  ; IsFinite(value)
  %93 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %17)  ; IsFinite(value)
  %94 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %95 = and i1 %91, %92
  %96 = and i1 %95, %93
  %97 = and i1 %96, %94
  %98 = and i1 %90, %97
  %99 = fcmp fast ogt float %17, 0.000000e+00
  %100 = and i1 %99, %98
  %101 = and i1 %81, %100
  %102 = select i1 %101, float %17, float 0.000000e+00
  %103 = select i1 %101, float %18, float 0.000000e+00
  %104 = fcmp fast ogt float %30, 5.000000e-01
  br i1 %74, label %114, label %105

; <label>:105                                     ; preds = %8
  %106 = select i1 %101, float %37, float 0.000000e+00
  %107 = select i1 %101, float %38, float 0.000000e+00
  %108 = select i1 %101, float %39, float 0.000000e+00
  %109 = select i1 %101, float %40, float 0.000000e+00
  %110 = select i1 %101, float %15, float 0.000000e+00
  %111 = select i1 %101, float %16, float 0.000000e+00
  br i1 %104, label %112, label %188

; <label>:112                                     ; preds = %105
  %113 = call float @dx.op.binary.f32(i32 36, float %102, float 2.000000e+00)  ; FMin(a,b)
  br label %188

; <label>:114                                     ; preds = %8
  %115 = select i1 %101, float %40, float %48
  %116 = select i1 %101, float %15, float %60
  %117 = select i1 %101, float %16, float %63
  %118 = select i1 %101, float %39, float %47
  %119 = select i1 %101, float %38, float %46
  %120 = select i1 %101, float %37, float %45
  %121 = fadd fast float %45, 0x3FA47AE140000000
  %122 = fadd fast float %46, 0x3FA47AE140000000
  %123 = fadd fast float %47, 0x3FA47AE140000000
  %124 = fadd fast float %45, 0xBFA47AE140000000
  %125 = fadd fast float %46, 0xBFA47AE140000000
  %126 = fadd fast float %47, 0xBFA47AE140000000
  %127 = call float @dx.op.binary.f32(i32 35, float %120, float %124)  ; FMax(a,b)
  %128 = call float @dx.op.binary.f32(i32 35, float %119, float %125)  ; FMax(a,b)
  %129 = call float @dx.op.binary.f32(i32 35, float %118, float %126)  ; FMax(a,b)
  %130 = call float @dx.op.binary.f32(i32 36, float %127, float %121)  ; FMin(a,b)
  %131 = call float @dx.op.binary.f32(i32 36, float %128, float %122)  ; FMin(a,b)
  %132 = call float @dx.op.binary.f32(i32 36, float %129, float %123)  ; FMin(a,b)
  %133 = select i1 %104, float 2.000000e+00, float 3.200000e+01
  %134 = fadd fast float %102, 1.000000e+00
  %135 = call float @dx.op.binary.f32(i32 36, float %134, float %133)  ; FMin(a,b)
  %136 = select i1 %101, float %135, float 1.000000e+00
  %137 = fdiv fast float 1.000000e+00, %136
  %138 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %137)  ; FMax(a,b)
  %139 = select i1 %101, float %138, float 1.000000e+00
  %140 = fsub fast float %48, %115
  %141 = call float @dx.op.unary.f32(i32 6, float %140)  ; FAbs(value)
  %142 = fmul fast float %141, 2.500000e-01
  %143 = select i1 %101, float %142, float 1.000000e+00
  %144 = call float @dx.op.binary.f32(i32 35, float %139, float %143)  ; FMax(a,b)
  %145 = fsub fast float %60, %116
  %146 = fsub fast float %63, %117
  %147 = fmul fast float %144, %145
  %148 = fmul fast float %144, %146
  %149 = fadd fast float %147, %116
  %150 = fadd fast float %148, %117
  %151 = fsub fast float %45, %130
  %152 = fsub fast float %46, %131
  %153 = fsub fast float %47, %132
  %154 = fmul fast float %144, %151
  %155 = fmul fast float %144, %152
  %156 = fmul fast float %144, %153
  %157 = fmul fast float %144, %140
  %158 = fadd fast float %154, %130
  %159 = fadd fast float %155, %131
  %160 = fadd fast float %156, %132
  %161 = fadd fast float %157, %115
  %162 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %158)  ; IsFinite(value)
  %163 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %159)  ; IsFinite(value)
  %164 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %160)  ; IsFinite(value)
  %165 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %161)  ; IsFinite(value)
  %166 = and i1 %162, %163
  %167 = and i1 %166, %164
  %168 = and i1 %167, %165
  %169 = fcmp fast ogt float %161, 0.000000e+00
  %170 = and i1 %169, %168
  %171 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %149)  ; IsFinite(value)
  %172 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %150)  ; IsFinite(value)
  %173 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %136)  ; IsFinite(value)
  %174 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %175 = and i1 %171, %172
  %176 = and i1 %175, %173
  %177 = and i1 %176, %174
  %178 = and i1 %170, %177
  %179 = fcmp fast ogt float %136, 0.000000e+00
  %180 = and i1 %179, %178
  %181 = select i1 %180, float %158, float 0.000000e+00
  %182 = select i1 %180, float %159, float 0.000000e+00
  %183 = select i1 %180, float %160, float 0.000000e+00
  %184 = select i1 %180, float %161, float 0.000000e+00
  %185 = select i1 %180, float %149, float 0.000000e+00
  %186 = select i1 %180, float %150, float 0.000000e+00
  %187 = select i1 %180, float %136, float 0.000000e+00
  br label %188

; <label>:188                                     ; preds = %114, %112, %105
  %189 = phi float [ %106, %112 ], [ %106, %105 ], [ %181, %114 ]
  %190 = phi float [ %107, %112 ], [ %107, %105 ], [ %182, %114 ]
  %191 = phi float [ %108, %112 ], [ %108, %105 ], [ %183, %114 ]
  %192 = phi float [ %109, %112 ], [ %109, %105 ], [ %184, %114 ]
  %193 = phi float [ %110, %112 ], [ %110, %105 ], [ %185, %114 ]
  %194 = phi float [ %111, %112 ], [ %111, %105 ], [ %186, %114 ]
  %195 = phi float [ %113, %112 ], [ %102, %105 ], [ %187, %114 ]
  %196 = phi float [ %103, %112 ], [ %103, %105 ], [ 0.000000e+00, %114 ]
  %197 = call i32 @dx.op.legacyF32ToF16(i32 130, float %189)  ; LegacyF32ToF16(value)
  %198 = call i32 @dx.op.legacyF32ToF16(i32 130, float %190)  ; LegacyF32ToF16(value)
  %199 = call i32 @dx.op.legacyF32ToF16(i32 130, float %191)  ; LegacyF32ToF16(value)
  %200 = call i32 @dx.op.legacyF32ToF16(i32 130, float %192)  ; LegacyF32ToF16(value)
  %201 = call float @dx.op.legacyF16ToF32(i32 131, i32 %197)  ; LegacyF16ToF32(value)
  %202 = call float @dx.op.legacyF16ToF32(i32 131, i32 %198)  ; LegacyF16ToF32(value)
  %203 = call float @dx.op.legacyF16ToF32(i32 131, i32 %199)  ; LegacyF16ToF32(value)
  %204 = call float @dx.op.legacyF16ToF32(i32 131, i32 %200)  ; LegacyF16ToF32(value)
  %205 = call i32 @dx.op.legacyF32ToF16(i32 130, float %25)  ; LegacyF32ToF16(value)
  %206 = call i32 @dx.op.legacyF32ToF16(i32 130, float %26)  ; LegacyF32ToF16(value)
  %207 = call i32 @dx.op.legacyF32ToF16(i32 130, float %27)  ; LegacyF32ToF16(value)
  %208 = call i32 @dx.op.legacyF32ToF16(i32 130, float %28)  ; LegacyF32ToF16(value)
  %209 = call float @dx.op.legacyF16ToF32(i32 131, i32 %205)  ; LegacyF16ToF32(value)
  %210 = call float @dx.op.legacyF16ToF32(i32 131, i32 %206)  ; LegacyF16ToF32(value)
  %211 = call float @dx.op.legacyF16ToF32(i32 131, i32 %207)  ; LegacyF16ToF32(value)
  %212 = call float @dx.op.legacyF16ToF32(i32 131, i32 %208)  ; LegacyF16ToF32(value)
  %213 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %209)  ; IsFinite(value)
  %214 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %210)  ; IsFinite(value)
  %215 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %211)  ; IsFinite(value)
  %216 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %212)  ; IsFinite(value)
  %217 = and i1 %213, %214
  %218 = and i1 %217, %215
  %219 = and i1 %218, %216
  %220 = fcmp fast ogt float %212, 0.000000e+00
  %221 = and i1 %220, %219
  %222 = call float @dx.op.dot3.f32(i32 55, float %209, float %210, float %211, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %223 = select i1 %221, float %222, float 0.000000e+00
  %224 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %223)  ; IsFinite(value)
  %225 = and i1 %221, %224
  %226 = fmul fast float %223, %223
  %227 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %226)  ; IsFinite(value)
  %228 = and i1 %225, %227
  %229 = fmul fast float %209, %209
  %230 = fmul fast float %210, %210
  %231 = fmul fast float %211, %211
  %232 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %229)  ; IsFinite(value)
  %233 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %230)  ; IsFinite(value)
  %234 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %231)  ; IsFinite(value)
  %235 = and i1 %232, %233
  %236 = and i1 %235, %234
  %237 = and i1 %228, %236
  %238 = and i1 %76, %78
  %239 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %201)  ; IsFinite(value)
  %240 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %202)  ; IsFinite(value)
  %241 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %203)  ; IsFinite(value)
  %242 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %204)  ; IsFinite(value)
  %243 = and i1 %239, %240
  %244 = and i1 %243, %241
  %245 = and i1 %244, %242
  %246 = fcmp fast ogt float %204, 0.000000e+00
  %247 = and i1 %246, %245
  %248 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %193)  ; IsFinite(value)
  %249 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %194)  ; IsFinite(value)
  %250 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %195)  ; IsFinite(value)
  %251 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %196)  ; IsFinite(value)
  %252 = and i1 %248, %249
  %253 = and i1 %252, %250
  %254 = and i1 %253, %251
  %255 = and i1 %247, %254
  %256 = fcmp fast ogt float %195, 0.000000e+00
  %257 = and i1 %256, %255
  %258 = and i1 %238, %257
  %259 = select i1 %258, float %195, float 0.000000e+00
  br i1 %237, label %268, label %260

; <label>:260                                     ; preds = %188
  %261 = select i1 %258, float %196, float 0.000000e+00
  %262 = select i1 %258, float %201, float 0.000000e+00
  %263 = select i1 %258, float %202, float 0.000000e+00
  %264 = select i1 %258, float %203, float 0.000000e+00
  %265 = select i1 %258, float %204, float 0.000000e+00
  %266 = select i1 %258, float %193, float 0.000000e+00
  %267 = select i1 %258, float %194, float 0.000000e+00
  br label %341

; <label>:268                                     ; preds = %188
  %269 = select i1 %258, float %204, float %212
  %270 = select i1 %258, float %193, float %223
  %271 = select i1 %258, float %194, float %226
  %272 = select i1 %258, float %203, float %211
  %273 = select i1 %258, float %202, float %210
  %274 = select i1 %258, float %201, float %209
  %275 = fadd fast float %209, 0x3FA47AE140000000
  %276 = fadd fast float %210, 0x3FA47AE140000000
  %277 = fadd fast float %211, 0x3FA47AE140000000
  %278 = fadd fast float %209, 0xBFA47AE140000000
  %279 = fadd fast float %210, 0xBFA47AE140000000
  %280 = fadd fast float %211, 0xBFA47AE140000000
  %281 = call float @dx.op.binary.f32(i32 35, float %274, float %278)  ; FMax(a,b)
  %282 = call float @dx.op.binary.f32(i32 35, float %273, float %279)  ; FMax(a,b)
  %283 = call float @dx.op.binary.f32(i32 35, float %272, float %280)  ; FMax(a,b)
  %284 = call float @dx.op.binary.f32(i32 36, float %281, float %275)  ; FMin(a,b)
  %285 = call float @dx.op.binary.f32(i32 36, float %282, float %276)  ; FMin(a,b)
  %286 = call float @dx.op.binary.f32(i32 36, float %283, float %277)  ; FMin(a,b)
  %287 = fadd fast float %259, 1.000000e+00
  %288 = call float @dx.op.binary.f32(i32 36, float %287, float 3.200000e+01)  ; FMin(a,b)
  %289 = select i1 %258, float %288, float 1.000000e+00
  %290 = fdiv fast float 1.000000e+00, %289
  %291 = call float @dx.op.binary.f32(i32 35, float 0x3FB47AE140000000, float %290)  ; FMax(a,b)
  %292 = select i1 %258, float %291, float 1.000000e+00
  %293 = fsub fast float %212, %269
  %294 = call float @dx.op.unary.f32(i32 6, float %293)  ; FAbs(value)
  %295 = fmul fast float %294, 2.500000e-01
  %296 = select i1 %258, float %295, float 1.000000e+00
  %297 = call float @dx.op.binary.f32(i32 35, float %292, float %296)  ; FMax(a,b)
  %298 = fsub fast float %223, %270
  %299 = fsub fast float %226, %271
  %300 = fmul fast float %297, %298
  %301 = fmul fast float %297, %299
  %302 = fadd fast float %300, %270
  %303 = fadd fast float %301, %271
  %304 = fsub fast float %209, %284
  %305 = fsub fast float %210, %285
  %306 = fsub fast float %211, %286
  %307 = fmul fast float %297, %304
  %308 = fmul fast float %297, %305
  %309 = fmul fast float %297, %306
  %310 = fmul fast float %297, %293
  %311 = fadd fast float %307, %284
  %312 = fadd fast float %308, %285
  %313 = fadd fast float %309, %286
  %314 = fadd fast float %310, %269
  %315 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %311)  ; IsFinite(value)
  %316 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %312)  ; IsFinite(value)
  %317 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %313)  ; IsFinite(value)
  %318 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %314)  ; IsFinite(value)
  %319 = and i1 %315, %316
  %320 = and i1 %319, %317
  %321 = and i1 %320, %318
  %322 = fcmp fast ogt float %314, 0.000000e+00
  %323 = and i1 %322, %321
  %324 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %302)  ; IsFinite(value)
  %325 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %303)  ; IsFinite(value)
  %326 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %289)  ; IsFinite(value)
  %327 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %328 = and i1 %324, %325
  %329 = and i1 %328, %326
  %330 = and i1 %329, %327
  %331 = and i1 %323, %330
  %332 = fcmp fast ogt float %289, 0.000000e+00
  %333 = and i1 %332, %331
  %334 = select i1 %333, float %311, float 0.000000e+00
  %335 = select i1 %333, float %312, float 0.000000e+00
  %336 = select i1 %333, float %313, float 0.000000e+00
  %337 = select i1 %333, float %314, float 0.000000e+00
  %338 = select i1 %333, float %302, float 0.000000e+00
  %339 = select i1 %333, float %303, float 0.000000e+00
  %340 = select i1 %333, float %289, float 0.000000e+00
  br label %341

; <label>:341                                     ; preds = %268, %260
  %342 = phi float [ %262, %260 ], [ %334, %268 ]
  %343 = phi float [ %263, %260 ], [ %335, %268 ]
  %344 = phi float [ %264, %260 ], [ %336, %268 ]
  %345 = phi float [ %265, %260 ], [ %337, %268 ]
  %346 = phi float [ %266, %260 ], [ %338, %268 ]
  %347 = phi float [ %267, %260 ], [ %339, %268 ]
  %348 = phi float [ %259, %260 ], [ %340, %268 ]
  %349 = phi float [ %261, %260 ], [ 0.000000e+00, %268 ]
  %350 = call i32 @dx.op.legacyF32ToF16(i32 130, float %342)  ; LegacyF32ToF16(value)
  %351 = call i32 @dx.op.legacyF32ToF16(i32 130, float %343)  ; LegacyF32ToF16(value)
  %352 = call i32 @dx.op.legacyF32ToF16(i32 130, float %344)  ; LegacyF32ToF16(value)
  %353 = call i32 @dx.op.legacyF32ToF16(i32 130, float %345)  ; LegacyF32ToF16(value)
  %354 = call float @dx.op.legacyF16ToF32(i32 131, i32 %350)  ; LegacyF16ToF32(value)
  %355 = call float @dx.op.legacyF16ToF32(i32 131, i32 %351)  ; LegacyF16ToF32(value)
  %356 = call float @dx.op.legacyF16ToF32(i32 131, i32 %352)  ; LegacyF16ToF32(value)
  %357 = call float @dx.op.legacyF16ToF32(i32 131, i32 %353)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %201, float %202, float %203, float %204, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %193, float %194, float %195, float %196, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %354, float %355, float %356, float %357, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %346, float %347, float %348, float %349, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %358

; <label>:358                                     ; preds = %341, %0
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
