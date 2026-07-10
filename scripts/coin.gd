extends Area2D

@onready var game_manager: Node = %GameManager
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_collected := false

func _on_body_entered(_body: Node2D) -> void:
	if is_collected:
		return

	is_collected = true

	game_manager.add_point()

	# Evita que la moneda vuelva a detectarse.
	collision_shape.set_deferred("disabled", true) # En realidad funciona sin esto.

	# Oculta la parte visual de la moneda.
	hide()

	print("Picking up coin, blink")

	audio_stream_player_2d.play()
	await audio_stream_player_2d.finished

	queue_free()
