Shader "Hidden/HybridLumenGI/ColorContractProbe"
{
    Properties
    {
        // Match Universal Render Pipeline/Lit's native material-property flags.
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        _SpecColor("Specular", Color) = (0.2,0.2,0.2,1)
        [HDR] _EmissionColor("Emission", Color) = (0,0,0,1)
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always
        HLSLINCLUDE
        // Read the actual URP LitInput declarations, not a reimplemented transfer function.
        #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
        float4 ProbeVertex(uint vertexID : SV_VertexID) : SV_POSITION
        {
            float2 uv=float2((vertexID<<1)&2,vertexID&2);
            return float4(uv*2-1,0,1);
        }
        float4 ProbeBase() : SV_Target { return _BaseColor; }
        float4 ProbeSpecular() : SV_Target { return _SpecColor; }
        float4 ProbeEmission() : SV_Target { return _EmissionColor; }
        ENDHLSL
        Pass
        {
            Name "BaseColor"
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ProbeVertex
            #pragma fragment ProbeBase
            ENDHLSL
        }
        Pass
        {
            Name "SpecColor"
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ProbeVertex
            #pragma fragment ProbeSpecular
            ENDHLSL
        }
        Pass
        {
            Name "EmissionColor"
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex ProbeVertex
            #pragma fragment ProbeEmission
            ENDHLSL
        }
    }
    Fallback Off
}
