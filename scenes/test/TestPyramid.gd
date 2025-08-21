extends Control

func _ready():
	# Create a test canvas
	var test_rect = Control.new()
	test_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	test_rect.custom_minimum_size = Vector2(400, 300)
	add_child(test_rect)
	
	# Load and test the PyramidsBoard
	var board_script = load("res://Pyramids/scripts/items/boards/procedural/rare/PyramidsBoard.gd")
	if board_script:
		var board = board_script.new()
		
		# Draw the board
		test_rect.draw.connect(func():
			board.draw_board_background(test_rect, test_rect.size)
		)
		
		# Animate it
		var tween = create_tween()
		tween.set_loops()
		tween.tween_method(
			func(phase: float):
				board.animation_phase = phase
				test_rect.queue_redraw(),
			0.0, 1.0, board.animation_duration
		)
	else:
		print("ERROR: Could not load PyramidsBoard script!")
