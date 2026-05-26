using UnityEngine;

public class SistemaTiros : MonoBehaviour
{
    public float danoPorTiro = 25f; 

    void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            // O raio sai agora exatamente do centro da câmara (Crosshair)
            Ray raio = Camera.main.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0));
            RaycastHit acerto;

            if (Physics.Raycast(raio, out acerto))
            {
                // 1. Verifica se acertou no Force Field (Escudo) primeiro
                VidaEscudo escudo = acerto.collider.GetComponent<VidaEscudo>();
                if (escudo != null)
                {
                    escudo.ReceberDano(danoPorTiro);
                    return; // Interrompe o tiro aqui. A bala não passa do escudo!
                }

                // 2. Verifica se acertou na Nave (Só chega aqui se o tiro não bateu num escudo)
                ExplosaoNave nave = acerto.collider.GetComponentInParent<ExplosaoNave>();
                if (nave != null)
                {
                    nave.ReceberDano(danoPorTiro);
                }
            }
        }
    }
}