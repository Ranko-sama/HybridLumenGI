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
; shader hash: 7c6f2fde5b17cfe5353e4a0b89c53beb
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
  br i1 %10, label %1625, label %11

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
  br i1 %61, label %62, label %902

; <label>:62                                      ; preds = %11
  br label %63

; <label>:63                                      ; preds = %895, %62
  %64 = phi i32 [ %901, %895 ], [ 1, %62 ]
  %65 = phi i32 [ %900, %895 ], [ 11, %62 ]
  %66 = phi i32 [ %899, %895 ], [ 7, %62 ]
  %67 = phi float [ %898, %895 ], [ 1.000000e+00, %62 ]
  %68 = phi float [ %897, %895 ], [ 0.000000e+00, %62 ]
  %69 = phi float [ %896, %895 ], [ 0.000000e+00, %62 ]
  %70 = phi float [ %889, %895 ], [ %46, %62 ]
  %71 = phi float [ %890, %895 ], [ %47, %62 ]
  %72 = phi float [ %891, %895 ], [ %48, %62 ]
  %73 = phi float [ %892, %895 ], [ %49, %62 ]
  %74 = phi float [ %881, %895 ], [ %18, %62 ]
  %75 = phi float [ %882, %895 ], [ %19, %62 ]
  %76 = phi float [ %883, %895 ], [ %20, %62 ]
  %77 = phi float [ %884, %895 ], [ %21, %62 ]
  %78 = phi i32 [ %893, %895 ], [ 0, %62 ]
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
  br i1 %336, label %337, label %876

; <label>:337                                     ; preds = %327
  %338 = call float @dx.op.binary.f32(i32 36, float %334, float 2.000000e+00)  ; FMin(a,b)
  br label %876

; <label>:339                                     ; preds = %266
  %340 = zext i1 %326 to i32
  %341 = fcmp fast ogt float %30, 5.000000e-01
  %342 = select i1 %341, i32 0, i32 %340
  %343 = icmp eq i32 %342, 0
  br i1 %343, label %790, label %344

; <label>:344                                     ; preds = %339
  %345 = call float @dx.op.unary.f32(i32 27, float %192)  ; Round_ni(value)
  %346 = call float @dx.op.unary.f32(i32 27, float %193)  ; Round_ni(value)
  %347 = fptosi float %345 to i32
  %348 = fptosi float %346 to i32
  %349 = call i32 @dx.op.binary.i32(i32 37, i32 %347, i32 0)  ; IMax(a,b)
  %350 = call i32 @dx.op.binary.i32(i32 37, i32 %348, i32 0)  ; IMax(a,b)
  %351 = call i32 @dx.op.binary.i32(i32 38, i32 %349, i32 0)  ; IMin(a,b)
  %352 = call i32 @dx.op.binary.i32(i32 38, i32 %350, i32 0)  ; IMin(a,b)
  %353 = add i32 %351, -1
  %354 = add i32 %352, -1
  %355 = call i32 @dx.op.binary.i32(i32 37, i32 %353, i32 0)  ; IMax(a,b)
  %356 = call i32 @dx.op.binary.i32(i32 37, i32 %354, i32 0)  ; IMax(a,b)
  %357 = and i32 %355, 2147483647
  %358 = and i32 %356, 2147483647
  %359 = uitofp i32 %357 to float
  %360 = uitofp i32 %358 to float
  %361 = fsub fast float 5.000000e-01, %192
  %362 = fadd fast float %359, %361
  %363 = fsub fast float 5.000000e-01, %193
  %364 = fadd fast float %360, %363
  %365 = call float @dx.op.unary.f32(i32 6, float %362)  ; FAbs(value)
  %366 = call float @dx.op.unary.f32(i32 6, float %364)  ; FAbs(value)
  %367 = call i32 @dx.op.binary.i32(i32 38, i32 %351, i32 0)  ; IMin(a,b)
  %368 = call i32 @dx.op.binary.i32(i32 38, i32 %352, i32 0)  ; IMin(a,b)
  %369 = and i32 %367, 2147483647
  %370 = and i32 %368, 2147483647
  %371 = uitofp i32 %369 to float
  %372 = uitofp i32 %370 to float
  %373 = fadd fast float %371, %361
  %374 = fadd fast float %372, %363
  %375 = call float @dx.op.unary.f32(i32 6, float %373)  ; FAbs(value)
  %376 = call float @dx.op.unary.f32(i32 6, float %374)  ; FAbs(value)
  %377 = fcmp fast olt float %375, %365
  %378 = select i1 %377, i32 %367, i32 %355
  %379 = select i1 %377, float %375, float %365
  %380 = fcmp fast olt float %376, %366
  %381 = select i1 %380, i32 %368, i32 %356
  %382 = select i1 %380, float %376, float %366
  %383 = add i32 %351, 1
  %384 = add i32 %352, 1
  %385 = call i32 @dx.op.binary.i32(i32 38, i32 %383, i32 0)  ; IMin(a,b)
  %386 = call i32 @dx.op.binary.i32(i32 38, i32 %384, i32 0)  ; IMin(a,b)
  %387 = and i32 %385, 2147483647
  %388 = and i32 %386, 2147483647
  %389 = uitofp i32 %387 to float
  %390 = uitofp i32 %388 to float
  %391 = fadd fast float %389, %361
  %392 = fadd fast float %390, %363
  %393 = call float @dx.op.unary.f32(i32 6, float %391)  ; FAbs(value)
  %394 = call float @dx.op.unary.f32(i32 6, float %392)  ; FAbs(value)
  %395 = fcmp fast olt float %393, %379
  %396 = select i1 %395, i32 %385, i32 %378
  %397 = fcmp fast olt float %394, %382
  %398 = select i1 %397, i32 %386, i32 %381
  %399 = and i32 %396, 2147483647
  %400 = and i32 %398, 2147483647
  %401 = uitofp i32 %399 to float
  %402 = uitofp i32 %400 to float
  %403 = fadd fast float %401, 5.000000e-01
  %404 = fadd fast float %402, 5.000000e-01
  %405 = fcmp fast olt float %192, %403
  br i1 %405, label %406, label %409

; <label>:406                                     ; preds = %344
  %407 = add nsw i32 %396, -1
  %408 = call i32 @dx.op.binary.i32(i32 37, i32 %407, i32 0)  ; IMax(a,b)
  br label %412

; <label>:409                                     ; preds = %344
  %410 = add i32 %396, 1
  %411 = call i32 @dx.op.binary.i32(i32 40, i32 %410, i32 0)  ; UMin(a,b)
  br label %412

; <label>:412                                     ; preds = %409, %406
  %413 = phi i32 [ %396, %406 ], [ %411, %409 ]
  %414 = phi i32 [ %408, %406 ], [ %396, %409 ]
  %415 = fcmp fast olt float %193, %404
  br i1 %415, label %416, label %419

; <label>:416                                     ; preds = %412
  %417 = add nsw i32 %398, -1
  %418 = call i32 @dx.op.binary.i32(i32 37, i32 %417, i32 0)  ; IMax(a,b)
  br label %422

; <label>:419                                     ; preds = %412
  %420 = add i32 %398, 1
  %421 = call i32 @dx.op.binary.i32(i32 40, i32 %420, i32 0)  ; UMin(a,b)
  br label %422

; <label>:422                                     ; preds = %419, %416
  %423 = phi i32 [ %398, %416 ], [ %421, %419 ]
  %424 = phi i32 [ %418, %416 ], [ %398, %419 ]
  %425 = and i32 %414, 2147483647
  %426 = and i32 %424, 2147483647
  %427 = uitofp i32 %425 to float
  %428 = uitofp i32 %426 to float
  %429 = fadd fast float %427, 5.000000e-01
  %430 = fadd fast float %428, 5.000000e-01
  %431 = and i32 %413, 2147483647
  %432 = and i32 %423, 2147483647
  %433 = uitofp i32 %431 to float
  %434 = uitofp i32 %432 to float
  %435 = fadd fast float %433, 5.000000e-01
  %436 = fadd fast float %434, 5.000000e-01
  %437 = fcmp fast ogt float %435, %429
  %438 = fsub fast float %192, %429
  %439 = fsub fast float %435, %429
  %440 = fdiv fast float %438, %439
  %441 = call float @dx.op.unary.f32(i32 7, float %440)  ; Saturate(value)
  %442 = select i1 %437, float %441, float 0.000000e+00
  %443 = fcmp fast ogt float %436, %430
  %444 = fsub fast float %193, %430
  %445 = fsub fast float %436, %430
  %446 = fdiv fast float %444, %445
  %447 = call float @dx.op.unary.f32(i32 7, float %446)  ; Saturate(value)
  %448 = select i1 %443, float %447, float 0.000000e+00
  %449 = fsub fast float 1.000000e+00, %442
  %450 = fsub fast float 1.000000e+00, %448
  %451 = fmul fast float %450, %449
  %452 = fcmp fast ugt float %451, 0.000000e+00
  br i1 %452, label %466, label %502

; <label>:453                                     ; preds = %577, %565, %514, %502
  %454 = phi i1 [ true, %502 ], [ false, %514 ], [ true, %565 ], [ false, %577 ]
  %455 = phi i1 [ false, %502 ], [ true, %514 ], [ false, %565 ], [ %567, %577 ]
  %456 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %578, %577 ]
  %457 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %579, %577 ]
  %458 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %580, %577 ]
  %459 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %581, %577 ]
  %460 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %582, %577 ]
  %461 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %583, %577 ]
  %462 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %584, %577 ]
  %463 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %585, %577 ]
  %464 = phi float [ 0.000000e+00, %502 ], [ 0.000000e+00, %514 ], [ 0.000000e+00, %565 ], [ %586, %577 ]
  %465 = or i1 %454, %455
  br i1 %465, label %774, label %600

; <label>:466                                     ; preds = %422
  %467 = icmp ne i32 %414, %267
  %468 = icmp ne i32 %424, %268
  %469 = or i1 %467, %468
  br i1 %469, label %470, label %492

; <label>:470                                     ; preds = %466
  %471 = fmul fast float %429, 2.000000e+00
  %472 = fmul fast float %430, 2.000000e+00
  %473 = fsub fast float %283, %471
  %474 = fsub fast float %285, %472
  %475 = call float @dx.op.dot3.f32(i32 55, float %473, float %474, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %476 = call float @dx.op.unary.f32(i32 6, float %475)  ; FAbs(value)
  %477 = fcmp fast olt float %476, 0x3F8EB851E0000000
  %478 = and i1 %282, %477
  %479 = call float @dx.op.dot3.f32(i32 55, float %473, float %474, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %480 = call float @dx.op.unary.f32(i32 6, float %479)  ; FAbs(value)
  %481 = fcmp fast olt float %480, 0x3F8EB851E0000000
  %482 = and i1 %478, %481
  %483 = fmul fast float %473, %473
  %484 = fmul fast float %474, %474
  %485 = fadd fast float %483, %298
  %486 = fadd fast float %485, %484
  %487 = call float @dx.op.unary.f32(i32 24, float %486)  ; Sqrt(value)
  %488 = fcmp fast olt float %487, 0x3F8EB851E0000000
  %489 = and i1 %482, %488
  %490 = xor i1 %489, true
  %491 = xor i1 %325, true
  br label %492

; <label>:492                                     ; preds = %470, %466
  %493 = phi i1 [ %491, %470 ], [ false, %466 ]
  %494 = phi i1 [ %490, %470 ], [ false, %466 ]
  %495 = fmul fast float %451, %70
  %496 = fmul fast float %451, %71
  %497 = fmul fast float %451, %72
  %498 = fmul fast float %451, %73
  %499 = fmul fast float %451, %74
  %500 = fmul fast float %451, %75
  %501 = fmul fast float %451, %77
  br label %502

; <label>:502                                     ; preds = %492, %422
  %503 = phi i1 [ %493, %492 ], [ false, %422 ]
  %504 = phi i1 [ %494, %492 ], [ false, %422 ]
  %505 = phi float [ %495, %492 ], [ 0.000000e+00, %422 ]
  %506 = phi float [ %496, %492 ], [ 0.000000e+00, %422 ]
  %507 = phi float [ %497, %492 ], [ 0.000000e+00, %422 ]
  %508 = phi float [ %498, %492 ], [ 0.000000e+00, %422 ]
  %509 = phi float [ %499, %492 ], [ 0.000000e+00, %422 ]
  %510 = phi float [ %500, %492 ], [ 0.000000e+00, %422 ]
  %511 = phi float [ %501, %492 ], [ 0.000000e+00, %422 ]
  %512 = phi float [ %451, %492 ], [ 0.000000e+00, %422 ]
  %513 = phi float [ %76, %492 ], [ 0.000000e+00, %422 ]
  br i1 %503, label %453, label %514

; <label>:514                                     ; preds = %502
  br i1 %504, label %453, label %515

; <label>:515                                     ; preds = %514
  %516 = fmul fast float %450, %442
  %517 = fcmp fast ugt float %516, 0.000000e+00
  br i1 %517, label %518, label %565

; <label>:518                                     ; preds = %515
  %519 = icmp ne i32 %413, %267
  %520 = icmp ne i32 %424, %268
  %521 = or i1 %519, %520
  br i1 %521, label %522, label %544

; <label>:522                                     ; preds = %518
  %523 = fmul fast float %435, 2.000000e+00
  %524 = fmul fast float %430, 2.000000e+00
  %525 = fsub fast float %283, %523
  %526 = fsub fast float %285, %524
  %527 = call float @dx.op.dot3.f32(i32 55, float %525, float %526, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %528 = call float @dx.op.unary.f32(i32 6, float %527)  ; FAbs(value)
  %529 = fcmp fast olt float %528, 0x3F8EB851E0000000
  %530 = and i1 %282, %529
  %531 = call float @dx.op.dot3.f32(i32 55, float %525, float %526, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %532 = call float @dx.op.unary.f32(i32 6, float %531)  ; FAbs(value)
  %533 = fcmp fast olt float %532, 0x3F8EB851E0000000
  %534 = and i1 %530, %533
  %535 = fmul fast float %525, %525
  %536 = fmul fast float %526, %526
  %537 = fadd fast float %535, %298
  %538 = fadd fast float %537, %536
  %539 = call float @dx.op.unary.f32(i32 24, float %538)  ; Sqrt(value)
  %540 = fcmp fast olt float %539, 0x3F8EB851E0000000
  %541 = and i1 %534, %540
  %542 = xor i1 %541, true
  %543 = xor i1 %325, true
  br label %544

; <label>:544                                     ; preds = %522, %518
  %545 = phi i1 [ %543, %522 ], [ false, %518 ]
  %546 = phi i1 [ %542, %522 ], [ false, %518 ]
  %547 = fcmp fast oeq float %512, 0.000000e+00
  %548 = call float @dx.op.binary.f32(i32 36, float %513, float %76)  ; FMin(a,b)
  %549 = select i1 %547, float %76, float %548
  %550 = fmul fast float %516, %70
  %551 = fmul fast float %516, %71
  %552 = fmul fast float %516, %72
  %553 = fmul fast float %516, %73
  %554 = fadd fast float %505, %550
  %555 = fadd fast float %506, %551
  %556 = fadd fast float %507, %552
  %557 = fadd fast float %508, %553
  %558 = fmul fast float %516, %74
  %559 = fmul fast float %516, %75
  %560 = fmul fast float %516, %77
  %561 = fadd fast float %509, %558
  %562 = fadd fast float %510, %559
  %563 = fadd fast float %511, %560
  %564 = fadd fast float %512, %516
  br label %565

; <label>:565                                     ; preds = %544, %515
  %566 = phi i1 [ %545, %544 ], [ false, %515 ]
  %567 = phi i1 [ %546, %544 ], [ false, %515 ]
  %568 = phi float [ %554, %544 ], [ %505, %515 ]
  %569 = phi float [ %555, %544 ], [ %506, %515 ]
  %570 = phi float [ %556, %544 ], [ %507, %515 ]
  %571 = phi float [ %557, %544 ], [ %508, %515 ]
  %572 = phi float [ %561, %544 ], [ %509, %515 ]
  %573 = phi float [ %562, %544 ], [ %510, %515 ]
  %574 = phi float [ %563, %544 ], [ %511, %515 ]
  %575 = phi float [ %564, %544 ], [ %512, %515 ]
  %576 = phi float [ %549, %544 ], [ %513, %515 ]
  br i1 %566, label %453, label %577

; <label>:577                                     ; preds = %565
  %578 = select i1 %567, float 0.000000e+00, float %576
  %579 = select i1 %567, float 0.000000e+00, float %575
  %580 = select i1 %567, float 0.000000e+00, float %574
  %581 = select i1 %567, float 0.000000e+00, float %573
  %582 = select i1 %567, float 0.000000e+00, float %572
  %583 = select i1 %567, float 0.000000e+00, float %571
  %584 = select i1 %567, float 0.000000e+00, float %570
  %585 = select i1 %567, float 0.000000e+00, float %569
  %586 = select i1 %567, float 0.000000e+00, float %568
  br label %453

; <label>:587                                     ; preds = %725, %713, %662, %650
  %588 = phi i1 [ true, %650 ], [ false, %662 ], [ true, %713 ], [ false, %725 ]
  %589 = phi i1 [ false, %650 ], [ true, %662 ], [ false, %713 ], [ %715, %725 ]
  %590 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %726, %725 ]
  %591 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %727, %725 ]
  %592 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %728, %725 ]
  %593 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %729, %725 ]
  %594 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %730, %725 ]
  %595 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %731, %725 ]
  %596 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %732, %725 ]
  %597 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %733, %725 ]
  %598 = phi float [ 0.000000e+00, %650 ], [ 0.000000e+00, %662 ], [ 0.000000e+00, %713 ], [ %734, %725 ]
  %599 = or i1 %588, %589
  br i1 %599, label %774, label %735

; <label>:600                                     ; preds = %453
  %601 = fmul fast float %448, %449
  %602 = fcmp fast ugt float %601, 0.000000e+00
  br i1 %602, label %603, label %650

; <label>:603                                     ; preds = %600
  %604 = icmp ne i32 %414, %267
  %605 = icmp ne i32 %423, %268
  %606 = or i1 %604, %605
  br i1 %606, label %607, label %629

; <label>:607                                     ; preds = %603
  %608 = fmul fast float %429, 2.000000e+00
  %609 = fmul fast float %436, 2.000000e+00
  %610 = fsub fast float %283, %608
  %611 = fsub fast float %285, %609
  %612 = call float @dx.op.dot3.f32(i32 55, float %610, float %611, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %613 = call float @dx.op.unary.f32(i32 6, float %612)  ; FAbs(value)
  %614 = fcmp fast olt float %613, 0x3F8EB851E0000000
  %615 = and i1 %282, %614
  %616 = call float @dx.op.dot3.f32(i32 55, float %610, float %611, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %617 = call float @dx.op.unary.f32(i32 6, float %616)  ; FAbs(value)
  %618 = fcmp fast olt float %617, 0x3F8EB851E0000000
  %619 = and i1 %615, %618
  %620 = fmul fast float %610, %610
  %621 = fmul fast float %611, %611
  %622 = fadd fast float %620, %298
  %623 = fadd fast float %622, %621
  %624 = call float @dx.op.unary.f32(i32 24, float %623)  ; Sqrt(value)
  %625 = fcmp fast olt float %624, 0x3F8EB851E0000000
  %626 = and i1 %619, %625
  %627 = xor i1 %626, true
  %628 = xor i1 %325, true
  br label %629

; <label>:629                                     ; preds = %607, %603
  %630 = phi i1 [ %628, %607 ], [ false, %603 ]
  %631 = phi i1 [ %627, %607 ], [ false, %603 ]
  %632 = fcmp fast oeq float %457, 0.000000e+00
  %633 = call float @dx.op.binary.f32(i32 36, float %456, float %76)  ; FMin(a,b)
  %634 = select i1 %632, float %76, float %633
  %635 = fmul fast float %601, %70
  %636 = fmul fast float %601, %71
  %637 = fmul fast float %601, %72
  %638 = fmul fast float %601, %73
  %639 = fadd fast float %464, %635
  %640 = fadd fast float %463, %636
  %641 = fadd fast float %462, %637
  %642 = fadd fast float %461, %638
  %643 = fmul fast float %601, %74
  %644 = fmul fast float %601, %75
  %645 = fmul fast float %601, %77
  %646 = fadd fast float %460, %643
  %647 = fadd fast float %459, %644
  %648 = fadd fast float %458, %645
  %649 = fadd fast float %457, %601
  br label %650

; <label>:650                                     ; preds = %629, %600
  %651 = phi i1 [ %630, %629 ], [ false, %600 ]
  %652 = phi i1 [ %631, %629 ], [ false, %600 ]
  %653 = phi float [ %639, %629 ], [ %464, %600 ]
  %654 = phi float [ %640, %629 ], [ %463, %600 ]
  %655 = phi float [ %641, %629 ], [ %462, %600 ]
  %656 = phi float [ %642, %629 ], [ %461, %600 ]
  %657 = phi float [ %646, %629 ], [ %460, %600 ]
  %658 = phi float [ %647, %629 ], [ %459, %600 ]
  %659 = phi float [ %648, %629 ], [ %458, %600 ]
  %660 = phi float [ %649, %629 ], [ %457, %600 ]
  %661 = phi float [ %634, %629 ], [ %456, %600 ]
  br i1 %651, label %587, label %662

; <label>:662                                     ; preds = %650
  br i1 %652, label %587, label %663

; <label>:663                                     ; preds = %662
  %664 = fmul fast float %448, %442
  %665 = fcmp fast ugt float %664, 0.000000e+00
  br i1 %665, label %666, label %713

; <label>:666                                     ; preds = %663
  %667 = icmp ne i32 %413, %267
  %668 = icmp ne i32 %423, %268
  %669 = or i1 %667, %668
  br i1 %669, label %670, label %692

; <label>:670                                     ; preds = %666
  %671 = fmul fast float %435, 2.000000e+00
  %672 = fmul fast float %436, 2.000000e+00
  %673 = fsub fast float %283, %671
  %674 = fsub fast float %285, %672
  %675 = call float @dx.op.dot3.f32(i32 55, float %673, float %674, float %287, float %166, float %167, float %168)  ; Dot3(ax,ay,az,bx,by,bz)
  %676 = call float @dx.op.unary.f32(i32 6, float %675)  ; FAbs(value)
  %677 = fcmp fast olt float %676, 0x3F8EB851E0000000
  %678 = and i1 %282, %677
  %679 = call float @dx.op.dot3.f32(i32 55, float %673, float %674, float %287, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %680 = call float @dx.op.unary.f32(i32 6, float %679)  ; FAbs(value)
  %681 = fcmp fast olt float %680, 0x3F8EB851E0000000
  %682 = and i1 %678, %681
  %683 = fmul fast float %673, %673
  %684 = fmul fast float %674, %674
  %685 = fadd fast float %683, %298
  %686 = fadd fast float %685, %684
  %687 = call float @dx.op.unary.f32(i32 24, float %686)  ; Sqrt(value)
  %688 = fcmp fast olt float %687, 0x3F8EB851E0000000
  %689 = and i1 %682, %688
  %690 = xor i1 %689, true
  %691 = xor i1 %325, true
  br label %692

; <label>:692                                     ; preds = %670, %666
  %693 = phi i1 [ %691, %670 ], [ false, %666 ]
  %694 = phi i1 [ %690, %670 ], [ false, %666 ]
  %695 = fcmp fast oeq float %660, 0.000000e+00
  %696 = call float @dx.op.binary.f32(i32 36, float %661, float %76)  ; FMin(a,b)
  %697 = select i1 %695, float %76, float %696
  %698 = fmul fast float %664, %70
  %699 = fmul fast float %664, %71
  %700 = fmul fast float %664, %72
  %701 = fmul fast float %664, %73
  %702 = fadd fast float %653, %698
  %703 = fadd fast float %654, %699
  %704 = fadd fast float %655, %700
  %705 = fadd fast float %656, %701
  %706 = fmul fast float %664, %74
  %707 = fmul fast float %664, %75
  %708 = fmul fast float %664, %77
  %709 = fadd fast float %657, %706
  %710 = fadd fast float %658, %707
  %711 = fadd fast float %659, %708
  %712 = fadd fast float %660, %664
  br label %713

; <label>:713                                     ; preds = %692, %663
  %714 = phi i1 [ %693, %692 ], [ false, %663 ]
  %715 = phi i1 [ %694, %692 ], [ false, %663 ]
  %716 = phi float [ %702, %692 ], [ %653, %663 ]
  %717 = phi float [ %703, %692 ], [ %654, %663 ]
  %718 = phi float [ %704, %692 ], [ %655, %663 ]
  %719 = phi float [ %705, %692 ], [ %656, %663 ]
  %720 = phi float [ %709, %692 ], [ %657, %663 ]
  %721 = phi float [ %710, %692 ], [ %658, %663 ]
  %722 = phi float [ %711, %692 ], [ %659, %663 ]
  %723 = phi float [ %712, %692 ], [ %660, %663 ]
  %724 = phi float [ %697, %692 ], [ %661, %663 ]
  br i1 %714, label %587, label %725

; <label>:725                                     ; preds = %713
  %726 = select i1 %715, float 0.000000e+00, float %724
  %727 = select i1 %715, float 0.000000e+00, float %723
  %728 = select i1 %715, float 0.000000e+00, float %722
  %729 = select i1 %715, float 0.000000e+00, float %721
  %730 = select i1 %715, float 0.000000e+00, float %720
  %731 = select i1 %715, float 0.000000e+00, float %719
  %732 = select i1 %715, float 0.000000e+00, float %718
  %733 = select i1 %715, float 0.000000e+00, float %717
  %734 = select i1 %715, float 0.000000e+00, float %716
  br label %587

; <label>:735                                     ; preds = %587
  %736 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %591)  ; IsFinite(value)
  %737 = xor i1 %736, true
  %738 = fcmp fast ole float %591, 0.000000e+00
  %739 = or i1 %738, %737
  br i1 %739, label %774, label %740

; <label>:740                                     ; preds = %735
  %741 = fdiv fast float %598, %591
  %742 = fdiv fast float %597, %591
  %743 = fdiv fast float %596, %591
  %744 = fdiv fast float %595, %591
  %745 = fdiv fast float %594, %591
  %746 = fdiv fast float %593, %591
  %747 = fdiv fast float %592, %591
  %748 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %741)  ; IsFinite(value)
  %749 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %742)  ; IsFinite(value)
  %750 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %743)  ; IsFinite(value)
  %751 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %744)  ; IsFinite(value)
  %752 = and i1 %748, %749
  %753 = and i1 %752, %750
  %754 = and i1 %753, %751
  %755 = fcmp fast ogt float %744, 0.000000e+00
  %756 = and i1 %755, %754
  %757 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %745)  ; IsFinite(value)
  %758 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %746)  ; IsFinite(value)
  %759 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %590)  ; IsFinite(value)
  %760 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %747)  ; IsFinite(value)
  %761 = and i1 %757, %758
  %762 = and i1 %761, %759
  %763 = and i1 %762, %760
  %764 = and i1 %756, %763
  %765 = fcmp fast ogt float %590, 0.000000e+00
  %766 = and i1 %765, %764
  %767 = select i1 %766, float %741, float %70
  %768 = select i1 %766, float %742, float %71
  %769 = select i1 %766, float %743, float %72
  %770 = select i1 %766, float %744, float %73
  %771 = select i1 %766, float %745, float %74
  %772 = select i1 %766, float %746, float %75
  %773 = select i1 %766, float %590, float %76
  br label %774

; <label>:774                                     ; preds = %740, %735, %587, %453
  %775 = phi i1 [ false, %735 ], [ %766, %740 ], [ false, %587 ], [ false, %453 ]
  %776 = phi float [ %70, %735 ], [ %767, %740 ], [ %70, %587 ], [ %70, %453 ]
  %777 = phi float [ %71, %735 ], [ %768, %740 ], [ %71, %587 ], [ %71, %453 ]
  %778 = phi float [ %72, %735 ], [ %769, %740 ], [ %72, %587 ], [ %72, %453 ]
  %779 = phi float [ %73, %735 ], [ %770, %740 ], [ %73, %587 ], [ %73, %453 ]
  %780 = phi float [ %74, %735 ], [ %771, %740 ], [ %74, %587 ], [ %74, %453 ]
  %781 = phi float [ %75, %735 ], [ %772, %740 ], [ %75, %587 ], [ %75, %453 ]
  %782 = phi float [ %76, %735 ], [ %773, %740 ], [ %76, %587 ], [ %76, %453 ]
  %783 = select i1 %775, float %776, float %70
  %784 = select i1 %775, float %777, float %71
  %785 = select i1 %775, float %778, float %72
  %786 = select i1 %775, float %779, float %73
  %787 = select i1 %775, float %780, float %74
  %788 = select i1 %775, float %781, float %75
  %789 = select i1 %775, float %782, float %76
  br label %790

; <label>:790                                     ; preds = %774, %339
  %791 = phi float [ %70, %339 ], [ %783, %774 ]
  %792 = phi float [ %71, %339 ], [ %784, %774 ]
  %793 = phi float [ %72, %339 ], [ %785, %774 ]
  %794 = phi float [ %73, %339 ], [ %786, %774 ]
  %795 = phi float [ %74, %339 ], [ %787, %774 ]
  %796 = phi float [ %75, %339 ], [ %788, %774 ]
  %797 = phi float [ %76, %339 ], [ %789, %774 ]
  %798 = icmp ne i32 %342, 0
  %799 = select i1 %798, float %794, float %57
  %800 = select i1 %798, float %795, float %89
  %801 = select i1 %798, float %796, float %92
  %802 = fcmp fast ogt float %28, 5.000000e-01
  %803 = select i1 %798, float %793, float %56
  %804 = select i1 %798, float %792, float %55
  %805 = select i1 %798, float %791, float %54
  %806 = fadd fast float %54, 0x3FA47AE140000000
  %807 = fadd fast float %55, 0x3FA47AE140000000
  %808 = fadd fast float %56, 0x3FA47AE140000000
  %809 = fadd fast float %54, 0xBFA47AE140000000
  %810 = fadd fast float %55, 0xBFA47AE140000000
  %811 = fadd fast float %56, 0xBFA47AE140000000
  %812 = call float @dx.op.binary.f32(i32 35, float %805, float %809)  ; FMax(a,b)
  %813 = call float @dx.op.binary.f32(i32 35, float %804, float %810)  ; FMax(a,b)
  %814 = call float @dx.op.binary.f32(i32 35, float %803, float %811)  ; FMax(a,b)
  %815 = call float @dx.op.binary.f32(i32 36, float %812, float %806)  ; FMin(a,b)
  %816 = call float @dx.op.binary.f32(i32 36, float %813, float %807)  ; FMin(a,b)
  %817 = call float @dx.op.binary.f32(i32 36, float %814, float %808)  ; FMin(a,b)
  %818 = sitofp i32 %60 to float
  %819 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %818)  ; FMin(a,b)
  %820 = select i1 %802, float %819, float %818
  %821 = fadd fast float %797, 1.000000e+00
  %822 = select i1 %798, float %821, float 1.000000e+00
  %823 = call float @dx.op.binary.f32(i32 36, float %822, float %820)  ; FMin(a,b)
  %824 = select i1 %798, float %823, float 1.000000e+00
  %825 = fdiv fast float 1.000000e+00, %824
  %826 = call float @dx.op.binary.f32(i32 35, float %40, float %825)  ; FMax(a,b)
  %827 = select i1 %798, float %826, float 1.000000e+00
  %828 = fsub fast float %57, %799
  %829 = call float @dx.op.unary.f32(i32 6, float %828)  ; FAbs(value)
  %830 = fmul fast float %829, 2.500000e-01
  %831 = select i1 %798, float %830, float 1.000000e+00
  %832 = call float @dx.op.binary.f32(i32 35, float %827, float %831)  ; FMax(a,b)
  %833 = fsub fast float %89, %800
  %834 = fsub fast float %92, %801
  %835 = fmul fast float %832, %833
  %836 = fmul fast float %832, %834
  %837 = fadd fast float %835, %800
  %838 = fadd fast float %836, %801
  %839 = fsub fast float %54, %815
  %840 = fsub fast float %55, %816
  %841 = fsub fast float %56, %817
  %842 = fmul fast float %832, %839
  %843 = fmul fast float %832, %840
  %844 = fmul fast float %832, %841
  %845 = fmul fast float %832, %828
  %846 = fadd fast float %842, %815
  %847 = fadd fast float %843, %816
  %848 = fadd fast float %844, %817
  %849 = fadd fast float %845, %799
  %850 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %846)  ; IsFinite(value)
  %851 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %847)  ; IsFinite(value)
  %852 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %848)  ; IsFinite(value)
  %853 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %849)  ; IsFinite(value)
  %854 = and i1 %850, %851
  %855 = and i1 %854, %852
  %856 = and i1 %855, %853
  %857 = fcmp fast ogt float %849, 0.000000e+00
  %858 = and i1 %857, %856
  %859 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %837)  ; IsFinite(value)
  %860 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %838)  ; IsFinite(value)
  %861 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %824)  ; IsFinite(value)
  %862 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %863 = and i1 %859, %860
  %864 = and i1 %863, %861
  %865 = and i1 %864, %862
  %866 = and i1 %858, %865
  %867 = fcmp fast ogt float %824, 0.000000e+00
  %868 = and i1 %867, %866
  %869 = select i1 %868, float %846, float 0.000000e+00
  %870 = select i1 %868, float %847, float 0.000000e+00
  %871 = select i1 %868, float %848, float 0.000000e+00
  %872 = select i1 %868, float %849, float 0.000000e+00
  %873 = select i1 %868, float %837, float 0.000000e+00
  %874 = select i1 %868, float %838, float 0.000000e+00
  %875 = select i1 %868, float %824, float 0.000000e+00
  br label %876

; <label>:876                                     ; preds = %790, %337, %327
  %877 = phi float [ %328, %337 ], [ %328, %327 ], [ %869, %790 ]
  %878 = phi float [ %329, %337 ], [ %329, %327 ], [ %870, %790 ]
  %879 = phi float [ %330, %337 ], [ %330, %327 ], [ %871, %790 ]
  %880 = phi float [ %331, %337 ], [ %331, %327 ], [ %872, %790 ]
  %881 = phi float [ %332, %337 ], [ %332, %327 ], [ %873, %790 ]
  %882 = phi float [ %333, %337 ], [ %333, %327 ], [ %874, %790 ]
  %883 = phi float [ %338, %337 ], [ %334, %327 ], [ %875, %790 ]
  %884 = phi float [ %335, %337 ], [ %335, %327 ], [ 0.000000e+00, %790 ]
  %885 = call i32 @dx.op.legacyF32ToF16(i32 130, float %877)  ; LegacyF32ToF16(value)
  %886 = call i32 @dx.op.legacyF32ToF16(i32 130, float %878)  ; LegacyF32ToF16(value)
  %887 = call i32 @dx.op.legacyF32ToF16(i32 130, float %879)  ; LegacyF32ToF16(value)
  %888 = call i32 @dx.op.legacyF32ToF16(i32 130, float %880)  ; LegacyF32ToF16(value)
  %889 = call float @dx.op.legacyF16ToF32(i32 131, i32 %885)  ; LegacyF16ToF32(value)
  %890 = call float @dx.op.legacyF16ToF32(i32 131, i32 %886)  ; LegacyF16ToF32(value)
  %891 = call float @dx.op.legacyF16ToF32(i32 131, i32 %887)  ; LegacyF16ToF32(value)
  %892 = call float @dx.op.legacyF16ToF32(i32 131, i32 %888)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 0, float %877, float %878, float %879, float %880, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 16, float %881, float %882, float %883, float %884, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 32, float %889, float %890, float %891, float %892, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %78, i32 48, float %881, float %882, float %883, float %884, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  %893 = add nuw nsw i32 %78, 1
  %894 = icmp eq i32 %893, 32
  br i1 %894, label %1624, label %895, !llvm.loop !16

; <label>:895                                     ; preds = %876
  %896 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 8), align 16
  %897 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 9), align 4
  %898 = load float, float* getelementptr inbounds ([16 x float], [16 x float]* @_HLGI_IdentityObjects.0.v.v.1dim, i32 0, i32 10), align 8
  %899 = load i32, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.1.0, i32 0, i32 0), align 4
  %900 = load i32, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.1.1, i32 0, i32 0), align 4
  %901 = load i32, i32* getelementptr inbounds ([1 x i32], [1 x i32]* @_HLGI_IdentityObjects.2, i32 0, i32 0), align 4
  br label %63

; <label>:902                                     ; preds = %11
  %903 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %54)  ; IsFinite(value)
  %904 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %55)  ; IsFinite(value)
  %905 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %56)  ; IsFinite(value)
  %906 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %57)  ; IsFinite(value)
  %907 = and i1 %903, %904
  %908 = and i1 %907, %905
  %909 = and i1 %908, %906
  %910 = fcmp fast ogt float %57, 0.000000e+00
  %911 = and i1 %910, %909
  %912 = call float @dx.op.dot3.f32(i32 55, float %54, float %55, float %56, float 0x3FCB367A00000000, float 0x3FE6E2EB20000000, float 0x3FB27BB300000000)  ; Dot3(ax,ay,az,bx,by,bz)
  %913 = select i1 %911, float %912, float 0.000000e+00
  %914 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %913)  ; IsFinite(value)
  %915 = and i1 %911, %914
  %916 = fmul fast float %913, %913
  %917 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %916)  ; IsFinite(value)
  %918 = and i1 %915, %917
  %919 = fmul fast float %54, %54
  %920 = fmul fast float %55, %55
  %921 = fmul fast float %56, %56
  %922 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %919)  ; IsFinite(value)
  %923 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %920)  ; IsFinite(value)
  %924 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %921)  ; IsFinite(value)
  %925 = and i1 %922, %923
  %926 = and i1 %925, %924
  %927 = and i1 %918, %926
  %928 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %41)  ; IsFinite(value)
  %929 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %930 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 5.000000e-01)  ; IsFinite(value)
  %931 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %932 = and i1 %928, %929
  %933 = and i1 %932, %930
  %934 = and i1 %933, %931
  %935 = fmul fast float %35, -5.000000e-01
  %936 = fadd fast float %935, 5.000000e-01
  %937 = icmp eq i32 %58, 0
  br i1 %937, label %954, label %938

; <label>:938                                     ; preds = %902
  %939 = fsub fast float 5.000000e-01, %33
  %940 = fsub fast float 5.000000e-01, %34
  %941 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %939)  ; IsFinite(value)
  %942 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %940)  ; IsFinite(value)
  %943 = and i1 %941, %942
  %944 = fsub fast float %939, %936
  %945 = fsub fast float -0.000000e+00, %34
  %946 = call float @dx.op.unary.f32(i32 6, float %944)  ; FAbs(value)
  %947 = call float @dx.op.unary.f32(i32 6, float %945)  ; FAbs(value)
  %948 = fcmp fast ole float %946, 1.000000e+00
  %949 = fcmp fast ole float %947, 1.000000e+00
  %950 = and i1 %948, %949
  %951 = and i1 %943, %950
  %952 = select i1 %951, float %939, float %936
  %953 = select i1 %951, float %940, float 5.000000e-01
  br label %954

; <label>:954                                     ; preds = %938, %902
  %955 = phi float [ %936, %902 ], [ %952, %938 ]
  %956 = phi float [ 5.000000e-01, %902 ], [ %953, %938 ]
  %957 = icmp ne i32 %59, 0
  %958 = and i1 %957, %934
  %959 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 1.000000e+00)  ; IsFinite(value)
  %960 = and i1 %958, %959
  %961 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %955)  ; IsFinite(value)
  %962 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %956)  ; IsFinite(value)
  %963 = and i1 %961, %962
  %964 = and i1 %960, %963
  %965 = fcmp fast ogt float %955, 0.000000e+00
  %966 = fcmp fast ogt float %956, 0.000000e+00
  %967 = and i1 %965, %966
  %968 = and i1 %967, %964
  %969 = fcmp fast olt float %955, 1.000000e+00
  %970 = fcmp fast olt float %956, 1.000000e+00
  %971 = and i1 %969, %970
  %972 = and i1 %971, %968
  br i1 %972, label %973, label %1028

; <label>:973                                     ; preds = %954
  %974 = call float @dx.op.unary.f32(i32 27, float %955)  ; Round_ni(value)
  %975 = call float @dx.op.unary.f32(i32 27, float %956)  ; Round_ni(value)
  %976 = fptosi float %974 to i32
  %977 = fptosi float %975 to i32
  %978 = call i32 @dx.op.binary.i32(i32 37, i32 %976, i32 0)  ; IMax(a,b)
  %979 = call i32 @dx.op.binary.i32(i32 37, i32 %977, i32 0)  ; IMax(a,b)
  %980 = call i32 @dx.op.binary.i32(i32 38, i32 %978, i32 0)  ; IMin(a,b)
  %981 = call i32 @dx.op.binary.i32(i32 38, i32 %979, i32 0)  ; IMin(a,b)
  %982 = add i32 %980, -1
  %983 = add i32 %981, -1
  %984 = call i32 @dx.op.binary.i32(i32 37, i32 %982, i32 0)  ; IMax(a,b)
  %985 = call i32 @dx.op.binary.i32(i32 37, i32 %983, i32 0)  ; IMax(a,b)
  %986 = and i32 %984, 2147483647
  %987 = and i32 %985, 2147483647
  %988 = uitofp i32 %986 to float
  %989 = uitofp i32 %987 to float
  %990 = fsub fast float 5.000000e-01, %955
  %991 = fadd fast float %988, %990
  %992 = fsub fast float 5.000000e-01, %956
  %993 = fadd fast float %989, %992
  %994 = call float @dx.op.unary.f32(i32 6, float %991)  ; FAbs(value)
  %995 = call float @dx.op.unary.f32(i32 6, float %993)  ; FAbs(value)
  %996 = call i32 @dx.op.binary.i32(i32 38, i32 %980, i32 0)  ; IMin(a,b)
  %997 = call i32 @dx.op.binary.i32(i32 38, i32 %981, i32 0)  ; IMin(a,b)
  %998 = and i32 %996, 2147483647
  %999 = and i32 %997, 2147483647
  %1000 = uitofp i32 %998 to float
  %1001 = uitofp i32 %999 to float
  %1002 = fadd fast float %1000, %990
  %1003 = fadd fast float %1001, %992
  %1004 = call float @dx.op.unary.f32(i32 6, float %1002)  ; FAbs(value)
  %1005 = call float @dx.op.unary.f32(i32 6, float %1003)  ; FAbs(value)
  %1006 = fcmp fast olt float %1004, %994
  %1007 = select i1 %1006, i32 %996, i32 %984
  %1008 = select i1 %1006, float %1004, float %994
  %1009 = fcmp fast olt float %1005, %995
  %1010 = select i1 %1009, i32 %997, i32 %985
  %1011 = select i1 %1009, float %1005, float %995
  %1012 = add i32 %980, 1
  %1013 = add i32 %981, 1
  %1014 = call i32 @dx.op.binary.i32(i32 38, i32 %1012, i32 0)  ; IMin(a,b)
  %1015 = call i32 @dx.op.binary.i32(i32 38, i32 %1013, i32 0)  ; IMin(a,b)
  %1016 = and i32 %1014, 2147483647
  %1017 = and i32 %1015, 2147483647
  %1018 = uitofp i32 %1016 to float
  %1019 = uitofp i32 %1017 to float
  %1020 = fadd fast float %1018, %990
  %1021 = fadd fast float %1019, %992
  %1022 = call float @dx.op.unary.f32(i32 6, float %1020)  ; FAbs(value)
  %1023 = call float @dx.op.unary.f32(i32 6, float %1021)  ; FAbs(value)
  %1024 = fcmp fast olt float %1022, %1008
  %1025 = select i1 %1024, i32 %1014, i32 %1007
  %1026 = fcmp fast olt float %1023, %1011
  %1027 = select i1 %1026, i32 %1015, i32 %1010
  br label %1028

; <label>:1028                                    ; preds = %973, %954
  %1029 = phi i32 [ 0, %954 ], [ %1025, %973 ]
  %1030 = phi i32 [ 0, %954 ], [ %1027, %973 ]
  %1031 = and i32 %1029, 2147483647
  %1032 = and i32 %1030, 2147483647
  %1033 = uitofp i32 %1031 to float
  %1034 = uitofp i32 %1032 to float
  %1035 = fadd fast float %1033, 5.000000e-01
  %1036 = fadd fast float %1034, 5.000000e-01
  %1037 = fmul fast float %1035, 2.000000e+00
  %1038 = fmul fast float %1036, 2.000000e+00
  %1039 = fadd fast float %1038, -1.000000e+00
  %1040 = fsub fast float 1.000000e+00, %35
  %1041 = fsub fast float %1040, %1037
  %1042 = fsub fast float -0.000000e+00, %1039
  %1043 = fsub fast float 5.000000e-01, %36
  %1044 = call float @dx.op.dot3.f32(i32 55, float %1041, float %1042, float %1043, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1045 = call float @dx.op.unary.f32(i32 6, float %1044)  ; FAbs(value)
  %1046 = fcmp fast olt float %1045, 0x3F8EB851E0000000
  %1047 = fmul fast float %1041, %1041
  %1048 = fmul fast float %1039, %1039
  %1049 = fmul fast float %1043, %1043
  %1050 = fadd fast float %1047, %1049
  %1051 = fadd fast float %1050, %1048
  %1052 = call float @dx.op.unary.f32(i32 24, float %1051)  ; Sqrt(value)
  %1053 = fcmp fast olt float %1052, 0x3F8EB851E0000000
  %1054 = and i1 %1046, %1053
  %1055 = and i1 %972, %1054
  %1056 = fcmp fast olt float %29, 5.000000e-01
  %1057 = and i1 %1056, %1055
  %1058 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %46)  ; IsFinite(value)
  %1059 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %47)  ; IsFinite(value)
  %1060 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %48)  ; IsFinite(value)
  %1061 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %49)  ; IsFinite(value)
  %1062 = and i1 %1058, %1059
  %1063 = and i1 %1062, %1060
  %1064 = and i1 %1063, %1061
  %1065 = fcmp fast ogt float %49, 0.000000e+00
  %1066 = and i1 %1065, %1064
  %1067 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %18)  ; IsFinite(value)
  %1068 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %19)  ; IsFinite(value)
  %1069 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %20)  ; IsFinite(value)
  %1070 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %21)  ; IsFinite(value)
  %1071 = and i1 %1067, %1068
  %1072 = and i1 %1071, %1069
  %1073 = and i1 %1072, %1070
  %1074 = and i1 %1066, %1073
  %1075 = fcmp fast ogt float %20, 0.000000e+00
  %1076 = and i1 %1075, %1074
  %1077 = and i1 %1057, %1076
  br i1 %927, label %1090, label %1078

; <label>:1078                                    ; preds = %1028
  %1079 = select i1 %1077, float %46, float 0.000000e+00
  %1080 = select i1 %1077, float %47, float 0.000000e+00
  %1081 = select i1 %1077, float %48, float 0.000000e+00
  %1082 = select i1 %1077, float %49, float 0.000000e+00
  %1083 = select i1 %1077, float %18, float 0.000000e+00
  %1084 = select i1 %1077, float %19, float 0.000000e+00
  %1085 = select i1 %1077, float %20, float 0.000000e+00
  %1086 = select i1 %1077, float %21, float 0.000000e+00
  %1087 = fcmp fast ogt float %28, 5.000000e-01
  br i1 %1087, label %1088, label %1607

; <label>:1088                                    ; preds = %1078
  %1089 = call float @dx.op.binary.f32(i32 36, float %1085, float 2.000000e+00)  ; FMin(a,b)
  br label %1607

; <label>:1090                                    ; preds = %1028
  %1091 = zext i1 %1077 to i32
  %1092 = fcmp fast ogt float %30, 5.000000e-01
  %1093 = select i1 %1092, i32 0, i32 %1091
  %1094 = icmp eq i32 %1093, 0
  br i1 %1094, label %1521, label %1095

; <label>:1095                                    ; preds = %1090
  %1096 = call float @dx.op.unary.f32(i32 27, float %955)  ; Round_ni(value)
  %1097 = call float @dx.op.unary.f32(i32 27, float %956)  ; Round_ni(value)
  %1098 = fptosi float %1096 to i32
  %1099 = fptosi float %1097 to i32
  %1100 = call i32 @dx.op.binary.i32(i32 37, i32 %1098, i32 0)  ; IMax(a,b)
  %1101 = call i32 @dx.op.binary.i32(i32 37, i32 %1099, i32 0)  ; IMax(a,b)
  %1102 = call i32 @dx.op.binary.i32(i32 38, i32 %1100, i32 0)  ; IMin(a,b)
  %1103 = call i32 @dx.op.binary.i32(i32 38, i32 %1101, i32 0)  ; IMin(a,b)
  %1104 = add i32 %1102, -1
  %1105 = add i32 %1103, -1
  %1106 = call i32 @dx.op.binary.i32(i32 37, i32 %1104, i32 0)  ; IMax(a,b)
  %1107 = call i32 @dx.op.binary.i32(i32 37, i32 %1105, i32 0)  ; IMax(a,b)
  %1108 = and i32 %1106, 2147483647
  %1109 = and i32 %1107, 2147483647
  %1110 = uitofp i32 %1108 to float
  %1111 = uitofp i32 %1109 to float
  %1112 = fsub fast float 5.000000e-01, %955
  %1113 = fadd fast float %1110, %1112
  %1114 = fsub fast float 5.000000e-01, %956
  %1115 = fadd fast float %1111, %1114
  %1116 = call float @dx.op.unary.f32(i32 6, float %1113)  ; FAbs(value)
  %1117 = call float @dx.op.unary.f32(i32 6, float %1115)  ; FAbs(value)
  %1118 = call i32 @dx.op.binary.i32(i32 38, i32 %1102, i32 0)  ; IMin(a,b)
  %1119 = call i32 @dx.op.binary.i32(i32 38, i32 %1103, i32 0)  ; IMin(a,b)
  %1120 = and i32 %1118, 2147483647
  %1121 = and i32 %1119, 2147483647
  %1122 = uitofp i32 %1120 to float
  %1123 = uitofp i32 %1121 to float
  %1124 = fadd fast float %1122, %1112
  %1125 = fadd fast float %1123, %1114
  %1126 = call float @dx.op.unary.f32(i32 6, float %1124)  ; FAbs(value)
  %1127 = call float @dx.op.unary.f32(i32 6, float %1125)  ; FAbs(value)
  %1128 = fcmp fast olt float %1126, %1116
  %1129 = select i1 %1128, i32 %1118, i32 %1106
  %1130 = select i1 %1128, float %1126, float %1116
  %1131 = fcmp fast olt float %1127, %1117
  %1132 = select i1 %1131, i32 %1119, i32 %1107
  %1133 = select i1 %1131, float %1127, float %1117
  %1134 = add i32 %1102, 1
  %1135 = add i32 %1103, 1
  %1136 = call i32 @dx.op.binary.i32(i32 38, i32 %1134, i32 0)  ; IMin(a,b)
  %1137 = call i32 @dx.op.binary.i32(i32 38, i32 %1135, i32 0)  ; IMin(a,b)
  %1138 = and i32 %1136, 2147483647
  %1139 = and i32 %1137, 2147483647
  %1140 = uitofp i32 %1138 to float
  %1141 = uitofp i32 %1139 to float
  %1142 = fadd fast float %1140, %1112
  %1143 = fadd fast float %1141, %1114
  %1144 = call float @dx.op.unary.f32(i32 6, float %1142)  ; FAbs(value)
  %1145 = call float @dx.op.unary.f32(i32 6, float %1143)  ; FAbs(value)
  %1146 = fcmp fast olt float %1144, %1130
  %1147 = select i1 %1146, i32 %1136, i32 %1129
  %1148 = fcmp fast olt float %1145, %1133
  %1149 = select i1 %1148, i32 %1137, i32 %1132
  %1150 = and i32 %1147, 2147483647
  %1151 = and i32 %1149, 2147483647
  %1152 = uitofp i32 %1150 to float
  %1153 = uitofp i32 %1151 to float
  %1154 = fadd fast float %1152, 5.000000e-01
  %1155 = fadd fast float %1153, 5.000000e-01
  %1156 = fcmp fast olt float %955, %1154
  br i1 %1156, label %1157, label %1160

; <label>:1157                                    ; preds = %1095
  %1158 = add nsw i32 %1147, -1
  %1159 = call i32 @dx.op.binary.i32(i32 37, i32 %1158, i32 0)  ; IMax(a,b)
  br label %1163

; <label>:1160                                    ; preds = %1095
  %1161 = add i32 %1147, 1
  %1162 = call i32 @dx.op.binary.i32(i32 40, i32 %1161, i32 0)  ; UMin(a,b)
  br label %1163

; <label>:1163                                    ; preds = %1160, %1157
  %1164 = phi i32 [ %1147, %1157 ], [ %1162, %1160 ]
  %1165 = phi i32 [ %1159, %1157 ], [ %1147, %1160 ]
  %1166 = fcmp fast olt float %956, %1155
  br i1 %1166, label %1167, label %1170

; <label>:1167                                    ; preds = %1163
  %1168 = add nsw i32 %1149, -1
  %1169 = call i32 @dx.op.binary.i32(i32 37, i32 %1168, i32 0)  ; IMax(a,b)
  br label %1173

; <label>:1170                                    ; preds = %1163
  %1171 = add i32 %1149, 1
  %1172 = call i32 @dx.op.binary.i32(i32 40, i32 %1171, i32 0)  ; UMin(a,b)
  br label %1173

; <label>:1173                                    ; preds = %1170, %1167
  %1174 = phi i32 [ %1149, %1167 ], [ %1172, %1170 ]
  %1175 = phi i32 [ %1169, %1167 ], [ %1149, %1170 ]
  %1176 = and i32 %1165, 2147483647
  %1177 = and i32 %1175, 2147483647
  %1178 = uitofp i32 %1176 to float
  %1179 = uitofp i32 %1177 to float
  %1180 = fadd fast float %1178, 5.000000e-01
  %1181 = fadd fast float %1179, 5.000000e-01
  %1182 = and i32 %1164, 2147483647
  %1183 = and i32 %1174, 2147483647
  %1184 = uitofp i32 %1182 to float
  %1185 = uitofp i32 %1183 to float
  %1186 = fadd fast float %1184, 5.000000e-01
  %1187 = fadd fast float %1185, 5.000000e-01
  %1188 = fcmp fast ogt float %1186, %1180
  %1189 = fsub fast float %955, %1180
  %1190 = fsub fast float %1186, %1180
  %1191 = fdiv fast float %1189, %1190
  %1192 = call float @dx.op.unary.f32(i32 7, float %1191)  ; Saturate(value)
  %1193 = select i1 %1188, float %1192, float 0.000000e+00
  %1194 = fcmp fast ogt float %1187, %1181
  %1195 = fsub fast float %956, %1181
  %1196 = fsub fast float %1187, %1181
  %1197 = fdiv fast float %1195, %1196
  %1198 = call float @dx.op.unary.f32(i32 7, float %1197)  ; Saturate(value)
  %1199 = select i1 %1194, float %1198, float 0.000000e+00
  %1200 = fsub fast float 1.000000e+00, %1193
  %1201 = fsub fast float 1.000000e+00, %1199
  %1202 = fmul fast float %1201, %1200
  %1203 = fcmp fast ugt float %1202, 0.000000e+00
  br i1 %1203, label %1217, label %1248

; <label>:1204                                    ; preds = %1318, %1306, %1260, %1248
  %1205 = phi i1 [ true, %1248 ], [ false, %1260 ], [ true, %1306 ], [ false, %1318 ]
  %1206 = phi i1 [ false, %1248 ], [ true, %1260 ], [ false, %1306 ], [ %1308, %1318 ]
  %1207 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1319, %1318 ]
  %1208 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1320, %1318 ]
  %1209 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1321, %1318 ]
  %1210 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1322, %1318 ]
  %1211 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1323, %1318 ]
  %1212 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1324, %1318 ]
  %1213 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1325, %1318 ]
  %1214 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1326, %1318 ]
  %1215 = phi float [ 0.000000e+00, %1248 ], [ 0.000000e+00, %1260 ], [ 0.000000e+00, %1306 ], [ %1327, %1318 ]
  %1216 = or i1 %1205, %1206
  br i1 %1216, label %1505, label %1341

; <label>:1217                                    ; preds = %1173
  %1218 = icmp ne i32 %1165, %1029
  %1219 = icmp ne i32 %1175, %1030
  %1220 = or i1 %1218, %1219
  br i1 %1220, label %1221, label %1238

; <label>:1221                                    ; preds = %1217
  %1222 = fmul fast float %1180, 2.000000e+00
  %1223 = fmul fast float %1181, 2.000000e+00
  %1224 = fadd fast float %1223, -1.000000e+00
  %1225 = fsub fast float %1040, %1222
  %1226 = fsub fast float -0.000000e+00, %1224
  %1227 = call float @dx.op.dot3.f32(i32 55, float %1225, float %1226, float %1043, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1228 = call float @dx.op.unary.f32(i32 6, float %1227)  ; FAbs(value)
  %1229 = fmul fast float %1225, %1225
  %1230 = fmul fast float %1224, %1224
  %1231 = fadd fast float %1229, %1049
  %1232 = fadd fast float %1231, %1230
  %1233 = call float @dx.op.unary.f32(i32 24, float %1232)  ; Sqrt(value)
  %1234 = fcmp uge float %1228, 0x3F8EB851E0000000
  %1235 = fcmp uge float %1233, 0x3F8EB851E0000000
  %1236 = or i1 %1235, %1234
  %1237 = xor i1 %1076, true
  br label %1238

; <label>:1238                                    ; preds = %1221, %1217
  %1239 = phi i1 [ %1237, %1221 ], [ false, %1217 ]
  %1240 = phi i1 [ %1236, %1221 ], [ false, %1217 ]
  %1241 = fmul fast float %1202, %46
  %1242 = fmul fast float %1202, %47
  %1243 = fmul fast float %1202, %48
  %1244 = fmul fast float %1202, %49
  %1245 = fmul fast float %1202, %18
  %1246 = fmul fast float %1202, %19
  %1247 = fmul fast float %1202, %21
  br label %1248

; <label>:1248                                    ; preds = %1238, %1173
  %1249 = phi i1 [ %1239, %1238 ], [ false, %1173 ]
  %1250 = phi i1 [ %1240, %1238 ], [ false, %1173 ]
  %1251 = phi float [ %1241, %1238 ], [ 0.000000e+00, %1173 ]
  %1252 = phi float [ %1242, %1238 ], [ 0.000000e+00, %1173 ]
  %1253 = phi float [ %1243, %1238 ], [ 0.000000e+00, %1173 ]
  %1254 = phi float [ %1244, %1238 ], [ 0.000000e+00, %1173 ]
  %1255 = phi float [ %1245, %1238 ], [ 0.000000e+00, %1173 ]
  %1256 = phi float [ %1246, %1238 ], [ 0.000000e+00, %1173 ]
  %1257 = phi float [ %1247, %1238 ], [ 0.000000e+00, %1173 ]
  %1258 = phi float [ %1202, %1238 ], [ 0.000000e+00, %1173 ]
  %1259 = phi float [ %20, %1238 ], [ 0.000000e+00, %1173 ]
  br i1 %1249, label %1204, label %1260

; <label>:1260                                    ; preds = %1248
  br i1 %1250, label %1204, label %1261

; <label>:1261                                    ; preds = %1260
  %1262 = fmul fast float %1201, %1193
  %1263 = fcmp fast ugt float %1262, 0.000000e+00
  br i1 %1263, label %1264, label %1306

; <label>:1264                                    ; preds = %1261
  %1265 = icmp ne i32 %1164, %1029
  %1266 = icmp ne i32 %1175, %1030
  %1267 = or i1 %1265, %1266
  br i1 %1267, label %1268, label %1285

; <label>:1268                                    ; preds = %1264
  %1269 = fmul fast float %1186, 2.000000e+00
  %1270 = fmul fast float %1181, 2.000000e+00
  %1271 = fadd fast float %1270, -1.000000e+00
  %1272 = fsub fast float %1040, %1269
  %1273 = fsub fast float -0.000000e+00, %1271
  %1274 = call float @dx.op.dot3.f32(i32 55, float %1272, float %1273, float %1043, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1275 = call float @dx.op.unary.f32(i32 6, float %1274)  ; FAbs(value)
  %1276 = fmul fast float %1272, %1272
  %1277 = fmul fast float %1271, %1271
  %1278 = fadd fast float %1276, %1049
  %1279 = fadd fast float %1278, %1277
  %1280 = call float @dx.op.unary.f32(i32 24, float %1279)  ; Sqrt(value)
  %1281 = fcmp uge float %1275, 0x3F8EB851E0000000
  %1282 = fcmp uge float %1280, 0x3F8EB851E0000000
  %1283 = or i1 %1282, %1281
  %1284 = xor i1 %1076, true
  br label %1285

; <label>:1285                                    ; preds = %1268, %1264
  %1286 = phi i1 [ %1284, %1268 ], [ false, %1264 ]
  %1287 = phi i1 [ %1283, %1268 ], [ false, %1264 ]
  %1288 = fcmp fast oeq float %1258, 0.000000e+00
  %1289 = call float @dx.op.binary.f32(i32 36, float %1259, float %20)  ; FMin(a,b)
  %1290 = select i1 %1288, float %20, float %1289
  %1291 = fmul fast float %1262, %46
  %1292 = fmul fast float %1262, %47
  %1293 = fmul fast float %1262, %48
  %1294 = fmul fast float %1262, %49
  %1295 = fadd fast float %1251, %1291
  %1296 = fadd fast float %1252, %1292
  %1297 = fadd fast float %1253, %1293
  %1298 = fadd fast float %1254, %1294
  %1299 = fmul fast float %1262, %18
  %1300 = fmul fast float %1262, %19
  %1301 = fmul fast float %1262, %21
  %1302 = fadd fast float %1255, %1299
  %1303 = fadd fast float %1256, %1300
  %1304 = fadd fast float %1257, %1301
  %1305 = fadd fast float %1258, %1262
  br label %1306

; <label>:1306                                    ; preds = %1285, %1261
  %1307 = phi i1 [ %1286, %1285 ], [ false, %1261 ]
  %1308 = phi i1 [ %1287, %1285 ], [ false, %1261 ]
  %1309 = phi float [ %1295, %1285 ], [ %1251, %1261 ]
  %1310 = phi float [ %1296, %1285 ], [ %1252, %1261 ]
  %1311 = phi float [ %1297, %1285 ], [ %1253, %1261 ]
  %1312 = phi float [ %1298, %1285 ], [ %1254, %1261 ]
  %1313 = phi float [ %1302, %1285 ], [ %1255, %1261 ]
  %1314 = phi float [ %1303, %1285 ], [ %1256, %1261 ]
  %1315 = phi float [ %1304, %1285 ], [ %1257, %1261 ]
  %1316 = phi float [ %1305, %1285 ], [ %1258, %1261 ]
  %1317 = phi float [ %1290, %1285 ], [ %1259, %1261 ]
  br i1 %1307, label %1204, label %1318

; <label>:1318                                    ; preds = %1306
  %1319 = select i1 %1308, float 0.000000e+00, float %1317
  %1320 = select i1 %1308, float 0.000000e+00, float %1316
  %1321 = select i1 %1308, float 0.000000e+00, float %1315
  %1322 = select i1 %1308, float 0.000000e+00, float %1314
  %1323 = select i1 %1308, float 0.000000e+00, float %1313
  %1324 = select i1 %1308, float 0.000000e+00, float %1312
  %1325 = select i1 %1308, float 0.000000e+00, float %1311
  %1326 = select i1 %1308, float 0.000000e+00, float %1310
  %1327 = select i1 %1308, float 0.000000e+00, float %1309
  br label %1204

; <label>:1328                                    ; preds = %1456, %1444, %1398, %1386
  %1329 = phi i1 [ true, %1386 ], [ false, %1398 ], [ true, %1444 ], [ false, %1456 ]
  %1330 = phi i1 [ false, %1386 ], [ true, %1398 ], [ false, %1444 ], [ %1446, %1456 ]
  %1331 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1457, %1456 ]
  %1332 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1458, %1456 ]
  %1333 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1459, %1456 ]
  %1334 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1460, %1456 ]
  %1335 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1461, %1456 ]
  %1336 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1462, %1456 ]
  %1337 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1463, %1456 ]
  %1338 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1464, %1456 ]
  %1339 = phi float [ 0.000000e+00, %1386 ], [ 0.000000e+00, %1398 ], [ 0.000000e+00, %1444 ], [ %1465, %1456 ]
  %1340 = or i1 %1329, %1330
  br i1 %1340, label %1505, label %1466

; <label>:1341                                    ; preds = %1204
  %1342 = fmul fast float %1199, %1200
  %1343 = fcmp fast ugt float %1342, 0.000000e+00
  br i1 %1343, label %1344, label %1386

; <label>:1344                                    ; preds = %1341
  %1345 = icmp ne i32 %1165, %1029
  %1346 = icmp ne i32 %1174, %1030
  %1347 = or i1 %1345, %1346
  br i1 %1347, label %1348, label %1365

; <label>:1348                                    ; preds = %1344
  %1349 = fmul fast float %1180, 2.000000e+00
  %1350 = fmul fast float %1187, 2.000000e+00
  %1351 = fadd fast float %1350, -1.000000e+00
  %1352 = fsub fast float %1040, %1349
  %1353 = fsub fast float -0.000000e+00, %1351
  %1354 = call float @dx.op.dot3.f32(i32 55, float %1352, float %1353, float %1043, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1355 = call float @dx.op.unary.f32(i32 6, float %1354)  ; FAbs(value)
  %1356 = fmul fast float %1352, %1352
  %1357 = fmul fast float %1351, %1351
  %1358 = fadd fast float %1356, %1049
  %1359 = fadd fast float %1358, %1357
  %1360 = call float @dx.op.unary.f32(i32 24, float %1359)  ; Sqrt(value)
  %1361 = fcmp uge float %1355, 0x3F8EB851E0000000
  %1362 = fcmp uge float %1360, 0x3F8EB851E0000000
  %1363 = or i1 %1362, %1361
  %1364 = xor i1 %1076, true
  br label %1365

; <label>:1365                                    ; preds = %1348, %1344
  %1366 = phi i1 [ %1364, %1348 ], [ false, %1344 ]
  %1367 = phi i1 [ %1363, %1348 ], [ false, %1344 ]
  %1368 = fcmp fast oeq float %1208, 0.000000e+00
  %1369 = call float @dx.op.binary.f32(i32 36, float %1207, float %20)  ; FMin(a,b)
  %1370 = select i1 %1368, float %20, float %1369
  %1371 = fmul fast float %1342, %46
  %1372 = fmul fast float %1342, %47
  %1373 = fmul fast float %1342, %48
  %1374 = fmul fast float %1342, %49
  %1375 = fadd fast float %1215, %1371
  %1376 = fadd fast float %1214, %1372
  %1377 = fadd fast float %1213, %1373
  %1378 = fadd fast float %1212, %1374
  %1379 = fmul fast float %1342, %18
  %1380 = fmul fast float %1342, %19
  %1381 = fmul fast float %1342, %21
  %1382 = fadd fast float %1211, %1379
  %1383 = fadd fast float %1210, %1380
  %1384 = fadd fast float %1209, %1381
  %1385 = fadd fast float %1208, %1342
  br label %1386

; <label>:1386                                    ; preds = %1365, %1341
  %1387 = phi i1 [ %1366, %1365 ], [ false, %1341 ]
  %1388 = phi i1 [ %1367, %1365 ], [ false, %1341 ]
  %1389 = phi float [ %1375, %1365 ], [ %1215, %1341 ]
  %1390 = phi float [ %1376, %1365 ], [ %1214, %1341 ]
  %1391 = phi float [ %1377, %1365 ], [ %1213, %1341 ]
  %1392 = phi float [ %1378, %1365 ], [ %1212, %1341 ]
  %1393 = phi float [ %1382, %1365 ], [ %1211, %1341 ]
  %1394 = phi float [ %1383, %1365 ], [ %1210, %1341 ]
  %1395 = phi float [ %1384, %1365 ], [ %1209, %1341 ]
  %1396 = phi float [ %1385, %1365 ], [ %1208, %1341 ]
  %1397 = phi float [ %1370, %1365 ], [ %1207, %1341 ]
  br i1 %1387, label %1328, label %1398

; <label>:1398                                    ; preds = %1386
  br i1 %1388, label %1328, label %1399

; <label>:1399                                    ; preds = %1398
  %1400 = fmul fast float %1199, %1193
  %1401 = fcmp fast ugt float %1400, 0.000000e+00
  br i1 %1401, label %1402, label %1444

; <label>:1402                                    ; preds = %1399
  %1403 = icmp ne i32 %1164, %1029
  %1404 = icmp ne i32 %1174, %1030
  %1405 = or i1 %1403, %1404
  br i1 %1405, label %1406, label %1423

; <label>:1406                                    ; preds = %1402
  %1407 = fmul fast float %1186, 2.000000e+00
  %1408 = fmul fast float %1187, 2.000000e+00
  %1409 = fadd fast float %1408, -1.000000e+00
  %1410 = fsub fast float %1040, %1407
  %1411 = fsub fast float -0.000000e+00, %1409
  %1412 = call float @dx.op.dot3.f32(i32 55, float %1410, float %1411, float %1043, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00)  ; Dot3(ax,ay,az,bx,by,bz)
  %1413 = call float @dx.op.unary.f32(i32 6, float %1412)  ; FAbs(value)
  %1414 = fmul fast float %1410, %1410
  %1415 = fmul fast float %1409, %1409
  %1416 = fadd fast float %1414, %1049
  %1417 = fadd fast float %1416, %1415
  %1418 = call float @dx.op.unary.f32(i32 24, float %1417)  ; Sqrt(value)
  %1419 = fcmp uge float %1413, 0x3F8EB851E0000000
  %1420 = fcmp uge float %1418, 0x3F8EB851E0000000
  %1421 = or i1 %1420, %1419
  %1422 = xor i1 %1076, true
  br label %1423

; <label>:1423                                    ; preds = %1406, %1402
  %1424 = phi i1 [ %1422, %1406 ], [ false, %1402 ]
  %1425 = phi i1 [ %1421, %1406 ], [ false, %1402 ]
  %1426 = fcmp fast oeq float %1396, 0.000000e+00
  %1427 = call float @dx.op.binary.f32(i32 36, float %1397, float %20)  ; FMin(a,b)
  %1428 = select i1 %1426, float %20, float %1427
  %1429 = fmul fast float %1400, %46
  %1430 = fmul fast float %1400, %47
  %1431 = fmul fast float %1400, %48
  %1432 = fmul fast float %1400, %49
  %1433 = fadd fast float %1389, %1429
  %1434 = fadd fast float %1390, %1430
  %1435 = fadd fast float %1391, %1431
  %1436 = fadd fast float %1392, %1432
  %1437 = fmul fast float %1400, %18
  %1438 = fmul fast float %1400, %19
  %1439 = fmul fast float %1400, %21
  %1440 = fadd fast float %1393, %1437
  %1441 = fadd fast float %1394, %1438
  %1442 = fadd fast float %1395, %1439
  %1443 = fadd fast float %1396, %1400
  br label %1444

; <label>:1444                                    ; preds = %1423, %1399
  %1445 = phi i1 [ %1424, %1423 ], [ false, %1399 ]
  %1446 = phi i1 [ %1425, %1423 ], [ false, %1399 ]
  %1447 = phi float [ %1433, %1423 ], [ %1389, %1399 ]
  %1448 = phi float [ %1434, %1423 ], [ %1390, %1399 ]
  %1449 = phi float [ %1435, %1423 ], [ %1391, %1399 ]
  %1450 = phi float [ %1436, %1423 ], [ %1392, %1399 ]
  %1451 = phi float [ %1440, %1423 ], [ %1393, %1399 ]
  %1452 = phi float [ %1441, %1423 ], [ %1394, %1399 ]
  %1453 = phi float [ %1442, %1423 ], [ %1395, %1399 ]
  %1454 = phi float [ %1443, %1423 ], [ %1396, %1399 ]
  %1455 = phi float [ %1428, %1423 ], [ %1397, %1399 ]
  br i1 %1445, label %1328, label %1456

; <label>:1456                                    ; preds = %1444
  %1457 = select i1 %1446, float 0.000000e+00, float %1455
  %1458 = select i1 %1446, float 0.000000e+00, float %1454
  %1459 = select i1 %1446, float 0.000000e+00, float %1453
  %1460 = select i1 %1446, float 0.000000e+00, float %1452
  %1461 = select i1 %1446, float 0.000000e+00, float %1451
  %1462 = select i1 %1446, float 0.000000e+00, float %1450
  %1463 = select i1 %1446, float 0.000000e+00, float %1449
  %1464 = select i1 %1446, float 0.000000e+00, float %1448
  %1465 = select i1 %1446, float 0.000000e+00, float %1447
  br label %1328

; <label>:1466                                    ; preds = %1328
  %1467 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1332)  ; IsFinite(value)
  %1468 = xor i1 %1467, true
  %1469 = fcmp fast ole float %1332, 0.000000e+00
  %1470 = or i1 %1469, %1468
  br i1 %1470, label %1505, label %1471

; <label>:1471                                    ; preds = %1466
  %1472 = fdiv fast float %1339, %1332
  %1473 = fdiv fast float %1338, %1332
  %1474 = fdiv fast float %1337, %1332
  %1475 = fdiv fast float %1336, %1332
  %1476 = fdiv fast float %1335, %1332
  %1477 = fdiv fast float %1334, %1332
  %1478 = fdiv fast float %1333, %1332
  %1479 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1472)  ; IsFinite(value)
  %1480 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1473)  ; IsFinite(value)
  %1481 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1474)  ; IsFinite(value)
  %1482 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1475)  ; IsFinite(value)
  %1483 = and i1 %1479, %1480
  %1484 = and i1 %1483, %1481
  %1485 = and i1 %1484, %1482
  %1486 = fcmp fast ogt float %1475, 0.000000e+00
  %1487 = and i1 %1486, %1485
  %1488 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1476)  ; IsFinite(value)
  %1489 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1477)  ; IsFinite(value)
  %1490 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1331)  ; IsFinite(value)
  %1491 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1478)  ; IsFinite(value)
  %1492 = and i1 %1488, %1489
  %1493 = and i1 %1492, %1490
  %1494 = and i1 %1493, %1491
  %1495 = and i1 %1487, %1494
  %1496 = fcmp fast ogt float %1331, 0.000000e+00
  %1497 = and i1 %1496, %1495
  %1498 = select i1 %1497, float %1472, float %46
  %1499 = select i1 %1497, float %1473, float %47
  %1500 = select i1 %1497, float %1474, float %48
  %1501 = select i1 %1497, float %1475, float %49
  %1502 = select i1 %1497, float %1476, float %18
  %1503 = select i1 %1497, float %1477, float %19
  %1504 = select i1 %1497, float %1331, float %20
  br label %1505

; <label>:1505                                    ; preds = %1471, %1466, %1328, %1204
  %1506 = phi i1 [ false, %1466 ], [ %1497, %1471 ], [ false, %1328 ], [ false, %1204 ]
  %1507 = phi float [ %46, %1466 ], [ %1498, %1471 ], [ %46, %1328 ], [ %46, %1204 ]
  %1508 = phi float [ %47, %1466 ], [ %1499, %1471 ], [ %47, %1328 ], [ %47, %1204 ]
  %1509 = phi float [ %48, %1466 ], [ %1500, %1471 ], [ %48, %1328 ], [ %48, %1204 ]
  %1510 = phi float [ %49, %1466 ], [ %1501, %1471 ], [ %49, %1328 ], [ %49, %1204 ]
  %1511 = phi float [ %18, %1466 ], [ %1502, %1471 ], [ %18, %1328 ], [ %18, %1204 ]
  %1512 = phi float [ %19, %1466 ], [ %1503, %1471 ], [ %19, %1328 ], [ %19, %1204 ]
  %1513 = phi float [ %20, %1466 ], [ %1504, %1471 ], [ %20, %1328 ], [ %20, %1204 ]
  %1514 = select i1 %1506, float %1507, float %46
  %1515 = select i1 %1506, float %1508, float %47
  %1516 = select i1 %1506, float %1509, float %48
  %1517 = select i1 %1506, float %1510, float %49
  %1518 = select i1 %1506, float %1511, float %18
  %1519 = select i1 %1506, float %1512, float %19
  %1520 = select i1 %1506, float %1513, float %20
  br label %1521

; <label>:1521                                    ; preds = %1505, %1090
  %1522 = phi float [ %46, %1090 ], [ %1514, %1505 ]
  %1523 = phi float [ %47, %1090 ], [ %1515, %1505 ]
  %1524 = phi float [ %48, %1090 ], [ %1516, %1505 ]
  %1525 = phi float [ %49, %1090 ], [ %1517, %1505 ]
  %1526 = phi float [ %18, %1090 ], [ %1518, %1505 ]
  %1527 = phi float [ %19, %1090 ], [ %1519, %1505 ]
  %1528 = phi float [ %20, %1090 ], [ %1520, %1505 ]
  %1529 = icmp ne i32 %1093, 0
  %1530 = select i1 %1529, float %1525, float %57
  %1531 = select i1 %1529, float %1526, float %913
  %1532 = select i1 %1529, float %1527, float %916
  %1533 = fcmp fast ogt float %28, 5.000000e-01
  %1534 = select i1 %1529, float %1524, float %56
  %1535 = select i1 %1529, float %1523, float %55
  %1536 = select i1 %1529, float %1522, float %54
  %1537 = fadd fast float %54, 0x3FA47AE140000000
  %1538 = fadd fast float %55, 0x3FA47AE140000000
  %1539 = fadd fast float %56, 0x3FA47AE140000000
  %1540 = fadd fast float %54, 0xBFA47AE140000000
  %1541 = fadd fast float %55, 0xBFA47AE140000000
  %1542 = fadd fast float %56, 0xBFA47AE140000000
  %1543 = call float @dx.op.binary.f32(i32 35, float %1536, float %1540)  ; FMax(a,b)
  %1544 = call float @dx.op.binary.f32(i32 35, float %1535, float %1541)  ; FMax(a,b)
  %1545 = call float @dx.op.binary.f32(i32 35, float %1534, float %1542)  ; FMax(a,b)
  %1546 = call float @dx.op.binary.f32(i32 36, float %1543, float %1537)  ; FMin(a,b)
  %1547 = call float @dx.op.binary.f32(i32 36, float %1544, float %1538)  ; FMin(a,b)
  %1548 = call float @dx.op.binary.f32(i32 36, float %1545, float %1539)  ; FMin(a,b)
  %1549 = sitofp i32 %60 to float
  %1550 = call float @dx.op.binary.f32(i32 36, float 2.000000e+00, float %1549)  ; FMin(a,b)
  %1551 = select i1 %1533, float %1550, float %1549
  %1552 = fadd fast float %1528, 1.000000e+00
  %1553 = select i1 %1529, float %1552, float 1.000000e+00
  %1554 = call float @dx.op.binary.f32(i32 36, float %1553, float %1551)  ; FMin(a,b)
  %1555 = select i1 %1529, float %1554, float 1.000000e+00
  %1556 = fdiv fast float 1.000000e+00, %1555
  %1557 = call float @dx.op.binary.f32(i32 35, float %40, float %1556)  ; FMax(a,b)
  %1558 = select i1 %1529, float %1557, float 1.000000e+00
  %1559 = fsub fast float %57, %1530
  %1560 = call float @dx.op.unary.f32(i32 6, float %1559)  ; FAbs(value)
  %1561 = fmul fast float %1560, 2.500000e-01
  %1562 = select i1 %1529, float %1561, float 1.000000e+00
  %1563 = call float @dx.op.binary.f32(i32 35, float %1558, float %1562)  ; FMax(a,b)
  %1564 = fsub fast float %913, %1531
  %1565 = fsub fast float %916, %1532
  %1566 = fmul fast float %1563, %1564
  %1567 = fmul fast float %1563, %1565
  %1568 = fadd fast float %1566, %1531
  %1569 = fadd fast float %1567, %1532
  %1570 = fsub fast float %54, %1546
  %1571 = fsub fast float %55, %1547
  %1572 = fsub fast float %56, %1548
  %1573 = fmul fast float %1563, %1570
  %1574 = fmul fast float %1563, %1571
  %1575 = fmul fast float %1563, %1572
  %1576 = fmul fast float %1563, %1559
  %1577 = fadd fast float %1573, %1546
  %1578 = fadd fast float %1574, %1547
  %1579 = fadd fast float %1575, %1548
  %1580 = fadd fast float %1576, %1530
  %1581 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1577)  ; IsFinite(value)
  %1582 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1578)  ; IsFinite(value)
  %1583 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1579)  ; IsFinite(value)
  %1584 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1580)  ; IsFinite(value)
  %1585 = and i1 %1581, %1582
  %1586 = and i1 %1585, %1583
  %1587 = and i1 %1586, %1584
  %1588 = fcmp fast ogt float %1580, 0.000000e+00
  %1589 = and i1 %1588, %1587
  %1590 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1568)  ; IsFinite(value)
  %1591 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1569)  ; IsFinite(value)
  %1592 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float %1555)  ; IsFinite(value)
  %1593 = call i1 @dx.op.isSpecialFloat.f32(i32 10, float 0.000000e+00)  ; IsFinite(value)
  %1594 = and i1 %1590, %1591
  %1595 = and i1 %1594, %1592
  %1596 = and i1 %1595, %1593
  %1597 = and i1 %1589, %1596
  %1598 = fcmp fast ogt float %1555, 0.000000e+00
  %1599 = and i1 %1598, %1597
  %1600 = select i1 %1599, float %1577, float 0.000000e+00
  %1601 = select i1 %1599, float %1578, float 0.000000e+00
  %1602 = select i1 %1599, float %1579, float 0.000000e+00
  %1603 = select i1 %1599, float %1580, float 0.000000e+00
  %1604 = select i1 %1599, float %1568, float 0.000000e+00
  %1605 = select i1 %1599, float %1569, float 0.000000e+00
  %1606 = select i1 %1599, float %1555, float 0.000000e+00
  br label %1607

; <label>:1607                                    ; preds = %1521, %1088, %1078
  %1608 = phi float [ %1079, %1088 ], [ %1079, %1078 ], [ %1600, %1521 ]
  %1609 = phi float [ %1080, %1088 ], [ %1080, %1078 ], [ %1601, %1521 ]
  %1610 = phi float [ %1081, %1088 ], [ %1081, %1078 ], [ %1602, %1521 ]
  %1611 = phi float [ %1082, %1088 ], [ %1082, %1078 ], [ %1603, %1521 ]
  %1612 = phi float [ %1083, %1088 ], [ %1083, %1078 ], [ %1604, %1521 ]
  %1613 = phi float [ %1084, %1088 ], [ %1084, %1078 ], [ %1605, %1521 ]
  %1614 = phi float [ %1089, %1088 ], [ %1085, %1078 ], [ %1606, %1521 ]
  %1615 = phi float [ %1086, %1088 ], [ %1086, %1078 ], [ 0.000000e+00, %1521 ]
  %1616 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1608)  ; LegacyF32ToF16(value)
  %1617 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1609)  ; LegacyF32ToF16(value)
  %1618 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1610)  ; LegacyF32ToF16(value)
  %1619 = call i32 @dx.op.legacyF32ToF16(i32 130, float %1611)  ; LegacyF32ToF16(value)
  %1620 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1616)  ; LegacyF16ToF32(value)
  %1621 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1617)  ; LegacyF16ToF32(value)
  %1622 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1618)  ; LegacyF16ToF32(value)
  %1623 = call float @dx.op.legacyF16ToF32(i32 131, i32 %1619)  ; LegacyF16ToF32(value)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 0, float %1608, float %1609, float %1610, float %1611, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 16, float %1612, float %1613, float %1614, float %1615, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 32, float %1620, float %1621, float %1622, float %1623, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  call void @dx.op.bufferStore.f32(i32 69, %dx.types.Handle %1, i32 %4, i32 48, float %1612, float %1613, float %1614, float %1615, i8 15)  ; BufferStore(uav,coord0,coord1,value0,value1,value2,value3,mask)
  br label %1625

; <label>:1624                                    ; preds = %876
  br label %1625

; <label>:1625                                    ; preds = %1624, %1607, %0
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
