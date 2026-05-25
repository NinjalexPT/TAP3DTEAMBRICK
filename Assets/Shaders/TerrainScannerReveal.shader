Shader "TAP/TerrainScannerReveal"
{
    // Aplicar a objetos que começam INVISIVEIS e sao revelados pela onda do scanner.
    // Alpha = 0 por defeito. Quando a frente da onda passa, o objeto aparece
    // com um glow de bordo e fica visivel enquanto o trail estiver ativo.
    // Para revelar permanentemente, usa o script: mat.SetFloat("_PermanentReveal", 1f);
    Properties
    {
        [Header(Base Surface)]
        _MainTex         ("Base Texture",     2D)         = "white" {}
        _BaseColor       ("Base Color",       Color)      = (0.7, 0.85, 1.0, 1.0)
        _Smoothness      ("Smoothness",       Range(0,1)) = 0.5

        [Header(Reveal)]
        [HDR]
        _RevealColor     ("Reveal Edge Color",  Color)        = (1.0, 0.55, 0.0, 1.0)
        _RevealIntensity ("Reveal Intensity",   Range(0, 8))  = 3.5
        _RevealEdgeSharp ("Edge Sharpness",     Range(1, 8))  = 3.0
        _PermanentReveal ("Permanent Reveal",   Range(0, 1))  = 0.0
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            float4 _ScannerOrigin;
            float  _ScannerRadius;
            float  _ScannerMaxRadius;
            float  _ScannerActive;

            sampler2D _MainTex;
            float4    _MainTex_ST;
            float4    _BaseColor;
            float     _Smoothness;
            float4    _RevealColor;
            float     _RevealIntensity;
            float     _RevealEdgeSharp;
            float     _PermanentReveal;

            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; float2 uv : TEXCOORD0; };
            struct v2f     { float4 pos : SV_POSITION; float2 uv : TEXCOORD0;
                             float3 worldPos : TEXCOORD1; float3 worldNorm : TEXCOORD2; };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos       = UnityObjectToClipPos(v.vertex);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 N    = normalize(i.worldNorm);
                float  dist = length(i.worldPos - _ScannerOrigin.xyz);
                float  maxR = max(_ScannerMaxRadius, 0.001);

                float  radiusFade  = saturate((1.0 - dist / maxR) * 3.0);
                float  inside      = step(dist, _ScannerRadius);
                float  trailFade   = pow(saturate((_ScannerRadius - dist) / 12.0),
                                         1.8) * inside * radiusFade;

                // Borda da revelacao: anel brilhante na frente da onda
                float  distToFront = abs(dist - _ScannerRadius);
                float  frontMask   = smoothstep(2.0, 0.0, distToFront) * radiusFade;

                // Alpha: sobe suavemente conforme a onda passa
                float  wavePassed  = saturate((_ScannerRadius - dist) / 1.5);
                float  alpha       = pow(wavePassed, _RevealEdgeSharp)
                                   * _ScannerActive * radiusFade;
                alpha = max(alpha, _PermanentReveal);   // revelacao permanente

                // Base lighting
                float4 baseTex = tex2D(_MainTex, i.uv);
                float3 baseCol = baseTex.rgb * _BaseColor.rgb;
                float  NdotL   = saturate(dot(N, _WorldSpaceLightPos0.xyz));
                float3 lit     = baseCol * (NdotL * 0.8 + 0.3);

                // Rim glow laranja na borda de revelacao
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float  rim     = pow(1.0 - saturate(dot(N, viewDir)), 3.0);
                float3 rimGlow = _RevealColor.rgb * (rim * trailFade + frontMask)
                               * _RevealIntensity;

                return fixed4(lit + rimGlow, alpha);
            }
            ENDCG
        }
    }
    FallBack "Transparent/Diffuse"
}
