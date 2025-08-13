# ProceduralBoardTest.gd - Test scene for procedural card designs
# Location: res://Pyramids/scenes/test/ProceduralCardTest.gd
# Last Updated: Created test scene for procedural cards [Date]

extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var test_button: Button = $VBoxContainer/HBoxContainer/TestButton
@onready var export_button: Button = $VBoxContainer/HBoxContainer/ExportButton
@onready var discover_button: Button = $VBoxContainer/HBoxContainer/DiscoverButton
@onready var card_display: Control = $VBoxContainer/CardDisplay

var current_card_back: ProceduralCardBack
var test_canvas: Control

func _ready():
	# Setup UI
	title_label.text = "Procedural Card Back Test"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	test_button.text = "Test Classic Pyramids Gold"
	export_button.text = "Export PNG"
	discover_button.text = "Discover All Items"
	
	# Setup card display area
	card_display.custom_minimum_size = Vector2(200, 280)
	card_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Connect buttons
	test_button.pressed.connect(_on_test_button_pressed)
	export_button.pressed.connect(_on_export_button_pressed)
	discover_button.pressed.connect(_on_discover_button_pressed)
	
	# Create test canvas
	test_canvas = Control.new()
	test_canvas.size = Vector2(180, 252)
	test_canvas.position = Vector2(10, 10)
	test_canvas.draw.connect(_on_canvas_draw)
	card_display.add_child(test_canvas)
	
	print("ProceduralCardTest ready!")

func _on_test_button_pressed():
	print("Creating Classic Pyramids Gold...")
	
	# Create the card back
	current_card_back = ClassicPyramidsGold.new()
	
	if current_card_back:
		print("✓ Classic Pyramids Gold created successfully!")
		print("  Display Name: %s" % current_card_back.display_name)
		print("  Theme: %s" % current_card_back.theme_name)
		print("  Animated: %s" % current_card_back.is_animated)
		print("  Animation Elements: %s" % current_card_back.animation_elements)
		
		# Start animation if supported
		if current_card_back.is_animated:
			current_card_back.setup_animation_on_node(self)
			print("  ✓ Animation started!")
		
		# Trigger redraw
		test_canvas.queue_redraw()
		export_button.disabled = false
	else:
		print("✗ Failed to create Classic Pyramids Gold")

func _on_export_button_pressed():
	if not current_card_back:
		print("No card back to export!")
		return
	
	print("Exporting to PNG with smart path...")
	# Use the new smart export (no path parameter = auto-generate)
	var success = await current_card_back.export_to_png()
	
	if success:
		print("✓ Exported successfully using smart path!")
	else:
		print("✗ Export failed!")

func _on_discover_button_pressed():
	print("Running procedural item discovery...")
	ProceduralItemRegistry.discover_and_register_all()
	ProceduralItemRegistry.debug_print_registry()

func _on_canvas_draw():
	if current_card_back and test_canvas:
		# Clear and draw the card
		current_card_back.draw_card_back(test_canvas, test_canvas.size)

func _process(_delta):
	# Update animation and redraw if needed
	if current_card_back and current_card_back.is_animated:
		test_canvas.queue_redraw()
