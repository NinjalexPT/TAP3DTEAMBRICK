using UnityEngine;
using System.Collections;

public class VidaEscudo : MonoBehaviour
{
    public float vida = 100f; // 4 tiros de 25 de dano destroem isto

    [Header("Efeito de Dano - Noise Scale")]
    public float pulseNoiseScaleBase = 4.0f;  // valor normal (igual ao shader)
    public float pulseNoiseScalePico = 14.0f; // valor máximo ao levar dano

    [Header("Efeito de Dano - Amplitude")]
    public float pulseAmplitudeBase = 0.08f; // valor normal (igual ao shader)
    public float pulseAmplitudePico = 0.4f;  // valor máximo ao levar dano

    [Header("Efeito de Dano - Geral")]
    public float duracaoEfeito = 0.5f;  // segundos até voltar ao normal

    private Renderer _renderer;
    private MaterialPropertyBlock _mpb;
    private Coroutine _coroutineEfeito;

    private static readonly int PulseNoiseScaleID =
        Shader.PropertyToID("_PulseNoiseScale");
    private static readonly int PulseAmplitudeID =
        Shader.PropertyToID("_PulseAmplitude");

    void Awake()
    {
        _renderer = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();

        // Garante que o shader arranca com os valores base
        AplicarEfeito(pulseNoiseScaleBase, pulseAmplitudeBase);
    }

    public void ReceberDano(float dano)
    {
        vida -= dano;

        // Reinicia o efeito se já estava a correr
        if (_coroutineEfeito != null)
            StopCoroutine(_coroutineEfeito);
        _coroutineEfeito = StartCoroutine(EfeitoDano());

        if (vida <= 0f)
        {
            Destroy(gameObject); // O Force Field desaparece!
        }
    }

    // Sobe rapidamente para o pico e depois interpola de volta ao normal
    private IEnumerator EfeitoDano()
    {
        // --- Subida quase instantânea (1 frame) ---
        AplicarEfeito(pulseNoiseScalePico, pulseAmplitudePico);
        yield return null;

        // --- Descida suave ao longo de duracaoEfeito ---
        float tempo = 0f;
        while (tempo < duracaoEfeito)
        {
            tempo += Time.deltaTime;
            float t = Mathf.Clamp01(tempo / duracaoEfeito);
            float tSmooth = t * t * (3f - 2f * t); // smoothstep

            float noiseScale = Mathf.Lerp(pulseNoiseScalePico, pulseNoiseScaleBase, tSmooth);
            float amplitude = Mathf.Lerp(pulseAmplitudePico, pulseAmplitudeBase, tSmooth);

            AplicarEfeito(noiseScale, amplitude);
            yield return null;
        }

        // Garante que termina exactamente nos valores base
        AplicarEfeito(pulseNoiseScaleBase, pulseAmplitudeBase);
        _coroutineEfeito = null;
    }

    private void AplicarEfeito(float noiseScale, float amplitude)
    {
        _renderer.GetPropertyBlock(_mpb);
        _mpb.SetFloat(PulseNoiseScaleID, noiseScale);
        _mpb.SetFloat(PulseAmplitudeID, amplitude);
        _renderer.SetPropertyBlock(_mpb);
    }
}
