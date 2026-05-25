using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : MonoBehaviour
{
    [Header("Movimento")]
    public float velocidade = 5f;
    public float sensibilidade = 0.5f;
    
    [Header("Interação")]
    public GameObject portal; 
    public bool temSonar = true; 

    private float rotacaoX = 0f;
    private Transform camTransform;
    private CharacterController controller; // <--- ADICIONADO

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        camTransform = Camera.main.transform;
        controller = GetComponent<CharacterController>(); // <--- ADICIONADO
        
        if (portal != null) portal.SetActive(false); 
    }

    void Update()
    {
        if (Keyboard.current == null || Mouse.current == null || controller == null) return;

        // 1. Olhar (Rato)
        Vector2 ratoDelta = Mouse.current.delta.ReadValue();
        transform.Rotate(Vector3.up * ratoDelta.x * sensibilidade); 
        
        rotacaoX -= ratoDelta.y * sensibilidade;
        rotacaoX = Mathf.Clamp(rotacaoX, -90f, 90f);
        camTransform.localRotation = Quaternion.Euler(rotacaoX, 0f, 0f); 

        // 2. Mover com Colisão (WASD)
        float x = 0f; float z = 0f;
        if (Keyboard.current.wKey.isPressed) z += 1f;
        if (Keyboard.current.sKey.isPressed) z -= 1f;
        if (Keyboard.current.dKey.isPressed) x += 1f;
        if (Keyboard.current.aKey.isPressed) x -= 1f;

        Vector3 direcao = (transform.right * x + transform.forward * z).normalized;
        
        // Aplica gravidade simples para não flutuares se o chão descer
        Vector3 movimentoFinal = direcao * velocidade;
        movimentoFinal.y = Physics.gravity.y; 

        controller.Move(movimentoFinal * Time.deltaTime); // <--- APLICADO COM COLISÃO

        // 3. Interagir (Clicar no botão)
       
    }

    void OnTriggerEnter(Collider outro)
    {
        // Se o jogador entrar na área invisível do botão...
        if (outro.CompareTag("BotaoSecreto"))
        {
            // ...e tiver o Sonar ativado, liga o portal!
            if (temSonar && portal != null) 
            {
                portal.SetActive(true);
            }
        }
    }   
}