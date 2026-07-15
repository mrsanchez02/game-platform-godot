extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_jump: AudioStreamPlayer2D = $AudioJump


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		trigger_hit_rumble()
		audio_jump.play()
		velocity.y = JUMP_VELOCITY

	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
		
	# Play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play('idle')
		else:
			animated_sprite.play('run')
	else:
		
		animated_sprite.play('jump')
	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func trigger_hit_rumble():
	var device_id = 0 # Default player 1 gamepad
	var weak_motor = 0.4 # High-frequency rumble (subtle buzz)
	var strong_motor = 0.8 # Low-frequency rumble (heavy impact)
	var duration = 0.1 # In seconds

	Input.start_joy_vibration(device_id, weak_motor, strong_motor, duration)
