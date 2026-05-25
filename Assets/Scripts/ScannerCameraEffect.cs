using UnityEngine;

/// <summary>
/// Efeito de camara para o Scanner de Terreno via Depth Texture.
///
/// SETUP:
///   1. Adiciona este componente a Main Camera.
///   2. Em Assets/Materials, cria um novo Material e atribui o shader
///      "Hidden/ScannerScreenPass". Chama-o "ScannerScreenPassMat".
///   3. Arrasta esse material para o campo "Scan Material" no Inspector.
///   4. O TerrainScannerController ja define os globais de shader.
///      Este componente so adiciona a camada full-screen de pos-processamento.
///
/// RESULTADO:
///   A grelha e a onda ficam visiveis em TODA a cena via depth texture,
///   mesmo em objetos que nao tenham o material TAP/TerrainScannerShader.
/// </summary>
[RequireComponent(typeof(Camera))]
public class ScannerCameraEffect : MonoBehaviour
{
    [Header("Material (shader: Hidden/ScannerScreenPass)")]
    public Material scanMaterial;

    [Header("Wave")]
    public Color  waveColor     = new Color(0f, 1f, 0.75f, 1f);
    [Range(0.05f, 8f)]
    public float  waveWidth     = 1.2f;
    [Range(0.5f, 10f)]
    public float  waveIntensity = 4.0f;
    [Range(0.5f, 40f)]
    public float  waveGlowRange = 12.0f;

    [Header("Grid")]
    public Color  gridColor     = new Color(0f, 0.6f, 1f, 1f);
    [Range(0.05f, 4f)]
    public float  gridScale     = 0.4f;
    [Range(0.005f, 0.15f)]
    public float  gridLineWidth = 0.03f;
    [Range(0f, 4f)]
    public float  gridIntensity = 1.8f;

    [Header("Contour Lines")]
    public Color  contourColor     = new Color(0.2f, 0.9f, 1f, 1f);
    [Range(0.1f, 10f)]
    public float  contourSpacing   = 1.5f;
    [Range(0.005f, 0.1f)]
    public float  contourWidth     = 0.02f;
    [Range(0f, 4f)]
    public float  contourIntensity = 1.2f;

    // IDs de shader (cache para performance)
    static readonly int ID_InvVP           = Shader.PropertyToID("_InvVP");
    static readonly int ID_WaveColor       = Shader.PropertyToID("_WaveColor");
    static readonly int ID_WaveWidth       = Shader.PropertyToID("_WaveWidth");
    static readonly int ID_WaveIntensity   = Shader.PropertyToID("_WaveIntensity");
    static readonly int ID_WaveGlowRange   = Shader.PropertyToID("_WaveGlowRange");
    static readonly int ID_GridColor       = Shader.PropertyToID("_GridColor");
    static readonly int ID_GridScale       = Shader.PropertyToID("_GridScale");
    static readonly int ID_GridLineWidth   = Shader.PropertyToID("_GridLineWidth");
    static readonly int ID_GridIntensity   = Shader.PropertyToID("_GridIntensity");
    static readonly int ID_ContourColor    = Shader.PropertyToID("_ContourColor");
    static readonly int ID_ContourSpacing  = Shader.PropertyToID("_ContourSpacing");
    static readonly int ID_ContourWidth    = Shader.PropertyToID("_ContourWidth");
    static readonly int ID_ContourIntensity= Shader.PropertyToID("_ContourIntensity");

    private Camera _cam;

    void Awake()
    {
        _cam = GetComponent<Camera>();
        // Pede ao Unity para gerar a Depth Texture desta camara
        _cam.depthTextureMode |= DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (scanMaterial == null)
        {
            Graphics.Blit(src, dst);
            return;
        }

        // Calcula a Inverse View-Projection para o frame atual
        // GL.GetGPUProjectionMatrix converte a matrix de projeccao para a
        // convencao da plataforma atual (DX vs OpenGL)
        Matrix4x4 proj = GL.GetGPUProjectionMatrix(_cam.projectionMatrix, false);
        Matrix4x4 vp   = proj * _cam.worldToCameraMatrix;
        scanMaterial.SetMatrix(ID_InvVP, vp.inverse);

        // Propriedades da onda / grid / contorno
        scanMaterial.SetColor(ID_WaveColor,        waveColor);
        scanMaterial.SetFloat(ID_WaveWidth,        waveWidth);
        scanMaterial.SetFloat(ID_WaveIntensity,    waveIntensity);
        scanMaterial.SetFloat(ID_WaveGlowRange,    waveGlowRange);
        scanMaterial.SetColor(ID_GridColor,        gridColor);
        scanMaterial.SetFloat(ID_GridScale,        gridScale);
        scanMaterial.SetFloat(ID_GridLineWidth,    gridLineWidth);
        scanMaterial.SetFloat(ID_GridIntensity,    gridIntensity);
        scanMaterial.SetColor(ID_ContourColor,     contourColor);
        scanMaterial.SetFloat(ID_ContourSpacing,   contourSpacing);
        scanMaterial.SetFloat(ID_ContourWidth,     contourWidth);
        scanMaterial.SetFloat(ID_ContourIntensity, contourIntensity);

        // Aplica o efeito por cima do frame renderizado
        Graphics.Blit(src, dst, scanMaterial);
    }

    void OnDisable()
    {
        // Remove o modo depth quando o componente e desativado
        if (_cam != null)
            _cam.depthTextureMode &= ~DepthTextureMode.Depth;
    }
}
