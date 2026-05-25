Shader "Hidden/ScannerScreenPass"
{
    // Shader de pos-processamento para o scanner via Depth Texture.
    // Usado EXCLUSIVAMENTE por ScannerCameraEffect.cs (Graphics.Blit).
    // NAO atribuir a materiais de objetos.
    //
    // Vantagem: a grelha e a onda aparecem em TODOS os pixels do ecra,
    // incluindo objetos sem o material TAP/TerrainScannerShader.
    Properties
    {
        _MainTex         ("Screen",           2D)    = "white" {}
        [HDR] _WaveColor ("Wave Color",       Color) = (0.0, 1.0, 0.75, 1.0)
        _WaveWidth       ("Wave Width",       Float) = 1.2
        _WaveIntensity   ("Wave Intensity",   Float) = 4.0
        _WaveGlowRange   ("Wave Glow Range",  Float) = 12.0
        [HDR] _GridColor ("Grid Color",       Color) = (0.0, 0.6, 1.0, 1.0)
        _GridScale       ("Grid Scale",       Float) = 0.4
        _GridLineWidth   ("Grid Line Width",  Float) = 0.03
        _GridIntensity   ("Grid Intensity",   Float) = 1.8
        [HDR] _ContourColor    ("Contour Color",     Color) = (0.2, 0.9, 1.0, 1.0)
        _ContourSpacing  ("Contour Spacing",  Float) = 1.5
        _ContourWidth    ("Contour Width",    Float) = 0.02
        _ContourIntensity("Contour Intensity",Float) = 1.2
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            // Globais do scanner (set pelo TerrainScannerController)
            float4   _ScannerOrigin;
            float    _ScannerRadius;
            float    _ScannerMaxRadius;
            float    _ScannerActive;

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;
            float4x4  _InvVP;       // Inverse VP enviado pelo ScannerCameraEffect.cs

            float4 _WaveColor;
            float  _WaveWidth;
            float  _WaveIntensity;
            float  _WaveGlowRange;

            float4 _GridColor;
            float  _GridScale;
            float  _GridLineWidth;
            float  _GridIntensity;

            float4 _ContourColor;
            float  _ContourSpacing;
            float  _ContourWidth;
            float  _ContourIntensity;

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f     { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; float2 uvDepth : TEXCOORD1; };

            float GridLine(float v, float lw)
            {
                float f = frac(v - 0.5) - 0.5;
                return 1.0 - smoothstep(0.0, lw, abs(f));
            }

            float TriplanarGrid(float3 wpos, float3 N, float scale, float lw)
            {
                float3 blend = abs(N);
                blend = pow(blend, 6.0);
                blend /= (blend.x + blend.y + blend.z + 1e-4);
                float gx = max(GridLine(wpos.y * scale, lw), GridLine(wpos.z * scale, lw));
                float gy = max(GridLine(wpos.x * scale, lw), GridLine(wpos.z * scale, lw));
                float gz = max(GridLine(wpos.x * scale, lw), GridLine(wpos.y * scale, lw));
                return saturate(gx * blend.x + gy * blend.y + gz * blend.z);
            }

            // Reconstroi posicao 3D a partir do depth buffer + matriz InvVP
            float3 ReconstructWorldPos(float2 uv, float rawDepth)
            {
                float4 ndc = float4(uv.x * 2.0 - 1.0,
                                    uv.y * 2.0 - 1.0,
                                    rawDepth * 2.0 - 1.0,
                                    1.0);
                #if UNITY_UV_STARTS_AT_TOP
                    ndc.y = -ndc.y;
                #endif
                float4 wp = mul(_InvVP, ndc);
                return wp.xyz / wp.w;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos     = UnityObjectToClipPos(v.vertex);
                o.uv      = v.uv;
                o.uvDepth = v.uv;
                #if UNITY_UV_STARTS_AT_TOP
                    if (_ProjectionParams.x < 0) o.uvDepth.y = 1.0 - v.uv.y;
                #endif
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 screenCol = tex2D(_MainTex, i.uv);

                if (_ScannerActive < 0.5)
                    return screenCol;

                // Le profundidade e ignora skybox
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uvDepth);
                float linDepth = LinearEyeDepth(rawDepth);
                if (linDepth > _ProjectionParams.z * 0.99)
                    return screenCol;

                // Reconstroi posicao world-space
                float3 worldPos = ReconstructWorldPos(i.uvDepth, rawDepth);

                // Aproxima normal pela derivada da posicao (suficiente para triplanar)
                float3 N = normalize(cross(ddy(worldPos), ddx(worldPos)));

                // Calculo da onda
                float  dist       = length(worldPos - _ScannerOrigin.xyz);
                float  maxR       = max(_ScannerMaxRadius, 0.001);
                float  inside     = step(dist, _ScannerRadius);
                float  radiusFade = saturate((1.0 - dist / maxR) * 3.0);

                float  distToFront = abs(dist - _ScannerRadius);
                float  waveMask    = smoothstep(_WaveWidth, 0.0, distToFront) * radiusFade;
                float3 waveGlow    = _WaveColor.rgb * waveMask * _WaveIntensity;

                float  trailFade   = pow(saturate((_ScannerRadius - dist) / _WaveGlowRange),
                                         1.8) * inside * radiusFade;

                float  grid        = TriplanarGrid(worldPos, N, _GridScale, _GridLineWidth);
                float3 gridCol     = _GridColor.rgb * grid * _GridIntensity * trailFade;

                float  contour     = GridLine(worldPos.y / _ContourSpacing, _ContourWidth);
                float3 contourCol  = _ContourColor.rgb * contour * _ContourIntensity * trailFade;

                // Adiciona efeito por cima do frame renderizado
                return fixed4(screenCol.rgb + waveGlow + gridCol + contourCol, 1.0);
            }
            ENDCG
        }
    }
}
