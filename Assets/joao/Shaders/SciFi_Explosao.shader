Shader "Custom/SciFi_Explosao_Geom_Texturado"
{
    Properties
    {
        _MainTex ("Albedo (Cor)", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _RefMap ("Specular/Reflection Map", 2D) = "white" {}
        
        [HDR] _GlowColor ("Cor do Nucleo (Explosao)", Color) = (0, 0.8, 1, 1)
        _Explosion ("Forca da Explosao", Range(0.0, 1.0)) = 0.0
        _Shrink ("Encolher Estilhacos", Range(0.0, 1.0)) = 0.0
    }
    SubShader
    {
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
                float4 centro = (input[0].vertex + input[1].vertex + input[2].vertex) / 3.0;

                float3 edge1 = input[1].vertex.xyz - input[0].vertex.xyz;
                float3 edge2 = input[2].vertex.xyz - input[0].vertex.xyz;
                float3 faceNormal = normalize(cross(edge1, edge2));

                float rnd = random(centro.xy) * 2.0;

                for (int i = 0; i < 3; i++)
                {
                    g2f o;
                    
                    // Encolhe em direção ao centro do triângulo com base no _Shrink
                    float4 posLocal = lerp(input[i].vertex, centro, _Shrink);
                    
                    // Suavizado com multiplicador 0.05 para o slider ser macio
                    posLocal.xyz += faceNormal * (_Explosion * 0.05) * rnd;

                    o.pos = UnityObjectToClipPos(posLocal);
                    o.wPos = mul(unity_ObjectToWorld, posLocal).xyz;
                    o.uv = input[i].uv;

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
                fixed4 albedo = tex2D(_MainTex, i.uv);
                float3 texNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
                float gloss = tex2D(_RefMap, i.uv).r;

                float3x3 TBN = float3x3(i.wTangent, i.wBitangent, i.wNormal);
                float3 worldNormal = normalize(mul(texNormal, TBN));

                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
                
                float diff = max(0.0, dot(worldNormal, lightDir));
                
                float3 halfVector = normalize(lightDir + viewDir);
                float nh = max(0.0, dot(worldNormal, halfVector));
                float spec = pow(nh, 48.0) * gloss;

                float3 iluminacao = (albedo.rgb * _LightColor0.rgb * diff) + (_LightColor0.rgb * spec);
                float3 glow = _GlowColor.rgb * (_Explosion * 2.0) * albedo.rgb;

                return fixed4(iluminacao + glow, 1.0);
            }
            ENDCG
        }
    }
}