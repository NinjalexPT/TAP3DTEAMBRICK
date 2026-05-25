using UnityEngine;

public class MovimentoCamera : MonoBehaviour
{
    public float velocidade = 10f;
    public float sensibilidade = 2f;
    private float rotacaoX = 0f;
    private float rotacaoY = 0f;

    void Start()
    {
        // Tranca e esconde o rato no centro do ecrã
        Cursor.lockState = CursorLockMode.Locked; 
    }

    void Update()
    {
        // Movimento (W, A, S, D)
        float x = Input.GetAxis("Horizontal") * velocidade * Time.deltaTime;
        float z = Input.GetAxis("Vertical") * velocidade * Time.deltaTime;
        transform.Translate(x, 0, z);

        // Olhar em volta (Rato)
        rotacaoX -= Input.GetAxis("Mouse Y") * sensibilidade;
        rotacaoY += Input.GetAxis("Mouse X") * sensibilidade;
        rotacaoX = Mathf.Clamp(rotacaoX, -90f, 90f); // Impede de dar cambalhotas com a cabeça

        transform.localRotation = Quaternion.Euler(rotacaoX, rotacaoY, 0f);

        // Clica ESC para destrancar o rato e poderes clicar no botão de Reset
        if (Input.GetKeyDown(KeyCode.Escape)) 
        {
            Cursor.lockState = CursorLockMode.None;
        }
    }
}