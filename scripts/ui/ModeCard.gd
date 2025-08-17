# ModeCard.gd - Individual card for mode selection carousel
# Location: res://Pyramids/scripts/ui/ModeCard.gd
# Last Updated: Initial creation [Date]

extends PanelContainer

# Card data
var mode_data: Dictionary = {}
var card_index: int = 0
var is_selected: bool = false

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var description_label: Label = $VBox/DescriptionLabel
@onready var difficulty_container: HBoxContainer = $VBox/DifficultyContainer
@onready var best_score_label: Label = $VBox/BestScoreLabel
@onready var lock_overlay: ColorRect = $LockOverlay
@onready var lock_icon: TextureRect = $LockOverlay/LockIcon

signal card_selected(index: int)

func _ready():
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(data: Dictionary, index: int):
	mode_data = data
	card_index = index
	
	# Set title (always visible)
	title_label.text = data.title
	
	# Set description (hidden by default)
	description_label.text = data.description
	description_label.visible = false
	
	# Set difficulty stars
	_setup_difficulty(data.difficulty)
	
	# Set best score
	if data.best_score > 0:
		best_score_label.text = "Best: %d" % data.best_score
	else:
		best_score_label.text = "New!"
	
	# Handle locked state
	if data.locked:
		lock_overlay.visible = true
		modulate.a = 0.7
	else:
		lock_overlay.visible = false
		modulate.a = 1.0
	
	# Apply color theme
	_apply_card_style()

func _setup_difficulty(level: int):
	# Clear existing stars
	for child in difficulty_container.get_children():
		child.queue_free()
	
	# Add difficulty stars
	for i in range(5):
		var star = Label.new()
		star.text = "★" if i < level else "☆"
		star.add_theme_font_size_override("font_size", 16)
		if i < level:
			star.add_theme_color_override("font_color", UIStyleManager.get_color("warning"))
		else:
			star.add_theme_color_override("font_color", UIStyleManager.get_color("gray_400"))
		difficulty_container.add_child(star)

func _apply_card_style():
	var style = StyleBoxFlat.new()
	
	# Get color from mode data
	var color_key = mode_data.get("color", "primary")
	var bg_color = UIStyleManager.get_color(color_key)
	
	style.bg_color = bg_color
	style.border_color = bg_color.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(UIStyleManager.get_dimension("corner_radius_large"))
	
	# Add shadow
	var shadow = UIStyleManager.get_shadow_config("medium")
	style.shadow_size = shadow.size
	style.shadow_offset = shadow.offset
	style.shadow_color = shadow.color
	
	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool):
	is_selected = selected
	
	# Show/hide description with animation
	var tween = create_tween()
	if selected:
		description_label.visible = true
		description_label.modulate.a = 0
		tween.tween_property(description_label, "modulate:a", 1.0, 0.3)
		
		# Scale up slightly
		tween.parallel().tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
		
		# Make title bigger
		title_label.add_theme_font_size_override("font_size", 24)
	else:
		tween.tween_property(description_label, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): description_label.visible = false)
		
		# Scale back to normal
		tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
		
		# Normal title size
		title_label.add_theme_font_size_override("font_size", 18)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not mode_data.locked:
				card_selected.emit(card_index)

func _on_mouse_entered():
	if not mode_data.locked and not is_selected:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited():
	if not mode_data.locked and not is_selected:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
