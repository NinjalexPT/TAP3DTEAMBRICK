Shader "Custom/CameraGlitch"
{
    Properties
    {
        // A RenderTexture da câmara deve ser atribuída aqui
        _MainTex ("Camera RenderTexture", 2D) = "white" {}

        // ── Glitch Controls ──────────────────────────────────────────────────
        [Toggle] _GlitchEnabled ("Glitch Enabled", Float) = 0

        _GlitchIntensity   ("Glitch Intensity",    Range(0, 1))   = 0.3
        _GlitchSpeed       ("Glitch Speed",        Range(0, 20))  = 5.0
        _BlockSize         ("Block Size",           Range(0.01, 0.5)) = 0.05
        _ScanlineStrength  ("Scanline Strength",   Range(0, 1))   = 0.15
        _RGBShift          ("RGB Shift Amount",    Range(0, 0.05)) = 0.01
        _DigitalNoise      ("Digital Noise",        Range(0, 1))   = 0.1
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue"      = "Geometry"
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target   3.0

            #include "UnityCG.cginc"

            // ── Uniforms ─────────────────────────────────────────────────────
            sampler2D _MainTex;
            float4    _MainTex_ST;

            float _GlitchEnabled;
            float _GlitchIntensity;
            float _GlitchSpeed;
            float _BlockSize;
            float _ScanlineStrength;
            float _RGBShift;
            float _DigitalNoise;

            // ── Structs ───────────────────────────────────────────────────────
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv  : TEXCOORD0;
            };

            // ── Helpers ───────────────────────────────────────────────────────

            // Hash pseudo-aleatório rápido (sem texturas extra)
            float hash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float hash1(float n) { return frac(sin(n) * 43758.5453); }

            // ── Vertex ────────────────────────────────────────────────────────
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            // ── Fragment ──────────────────────────────────────────────────────
            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                // ── Sem glitch: apenas amostra a textura ──────────────────────
                if (_GlitchEnabled < 0.5)
                {
                    return tex2D(_MainTex, uv);
                }

                // ── Com glitch ────────────────────────────────────────────────
                float t = _Time.y * _GlitchSpeed;

                // 1. Deslocamento horizontal em blocos (block tearing)
                float blockY    = floor(uv.y / _BlockSize);
                float blockRand = hash(float2(blockY, floor(t * 2.0)));
                float tearAmt   = (blockRand - 0.5) * 2.0 * _GlitchIntensity;

                // Activar o rasgo só em alguns blocos / momentos
                float tearTrigger = step(0.75, hash(float2(blockY * 7.3, floor(t))));
                float2 uvGlitch   = uv + float2(tearAmt * tearTrigger, 0.0);

                // 2. Saltos verticais ocasionais (jump cuts)
                float jumpTrigger = step(0.97, hash1(floor(t * 3.0)));
                uvGlitch.y += (hash1(floor(t * 3.0) + 0.5) - 0.5) * jumpTrigger * _GlitchIntensity;

                // Clampar para evitar wrap indesejado
                uvGlitch = saturate(uvGlitch);

                // 3. Separação de canais RGB (chromatic aberration)
                float shiftX = _RGBShift * _GlitchIntensity;
                float shiftStep = step(0.6, hash1(floor(t * 5.0)));
                float2 uvR = uvGlitch + float2( shiftX * shiftStep, 0.0);
                float2 uvB = uvGlitch + float2(-shiftX * shiftStep, 0.0);

                float r = tex2D(_MainTex, saturate(uvR)).r;
                float g = tex2D(_MainTex, uvGlitch).g;
                float b = tex2D(_MainTex, saturate(uvB)).b;

                fixed4 col = fixed4(r, g, b, 1.0);

                // 4. Linhas de varrimento (scanlines)
                float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
                col.rgb -= scanline * _ScanlineStrength;

                // 5. Ruído digital (pixel dropout)
                float noise    = hash(float2(uv.x * 100.0 + t, uv.y * 100.0));
                float noiseHit = step(1.0 - _DigitalNoise * _GlitchIntensity, noise);
                col.rgb        = lerp(col.rgb, fixed3(noise, noise, noise), noiseHit * 0.8);

                // 6. Flash de brilho breve (white flash)
                float flashTrigger = step(0.99, hash1(floor(t * 7.0)));
                col.rgb = lerp(col.rgb, fixed3(1, 1, 1), flashTrigger * _GlitchIntensity * 0.4);

                // 7. Vinheta leve para ancorar o efeito
                float2 vigUV   = uv * 2.0 - 1.0;
                float  vignette = 1.0 - dot(vigUV, vigUV) * 0.25;
                col.rgb *= saturate(vignette);

                return saturate(col);
            }
            ENDCG
        }
    }

    FallBack "Diffuse"
}
