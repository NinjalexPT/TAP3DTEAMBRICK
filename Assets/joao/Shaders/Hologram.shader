Shader "Custom/SCI-FI/Hologram"
{
    Properties
    { 
        _BaseColor ("Cor Base", Color) = (0.2, 0.9, 1.0, 1.0)
        _EmissionColor ("Cor de Emissao", Color) = (0.4, 1.0, 1.0, 1.0)
        _Alpha ("Transparencia", Range(0.0, 1.0)) = 0.7
        
        [Header(Glitch Settings)]
        _GlitchAmplitude ("Amplitude do Glitch", Range(0, 0.2)) = 0.05
        _GlitchFrequency ("Frequencia do Glitch", Range(0, 100)) = 20
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend SrcAlpha One
            ZWrite Off
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"

            static const float FRESNEL_POWER = 4.0;
            static const float EDGE_INTENSITY = 4.0;
            static const float SCANLINE_DENSITY = 200.0;
            static const float SCANLINE_SPEED = 16.0;
            static const float SCANLINE_STRENGTH = 1.3;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
            };

            float4 _BaseColor;
            float4 _EmissionColor;
            float _Alpha;
            float _GlitchAmplitude;
            float _GlitchFrequency;

            v2f vert(appdata v)
            {
                v2f o;
                
                // --- Lógica do Glitch Sideways ---
                // Geramos um valor aleatório baseado no tempo
                float time = _Time.y * _GlitchFrequency;
                float randomOffset = frac(sin(dot(float2(floor(time), 0.0), float2(12.9898, 78.233))) * 43758.5453);
                
                // Se o valor aleatório for muito alto, aplicamos o glitch (ocorre de forma esporádica)
                if (randomOffset > 0.9) 
                {
                    // Deslocamos o X baseado na altura (v.vertex.y) para criar o efeito de "rasgão"
                    v.vertex.x += sin(v.vertex.y * 10.0 + _Time.y * 50.0) * _GlitchAmplitude;
                }
                // ----------------------------------

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                float3 normalDir = normalize(i.worldNormal);

                float fresnel = pow(1.0 - saturate(dot(viewDir, normalDir)), FRESNEL_POWER);
                float edge = fresnel * EDGE_INTENSITY;

                float scanPhase = (i.worldPos.y * SCANLINE_DENSITY) - (_Time.y * SCANLINE_SPEED);
                float scanline = 0.5 + 0.5 * sin(scanPhase);
                scanline = lerp(1.0, scanline, SCANLINE_STRENGTH);

                float pulse = 0.65 + 0.35 * sin(_Time.y * 4.0 + i.worldPos.y * 2.0);
                float intensity = saturate(edge + scanline * 0.35) * pulse;

                float3 color = _BaseColor.rgb * 0.25 + _EmissionColor.rgb * intensity;
                float alpha = saturate((_Alpha * 0.35) + fresnel * 0.65 + scanline * 0.1);

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}