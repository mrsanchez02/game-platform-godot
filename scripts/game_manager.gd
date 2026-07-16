extends Node

@onready var coins_collected: Label = $CoinsCollected
@onready var congratulations: Label = $Congratulations
@onready var label_5: Label = $"../Labels/Label5"

var score: int = 0
var allCoins := false

func add_point():
	score += 1
	if score == 16:
		allCoins = true
	if allCoins:
		congratulations.visible = true
	coins_collected.text = "You collected " + str(score) + "/16 coins"
	return score

func _on_timer_timeout() -> void:
	label_5.visible = false
