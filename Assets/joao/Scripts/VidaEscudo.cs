using UnityEngine;

public class VidaEscudo : MonoBehaviour
{
    public float vida = 100f; // 4 tiros de 25 de dano destroem isto

    public void ReceberDano(float dano)
    {
        vida -= dano;
        if (vida <= 0f)
        {
            Destroy(gameObject); // O Force Field desaparece!
        }
    }
}