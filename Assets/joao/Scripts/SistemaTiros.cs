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
                ExplosaoNave nave = acerto.collider.GetComponentInParent<ExplosaoNave>();
                
                if (nave != null)
                {
                    nave.ReceberDano(danoPorTiro);
                }
            }
        }
    }
}