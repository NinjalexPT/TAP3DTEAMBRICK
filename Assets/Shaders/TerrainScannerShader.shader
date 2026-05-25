Shader "TAP/TerrainScannerShader"
{
    // Aplica este shader aos materiais dos objetos do cenário.
    // O TerrainScannerController.cs actualiza os globais em runtime.
    Properties
    {
        [Header(Base Surface)]
        _MainTex           ("Base Texture",           2D)              = "white" {}
        _BaseColor         ("Base Color",             Color)           = (0.15, 0.16, 0.22, 1.0)

        [Header(Grid Texture Triplanar)]
        _GridTex           ("Grid Texture (Sci-Fi)",  2D)              = "white" {}
        _GridScale         ("Grid Scale",             Range(0.05, 5.0)) = 0.5
        [HDR]
        _GridColor         ("Grid Color",             Color)           = (0.0, 0.6, 1.0, 1.0)
        _GridIntensity     ("Grid Intensity",         Range(0.0, 4.0)) = 2.0

        [Header(Scanner Wave)]
        [HDR]
        _ScanColor         ("Scan Color (HDR)",       Color)           = (0.0, 1.0, 0.75, 1.0)
        _ScanWidth         ("Scan Ring Width",        Range(0.05, 8.0)) = 1.5
        _ScanGlowRange     ("Trail Glow Range",       Range(0.5, 40.0)) = 15.0
        _ScanIntensity     ("Scan Intensity",         Range(0.5, 10.0)) = 4.0

        [Header(Vertex Displacement)]
        _DisplaceAmount    ("Displace Amount",        Range(0.0, 0.5)) = 0.08
        _DisplaceSpeed     ("Displace Speed",         Range(1.0, 20.0)) = 8.0

        [Header(Intersection Glow)]
        [HDR]
        _IntersectColor    ("Intersect Color",        Color)           = (0.0, 0.85, 1.0, 1.0)
        _IntersectWidth    ("Intersect Width",        Range(0.01, 1.0)) = 0.15
        _IntersectIntensity("Intersect Intensity",   Range(0.0, 5.0)) = 2.5

        [Header(Item Reveal)]
        [HDR]
        _RevealColor       ("Reveal Color",           Color)           = (1.0, 0.55, 0.0, 1.0)
        _RevealIntensity   ("Reveal Intensity",       Range(0.0, 8.0)) = 3.5
        _IsRevealable      ("Is Revealable",          Range(0, 1))     = 0.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        // ══════════════════════════════════════════════════════════
        // PASS PRINCIPAL
        // ══════════════════════════════════════════════════════════
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

            // ── Globais (set via Shader.SetGlobal* no controller) ──
            float4 _ScanCenter;       // world-space XYZ da origem
            float  _ScanRadius;       // raio actual da onda
            float  _ScanMaxRadius;    // raio máximo (controla fade)
            float  _ScanActive;       // 0 = off | 1 = on
            float  _ScanRevealItems;  // 0 = não revela | 1 = revela

            // ── Material props ─────────────────────────────────────
            sampler2D _MainTex;
            float4    _MainTex_ST;
            float4    _BaseColor;

            sampler2D _GridTex;
            float     _GridScale;
            float4    _GridColor;
            float     _GridIntensity;

            float4 _ScanColor;
            float  _ScanWidth;
            float  _ScanGlowRange;
            float  _ScanIntensity;

            float  _DisplaceAmount;
            float  _DisplaceSpeed;

            float4 _IntersectColor;
            float  _IntersectWidth;
            float  _IntersectIntensity;

            float4 _RevealColor;
            float  _RevealIntensity;
            float  _IsRevealable;

            // Depth texture (câmara precisa de depth mode)
            sampler2D_float _CameraDepthTexture;

            // ── Structs ────────────────────────────────────────────
            struct appdata
            {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float2 uv      : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos       : SV_POSITION;
                float2 uv        : TEXCOORD0;
                float3 worldPos  : TEXCOORD1;
                float3 worldNorm : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                float  eyeDepth  : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            // ── Triplanar: amostra _GridTex nos 3 eixos ────────────
            float4 TriplanarTex(sampler2D tex,
                                float3 worldPos,
                                float3 worldNorm,
                                float  scale)
            {
                // Pesos baseados na normal — blending suave
                float3 blend = abs(worldNorm);
                blend = pow(blend, 6.0);
                blend /= (blend.x + blend.y + blend.z + 1e-4);

                // Passo 3 do documento: amostragem nos 3 planos
                float4 cx = tex2D(tex, worldPos.yz * scale); // plano YZ (lado)
                float4 cy = tex2D(tex, worldPos.xz * scale); // plano XZ (cima)
                float4 cz = tex2D(tex, worldPos.xy * scale); // plano XY (frente)

                return cx * blend.x + cy * blend.y + cz * blend.z;
            }

            // ── VERTEX SHADER ──────────────────────────────────────
            // Passo 2 do documento: deslocamento físico dos vértices
            v2f vert(appdata v)
            {
                // 1. Posição e normal no espaço do mundo
                float3 worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNorm = UnityObjectToWorldNormal(v.normal);

                // 2. Distância do vértice ao centro do scan
                float dist = length(worldPos - _ScanCenter.xyz);

                // 3. Máscara de impacto: pico quando dist ≈ _ScanRadius
                float distToWave = abs(dist - _ScanRadius);
                float waveMask   = smoothstep(_ScanWidth, 0.0, distToWave)
                                 * _ScanActive;

                // 4. Vertex displacement: "pulso" físico ao longo da normal
                float displaceWave = sin(_Time.y * _DisplaceSpeed) * waveMask;
                v.vertex.xyz += v.normal * displaceWave * _DisplaceAmount;

                // 5. Output para o fragment shader
                v2f o;
                o.pos      = UnityObjectToClipPos(v.vertex);
                o.uv       = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = worldNorm;
                o.screenPos = ComputeScreenPos(o.pos);
                // Eye-space depth para o intersection glow
                o.eyeDepth  = -mul(UNITY_MATRIX_MV, v.vertex).z;
                TRANSFER_SHADOW(o);
                return o;
            }

            // ── FRAGMENT SHADER ────────────────────────────────────
            fixed4 frag(v2f i) : SV_Target
            {
                float3 N = normalize(i.worldNorm);

                // ─ 1. Base surface com lighting Lambert simples ──────
                float4 baseTex = tex2D(_MainTex, i.uv);
                float3 baseCol = baseTex.rgb * _BaseColor.rgb;
                float  NdotL   = saturate(dot(N, _WorldSpaceLightPos0.xyz));
                float  shadow  = SHADOW_ATTENUATION(i);
                float3 lit     = baseCol * (NdotL * shadow * 0.8 + 0.35);

                // ─ 2. Distância ao scanner (por pixel) ───────────────
                float  dist      = length(i.worldPos - _ScanCenter.xyz);
                float  maxR      = max(_ScanMaxRadius, 0.001);
                float  normDist  = dist / maxR;
                float  inside    = step(dist, _ScanRadius);
                float  radiusFade = saturate((1.0 - normDist) * 3.0);

                // Trail que fica atrás da onda
                float  trailDist = _ScanRadius - dist;
                float  trailFade = pow(saturate(trailDist / _ScanGlowRange), 1.8)
                                 * inside * radiusFade;

                // ─ 3. Anel da onda (Passo 5 do documento) ────────────
                // smoothstep duplo cria um anel centrado em _ScanRadius
                float wave = smoothstep(_ScanRadius - _ScanWidth, _ScanRadius, dist)
                           * smoothstep(_ScanRadius + _ScanWidth, _ScanRadius, dist);
                float3 waveCol = _ScanColor.rgb * wave * _ScanIntensity * radiusFade;

                // ─ 4. Triplanar grid (Passo 3 do documento) ──────────
                float4 gridSample = TriplanarTex(_GridTex, i.worldPos, N, _GridScale);
                float3 gridCol    = gridSample.rgb * _GridColor.rgb
                                  * _GridIntensity * trailFade;

                // ─ 5. Intersection glow (Passo 4 do documento) ───────
                // Lê a depth texture para encontrar onde os objetos se tocam
                float sceneDepth    = LinearEyeDepth(
                                        SAMPLE_DEPTH_TEXTURE_PROJ(
                                            _CameraDepthTexture,
                                            UNITY_PROJ_COORD(i.screenPos)));
                float depthDiff     = abs(sceneDepth - i.eyeDepth);
                float intersectMask = smoothstep(_IntersectWidth, 0.0, depthDiff)
                                    * trailFade;
                float3 intersectCol = _IntersectColor.rgb
                                    * intersectMask * _IntersectIntensity;

                // ─ 6. Item reveal ─────────────────────────────────────
                float  revealPulse = 0.5 + 0.5 * sin(_Time.y * 5.0 + dist * 0.5);
                float3 viewDir     = normalize(_WorldSpaceCameraPos - i.worldPos);
                float  rim         = pow(1.0 - saturate(dot(N, viewDir)), 3.0);
                float3 revealCol   = (_RevealColor.rgb * _RevealIntensity * revealPulse
                                   +  _RevealColor.rgb * rim * 2.0)
                                   * _IsRevealable * trailFade * _ScanRevealItems;

                // ─ 7. Composição final (Passo 5 do documento) ─────────
                // Dentro do trail: grelha + intersect | na frente: anel
                // Fora do scan: apenas lit base
                float3 scanEffect = waveCol + gridCol + intersectCol + revealCol;
                float3 finalCol   = lit + scanEffect * _ScanActive;

                return fixed4(finalCol, 1.0);
            }
            ENDCG
        }

        // ══════════════════════════════════════════════════════════
        // SHADOW CASTER — com vertex displacement para sombras exactas
        // ══════════════════════════════════════════════════════════
        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            CGPROGRAM
            #pragma vertex   vert_shadow
            #pragma fragment frag_shadow
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            float4 _ScanCenter;
            float  _ScanRadius;
            float  _ScanActive;
            float  _ScanWidth;
            float  _DisplaceAmount;
            float  _DisplaceSpeed;

            struct ShadowInput
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float2 texcoord : TEXCOORD0;
            };

            struct ShadowV2F { V2F_SHADOW_CASTER; };

            ShadowV2F vert_shadow(ShadowInput v)
            {
                float3 worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                float  dist      = length(worldPos - _ScanCenter.xyz);
                float  distToWave = abs(dist - _ScanRadius);
                float  waveMask   = smoothstep(_ScanWidth, 0.0, distToWave) * _ScanActive;
                float  dsp        = sin(_Time.y * _DisplaceSpeed) * waveMask;
                v.vertex.xyz     += v.normal * dsp * _DisplaceAmount;

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
