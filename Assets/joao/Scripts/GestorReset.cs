using UnityEngine;
using UnityEngine.SceneManagement; // Necessário para recarregar cenas

public class GestorReset : MonoBehaviour
{
    public void ReiniciarCena()
    {
        // Recarrega a cena atual do zero
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }
}