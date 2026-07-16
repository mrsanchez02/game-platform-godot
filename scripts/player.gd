extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const JUMP_CUT = 0.45  # Variable jump height
const ACCEL = 1300.0   # ground: reach top speed quickly
const FRICTION = 1600.0   # ground: stop quickly
const AIR_ACCELERATION = 900.0    # weaker steering in the air...
const AIR_FRICTION = 350.0    # ...and you keep momentum longer

# Jump Buffering
const COYOTE_TIME = 0.10  # still jumpable just after leaving a ledge
const JUMP_BUFFER = 0.10  # a press just before landing still counts

const SQUASH_STIFFNESS = 360.0  # higher = snappier recovery
const SQUASH_DAMPING   = 16.0   # lower = more wobble and bounce
const SPAWN_SQUASH     = 0.22   # the pop-in at level start
const AIR_STRETCH_MAX  = 0.10   # subtle tall-stretch that grows with air speed
const SQUASH_PIVOT     = 16.0   # keeps the feet planted while squashing

# Squash & stretch spring state (see _update_squash). squash > 0 = squashed
# (wide & short), squash < 0 = stretched (tall & thin); it springs back to 0.
var squash := 0.0
var squash_vel := 0.0
var base_sprite_y := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_jump: AudioStreamPlayer2D = $AudioJump

func _ready():
	add_to_group("player")
	base_sprite_y = animated_sprite.position.y
	_squash_impulse(SPAWN_SQUASH)  # a little pop-in so the level starts with energy

func _process(delta: float) -> void:
	_update_squash(delta)   # drive the squash/stretch spring every frame

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		Juice.trigger_hit_rumble()
		audio_jump.play()
		#_handle_jump(delta)
		velocity.y = JUMP_VELOCITY
		_squash_impulse(0.22)
		
	# Variable jump height
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
		
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

	# Applying movement
	if direction != 0.0:
		var accel := ACCEL if is_on_floor() else AIR_ACCELERATION
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
	else:
		var fric := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)
		
	move_and_slide()

#func trigger_hit_rumble():
	#var device_id = 0 # Default player 1 gamepad
	#var weak_motor = 0.4 # High-frequency rumble (subtle buzz)
	#var strong_motor = 0.8 # Low-frequency rumble (heavy impact)
	#var duration = 0.1 # In seconds
#
	#Input.start_joy_vibration(device_id, weak_motor, strong_motor, duration)

#func _handle_jump(delta):
	#var coyote_timer
	#var jump_buffer_timer
	#if is_on_floor():
		#coyote_timer = COYOTE_TIME
	#else:
		#coyote_timer = max(coyote_timer - delta, 0.0)
#
	#if Input.is_action_just_pressed("jump"):
		#jump_buffer_timer = JUMP_BUFFER
	#else:
		#jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
		#
	## A buffered press plus coyote grace = a jump. Neither has to be exact.
	#if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		#velocity.y = JUMP_VELOCITY
		#jump_buffer_timer = 0.0
		#coyote_timer = 0.0
# "Kick" the spring. Positive = squash (wide, short); negative = stretch (tall).
func _squash_impulse(amount: float):
	squash = amount
	squash_vel = 0.0

# Integrate the spring every frame and write it to the sprite's scale.
func _update_squash(delta):
	#var force := -SQUASH_STIFFNESS * squash - SQUASH_DAMPING * squash_vel
	#squash_vel += force * delta
	#squash += squash_vel * delta
	#animated_sprite.scale = Vector2(1.0 + squash, 1.0 - squash)
	if animated_sprite == null:
		return
	var d = minf(delta, 0.033)   # guard the spring against frame-time spikes
	var rest := 0.0
	if not is_on_floor():
		rest = -clampf(absf(velocity.y) / 650.0, 0.0, AIR_STRETCH_MAX)
	var force = -SQUASH_STIFFNESS * (squash - rest) - SQUASH_DAMPING * squash_vel
	squash_vel += force * d
	squash += squash_vel * d
	animated_sprite.scale = Vector2(1.0 + squash, 1.0 - squash)
	animated_sprite.position.y = base_sprite_y + SQUASH_PIVOT * squash
