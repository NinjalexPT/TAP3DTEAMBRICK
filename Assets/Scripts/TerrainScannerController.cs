using System.Collections;
using UnityEngine;

/// <summary>
/// Controla a onda do scanner de terreno.
/// Chama TriggerScan(position) para disparar a onda a partir de qualquer ponto.
/// </summary>
public class TerrainScannerController : MonoBehaviour
{
    [Header("Wave")]
    [Tooltip("Velocidade de expansão em metros/segundo")]
    public float waveSpeed   = 25f;
    [Tooltip("Raio máximo antes de a onda desaparecer")]
    public float maxRadius   = 100f;
    [Tooltip("Tempo de fade-out após atingir o raio máximo")]
    public float fadeOutTime = 2.0f;

    [Header("Reveal")]
    public bool revealItems = true;

    [Header("Debug")]
    [Tooltip("Pressiona Tab em Play Mode para disparar um scan de teste")]
    public bool debugScanOnTab = true;

    // ── Shader global property IDs ──────────────────────────────────
    static readonly int ID_Center      = Shader.PropertyToID("_ScanCenter");
    static readonly int ID_Radius      = Shader.PropertyToID("_ScanRadius");
    static readonly int ID_MaxRadius   = Shader.PropertyToID("_ScanMaxRadius");
    static readonly int ID_Active      = Shader.PropertyToID("_ScanActive");
    static readonly int ID_RevealItems = Shader.PropertyToID("_ScanRevealItems");

    private Coroutine _wave;

    void Start()  => ResetGlobals();

    void Update()
    {
        if (debugScanOnTab && Input.GetKeyDown(KeyCode.Tab))
            TriggerScan(transform.position);
    }

    // ── API pública ─────────────────────────────────────────────────

    /// <summary>Dispara a onda a partir de uma posição no mundo.</summary>
    public void TriggerScan(Vector3 origin, bool reveal = true)
    {
        if (_wave != null) StopCoroutine(_wave);
        _wave = StartCoroutine(WaveRoutine(origin, reveal));
    }

    [ContextMenu("Trigger Scan Here")]
    public void TriggerScanHere() => TriggerScan(transform.position, revealItems);

    public void StopScan()
    {
        if (_wave != null) { StopCoroutine(_wave); _wave = null; }
        ResetGlobals();
    }

    // ── Coroutine ────────────────────────────────────────────────────
    IEnumerator WaveRoutine(Vector3 origin, bool reveal)
    {
        Shader.SetGlobalVector(ID_Center,      new Vector4(origin.x, origin.y, origin.z, 1f));
        Shader.SetGlobalFloat (ID_MaxRadius,   maxRadius);
        Shader.SetGlobalFloat (ID_Active,      1f);
        Shader.SetGlobalFloat (ID_RevealItems, reveal ? 1f : 0f);

        // Fase de expansão
        float radius = 0f;
        while (radius < maxRadius)
        {
            radius += waveSpeed * Time.deltaTime;
            Shader.SetGlobalFloat(ID_Radius, radius);
            yield return null;
        }
        Shader.SetGlobalFloat(ID_Radius, maxRadius);

        // Fase de fade-out
        float elapsed = 0f;
        while (elapsed < fadeOutTime)
        {
            elapsed += Time.deltaTime;
            Shader.SetGlobalFloat(ID_MaxRadius,
                Mathf.Lerp(maxRadius, 0f, elapsed / fadeOutTime));
            yield return null;
        }

        ResetGlobals();
        _wave = null;
    }

    void ResetGlobals()
    {
        Shader.SetGlobalFloat (ID_Active,      0f);
        Shader.SetGlobalFloat (ID_Radius,      0f);
        Shader.SetGlobalFloat (ID_MaxRadius,   maxRadius);
        Shader.SetGlobalFloat (ID_RevealItems, 0f);
    }
}
