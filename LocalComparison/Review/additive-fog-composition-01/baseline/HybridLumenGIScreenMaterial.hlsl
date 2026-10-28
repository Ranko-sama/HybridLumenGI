#ifndef HYBRID_LUMEN_GI_SCREEN_MATERIAL_INCLUDED
#define HYBRID_LUMEN_GI_SCREEN_MATERIAL_INCLUDED

// Screen capture only: magnitude retains validity (ordinary: 1) or validity
// plus material AO (native: 1 + AO). Sign carries the source Lit shadow policy.
// Zero remains uncovered/unsupported; world-card alpha uses a different layout.
float HLGIEncodeScreenMaterial(float magnitude,bool receivesShadows)
{
    return receivesShadows?magnitude:-magnitude;
}
bool HLGICaptureReceivesShadows()
{
#if defined(_RECEIVE_SHADOWS_OFF)
    return false;
#else
    return true;
#endif
}
bool HLGIHasScreenMaterial(float alpha) { return abs(alpha)>0.5; }
bool HLGIScreenReceivesShadows(float alpha) { return alpha>0; }
float HLGIScreenMaterialAO(float alpha,bool nativeComposition,float ordinaryAO)
{
    return nativeComposition?saturate(abs(alpha)-1):ordinaryAO;
}
#endif
