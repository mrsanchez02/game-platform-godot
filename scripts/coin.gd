extends Area2D

const PIXEL_FONT = preload("res://assets/fonts/PixelOperator8.ttf")
const COIN_COLOR = Color(1.0, 0.85, 0.25)

@onready var game_manager: Node = %GameManager
@onready var pickup_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected := false

func _on_body_entered(_body: Node2D) -> void:
	if is_collected:
		return
	is_collected = true

	var score = game_manager.add_point()
	Juice.spawn_burst(global_position, COIN_COLOR, 12, 95.0)
	_spawn_popup(score)

	# Evita que la moneda vuelva a detectarse.
	collision_shape.set_deferred("disabled", true) # En realidad funciona sin esto.

	# Oculta la parte visual de la moneda.
	hide()

	# Each coin in a chain plays a little higher than the last (caps out so it
	# never gets shrill). That climbing pitch is most of the "feel good" here.
	#pickup_sound.pitch_scale = randf_range(0.9, 1.1)
	pickup_sound.pitch_scale = 1.0 + min(score - 1, 16) * 0.07
	
	pickup_sound.play()
	await pickup_sound.finished
	
	
	

	queue_free()

func _spawn_popup(combo: int):
	var label := Label.new()
	label.text = "+1"
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", COIN_COLOR)
	label.z_index = 30

	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(label)
	label.global_position = global_position + Vector2(-6, -10)

	var tween := label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -14), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
