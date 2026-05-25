using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>
/// Rotação da câmara FPS.
///
/// SETUP:
///   1. Este script vai na Main Camera.
///   2. No Inspector arrasta o Player para "Player Body".
///   3. No Player adiciona o componente PlayerInput:
///      - Actions  → InputSystem_Actions
///      - Behavior → Send Messages
/// </summary>
public class FPSCameraLook : MonoBehaviour
{
    [Header("References")]
    [Tooltip("Transform do Player (corpo) — a rotação horizontal vai aqui.")]
    public Transform playerBody;

    [Header("Sensitivity")]
    public float sensitivityX = 0.15f;
    public float sensitivityY = 0.15f;

    [Header("Vertical Clamp")]
    [Range(-90f, 0f)] public float minPitch = -80f;
    [Range(0f, 90f)]  public float maxPitch =  80f;

    [Header("Smoothing (0 = off)")]
    [Range(0f, 0.9f)] public float smoothing = 0.05f;

    // ── Estado interno ──────────────────────────────────────────────
    private float   _pitch;
    private Vector2 _lookInput;
    private Vector2 _smoothed;

    void OnEnable()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible   = false;
    }

    void OnDisable()
    {
        Cursor.lockState = CursorLockMode.None;
        Cursor.visible   = true;
    }

    // Chamado automaticamente pelo PlayerInput (Send Messages)
    void OnLook(InputValue value)
    {
        _lookInput = value.Get<Vector2>();
    }

    void Update()
    {
        // Smooth opcional
        _smoothed = smoothing > 0f
            ? Vector2.Lerp(_smoothed, _lookInput, 1f - smoothing)
            : _lookInput;

        // Pitch — câmara sobe/desce
        _pitch -= _smoothed.y * sensitivityY;
        _pitch  = Mathf.Clamp(_pitch, minPitch, maxPitch);
        transform.localRotation = Quaternion.Euler(_pitch, 0f, 0f);

        // Yaw — player roda na horizontal
        if (playerBody != null)
            playerBody.Rotate(Vector3.up * _smoothed.x * sensitivityX);

        // ESC desbloqueia cursor no editor
        if (Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame)
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible   = true;
        }
    }
}
