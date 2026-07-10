extends Node

@onready var coins_collected: Label = $CoinsCollected
@onready var congratulations: Label = $Congratulations

var score: int = 0
var allCoins := false

func add_point():
	score += 1
	if score == 16:
		allCoins = true
	if allCoins:
		congratulations.visible = true
	coins_collected.text = "You collected " + str(score) + "/16 coins"
	#print(score)
