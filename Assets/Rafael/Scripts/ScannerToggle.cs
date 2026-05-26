using UnityEngine;

public class ScannerToggle : MonoBehaviour
{
    [Header("Arrasta o teu Quad (Scanner) para aqui")]
    public GameObject scannerObject;

    void Update()
    {
        // Verifica se a tecla F foi pressionada neste exato frame
        if (Input.GetKeyDown(KeyCode.F))
        {
            // Confirma se não te esqueceste de atribuir o objeto no Unity
            if (scannerObject != null)
            {
                // Alterna o estado: se estiver ligado, desliga. Se estiver desligado, liga.
                bool estadoAtual = scannerObject.activeSelf;
                scannerObject.SetActive(!estadoAtual);
            }
            else
            {
                Debug.LogWarning("Falta arrastar o objeto do Scanner para o script!");
            }
        }
    }
}