extends Area2D

@onready var timer: Timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	print("You died")
	trigger_hit_rumble()
	Engine.time_scale = 0.5
	body.die()
	body.get_node("CollisionShape2D").queue_free()
	timer.start()


func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func trigger_hit_rumble():
	var device_id = 0 # Default player 1 gamepad
	var weak_motor = 0.5 # High-frequency rumble (subtle buzz)
	var strong_motor = 0.9 # Low-frequency rumble (heavy impact)
	var duration = 0.5 # In seconds

	Input.start_joy_vibration(device_id, weak_motor, strong_motor, duration)
