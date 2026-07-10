extends Node

var score: int = 0
@onready var coins_collected: Label = $CoinsCollected


func add_point():
	score += 1
	coins_collected.text = "You collected " + str(score) + " coins"
	print(score)
