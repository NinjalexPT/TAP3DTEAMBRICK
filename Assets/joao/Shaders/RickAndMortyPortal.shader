Shader "Custom/RickAndMortyPortal"
{
    Properties
    {
         [HDR] _MainColor ("Verde Brilhante (HDR)", Color) = (0.0, 1.0, 0.2, 1.0)
      [HDR]  _DarkColor ("Verde Escuro", Color) = (0.0, 0.1, 0.02, 1.0)
        [HDR] _CoreColor ("Centro do Portal", Color) = (0.8, 1.0, 0.7, 1.0)
        _Speed ("Velocidade do Vórtice", Range(0, 10)) = 4.0
        _WaveStrength ("Distorçao das Bolhas", Range(0, 1)) = 0.4
    }
    SubShader
    {
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

            // Função pseudo-ruído para gerar as bolhas orgânicas do desenho animado
            float noise(float2 p) {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // Centralizar coordenadas UV de -0.5 a 0.5
                float2 uv = i.uv - 0.5;
                float r = length(uv);
                float angle = atan2(uv.y, uv.x);

                // Forçar o corte circular perfeito na borda do plano
                float alphaEdge = smoothstep(0.5, 0.47, r);

                // Efeito de Profundidade Infinito (Túnel)
                // O inverso do raio (1/r) faz com que o centro pareça infinitamente longe
                float depth = 1.0 / (r + 0.001);

                // Criar o turbilhão espiral (Vórtice)
                float swirl = angle + depth * 0.2 - _Time.y * _Speed;

                // Gerar o padrão de "bolhas" do Rick and Morty combinando ondas senoidais distorcidas
                float pattern = sin(swirl * 6.0) * cos(depth * 0.5 + _Time.y);
                pattern += sin(angle * 3.0 - _Time.y * 2.0) * _WaveStrength;
                
                // Adicionar micro-detalhes baseados na profundidade para parecer denso
                pattern += sin(depth * 2.0 - _Time.y * _Speed) * 0.2;

                // Interpolação de cores (Base do portal)
                float colorMask = saturate(pattern * 0.5 + 0.5);
                fixed4 col = lerp(_DarkColor, _MainColor, colorMask);

                // Brilho central (Efeito de luz no fundo do túnel)
                float coreGlowing = smoothstep(0.0, 15.0, depth);
                col = lerp(col, _CoreColor, coreGlowing * 0.7);

                return fixed4(col.rgb, alphaEdge);
            }
            ENDCG
        }
    }
    FallBack "Transparent/VertexLit"
}