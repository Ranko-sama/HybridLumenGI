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
; shader hash: 84da69fd442e56eadae02c6d63e41245
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
  br i1 %10, label %1518, label %11

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
  %41 = call i32 @dx.op.legacyF32ToF16(i32 130, float %13)  ; LegacyF32ToF16(value)
  %42 = call i32 @dx.op.legacyF32ToF16(i32 130, float %14)  ; LegacyF32ToF16(value)
  %43 = call i32 @dx.op.legacyF32ToF16(i32 130, float %15)  ; LegacyF32ToF16(value)
  %44 = call i32 @dx.op.legacyF32ToF16(i32 130, float %16)  ; LegacyF32ToF16(value)
  %45 = call float @dx.op.legacyF16ToF32(i32 131, i32 %41)  ; LegacyF16ToF32(value)
  %46 = call float @dx.op.legacyF16ToF32(i32 131, i32 %42)  ; LegacyF16ToF32(value)
  %47 = call float @dx.op.legacyF16ToF32(i32 131, i32 %43)  ; LegacyF16ToF32(value)
  %48 = call float @dx.op.legacyF16ToF32(i32 131, i32 %44)  ; LegacyF16ToF32(value)
  %49 = call i32 @dx.op.legacyF32ToF16(i32 130, float %23)  ; LegacyF32ToF16(value)
  %50 = call i32 @dx.op.legacyF32ToF16(i32 130, float %24)  ; LegacyF32ToF16(value)
  %51 = call i32 @dx.op.legacyF32ToF16(i32 130, float %25)  ; LegacyF32ToF16(value)
  %52 = call i32 @dx.op.legacyF32ToF16(i32 130, float %26)  ; LegacyF32ToF16(value)
  %53 = call float @dx.op.legacyF16ToF32(i32 131, i32 %49)  ; LegacyF16ToF32(value)
  %54 = call float @dx.op.legacyF16ToF32(i32 131, i32 %50)  ; LegacyF16ToF32(value)
  %55 = call float @dx.op.legacyF16ToF32(i32 131, i32 %51)  ; LegacyF16ToF32(value)
  %56 = call float @dx.op.legacyF16ToF32(i32 131, i32 %52)  ; LegacyF16ToF32(value)
  %57 = fptosi float %31 to i32
  %58 = fptosi float %38 to i32
  %59 = fptosi float %39 to i32
  %60 = icmp eq i32 %4, 0
  br i1 %60, label %61, label %795

; <label>:61                                      ; preds = %11
  br label %62

; <label>:62                                      ; preds = %776, %61
  %63 = phi float [ %789, %776 ], [ %45, %61 ]
  %64 = phi float [ %790, %776 ], [ %46, %61 ]
  %65 = phi float [ %791, %776 ], [ %47, %61 ]
  %66 = phi float [ %792, %776 ], [ %48, %61 ]
  %67 = phi float [ %781, %776 ], [ %18, %61 ]
  %68 = phi float [ %782, %776 ], [ %19, %61 ]
  %69 = phi float [ %783, %776 ], [ %20, %61 ]
  %70 = phi float [ %784, %776 ], [ %21, %61 ]
  %71 = phi i32 [ %793, %776 ], [ 0, %61 ]
  %72 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %53)  ; IsFinite(value)
  %73 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %74 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %75 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %76 = and i1 %72, %73
  %77 = and i1 %76, %74
  %78 = and i1 %77, %75
  %79 = fcmp fast ogt float %56, 0.000000e+00
  %80 = and i1 %79, %78
  %81 = call float @dx.op.dot3.f32(i32 55, float %53, float %54, float %55, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %82 = select i1 %80, float %81, float 0.000000e+00
  %83 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %82)  ; IsFinite(value)
  %84 = and i1 %80, %83
  %85 = fmul fast float %82, %82
  %86 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %85)  ; IsFinite(value)
  %87 = and i1 %84, %86
  %88 = fmul fast float %53, %53
  %89 = fmul fast float %54, %54
  %90 = fmul fast float %55, %55
  %91 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %88)  ; IsFinite(value)
  %92 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %89)  ; IsFinite(value)
  %93 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %90)  ; IsFinite(value)
  %94 = and i1 %91, %92
  %95 = and i1 %94, %93
  %96 = and i1 %87, %95
  %97 = fmul fast float %35, -5.000000e-01
  %98 = icmp ne i32 %57, 0
  %99 = fsub fast float 5.000000e-01, %34
  %100 = fsub fast float -0.000000e+00, %33
  %101 = select i1 %98, float %100, float %97
  %102 = fadd fast float %101, 5.000000e-01
  %103 = select i1 %98, float %99, float 5.000000e-01
  %104 = icmp ne i32 %58, 0
  %105 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %106 = and i1 %104, %105
  %107 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %102)  ; IsFinite(value)
  %108 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %103)  ; IsFinite(value)
  %109 = and i1 %107, %108
  %110 = and i1 %106, %109
  %111 = fcmp fast ogt float %102, 0.000000e+00
  %112 = fcmp fast ogt float %103, 0.000000e+00
  %113 = and i1 %112, %111
  %114 = and i1 %113, %110
  %115 = fcmp fast olt float %102, 1.000000e+00
  %116 = fcmp fast olt float %103, 1.000000e+00
  %117 = and i1 %116, %115
  %118 = and i1 %117, %114
  br i1 %118, label %119, label %173

; <label>:119                                     ; preds = %62
  %120 = call float @dx.op.unary.f32(i32 27, float %102)  ; Round_ni(value)
  %121 = call float @dx.op.unary.f32(i32 27, float %103)  ; Round_ni(value)
  %122 = fptosi float %120 to i32
  %123 = fptosi float %121 to i32
  %124 = call i32 @dx.op.binary.i32(i32 37, i32 %122, i32 0)  ; IMax(a,b)
  %125 = call i32 @dx.op.binary.i32(i32 37, i32 %123, i32 0)  ; IMax(a,b)
  %126 = call i32 @dx.op.binary.i32(i32 38, i32 %124, i32 0)  ; IMin(a,b)
  %127 = call i32 @dx.op.binary.i32(i32 38, i32 %125, i32 0)  ; IMin(a,b)
  %128 = add i32 %126, -1
  %129 = add i32 %127, -1
  %130 = call i32 @dx.op.binary.i32(i32 37, i32 %128, i32 0)  ; IMax(a,b)
  %131 = call i32 @dx.op.binary.i32(i32 37, i32 %129, i32 0)  ; IMax(a,b)
  %132 = and i32 %130, 2147483647
  %133 = and i32 %131, 2147483647
  %134 = uitofp i32 %132 to float
  %135 = uitofp i32 %133 to float
  %136 = fsub fast float %134, %101
  %137 = fsub fast float 5.000000e-01, %103
  %138 = fadd fast float %135, %137
  %139 = call float @dx.op.unary.f32(i32 6, float %136)  ; FAbs(value)
  %140 = call float @dx.op.unary.f32(i32 6, float %138)  ; FAbs(value)
  %141 = call i32 @dx.op.binary.i32(i32 38, i32 %126, i32 0)  ; IMin(a,b)
  %142 = call i32 @dx.op.binary.i32(i32 38, i32 %127, i32 0)  ; IMin(a,b)
  %143 = and i32 %141, 2147483647
  %144 = and i32 %142, 2147483647
  %145 = uitofp i32 %143 to float
  %146 = uitofp i32 %144 to float
  %147 = fsub fast float %145, %101
  %148 = fadd fast float %146, %137
  %149 = call float @dx.op.unary.f32(i32 6, float %147)  ; FAbs(value)
  %150 = call float @dx.op.unary.f32(i32 6, float %148)  ; FAbs(value)
  %151 = fcmp fast olt float %149, %139
  %152 = select i1 %151, i32 %141, i32 %130
  %153 = select i1 %151, float %149, float %139
  %154 = fcmp fast olt float %150, %140
  %155 = select i1 %154, i32 %142, i32 %131
  %156 = select i1 %154, float %150, float %140
  %157 = add i32 %126, 1
  %158 = add i32 %127, 1
  %159 = call i32 @dx.op.binary.i32(i32 38, i32 %157, i32 0)  ; IMin(a,b)
  %160 = call i32 @dx.op.binary.i32(i32 38, i32 %158, i32 0)  ; IMin(a,b)
  %161 = and i32 %159, 2147483647
  %162 = and i32 %160, 2147483647
  %163 = uitofp i32 %161 to float
  %164 = uitofp i32 %162 to float
  %165 = fsub fast float %163, %101
  %166 = fadd fast float %164, %137
  %167 = call float @dx.op.unary.f32(i32 6, float %165)  ; FAbs(value)
  %168 = call float @dx.op.unary.f32(i32 6, float %166)  ; FAbs(value)
  %169 = fcmp fast olt float %167, %153
  %170 = select i1 %169, i32 %159, i32 %152
  %171 = fcmp fast olt float %168, %156
  %172 = select i1 %171, i32 %160, i32 %155
  br label %173

; <label>:173                                     ; preds = %119, %62
  %174 = phi i32 [ 0, %62 ], [ %170, %119 ]
  %175 = phi i32 [ 0, %62 ], [ %172, %119 ]
  %176 = and i32 %174, 2147483647
  %177 = and i32 %175, 2147483647
  %178 = uitofp i32 %176 to float
  %179 = uitofp i32 %177 to float
  %180 = fadd fast float %178, 5.000000e-01
  %181 = fadd fast float %179, 5.000000e-01
  %182 = fmul fast float %180, 2.000000e+00
  %183 = fmul fast float %181, 2.000000e+00
  %184 = fadd fast float %183, -1.000000e+00
  %185 = fsub fast float 1.000000e+00, %35
  %186 = fsub fast float %185, %182
  %187 = fsub fast float -0.000000e+00, %184
  %188 = fsub fast float 5.000000e-01, %36
  %189 = call float @dx.op.dot3.f32(i32 55, float %186, float %187, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %190 = call float @dx.op.unary.f32(i32 6, float %189)  ; FAbs(value)
  %191 = fcmp fast olt float %190, 0x3F8EB851E0000000
  %192 = fmul fast float %186, %186
  %193 = fmul fast float %184, %184
  %194 = fmul fast float %188, %188
  %195 = fadd fast float %192, %194
  %196 = fadd fast float %195, %193
  %197 = call float @dx.op.unary.f32(i32 24, float %196)  ; Sqrt(value)
  %198 = fcmp fast olt float %197, 0x3F8EB851E0000000
  %199 = and i1 %191, %198
  %200 = and i1 %118, %199
  %201 = fcmp fast olt float %29, 5.000000e-01
  %202 = and i1 %201, %200
  %203 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %63)  ; IsFinite(value)
  %204 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %64)  ; IsFinite(value)
  %205 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %65)  ; IsFinite(value)
  %206 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %66)  ; IsFinite(value)
  %207 = and i1 %203, %204
  %208 = and i1 %207, %205
  %209 = and i1 %208, %206
  %210 = fcmp fast ogt float %66, 0.000000e+00
  %211 = and i1 %210, %209
  %212 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %67)  ; IsFinite(value)
  %213 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %68)  ; IsFinite(value)
  %214 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %69)  ; IsFinite(value)
  %215 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %70)  ; IsFinite(value)
  %216 = and i1 %212, %213
  %217 = and i1 %216, %214
  %218 = and i1 %217, %215
  %219 = and i1 %211, %218
  %220 = fcmp fast ogt float %69, 0.000000e+00
  %221 = and i1 %220, %219
  %222 = and i1 %202, %221
  br i1 %96, label %235, label %223

; <label>:223                                     ; preds = %173
  %224 = select i1 %222, float %63, float 0.000000e+00
  %225 = select i1 %222, float %64, float 0.000000e+00
  %226 = select i1 %222, float %65, float 0.000000e+00
  %227 = select i1 %222, float %66, float 0.000000e+00
  %228 = select i1 %222, float %67, float 0.000000e+00
  %229 = select i1 %222, float %68, float 0.000000e+00
  %230 = select i1 %222, float %69, float 0.000000e+00
  %231 = select i1 %222, float %70, float 0.000000e+00
  %232 = fcmp fast ogt float %28, 5.000000e-01
  br i1 %232, label %233, label %776

; <label>:233                                     ; preds = %223
  %234 = call float @dx.op.binary.f32(i32 36, float %230, float 2.000000e+00)  ; FMin(a,b)
  br label %776

; <label>:235                                     ; preds = %173
  %236 = fcmp ule float %30, 5.000000e-01
  %237 = and i1 %222, %236
  %238 = fcmp fast olt float %28, 5.000000e-01
  %239 = and i1 %238, %237
  %240 = sitofp i32 %59 to float
  %241 = fcmp fast oge float %69, %240
  %242 = and i1 %241, %239
  %243 = or i32 %175, %174
  %244 = icmp eq i32 %243, 0
  %245 = and i1 %244, %242
  %246 = fcmp fast oeq float %102, 5.000000e-01
  %247 = fcmp fast oeq float %103, 5.000000e-01
  %248 = and i1 %247, %246
  %249 = and i1 %248, %245
  %250 = icmp eq i32 %57, 0
  %251 = fcmp fast oeq float %33, 0.000000e+00
  %252 = fcmp fast oeq float %34, 0.000000e+00
  %253 = and i1 %251, %252
  %254 = or i1 %250, %253
  %255 = and i1 %254, %249
  %256 = fcmp fast oeq float %35, 0.000000e+00
  %257 = and i1 %256, %255
  %258 = fcmp fast oeq float %36, 5.000000e-01
  %259 = and i1 %258, %257
  %260 = xor i1 %259, true
  %261 = and i1 %237, %260
  br i1 %261, label %262, label %687

; <label>:262                                     ; preds = %235
  %263 = call float @dx.op.unary.f32(i32 27, float %102)  ; Round_ni(value)
  %264 = call float @dx.op.unary.f32(i32 27, float %103)  ; Round_ni(value)
  %265 = fptosi float %263 to i32
  %266 = fptosi float %264 to i32
  %267 = call i32 @dx.op.binary.i32(i32 37, i32 %265, i32 0)  ; IMax(a,b)
  %268 = call i32 @dx.op.binary.i32(i32 37, i32 %266, i32 0)  ; IMax(a,b)
  %269 = call i32 @dx.op.binary.i32(i32 38, i32 %267, i32 0)  ; IMin(a,b)
  %270 = call i32 @dx.op.binary.i32(i32 38, i32 %268, i32 0)  ; IMin(a,b)
  %271 = add i32 %269, -1
  %272 = add i32 %270, -1
  %273 = call i32 @dx.op.binary.i32(i32 37, i32 %271, i32 0)  ; IMax(a,b)
  %274 = call i32 @dx.op.binary.i32(i32 37, i32 %272, i32 0)  ; IMax(a,b)
  %275 = and i32 %273, 2147483647
  %276 = and i32 %274, 2147483647
  %277 = uitofp i32 %275 to float
  %278 = uitofp i32 %276 to float
  %279 = fsub fast float %277, %101
  %280 = fsub fast float 5.000000e-01, %103
  %281 = fadd fast float %278, %280
  %282 = call float @dx.op.unary.f32(i32 6, float %279)  ; FAbs(value)
  %283 = call float @dx.op.unary.f32(i32 6, float %281)  ; FAbs(value)
  %284 = call i32 @dx.op.binary.i32(i32 38, i32 %269, i32 0)  ; IMin(a,b)
  %285 = call i32 @dx.op.binary.i32(i32 38, i32 %270, i32 0)  ; IMin(a,b)
  %286 = and i32 %284, 2147483647
  %287 = and i32 %285, 2147483647
  %288 = uitofp i32 %286 to float
  %289 = uitofp i32 %287 to float
  %290 = fsub fast float %288, %101
  %291 = fadd fast float %289, %280
  %292 = call float @dx.op.unary.f32(i32 6, float %290)  ; FAbs(value)
  %293 = call float @dx.op.unary.f32(i32 6, float %291)  ; FAbs(value)
  %294 = fcmp fast olt float %292, %282
  %295 = select i1 %294, i32 %284, i32 %273
  %296 = select i1 %294, float %292, float %282
  %297 = fcmp fast olt float %293, %283
  %298 = select i1 %297, i32 %285, i32 %274
  %299 = select i1 %297, float %293, float %283
  %300 = add i32 %269, 1
  %301 = add i32 %270, 1
  %302 = call i32 @dx.op.binary.i32(i32 38, i32 %300, i32 0)  ; IMin(a,b)
  %303 = call i32 @dx.op.binary.i32(i32 38, i32 %301, i32 0)  ; IMin(a,b)
  %304 = and i32 %302, 2147483647
  %305 = and i32 %303, 2147483647
  %306 = uitofp i32 %304 to float
  %307 = uitofp i32 %305 to float
  %308 = fsub fast float %306, %101
  %309 = fadd fast float %307, %280
  %310 = call float @dx.op.unary.f32(i32 6, float %308)  ; FAbs(value)
  %311 = call float @dx.op.unary.f32(i32 6, float %309)  ; FAbs(value)
  %312 = fcmp fast olt float %310, %296
  %313 = select i1 %312, i32 %302, i32 %295
  %314 = fcmp fast olt float %311, %299
  %315 = select i1 %314, i32 %303, i32 %298
  %316 = and i32 %313, 2147483647
  %317 = and i32 %315, 2147483647
  %318 = uitofp i32 %316 to float
  %319 = uitofp i32 %317 to float
  %320 = fadd fast float %318, 5.000000e-01
  %321 = fadd fast float %319, 5.000000e-01
  %322 = fcmp fast olt float %102, %320
  br i1 %322, label %323, label %326

; <label>:323                                     ; preds = %262
  %324 = add nsw i32 %313, -1
  %325 = call i32 @dx.op.binary.i32(i32 37, i32 %324, i32 0)  ; IMax(a,b)
  br label %329

; <label>:326                                     ; preds = %262
  %327 = add i32 %313, 1
  %328 = call i32 @dx.op.binary.i32(i32 40, i32 %327, i32 0)  ; UMin(a,b)
  br label %329

; <label>:329                                     ; preds = %326, %323
  %330 = phi i32 [ %313, %323 ], [ %328, %326 ]
  %331 = phi i32 [ %325, %323 ], [ %313, %326 ]
  %332 = fcmp fast olt float %103, %321
  br i1 %332, label %333, label %336

; <label>:333                                     ; preds = %329
  %334 = add nsw i32 %315, -1
  %335 = call i32 @dx.op.binary.i32(i32 37, i32 %334, i32 0)  ; IMax(a,b)
  br label %339

; <label>:336                                     ; preds = %329
  %337 = add i32 %315, 1
  %338 = call i32 @dx.op.binary.i32(i32 40, i32 %337, i32 0)  ; UMin(a,b)
  br label %339

; <label>:339                                     ; preds = %336, %333
  %340 = phi i32 [ %315, %333 ], [ %338, %336 ]
  %341 = phi i32 [ %335, %333 ], [ %315, %336 ]
  %342 = and i32 %331, 2147483647
  %343 = and i32 %341, 2147483647
  %344 = uitofp i32 %342 to float
  %345 = uitofp i32 %343 to float
  %346 = fadd fast float %344, 5.000000e-01
  %347 = fadd fast float %345, 5.000000e-01
  %348 = and i32 %330, 2147483647
  %349 = and i32 %340, 2147483647
  %350 = uitofp i32 %348 to float
  %351 = uitofp i32 %349 to float
  %352 = fadd fast float %350, 5.000000e-01
  %353 = fadd fast float %351, 5.000000e-01
  %354 = fcmp fast ogt float %352, %346
  %355 = fsub fast float %102, %346
  %356 = fsub fast float %352, %346
  %357 = fdiv fast float %355, %356
  %358 = call float @dx.op.unary.f32(i32 7, float %357)  ; Saturate(value)
  %359 = select i1 %354, float %358, float 0.000000e+00
  %360 = fcmp fast ogt float %353, %347
  %361 = fsub fast float %103, %347
  %362 = fsub fast float %353, %347
  %363 = fdiv fast float %361, %362
  %364 = call float @dx.op.unary.f32(i32 7, float %363)  ; Saturate(value)
  %365 = select i1 %360, float %364, float 0.000000e+00
  %366 = fsub fast float 1.000000e+00, %359
  %367 = fsub fast float 1.000000e+00, %365
  %368 = fmul fast float %367, %366
  %369 = fcmp fast ugt float %368, 0.000000e+00
  br i1 %369, label %383, label %414

; <label>:370                                     ; preds = %484, %472, %426, %414
  %371 = phi i1 [ true, %414 ], [ false, %426 ], [ true, %472 ], [ false, %484 ]
  %372 = phi i1 [ false, %414 ], [ true, %426 ], [ false, %472 ], [ %474, %484 ]
  %373 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %485, %484 ]
  %374 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %486, %484 ]
  %375 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %487, %484 ]
  %376 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %488, %484 ]
  %377 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %489, %484 ]
  %378 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %490, %484 ]
  %379 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %491, %484 ]
  %380 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %492, %484 ]
  %381 = phi float [ 0.000000e+00, %414 ], [ 0.000000e+00, %426 ], [ 0.000000e+00, %472 ], [ %493, %484 ]
  %382 = or i1 %371, %372
  br i1 %382, label %671, label %507

; <label>:383                                     ; preds = %339
  %384 = icmp ne i32 %331, %174
  %385 = icmp ne i32 %341, %175
  %386 = or i1 %384, %385
  br i1 %386, label %387, label %404

; <label>:387                                     ; preds = %383
  %388 = fmul fast float %346, 2.000000e+00
  %389 = fmul fast float %347, 2.000000e+00
  %390 = fadd fast float %389, -1.000000e+00
  %391 = fsub fast float %185, %388
  %392 = fsub fast float -0.000000e+00, %390
  %393 = call float @dx.op.dot3.f32(i32 55, float %391, float %392, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %394 = call float @dx.op.unary.f32(i32 6, float %393)  ; FAbs(value)
  %395 = fmul fast float %391, %391
  %396 = fmul fast float %390, %390
  %397 = fadd fast float %395, %194
  %398 = fadd fast float %397, %396
  %399 = call float @dx.op.unary.f32(i32 24, float %398)  ; Sqrt(value)
  %400 = fcmp uge float %394, 0x3F8EB851E0000000
  %401 = fcmp uge float %399, 0x3F8EB851E0000000
  %402 = or i1 %401, %400
  %403 = xor i1 %221, true
  br label %404

; <label>:404                                     ; preds = %387, %383
  %405 = phi i1 [ %403, %387 ], [ false, %383 ]
  %406 = phi i1 [ %402, %387 ], [ false, %383 ]
  %407 = fmul fast float %368, %63
  %408 = fmul fast float %368, %64
  %409 = fmul fast float %368, %65
  %410 = fmul fast float %368, %66
  %411 = fmul fast float %368, %67
  %412 = fmul fast float %368, %68
  %413 = fmul fast float %368, %70
  br label %414

; <label>:414                                     ; preds = %404, %339
  %415 = phi i1 [ %405, %404 ], [ false, %339 ]
  %416 = phi i1 [ %406, %404 ], [ false, %339 ]
  %417 = phi float [ %407, %404 ], [ 0.000000e+00, %339 ]
  %418 = phi float [ %408, %404 ], [ 0.000000e+00, %339 ]
  %419 = phi float [ %409, %404 ], [ 0.000000e+00, %339 ]
  %420 = phi float [ %410, %404 ], [ 0.000000e+00, %339 ]
  %421 = phi float [ %411, %404 ], [ 0.000000e+00, %339 ]
  %422 = phi float [ %412, %404 ], [ 0.000000e+00, %339 ]
  %423 = phi float [ %413, %404 ], [ 0.000000e+00, %339 ]
  %424 = phi float [ %368, %404 ], [ 0.000000e+00, %339 ]
  %425 = phi float [ %69, %404 ], [ 0.000000e+00, %339 ]
  br i1 %415, label %370, label %426

; <label>:426                                     ; preds = %414
  br i1 %416, label %370, label %427

; <label>:427                                     ; preds = %426
  %428 = fmul fast float %367, %359
  %429 = fcmp fast ugt float %428, 0.000000e+00
  br i1 %429, label %430, label %472

; <label>:430                                     ; preds = %427
  %431 = icmp ne i32 %330, %174
  %432 = icmp ne i32 %341, %175
  %433 = or i1 %431, %432
  br i1 %433, label %434, label %451

; <label>:434                                     ; preds = %430
  %435 = fmul fast float %352, 2.000000e+00
  %436 = fmul fast float %347, 2.000000e+00
  %437 = fadd fast float %436, -1.000000e+00
  %438 = fsub fast float %185, %435
  %439 = fsub fast float -0.000000e+00, %437
  %440 = call float @dx.op.dot3.f32(i32 55, float %438, float %439, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %441 = call float @dx.op.unary.f32(i32 6, float %440)  ; FAbs(value)
  %442 = fmul fast float %438, %438
  %443 = fmul fast float %437, %437
  %444 = fadd fast float %442, %194
  %445 = fadd fast float %444, %443
  %446 = call float @dx.op.unary.f32(i32 24, float %445)  ; Sqrt(value)
  %447 = fcmp uge float %441, 0x3F8EB851E0000000
  %448 = fcmp uge float %446, 0x3F8EB851E0000000
  %449 = or i1 %448, %447
  %450 = xor i1 %221, true
  br label %451

; <label>:451                                     ; preds = %434, %430
  %452 = phi i1 [ %450, %434 ], [ false, %430 ]
  %453 = phi i1 [ %449, %434 ], [ false, %430 ]
  %454 = fcmp fast oeq float %424, 0.000000e+00
  %455 = call float @dx.op.binary.f32(i32 36, float %425, float %69)  ; FMin(a,b)
  %456 = select i1 %454, float %69, float %455
  %457 = fmul fast float %428, %63
  %458 = fmul fast float %428, %64
  %459 = fmul fast float %428, %65
  %460 = fmul fast float %428, %66
  %461 = fadd fast float %417, %457
  %462 = fadd fast float %418, %458
  %463 = fadd fast float %419, %459
  %464 = fadd fast float %420, %460
  %465 = fmul fast float %428, %67
  %466 = fmul fast float %428, %68
  %467 = fmul fast float %428, %70
  %468 = fadd fast float %421, %465
  %469 = fadd fast float %422, %466
  %470 = fadd fast float %423, %467
  %471 = fadd fast float %424, %428
  br label %472

; <label>:472                                     ; preds = %451, %427
  %473 = phi i1 [ %452, %451 ], [ false, %427 ]
  %474 = phi i1 [ %453, %451 ], [ false, %427 ]
  %475 = phi float [ %461, %451 ], [ %417, %427 ]
  %476 = phi float [ %462, %451 ], [ %418, %427 ]
  %477 = phi float [ %463, %451 ], [ %419, %427 ]
  %478 = phi float [ %464, %451 ], [ %420, %427 ]
  %479 = phi float [ %468, %451 ], [ %421, %427 ]
  %480 = phi float [ %469, %451 ], [ %422, %427 ]
  %481 = phi float [ %470, %451 ], [ %423, %427 ]
  %482 = phi float [ %471, %451 ], [ %424, %427 ]
  %483 = phi float [ %456, %451 ], [ %425, %427 ]
  br i1 %473, label %370, label %484

; <label>:484                                     ; preds = %472
  %485 = select i1 %474, float 0.000000e+00, float %483
  %486 = select i1 %474, float 0.000000e+00, float %482
  %487 = select i1 %474, float 0.000000e+00, float %481
  %488 = select i1 %474, float 0.000000e+00, float %480
  %489 = select i1 %474, float 0.000000e+00, float %479
  %490 = select i1 %474, float 0.000000e+00, float %478
  %491 = select i1 %474, float 0.000000e+00, float %477
  %492 = select i1 %474, float 0.000000e+00, float %476
  %493 = select i1 %474, float 0.000000e+00, float %475
  br label %370

; <label>:494                                     ; preds = %622, %610, %564, %552
  %495 = phi i1 [ true, %552 ], [ false, %564 ], [ true, %610 ], [ false, %622 ]
  %496 = phi i1 [ false, %552 ], [ true, %564 ], [ false, %610 ], [ %612, %622 ]
  %497 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %623, %622 ]
  %498 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %624, %622 ]
  %499 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %625, %622 ]
  %500 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %626, %622 ]
  %501 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %627, %622 ]
  %502 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %628, %622 ]
  %503 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %629, %622 ]
  %504 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %630, %622 ]
  %505 = phi float [ 0.000000e+00, %552 ], [ 0.000000e+00, %564 ], [ 0.000000e+00, %610 ], [ %631, %622 ]
  %506 = or i1 %495, %496
  br i1 %506, label %671, label %632

; <label>:507                                     ; preds = %370
  %508 = fmul fast float %365, %366
  %509 = fcmp fast ugt float %508, 0.000000e+00
  br i1 %509, label %510, label %552

; <label>:510                                     ; preds = %507
  %511 = icmp ne i32 %331, %174
  %512 = icmp ne i32 %340, %175
  %513 = or i1 %511, %512
  br i1 %513, label %514, label %531

; <label>:514                                     ; preds = %510
  %515 = fmul fast float %346, 2.000000e+00
  %516 = fmul fast float %353, 2.000000e+00
  %517 = fadd fast float %516, -1.000000e+00
  %518 = fsub fast float %185, %515
  %519 = fsub fast float -0.000000e+00, %517
  %520 = call float @dx.op.dot3.f32(i32 55, float %518, float %519, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %521 = call float @dx.op.unary.f32(i32 6, float %520)  ; FAbs(value)
  %522 = fmul fast float %518, %518
  %523 = fmul fast float %517, %517
  %524 = fadd fast float %522, %194
  %525 = fadd fast float %524, %523
  %526 = call float @dx.op.unary.f32(i32 24, float %525)  ; Sqrt(value)
  %527 = fcmp uge float %521, 0x3F8EB851E0000000
  %528 = fcmp uge float %526, 0x3F8EB851E0000000
  %529 = or i1 %528, %527
  %530 = xor i1 %221, true
  br label %531

; <label>:531                                     ; preds = %514, %510
  %532 = phi i1 [ %530, %514 ], [ false, %510 ]
  %533 = phi i1 [ %529, %514 ], [ false, %510 ]
  %534 = fcmp fast oeq float %374, 0.000000e+00
  %535 = call float @dx.op.binary.f32(i32 36, float %373, float %69)  ; FMin(a,b)
  %536 = select i1 %534, float %69, float %535
  %537 = fmul fast float %508, %63
  %538 = fmul fast float %508, %64
  %539 = fmul fast float %508, %65
  %540 = fmul fast float %508, %66
  %541 = fadd fast float %381, %537
  %542 = fadd fast float %380, %538
  %543 = fadd fast float %379, %539
  %544 = fadd fast float %378, %540
  %545 = fmul fast float %508, %67
  %546 = fmul fast float %508, %68
  %547 = fmul fast float %508, %70
  %548 = fadd fast float %377, %545
  %549 = fadd fast float %376, %546
  %550 = fadd fast float %375, %547
  %551 = fadd fast float %374, %508
  br label %552

; <label>:552                                     ; preds = %531, %507
  %553 = phi i1 [ %532, %531 ], [ false, %507 ]
  %554 = phi i1 [ %533, %531 ], [ false, %507 ]
  %555 = phi float [ %541, %531 ], [ %381, %507 ]
  %556 = phi float [ %542, %531 ], [ %380, %507 ]
  %557 = phi float [ %543, %531 ], [ %379, %507 ]
  %558 = phi float [ %544, %531 ], [ %378, %507 ]
  %559 = phi float [ %548, %531 ], [ %377, %507 ]
  %560 = phi float [ %549, %531 ], [ %376, %507 ]
  %561 = phi float [ %550, %531 ], [ %375, %507 ]
  %562 = phi float [ %551, %531 ], [ %374, %507 ]
  %563 = phi float [ %536, %531 ], [ %373, %507 ]
  br i1 %553, label %494, label %564

; <label>:564                                     ; preds = %552
  br i1 %554, label %494, label %565

; <label>:565                                     ; preds = %564
  %566 = fmul fast float %365, %359
  %567 = fcmp fast ugt float %566, 0.000000e+00
  br i1 %567, label %568, label %610

; <label>:568                                     ; preds = %565
  %569 = icmp ne i32 %330, %174
  %570 = icmp ne i32 %340, %175
  %571 = or i1 %569, %570
  br i1 %571, label %572, label %589

; <label>:572                                     ; preds = %568
  %573 = fmul fast float %352, 2.000000e+00
  %574 = fmul fast float %353, 2.000000e+00
  %575 = fadd fast float %574, -1.000000e+00
  %576 = fsub fast float %185, %573
  %577 = fsub fast float -0.000000e+00, %575
  %578 = call float @dx.op.dot3.f32(i32 55, float %576, float %577, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %579 = call float @dx.op.unary.f32(i32 6, float %578)  ; FAbs(value)
  %580 = fmul fast float %576, %576
  %581 = fmul fast float %575, %575
  %582 = fadd fast float %580, %194
  %583 = fadd fast float %582, %581
  %584 = call float @dx.op.unary.f32(i32 24, float %583)  ; Sqrt(value)
  %585 = fcmp uge float %579, 0x3F8EB851E0000000
  %586 = fcmp uge float %584, 0x3F8EB851E0000000
  %587 = or i1 %586, %585
  %588 = xor i1 %221, true
  br label %589

; <label>:589                                     ; preds = %572, %568
  %590 = phi i1 [ %588, %572 ], [ false, %568 ]
  %591 = phi i1 [ %587, %572 ], [ false, %568 ]
  %592 = fcmp fast oeq float %562, 0.000000e+00
  %593 = call float @dx.op.binary.f32(i32 36, float %563, float %69)  ; FMin(a,b)
  %594 = select i1 %592, float %69, float %593
  %595 = fmul fast float %566, %63
  %596 = fmul fast float %566, %64
  %597 = fmul fast float %566, %65
  %598 = fmul fast float %566, %66
  %599 = fadd fast float %555, %595
  %600 = fadd fast float %556, %596
  %601 = fadd fast float %557, %597
  %602 = fadd fast float %558, %598
  %603 = fmul fast float %566, %67
  %604 = fmul fast float %566, %68
  %605 = fmul fast float %566, %70
  %606 = fadd fast float %559, %603
  %607 = fadd fast float %560, %604
  %608 = fadd fast float %561, %605
  %609 = fadd fast float %562, %566
  br label %610

; <label>:610                                     ; preds = %589, %565
  %611 = phi i1 [ %590, %589 ], [ false, %565 ]
  %612 = phi i1 [ %591, %589 ], [ false, %565 ]
  %613 = phi float [ %599, %589 ], [ %555, %565 ]
  %614 = phi float [ %600, %589 ], [ %556, %565 ]
  %615 = phi float [ %601, %589 ], [ %557, %565 ]
  %616 = phi float [ %602, %589 ], [ %558, %565 ]
  %617 = phi float [ %606, %589 ], [ %559, %565 ]
  %618 = phi float [ %607, %589 ], [ %560, %565 ]
  %619 = phi float [ %608, %589 ], [ %561, %565 ]
  %620 = phi float [ %609, %589 ], [ %562, %565 ]
  %621 = phi float [ %594, %589 ], [ %563, %565 ]
  br i1 %611, label %494, label %622

; <label>:622                                     ; preds = %610
  %623 = select i1 %612, float 0.000000e+00, float %621
  %624 = select i1 %612, float 0.000000e+00, float %620
  %625 = select i1 %612, float 0.000000e+00, float %619
  %626 = select i1 %612, float 0.000000e+00, float %618
  %627 = select i1 %612, float 0.000000e+00, float %617
  %628 = select i1 %612, float 0.000000e+00, float %616
  %629 = select i1 %612, float 0.000000e+00, float %615
  %630 = select i1 %612, float 0.000000e+00, float %614
  %631 = select i1 %612, float 0.000000e+00, float %613
  br label %494

; <label>:632                                     ; preds = %494
  %633 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %498)  ; IsFinite(value)
  %634 = xor i1 %633, true
  %635 = fcmp fast ole float %498, 0.000000e+00
  %636 = or i1 %635, %634
  br i1 %636, label %671, label %637

; <label>:637                                     ; preds = %632
  %638 = fdiv fast float %505, %498
  %639 = fdiv fast float %504, %498
  %640 = fdiv fast float %503, %498
  %641 = fdiv fast float %502, %498
  %642 = fdiv fast float %501, %498
  %643 = fdiv fast float %500, %498
  %644 = fdiv fast float %499, %498
  %645 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %638)  ; IsFinite(value)
  %646 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %639)  ; IsFinite(value)
  %647 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %640)  ; IsFinite(value)
  %648 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %641)  ; IsFinite(value)
  %649 = and i1 %645, %646
  %650 = and i1 %649, %647
  %651 = and i1 %650, %648
  %652 = fcmp fast ogt float %641, 0.000000e+00
  %653 = and i1 %652, %651
  %654 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %642)  ; IsFinite(value)
  %655 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %643)  ; IsFinite(value)
  %656 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %497)  ; IsFinite(value)
  %657 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %644)  ; IsFinite(value)
  %658 = and i1 %654, %655
  %659 = and i1 %658, %656
  %660 = and i1 %659, %657
  %661 = and i1 %653, %660
  %662 = fcmp fast ogt float %497, 0.000000e+00
  %663 = and i1 %662, %661
  %664 = select i1 %663, float %638, float %63
  %665 = select i1 %663, float %639, float %64
  %666 = select i1 %663, float %640, float %65
  %667 = select i1 %663, float %641, float %66
  %668 = select i1 %663, float %642, float %67
  %669 = select i1 %663, float %643, float %68
  %670 = select i1 %663, float %497, float %69
  br label %671

; <label>:671                                     ; preds = %637, %632, %494, %370
  %672 = phi i1 [ false, %632 ], [ %663, %637 ], [ false, %494 ], [ false, %370 ]
  %673 = phi float [ %63, %632 ], [ %664, %637 ], [ %63, %494 ], [ %63, %370 ]
  %674 = phi float [ %64, %632 ], [ %665, %637 ], [ %64, %494 ], [ %64, %370 ]
  %675 = phi float [ %65, %632 ], [ %666, %637 ], [ %65, %494 ], [ %65, %370 ]
  %676 = phi float [ %66, %632 ], [ %667, %637 ], [ %66, %494 ], [ %66, %370 ]
  %677 = phi float [ %67, %632 ], [ %668, %637 ], [ %67, %494 ], [ %67, %370 ]
  %678 = phi float [ %68, %632 ], [ %669, %637 ], [ %68, %494 ], [ %68, %370 ]
  %679 = phi float [ %69, %632 ], [ %670, %637 ], [ %69, %494 ], [ %69, %370 ]
  %680 = select i1 %672, float %673, float %63
  %681 = select i1 %672, float %674, float %64
  %682 = select i1 %672, float %675, float %65
  %683 = select i1 %672, float %676, float %66
  %684 = select i1 %672, float %677, float %67
  %685 = select i1 %672, float %678, float %68
  %686 = select i1 %672, float %679, float %69
  br label %687

; <label>:687                                     ; preds = %671, %235
  %688 = phi float [ %63, %235 ], [ %680, %671 ]
  %689 = phi float [ %64, %235 ], [ %681, %671 ]
  %690 = phi float [ %65, %235 ], [ %682, %671 ]
  %691 = phi float [ %66, %235 ], [ %683, %671 ]
  %692 = phi float [ %67, %235 ], [ %684, %671 ]
  %693 = phi float [ %68, %235 ], [ %685, %671 ]
  %694 = phi float [ %69, %235 ], [ %686, %671 ]
  %695 = select i1 %237, float %688, float %53
  %696 = select i1 %237, float %689, float %54
  %697 = select i1 %237, float %690, float %55
  %698 = select i1 %237, float %691, float %56
  %699 = select i1 %237, float %692, float %82
  %700 = select i1 %237, float %693, float %85
  br i1 %259, label %714, label %701

; <label>:701                                     ; preds = %687
  %702 = fadd fast float %53, 0x3FA47AE140000000
  %703 = fadd fast float %54, 0x3FA47AE140000000
  %704 = fadd fast float %55, 0x3FA47AE140000000
  %705 = fadd fast float %53, 0xBFA47AE140000000
  %706 = fadd fast float %54, 0xBFA47AE140000000
  %707 = fadd fast float %55, 0xBFA47AE140000000
  %708 = call float @dx.op.binary.f32(i32 35, float %695, float %705)  ; FMax(a,b)
  %709 = call float @dx.op.binary.f32(i32 35, float %696, float %706)  ; FMax(a,b)
  %710 = call float @dx.op.binary.f32(i32 35, float %697, float %707)  ; FMax(a,b)
  %711 = call float @dx.op.binary.f32(i32 36, float %708, float %702)  ; FMin(a,b)
  %712 = call float @dx.op.binary.f32(i32 36, float %709, float %703)  ; FMin(a,b)
  %713 = call float @dx.op.binary.f32(i32 36, float %710, float %704)  ; FMin(a,b)
  br label %714

; <label>:714                                     ; preds = %701, %687
  %715 = phi float [ %695, %687 ], [ %711, %701 ]
  %716 = phi float [ %696, %687 ], [ %712, %701 ]
  %717 = phi float [ %697, %687 ], [ %713, %701 ]
  %718 = fcmp fast ogt float %28, 5.000000e-01
  %719 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %240)  ; FMin(a,b)
  %720 = select i1 %718, float %719, float %240
  %721 = fadd fast float %694, 1.000000e+00
  %722 = select i1 %237, float %721, float 1.000000e+00
  %723 = call float @dx.op.binary.f32(i32 36, float %722, float %720)  ; FMin(a,b)
  %724 = select i1 %237, float %723, float 1.000000e+00
  %725 = fdiv fast float 1.000000e+00, %724
  %726 = call float @dx.op.binary.f32(i32 35, float %40, float %725)  ; FMax(a,b)
  %727 = select i1 %237, float %726, float 1.000000e+00
  %728 = fsub fast float %56, %698
  %729 = call float @dx.op.unary.f32(i32 6, float %728)  ; FAbs(value)
  %730 = fmul fast float %729, 2.500000e-01
  %731 = select i1 %237, float %730, float 1.000000e+00
  %732 = call float @dx.op.binary.f32(i32 35, float %727, float %731)  ; FMax(a,b)
  %733 = fsub fast float %82, %699
  %734 = fsub fast float %85, %700
  %735 = fmul fast float %732, %733
  %736 = fmul fast float %732, %734
  %737 = fadd fast float %735, %699
  %738 = fadd fast float %736, %700
  %739 = fsub fast float %53, %715
  %740 = fsub fast float %54, %716
  %741 = fsub fast float %55, %717
  %742 = fmul fast float %732, %739
  %743 = fmul fast float %732, %740
  %744 = fmul fast float %732, %741
  %745 = fmul fast float %732, %728
  %746 = fadd fast float %742, %715
  %747 = fadd fast float %743, %716
  %748 = fadd fast float %744, %717
  %749 = fadd fast float %745, %698
  %750 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %746)  ; IsFinite(value)
  %751 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %747)  ; IsFinite(value)
  %752 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %748)  ; IsFinite(value)
  %753 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %749)  ; IsFinite(value)
  %754 = and i1 %750, %751
  %755 = and i1 %754, %752
  %756 = and i1 %755, %753
  %757 = fcmp fast ogt float %749, 0.000000e+00
  %758 = and i1 %757, %756
  %759 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %737)  ; IsFinite(value)
  %760 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %738)  ; IsFinite(value)
  %761 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %724)  ; IsFinite(value)
  %762 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %763 = and i1 %759, %760
  %764 = and i1 %763, %761
  %765 = and i1 %764, %762
  %766 = and i1 %758, %765
  %767 = fcmp fast ogt float %724, 0.000000e+00
  %768 = and i1 %767, %766
  %769 = select i1 %768, float %746, float 0.000000e+00
  %770 = select i1 %768, float %747, float 0.000000e+00
  %771 = select i1 %768, float %748, float 0.000000e+00
  %772 = select i1 %768, float %749, float 0.000000e+00
  %773 = select i1 %768, float %737, float 0.000000e+00
  %774 = select i1 %768, float %738, float 0.000000e+00
  %775 = select i1 %768, float %724, float 0.000000e+00
  br label %776

; <label>:776                                     ; preds = %714, %233, %223
  %777 = phi float [ %224, %233 ], [ %224, %223 ], [ %769, %714 ]
  %778 = phi float [ %225, %233 ], [ %225, %223 ], [ %770, %714 ]
  %779 = phi float [ %226, %233 ], [ %226, %223 ], [ %771, %714 ]
  %780 = phi float [ %227, %233 ], [ %227, %223 ], [ %772, %714 ]
  %781 = phi float [ %228, %233 ], [ %228, %223 ], [ %773, %714 ]
  %782 = phi float [ %229, %233 ], [ %229, %223 ], [ %774, %714 ]
  %783 = phi float [ %234, %233 ], [ %230, %223 ], [ %775, %714 ]
  %784 = phi float [ %231, %233 ], [ %231, %223 ], [ 0.000000e+00, %714 ]
  %785 = call i32 @dx.op.legacyF32ToF16(i32 130, float %777)  ; LegacyF32ToF16(value)
  %786 = call i32 @dx.op.legacyF32ToF16(i32 130, float %778)  ; LegacyF32ToF16(value)
  %787 = call i32 @dx.op.legacyF32ToF16(i32 130, float %779)  ; LegacyF32ToF16(value)
  %788 = call i32 @dx.op.legacyF32ToF16(i32 130, float %780)  ; LegacyF32ToF16(value)
  %789 = call float @dx.op.legacyF16ToF32(i32 131, i32 %785)  ; LegacyF16ToF32(value)
  %790 = call float @dx.op.legacyF16ToF32(i32 131, i32 %786)  ; LegacyF16ToF32(value)
  %791 = call float @dx.op.legacyF16ToF32(i32 131, i32 %787)  ; LegacyF16ToF32(value)
  %792 = call float @dx.op.legacyF16ToF32(i32 131, i32 %788)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 0, float %777, float %778, float %779, float %780, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 16, float %781, float %782, float %783, float %784, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 32, float %789, float %790, float %791, float %792, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 48, float %781, float %782, float %783, float %784, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %793 = add nuw nsw i32 %71, 1
  %794 = icmp eq i32 %793, 32
  br i1 %794, label %1517, label %62, !llvm.loop !16

; <label>:795                                     ; preds = %11
  %796 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %53)  ; IsFinite(value)
  %797 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %798 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %799 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %800 = and i1 %796, %797
  %801 = and i1 %800, %798
  %802 = and i1 %801, %799
  %803 = fcmp fast ogt float %56, 0.000000e+00
  %804 = and i1 %803, %802
  %805 = call float @dx.op.dot3.f32(i32 55, float %53, float %54, float %55, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %806 = select i1 %804, float %805, float 0.000000e+00
  %807 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %806)  ; IsFinite(value)
  %808 = and i1 %804, %807
  %809 = fmul fast float %806, %806
  %810 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %809)  ; IsFinite(value)
  %811 = and i1 %808, %810
  %812 = fmul fast float %53, %53
  %813 = fmul fast float %54, %54
  %814 = fmul fast float %55, %55
  %815 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %812)  ; IsFinite(value)
  %816 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %813)  ; IsFinite(value)
  %817 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %814)  ; IsFinite(value)
  %818 = and i1 %815, %816
  %819 = and i1 %818, %817
  %820 = and i1 %811, %819
  %821 = fmul fast float %35, -5.000000e-01
  %822 = icmp ne i32 %57, 0
  %823 = fsub fast float 5.000000e-01, %34
  %824 = fsub fast float -0.000000e+00, %33
  %825 = select i1 %822, float %824, float %821
  %826 = fadd fast float %825, 5.000000e-01
  %827 = select i1 %822, float %823, float 5.000000e-01
  %828 = icmp ne i32 %58, 0
  %829 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %830 = and i1 %828, %829
  %831 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %826)  ; IsFinite(value)
  %832 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %827)  ; IsFinite(value)
  %833 = and i1 %831, %832
  %834 = and i1 %830, %833
  %835 = fcmp fast ogt float %826, 0.000000e+00
  %836 = fcmp fast ogt float %827, 0.000000e+00
  %837 = and i1 %836, %835
  %838 = and i1 %837, %834
  %839 = fcmp fast olt float %826, 1.000000e+00
  %840 = fcmp fast olt float %827, 1.000000e+00
  %841 = and i1 %840, %839
  %842 = and i1 %841, %838
  br i1 %842, label %843, label %897

; <label>:843                                     ; preds = %795
  %844 = call float @dx.op.unary.f32(i32 27, float %826)  ; Round_ni(value)
  %845 = call float @dx.op.unary.f32(i32 27, float %827)  ; Round_ni(value)
  %846 = fptosi float %844 to i32
  %847 = fptosi float %845 to i32
  %848 = call i32 @dx.op.binary.i32(i32 37, i32 %846, i32 0)  ; IMax(a,b)
  %849 = call i32 @dx.op.binary.i32(i32 37, i32 %847, i32 0)  ; IMax(a,b)
  %850 = call i32 @dx.op.binary.i32(i32 38, i32 %848, i32 0)  ; IMin(a,b)
  %851 = call i32 @dx.op.binary.i32(i32 38, i32 %849, i32 0)  ; IMin(a,b)
  %852 = add i32 %850, -1
  %853 = add i32 %851, -1
  %854 = call i32 @dx.op.binary.i32(i32 37, i32 %852, i32 0)  ; IMax(a,b)
  %855 = call i32 @dx.op.binary.i32(i32 37, i32 %853, i32 0)  ; IMax(a,b)
  %856 = and i32 %854, 2147483647
  %857 = and i32 %855, 2147483647
  %858 = uitofp i32 %856 to float
  %859 = uitofp i32 %857 to float
  %860 = fsub fast float %858, %825
  %861 = fsub fast float 5.000000e-01, %827
  %862 = fadd fast float %859, %861
  %863 = call float @dx.op.unary.f32(i32 6, float %860)  ; FAbs(value)
  %864 = call float @dx.op.unary.f32(i32 6, float %862)  ; FAbs(value)
  %865 = call i32 @dx.op.binary.i32(i32 38, i32 %850, i32 0)  ; IMin(a,b)
  %866 = call i32 @dx.op.binary.i32(i32 38, i32 %851, i32 0)  ; IMin(a,b)
  %867 = and i32 %865, 2147483647
  %868 = and i32 %866, 2147483647
  %869 = uitofp i32 %867 to float
  %870 = uitofp i32 %868 to float
  %871 = fsub fast float %869, %825
  %872 = fadd fast float %870, %861
  %873 = call float @dx.op.unary.f32(i32 6, float %871)  ; FAbs(value)
  %874 = call float @dx.op.unary.f32(i32 6, float %872)  ; FAbs(value)
  %875 = fcmp fast olt float %873, %863
  %876 = select i1 %875, i32 %865, i32 %854
  %877 = select i1 %875, float %873, float %863
  %878 = fcmp fast olt float %874, %864
  %879 = select i1 %878, i32 %866, i32 %855
  %880 = select i1 %878, float %874, float %864
  %881 = add i32 %850, 1
  %882 = add i32 %851, 1
  %883 = call i32 @dx.op.binary.i32(i32 38, i32 %881, i32 0)  ; IMin(a,b)
  %884 = call i32 @dx.op.binary.i32(i32 38, i32 %882, i32 0)  ; IMin(a,b)
  %885 = and i32 %883, 2147483647
  %886 = and i32 %884, 2147483647
  %887 = uitofp i32 %885 to float
  %888 = uitofp i32 %886 to float
  %889 = fsub fast float %887, %825
  %890 = fadd fast float %888, %861
  %891 = call float @dx.op.unary.f32(i32 6, float %889)  ; FAbs(value)
  %892 = call float @dx.op.unary.f32(i32 6, float %890)  ; FAbs(value)
  %893 = fcmp fast olt float %891, %877
  %894 = select i1 %893, i32 %883, i32 %876
  %895 = fcmp fast olt float %892, %880
  %896 = select i1 %895, i32 %884, i32 %879
  br label %897

; <label>:897                                     ; preds = %843, %795
  %898 = phi i32 [ 0, %795 ], [ %894, %843 ]
  %899 = phi i32 [ 0, %795 ], [ %896, %843 ]
  %900 = and i32 %898, 2147483647
  %901 = and i32 %899, 2147483647
  %902 = uitofp i32 %900 to float
  %903 = uitofp i32 %901 to float
  %904 = fadd fast float %902, 5.000000e-01
  %905 = fadd fast float %903, 5.000000e-01
  %906 = fmul fast float %904, 2.000000e+00
  %907 = fmul fast float %905, 2.000000e+00
  %908 = fadd fast float %907, -1.000000e+00
  %909 = fsub fast float 1.000000e+00, %35
  %910 = fsub fast float %909, %906
  %911 = fsub fast float -0.000000e+00, %908
  %912 = fsub fast float 5.000000e-01, %36
  %913 = call float @dx.op.dot3.f32(i32 55, float %910, float %911, float %912, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %914 = call float @dx.op.unary.f32(i32 6, float %913)  ; FAbs(value)
  %915 = fcmp fast olt float %914, 0x3F8EB851E0000000
  %916 = fmul fast float %910, %910
  %917 = fmul fast float %908, %908
  %918 = fmul fast float %912, %912
  %919 = fadd fast float %916, %918
  %920 = fadd fast float %919, %917
  %921 = call float @dx.op.unary.f32(i32 24, float %920)  ; Sqrt(value)
  %922 = fcmp fast olt float %921, 0x3F8EB851E0000000
  %923 = and i1 %915, %922
  %924 = and i1 %842, %923
  %925 = fcmp fast olt float %29, 5.000000e-01
  %926 = and i1 %925, %924
  %927 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %45)  ; IsFinite(value)
  %928 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %46)  ; IsFinite(value)
  %929 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %47)  ; IsFinite(value)
  %930 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %48)  ; IsFinite(value)
  %931 = and i1 %927, %928
  %932 = and i1 %931, %929
  %933 = and i1 %932, %930
  %934 = fcmp fast ogt float %48, 0.000000e+00
  %935 = and i1 %934, %933
  %936 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %937 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %19)  ; IsFinite(value)
  %938 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %20)  ; IsFinite(value)
  %939 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %21)  ; IsFinite(value)
  %940 = and i1 %936, %937
  %941 = and i1 %940, %938
  %942 = and i1 %941, %939
  %943 = and i1 %935, %942
  %944 = fcmp fast ogt float %20, 0.000000e+00
  %945 = and i1 %944, %943
  %946 = and i1 %926, %945
  br i1 %820, label %959, label %947

; <label>:947                                     ; preds = %897
  %948 = select i1 %946, float %45, float 0.000000e+00
  %949 = select i1 %946, float %46, float 0.000000e+00
  %950 = select i1 %946, float %47, float 0.000000e+00
  %951 = select i1 %946, float %48, float 0.000000e+00
  %952 = select i1 %946, float %18, float 0.000000e+00
  %953 = select i1 %946, float %19, float 0.000000e+00
  %954 = select i1 %946, float %20, float 0.000000e+00
  %955 = select i1 %946, float %21, float 0.000000e+00
  %956 = fcmp fast ogt float %28, 5.000000e-01
  br i1 %956, label %957, label %1500

; <label>:957                                     ; preds = %947
  %958 = call float @dx.op.binary.f32(i32 36, float %954, float 2.000000e+00)  ; FMin(a,b)
  br label %1500

; <label>:959                                     ; preds = %897
  %960 = fcmp ule float %30, 5.000000e-01
  %961 = and i1 %946, %960
  %962 = fcmp fast olt float %28, 5.000000e-01
  %963 = and i1 %962, %961
  %964 = sitofp i32 %59 to float
  %965 = fcmp fast oge float %20, %964
  %966 = and i1 %965, %963
  %967 = or i32 %899, %898
  %968 = icmp eq i32 %967, 0
  %969 = and i1 %968, %966
  %970 = fcmp fast oeq float %826, 5.000000e-01
  %971 = fcmp fast oeq float %827, 5.000000e-01
  %972 = and i1 %971, %970
  %973 = and i1 %972, %969
  %974 = icmp eq i32 %57, 0
  %975 = fcmp fast oeq float %33, 0.000000e+00
  %976 = fcmp fast oeq float %34, 0.000000e+00
  %977 = and i1 %975, %976
  %978 = or i1 %974, %977
  %979 = and i1 %978, %973
  %980 = fcmp fast oeq float %35, 0.000000e+00
  %981 = and i1 %980, %979
  %982 = fcmp fast oeq float %36, 5.000000e-01
  %983 = and i1 %982, %981
  %984 = xor i1 %983, true
  %985 = and i1 %961, %984
  br i1 %985, label %986, label %1411

; <label>:986                                     ; preds = %959
  %987 = call float @dx.op.unary.f32(i32 27, float %826)  ; Round_ni(value)
  %988 = call float @dx.op.unary.f32(i32 27, float %827)  ; Round_ni(value)
  %989 = fptosi float %987 to i32
  %990 = fptosi float %988 to i32
  %991 = call i32 @dx.op.binary.i32(i32 37, i32 %989, i32 0)  ; IMax(a,b)
  %992 = call i32 @dx.op.binary.i32(i32 37, i32 %990, i32 0)  ; IMax(a,b)
  %993 = call i32 @dx.op.binary.i32(i32 38, i32 %991, i32 0)  ; IMin(a,b)
  %994 = call i32 @dx.op.binary.i32(i32 38, i32 %992, i32 0)  ; IMin(a,b)
  %995 = add i32 %993, -1
  %996 = add i32 %994, -1
  %997 = call i32 @dx.op.binary.i32(i32 37, i32 %995, i32 0)  ; IMax(a,b)
  %998 = call i32 @dx.op.binary.i32(i32 37, i32 %996, i32 0)  ; IMax(a,b)
  %999 = and i32 %997, 2147483647
  %1000 = and i32 %998, 2147483647
  %1001 = uitofp i32 %999 to float
  %1002 = uitofp i32 %1000 to float
  %1003 = fsub fast float %1001, %825
  %1004 = fsub fast float 5.000000e-01, %827
  %1005 = fadd fast float %1002, %1004
  %1006 = call float @dx.op.unary.f32(i32 6, float %1003)  ; FAbs(value)
  %1007 = call float @dx.op.unary.f32(i32 6, float %1005)  ; FAbs(value)
  %1008 = call i32 @dx.op.binary.i32(i32 38, i32 %993, i32 0)  ; IMin(a,b)
  %1009 = call i32 @dx.op.binary.i32(i32 38, i32 %994, i32 0)  ; IMin(a,b)
  %1010 = and i32 %1008, 2147483647
  %1011 = and i32 %1009, 2147483647
  %1012 = uitofp i32 %1010 to float
  %1013 = uitofp i32 %1011 to float
  %1014 = fsub fast float %1012, %825
  %1015 = fadd fast float %1013, %1004
  %1016 = call float @dx.op.unary.f32(i32 6, float %1014)  ; FAbs(value)
  %1017 = call float @dx.op.unary.f32(i32 6, float %1015)  ; FAbs(value)
  %1018 = fcmp fast olt float %1016, %1006
  %1019 = select i1 %1018, i32 %1008, i32 %997
  %1020 = select i1 %1018, float %1016, float %1006
  %1021 = fcmp fast olt float %1017, %1007
  %1022 = select i1 %1021, i32 %1009, i32 %998
  %1023 = select i1 %1021, float %1017, float %1007
  %1024 = add i32 %993, 1
  %1025 = add i32 %994, 1
  %1026 = call i32 @dx.op.binary.i32(i32 38, i32 %1024, i32 0)  ; IMin(a,b)
  %1027 = call i32 @dx.op.binary.i32(i32 38, i32 %1025, i32 0)  ; IMin(a,b)
  %1028 = and i32 %1026, 2147483647
  %1029 = and i32 %1027, 2147483647
  %1030 = uitofp i32 %1028 to float
  %1031 = uitofp i32 %1029 to float
  %1032 = fsub fast float %1030, %825
  %1033 = fadd fast float %1031, %1004
  %1034 = call float @dx.op.unary.f32(i32 6, float %1032)  ; FAbs(value)
  %1035 = call float @dx.op.unary.f32(i32 6, float %1033)  ; FAbs(value)
  %1036 = fcmp fast olt float %1034, %1020
  %1037 = select i1 %1036, i32 %1026, i32 %1019
  %1038 = fcmp fast olt float %1035, %1023
  %1039 = select i1 %1038, i32 %1027, i32 %1022
  %1040 = and i32 %1037, 2147483647
  %1041 = and i32 %1039, 2147483647
  %1042 = uitofp i32 %1040 to float
  %1043 = uitofp i32 %1041 to float
  %1044 = fadd fast float %1042, 5.000000e-01
  %1045 = fadd fast float %1043, 5.000000e-01
  %1046 = fcmp fast olt float %826, %1044
  br i1 %1046, label %1047, label %1050

; <label>:1047                                    ; preds = %986
  %1048 = add nsw i32 %1037, -1
  %1049 = call i32 @dx.op.binary.i32(i32 37, i32 %1048, i32 0)  ; IMax(a,b)
  br label %1053

; <label>:1050                                    ; preds = %986
  %1051 = add i32 %1037, 1
  %1052 = call i32 @dx.op.binary.i32(i32 40, i32 %1051, i32 0)  ; UMin(a,b)
  br label %1053

; <label>:1053                                    ; preds = %1050, %1047
  %1054 = phi i32 [ %1037, %1047 ], [ %1052, %1050 ]
  %1055 = phi i32 [ %1049, %1047 ], [ %1037, %1050 ]
  %1056 = fcmp fast olt float %827, %1045
  br i1 %1056, label %1057, label %1060

; <label>:1057                                    ; preds = %1053
  %1058 = add nsw i32 %1039, -1
  %1059 = call i32 @dx.op.binary.i32(i32 37, i32 %1058, i32 0)  ; IMax(a,b)
  br label %1063

; <label>:1060                                    ; preds = %1053
  %1061 = add i32 %1039, 1
  %1062 = call i32 @dx.op.binary.i32(i32 40, i32 %1061, i32 0)  ; UMin(a,b)
  br label %1063

; <label>:1063                                    ; preds = %1060, %1057
  %1064 = phi i32 [ %1039, %1057 ], [ %1062, %1060 ]
  %1065 = phi i32 [ %1059, %1057 ], [ %1039, %1060 ]
  %1066 = and i32 %1055, 2147483647
  %1067 = and i32 %1065, 2147483647
  %1068 = uitofp i32 %1066 to float
  %1069 = uitofp i32 %1067 to float
  %1070 = fadd fast float %1068, 5.000000e-01
  %1071 = fadd fast float %1069, 5.000000e-01
  %1072 = and i32 %1054, 2147483647
  %1073 = and i32 %1064, 2147483647
  %1074 = uitofp i32 %1072 to float
  %1075 = uitofp i32 %1073 to float
  %1076 = fadd fast float %1074, 5.000000e-01
  %1077 = fadd fast float %1075, 5.000000e-01
  %1078 = fcmp fast ogt float %1076, %1070
  %1079 = fsub fast float %826, %1070
  %1080 = fsub fast float %1076, %1070
  %1081 = fdiv fast float %1079, %1080
  %1082 = call float @dx.op.unary.f32(i32 7, float %1081)  ; Saturate(value)
  %1083 = select i1 %1078, float %1082, float 0.000000e+00
  %1084 = fcmp fast ogt float %1077, %1071
  %1085 = fsub fast float %827, %1071
  %1086 = fsub fast float %1077, %1071
  %1087 = fdiv fast float %1085, %1086
  %1088 = call float @dx.op.unary.f32(i32 7, float %1087)  ; Saturate(value)
  %1089 = select i1 %1084, float %1088, float 0.000000e+00
  %1090 = fsub fast float 1.000000e+00, %1083
  %1091 = fsub fast float 1.000000e+00, %1089
  %1092 = fmul fast float %1091, %1090
  %1093 = fcmp fast ugt float %1092, 0.000000e+00
  br i1 %1093, label %1107, label %1138

; <label>:1094                                    ; preds = %1208, %1196, %1150, %1138
  %1095 = phi i1 [ true, %1138 ], [ false, %1150 ], [ true, %1196 ], [ false, %1208 ]
  %1096 = phi i1 [ false, %1138 ], [ true, %1150 ], [ false, %1196 ], [ %1198, %1208 ]
  %1097 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1209, %1208 ]
  %1098 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1210, %1208 ]
  %1099 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1211, %1208 ]
  %1100 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1212, %1208 ]
  %1101 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1213, %1208 ]
  %1102 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1214, %1208 ]
  %1103 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1215, %1208 ]
  %1104 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1216, %1208 ]
  %1105 = phi float [ 0.000000e+00, %1138 ], [ 0.000000e+00, %1150 ], [ 0.000000e+00, %1196 ], [ %1217, %1208 ]
  %1106 = or i1 %1095, %1096
  br i1 %1106, label %1395, label %1231

; <label>:1107                                    ; preds = %1063
  %1108 = icmp ne i32 %1055, %898
  %1109 = icmp ne i32 %1065, %899
  %1110 = or i1 %1108, %1109
  br i1 %1110, label %1111, label %1128

; <label>:1111                                    ; preds = %1107
  %1112 = fmul fast float %1070, 2.000000e+00
  %1113 = fmul fast float %1071, 2.000000e+00
  %1114 = fadd fast float %1113, -1.000000e+00
  %1115 = fsub fast float %909, %1112
  %1116 = fsub fast float -0.000000e+00, %1114
  %1117 = call float @dx.op.dot3.f32(i32 55, float %1115, float %1116, float %912, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1118 = call float @dx.op.unary.f32(i32 6, float %1117)  ; FAbs(value)
  %1119 = fmul fast float %1115, %1115
  %1120 = fmul fast float %1114, %1114
  %1121 = fadd fast float %1119, %918
  %1122 = fadd fast float %1121, %1120
  %1123 = call float @dx.op.unary.f32(i32 24, float %1122)  ; Sqrt(value)
  %1124 = fcmp uge float %1118, 0x3F8EB851E0000000
  %1125 = fcmp uge float %1123, 0x3F8EB851E0000000
  %1126 = or i1 %1125, %1124
  %1127 = xor i1 %945, true
  br label %1128

; <label>:1128                                    ; preds = %1111, %1107
  %1129 = phi i1 [ %1127, %1111 ], [ false, %1107 ]
  %1130 = phi i1 [ %1126, %1111 ], [ false, %1107 ]
  %1131 = fmul fast float %1092, %45
  %1132 = fmul fast float %1092, %46
  %1133 = fmul fast float %1092, %47
  %1134 = fmul fast float %1092, %48
  %1135 = fmul fast float %1092, %18
  %1136 = fmul fast float %1092, %19
  %1137 = fmul fast float %1092, %21
  br label %1138

; <label>:1138                                    ; preds = %1128, %1063
  %1139 = phi i1 [ %1129, %1128 ], [ false, %1063 ]
  %1140 = phi i1 [ %1130, %1128 ], [ false, %1063 ]
  %1141 = phi float [ %1131, %1128 ], [ 0.000000e+00, %1063 ]
  %1142 = phi float [ %1132, %1128 ], [ 0.000000e+00, %1063 ]
  %1143 = phi float [ %1133, %1128 ], [ 0.000000e+00, %1063 ]
  %1144 = phi float [ %1134, %1128 ], [ 0.000000e+00, %1063 ]
  %1145 = phi float [ %1135, %1128 ], [ 0.000000e+00, %1063 ]
  %1146 = phi float [ %1136, %1128 ], [ 0.000000e+00, %1063 ]
  %1147 = phi float [ %1137, %1128 ], [ 0.000000e+00, %1063 ]
  %1148 = phi float [ %1092, %1128 ], [ 0.000000e+00, %1063 ]
  %1149 = phi float [ %20, %1128 ], [ 0.000000e+00, %1063 ]
  br i1 %1139, label %1094, label %1150

; <label>:1150                                    ; preds = %1138
  br i1 %1140, label %1094, label %1151

; <label>:1151                                    ; preds = %1150
  %1152 = fmul fast float %1091, %1083
  %1153 = fcmp fast ugt float %1152, 0.000000e+00
  br i1 %1153, label %1154, label %1196

; <label>:1154                                    ; preds = %1151
  %1155 = icmp ne i32 %1054, %898
  %1156 = icmp ne i32 %1065, %899
  %1157 = or i1 %1155, %1156
  br i1 %1157, label %1158, label %1175

; <label>:1158                                    ; preds = %1154
  %1159 = fmul fast float %1076, 2.000000e+00
  %1160 = fmul fast float %1071, 2.000000e+00
  %1161 = fadd fast float %1160, -1.000000e+00
  %1162 = fsub fast float %909, %1159
  %1163 = fsub fast float -0.000000e+00, %1161
  %1164 = call float @dx.op.dot3.f32(i32 55, float %1162, float %1163, float %912, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1165 = call float @dx.op.unary.f32(i32 6, float %1164)  ; FAbs(value)
  %1166 = fmul fast float %1162, %1162
  %1167 = fmul fast float %1161, %1161
  %1168 = fadd fast float %1166, %918
  %1169 = fadd fast float %1168, %1167
  %1170 = call float @dx.op.unary.f32(i32 24, float %1169)  ; Sqrt(value)
  %1171 = fcmp uge float %1165, 0x3F8EB851E0000000
  %1172 = fcmp uge float %1170, 0x3F8EB851E0000000
  %1173 = or i1 %1172, %1171
  %1174 = xor i1 %945, true
  br label %1175

; <label>:1175                                    ; preds = %1158, %1154
  %1176 = phi i1 [ %1174, %1158 ], [ false, %1154 ]
  %1177 = phi i1 [ %1173, %1158 ], [ false, %1154 ]
  %1178 = fcmp fast oeq float %1148, 0.000000e+00
  %1179 = call float @dx.op.binary.f32(i32 36, float %1149, float %20)  ; FMin(a,b)
  %1180 = select i1 %1178, float %20, float %1179
  %1181 = fmul fast float %1152, %45
  %1182 = fmul fast float %1152, %46
  %1183 = fmul fast float %1152, %47
  %1184 = fmul fast float %1152, %48
  %1185 = fadd fast float %1141, %1181
  %1186 = fadd fast float %1142, %1182
  %1187 = fadd fast float %1143, %1183
  %1188 = fadd fast float %1144, %1184
  %1189 = fmul fast float %1152, %18
  %1190 = fmul fast float %1152, %19
  %1191 = fmul fast float %1152, %21
  %1192 = fadd fast float %1145, %1189
  %1193 = fadd fast float %1146, %1190
  %1194 = fadd fast float %1147, %1191
  %1195 = fadd fast float %1148, %1152
  br label %1196

; <label>:1196                                    ; preds = %1175, %1151
  %1197 = phi i1 [ %1176, %1175 ], [ false, %1151 ]
  %1198 = phi i1 [ %1177, %1175 ], [ false, %1151 ]
  %1199 = phi float [ %1185, %1175 ], [ %1141, %1151 ]
  %1200 = phi float [ %1186, %1175 ], [ %1142, %1151 ]
  %1201 = phi float [ %1187, %1175 ], [ %1143, %1151 ]
  %1202 = phi float [ %1188, %1175 ], [ %1144, %1151 ]
  %1203 = phi float [ %1192, %1175 ], [ %1145, %1151 ]
  %1204 = phi float [ %1193, %1175 ], [ %1146, %1151 ]
  %1205 = phi float [ %1194, %1175 ], [ %1147, %1151 ]
  %1206 = phi float [ %1195, %1175 ], [ %1148, %1151 ]
  %1207 = phi float [ %1180, %1175 ], [ %1149, %1151 ]
  br i1 %1197, label %1094, label %1208

; <label>:1208                                    ; preds = %1196
  %1209 = select i1 %1198, float 0.000000e+00, float %1207
  %1210 = select i1 %1198, float 0.000000e+00, float %1206
  %1211 = select i1 %1198, float 0.000000e+00, float %1205
  %1212 = select i1 %1198, float 0.000000e+00, float %1204
  %1213 = select i1 %1198, float 0.000000e+00, float %1203
  %1214 = select i1 %1198, float 0.000000e+00, float %1202
  %1215 = select i1 %1198, float 0.000000e+00, float %1201
  %1216 = select i1 %1198, float 0.000000e+00, float %1200
  %1217 = select i1 %1198, float 0.000000e+00, float %1199
  br label %1094

; <label>:1218                                    ; preds = %1346, %1334, %1288, %1276
  %1219 = phi i1 [ true, %1276 ], [ false, %1288 ], [ true, %1334 ], [ false, %1346 ]
  %1220 = phi i1 [ false, %1276 ], [ true, %1288 ], [ false, %1334 ], [ %1336, %1346 ]
  %1221 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1347, %1346 ]
  %1222 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1348, %1346 ]
  %1223 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1349, %1346 ]
  %1224 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1350, %1346 ]
  %1225 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1351, %1346 ]
  %1226 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1352, %1346 ]
  %1227 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1353, %1346 ]
  %1228 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1354, %1346 ]
  %1229 = phi float [ 0.000000e+00, %1276 ], [ 0.000000e+00, %1288 ], [ 0.000000e+00, %1334 ], [ %1355, %1346 ]
  %1230 = or i1 %1219, %1220
  br i1 %1230, label %1395, label %1356

; <label>:1231                                    ; preds = %1094
  %1232 = fmul fast float %1089, %1090
  %1233 = fcmp fast ugt float %1232, 0.000000e+00
  br i1 %1233, label %1234, label %1276

; <label>:1234                                    ; preds = %1231
  %1235 = icmp ne i32 %1055, %898
  %1236 = icmp ne i32 %1064, %899
  %1237 = or i1 %1235, %1236
  br i1 %1237, label %1238, label %1255

; <label>:1238                                    ; preds = %1234
  %1239 = fmul fast float %1070, 2.000000e+00
  %1240 = fmul fast float %1077, 2.000000e+00
  %1241 = fadd fast float %1240, -1.000000e+00
  %1242 = fsub fast float %909, %1239
  %1243 = fsub fast float -0.000000e+00, %1241
  %1244 = call float @dx.op.dot3.f32(i32 55, float %1242, float %1243, float %912, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1245 = call float @dx.op.unary.f32(i32 6, float %1244)  ; FAbs(value)
  %1246 = fmul fast float %1242, %1242
  %1247 = fmul fast float %1241, %1241
  %1248 = fadd fast float %1246, %918
  %1249 = fadd fast float %1248, %1247
  %1250 = call float @dx.op.unary.f32(i32 24, float %1249)  ; Sqrt(value)
  %1251 = fcmp uge float %1245, 0x3F8EB851E0000000
  %1252 = fcmp uge float %1250, 0x3F8EB851E0000000
  %1253 = or i1 %1252, %1251
  %1254 = xor i1 %945, true
  br label %1255

; <label>:1255                                    ; preds = %1238, %1234
  %1256 = phi i1 [ %1254, %1238 ], [ false, %1234 ]
  %1257 = phi i1 [ %1253, %1238 ], [ false, %1234 ]
  %1258 = fcmp fast oeq float %1098, 0.000000e+00
  %1259 = call float @dx.op.binary.f32(i32 36, float %1097, float %20)  ; FMin(a,b)
  %1260 = select i1 %1258, float %20, float %1259
  %1261 = fmul fast float %1232, %45
  %1262 = fmul fast float %1232, %46
  %1263 = fmul fast float %1232, %47
  %1264 = fmul fast float %1232, %48
  %1265 = fadd fast float %1105, %1261
  %1266 = fadd fast float %1104, %1262
  %1267 = fadd fast float %1103, %1263
  %1268 = fadd fast float %1102, %1264
  %1269 = fmul fast float %1232, %18
  %1270 = fmul fast float %1232, %19
  %1271 = fmul fast float %1232, %21
  %1272 = fadd fast float %1101, %1269
  %1273 = fadd fast float %1100, %1270
  %1274 = fadd fast float %1099, %1271
  %1275 = fadd fast float %1098, %1232
  br label %1276

; <label>:1276                                    ; preds = %1255, %1231
  %1277 = phi i1 [ %1256, %1255 ], [ false, %1231 ]
  %1278 = phi i1 [ %1257, %1255 ], [ false, %1231 ]
  %1279 = phi float [ %1265, %1255 ], [ %1105, %1231 ]
  %1280 = phi float [ %1266, %1255 ], [ %1104, %1231 ]
  %1281 = phi float [ %1267, %1255 ], [ %1103, %1231 ]
  %1282 = phi float [ %1268, %1255 ], [ %1102, %1231 ]
  %1283 = phi float [ %1272, %1255 ], [ %1101, %1231 ]
  %1284 = phi float [ %1273, %1255 ], [ %1100, %1231 ]
  %1285 = phi float [ %1274, %1255 ], [ %1099, %1231 ]
  %1286 = phi float [ %1275, %1255 ], [ %1098, %1231 ]
  %1287 = phi float [ %1260, %1255 ], [ %1097, %1231 ]
  br i1 %1277, label %1218, label %1288

; <label>:1288                                    ; preds = %1276
  br i1 %1278, label %1218, label %1289

; <label>:1289                                    ; preds = %1288
  %1290 = fmul fast float %1089, %1083
  %1291 = fcmp fast ugt float %1290, 0.000000e+00
  br i1 %1291, label %1292, label %1334

; <label>:1292                                    ; preds = %1289
  %1293 = icmp ne i32 %1054, %898
  %1294 = icmp ne i32 %1064, %899
  %1295 = or i1 %1293, %1294
  br i1 %1295, label %1296, label %1313

; <label>:1296                                    ; preds = %1292
  %1297 = fmul fast float %1076, 2.000000e+00
  %1298 = fmul fast float %1077, 2.000000e+00
  %1299 = fadd fast float %1298, -1.000000e+00
  %1300 = fsub fast float %909, %1297
  %1301 = fsub fast float -0.000000e+00, %1299
  %1302 = call float @dx.op.dot3.f32(i32 55, float %1300, float %1301, float %912, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1303 = call float @dx.op.unary.f32(i32 6, float %1302)  ; FAbs(value)
  %1304 = fmul fast float %1300, %1300
  %1305 = fmul fast float %1299, %1299
  %1306 = fadd fast float %1304, %918
  %1307 = fadd fast float %1306, %1305
  %1308 = call float @dx.op.unary.f32(i32 24, float %1307)  ; Sqrt(value)
  %1309 = fcmp uge float %1303, 0x3F8EB851E0000000
  %1310 = fcmp uge float %1308, 0x3F8EB851E0000000
  %1311 = or i1 %1310, %1309
  %1312 = xor i1 %945, true
  br label %1313

; <label>:1313                                    ; preds = %1296, %1292
  %1314 = phi i1 [ %1312, %1296 ], [ false, %1292 ]
  %1315 = phi i1 [ %1311, %1296 ], [ false, %1292 ]
  %1316 = fcmp fast oeq float %1286, 0.000000e+00
  %1317 = call float @dx.op.binary.f32(i32 36, float %1287, float %20)  ; FMin(a,b)
  %1318 = select i1 %1316, float %20, float %1317
  %1319 = fmul fast float %1290, %45
  %1320 = fmul fast float %1290, %46
  %1321 = fmul fast float %1290, %47
  %1322 = fmul fast float %1290, %48
  %1323 = fadd fast float %1279, %1319
  %1324 = fadd fast float %1280, %1320
  %1325 = fadd fast float %1281, %1321
  %1326 = fadd fast float %1282, %1322
  %1327 = fmul fast float %1290, %18
  %1328 = fmul fast float %1290, %19
  %1329 = fmul fast float %1290, %21
  %1330 = fadd fast float %1283, %1327
  %1331 = fadd fast float %1284, %1328
  %1332 = fadd fast float %1285, %1329
  %1333 = fadd fast float %1286, %1290
  br label %1334

; <label>:1334                                    ; preds = %1313, %1289
  %1335 = phi i1 [ %1314, %1313 ], [ false, %1289 ]
  %1336 = phi i1 [ %1315, %1313 ], [ false, %1289 ]
  %1337 = phi float [ %1323, %1313 ], [ %1279, %1289 ]
  %1338 = phi float [ %1324, %1313 ], [ %1280, %1289 ]
  %1339 = phi float [ %1325, %1313 ], [ %1281, %1289 ]
  %1340 = phi float [ %1326, %1313 ], [ %1282, %1289 ]
  %1341 = phi float [ %1330, %1313 ], [ %1283, %1289 ]
  %1342 = phi float [ %1331, %1313 ], [ %1284, %1289 ]
  %1343 = phi float [ %1332, %1313 ], [ %1285, %1289 ]
  %1344 = phi float [ %1333, %1313 ], [ %1286, %1289 ]
  %1345 = phi float [ %1318, %1313 ], [ %1287, %1289 ]
  br i1 %1335, label %1218, label %1346

; <label>:1346                                    ; preds = %1334
  %1347 = select i1 %1336, float 0.000000e+00, float %1345
  %1348 = select i1 %1336, float 0.000000e+00, float %1344
  %1349 = select i1 %1336, float 0.000000e+00, float %1343
  %1350 = select i1 %1336, float 0.000000e+00, float %1342
  %1351 = select i1 %1336, float 0.000000e+00, float %1341
  %1352 = select i1 %1336, float 0.000000e+00, float %1340
  %1353 = select i1 %1336, float 0.000000e+00, float %1339
  %1354 = select i1 %1336, float 0.000000e+00, float %1338
  %1355 = select i1 %1336, float 0.000000e+00, float %1337
  br label %1218

; <label>:1356                                    ; preds = %1218
  %1357 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1222)  ; IsFinite(value)
  %1358 = xor i1 %1357, true
  %1359 = fcmp fast ole float %1222, 0.000000e+00
  %1360 = or i1 %1359, %1358
  br i1 %1360, label %1395, label %1361

; <label>:1361                                    ; preds = %1356
  %1362 = fdiv fast float %1229, %1222
  %1363 = fdiv fast float %1228, %1222
  %1364 = fdiv fast float %1227, %1222
  %1365 = fdiv fast float %1226, %1222
  %1366 = fdiv fast float %1225, %1222
  %1367 = fdiv fast float %1224, %1222
  %1368 = fdiv fast float %1223, %1222
  %1369 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1362)  ; IsFinite(value)
  %1370 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1363)  ; IsFinite(value)
  %1371 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1364)  ; IsFinite(value)
  %1372 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1365)  ; IsFinite(value)
  %1373 = and i1 %1369, %1370
  %1374 = and i1 %1373, %1371
  %1375 = and i1 %1374, %1372
  %1376 = fcmp fast ogt float %1365, 0.000000e+00
  %1377 = and i1 %1376, %1375
  %1378 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1366)  ; IsFinite(value)
  %1379 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1367)  ; IsFinite(value)
  %1380 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1221)  ; IsFinite(value)
  %1381 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1368)  ; IsFinite(value)
  %1382 = and i1 %1378, %1379
  %1383 = and i1 %1382, %1380
  %1384 = and i1 %1383, %1381
  %1385 = and i1 %1377, %1384
  %1386 = fcmp fast ogt float %1221, 0.000000e+00
  %1387 = and i1 %1386, %1385
  %1388 = select i1 %1387, float %1362, float %45
  %1389 = select i1 %1387, float %1363, float %46
  %1390 = select i1 %1387, float %1364, float %47
  %1391 = select i1 %1387, float %1365, float %48
  %1392 = select i1 %1387, float %1366, float %18
  %1393 = select i1 %1387, float %1367, float %19
  %1394 = select i1 %1387, float %1221, float %20
  br label %1395

; <label>:1395                                    ; preds = %1361, %1356, %1218, %1094
  %1396 = phi i1 [ false, %1356 ], [ %1387, %1361 ], [ false, %1218 ], [ false, %1094 ]
  %1397 = phi float [ %45, %1356 ], [ %1388, %1361 ], [ %45, %1218 ], [ %45, %1094 ]
  %1398 = phi float [ %46, %1356 ], [ %1389, %1361 ], [ %46, %1218 ], [ %46, %1094 ]
  %1399 = phi float [ %47, %1356 ], [ %1390, %1361 ], [ %47, %1218 ], [ %47, %1094 ]
  %1400 = phi float [ %48, %1356 ], [ %1391, %1361 ], [ %48, %1218 ], [ %48, %1094 ]
  %1401 = phi float [ %18, %1356 ], [ %1392, %1361 ], [ %18, %1218 ], [ %18, %1094 ]
  %1402 = phi float [ %19, %1356 ], [ %1393, %1361 ], [ %19, %1218 ], [ %19, %1094 ]
  %1403 = phi float [ %20, %1356 ], [ %1394, %1361 ], [ %20, %1218 ], [ %20, %1094 ]
  %1404 = select i1 %1396, float %1397, float %45
  %1405 = select i1 %1396, float %1398, float %46
  %1406 = select i1 %1396, float %1399, float %47
  %1407 = select i1 %1396, float %1400, float %48
  %1408 = select i1 %1396, float %1401, float %18
  %1409 = select i1 %1396, float %1402, float %19
  %1410 = select i1 %1396, float %1403, float %20
  br label %1411

; <label>:1411                                    ; preds = %1395, %959
  %1412 = phi float [ %45, %959 ], [ %1404, %1395 ]
  %1413 = phi float [ %46, %959 ], [ %1405, %1395 ]
  %1414 = phi float [ %47, %959 ], [ %1406, %1395 ]
  %1415 = phi float [ %48, %959 ], [ %1407, %1395 ]
  %1416 = phi float [ %18, %959 ], [ %1408, %1395 ]
  %1417 = phi float [ %19, %959 ], [ %1409, %1395 ]
  %1418 = phi float [ %20, %959 ], [ %1410, %1395 ]
  %1419 = select i1 %961, float %1412, float %53
  %1420 = select i1 %961, float %1413, float %54
  %1421 = select i1 %961, float %1414, float %55
  %1422 = select i1 %961, float %1415, float %56
  %1423 = select i1 %961, float %1416, float %806
  %1424 = select i1 %961, float %1417, float %809
  br i1 %983, label %1438, label %1425

; <label>:1425                                    ; preds = %1411
  %1426 = fadd fast float %53, 0x3FA47AE140000000
  %1427 = fadd fast float %54, 0x3FA47AE140000000
  %1428 = fadd fast float %55, 0x3FA47AE140000000
  %1429 = fadd fast float %53, 0xBFA47AE140000000
  %1430 = fadd fast float %54, 0xBFA47AE140000000
  %1431 = fadd fast float %55, 0xBFA47AE140000000
  %1432 = call float @dx.op.binary.f32(i32 35, float %1419, float %1429)  ; FMax(a,b)
  %1433 = call float @dx.op.binary.f32(i32 35, float %1420, float %1430)  ; FMax(a,b)
  %1434 = call float @dx.op.binary.f32(i32 35, float %1421, float %1431)  ; FMax(a,b)
  %1435 = call float @dx.op.binary.f32(i32 36, float %1432, float %1426)  ; FMin(a,b)
  %1436 = call float @dx.op.binary.f32(i32 36, float %1433, float %1427)  ; FMin(a,b)
  %1437 = call float @dx.op.binary.f32(i32 36, float %1434, float %1428)  ; FMin(a,b)
  br label %1438

; <label>:1438                                    ; preds = %1425, %1411
  %1439 = phi float [ %1419, %1411 ], [ %1435, %1425 ]
  %1440 = phi float [ %1420, %1411 ], [ %1436, %1425 ]
  %1441 = phi float [ %1421, %1411 ], [ %1437, %1425 ]
  %1442 = fcmp fast ogt float %28, 5.000000e-01
  %1443 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %964)  ; FMin(a,b)
  %1444 = select i1 %1442, float %1443, float %964
  %1445 = fadd fast float %1418, 1.000000e+00
  %1446 = select i1 %961, float %1445, float 1.000000e+00
  %1447 = call float @dx.op.binary.f32(i32 36, float %1446, float %1444)  ; FMin(a,b)
  %1448 = select i1 %961, float %1447, float 1.000000e+00
  %1449 = fdiv fast float 1.000000e+00, %1448
  %1450 = call float @dx.op.binary.f32(i32 35, float %40, float %1449)  ; FMax(a,b)
  %1451 = select i1 %961, float %1450, float 1.000000e+00
  %1452 = fsub fast float %56, %1422
  %1453 = call float @dx.op.unary.f32(i32 6, float %1452)  ; FAbs(value)
  %1454 = fmul fast float %1453, 2.500000e-01
  %1455 = select i1 %961, float %1454, float 1.000000e+00
  %1456 = call float @dx.op.binary.f32(i32 35, float %1451, float %1455)  ; FMax(a,b)
  %1457 = fsub fast float %806, %1423
  %1458 = fsub fast float %809, %1424
  %1459 = fmul fast float %1456, %1457
  %1460 = fmul fast float %1456, %1458
  %1461 = fadd fast float %1459, %1423
  %1462 = fadd fast float %1460, %1424
  %1463 = fsub fast float %53, %1439
  %1464 = fsub fast float %54, %1440
  %1465 = fsub fast float %55, %1441
  %1466 = fmul fast float %1456, %1463
  %1467 = fmul fast float %1456, %1464
  %1468 = fmul fast float %1456, %1465
  %1469 = fmul fast float %1456, %1452
  %1470 = fadd fast float %1466, %1439
  %1471 = fadd fast float %1467, %1440
  %1472 = fadd fast float %1468, %1441
  %1473 = fadd fast float %1469, %1422
  %1474 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1470)  ; IsFinite(value)
  %1475 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1471)  ; IsFinite(value)
  %1476 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1472)  ; IsFinite(value)
  %1477 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1473)  ; IsFinite(value)
  %1478 = and i1 %1474, %1475
  %1479 = and i1 %1478, %1476
  %1480 = and i1 %1479, %1477
  %1481 = fcmp fast ogt float %1473, 0.000000e+00
  %1482 = and i1 %1481, %1480
  %1483 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1461)  ; IsFinite(value)
  %1484 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1462)  ; IsFinite(value)
  %1485 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1448)  ; IsFinite(value)
  %1486 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %1487 = and i1 %1483, %1484
  %1488 = and i1 %1487, %1485
  %1489 = and i1 %1488, %1486
  %1490 = and i1 %1482, %1489
  %1491 = fcmp fast ogt float %1448, 0.000000e+00
  %1492 = and i1 %1491, %1490
  %1493 = select i1 %1492, float %1470, float 0.000000e+00
  %1494 = select i1 %1492, float %1471, float 0.000000e+00
  %1495 = select i1 %1492, float %1472, float 0.000000e+00
  %1496 = select i1 %1492, float %1473, float 0.000000e+00
  %1497 = select i1 %1492, float %1461, float 0.000000e+00
  %1498 = select i1 %1492, float %1462, float 0.000000e+00
  %1499 = select i1 %1492, float %1448, float 0.000000e+00
  br label %1500

; <label>:1500                                    ; preds = %1438, %957, %947
  %1501 = phi float [ %948, %957 ], [ %948, %947 ], [ %1493, %1438 ]
  %1502 = phi float [ %949, %957 ], [ %949, %947 ], [ %1494, %1438 ]
  %1503 = phi float [ %950, %957 ], [ %950, %947 ], [ %1495, %1438 ]
  %1504 = phi float [ %951, %957 ], [ %951, %947 ], [ %1496, %1438 ]
  %1505 = phi float [ %952, %957 ], [ %952, %947 ], [ %1497, %1438 ]
  %1506 = phi float [ %953, %957 ], [ %953, %947 ], [ %1498, %1438 ]
  %1507 = phi float [ %958, %957 ], [ %954, %947 ], [ %1499, %1438 ]
  %1508 = phi float [ %955, %957 ], [ %955, %947 ], [ 0.000000e+00, %1438 ]
  %1509 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1501)  ; LegacyF32ToF16(value)
  %1510 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1502)  ; LegacyF32ToF16(value)
  %1511 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1503)  ; LegacyF32ToF16(value)
  %1512 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1504)  ; LegacyF32ToF16(value)
  %1513 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1509)  ; LegacyF16ToF32(value)
  %1514 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1510)  ; LegacyF16ToF32(value)
  %1515 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1511)  ; LegacyF16ToF32(value)
  %1516 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1512)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %1501, float %1502, float %1503, float %1504, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %1505, float %1506, float %1507, float %1508, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %1513, float %1514, float %1515, float %1516, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %1505, float %1506, float %1507, float %1508, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %1518

; <label>:1517                                    ; preds = %776
  br label %1518

; <label>:1518                                    ; preds = %1517, %1500, %0
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
declare i32 @dx.op.binary.i32(i32, i32, i32) #0

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
