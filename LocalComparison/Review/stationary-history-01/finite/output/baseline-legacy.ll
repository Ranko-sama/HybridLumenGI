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
; shader hash: 9bc6d023242a585a434329627bd3841c
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
  br i1 %10, label %1468, label %11

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
  br i1 %60, label %61, label %770

; <label>:61                                      ; preds = %11
  br label %62

; <label>:62                                      ; preds = %751, %61
  %63 = phi float [ %764, %751 ], [ %45, %61 ]
  %64 = phi float [ %765, %751 ], [ %46, %61 ]
  %65 = phi float [ %766, %751 ], [ %47, %61 ]
  %66 = phi float [ %767, %751 ], [ %48, %61 ]
  %67 = phi float [ %756, %751 ], [ %18, %61 ]
  %68 = phi float [ %757, %751 ], [ %19, %61 ]
  %69 = phi float [ %758, %751 ], [ %20, %61 ]
  %70 = phi float [ %759, %751 ], [ %21, %61 ]
  %71 = phi i32 [ %768, %751 ], [ 0, %61 ]
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
  br i1 %232, label %233, label %751

; <label>:233                                     ; preds = %223
  %234 = call float @dx.op.binary.f32(i32 36, float %230, float 2.000000e+00)  ; FMin(a,b)
  br label %751

; <label>:235                                     ; preds = %173
  %236 = zext i1 %222 to i32
  %237 = fcmp fast ogt float %30, 5.000000e-01
  %238 = select i1 %237, i32 0, i32 %236
  %239 = icmp eq i32 %238, 0
  br i1 %239, label %665, label %240

; <label>:240                                     ; preds = %235
  %241 = call float @dx.op.unary.f32(i32 27, float %102)  ; Round_ni(value)
  %242 = call float @dx.op.unary.f32(i32 27, float %103)  ; Round_ni(value)
  %243 = fptosi float %241 to i32
  %244 = fptosi float %242 to i32
  %245 = call i32 @dx.op.binary.i32(i32 37, i32 %243, i32 0)  ; IMax(a,b)
  %246 = call i32 @dx.op.binary.i32(i32 37, i32 %244, i32 0)  ; IMax(a,b)
  %247 = call i32 @dx.op.binary.i32(i32 38, i32 %245, i32 0)  ; IMin(a,b)
  %248 = call i32 @dx.op.binary.i32(i32 38, i32 %246, i32 0)  ; IMin(a,b)
  %249 = add i32 %247, -1
  %250 = add i32 %248, -1
  %251 = call i32 @dx.op.binary.i32(i32 37, i32 %249, i32 0)  ; IMax(a,b)
  %252 = call i32 @dx.op.binary.i32(i32 37, i32 %250, i32 0)  ; IMax(a,b)
  %253 = and i32 %251, 2147483647
  %254 = and i32 %252, 2147483647
  %255 = uitofp i32 %253 to float
  %256 = uitofp i32 %254 to float
  %257 = fsub fast float %255, %101
  %258 = fsub fast float 5.000000e-01, %103
  %259 = fadd fast float %256, %258
  %260 = call float @dx.op.unary.f32(i32 6, float %257)  ; FAbs(value)
  %261 = call float @dx.op.unary.f32(i32 6, float %259)  ; FAbs(value)
  %262 = call i32 @dx.op.binary.i32(i32 38, i32 %247, i32 0)  ; IMin(a,b)
  %263 = call i32 @dx.op.binary.i32(i32 38, i32 %248, i32 0)  ; IMin(a,b)
  %264 = and i32 %262, 2147483647
  %265 = and i32 %263, 2147483647
  %266 = uitofp i32 %264 to float
  %267 = uitofp i32 %265 to float
  %268 = fsub fast float %266, %101
  %269 = fadd fast float %267, %258
  %270 = call float @dx.op.unary.f32(i32 6, float %268)  ; FAbs(value)
  %271 = call float @dx.op.unary.f32(i32 6, float %269)  ; FAbs(value)
  %272 = fcmp fast olt float %270, %260
  %273 = select i1 %272, i32 %262, i32 %251
  %274 = select i1 %272, float %270, float %260
  %275 = fcmp fast olt float %271, %261
  %276 = select i1 %275, i32 %263, i32 %252
  %277 = select i1 %275, float %271, float %261
  %278 = add i32 %247, 1
  %279 = add i32 %248, 1
  %280 = call i32 @dx.op.binary.i32(i32 38, i32 %278, i32 0)  ; IMin(a,b)
  %281 = call i32 @dx.op.binary.i32(i32 38, i32 %279, i32 0)  ; IMin(a,b)
  %282 = and i32 %280, 2147483647
  %283 = and i32 %281, 2147483647
  %284 = uitofp i32 %282 to float
  %285 = uitofp i32 %283 to float
  %286 = fsub fast float %284, %101
  %287 = fadd fast float %285, %258
  %288 = call float @dx.op.unary.f32(i32 6, float %286)  ; FAbs(value)
  %289 = call float @dx.op.unary.f32(i32 6, float %287)  ; FAbs(value)
  %290 = fcmp fast olt float %288, %274
  %291 = select i1 %290, i32 %280, i32 %273
  %292 = fcmp fast olt float %289, %277
  %293 = select i1 %292, i32 %281, i32 %276
  %294 = and i32 %291, 2147483647
  %295 = and i32 %293, 2147483647
  %296 = uitofp i32 %294 to float
  %297 = uitofp i32 %295 to float
  %298 = fadd fast float %296, 5.000000e-01
  %299 = fadd fast float %297, 5.000000e-01
  %300 = fcmp fast olt float %102, %298
  br i1 %300, label %301, label %304

; <label>:301                                     ; preds = %240
  %302 = add nsw i32 %291, -1
  %303 = call i32 @dx.op.binary.i32(i32 37, i32 %302, i32 0)  ; IMax(a,b)
  br label %307

; <label>:304                                     ; preds = %240
  %305 = add i32 %291, 1
  %306 = call i32 @dx.op.binary.i32(i32 40, i32 %305, i32 0)  ; UMin(a,b)
  br label %307

; <label>:307                                     ; preds = %304, %301
  %308 = phi i32 [ %291, %301 ], [ %306, %304 ]
  %309 = phi i32 [ %303, %301 ], [ %291, %304 ]
  %310 = fcmp fast olt float %103, %299
  br i1 %310, label %311, label %314

; <label>:311                                     ; preds = %307
  %312 = add nsw i32 %293, -1
  %313 = call i32 @dx.op.binary.i32(i32 37, i32 %312, i32 0)  ; IMax(a,b)
  br label %317

; <label>:314                                     ; preds = %307
  %315 = add i32 %293, 1
  %316 = call i32 @dx.op.binary.i32(i32 40, i32 %315, i32 0)  ; UMin(a,b)
  br label %317

; <label>:317                                     ; preds = %314, %311
  %318 = phi i32 [ %293, %311 ], [ %316, %314 ]
  %319 = phi i32 [ %313, %311 ], [ %293, %314 ]
  %320 = and i32 %309, 2147483647
  %321 = and i32 %319, 2147483647
  %322 = uitofp i32 %320 to float
  %323 = uitofp i32 %321 to float
  %324 = fadd fast float %322, 5.000000e-01
  %325 = fadd fast float %323, 5.000000e-01
  %326 = and i32 %308, 2147483647
  %327 = and i32 %318, 2147483647
  %328 = uitofp i32 %326 to float
  %329 = uitofp i32 %327 to float
  %330 = fadd fast float %328, 5.000000e-01
  %331 = fadd fast float %329, 5.000000e-01
  %332 = fcmp fast ogt float %330, %324
  %333 = fsub fast float %102, %324
  %334 = fsub fast float %330, %324
  %335 = fdiv fast float %333, %334
  %336 = call float @dx.op.unary.f32(i32 7, float %335)  ; Saturate(value)
  %337 = select i1 %332, float %336, float 0.000000e+00
  %338 = fcmp fast ogt float %331, %325
  %339 = fsub fast float %103, %325
  %340 = fsub fast float %331, %325
  %341 = fdiv fast float %339, %340
  %342 = call float @dx.op.unary.f32(i32 7, float %341)  ; Saturate(value)
  %343 = select i1 %338, float %342, float 0.000000e+00
  %344 = fsub fast float 1.000000e+00, %337
  %345 = fsub fast float 1.000000e+00, %343
  %346 = fmul fast float %345, %344
  %347 = fcmp fast ugt float %346, 0.000000e+00
  br i1 %347, label %361, label %392

; <label>:348                                     ; preds = %462, %450, %404, %392
  %349 = phi i1 [ true, %392 ], [ false, %404 ], [ true, %450 ], [ false, %462 ]
  %350 = phi i1 [ false, %392 ], [ true, %404 ], [ false, %450 ], [ %452, %462 ]
  %351 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %463, %462 ]
  %352 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %464, %462 ]
  %353 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %465, %462 ]
  %354 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %466, %462 ]
  %355 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %467, %462 ]
  %356 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %468, %462 ]
  %357 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %469, %462 ]
  %358 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %470, %462 ]
  %359 = phi float [ 0.000000e+00, %392 ], [ 0.000000e+00, %404 ], [ 0.000000e+00, %450 ], [ %471, %462 ]
  %360 = or i1 %349, %350
  br i1 %360, label %649, label %485

; <label>:361                                     ; preds = %317
  %362 = icmp ne i32 %309, %174
  %363 = icmp ne i32 %319, %175
  %364 = or i1 %362, %363
  br i1 %364, label %365, label %382

; <label>:365                                     ; preds = %361
  %366 = fmul fast float %324, 2.000000e+00
  %367 = fmul fast float %325, 2.000000e+00
  %368 = fadd fast float %367, -1.000000e+00
  %369 = fsub fast float %185, %366
  %370 = fsub fast float -0.000000e+00, %368
  %371 = call float @dx.op.dot3.f32(i32 55, float %369, float %370, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %372 = call float @dx.op.unary.f32(i32 6, float %371)  ; FAbs(value)
  %373 = fmul fast float %369, %369
  %374 = fmul fast float %368, %368
  %375 = fadd fast float %373, %194
  %376 = fadd fast float %375, %374
  %377 = call float @dx.op.unary.f32(i32 24, float %376)  ; Sqrt(value)
  %378 = fcmp uge float %372, 0x3F8EB851E0000000
  %379 = fcmp uge float %377, 0x3F8EB851E0000000
  %380 = or i1 %379, %378
  %381 = xor i1 %221, true
  br label %382

; <label>:382                                     ; preds = %365, %361
  %383 = phi i1 [ %381, %365 ], [ false, %361 ]
  %384 = phi i1 [ %380, %365 ], [ false, %361 ]
  %385 = fmul fast float %346, %63
  %386 = fmul fast float %346, %64
  %387 = fmul fast float %346, %65
  %388 = fmul fast float %346, %66
  %389 = fmul fast float %346, %67
  %390 = fmul fast float %346, %68
  %391 = fmul fast float %346, %70
  br label %392

; <label>:392                                     ; preds = %382, %317
  %393 = phi i1 [ %383, %382 ], [ false, %317 ]
  %394 = phi i1 [ %384, %382 ], [ false, %317 ]
  %395 = phi float [ %385, %382 ], [ 0.000000e+00, %317 ]
  %396 = phi float [ %386, %382 ], [ 0.000000e+00, %317 ]
  %397 = phi float [ %387, %382 ], [ 0.000000e+00, %317 ]
  %398 = phi float [ %388, %382 ], [ 0.000000e+00, %317 ]
  %399 = phi float [ %389, %382 ], [ 0.000000e+00, %317 ]
  %400 = phi float [ %390, %382 ], [ 0.000000e+00, %317 ]
  %401 = phi float [ %391, %382 ], [ 0.000000e+00, %317 ]
  %402 = phi float [ %346, %382 ], [ 0.000000e+00, %317 ]
  %403 = phi float [ %69, %382 ], [ 0.000000e+00, %317 ]
  br i1 %393, label %348, label %404

; <label>:404                                     ; preds = %392
  br i1 %394, label %348, label %405

; <label>:405                                     ; preds = %404
  %406 = fmul fast float %345, %337
  %407 = fcmp fast ugt float %406, 0.000000e+00
  br i1 %407, label %408, label %450

; <label>:408                                     ; preds = %405
  %409 = icmp ne i32 %308, %174
  %410 = icmp ne i32 %319, %175
  %411 = or i1 %409, %410
  br i1 %411, label %412, label %429

; <label>:412                                     ; preds = %408
  %413 = fmul fast float %330, 2.000000e+00
  %414 = fmul fast float %325, 2.000000e+00
  %415 = fadd fast float %414, -1.000000e+00
  %416 = fsub fast float %185, %413
  %417 = fsub fast float -0.000000e+00, %415
  %418 = call float @dx.op.dot3.f32(i32 55, float %416, float %417, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %419 = call float @dx.op.unary.f32(i32 6, float %418)  ; FAbs(value)
  %420 = fmul fast float %416, %416
  %421 = fmul fast float %415, %415
  %422 = fadd fast float %420, %194
  %423 = fadd fast float %422, %421
  %424 = call float @dx.op.unary.f32(i32 24, float %423)  ; Sqrt(value)
  %425 = fcmp uge float %419, 0x3F8EB851E0000000
  %426 = fcmp uge float %424, 0x3F8EB851E0000000
  %427 = or i1 %426, %425
  %428 = xor i1 %221, true
  br label %429

; <label>:429                                     ; preds = %412, %408
  %430 = phi i1 [ %428, %412 ], [ false, %408 ]
  %431 = phi i1 [ %427, %412 ], [ false, %408 ]
  %432 = fcmp fast oeq float %402, 0.000000e+00
  %433 = call float @dx.op.binary.f32(i32 36, float %403, float %69)  ; FMin(a,b)
  %434 = select i1 %432, float %69, float %433
  %435 = fmul fast float %406, %63
  %436 = fmul fast float %406, %64
  %437 = fmul fast float %406, %65
  %438 = fmul fast float %406, %66
  %439 = fadd fast float %395, %435
  %440 = fadd fast float %396, %436
  %441 = fadd fast float %397, %437
  %442 = fadd fast float %398, %438
  %443 = fmul fast float %406, %67
  %444 = fmul fast float %406, %68
  %445 = fmul fast float %406, %70
  %446 = fadd fast float %399, %443
  %447 = fadd fast float %400, %444
  %448 = fadd fast float %401, %445
  %449 = fadd fast float %402, %406
  br label %450

; <label>:450                                     ; preds = %429, %405
  %451 = phi i1 [ %430, %429 ], [ false, %405 ]
  %452 = phi i1 [ %431, %429 ], [ false, %405 ]
  %453 = phi float [ %439, %429 ], [ %395, %405 ]
  %454 = phi float [ %440, %429 ], [ %396, %405 ]
  %455 = phi float [ %441, %429 ], [ %397, %405 ]
  %456 = phi float [ %442, %429 ], [ %398, %405 ]
  %457 = phi float [ %446, %429 ], [ %399, %405 ]
  %458 = phi float [ %447, %429 ], [ %400, %405 ]
  %459 = phi float [ %448, %429 ], [ %401, %405 ]
  %460 = phi float [ %449, %429 ], [ %402, %405 ]
  %461 = phi float [ %434, %429 ], [ %403, %405 ]
  br i1 %451, label %348, label %462

; <label>:462                                     ; preds = %450
  %463 = select i1 %452, float 0.000000e+00, float %461
  %464 = select i1 %452, float 0.000000e+00, float %460
  %465 = select i1 %452, float 0.000000e+00, float %459
  %466 = select i1 %452, float 0.000000e+00, float %458
  %467 = select i1 %452, float 0.000000e+00, float %457
  %468 = select i1 %452, float 0.000000e+00, float %456
  %469 = select i1 %452, float 0.000000e+00, float %455
  %470 = select i1 %452, float 0.000000e+00, float %454
  %471 = select i1 %452, float 0.000000e+00, float %453
  br label %348

; <label>:472                                     ; preds = %600, %588, %542, %530
  %473 = phi i1 [ true, %530 ], [ false, %542 ], [ true, %588 ], [ false, %600 ]
  %474 = phi i1 [ false, %530 ], [ true, %542 ], [ false, %588 ], [ %590, %600 ]
  %475 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %601, %600 ]
  %476 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %602, %600 ]
  %477 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %603, %600 ]
  %478 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %604, %600 ]
  %479 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %605, %600 ]
  %480 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %606, %600 ]
  %481 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %607, %600 ]
  %482 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %608, %600 ]
  %483 = phi float [ 0.000000e+00, %530 ], [ 0.000000e+00, %542 ], [ 0.000000e+00, %588 ], [ %609, %600 ]
  %484 = or i1 %473, %474
  br i1 %484, label %649, label %610

; <label>:485                                     ; preds = %348
  %486 = fmul fast float %343, %344
  %487 = fcmp fast ugt float %486, 0.000000e+00
  br i1 %487, label %488, label %530

; <label>:488                                     ; preds = %485
  %489 = icmp ne i32 %309, %174
  %490 = icmp ne i32 %318, %175
  %491 = or i1 %489, %490
  br i1 %491, label %492, label %509

; <label>:492                                     ; preds = %488
  %493 = fmul fast float %324, 2.000000e+00
  %494 = fmul fast float %331, 2.000000e+00
  %495 = fadd fast float %494, -1.000000e+00
  %496 = fsub fast float %185, %493
  %497 = fsub fast float -0.000000e+00, %495
  %498 = call float @dx.op.dot3.f32(i32 55, float %496, float %497, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %499 = call float @dx.op.unary.f32(i32 6, float %498)  ; FAbs(value)
  %500 = fmul fast float %496, %496
  %501 = fmul fast float %495, %495
  %502 = fadd fast float %500, %194
  %503 = fadd fast float %502, %501
  %504 = call float @dx.op.unary.f32(i32 24, float %503)  ; Sqrt(value)
  %505 = fcmp uge float %499, 0x3F8EB851E0000000
  %506 = fcmp uge float %504, 0x3F8EB851E0000000
  %507 = or i1 %506, %505
  %508 = xor i1 %221, true
  br label %509

; <label>:509                                     ; preds = %492, %488
  %510 = phi i1 [ %508, %492 ], [ false, %488 ]
  %511 = phi i1 [ %507, %492 ], [ false, %488 ]
  %512 = fcmp fast oeq float %352, 0.000000e+00
  %513 = call float @dx.op.binary.f32(i32 36, float %351, float %69)  ; FMin(a,b)
  %514 = select i1 %512, float %69, float %513
  %515 = fmul fast float %486, %63
  %516 = fmul fast float %486, %64
  %517 = fmul fast float %486, %65
  %518 = fmul fast float %486, %66
  %519 = fadd fast float %359, %515
  %520 = fadd fast float %358, %516
  %521 = fadd fast float %357, %517
  %522 = fadd fast float %356, %518
  %523 = fmul fast float %486, %67
  %524 = fmul fast float %486, %68
  %525 = fmul fast float %486, %70
  %526 = fadd fast float %355, %523
  %527 = fadd fast float %354, %524
  %528 = fadd fast float %353, %525
  %529 = fadd fast float %352, %486
  br label %530

; <label>:530                                     ; preds = %509, %485
  %531 = phi i1 [ %510, %509 ], [ false, %485 ]
  %532 = phi i1 [ %511, %509 ], [ false, %485 ]
  %533 = phi float [ %519, %509 ], [ %359, %485 ]
  %534 = phi float [ %520, %509 ], [ %358, %485 ]
  %535 = phi float [ %521, %509 ], [ %357, %485 ]
  %536 = phi float [ %522, %509 ], [ %356, %485 ]
  %537 = phi float [ %526, %509 ], [ %355, %485 ]
  %538 = phi float [ %527, %509 ], [ %354, %485 ]
  %539 = phi float [ %528, %509 ], [ %353, %485 ]
  %540 = phi float [ %529, %509 ], [ %352, %485 ]
  %541 = phi float [ %514, %509 ], [ %351, %485 ]
  br i1 %531, label %472, label %542

; <label>:542                                     ; preds = %530
  br i1 %532, label %472, label %543

; <label>:543                                     ; preds = %542
  %544 = fmul fast float %343, %337
  %545 = fcmp fast ugt float %544, 0.000000e+00
  br i1 %545, label %546, label %588

; <label>:546                                     ; preds = %543
  %547 = icmp ne i32 %308, %174
  %548 = icmp ne i32 %318, %175
  %549 = or i1 %547, %548
  br i1 %549, label %550, label %567

; <label>:550                                     ; preds = %546
  %551 = fmul fast float %330, 2.000000e+00
  %552 = fmul fast float %331, 2.000000e+00
  %553 = fadd fast float %552, -1.000000e+00
  %554 = fsub fast float %185, %551
  %555 = fsub fast float -0.000000e+00, %553
  %556 = call float @dx.op.dot3.f32(i32 55, float %554, float %555, float %188, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %557 = call float @dx.op.unary.f32(i32 6, float %556)  ; FAbs(value)
  %558 = fmul fast float %554, %554
  %559 = fmul fast float %553, %553
  %560 = fadd fast float %558, %194
  %561 = fadd fast float %560, %559
  %562 = call float @dx.op.unary.f32(i32 24, float %561)  ; Sqrt(value)
  %563 = fcmp uge float %557, 0x3F8EB851E0000000
  %564 = fcmp uge float %562, 0x3F8EB851E0000000
  %565 = or i1 %564, %563
  %566 = xor i1 %221, true
  br label %567

; <label>:567                                     ; preds = %550, %546
  %568 = phi i1 [ %566, %550 ], [ false, %546 ]
  %569 = phi i1 [ %565, %550 ], [ false, %546 ]
  %570 = fcmp fast oeq float %540, 0.000000e+00
  %571 = call float @dx.op.binary.f32(i32 36, float %541, float %69)  ; FMin(a,b)
  %572 = select i1 %570, float %69, float %571
  %573 = fmul fast float %544, %63
  %574 = fmul fast float %544, %64
  %575 = fmul fast float %544, %65
  %576 = fmul fast float %544, %66
  %577 = fadd fast float %533, %573
  %578 = fadd fast float %534, %574
  %579 = fadd fast float %535, %575
  %580 = fadd fast float %536, %576
  %581 = fmul fast float %544, %67
  %582 = fmul fast float %544, %68
  %583 = fmul fast float %544, %70
  %584 = fadd fast float %537, %581
  %585 = fadd fast float %538, %582
  %586 = fadd fast float %539, %583
  %587 = fadd fast float %540, %544
  br label %588

; <label>:588                                     ; preds = %567, %543
  %589 = phi i1 [ %568, %567 ], [ false, %543 ]
  %590 = phi i1 [ %569, %567 ], [ false, %543 ]
  %591 = phi float [ %577, %567 ], [ %533, %543 ]
  %592 = phi float [ %578, %567 ], [ %534, %543 ]
  %593 = phi float [ %579, %567 ], [ %535, %543 ]
  %594 = phi float [ %580, %567 ], [ %536, %543 ]
  %595 = phi float [ %584, %567 ], [ %537, %543 ]
  %596 = phi float [ %585, %567 ], [ %538, %543 ]
  %597 = phi float [ %586, %567 ], [ %539, %543 ]
  %598 = phi float [ %587, %567 ], [ %540, %543 ]
  %599 = phi float [ %572, %567 ], [ %541, %543 ]
  br i1 %589, label %472, label %600

; <label>:600                                     ; preds = %588
  %601 = select i1 %590, float 0.000000e+00, float %599
  %602 = select i1 %590, float 0.000000e+00, float %598
  %603 = select i1 %590, float 0.000000e+00, float %597
  %604 = select i1 %590, float 0.000000e+00, float %596
  %605 = select i1 %590, float 0.000000e+00, float %595
  %606 = select i1 %590, float 0.000000e+00, float %594
  %607 = select i1 %590, float 0.000000e+00, float %593
  %608 = select i1 %590, float 0.000000e+00, float %592
  %609 = select i1 %590, float 0.000000e+00, float %591
  br label %472

; <label>:610                                     ; preds = %472
  %611 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %476)  ; IsFinite(value)
  %612 = xor i1 %611, true
  %613 = fcmp fast ole float %476, 0.000000e+00
  %614 = or i1 %613, %612
  br i1 %614, label %649, label %615

; <label>:615                                     ; preds = %610
  %616 = fdiv fast float %483, %476
  %617 = fdiv fast float %482, %476
  %618 = fdiv fast float %481, %476
  %619 = fdiv fast float %480, %476
  %620 = fdiv fast float %479, %476
  %621 = fdiv fast float %478, %476
  %622 = fdiv fast float %477, %476
  %623 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %616)  ; IsFinite(value)
  %624 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %617)  ; IsFinite(value)
  %625 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %618)  ; IsFinite(value)
  %626 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %619)  ; IsFinite(value)
  %627 = and i1 %623, %624
  %628 = and i1 %627, %625
  %629 = and i1 %628, %626
  %630 = fcmp fast ogt float %619, 0.000000e+00
  %631 = and i1 %630, %629
  %632 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %620)  ; IsFinite(value)
  %633 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %621)  ; IsFinite(value)
  %634 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %475)  ; IsFinite(value)
  %635 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %622)  ; IsFinite(value)
  %636 = and i1 %632, %633
  %637 = and i1 %636, %634
  %638 = and i1 %637, %635
  %639 = and i1 %631, %638
  %640 = fcmp fast ogt float %475, 0.000000e+00
  %641 = and i1 %640, %639
  %642 = select i1 %641, float %616, float %63
  %643 = select i1 %641, float %617, float %64
  %644 = select i1 %641, float %618, float %65
  %645 = select i1 %641, float %619, float %66
  %646 = select i1 %641, float %620, float %67
  %647 = select i1 %641, float %621, float %68
  %648 = select i1 %641, float %475, float %69
  br label %649

; <label>:649                                     ; preds = %615, %610, %472, %348
  %650 = phi i1 [ false, %610 ], [ %641, %615 ], [ false, %472 ], [ false, %348 ]
  %651 = phi float [ %63, %610 ], [ %642, %615 ], [ %63, %472 ], [ %63, %348 ]
  %652 = phi float [ %64, %610 ], [ %643, %615 ], [ %64, %472 ], [ %64, %348 ]
  %653 = phi float [ %65, %610 ], [ %644, %615 ], [ %65, %472 ], [ %65, %348 ]
  %654 = phi float [ %66, %610 ], [ %645, %615 ], [ %66, %472 ], [ %66, %348 ]
  %655 = phi float [ %67, %610 ], [ %646, %615 ], [ %67, %472 ], [ %67, %348 ]
  %656 = phi float [ %68, %610 ], [ %647, %615 ], [ %68, %472 ], [ %68, %348 ]
  %657 = phi float [ %69, %610 ], [ %648, %615 ], [ %69, %472 ], [ %69, %348 ]
  %658 = select i1 %650, float %651, float %63
  %659 = select i1 %650, float %652, float %64
  %660 = select i1 %650, float %653, float %65
  %661 = select i1 %650, float %654, float %66
  %662 = select i1 %650, float %655, float %67
  %663 = select i1 %650, float %656, float %68
  %664 = select i1 %650, float %657, float %69
  br label %665

; <label>:665                                     ; preds = %649, %235
  %666 = phi float [ %63, %235 ], [ %658, %649 ]
  %667 = phi float [ %64, %235 ], [ %659, %649 ]
  %668 = phi float [ %65, %235 ], [ %660, %649 ]
  %669 = phi float [ %66, %235 ], [ %661, %649 ]
  %670 = phi float [ %67, %235 ], [ %662, %649 ]
  %671 = phi float [ %68, %235 ], [ %663, %649 ]
  %672 = phi float [ %69, %235 ], [ %664, %649 ]
  %673 = icmp ne i32 %238, 0
  %674 = select i1 %673, float %669, float %56
  %675 = select i1 %673, float %670, float %82
  %676 = select i1 %673, float %671, float %85
  %677 = fcmp fast ogt float %28, 5.000000e-01
  %678 = select i1 %673, float %668, float %55
  %679 = select i1 %673, float %667, float %54
  %680 = select i1 %673, float %666, float %53
  %681 = fadd fast float %53, 0x3FA47AE140000000
  %682 = fadd fast float %54, 0x3FA47AE140000000
  %683 = fadd fast float %55, 0x3FA47AE140000000
  %684 = fadd fast float %53, 0xBFA47AE140000000
  %685 = fadd fast float %54, 0xBFA47AE140000000
  %686 = fadd fast float %55, 0xBFA47AE140000000
  %687 = call float @dx.op.binary.f32(i32 35, float %680, float %684)  ; FMax(a,b)
  %688 = call float @dx.op.binary.f32(i32 35, float %679, float %685)  ; FMax(a,b)
  %689 = call float @dx.op.binary.f32(i32 35, float %678, float %686)  ; FMax(a,b)
  %690 = call float @dx.op.binary.f32(i32 36, float %687, float %681)  ; FMin(a,b)
  %691 = call float @dx.op.binary.f32(i32 36, float %688, float %682)  ; FMin(a,b)
  %692 = call float @dx.op.binary.f32(i32 36, float %689, float %683)  ; FMin(a,b)
  %693 = sitofp i32 %59 to float
  %694 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %693)  ; FMin(a,b)
  %695 = select i1 %677, float %694, float %693
  %696 = fadd fast float %672, 1.000000e+00
  %697 = select i1 %673, float %696, float 1.000000e+00
  %698 = call float @dx.op.binary.f32(i32 36, float %697, float %695)  ; FMin(a,b)
  %699 = select i1 %673, float %698, float 1.000000e+00
  %700 = fdiv fast float 1.000000e+00, %699
  %701 = call float @dx.op.binary.f32(i32 35, float %40, float %700)  ; FMax(a,b)
  %702 = select i1 %673, float %701, float 1.000000e+00
  %703 = fsub fast float %56, %674
  %704 = call float @dx.op.unary.f32(i32 6, float %703)  ; FAbs(value)
  %705 = fmul fast float %704, 2.500000e-01
  %706 = select i1 %673, float %705, float 1.000000e+00
  %707 = call float @dx.op.binary.f32(i32 35, float %702, float %706)  ; FMax(a,b)
  %708 = fsub fast float %82, %675
  %709 = fsub fast float %85, %676
  %710 = fmul fast float %707, %708
  %711 = fmul fast float %707, %709
  %712 = fadd fast float %710, %675
  %713 = fadd fast float %711, %676
  %714 = fsub fast float %53, %690
  %715 = fsub fast float %54, %691
  %716 = fsub fast float %55, %692
  %717 = fmul fast float %707, %714
  %718 = fmul fast float %707, %715
  %719 = fmul fast float %707, %716
  %720 = fmul fast float %707, %703
  %721 = fadd fast float %717, %690
  %722 = fadd fast float %718, %691
  %723 = fadd fast float %719, %692
  %724 = fadd fast float %720, %674
  %725 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %721)  ; IsFinite(value)
  %726 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %722)  ; IsFinite(value)
  %727 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %723)  ; IsFinite(value)
  %728 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %724)  ; IsFinite(value)
  %729 = and i1 %725, %726
  %730 = and i1 %729, %727
  %731 = and i1 %730, %728
  %732 = fcmp fast ogt float %724, 0.000000e+00
  %733 = and i1 %732, %731
  %734 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %712)  ; IsFinite(value)
  %735 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %713)  ; IsFinite(value)
  %736 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %699)  ; IsFinite(value)
  %737 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %738 = and i1 %734, %735
  %739 = and i1 %738, %736
  %740 = and i1 %739, %737
  %741 = and i1 %733, %740
  %742 = fcmp fast ogt float %699, 0.000000e+00
  %743 = and i1 %742, %741
  %744 = select i1 %743, float %721, float 0.000000e+00
  %745 = select i1 %743, float %722, float 0.000000e+00
  %746 = select i1 %743, float %723, float 0.000000e+00
  %747 = select i1 %743, float %724, float 0.000000e+00
  %748 = select i1 %743, float %712, float 0.000000e+00
  %749 = select i1 %743, float %713, float 0.000000e+00
  %750 = select i1 %743, float %699, float 0.000000e+00
  br label %751

; <label>:751                                     ; preds = %665, %233, %223
  %752 = phi float [ %224, %233 ], [ %224, %223 ], [ %744, %665 ]
  %753 = phi float [ %225, %233 ], [ %225, %223 ], [ %745, %665 ]
  %754 = phi float [ %226, %233 ], [ %226, %223 ], [ %746, %665 ]
  %755 = phi float [ %227, %233 ], [ %227, %223 ], [ %747, %665 ]
  %756 = phi float [ %228, %233 ], [ %228, %223 ], [ %748, %665 ]
  %757 = phi float [ %229, %233 ], [ %229, %223 ], [ %749, %665 ]
  %758 = phi float [ %234, %233 ], [ %230, %223 ], [ %750, %665 ]
  %759 = phi float [ %231, %233 ], [ %231, %223 ], [ 0.000000e+00, %665 ]
  %760 = call i32 @dx.op.legacyF32ToF16(i32 130, float %752)  ; LegacyF32ToF16(value)
  %761 = call i32 @dx.op.legacyF32ToF16(i32 130, float %753)  ; LegacyF32ToF16(value)
  %762 = call i32 @dx.op.legacyF32ToF16(i32 130, float %754)  ; LegacyF32ToF16(value)
  %763 = call i32 @dx.op.legacyF32ToF16(i32 130, float %755)  ; LegacyF32ToF16(value)
  %764 = call float @dx.op.legacyF16ToF32(i32 131, i32 %760)  ; LegacyF16ToF32(value)
  %765 = call float @dx.op.legacyF16ToF32(i32 131, i32 %761)  ; LegacyF16ToF32(value)
  %766 = call float @dx.op.legacyF16ToF32(i32 131, i32 %762)  ; LegacyF16ToF32(value)
  %767 = call float @dx.op.legacyF16ToF32(i32 131, i32 %763)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 0, float %752, float %753, float %754, float %755, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 16, float %756, float %757, float %758, float %759, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 32, float %764, float %765, float %766, float %767, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %71, i32 48, float %756, float %757, float %758, float %759, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %768 = add nuw nsw i32 %71, 1
  %769 = icmp eq i32 %768, 32
  br i1 %769, label %1467, label %62, !llvm.loop !16

; <label>:770                                     ; preds = %11
  %771 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %53)  ; IsFinite(value)
  %772 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %773 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %774 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %775 = and i1 %771, %772
  %776 = and i1 %775, %773
  %777 = and i1 %776, %774
  %778 = fcmp fast ogt float %56, 0.000000e+00
  %779 = and i1 %778, %777
  %780 = call float @dx.op.dot3.f32(i32 55, float %53, float %54, float %55, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %781 = select i1 %779, float %780, float 0.000000e+00
  %782 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %781)  ; IsFinite(value)
  %783 = and i1 %779, %782
  %784 = fmul fast float %781, %781
  %785 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %784)  ; IsFinite(value)
  %786 = and i1 %783, %785
  %787 = fmul fast float %53, %53
  %788 = fmul fast float %54, %54
  %789 = fmul fast float %55, %55
  %790 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %787)  ; IsFinite(value)
  %791 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %788)  ; IsFinite(value)
  %792 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %789)  ; IsFinite(value)
  %793 = and i1 %790, %791
  %794 = and i1 %793, %792
  %795 = and i1 %786, %794
  %796 = fmul fast float %35, -5.000000e-01
  %797 = icmp ne i32 %57, 0
  %798 = fsub fast float 5.000000e-01, %34
  %799 = fsub fast float -0.000000e+00, %33
  %800 = select i1 %797, float %799, float %796
  %801 = fadd fast float %800, 5.000000e-01
  %802 = select i1 %797, float %798, float 5.000000e-01
  %803 = icmp ne i32 %58, 0
  %804 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %805 = and i1 %803, %804
  %806 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %801)  ; IsFinite(value)
  %807 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %802)  ; IsFinite(value)
  %808 = and i1 %806, %807
  %809 = and i1 %805, %808
  %810 = fcmp fast ogt float %801, 0.000000e+00
  %811 = fcmp fast ogt float %802, 0.000000e+00
  %812 = and i1 %811, %810
  %813 = and i1 %812, %809
  %814 = fcmp fast olt float %801, 1.000000e+00
  %815 = fcmp fast olt float %802, 1.000000e+00
  %816 = and i1 %815, %814
  %817 = and i1 %816, %813
  br i1 %817, label %818, label %872

; <label>:818                                     ; preds = %770
  %819 = call float @dx.op.unary.f32(i32 27, float %801)  ; Round_ni(value)
  %820 = call float @dx.op.unary.f32(i32 27, float %802)  ; Round_ni(value)
  %821 = fptosi float %819 to i32
  %822 = fptosi float %820 to i32
  %823 = call i32 @dx.op.binary.i32(i32 37, i32 %821, i32 0)  ; IMax(a,b)
  %824 = call i32 @dx.op.binary.i32(i32 37, i32 %822, i32 0)  ; IMax(a,b)
  %825 = call i32 @dx.op.binary.i32(i32 38, i32 %823, i32 0)  ; IMin(a,b)
  %826 = call i32 @dx.op.binary.i32(i32 38, i32 %824, i32 0)  ; IMin(a,b)
  %827 = add i32 %825, -1
  %828 = add i32 %826, -1
  %829 = call i32 @dx.op.binary.i32(i32 37, i32 %827, i32 0)  ; IMax(a,b)
  %830 = call i32 @dx.op.binary.i32(i32 37, i32 %828, i32 0)  ; IMax(a,b)
  %831 = and i32 %829, 2147483647
  %832 = and i32 %830, 2147483647
  %833 = uitofp i32 %831 to float
  %834 = uitofp i32 %832 to float
  %835 = fsub fast float %833, %800
  %836 = fsub fast float 5.000000e-01, %802
  %837 = fadd fast float %834, %836
  %838 = call float @dx.op.unary.f32(i32 6, float %835)  ; FAbs(value)
  %839 = call float @dx.op.unary.f32(i32 6, float %837)  ; FAbs(value)
  %840 = call i32 @dx.op.binary.i32(i32 38, i32 %825, i32 0)  ; IMin(a,b)
  %841 = call i32 @dx.op.binary.i32(i32 38, i32 %826, i32 0)  ; IMin(a,b)
  %842 = and i32 %840, 2147483647
  %843 = and i32 %841, 2147483647
  %844 = uitofp i32 %842 to float
  %845 = uitofp i32 %843 to float
  %846 = fsub fast float %844, %800
  %847 = fadd fast float %845, %836
  %848 = call float @dx.op.unary.f32(i32 6, float %846)  ; FAbs(value)
  %849 = call float @dx.op.unary.f32(i32 6, float %847)  ; FAbs(value)
  %850 = fcmp fast olt float %848, %838
  %851 = select i1 %850, i32 %840, i32 %829
  %852 = select i1 %850, float %848, float %838
  %853 = fcmp fast olt float %849, %839
  %854 = select i1 %853, i32 %841, i32 %830
  %855 = select i1 %853, float %849, float %839
  %856 = add i32 %825, 1
  %857 = add i32 %826, 1
  %858 = call i32 @dx.op.binary.i32(i32 38, i32 %856, i32 0)  ; IMin(a,b)
  %859 = call i32 @dx.op.binary.i32(i32 38, i32 %857, i32 0)  ; IMin(a,b)
  %860 = and i32 %858, 2147483647
  %861 = and i32 %859, 2147483647
  %862 = uitofp i32 %860 to float
  %863 = uitofp i32 %861 to float
  %864 = fsub fast float %862, %800
  %865 = fadd fast float %863, %836
  %866 = call float @dx.op.unary.f32(i32 6, float %864)  ; FAbs(value)
  %867 = call float @dx.op.unary.f32(i32 6, float %865)  ; FAbs(value)
  %868 = fcmp fast olt float %866, %852
  %869 = select i1 %868, i32 %858, i32 %851
  %870 = fcmp fast olt float %867, %855
  %871 = select i1 %870, i32 %859, i32 %854
  br label %872

; <label>:872                                     ; preds = %818, %770
  %873 = phi i32 [ 0, %770 ], [ %869, %818 ]
  %874 = phi i32 [ 0, %770 ], [ %871, %818 ]
  %875 = and i32 %873, 2147483647
  %876 = and i32 %874, 2147483647
  %877 = uitofp i32 %875 to float
  %878 = uitofp i32 %876 to float
  %879 = fadd fast float %877, 5.000000e-01
  %880 = fadd fast float %878, 5.000000e-01
  %881 = fmul fast float %879, 2.000000e+00
  %882 = fmul fast float %880, 2.000000e+00
  %883 = fadd fast float %882, -1.000000e+00
  %884 = fsub fast float 1.000000e+00, %35
  %885 = fsub fast float %884, %881
  %886 = fsub fast float -0.000000e+00, %883
  %887 = fsub fast float 5.000000e-01, %36
  %888 = call float @dx.op.dot3.f32(i32 55, float %885, float %886, float %887, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %889 = call float @dx.op.unary.f32(i32 6, float %888)  ; FAbs(value)
  %890 = fcmp fast olt float %889, 0x3F8EB851E0000000
  %891 = fmul fast float %885, %885
  %892 = fmul fast float %883, %883
  %893 = fmul fast float %887, %887
  %894 = fadd fast float %891, %893
  %895 = fadd fast float %894, %892
  %896 = call float @dx.op.unary.f32(i32 24, float %895)  ; Sqrt(value)
  %897 = fcmp fast olt float %896, 0x3F8EB851E0000000
  %898 = and i1 %890, %897
  %899 = and i1 %817, %898
  %900 = fcmp fast olt float %29, 5.000000e-01
  %901 = and i1 %900, %899
  %902 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %45)  ; IsFinite(value)
  %903 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %46)  ; IsFinite(value)
  %904 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %47)  ; IsFinite(value)
  %905 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %48)  ; IsFinite(value)
  %906 = and i1 %902, %903
  %907 = and i1 %906, %904
  %908 = and i1 %907, %905
  %909 = fcmp fast ogt float %48, 0.000000e+00
  %910 = and i1 %909, %908
  %911 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %912 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %19)  ; IsFinite(value)
  %913 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %20)  ; IsFinite(value)
  %914 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %21)  ; IsFinite(value)
  %915 = and i1 %911, %912
  %916 = and i1 %915, %913
  %917 = and i1 %916, %914
  %918 = and i1 %910, %917
  %919 = fcmp fast ogt float %20, 0.000000e+00
  %920 = and i1 %919, %918
  %921 = and i1 %901, %920
  br i1 %795, label %934, label %922

; <label>:922                                     ; preds = %872
  %923 = select i1 %921, float %45, float 0.000000e+00
  %924 = select i1 %921, float %46, float 0.000000e+00
  %925 = select i1 %921, float %47, float 0.000000e+00
  %926 = select i1 %921, float %48, float 0.000000e+00
  %927 = select i1 %921, float %18, float 0.000000e+00
  %928 = select i1 %921, float %19, float 0.000000e+00
  %929 = select i1 %921, float %20, float 0.000000e+00
  %930 = select i1 %921, float %21, float 0.000000e+00
  %931 = fcmp fast ogt float %28, 5.000000e-01
  br i1 %931, label %932, label %1450

; <label>:932                                     ; preds = %922
  %933 = call float @dx.op.binary.f32(i32 36, float %929, float 2.000000e+00)  ; FMin(a,b)
  br label %1450

; <label>:934                                     ; preds = %872
  %935 = zext i1 %921 to i32
  %936 = fcmp fast ogt float %30, 5.000000e-01
  %937 = select i1 %936, i32 0, i32 %935
  %938 = icmp eq i32 %937, 0
  br i1 %938, label %1364, label %939

; <label>:939                                     ; preds = %934
  %940 = call float @dx.op.unary.f32(i32 27, float %801)  ; Round_ni(value)
  %941 = call float @dx.op.unary.f32(i32 27, float %802)  ; Round_ni(value)
  %942 = fptosi float %940 to i32
  %943 = fptosi float %941 to i32
  %944 = call i32 @dx.op.binary.i32(i32 37, i32 %942, i32 0)  ; IMax(a,b)
  %945 = call i32 @dx.op.binary.i32(i32 37, i32 %943, i32 0)  ; IMax(a,b)
  %946 = call i32 @dx.op.binary.i32(i32 38, i32 %944, i32 0)  ; IMin(a,b)
  %947 = call i32 @dx.op.binary.i32(i32 38, i32 %945, i32 0)  ; IMin(a,b)
  %948 = add i32 %946, -1
  %949 = add i32 %947, -1
  %950 = call i32 @dx.op.binary.i32(i32 37, i32 %948, i32 0)  ; IMax(a,b)
  %951 = call i32 @dx.op.binary.i32(i32 37, i32 %949, i32 0)  ; IMax(a,b)
  %952 = and i32 %950, 2147483647
  %953 = and i32 %951, 2147483647
  %954 = uitofp i32 %952 to float
  %955 = uitofp i32 %953 to float
  %956 = fsub fast float %954, %800
  %957 = fsub fast float 5.000000e-01, %802
  %958 = fadd fast float %955, %957
  %959 = call float @dx.op.unary.f32(i32 6, float %956)  ; FAbs(value)
  %960 = call float @dx.op.unary.f32(i32 6, float %958)  ; FAbs(value)
  %961 = call i32 @dx.op.binary.i32(i32 38, i32 %946, i32 0)  ; IMin(a,b)
  %962 = call i32 @dx.op.binary.i32(i32 38, i32 %947, i32 0)  ; IMin(a,b)
  %963 = and i32 %961, 2147483647
  %964 = and i32 %962, 2147483647
  %965 = uitofp i32 %963 to float
  %966 = uitofp i32 %964 to float
  %967 = fsub fast float %965, %800
  %968 = fadd fast float %966, %957
  %969 = call float @dx.op.unary.f32(i32 6, float %967)  ; FAbs(value)
  %970 = call float @dx.op.unary.f32(i32 6, float %968)  ; FAbs(value)
  %971 = fcmp fast olt float %969, %959
  %972 = select i1 %971, i32 %961, i32 %950
  %973 = select i1 %971, float %969, float %959
  %974 = fcmp fast olt float %970, %960
  %975 = select i1 %974, i32 %962, i32 %951
  %976 = select i1 %974, float %970, float %960
  %977 = add i32 %946, 1
  %978 = add i32 %947, 1
  %979 = call i32 @dx.op.binary.i32(i32 38, i32 %977, i32 0)  ; IMin(a,b)
  %980 = call i32 @dx.op.binary.i32(i32 38, i32 %978, i32 0)  ; IMin(a,b)
  %981 = and i32 %979, 2147483647
  %982 = and i32 %980, 2147483647
  %983 = uitofp i32 %981 to float
  %984 = uitofp i32 %982 to float
  %985 = fsub fast float %983, %800
  %986 = fadd fast float %984, %957
  %987 = call float @dx.op.unary.f32(i32 6, float %985)  ; FAbs(value)
  %988 = call float @dx.op.unary.f32(i32 6, float %986)  ; FAbs(value)
  %989 = fcmp fast olt float %987, %973
  %990 = select i1 %989, i32 %979, i32 %972
  %991 = fcmp fast olt float %988, %976
  %992 = select i1 %991, i32 %980, i32 %975
  %993 = and i32 %990, 2147483647
  %994 = and i32 %992, 2147483647
  %995 = uitofp i32 %993 to float
  %996 = uitofp i32 %994 to float
  %997 = fadd fast float %995, 5.000000e-01
  %998 = fadd fast float %996, 5.000000e-01
  %999 = fcmp fast olt float %801, %997
  br i1 %999, label %1000, label %1003

; <label>:1000                                    ; preds = %939
  %1001 = add nsw i32 %990, -1
  %1002 = call i32 @dx.op.binary.i32(i32 37, i32 %1001, i32 0)  ; IMax(a,b)
  br label %1006

; <label>:1003                                    ; preds = %939
  %1004 = add i32 %990, 1
  %1005 = call i32 @dx.op.binary.i32(i32 40, i32 %1004, i32 0)  ; UMin(a,b)
  br label %1006

; <label>:1006                                    ; preds = %1003, %1000
  %1007 = phi i32 [ %990, %1000 ], [ %1005, %1003 ]
  %1008 = phi i32 [ %1002, %1000 ], [ %990, %1003 ]
  %1009 = fcmp fast olt float %802, %998
  br i1 %1009, label %1010, label %1013

; <label>:1010                                    ; preds = %1006
  %1011 = add nsw i32 %992, -1
  %1012 = call i32 @dx.op.binary.i32(i32 37, i32 %1011, i32 0)  ; IMax(a,b)
  br label %1016

; <label>:1013                                    ; preds = %1006
  %1014 = add i32 %992, 1
  %1015 = call i32 @dx.op.binary.i32(i32 40, i32 %1014, i32 0)  ; UMin(a,b)
  br label %1016

; <label>:1016                                    ; preds = %1013, %1010
  %1017 = phi i32 [ %992, %1010 ], [ %1015, %1013 ]
  %1018 = phi i32 [ %1012, %1010 ], [ %992, %1013 ]
  %1019 = and i32 %1008, 2147483647
  %1020 = and i32 %1018, 2147483647
  %1021 = uitofp i32 %1019 to float
  %1022 = uitofp i32 %1020 to float
  %1023 = fadd fast float %1021, 5.000000e-01
  %1024 = fadd fast float %1022, 5.000000e-01
  %1025 = and i32 %1007, 2147483647
  %1026 = and i32 %1017, 2147483647
  %1027 = uitofp i32 %1025 to float
  %1028 = uitofp i32 %1026 to float
  %1029 = fadd fast float %1027, 5.000000e-01
  %1030 = fadd fast float %1028, 5.000000e-01
  %1031 = fcmp fast ogt float %1029, %1023
  %1032 = fsub fast float %801, %1023
  %1033 = fsub fast float %1029, %1023
  %1034 = fdiv fast float %1032, %1033
  %1035 = call float @dx.op.unary.f32(i32 7, float %1034)  ; Saturate(value)
  %1036 = select i1 %1031, float %1035, float 0.000000e+00
  %1037 = fcmp fast ogt float %1030, %1024
  %1038 = fsub fast float %802, %1024
  %1039 = fsub fast float %1030, %1024
  %1040 = fdiv fast float %1038, %1039
  %1041 = call float @dx.op.unary.f32(i32 7, float %1040)  ; Saturate(value)
  %1042 = select i1 %1037, float %1041, float 0.000000e+00
  %1043 = fsub fast float 1.000000e+00, %1036
  %1044 = fsub fast float 1.000000e+00, %1042
  %1045 = fmul fast float %1044, %1043
  %1046 = fcmp fast ugt float %1045, 0.000000e+00
  br i1 %1046, label %1060, label %1091

; <label>:1047                                    ; preds = %1161, %1149, %1103, %1091
  %1048 = phi i1 [ true, %1091 ], [ false, %1103 ], [ true, %1149 ], [ false, %1161 ]
  %1049 = phi i1 [ false, %1091 ], [ true, %1103 ], [ false, %1149 ], [ %1151, %1161 ]
  %1050 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1162, %1161 ]
  %1051 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1163, %1161 ]
  %1052 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1164, %1161 ]
  %1053 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1165, %1161 ]
  %1054 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1166, %1161 ]
  %1055 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1167, %1161 ]
  %1056 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1168, %1161 ]
  %1057 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1169, %1161 ]
  %1058 = phi float [ 0.000000e+00, %1091 ], [ 0.000000e+00, %1103 ], [ 0.000000e+00, %1149 ], [ %1170, %1161 ]
  %1059 = or i1 %1048, %1049
  br i1 %1059, label %1348, label %1184

; <label>:1060                                    ; preds = %1016
  %1061 = icmp ne i32 %1008, %873
  %1062 = icmp ne i32 %1018, %874
  %1063 = or i1 %1061, %1062
  br i1 %1063, label %1064, label %1081

; <label>:1064                                    ; preds = %1060
  %1065 = fmul fast float %1023, 2.000000e+00
  %1066 = fmul fast float %1024, 2.000000e+00
  %1067 = fadd fast float %1066, -1.000000e+00
  %1068 = fsub fast float %884, %1065
  %1069 = fsub fast float -0.000000e+00, %1067
  %1070 = call float @dx.op.dot3.f32(i32 55, float %1068, float %1069, float %887, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1071 = call float @dx.op.unary.f32(i32 6, float %1070)  ; FAbs(value)
  %1072 = fmul fast float %1068, %1068
  %1073 = fmul fast float %1067, %1067
  %1074 = fadd fast float %1072, %893
  %1075 = fadd fast float %1074, %1073
  %1076 = call float @dx.op.unary.f32(i32 24, float %1075)  ; Sqrt(value)
  %1077 = fcmp uge float %1071, 0x3F8EB851E0000000
  %1078 = fcmp uge float %1076, 0x3F8EB851E0000000
  %1079 = or i1 %1078, %1077
  %1080 = xor i1 %920, true
  br label %1081

; <label>:1081                                    ; preds = %1064, %1060
  %1082 = phi i1 [ %1080, %1064 ], [ false, %1060 ]
  %1083 = phi i1 [ %1079, %1064 ], [ false, %1060 ]
  %1084 = fmul fast float %1045, %45
  %1085 = fmul fast float %1045, %46
  %1086 = fmul fast float %1045, %47
  %1087 = fmul fast float %1045, %48
  %1088 = fmul fast float %1045, %18
  %1089 = fmul fast float %1045, %19
  %1090 = fmul fast float %1045, %21
  br label %1091

; <label>:1091                                    ; preds = %1081, %1016
  %1092 = phi i1 [ %1082, %1081 ], [ false, %1016 ]
  %1093 = phi i1 [ %1083, %1081 ], [ false, %1016 ]
  %1094 = phi float [ %1084, %1081 ], [ 0.000000e+00, %1016 ]
  %1095 = phi float [ %1085, %1081 ], [ 0.000000e+00, %1016 ]
  %1096 = phi float [ %1086, %1081 ], [ 0.000000e+00, %1016 ]
  %1097 = phi float [ %1087, %1081 ], [ 0.000000e+00, %1016 ]
  %1098 = phi float [ %1088, %1081 ], [ 0.000000e+00, %1016 ]
  %1099 = phi float [ %1089, %1081 ], [ 0.000000e+00, %1016 ]
  %1100 = phi float [ %1090, %1081 ], [ 0.000000e+00, %1016 ]
  %1101 = phi float [ %1045, %1081 ], [ 0.000000e+00, %1016 ]
  %1102 = phi float [ %20, %1081 ], [ 0.000000e+00, %1016 ]
  br i1 %1092, label %1047, label %1103

; <label>:1103                                    ; preds = %1091
  br i1 %1093, label %1047, label %1104

; <label>:1104                                    ; preds = %1103
  %1105 = fmul fast float %1044, %1036
  %1106 = fcmp fast ugt float %1105, 0.000000e+00
  br i1 %1106, label %1107, label %1149

; <label>:1107                                    ; preds = %1104
  %1108 = icmp ne i32 %1007, %873
  %1109 = icmp ne i32 %1018, %874
  %1110 = or i1 %1108, %1109
  br i1 %1110, label %1111, label %1128

; <label>:1111                                    ; preds = %1107
  %1112 = fmul fast float %1029, 2.000000e+00
  %1113 = fmul fast float %1024, 2.000000e+00
  %1114 = fadd fast float %1113, -1.000000e+00
  %1115 = fsub fast float %884, %1112
  %1116 = fsub fast float -0.000000e+00, %1114
  %1117 = call float @dx.op.dot3.f32(i32 55, float %1115, float %1116, float %887, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1118 = call float @dx.op.unary.f32(i32 6, float %1117)  ; FAbs(value)
  %1119 = fmul fast float %1115, %1115
  %1120 = fmul fast float %1114, %1114
  %1121 = fadd fast float %1119, %893
  %1122 = fadd fast float %1121, %1120
  %1123 = call float @dx.op.unary.f32(i32 24, float %1122)  ; Sqrt(value)
  %1124 = fcmp uge float %1118, 0x3F8EB851E0000000
  %1125 = fcmp uge float %1123, 0x3F8EB851E0000000
  %1126 = or i1 %1125, %1124
  %1127 = xor i1 %920, true
  br label %1128

; <label>:1128                                    ; preds = %1111, %1107
  %1129 = phi i1 [ %1127, %1111 ], [ false, %1107 ]
  %1130 = phi i1 [ %1126, %1111 ], [ false, %1107 ]
  %1131 = fcmp fast oeq float %1101, 0.000000e+00
  %1132 = call float @dx.op.binary.f32(i32 36, float %1102, float %20)  ; FMin(a,b)
  %1133 = select i1 %1131, float %20, float %1132
  %1134 = fmul fast float %1105, %45
  %1135 = fmul fast float %1105, %46
  %1136 = fmul fast float %1105, %47
  %1137 = fmul fast float %1105, %48
  %1138 = fadd fast float %1094, %1134
  %1139 = fadd fast float %1095, %1135
  %1140 = fadd fast float %1096, %1136
  %1141 = fadd fast float %1097, %1137
  %1142 = fmul fast float %1105, %18
  %1143 = fmul fast float %1105, %19
  %1144 = fmul fast float %1105, %21
  %1145 = fadd fast float %1098, %1142
  %1146 = fadd fast float %1099, %1143
  %1147 = fadd fast float %1100, %1144
  %1148 = fadd fast float %1101, %1105
  br label %1149

; <label>:1149                                    ; preds = %1128, %1104
  %1150 = phi i1 [ %1129, %1128 ], [ false, %1104 ]
  %1151 = phi i1 [ %1130, %1128 ], [ false, %1104 ]
  %1152 = phi float [ %1138, %1128 ], [ %1094, %1104 ]
  %1153 = phi float [ %1139, %1128 ], [ %1095, %1104 ]
  %1154 = phi float [ %1140, %1128 ], [ %1096, %1104 ]
  %1155 = phi float [ %1141, %1128 ], [ %1097, %1104 ]
  %1156 = phi float [ %1145, %1128 ], [ %1098, %1104 ]
  %1157 = phi float [ %1146, %1128 ], [ %1099, %1104 ]
  %1158 = phi float [ %1147, %1128 ], [ %1100, %1104 ]
  %1159 = phi float [ %1148, %1128 ], [ %1101, %1104 ]
  %1160 = phi float [ %1133, %1128 ], [ %1102, %1104 ]
  br i1 %1150, label %1047, label %1161

; <label>:1161                                    ; preds = %1149
  %1162 = select i1 %1151, float 0.000000e+00, float %1160
  %1163 = select i1 %1151, float 0.000000e+00, float %1159
  %1164 = select i1 %1151, float 0.000000e+00, float %1158
  %1165 = select i1 %1151, float 0.000000e+00, float %1157
  %1166 = select i1 %1151, float 0.000000e+00, float %1156
  %1167 = select i1 %1151, float 0.000000e+00, float %1155
  %1168 = select i1 %1151, float 0.000000e+00, float %1154
  %1169 = select i1 %1151, float 0.000000e+00, float %1153
  %1170 = select i1 %1151, float 0.000000e+00, float %1152
  br label %1047

; <label>:1171                                    ; preds = %1299, %1287, %1241, %1229
  %1172 = phi i1 [ true, %1229 ], [ false, %1241 ], [ true, %1287 ], [ false, %1299 ]
  %1173 = phi i1 [ false, %1229 ], [ true, %1241 ], [ false, %1287 ], [ %1289, %1299 ]
  %1174 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1300, %1299 ]
  %1175 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1301, %1299 ]
  %1176 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1302, %1299 ]
  %1177 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1303, %1299 ]
  %1178 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1304, %1299 ]
  %1179 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1305, %1299 ]
  %1180 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1306, %1299 ]
  %1181 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1307, %1299 ]
  %1182 = phi float [ 0.000000e+00, %1229 ], [ 0.000000e+00, %1241 ], [ 0.000000e+00, %1287 ], [ %1308, %1299 ]
  %1183 = or i1 %1172, %1173
  br i1 %1183, label %1348, label %1309

; <label>:1184                                    ; preds = %1047
  %1185 = fmul fast float %1042, %1043
  %1186 = fcmp fast ugt float %1185, 0.000000e+00
  br i1 %1186, label %1187, label %1229

; <label>:1187                                    ; preds = %1184
  %1188 = icmp ne i32 %1008, %873
  %1189 = icmp ne i32 %1017, %874
  %1190 = or i1 %1188, %1189
  br i1 %1190, label %1191, label %1208

; <label>:1191                                    ; preds = %1187
  %1192 = fmul fast float %1023, 2.000000e+00
  %1193 = fmul fast float %1030, 2.000000e+00
  %1194 = fadd fast float %1193, -1.000000e+00
  %1195 = fsub fast float %884, %1192
  %1196 = fsub fast float -0.000000e+00, %1194
  %1197 = call float @dx.op.dot3.f32(i32 55, float %1195, float %1196, float %887, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1198 = call float @dx.op.unary.f32(i32 6, float %1197)  ; FAbs(value)
  %1199 = fmul fast float %1195, %1195
  %1200 = fmul fast float %1194, %1194
  %1201 = fadd fast float %1199, %893
  %1202 = fadd fast float %1201, %1200
  %1203 = call float @dx.op.unary.f32(i32 24, float %1202)  ; Sqrt(value)
  %1204 = fcmp uge float %1198, 0x3F8EB851E0000000
  %1205 = fcmp uge float %1203, 0x3F8EB851E0000000
  %1206 = or i1 %1205, %1204
  %1207 = xor i1 %920, true
  br label %1208

; <label>:1208                                    ; preds = %1191, %1187
  %1209 = phi i1 [ %1207, %1191 ], [ false, %1187 ]
  %1210 = phi i1 [ %1206, %1191 ], [ false, %1187 ]
  %1211 = fcmp fast oeq float %1051, 0.000000e+00
  %1212 = call float @dx.op.binary.f32(i32 36, float %1050, float %20)  ; FMin(a,b)
  %1213 = select i1 %1211, float %20, float %1212
  %1214 = fmul fast float %1185, %45
  %1215 = fmul fast float %1185, %46
  %1216 = fmul fast float %1185, %47
  %1217 = fmul fast float %1185, %48
  %1218 = fadd fast float %1058, %1214
  %1219 = fadd fast float %1057, %1215
  %1220 = fadd fast float %1056, %1216
  %1221 = fadd fast float %1055, %1217
  %1222 = fmul fast float %1185, %18
  %1223 = fmul fast float %1185, %19
  %1224 = fmul fast float %1185, %21
  %1225 = fadd fast float %1054, %1222
  %1226 = fadd fast float %1053, %1223
  %1227 = fadd fast float %1052, %1224
  %1228 = fadd fast float %1051, %1185
  br label %1229

; <label>:1229                                    ; preds = %1208, %1184
  %1230 = phi i1 [ %1209, %1208 ], [ false, %1184 ]
  %1231 = phi i1 [ %1210, %1208 ], [ false, %1184 ]
  %1232 = phi float [ %1218, %1208 ], [ %1058, %1184 ]
  %1233 = phi float [ %1219, %1208 ], [ %1057, %1184 ]
  %1234 = phi float [ %1220, %1208 ], [ %1056, %1184 ]
  %1235 = phi float [ %1221, %1208 ], [ %1055, %1184 ]
  %1236 = phi float [ %1225, %1208 ], [ %1054, %1184 ]
  %1237 = phi float [ %1226, %1208 ], [ %1053, %1184 ]
  %1238 = phi float [ %1227, %1208 ], [ %1052, %1184 ]
  %1239 = phi float [ %1228, %1208 ], [ %1051, %1184 ]
  %1240 = phi float [ %1213, %1208 ], [ %1050, %1184 ]
  br i1 %1230, label %1171, label %1241

; <label>:1241                                    ; preds = %1229
  br i1 %1231, label %1171, label %1242

; <label>:1242                                    ; preds = %1241
  %1243 = fmul fast float %1042, %1036
  %1244 = fcmp fast ugt float %1243, 0.000000e+00
  br i1 %1244, label %1245, label %1287

; <label>:1245                                    ; preds = %1242
  %1246 = icmp ne i32 %1007, %873
  %1247 = icmp ne i32 %1017, %874
  %1248 = or i1 %1246, %1247
  br i1 %1248, label %1249, label %1266

; <label>:1249                                    ; preds = %1245
  %1250 = fmul fast float %1029, 2.000000e+00
  %1251 = fmul fast float %1030, 2.000000e+00
  %1252 = fadd fast float %1251, -1.000000e+00
  %1253 = fsub fast float %884, %1250
  %1254 = fsub fast float -0.000000e+00, %1252
  %1255 = call float @dx.op.dot3.f32(i32 55, float %1253, float %1254, float %887, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1256 = call float @dx.op.unary.f32(i32 6, float %1255)  ; FAbs(value)
  %1257 = fmul fast float %1253, %1253
  %1258 = fmul fast float %1252, %1252
  %1259 = fadd fast float %1257, %893
  %1260 = fadd fast float %1259, %1258
  %1261 = call float @dx.op.unary.f32(i32 24, float %1260)  ; Sqrt(value)
  %1262 = fcmp uge float %1256, 0x3F8EB851E0000000
  %1263 = fcmp uge float %1261, 0x3F8EB851E0000000
  %1264 = or i1 %1263, %1262
  %1265 = xor i1 %920, true
  br label %1266

; <label>:1266                                    ; preds = %1249, %1245
  %1267 = phi i1 [ %1265, %1249 ], [ false, %1245 ]
  %1268 = phi i1 [ %1264, %1249 ], [ false, %1245 ]
  %1269 = fcmp fast oeq float %1239, 0.000000e+00
  %1270 = call float @dx.op.binary.f32(i32 36, float %1240, float %20)  ; FMin(a,b)
  %1271 = select i1 %1269, float %20, float %1270
  %1272 = fmul fast float %1243, %45
  %1273 = fmul fast float %1243, %46
  %1274 = fmul fast float %1243, %47
  %1275 = fmul fast float %1243, %48
  %1276 = fadd fast float %1232, %1272
  %1277 = fadd fast float %1233, %1273
  %1278 = fadd fast float %1234, %1274
  %1279 = fadd fast float %1235, %1275
  %1280 = fmul fast float %1243, %18
  %1281 = fmul fast float %1243, %19
  %1282 = fmul fast float %1243, %21
  %1283 = fadd fast float %1236, %1280
  %1284 = fadd fast float %1237, %1281
  %1285 = fadd fast float %1238, %1282
  %1286 = fadd fast float %1239, %1243
  br label %1287

; <label>:1287                                    ; preds = %1266, %1242
  %1288 = phi i1 [ %1267, %1266 ], [ false, %1242 ]
  %1289 = phi i1 [ %1268, %1266 ], [ false, %1242 ]
  %1290 = phi float [ %1276, %1266 ], [ %1232, %1242 ]
  %1291 = phi float [ %1277, %1266 ], [ %1233, %1242 ]
  %1292 = phi float [ %1278, %1266 ], [ %1234, %1242 ]
  %1293 = phi float [ %1279, %1266 ], [ %1235, %1242 ]
  %1294 = phi float [ %1283, %1266 ], [ %1236, %1242 ]
  %1295 = phi float [ %1284, %1266 ], [ %1237, %1242 ]
  %1296 = phi float [ %1285, %1266 ], [ %1238, %1242 ]
  %1297 = phi float [ %1286, %1266 ], [ %1239, %1242 ]
  %1298 = phi float [ %1271, %1266 ], [ %1240, %1242 ]
  br i1 %1288, label %1171, label %1299

; <label>:1299                                    ; preds = %1287
  %1300 = select i1 %1289, float 0.000000e+00, float %1298
  %1301 = select i1 %1289, float 0.000000e+00, float %1297
  %1302 = select i1 %1289, float 0.000000e+00, float %1296
  %1303 = select i1 %1289, float 0.000000e+00, float %1295
  %1304 = select i1 %1289, float 0.000000e+00, float %1294
  %1305 = select i1 %1289, float 0.000000e+00, float %1293
  %1306 = select i1 %1289, float 0.000000e+00, float %1292
  %1307 = select i1 %1289, float 0.000000e+00, float %1291
  %1308 = select i1 %1289, float 0.000000e+00, float %1290
  br label %1171

; <label>:1309                                    ; preds = %1171
  %1310 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1175)  ; IsFinite(value)
  %1311 = xor i1 %1310, true
  %1312 = fcmp fast ole float %1175, 0.000000e+00
  %1313 = or i1 %1312, %1311
  br i1 %1313, label %1348, label %1314

; <label>:1314                                    ; preds = %1309
  %1315 = fdiv fast float %1182, %1175
  %1316 = fdiv fast float %1181, %1175
  %1317 = fdiv fast float %1180, %1175
  %1318 = fdiv fast float %1179, %1175
  %1319 = fdiv fast float %1178, %1175
  %1320 = fdiv fast float %1177, %1175
  %1321 = fdiv fast float %1176, %1175
  %1322 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1315)  ; IsFinite(value)
  %1323 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1316)  ; IsFinite(value)
  %1324 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1317)  ; IsFinite(value)
  %1325 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1318)  ; IsFinite(value)
  %1326 = and i1 %1322, %1323
  %1327 = and i1 %1326, %1324
  %1328 = and i1 %1327, %1325
  %1329 = fcmp fast ogt float %1318, 0.000000e+00
  %1330 = and i1 %1329, %1328
  %1331 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1319)  ; IsFinite(value)
  %1332 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1320)  ; IsFinite(value)
  %1333 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1174)  ; IsFinite(value)
  %1334 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1321)  ; IsFinite(value)
  %1335 = and i1 %1331, %1332
  %1336 = and i1 %1335, %1333
  %1337 = and i1 %1336, %1334
  %1338 = and i1 %1330, %1337
  %1339 = fcmp fast ogt float %1174, 0.000000e+00
  %1340 = and i1 %1339, %1338
  %1341 = select i1 %1340, float %1315, float %45
  %1342 = select i1 %1340, float %1316, float %46
  %1343 = select i1 %1340, float %1317, float %47
  %1344 = select i1 %1340, float %1318, float %48
  %1345 = select i1 %1340, float %1319, float %18
  %1346 = select i1 %1340, float %1320, float %19
  %1347 = select i1 %1340, float %1174, float %20
  br label %1348

; <label>:1348                                    ; preds = %1314, %1309, %1171, %1047
  %1349 = phi i1 [ false, %1309 ], [ %1340, %1314 ], [ false, %1171 ], [ false, %1047 ]
  %1350 = phi float [ %45, %1309 ], [ %1341, %1314 ], [ %45, %1171 ], [ %45, %1047 ]
  %1351 = phi float [ %46, %1309 ], [ %1342, %1314 ], [ %46, %1171 ], [ %46, %1047 ]
  %1352 = phi float [ %47, %1309 ], [ %1343, %1314 ], [ %47, %1171 ], [ %47, %1047 ]
  %1353 = phi float [ %48, %1309 ], [ %1344, %1314 ], [ %48, %1171 ], [ %48, %1047 ]
  %1354 = phi float [ %18, %1309 ], [ %1345, %1314 ], [ %18, %1171 ], [ %18, %1047 ]
  %1355 = phi float [ %19, %1309 ], [ %1346, %1314 ], [ %19, %1171 ], [ %19, %1047 ]
  %1356 = phi float [ %20, %1309 ], [ %1347, %1314 ], [ %20, %1171 ], [ %20, %1047 ]
  %1357 = select i1 %1349, float %1350, float %45
  %1358 = select i1 %1349, float %1351, float %46
  %1359 = select i1 %1349, float %1352, float %47
  %1360 = select i1 %1349, float %1353, float %48
  %1361 = select i1 %1349, float %1354, float %18
  %1362 = select i1 %1349, float %1355, float %19
  %1363 = select i1 %1349, float %1356, float %20
  br label %1364

; <label>:1364                                    ; preds = %1348, %934
  %1365 = phi float [ %45, %934 ], [ %1357, %1348 ]
  %1366 = phi float [ %46, %934 ], [ %1358, %1348 ]
  %1367 = phi float [ %47, %934 ], [ %1359, %1348 ]
  %1368 = phi float [ %48, %934 ], [ %1360, %1348 ]
  %1369 = phi float [ %18, %934 ], [ %1361, %1348 ]
  %1370 = phi float [ %19, %934 ], [ %1362, %1348 ]
  %1371 = phi float [ %20, %934 ], [ %1363, %1348 ]
  %1372 = icmp ne i32 %937, 0
  %1373 = select i1 %1372, float %1368, float %56
  %1374 = select i1 %1372, float %1369, float %781
  %1375 = select i1 %1372, float %1370, float %784
  %1376 = fcmp fast ogt float %28, 5.000000e-01
  %1377 = select i1 %1372, float %1367, float %55
  %1378 = select i1 %1372, float %1366, float %54
  %1379 = select i1 %1372, float %1365, float %53
  %1380 = fadd fast float %53, 0x3FA47AE140000000
  %1381 = fadd fast float %54, 0x3FA47AE140000000
  %1382 = fadd fast float %55, 0x3FA47AE140000000
  %1383 = fadd fast float %53, 0xBFA47AE140000000
  %1384 = fadd fast float %54, 0xBFA47AE140000000
  %1385 = fadd fast float %55, 0xBFA47AE140000000
  %1386 = call float @dx.op.binary.f32(i32 35, float %1379, float %1383)  ; FMax(a,b)
  %1387 = call float @dx.op.binary.f32(i32 35, float %1378, float %1384)  ; FMax(a,b)
  %1388 = call float @dx.op.binary.f32(i32 35, float %1377, float %1385)  ; FMax(a,b)
  %1389 = call float @dx.op.binary.f32(i32 36, float %1386, float %1380)  ; FMin(a,b)
  %1390 = call float @dx.op.binary.f32(i32 36, float %1387, float %1381)  ; FMin(a,b)
  %1391 = call float @dx.op.binary.f32(i32 36, float %1388, float %1382)  ; FMin(a,b)
  %1392 = sitofp i32 %59 to float
  %1393 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %1392)  ; FMin(a,b)
  %1394 = select i1 %1376, float %1393, float %1392
  %1395 = fadd fast float %1371, 1.000000e+00
  %1396 = select i1 %1372, float %1395, float 1.000000e+00
  %1397 = call float @dx.op.binary.f32(i32 36, float %1396, float %1394)  ; FMin(a,b)
  %1398 = select i1 %1372, float %1397, float 1.000000e+00
  %1399 = fdiv fast float 1.000000e+00, %1398
  %1400 = call float @dx.op.binary.f32(i32 35, float %40, float %1399)  ; FMax(a,b)
  %1401 = select i1 %1372, float %1400, float 1.000000e+00
  %1402 = fsub fast float %56, %1373
  %1403 = call float @dx.op.unary.f32(i32 6, float %1402)  ; FAbs(value)
  %1404 = fmul fast float %1403, 2.500000e-01
  %1405 = select i1 %1372, float %1404, float 1.000000e+00
  %1406 = call float @dx.op.binary.f32(i32 35, float %1401, float %1405)  ; FMax(a,b)
  %1407 = fsub fast float %781, %1374
  %1408 = fsub fast float %784, %1375
  %1409 = fmul fast float %1406, %1407
  %1410 = fmul fast float %1406, %1408
  %1411 = fadd fast float %1409, %1374
  %1412 = fadd fast float %1410, %1375
  %1413 = fsub fast float %53, %1389
  %1414 = fsub fast float %54, %1390
  %1415 = fsub fast float %55, %1391
  %1416 = fmul fast float %1406, %1413
  %1417 = fmul fast float %1406, %1414
  %1418 = fmul fast float %1406, %1415
  %1419 = fmul fast float %1406, %1402
  %1420 = fadd fast float %1416, %1389
  %1421 = fadd fast float %1417, %1390
  %1422 = fadd fast float %1418, %1391
  %1423 = fadd fast float %1419, %1373
  %1424 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1420)  ; IsFinite(value)
  %1425 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1421)  ; IsFinite(value)
  %1426 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1422)  ; IsFinite(value)
  %1427 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1423)  ; IsFinite(value)
  %1428 = and i1 %1424, %1425
  %1429 = and i1 %1428, %1426
  %1430 = and i1 %1429, %1427
  %1431 = fcmp fast ogt float %1423, 0.000000e+00
  %1432 = and i1 %1431, %1430
  %1433 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1411)  ; IsFinite(value)
  %1434 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1412)  ; IsFinite(value)
  %1435 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1398)  ; IsFinite(value)
  %1436 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %1437 = and i1 %1433, %1434
  %1438 = and i1 %1437, %1435
  %1439 = and i1 %1438, %1436
  %1440 = and i1 %1432, %1439
  %1441 = fcmp fast ogt float %1398, 0.000000e+00
  %1442 = and i1 %1441, %1440
  %1443 = select i1 %1442, float %1420, float 0.000000e+00
  %1444 = select i1 %1442, float %1421, float 0.000000e+00
  %1445 = select i1 %1442, float %1422, float 0.000000e+00
  %1446 = select i1 %1442, float %1423, float 0.000000e+00
  %1447 = select i1 %1442, float %1411, float 0.000000e+00
  %1448 = select i1 %1442, float %1412, float 0.000000e+00
  %1449 = select i1 %1442, float %1398, float 0.000000e+00
  br label %1450

; <label>:1450                                    ; preds = %1364, %932, %922
  %1451 = phi float [ %923, %932 ], [ %923, %922 ], [ %1443, %1364 ]
  %1452 = phi float [ %924, %932 ], [ %924, %922 ], [ %1444, %1364 ]
  %1453 = phi float [ %925, %932 ], [ %925, %922 ], [ %1445, %1364 ]
  %1454 = phi float [ %926, %932 ], [ %926, %922 ], [ %1446, %1364 ]
  %1455 = phi float [ %927, %932 ], [ %927, %922 ], [ %1447, %1364 ]
  %1456 = phi float [ %928, %932 ], [ %928, %922 ], [ %1448, %1364 ]
  %1457 = phi float [ %933, %932 ], [ %929, %922 ], [ %1449, %1364 ]
  %1458 = phi float [ %930, %932 ], [ %930, %922 ], [ 0.000000e+00, %1364 ]
  %1459 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1451)  ; LegacyF32ToF16(value)
  %1460 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1452)  ; LegacyF32ToF16(value)
  %1461 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1453)  ; LegacyF32ToF16(value)
  %1462 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1454)  ; LegacyF32ToF16(value)
  %1463 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1459)  ; LegacyF16ToF32(value)
  %1464 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1460)  ; LegacyF16ToF32(value)
  %1465 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1461)  ; LegacyF16ToF32(value)
  %1466 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1462)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %1451, float %1452, float %1453, float %1454, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %1455, float %1456, float %1457, float %1458, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %1463, float %1464, float %1465, float %1466, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %1455, float %1456, float %1457, float %1458, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %1468

; <label>:1467                                    ; preds = %751
  br label %1468

; <label>:1468                                    ; preds = %1467, %1450, %0
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
