Shader "Custom/RickAndMortyPortal"
{
    Properties
    {
         // Cores principais do portal e controlo da animação
         [HDR] _MainColor ("Verde Brilhante (HDR)", Color) = (0.0, 1.0, 0.2, 1.0)
      [HDR]  _DarkColor ("Verde Escuro", Color) = (0.0, 0.1, 0.02, 1.0)
        [HDR] _CoreColor ("Centro do Portal", Color) = (0.8, 1.0, 0.7, 1.0)
        _Speed ("Velocidade do Vórtice", Range(0, 10)) = 4.0
        _WaveStrength ("Distorçao das Bolhas", Range(0, 1)) = 0.4
    }
    SubShader
    {
        // Shader transparente pensado para parecer um portal com brilho e movimento
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _MainColor;
            float4 _DarkColor;
            float4 _CoreColor;
            float _Speed;
            float _WaveStrength;

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv ;
                return o;
            }

            // Função pseudo-ruído para gerar as bolhas orgânicas que quis tenar copiar o rick and morty
            float noise(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // Centralizar coordenadas UV de -0.5 a 0.5
                float2 uv = i.uv - 0.5;
                float r = length(uv);
                float angle = atan2(uv.y, uv.x);

                // Mantém o formato redondo do portal, cortando as partes fora do círculo
                float alphaEdge = smoothstep(0.5, 0.47, r);

                // Simulamos profundidade usando a distância ao centro:
                // quanto mais perto do centro, mais o portal parece entrar para dentro
                float depth = 1.0 / (r + 0.001);

                // Aqui criamos o vórtice: o ângulo + a profundidade fazem o movimento em espiral
                float swirl = angle + depth * 0.2 - _Time.y * _Speed;

                // As "bolhas" e ondulações nascem de ondas que se misturam e mudam com o tempo
                float pattern = sin(swirl * 6.0) * cos(depth * 0.5 + _Time.y);
                pattern += sin(angle * 3.0 - _Time.y * 2.0) * _WaveStrength;
                
                // Pequenos detalhes extras para o portal parecer mais vivo e cheio
                pattern += sin(depth * 2.0 - _Time.y * _Speed) * 0.2;

                // Mistura entre verde escuro e verde brilhante para formar o corpo do portal
                float colorMask = saturate(pattern * 0.5 + 0.5);
                fixed4 col = lerp(_DarkColor, _MainColor, colorMask);

                // O centro fica mais claro para dar a sensação de fundo luminoso
                float coreGlowing = smoothstep(0.0, 15.0, depth);
                col = lerp(col, _CoreColor, coreGlowing * 0.7);

                return fixed4(col.rgb, alphaEdge);
            }
            ENDCG
        }
    }
    FallBack "Transparent/VertexLit"
}