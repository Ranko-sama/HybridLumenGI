// TEST ONLY: DX12 syntax validation without an installed Unity Editor.
// Unity supplies its own engine header when importing the actual compute shader.
// The official 6000.0.65f1 builtin shader archive was inspected: on the default
// PLATFORM_RAYQUERY path Unity uses this alias too. This checks the DX12 HLSL
// surface only, not Unity importing, binding, dispatch, or alternate platforms.
// Source: unity.com/releases/editor/whats-new/6000.0.65f1 -> Shaders, a18e2220bd50.
#define UnityRayQuery RayQuery
