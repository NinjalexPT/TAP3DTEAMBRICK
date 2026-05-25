using UnityEngine;

public class VirarParaCamera : MonoBehaviour
{
    void Update()
    {
        // Força a barra de vida a olhar sempre para a câmara do jogador
        transform.LookAt(transform.position + Camera.main.transform.rotation * Vector3.forward,
                         Camera.main.transform.rotation * Vector3.up);
    }
}