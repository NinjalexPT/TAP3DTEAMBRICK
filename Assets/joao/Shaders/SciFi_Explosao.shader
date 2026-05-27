Shader "Custom/SciFi_Explosao_Geom_Texturado"
{
    Properties
    {
        // Textura base, normal map e mapa para brilho/reflexo
        _MainTex ("Albedo (Cor)", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _RefMap ("Specular/Reflection Map", 2D) = "white" {}
        
        // Cor do núcleo da explosão e controlo do efeito
        [HDR] _GlowColor ("Cor do Nucleo (Explosao)", Color) = (0, 0.8, 1, 1)
        _Explosion ("Forca da Explosao", Range(0.0, 1.0)) = 0.0
        _Shrink ("Encolher Estilhacos", Range(0.0, 1.0)) = 0.0
    }
    SubShader
    {
        // Shader opaco com geometria: serve para deformar o modelo em tempo real
        Tags { "RenderType"="Opaque" "Cull"="Off" }
        LOD 200

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 4.0 

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2g
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wPos : TEXCOORD1;
                float3 wNormal : NORMAL;
                float3 wTangent : TANGENT;
                float3 wBitangent : BINORMAL;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            sampler2D _RefMap;
            
            float4 _GlowColor;
            float _Explosion;
            float _Shrink;

            float random(float2 st)
            {
                // Valor Random para cada triangulo, para que pareça a explosao seja diferente
                return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453123);
            }

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex; 
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = v.normal;
                o.tangent = v.tangent;
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle v2g input[3], inout TriangleStream<g2f> stream)
            {
                // Calcula o centro do triângulo para sabermos para onde ele vai encolher
                float4 centro = (input[0].vertex + input[1].vertex + input[2].vertex) / 3.0;

                // Direção usada para empurrar os triângulos para fora
                float3 edge1 = input[1].vertex.xyz - input[0].vertex.xyz;
                float3 edge2 = input[2].vertex.xyz - input[0].vertex.xyz;
                float3 faceNormal = normalize(cross(edge1, edge2));

                // Número aleatório por triângulo para que a explosão não fique igual em todo lado
                float rnd = random(centro.xy) * 2.0;

                for (int i = 0; i < 3; i++)
                {
                    g2f o;
                    
                    // Cada vértice aproxima-se do centro para parecer q desaparece
                    float4 posLocal = lerp(input[i].vertex, centro, _Shrink);
                    
                    // A explosão empurra os pedaços para fora, de forma suave
                    posLocal.xyz += faceNormal * (_Explosion * 0.05) * rnd;

                    o.pos = UnityObjectToClipPos(posLocal);
                    o.wPos = mul(unity_ObjectToWorld, posLocal).xyz;
                    o.uv = input[i].uv;

                    // Normais e tangentes servem para aplicar corretamente a luz e as texturas
                    o.wNormal = UnityObjectToWorldNormal(input[i].normal);
                    o.wTangent = UnityObjectToWorldDir(input[i].tangent.xyz);
                    
                    float tangentSign = input[i].tangent.w * unity_WorldTransformParams.w;
                    o.wBitangent = cross(o.wNormal, o.wTangent) * tangentSign;

                    stream.Append(o);
                }
                stream.RestartStrip();
            }

            fixed4 frag (g2f i) : SV_Target
            {
                // Cor do objeto
                fixed4 albedo = tex2D(_MainTex, i.uv);
                // Normal map para dar relevo e detalhe sem aumentar polígonos
                float3 texNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
                // Mapa que controla o brilho especular
                float gloss = tex2D(_RefMap, i.uv).r;

                // Converte a normal da textura para espaço do mundo
                float3x3 TBN = float3x3(i.wTangent, i.wBitangent, i.wNormal);
                float3 worldNormal = normalize(mul(texNormal, TBN));

                // Direção da luz e da câmara
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
                
                // Luz difusa: ilumina mais as partes viradas para a luz
                float diff = max(0.0, dot(worldNormal, lightDir));
                
                // Brilho especular: pequenos pontos brilhantes nas superfícies
                float3 halfVector = normalize(lightDir + viewDir);
                float nh = max(0.0, dot(worldNormal, halfVector));
                float spec = pow(nh, 48.0) * gloss;

                // Mistura da iluminação principal com o brilho metálico
                float3 iluminacao = (albedo.rgb * _LightColor0.rgb * diff) + (_LightColor0.rgb * spec);
                // Luz azulada extra no núcleo da explosão
                float3 glow = _GlowColor.rgb * (_Explosion * 2.0) * albedo.rgb;

                return fixed4(iluminacao + glow, 1.0);
            }
            ENDCG
        }
    }
}