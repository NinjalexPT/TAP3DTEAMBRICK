using UnityEngine;
using UnityEngine.InputSystem;

/// <summary>
/// Movimento FPS: WASD, Sprint, Jump, Crouch.
///
/// SETUP:
///   1. Este script vai no Player (objeto raiz).
///   2. Adiciona também CharacterController ao Player.
///   3. Adiciona PlayerInput ao Player:
///      - Actions  → InputSystem_Actions
///      - Behavior → Send Messages
/// </summary>
[RequireComponent(typeof(CharacterController))]
public class FPSPlayerController : MonoBehaviour
{
    [Header("Movement")]
    public float walkSpeed   = 5f;
    public float sprintSpeed = 9f;
    public float crouchSpeed = 2.5f;

    [Header("Jump & Gravity")]
    public float jumpHeight = 1.2f;
    public float gravity    = -18f;

    [Header("Crouch")]
    public float standHeight           = 2f;
    public float crouchHeight          = 1f;
    public float crouchTransitionSpeed = 8f;

    // ── Refs ────────────────────────────────────────────────────────
    private CharacterController _cc;

    // ── Input state (preenchido pelos callbacks do PlayerInput) ─────
    private Vector2 _moveInput;
    private bool    _jumpPressed;
    private bool    _isSprinting;
    private bool    _isCrouching;

    // ── Física ──────────────────────────────────────────────────────
    private Vector3 _velocity;

    void Awake()
    {
        _cc = GetComponent<CharacterController>();
    }

    // ── Callbacks do PlayerInput (Send Messages) ────────────────────
    void OnMove(InputValue v)   => _moveInput   = v.Get<Vector2>();
    void OnSprint(InputValue v) => _isSprinting = v.isPressed;
    void OnCrouch(InputValue v) { if (v.isPressed) _isCrouching = !_isCrouching; }
    void OnJump(InputValue v)   { if (v.isPressed) _jumpPressed = true; }

    // ── Update ──────────────────────────────────────────────────────
    void Update()
    {
        HandleCrouchHeight();
        HandleMovement();
        HandleJumpAndGravity();
    }

    void HandleMovement()
    {
        float speed = _isCrouching ? crouchSpeed
                    : _isSprinting ? sprintSpeed
                                   : walkSpeed;

        Vector3 move = transform.right   * _moveInput.x
                     + transform.forward * _moveInput.y;

        _cc.Move(move * speed * Time.deltaTime);
    }

    void HandleJumpAndGravity()
    {
        bool grounded = _cc.isGrounded;

        if (grounded && _velocity.y < 0f)
            _velocity.y = -2f;

        if (_jumpPressed && grounded)
        {
            _velocity.y = Mathf.Sqrt(jumpHeight * -2f * gravity);
            _jumpPressed = false;
        }
        else
        {
            _jumpPressed = false;
        }

        _velocity.y += gravity * Time.deltaTime;
        _cc.Move(_velocity * Time.deltaTime);
    }

    void HandleCrouchHeight()
    {
        float target = _isCrouching ? crouchHeight : standHeight;
        _cc.height = Mathf.Lerp(_cc.height, target,
                                 crouchTransitionSpeed * Time.deltaTime);
    }
}
