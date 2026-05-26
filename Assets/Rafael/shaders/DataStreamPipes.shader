Shader "Custom/DataStreamPipes"

{
    Properties
    {
        [HDR] _Color ("Cor do Stream", Color) = (0.0, 1.0, 0.2, 1.0) 
        _MainTex ("Textura dos Caracteres", 2D) = "white" {}
        _Columns ("Número de Colunas", Float) = 20.0
        _Speed ("Velocidade Base", Float) = 1.0
        _Tiling ("Tamanho da Textura (Tiling)", Float) = 1.0 
        _GlowIntensity ("Intensidade do Glow das Letras", Float) = 2.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1; 
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _Color;
            float _Columns;
            float _Speed;
            float _Tiling;
            float _GlowIntensity; // Declarar a variável aqui para o CG usar

            float random(float x)
            {
                return frac(sin(x) * 43758.5453123);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 baseUV = i.worldPos.xy * _Tiling;

                // 1. DIVIDIR EM COLUNAS
                float idColuna = floor(baseUV.x * _Columns);

                // 2. GERAR VELOCIDADE ALEATÓRIA
                float velocidadeAleatoria = random(idColuna) + 0.5;

                // 3. CALCULAR O MOVIMENTO
                float offsetVertical = _Time.y * _Speed * velocidadeAleatoria;

                // 4. APLICAR MOVIMENTO AOS UVs
                float2 uvAnimado = baseUV;
                uvAnimado.y -= offsetVertical;

                // 5. LER A TEXTURA E APLICAR A COR COM O GLOW
                // Multiplicamos pela _GlowIntensity para "estourar" o valor e gerar Bloom
                fixed4 col = tex2D(_MainTex, uvAnimado) * _Color * _GlowIntensity;

                return col;
            }
            ENDCG
        }
    }
}