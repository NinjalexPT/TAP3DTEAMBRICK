Shader "TerrainScannerShader"
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

        [Header(X Ray Through Walls)]
        [HDR]
        _XRayColor         ("X-Ray Color",            Color)           = (1.0, 0.3, 0.0, 1.0)
        _XRayIntensity     ("X-Ray Intensity",        Range(0.0, 6.0)) = 2.5
        _XRayAlpha         ("X-Ray Opacity",          Range(0.0, 1.0)) = 0.6
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        // ══════════════════════════════════════════════════════════
        // PASS 1 — PRINCIPAL (renderização normal, ZTest padrão)
        // ══════════════════════════════════════════════════════════
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            ZTest  LEqual
            ZWrite On
            Blend  Off

            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            // ── Globais (set via Shader.SetGlobal* no controller) ──
            float4 _ScanCenter;
            float  _ScanRadius;
            float  _ScanMaxRadius;
            float  _ScanActive;
            float  _ScanRevealItems;

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

            sampler2D_float _CameraDepthTexture;

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

            float4 TriplanarTex(sampler2D tex, float3 worldPos,
                                float3 worldNorm, float scale)
            {
                float3 blend = abs(worldNorm);
                blend = pow(blend, 6.0);
                blend /= (blend.x + blend.y + blend.z + 1e-4);
                float4 cx = tex2D(tex, worldPos.yz * scale);
                float4 cy = tex2D(tex, worldPos.xz * scale);
                float4 cz = tex2D(tex, worldPos.xy * scale);
                return cx * blend.x + cy * blend.y + cz * blend.z;
            }

            v2f vert(appdata v)
            {
                float3 worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNorm = UnityObjectToWorldNormal(v.normal);
                float  dist      = length(worldPos - _ScanCenter.xyz);
                float  distToWave = abs(dist - _ScanRadius);
                float  waveMask  = smoothstep(_ScanWidth, 0.0, distToWave) * _ScanActive;
                float  dsp       = sin(_Time.y * _DisplaceSpeed) * waveMask;
                v.vertex.xyz    += v.normal * dsp * _DisplaceAmount;

                v2f o;
                o.pos       = UnityObjectToClipPos(v.vertex);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = worldNorm;
                o.screenPos = ComputeScreenPos(o.pos);
                o.eyeDepth  = -mul(UNITY_MATRIX_MV, v.vertex).z;
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 N = normalize(i.worldNorm);

                // Base lighting
                float4 baseTex = tex2D(_MainTex, i.uv);
                float3 baseCol = baseTex.rgb * _BaseColor.rgb;
                float  NdotL   = saturate(dot(N, _WorldSpaceLightPos0.xyz));
                float  shadow  = SHADOW_ATTENUATION(i);
                float3 lit     = baseCol * (NdotL * shadow * 0.8 + 0.35);

                // Distância ao scanner
                float  dist       = length(i.worldPos - _ScanCenter.xyz);
                float  maxR       = max(_ScanMaxRadius, 0.001);
                float  normDist   = dist / maxR;
                float  inside     = step(dist, _ScanRadius);
                float  radiusFade = saturate((1.0 - normDist) * 3.0);

                float  trailDist  = _ScanRadius - dist;
                float  trailFade  = pow(saturate(trailDist / _ScanGlowRange), 1.8)
                                  * inside * radiusFade;

                // Anel da onda
                float  wave    = smoothstep(_ScanRadius - _ScanWidth, _ScanRadius, dist)
                               * smoothstep(_ScanRadius + _ScanWidth, _ScanRadius, dist);
                float3 waveCol = _ScanColor.rgb * wave * _ScanIntensity * radiusFade;

                // Triplanar grid
                float4 gridSample = TriplanarTex(_GridTex, i.worldPos, N, _GridScale);
                float3 gridCol    = gridSample.rgb * _GridColor.rgb * _GridIntensity * trailFade;

                // Intersection glow (depth texture)
                float sceneDepth    = LinearEyeDepth(
                    SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture,
                                             UNITY_PROJ_COORD(i.screenPos)));
                float depthDiff     = abs(sceneDepth - i.eyeDepth);
                float intersectMask = smoothstep(_IntersectWidth, 0.0, depthDiff) * trailFade;
                float3 intersectCol = _IntersectColor.rgb * intersectMask * _IntersectIntensity;

                // Item reveal (rim + pulse)
                float  revealPulse = 0.5 + 0.5 * sin(_Time.y * 5.0 + dist * 0.5);
                float3 viewDir     = normalize(_WorldSpaceCameraPos - i.worldPos);
                float  rim         = pow(1.0 - saturate(dot(N, viewDir)), 3.0);
                float3 revealCol   = (_RevealColor.rgb * _RevealIntensity * revealPulse
                                   +  _RevealColor.rgb * rim * 2.0)
                                   * _IsRevealable * trailFade * _ScanRevealItems;

                float3 finalCol = lit + (waveCol + gridCol + intersectCol + revealCol)
                                * _ScanActive;
                return fixed4(finalCol, 1.0);
            }
            ENDCG
        }

        // ══════════════════════════════════════════════════════════
        // PASS 2 — X-RAY: ver objetos revelados ATRAVÉS das paredes
        //
        // ZTest Greater: só renderiza os pixels onde o depth test
        // FALHA, ou seja, onde o objeto está atrás de outra geometria.
        // O resultado é uma silhueta/rim visível através das paredes,
        // mas apenas quando o scanner a revelou.
        // ══════════════════════════════════════════════════════════
        Pass
        {
            ZTest  Greater       // rende onde o objeto está tapado
            ZWrite Off         // não escreve no depth buffer
            Blend  SrcAlpha OneMinusSrcAlpha
            Cull   Back

            CGPROGRAM
            #pragma vertex   vert_xray
            #pragma fragment frag_xray
            #include "UnityCG.cginc"

            // Globais do scanner
            float4 _ScanCenter;
            float  _ScanRadius;
            float  _ScanMaxRadius;
            float  _ScanActive;
            float  _ScanRevealItems;
            float  _ScanGlowRange;

            // Props X-ray
            float4 _XRayColor;
            float  _XRayIntensity;
            float  _XRayAlpha;
            float  _IsRevealable;

            struct appdata_xray
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f_xray
            {
                float4 pos       : SV_POSITION;
                float3 worldPos  : TEXCOORD0;
                float3 worldNorm : TEXCOORD1;
            };

            v2f_xray vert_xray(appdata_xray v)
            {
                v2f_xray o;
                o.pos       = UnityObjectToClipPos(v.vertex);
                o.worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag_xray(v2f_xray i) : SV_Target
            {
                float3 N       = normalize(i.worldNorm);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Rim: bordas brilham mais — efeito X-ray/holográfico clássico
                float rim = pow(1.0 - saturate(dot(N, viewDir)), 2.0);

                // Distância ao scanner
                float dist       = length(i.worldPos - _ScanCenter.xyz);
                float maxR       = max(_ScanMaxRadius, 0.001);
                float inside     = step(dist, _ScanRadius);
                float radiusFade = saturate((1.0 - dist / maxR) * 3.0);

                float trailDist  = _ScanRadius - dist;
                float trailFade  = pow(saturate(trailDist / _ScanGlowRange), 1.8)
                                 * inside * radiusFade;

                // Pulso animado para efeito vivo
                float pulse = 0.5 + 0.5 * sin(_Time.y * 4.0 + dist * 0.3);

                // Cor: rim forte nas bordas + fill translúcido no centro
                float3 col = _XRayColor.rgb * _XRayIntensity * (rim * 2.0 + 0.25 * pulse);

                // Alpha:
                //  - 0 se não é revelável, scanner inativo, ou onda ainda não chegou
                //  - Rim dá mais alpha nas bordas (silhueta mais definida)
                float alpha = (rim * 0.85 + 0.15 * pulse)
                            * _XRayAlpha
                            * trailFade
                            * _IsRevealable
                            * _ScanRevealItems
                            * _ScanActive;

                return fixed4(col, saturate(alpha));
            }
            ENDCG
        }

        // ══════════════════════════════════════════════════════════
        // PASS 3 — SHADOW CASTER (com vertex displacement)
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
                float3 worldPos   = mul(unity_ObjectToWorld, v.vertex).xyz;
                float  dist       = length(worldPos - _ScanCenter.xyz);
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
