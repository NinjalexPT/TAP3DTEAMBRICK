using System.Collections;
using UnityEngine;

/// <summary>
/// Controla a onda de scanner de terreno (estilo Death Stranding).
///
/// SETUP:
///   1. Adiciona este componente a qualquer GameObject (ex: o Player).
///   2. Os materiais do cenário devem usar o shader TAP/TerrainScannerShader.
///   3. Chama TriggerScan(position) via script para disparar a onda.
///      Ex: scanner.TriggerScan(grenade.transform.position);
///
/// REVEAL DE ITENS:
///   Nos objetos escondidos, no material define "_IsRevealable = 1".
///   Quando a onda passa, ficam iluminados com _RevealColor durante o trail.
/// </summary>
public class TerrainScannerController : MonoBehaviour
{
    // ── Configuração pública ────────────────────────────────────────
    [Header("Wave")]
    [Tooltip("Velocidade de expansão da onda (metros/segundo)")]
    public float waveSpeed    = 25f;

    [Tooltip("Raio máximo antes de a onda desaparecer")]
    public float maxRadius    = 100f;

    [Tooltip("Tempo de fade-out depois de a onda atingir o raio máximo")]
    public float fadeOutTime  = 2.0f;

    [Header("Reveal")]
    [Tooltip("Se true, objetos com _IsRevealable=1 ficam visíveis durante a passagem")]
    public bool  revealItems  = true;

    [Header("Debug")]
    [Tooltip("Dispara um scan da posição do jogador ao pressionar Tab")]
    public bool  debugScanOnTab = true;

    // ── Shader property IDs (cache para performance) ────────────────
    static readonly int ID_Origin      = Shader.PropertyToID("_ScannerOrigin");
    static readonly int ID_Radius      = Shader.PropertyToID("_ScannerRadius");
    static readonly int ID_MaxRadius   = Shader.PropertyToID("_ScannerMaxRadius");
    static readonly int ID_Active      = Shader.PropertyToID("_ScannerActive");
    static readonly int ID_RevealItems = Shader.PropertyToID("_ScannerRevealItems");

    private Coroutine _waveRoutine;

    // ── Unity Lifecycle ─────────────────────────────────────────────
    void Start()
    {
        ResetGlobals();
    }

    void Update()
    {
        if (debugScanOnTab && Input.GetKeyDown(KeyCode.Tab))
            TriggerScan(transform.position);
    }

    // ── API Pública ─────────────────────────────────────────────────

    /// <summary>
    /// Dispara a onda a partir de uma posição arbitrária.
    /// Ideal para granadas, explosões, pickups, etc.
    /// </summary>
    /// <param name="origin">Posição no mundo onde a onda nasce.</param>
    /// <param name="reveal">Se true, revela itens escondidos.</param>
    public void TriggerScan(Vector3 origin, bool reveal = true)
    {
        if (_waveRoutine != null)
            StopCoroutine(_waveRoutine);

        _waveRoutine = StartCoroutine(WaveRoutine(origin, reveal));
    }

    /// <summary>Dispara da posição deste GameObject (útil para testes).</summary>
    [ContextMenu("Trigger Scan Here")]
    public void TriggerScanHere() => TriggerScan(transform.position, revealItems);

    /// <summary>Para a onda imediatamente.</summary>
    public void StopScan()
    {
        if (_waveRoutine != null)
        {
            StopCoroutine(_waveRoutine);
            _waveRoutine = null;
        }
        ResetGlobals();
    }

    // ── Coroutine interna ───────────────────────────────────────────
    IEnumerator WaveRoutine(Vector3 origin, bool reveal)
    {
        // Inicializa globais
        Shader.SetGlobalVector(ID_Origin,      new Vector4(origin.x, origin.y, origin.z, 1f));
        Shader.SetGlobalFloat (ID_MaxRadius,   maxRadius);
        Shader.SetGlobalFloat (ID_Active,      1f);
        Shader.SetGlobalFloat (ID_RevealItems, reveal ? 1f : 0f);

        float radius = 0f;

        // ── Fase de expansão ────────────────────────────────────────
        while (radius < maxRadius)
        {
            radius += waveSpeed * Time.deltaTime;
            Shader.SetGlobalFloat(ID_Radius, radius);
            yield return null;
        }
        Shader.SetGlobalFloat(ID_Radius, maxRadius);

        // ── Fase de fade-out ────────────────────────────────────────
        // Encolhemos o maxRadius para que o trail desapareça gradualmente
        float elapsed = 0f;
        while (elapsed < fadeOutTime)
        {
            elapsed += Time.deltaTime;
            float t         = elapsed / fadeOutTime;
            float currentMax = Mathf.Lerp(maxRadius, 0f, t);
            Shader.SetGlobalFloat(ID_MaxRadius, currentMax);
            yield return null;
        }

        // ── Reset ────────────────────────────────────────────────────
        ResetGlobals();
        _waveRoutine = null;
    }

    void ResetGlobals()
    {
        Shader.SetGlobalFloat (ID_Active,      0f);
        Shader.SetGlobalFloat (ID_Radius,      0f);
        Shader.SetGlobalFloat (ID_MaxRadius,   maxRadius);
        Shader.SetGlobalFloat (ID_RevealItems, 0f);
    }
}
