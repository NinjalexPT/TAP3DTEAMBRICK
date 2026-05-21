Shader "TAP/ReinforcedGlassShader"
{
    Properties
    {
        [Header(Hex Cells)]
        _CellColor           ("Cell Color (Dark)",   Color)            = (0.04, 0.04, 0.06, 1.0)
        _CellEdgeSoftness    ("Cell Edge Softness",  Range(0.001, 0.05)) = 0.008
        _HexScale            ("Hex Scale",           Range(2, 100))    = 18.0

        [Header(Border Glow)]
        [HDR]
        _GlowColor           ("Glow Color",          Color)            = (0.0, 0.85, 1.0, 1.0)
        _GlowWidth           ("Glow Width",          Range(0.01, 0.35)) = 0.12
        _GlowFalloff         ("Glow Falloff",        Range(0.5, 6.0))  = 2.5
        _GlowIntensity       ("Glow Intensity",      Range(0.0, 5.0))  = 2.0

        [Header(Pulse)]
        [HDR]
        _PulseColor          ("Pulse Color",         Color)            = (0.4, 1.0, 1.0, 1.0)
        _PulseSpeed          ("Pulse Speed",         Range(0.0, 20.0)) = 5.0
        _PulseFrequency      ("Pulse Frequency",     Range(0.1, 8.0))  = 1.5
        _PulseSharpness      ("Pulse Sharpness",     Range(1.0, 16.0)) = 6.0
        _PulseDirection      ("Pulse Dir (XY)",      Vector)           = (0.7, 0.4, 0.0, 0.0)

        [Header(Vignette and Depth)]
        _CellDepth           ("Cell Depth (inner shadow)", Range(0.0, 1.0)) = 0.45
        _CellDepthRadius     ("Depth Radius",        Range(0.1, 1.0))  = 0.55
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _CellColor;
            float  _CellEdgeSoftness;
            float  _HexScale;

            float4 _GlowColor;
            float  _GlowWidth;
            float  _GlowFalloff;
            float  _GlowIntensity;

            float4 _PulseColor;
            float  _PulseSpeed;
            float  _PulseFrequency;
            float  _PulseSharpness;
            float4 _PulseDirection;

            float  _CellDepth;
            float  _CellDepthRadius;

            struct appdata {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv  : TEXCOORD0;
            };

            // ── Hex grid ──────────────────────────────────────────────────
            // Returns local offset from nearest hex centre (pointy-top)
            float2 HexLocal(float2 p)
            {
                // pointy-top hex basis
                float2 basis  = float2(sqrt(3.0), 1.0);
                float2 hbasis = basis * 0.5;
                float2 a = fmod(p,           basis) - hbasis;
                float2 b = fmod(p - hbasis,  basis) - hbasis;
                return dot(a, a) < dot(b, b) ? a : b;
            }

            // Normalised dist from centre (0) to edge (1), for pointy-top hex
            float HexNormDist(float2 lp)
            {
                float2 q = abs(lp);
                // max of 3 half-plane tests
                float d = max(q.x, q.x * 0.5 + q.y * 0.86602540);
                return d / 0.57735027;  // normalise so edge = 1.0
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv  = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 uv    = i.uv * _HexScale;
                float2 local = HexLocal(uv);
                float  nd    = HexNormDist(local);  // 0=centre, 1=edge, >1=border gap

                // ── 1. Hard cell mask ─────────────────────────────────────
                // 1 inside hex cell, 0 in the border gap
                float cellMask = smoothstep(1.0, 1.0 - _CellEdgeSoftness, nd);

                // ── 2. Glow from border into cell ─────────────────────────
                // Distance from the edge (positive inside cell, negative outside)
                float distFromEdge = 1.0 - nd;  // 0 at edge, grows inward
                float glow = saturate(distFromEdge / _GlowWidth);
                glow = 1.0 - pow(glow, _GlowFalloff);   // bright at edge, falls inward
                glow *= cellMask;                        // only inside cells

                // ── 3. Animated pulse ─────────────────────────────────────
                float2 dir   = normalize(_PulseDirection.xy + float2(0.001, 0.0));
                float  t     = dot(i.uv, dir);
                float  phase = frac(t * _PulseFrequency - _Time.y * _PulseSpeed * 0.05);
                float  pulse = pow(max(0.0, sin(phase * 3.14159265)), _PulseSharpness);

                // Pulse multiplies the glow (rides along the border light)
                float3 borderGlow  = _GlowColor.rgb  * _GlowIntensity * glow;
                float3 pulseLight  = _PulseColor.rgb * pulse * glow * 2.5;

                // ── 4. Cell inner depth/vignette ──────────────────────────
                float vignette = smoothstep(0.0, _CellDepthRadius, 1.0 - nd);
                float3 cellCol = _CellColor.rgb * (1.0 - vignette * _CellDepth);

                // ── 5. Compose ────────────────────────────────────────────
                float3 finalCol = cellCol + borderGlow + pulseLight;

                // Alpha: fully opaque in cell, slightly visible in border gap
                float alpha = lerp(0.6, 1.0, cellMask);

                return float4(finalCol, alpha);
            }
            ENDCG
        }
    }
    FallBack "Transparent/Diffuse"
}
