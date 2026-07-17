extends Node

@onready var congratulations: Label = $Congratulations
@onready var label_5: Label = $"../Labels/Label5"
@onready var coin_counter: Label = $"../HUBLayer/CoinCounter"

var score: int = 0
var allCoins := false
const GO_COLOR  := Color(0.5, 0.779, 0.0, 1.0)

func add_point():
	score += 1
	if score == 16:
		allCoins = true
	if allCoins:
		congratulations.visible = true
		coin_counter.add_theme_color_override("font_color", GO_COLOR)
	coin_counter.text = "Coins:" + str(score) +"/16 coins"
	return score

func _on_timer_timeout() -> void:
	label_5.visible = false
