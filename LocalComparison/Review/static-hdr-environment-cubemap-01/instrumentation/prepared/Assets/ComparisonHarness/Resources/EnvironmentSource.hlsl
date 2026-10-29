float4 _HLGI_Environment;
TextureCube<float4> _HLGI_EnvironmentCube;
SamplerState sampler_HLGIEnvironment_LinearClamp;
int _HLGI_EnvironmentCubeEnabled;
float3 HLGIEnvironmentRadiance(float3 direction)
{
    // Li along the escaping world ray; existing sampling weights produce D=E/pi.
    // Leave nonfinite samples intact for the existing measurement guards.
    return _HLGI_EnvironmentCubeEnabled!=0 ?
        _HLGI_EnvironmentCube.SampleLevel(sampler_HLGIEnvironment_LinearClamp,direction,0).rgb : _HLGI_Environment.rgb;
}

