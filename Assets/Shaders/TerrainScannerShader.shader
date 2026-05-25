Shader "TerrainScannerShader"
{
    // ═══════════════════════════════════════════════════════════════
    //  TerrainScannerShader — shader único com 2 passes
    //  Pass 0 (ForwardBase): displacement, reveal, base lit
    //  Pass 1 (ScannerScreen): Blit full-screen via ScannerCameraEffect
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
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 300
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite [_ZWrite]

        CGINCLUDE
        #include "UnityCG.cginc"

        sampler2D _CameraDepthTexture;

        float4 _ScannerOrigin;
        float  _ScannerRadius;
        float  _ScannerMaxRadius;
        float  _ScannerActive;
        float  _ScannerRevealItems;

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

        float _DisplaceStrength;
        float _DisplaceWidth;

        float4x4 _InvVP;

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

        void ComputeScannerOverlay(
            float3 worldPos,
            float3 worldNorm,
            float softEdge,
            out float3 waveGlow,
            out float3 gridCol,
            out float3 contourCol,
            out float trailFade)
        {
            float dist       = length(worldPos - _ScannerOrigin.xyz);
            float maxR       = max(_ScannerMaxRadius, 0.001);
            float normDist   = dist / maxR;
            float inside     = step(dist, _ScannerRadius);
            float radiusFade = saturate((1.0 - normDist) * 3.0);

            float distToFront = abs(dist - _ScannerRadius);
            float waveMask    = smoothstep(_WaveWidth, 0.0, distToFront)
                              * radiusFade
                              * softEdge;
            waveGlow = _WaveColor.rgb * waveMask * _WaveIntensity;

            float trailDist = _ScannerRadius - dist;
            trailFade = saturate(trailDist / _WaveGlowRange);
            trailFade = pow(trailFade, 1.8) * inside * radiusFade;

            float grid = TriplanarGrid(worldPos, worldNorm, _GridScale, _GridLineWidth);
            gridCol = _GridColor.rgb * grid * _GridIntensity * trailFade;

            float contour = ContourLine(worldPos.y, _ContourSpacing, _ContourWidth);
            contourCol = _ContourColor.rgb * contour * _ContourIntensity * trailFade;
        }

        float3 ComputeVertexDisplacementWS(float3 worldPos, float3 worldNorm)
        {
            float dist0    = length(worldPos - _ScannerOrigin.xyz);
            float waveDist = abs(dist0 - _ScannerRadius);
            float dispMask = smoothstep(_DisplaceWidth, 0.0, waveDist) * _ScannerActive;
            return worldNorm * dispMask * _DisplaceStrength;
        }
        ENDCG

        // ── Pass 0: Forward (meshes com material scanner) ───────────
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex;
            float4    _MainTex_ST;
            float4    _BaseColor;
            float     _Smoothness;

            float4 _RevealColor;
            float  _RevealIntensity;
            float  _IsRevealable;

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
                float4 screenPos : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert(appdata v)
            {
                float3 worldPos0  = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNorm0 = UnityObjectToWorldNormal(v.normal);

                float3 displaceWS = ComputeVertexDisplacementWS(worldPos0, worldNorm0);
                float3 displaceOS = mul((float3x3)unity_WorldToObject, displaceWS);
                v.vertex.xyz += displaceOS;

                v2f o;
                o.pos       = UnityObjectToClipPos(v.vertex);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos  = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = worldNorm0;
                o.screenPos = ComputeScreenPos(o.pos);
                TRANSFER_SHADOW(o);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 N = normalize(i.worldNorm);

                float4 baseTex = tex2D(_MainTex, i.uv);
                float3 baseCol = baseTex.rgb * _BaseColor.rgb;
                float  NdotL   = saturate(dot(N, _WorldSpaceLightPos0.xyz));
                float  shadow  = SHADOW_ATTENUATION(i);
                float3 lit     = baseCol * (NdotL * shadow * 0.8 + 0.35);

                float2 screenUV   = i.screenPos.xy / i.screenPos.w;
                float  sceneDepth = LinearEyeDepth(
                    SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV)
                );
                float  fragDepth  = i.screenPos.w;
                float  softEdge   = saturate((sceneDepth - fragDepth) / 0.5);

                float3 waveGlow, gridCol, contourCol;
                float  trailFade;
                ComputeScannerOverlay(i.worldPos, N, softEdge,
                    waveGlow, gridCol, contourCol, trailFade);

                float  revealPulse = 0.5 + 0.5 * sin(_Time.y * 5.0
                                    + length(i.worldPos - _ScannerOrigin.xyz) * 0.5);
                float3 revealCol   = _RevealColor.rgb * _RevealIntensity
                                   * _IsRevealable * trailFade
                                   * _ScannerRevealItems * revealPulse;

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float  rim     = pow(1.0 - saturate(dot(N, viewDir)), 3.0);
                revealCol     += _RevealColor.rgb * rim * _IsRevealable
                               * _ScannerRevealItems * trailFade * 2.0;

                float baseAlpha   = 1.0 - _IsRevealable;
                float revealAlpha = saturate(trailFade * 4.0) * _ScannerRevealItems;
                float activeAlpha = lerp(1.0, revealAlpha, _IsRevealable);
                float finalAlpha  = lerp(baseAlpha, activeAlpha, _ScannerActive);

                float3 finalCol = lit
                                + (waveGlow + gridCol + contourCol + revealCol)
                                * _ScannerActive;

                return fixed4(finalCol, finalAlpha);
            }
            ENDCG
        }

        // ── Pass 1: Screen Blit (ScannerCameraEffect, pass index 1) ───
        Pass
        {
            Name "ScannerScreen"
            ZWrite Off
            ZTest Always
            Cull Off
            Blend One Zero

            CGPROGRAM
            #pragma vertex   vert_screen
            #pragma fragment frag_screen

            sampler2D _MainTex;

            struct appdata_screen
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f_screen
            {
                float4 pos     : SV_POSITION;
                float2 uv      : TEXCOORD0;
                float2 uvDepth : TEXCOORD1;
            };

            v2f_screen vert_screen(appdata_screen v)
            {
                v2f_screen o;
                o.pos     = UnityObjectToClipPos(v.vertex);
                o.uv      = v.uv;
                o.uvDepth = v.uv;
                #if UNITY_UV_STARTS_AT_TOP
                    if (_ProjectionParams.x < 0) o.uvDepth.y = 1.0 - v.uv.y;
                #endif
                return o;
            }

            fixed4 frag_screen(v2f_screen i) : SV_Target
            {
                fixed4 screenCol = tex2D(_MainTex, i.uv);

                if (_ScannerActive < 0.5)
                    return screenCol;

                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uvDepth);
                float linDepth = LinearEyeDepth(rawDepth);
                if (linDepth > _ProjectionParams.z * 0.99)
                    return screenCol;

                float3 worldPos = ReconstructWorldPos(i.uvDepth, rawDepth);
                float3 N        = normalize(cross(ddy(worldPos), ddx(worldPos)));

                float3 waveGlow, gridCol, contourCol;
                float  trailFade;
                ComputeScannerOverlay(worldPos, N, 1.0,
                    waveGlow, gridCol, contourCol, trailFade);

                return fixed4(screenCol.rgb + waveGlow + gridCol + contourCol, 1.0);
            }
            ENDCG
        }

        // ── Pass 2: Shadow Caster (displacement alinhado à onda) ──────
        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            CGPROGRAM
            #pragma vertex   vert_shadow
            #pragma fragment frag_shadow
            #pragma multi_compile_shadowcaster

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
                float3 worldNorm = UnityObjectToWorldNormal(v.normal);
                float3 displaceWS = ComputeVertexDisplacementWS(worldPos, worldNorm);
                v.vertex.xyz += mul((float3x3)unity_WorldToObject, displaceWS);

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
