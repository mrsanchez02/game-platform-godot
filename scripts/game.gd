extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func check_device():
	# Get the exact platform name (e.g., "Android", "iOS", "Windows", "macOS", "Linux", "Web")
	var platform = OS.get_name()
	print("Running on: ", platform)
	
	# Check if running on a mobile device
	if OS.has_feature("mobile"):
		print("This is a mobile device.")
		
	# Check for specific platforms
	match platform:
		"Android", "iOS":
			print("Mobile controls enabled")
		"Windows", "macOS", "Linux":
			print("Desktop controls enabled")
