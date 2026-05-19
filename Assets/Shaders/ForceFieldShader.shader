Shader "Unlit/ForceFieldShader"
{
    Properties
    {
     // --- Cores ---
        _CoreColor ("Core Color", Color) = (0.0, 0.8, 1.0, 0.6)
        _RimColor  ("Rim / Edge Color", Color) = (0.0, 1.0, 1.0, 1.0)
        _FresnelPower ("Fresnel Power", Range(0.5, 8.0)) = 3.0

        // --- Hexagonos / Grelha ---
        _HexTex         ("Hex / Pattern Tex", 2D) = "white" {}
        _HexTiling      ("Hex Tiling", Float) = 6.0
        _HexBrightness  ("Hex Brightness", Range(0.0, 2.0)) = 1.2

        // --- Pulsação das normais ---
        _PulseAmplitude ("Pulse Amplitude",    Range(0.0, 0.5)) = 0.08
        _PulseFrequency ("Pulse Frequency",    Range(0.1, 10.0)) = 2.0
        _PulseSpeed     ("Pulse Speed",        Range(0.0, 5.0)) = 1.5
        // Escala do ruído espacial que quebra a uniformidade da pulsacao
        _PulseNoiseScale("Pulse Noise Scale",  Range(0.1, 20.0)) = 4.0

        // --- Scanlines / ondas horizontais ---
        _ScanlineSpeed  ("Scanline Speed",     Range(-5.0, 5.0)) = 1.2
        _ScanlineDensity("Scanline Density",   Range(1.0, 40.0)) = 12.0
        _ScanlineWidth  ("Scanline Width",     Range(0.01, 0.5)) = 0.08
        _ScanlineIntensity("Scanline Intensity", Range(0.0, 1.0)) = 0.35

        // --- Transparencia e blend ---
        _Opacity        ("Global Opacity",     Range(0.0, 1.0)) = 0.75
        _IntersectionPow("Intersection Power", Range(0.5, 4.0)) = 1.5
    }

    SubShader
    {
        // Fila transparente, sem Z-write, renderiza frente e verso
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        LOD 200

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off          // ver interior da esfera também

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target   3.0

            #include "UnityCG.cginc"

            //  Propriedades expostas 
            fixed4  _CoreColor;
            fixed4  _RimColor;
            float   _FresnelPower;

            sampler2D _HexTex;
            float4    _HexTex_ST;
            float     _HexTiling;
            float     _HexBrightness;

            float _PulseAmplitude;
            float _PulseFrequency;
            float _PulseSpeed;
            float _PulseNoiseScale;

            float _ScanlineSpeed;
            float _ScanlineDensity;
            float _ScanlineWidth;
            float _ScanlineIntensity;

            float _Opacity;
            float _IntersectionPow;

            //  Estruturas 
            struct appdata
            {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float2 uv      : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos      : SV_POSITION;
                float2 uv       : TEXCOORD0;
                float3 worldNrm : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 viewDir  : TEXCOORD3;
                // posicao local antes do deslocamento (para o ruído)
                float3 localPos : TEXCOORD4;
            };

            //  Funcoes auxiliares 

            // Hash simples sem textura (evita dependências externas)
            float hash(float3 p)
            {
                p = frac(p * float3(443.8975, 397.2973, 491.1871));
                p += dot(p, p.yxz + 19.19);
                return frac((p.x + p.y) * p.z);
            }

            // Ruido suave 3D (Value Noise trilinear)
            float valueNoise(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);
                float3 u = f * f * (3.0 - 2.0 * f); // smoothstep

                return lerp(
                    lerp(
                        lerp(hash(i + float3(0,0,0)), hash(i + float3(1,0,0)), u.x),
                        lerp(hash(i + float3(0,1,0)), hash(i + float3(1,1,0)), u.x),
                        u.y),
                    lerp(
                        lerp(hash(i + float3(0,0,1)), hash(i + float3(1,0,1)), u.x),
                        lerp(hash(i + float3(0,1,1)), hash(i + float3(1,1,1)), u.x),
                        u.y),
                    u.z);
            }

            // Vertex shader 
            v2f vert(appdata v)
            {
                v2f o;

                // Ruido espacial que varia por fragmento da esfera
                float3 noisePos   = v.vertex.xyz * _PulseNoiseScale;
                float  noiseVal   = valueNoise(noisePos);          // [0, 1]

                // Fase individual por fragmento: offset de fase aleatório
                float phaseOffset = noiseVal * UNITY_TWO_PI;

                // Envelope pulsatorio: sin oscila entre -1 e 1 
                //   mapeia para [0, 1] com meio-onda positivo para "expandir"
                float pulse = sin(_Time.y * _PulseFrequency * UNITY_TWO_PI * 0.1
                                  + phaseOffset
                                  + _PulseSpeed * _Time.y) * 0.5 + 0.5;

                // Deslocamento ao longo da normal local
                float3 displaced = v.vertex.xyz + v.normal * (pulse * _PulseAmplitude);

                o.localPos  = v.vertex.xyz;
                o.pos       = UnityObjectToClipPos(float4(displaced, 1.0));
                o.uv        = v.uv;
                o.worldNrm  = UnityObjectToWorldNormal(v.normal);
                o.worldPos  = mul(unity_ObjectToWorld, float4(displaced, 1.0)).xyz;
                o.viewDir   = normalize(_WorldSpaceCameraPos - o.worldPos);

                return o;
            }

            // Fragment shader 
            fixed4 frag(v2f i) : SV_Target
            {
                float3 N = normalize(i.worldNrm);
                float3 V = normalize(i.viewDir);

                // Fresnel (rim glow) 
                float  NdotV    = saturate(dot(N, V));
                float  fresnel  = pow(1.0 - NdotV, _FresnelPower);

                //  Textura de padrão (hex / grelha) 
                float2 hexUV    = i.uv * _HexTiling;
                fixed4 hexSample= tex2D(_HexTex, TRANSFORM_TEX(hexUV, _HexTex));
                float  hexMask  = hexSample.r * _HexBrightness;

                //  Scanlines (ondas que percorrem a esfera verticalmente)
                // Usa a coordenada Y do mundo normalizada para as linhas
                float scanCoord = i.worldPos.y * _ScanlineDensity
                                  + _Time.y * _ScanlineSpeed;
                float scan      = abs(frac(scanCoord) - 0.5);
                float scanLine  = 1.0 - smoothstep(0.0, _ScanlineWidth, scan);
                scanLine       *= _ScanlineIntensity;

                // Cor base: mistura cor e  rim pelo fresnel 
                fixed4 baseColor = lerp(_CoreColor, _RimColor, fresnel);

                // Adiciona contribuições
                baseColor.rgb += hexMask  * _RimColor.rgb * 0.4;
                baseColor.rgb += scanLine * _RimColor.rgb;

                //  Alpha: fresnel + hexagonos + scanlines + opacidade global
                float alpha = saturate(fresnel * 1.5 + hexMask * 0.4 + scanLine) * _Opacity;

                return fixed4(baseColor.rgb, alpha);
            }
            ENDCG
        }
    }

    FallBack "Transparent/Diffuse"
}
