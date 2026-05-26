Shader "Custom/ScannerMask"
{
    SubShader
    {
        // Tem de ser desenhado ANTES do Data Stream
        Tags { "RenderType"="Opaque" "Queue"="Geometry+1" }

        // ColorMask 0 impede que ele pinte o objeto, fica 100% invisível.
        // ZWrite Off impede que ele bloqueie objetos 3D que estejam por trás.
        ColorMask 0
        ZWrite Off

        // A MAGIA DO STENCIL
        Stencil
        {
            Ref 1           // A nossa "password" ou número de marcação
            Comp Always     // Escreve sempre que passar na câmara
            Pass Replace    // Substitui o valor do ecrã por '1'
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; };
            struct v2f { float4 vertex : SV_POSITION; };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(0,0,0,0); // A cor não importa por causa do ColorMask 0
            }
            ENDCG
        }
    }
}