using UnityEngine;

public class TeleportePortal : MonoBehaviour
{
    public Transform pontoDestino; // Arrasta o teu "spawnPoint" da Sala B para aqui

    void OnTriggerEnter(Collider outro)
    {
        // Se quem tocou no portal foi o Player
        if (outro.CompareTag("Player"))
        {
            CharacterController cc = outro.GetComponent<CharacterController>();
            
            // 1. Desliga a física temporariamente
            if (cc != null) cc.enabled = false; 

            // 2. Move para a Sala B
            outro.transform.position = pontoDestino.position;
            outro.transform.rotation = pontoDestino.rotation;

            // 3. Volta a ligar a física
            if (cc != null) cc.enabled = true; 
        }
    }
}