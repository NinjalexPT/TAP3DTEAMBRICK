Shader "TerrainScannerShader"
{
    // ═══════════════════════════════════════════════════════════════
    //  TerrainScannerShader — Versão Completa
    //  Inclui: Triplanar Grid · Contour Lines · Vertex Displacement
    //          Depth Texture (soft edges) · Opacity Masking (Reveal)
    // ═══════════════════════════════════════════════════════════════
    Properties
    {
        [Header(Base Surface)]
        _MainTex          ("Base Texture",          2D)               = "white" {}
        _BaseColor        ("Base Color",            Color)            = (0.15, 0.16, 0.22, 1.0)
        _Smoothness       ("Smoothness",            Range(0,1))       = 0.4

        [Header(Scanner Wave)]
        [HDR]
        _WaveColor        ("Wave Front Color",      Color)            = (0.0, 1.0, 0.75, 1.0)
        _WaveWidth        ("Wave Front Width",      Range(0.05, 8.0)) = 1.2
        _WaveGlowRange    ("Wave Trail Range",      Range(0.5, 40.0)) = 12.0
        _WaveIntensity    ("Wave Intensity",        Range(0.5, 10.0)) = 4.0

        [Header(Triplanar Grid)]
        [HDR]
        _GridColor        ("Grid Color",            Color)            = (0.0, 0.6, 1.0, 1.0)
        _GridScale        ("Grid Scale",            Range(0.05, 4.0)) = 0.4
        _GridLineWidth    ("Grid Line Width",       Range(0.005,0.15))= 0.03
        _GridIntensity    ("Grid Intensity",        Range(0.0, 4.0))  = 1.8

        [Header(Contour Lines)]
        [HDR]
        _ContourColor     ("Contour Color",         Color)            = (0.2, 0.9, 1.0, 1.0)
        _ContourSpacing   ("Contour Spacing (m)",   Range(0.1, 10.0)) = 1.5
        _ContourWidth     ("Contour Width",         Range(0.005,0.1)) = 0.02
        _ContourIntensity ("Contour Intensity",     Range(0.0, 4.0))  = 1.2

        [Header(Item Reveal)]
        [HDR]
        _RevealColor      ("Reveal Color",          Color)            = (1.0, 0.55, 0.0, 1.0)
        _RevealIntensity  ("Reveal Intensity",      Range(0.0, 8.0))  = 3.5
        _IsRevealable     ("Is Revealable",         Range(0,1))       = 0.0

        [Header(Vertex Displacement)]
        _DisplaceStrength ("Displace Strength",     Range(0.0, 0.5))  = 0.08
        _DisplaceWidth    ("Displace Width",        Range(0.1, 5.0))  = 2.0

        [Header(Rendering)]
        [Toggle] _ZWrite  ("Z Write (Off para Reveal)", Float)        = 1
    }

    SubShader
    {
        // Transparent para suportar o Opacity Masking dos itens revelavel.
        // Terreno usa _ZWrite=1 e finalAlpha=1, comporta-se como opaco.
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 300
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite [_ZWrite]

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            // ── Depth Texture (activada via script na camara) ─────────
            sampler2D _CameraDepthTexture;

            // ── Globais do scanner (TerrainScannerController.cs) ──────
            float4 _ScannerOrigin;      // world-space XYZ origem da onda
            float  _ScannerRadius;      // raio atual em expansao
            float  _ScannerMaxRadius;   // raio maximo (controla fade)
            float  _ScannerActive;      // 0 = inativo | 1 = ativo
            float  _ScannerRevealItems; // 0 = nao revela | 1 = revela

            // ── Material props ────────────────────────────────────────
            sampler2D _MainTex;
            float4    _MainTex_ST;
            float4    _BaseColor;
            float     _Smoothness;

            float4 _WaveColor;
            float  _WaveWidth;
            float  _WaveGlowRange;
            float  _WaveIntensity;

            float4 _GridColor;
            float  _GridScale;
            float  _GridLineWidth;
            float  _GridIntensity;

            float4 _ContourColor;
            float  _ContourSpacing;
            float  _ContourWidth;
            float  _ContourIntensity;

            float4 _RevealColor;
            float  _RevealIntensity;
            float  _IsRevealable;

            float _DisplaceStrength;
            float _DisplaceWidth;

            // ─────────────────────────────────────────────────────────
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos       : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 worldPos  : TEXCOORD1;
                float3 worldNorm : TEXCOORD2;
                float4 screenPos : TEXCOORD3;   // para depth texture
                SHADOW_COORDS(4)
            };

            // ─────────────────────────────────────────────────────────
            // Helpers de grid / contorno
            // ─────────────────────────────────────────────────────────

            float GridLine(float v, float lw)
            {
                float f = frac(v - 0.5) - 0.5;
                return 1.0 - smoothstep(0.0, lw, abs(f));
            }

            float TriplanarGrid(float3 wpos, float3 wnorm, float scale, float lw)
            {
                float3 blend = abs(wnorm);
                blend = pow(blend, 6.0);
                blend /= (blend.x + blend.y + blend.z + 1e-4);

                float gx = max(GridLine(wpos.y * scale, lw), GridLine(wpos.z * scale, lw));
                float gy = max(GridLine(wpos.x * scale, lw), GridLine(wpos.z * scale, lw));
                float gz = max(GridLine(wpos.x * scale, lw), GridLine(wpos.y * scale, lw));

                return saturate(gx * blend.x + gy * blend.y + gz * blend.z);
            }

            float ContourLine(float worldY, float spacing, float lw)
            {
                return GridLine(worldY / spacing, lw);
            }

            // ─────────────────────────────────────────────────────────
            v2f vert(appdata v)
            {
                // ── Vertex Displacement ───────────────────────────────
                // 1. Calcular posicao world ANTES do deslocamento
                float3 worldPos0  = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNorm0 = UnityObjectToWorldNormal(v.normal);

                // 2. Distancia da wave front a este vertice
                float  dist0       = length(worldPos0 - _ScannerOrigin.xyz);
                float  waveDist    = abs(dist0 - _ScannerRadius);

                // 3. Mascara de pico: maximo na frente da onda
                float  dispMask    = smoothstep(_DisplaceWidth, 0.0, waveDist);
                dispMask          *= _ScannerActive;

                // 4. Deslocar ao longo da normal world-space
                float3 displaceWS  = worldNorm0 * dispMask * _DisplaceStrength;

                // 5. Converter deslocamento world->object para aplicar ao vertex
                float3 displaceOS  = mul((float3x3)unity_WorldToObject, displaceWS);
                v.vertex.xyz      += displaceOS;

                // ── Output ────────────────────────────────────────────
                v2f o;
                o.pos       = UnityObjectToClipPos(v.vertex);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = worldNorm0;
                o.screenPos = ComputeScreenPos(o.pos);
                TRANSFER_SHADOW(o);
                return o;
            }

            // ─────────────────────────────────────────────────────────
            fixed4 frag(v2f i) : SV_Target
            {
                float3 N = normalize(i.worldNorm);

                // ── 1. Base lighting (Lambert + sombras) ───────────────
                float4 baseTex = tex2D(_MainTex, i.uv);
                float3 baseCol = baseTex.rgb * _BaseColor.rgb;
                float  NdotL   = saturate(dot(N, _WorldSpaceLightPos0.xyz));
                float  shadow  = SHADOW_ATTENUATION(i);
                float3 lit     = baseCol * (NdotL * shadow * 0.8 + 0.35);

                // ── 2. Depth Texture — Soft Intersection ───────────────
                // Le a profundidade da cena para suavizar onde a onda
                // intersecta outras superficies (efeito soft-particle).
                // Requer camera.depthTextureMode = DepthTextureMode.Depth
                float2 screenUV   = i.screenPos.xy / i.screenPos.w;
                float  sceneDepth = LinearEyeDepth(
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV)
                );
                float  fragDepth  = i.screenPos.w;
                // Fade suave onde a onda corta outras superficies
                float  softEdge   = saturate((sceneDepth - fragDepth) / 0.5);

                // ── 3. Distancia ao scanner ────────────────────────────
                float3 delta      = i.worldPos - _ScannerOrigin.xyz;
                float  dist       = length(delta);
                float  maxR       = max(_ScannerMaxRadius, 0.001);
                float  normDist   = dist / maxR;
                float  inside     = step(dist, _ScannerRadius);
                float  radiusFade = saturate((1.0 - normDist) * 3.0);

                // ── 4. Frente da onda (anel brilhante) ─────────────────
                float  distToFront = abs(dist - _ScannerRadius);
                float  waveMask    = smoothstep(_WaveWidth, 0.0, distToFront)
                                   * radiusFade
                                   * softEdge;   // suaviza nas intersecoes
                float3 waveGlow    = _WaveColor.rgb * waveMask * _WaveIntensity;

                // ── 5. Trail atras da onda ─────────────────────────────
                float  trailDist = _ScannerRadius - dist;
                float  trailFade = saturate(trailDist / _WaveGlowRange);
                trailFade = pow(trailFade, 1.8) * inside * radiusFade;

                // ── 6. Grid triplanar (dentro da area varrida) ─────────
                float  grid    = TriplanarGrid(i.worldPos, N, _GridScale, _GridLineWidth);
                float3 gridCol = _GridColor.rgb * grid * _GridIntensity * trailFade;

                // ── 7. Linhas de contorno por altitude ─────────────────
                float  contour    = ContourLine(i.worldPos.y, _ContourSpacing, _ContourWidth);
                float3 contourCol = _ContourColor.rgb * contour * _ContourIntensity * trailFade;

                // ── 8. Reveal de itens ─────────────────────────────────
                float  revealPulse = 0.5 + 0.5 * sin(_Time.y * 5.0 + dist * 0.5);
                float3 revealCol   = _RevealColor.rgb * _RevealIntensity
                                   * _IsRevealable * trailFade
                                   * _ScannerRevealItems * revealPulse;

                // Rim glow adicional no reveal
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float  rim     = pow(1.0 - saturate(dot(N, viewDir)), 3.0);
                revealCol     += _RevealColor.rgb * rim * _IsRevealable
                               * _ScannerRevealItems * trailFade * 2.0;

                // ── 9. Opacity Masking (Reveal) ────────────────────────
                //
                //   _IsRevealable = 0 (terreno):
                //     → Alpha sempre 1 (opaco). Scanner so adiciona visuais.
                //
                //   _IsRevealable = 1 (item escondido):
                //     → Scanner inativo:  Alpha = 0  (completamente invisivel)
                //     → Onda passa:       Alpha sobe com trailFade
                //     → _ScannerRevealItems = 0: permanece invisivel
                //
                float baseAlpha   = 1.0 - _IsRevealable;   // terreno=1, reveal=0
                float revealAlpha = saturate(trailFade * 4.0) * _ScannerRevealItems;
                float activeAlpha = lerp(1.0, revealAlpha, _IsRevealable);
                float finalAlpha  = lerp(baseAlpha, activeAlpha, _ScannerActive);

                // ── 10. Composicao final ────────────────────────────────
                float3 finalCol = lit
                                + (waveGlow + gridCol + contourCol + revealCol)
                                * _ScannerActive;

                return fixed4(finalCol, finalAlpha);
            }
            ENDCG
        }

        // ── Shadow Caster ─────────────────────────────────────────────
        // ATENCAO: parametro DEVE chamar-se "v" e campos "vertex"/"normal"
        // pois os macros Unity referenciam v.vertex e v.normal internamente.
        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            CGPROGRAM
            #pragma vertex   vert_shadow
            #pragma fragment frag_shadow
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct ShadowInput
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float2 texcoord : TEXCOORD0;
            };

            struct ShadowV2F { V2F_SHADOW_CASTER; };

            ShadowV2F vert_shadow(ShadowInput v)
            {
                ShadowV2F o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag_shadow(ShadowV2F i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
