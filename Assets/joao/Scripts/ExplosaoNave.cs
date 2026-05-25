using UnityEngine;
using UnityEngine.UI;

public class ExplosaoNave : MonoBehaviour
{
    [Header("Sistema de Vida (HP)")]
    public float vidaMaxima = 100f;
    private float vidaAtual;
    public Slider barraDeVida;

    [Header("Teste Manual")]
    // Removido o limite [Range] para a explosão poder crescer infinitamente
    public float forcaExplosao = 0f; 
    [Range(0f, 1f)] public float encolherEstilhacos = 0f;

    [Header("Configuração da Automação")]
    public float velocidadeDaExplosao = 5f; // Aumentei um pouco para voarem mais rápido
    public float velocidadeDoEncolhimento = 0.5f; // Encolhem mais devagar para dar tempo de voarem

    private Renderer[] pedacos;
    private bool estaAExplodir = false;

    void Start()
    {
        pedacos = GetComponentsInChildren<Renderer>();
        vidaAtual = vidaMaxima;
        if(barraDeVida != null) barraDeVida.value = vidaAtual / vidaMaxima;
    }

    public void ReceberDano(float dano)
    {
        if (estaAExplodir) return;

        vidaAtual -= dano;
        if(barraDeVida != null) barraDeVida.value = vidaAtual / vidaMaxima;

        if (vidaAtual <= 0)
        {
            LevarTiro();
            if(barraDeVida != null) barraDeVida.gameObject.SetActive(false);
        }
    }

    public void LevarTiro()
    {
        if (!estaAExplodir) estaAExplodir = true;
    }

    void Update()
    {
        if (estaAExplodir)
        {
            // A força da explosão cresce sempre, empurrando os pedaços para longe
            forcaExplosao += Time.deltaTime * velocidadeDaExplosao;
            encolherEstilhacos += Time.deltaTime * velocidadeDoEncolhimento;

            // Mantemos o limite APENAS no encolhimento para o objeto ser destruído no momento certo
            encolherEstilhacos = Mathf.Clamp01(encolherEstilhacos);

            if (encolherEstilhacos >= 1.0f)
            {
                Destroy(gameObject);
                return;
            }
        }

        foreach (Renderer r in pedacos)
        {
            if (r != null && r.material != null)
            {
                r.material.SetFloat("_Explosion", forcaExplosao);
                r.material.SetFloat("_Shrink", encolherEstilhacos);
            }
        }
    }
}