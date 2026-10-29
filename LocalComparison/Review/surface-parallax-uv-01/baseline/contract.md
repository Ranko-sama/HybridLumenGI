# Fixed parallax UV decision contract

Frozen before baseline execution and product edits. One baseline invocation,
one candidate invocation; each uses exactly the following three records.
First baseline/reference dependency or candidate failure is preserved and stops
the lane. Do not adjust inputs, bounds, seeds or expand the material matrix.

Use the complete actual Surface Vert and Frag, and actual frozen Core
ParallaxMapping.hlsl. Model identity object transform, positive handedness and
perspective camera (1,1,1) looking along -Z. Source vertices are
P0=(-.5,-.5,0), P1=(.5,-.5,0), P2=(-.5,.5,0), all clip w=1.
Normals N0=(0,0,1), N1=(.6,0,.8), N2=(0,.6,.8); tangents
T0=(1,0,0,1), T1=(.8,0,-.6,1), T2=(1,0,0,1).
Each normal/tangent pair is unit and orthogonal. Fixed barycentric weights
are (.2,.3,.5). Invoke Vert at every vertex, then interpolate its outputs.
Raw UVs are (.1,.15),(.3,.15),(.1,.35). Base ST=(2,1,.16,.15),
so the pre-parallax fragment UV is (.48,.4). Detail ST=(.5,.75,.25,.1).

Independent stock-Lit reference: normalize(camera-Pi) at each vertex. Form
Bi=cross(Ni,Ti), viewTSi=(dot(Ti,Vi),dot(Bi,Vi),dot(Ni,Vi)); interpolate
viewTS with the declared weights, then normalize the result for parallax.
Interpolated TS=(.4967409436525119,.3150032991520633,.5556600723081111).
With height.g=1, amplitude=.08, offset is
(.022188156899485015,.014070397688680746), displaced UV
(.502188156899485,.41407039768868076). This reference is independent of
candidate bytes. Rebuilding a frame/view at the interpolated fragment instead
gives offset (.018239603832687395,.009142890022461025), which must not pass.

Three records:

1. parallax-on: keyword on, height.g=1, amplitude=.08. Old actual consumer
   must retain (.48,.4) and differ from the reference. Candidate must use the
   displaced UV at every base/metal/spec/AO/emission/detail-mask read. Detail
   albedo reads displacedUV*DetailST.xy+DetailST.zw.
2. keyword-off: same height/amplitude/triangle, _PARALLAXMAP absent.
   Entire recorded output must remain byte-identical to baseline.
3. zero-offset: keyword on, same amplitude/triangle, height.g=.5. Centering
   yields exact zero offset. Entire recorded output remains baseline-identical.

One fixed metallic+_METALLICSPECGLOSSMAP+_DETAIL_MULX2+_OCCLUSIONMAP+_EMISSION
variant is used for behavior; alpha testing is off and source is opaque.
Texture fields at UV=(u,v), legal bilinear interior signals on a 2x2 grid:
Base=(u,v,.25+.25u,1); metallic.r=.25+.25u;
specular=(.1+.1u,.1+.1v,.2,1); AO.g=.25+.5v;
emission=(.5u,.25v,.125+.125u,1); mask.a=.25+.5v;
detail at its own UV=(dU,dV): (.25+.25dU,.5+.125dV,.75-.25dU,1).
Height.g uses the record value. BaseColor=(.8,.6,.9,1), EmissionColor=(.5,.75,.25,1),
OcclusionStrength=.75; sample-space inputs avoid authoring gamma ambiguity.
Expected diffuse uses existing detail MulX2/mask then metallic diffuse split
.96*(1-metallic), followed by existing final saturate. No value approaches cap.

Old/unshifted expected diffuse=(.2055932928,.15168384,.2245088664),
AO=.5875, emission=(.12,.075,.04625).
On/reference expected diffuse=(.21338153357195896,.1559212979313438,.22571812243813022),
AO=.5927763991332553,
emission=(.12554703922487126,.07763819956662764,.04694337990310891).
Validity+policy remain1 and (1,1), opaque clip count/minimum remain1/.5.
Absolute numerical bound is2e-6 for UV, diffuse, AO and emission, inherited from
the existing source host. Two control records must be entirely byte-identical
old/candidate; unrelated clip/validity/policy fields remain exact for all records.
All output floats finite. Exact recorded texture UVs must match declared values;
this catches partial material offsets even where a field is not in final RGB.

Candidate additionally compiles the complete original HLSLPROGRAM with real clip
for Vert/Frag x _PARALLAXMAP off/on (four entries only). Preserve actual local
helpers and fixed installed/include-cache sources. No Unity, Player, texture
allocation, new host, alpha/detail/workflow matrix, or broad material claim.
