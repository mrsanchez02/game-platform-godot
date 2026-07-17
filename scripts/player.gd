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
const MAX_AIR_JUMPS = 1       # extra jumps after leaving the ground
const JUMP_STRETCH = 0.22   # stretch on take-off
const DOUBLE_JUMP_VELOCITY = -260.0  # the second (air) jump, a touch weaker

const SQUASH_STIFFNESS = 360.0  # higher = snappier recovery
const SQUASH_DAMPING = 16.0   # lower = more wobble and bounce
const SPAWN_SQUASH = 0.22   # the pop-in at level start
const AIR_STRETCH_MAX = 0.10   # subtle tall-stretch that grows with air speed
const SQUASH_PIVOT = 16.0   # keeps the feet planted while squashing

# Squash & stretch spring state (see _update_squash). squash > 0 = squashed
# (wide & short), squash < 0 = stretched (tall & thin); it springs back to 0.
var squash := 0.0
var squash_vel := 0.0
var base_sprite_y := 0.0

# --- Runtime state ---
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var air_jumps_left := 0
var was_on_floor := false
var is_dead := false
var dust_cooldown := 0.0

# --- Motion trail (after-images) ---
# A short streak of fading ghost-sprites left behind by the flashy moves
# (double jump, stomp bounce) to make them read as fast and powerful.
var trail_timer := 0.0
var afterimage_cooldown := 0.0
const TRAIL_DURATION      = 0.35
const AFTERIMAGE_INTERVAL = 0.05
const TRAIL_COLOR = Color(0.6, 0.8, 1.0, 0.5)

# --- Camera feel: shake, look-ahead, zoom punch ---
var shake_strength := 0.0
const SHAKE_DECAY = 28.0   # higher = shake settles back faster

# Look-ahead: the camera leads slightly in the direction you're running so you
# can see what you're moving into. The camera is a character too.
var look_ahead_x := 0.0
const LOOK_AHEAD       = 16.0   # how far the camera leads, in pixels
const LOOK_AHEAD_SPEED = 4.0    # how quickly it eases to the lead position

# Zoom "punch": a quick push-in on big impacts that springs back to normal.
var base_zoom := Vector2.ONE
var zoom_punch := 0.0
const ZOOM_PUNCH_DECAY = 5.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer = $jump_sound
@onready var double_jump_sound: AudioStreamPlayer = $DoubleJump
@onready var dust_particles: CPUParticles2D = $DustParticles
@onready var hurt_sound: AudioStreamPlayer = $Hurt
@onready var camera: Camera2D = $Camera2D

func _ready():
	add_to_group("player")
	base_sprite_y = animated_sprite.position.y
	_squash_impulse(SPAWN_SQUASH)  # a little pop-in so the level starts with energy

func _process(delta: float) -> void:
	_update_squash(delta)   # drive the squash/stretch spring every frame
		# Decaying random shake, added on top of the look-ahead.
	var shake_vec := Vector2.ZERO
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, SHAKE_DECAY * delta)
		shake_vec = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength

	camera.offset = Vector2(look_ahead_x, 0.0) + shake_vec

	# Zoom punch: push in on impact, then spring back to the resting zoom.
	if zoom_punch > 0.0:
		zoom_punch = move_toward(zoom_punch, 0.0, ZOOM_PUNCH_DECAY * delta)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	_handle_jump(delta)
	_update_animation()
	_handle_movement(delta)
	_update_trail(delta)
	move_and_slide()
	pass

func _handle_jump(delta):
	# Tick down the two forgiveness timers.
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		air_jumps_left = MAX_AIR_JUMPS
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		Juice.trigger_hit_rumble()
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# A buffered press + coyote grace = a ground jump.
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_do_jump(JUMP_VELOCITY)
		_play_varied(jump_sound)
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	# Otherwise spend an air jump (double jump) with its own pop of feedback.
	elif jump_buffer_timer > 0.0 and air_jumps_left > 0:
		Juice.trigger_hit_rumble()
		_do_jump(DOUBLE_JUMP_VELOCITY)
		_play_varied(double_jump_sound)
		Juice.spawn_burst(global_position + Vector2(0, -6), Color(0.9, 0.95, 1.0), 8, 70.0)
		trail_timer = TRAIL_DURATION   # streak out of the double jump
		air_jumps_left -= 1
		jump_buffer_timer = 0.0

	# Variable jump height: let go early and the jump is cut short.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

func _do_jump(jump_force: float):
	velocity.y = jump_force
	_squash_impulse(-JUMP_STRETCH)   # stretch tall on take-off
	_spawn_dust(6)

func _squash_impulse(amount: float):
	squash = amount
	squash_vel = 0.0

# Integrate the spring every frame and write it to the sprite's scale.
func _update_squash(delta):
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

func _spawn_dust(amount: int):
	dust_particles.amount = max(1, amount)
	dust_particles.restart()

#  PLAY ANIMATION
func _update_animation():
	if not is_on_floor():
		animated_sprite.play("jump")
	elif abs(velocity.x) > 10.0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")

func _handle_movement(delta):
		# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	if direction != 0.0:
		var accel := ACCEL if is_on_floor() else AIR_ACCELERATION
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
	else:
		var fric := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)
	
	if is_on_floor() and abs(velocity.x) > 40.0:
		dust_cooldown -= delta
		if dust_cooldown <= 0.0:
			dust_cooldown = 0.2
			_spawn_dust(3)

func die():
	if is_dead:
		return
	is_dead = true

	_play_varied(hurt_sound)
	Juice.spawn_burst(global_position + Vector2(0, -6), Color(1.0, 0.4, 0.4), 22, 150.0)
	Juice.flash_screen(Color(0.7, 0.05, 0.05, 0.55), 0.5)   # red full-screen hit-flash
	#Music.duck()                                            # drop + muffle the music
	add_shake(7.0)
	add_zoom_punch(0.18)
	velocity = Vector2.ZERO
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)

	# Dramatic slow-mo, then restart.
	Engine.time_scale = 0.4
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	

func _spawn_afterimage():
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.global_position = animated_sprite.global_position
	ghost.flip_h = animated_sprite.flip_h
	ghost.scale = animated_sprite.scale
	ghost.modulate = TRAIL_COLOR
	ghost.z_index = 4   # behind the player (z_index 5)

	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)

#-----------------
# FEEDBACKS
#-----------------
# Plays a sound with a little random pitch so repeated actions never sound
# identical — the cheapest way to kill "repetition fatigue" in the SFX.
func _play_varied(sound: AudioStreamPlayer, low := 0.92, high := 1.09):
	sound.pitch_scale = randf_range(low, high)
	sound.play()

func add_shake(amount: float):
	shake_strength = max(shake_strength, amount)

func add_zoom_punch(amount: float):
	zoom_punch = max(zoom_punch, amount)

# While the trail timer is active, drop a fading ghost on a fixed cadence.
func _update_trail(delta: float):
	if trail_timer <= 0.0:
		return
	trail_timer -= delta
	afterimage_cooldown -= delta
	if afterimage_cooldown <= 0.0:
		afterimage_cooldown = AFTERIMAGE_INTERVAL
		_spawn_afterimage()
