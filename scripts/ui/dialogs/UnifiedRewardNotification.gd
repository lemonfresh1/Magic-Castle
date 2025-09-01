# UnifiedRewardNotification.gd - COMPLETE REDESIGN to match RewardClaimPopup
# Path: res://Pyramids/scripts/ui/dialogs/UnifiedRewardNotification.gd
# Last Updated: Redesigned to match RewardClaimPopup clean style

extends PanelContainer
class_name UnifiedRewardNotification

# Debug
var debug_enabled: bool = false
var global_debug: bool = true

# UI Constants (match RewardClaimPopup)
const POPUP_WIDTH: int = 600
const POPUP_HEIGHT: int = 280

# Data storage
var level_ups: Array = []
var total_stars_gained: int = 0
var source_name: String = ""

# UI elements
var title_label: Label
var level_up_container: VBoxContainer
var message_label: Label
var accept_button: Button

signal confirmed()

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[UNIFIED_REWARD_NOTIFICATION] %s" % message)

func _ready():
	_debug_log("UnifiedRewardNotification ready")
	
	# Apply same panel style as RewardClaimPopup
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.border_color = Color("#E5E7EB")
	style.set_border_width_all(1)
	add_theme_stylebox_override("panel", style)
	
	# Set size
	custom_minimum_size = Vector2(POPUP_WIDTH, POPUP_HEIGHT)
	size = Vector2(POPUP_WIDTH, POPUP_HEIGHT)
	
	_create_popup_structure()
	_center_popup()

func _create_popup_structure():
	"""Create the popup UI structure matching RewardClaimPopup"""
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "Level Up! 🎉"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color("#1F2937"))
	vbox.add_child(title_label)
	
	# Level-up container (golden background like RewardClaimPopup)
	level_up_container = VBoxContainer.new()
	level_up_container.add_theme_constant_override("separation", 8)
	vbox.add_child(level_up_container)
	
	# Message
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.x = 550
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color("#6B7280"))
	vbox.add_child(message_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Button
	var button_container = CenterContainer.new()
	vbox.add_child(button_container)
	
	accept_button = Button.new()
	accept_button.text = "Awesome!"
	accept_button.custom_minimum_size = Vector2(120, 36)
	button_container.add_child(accept_button)
	
	# Style button
	var button_style_normal = StyleBoxFlat.new()
	button_style_normal.bg_color = Color("#3B82F6")
	button_style_normal.set_corner_radius_all(8)
	button_style_normal.content_margin_left = 24
	button_style_normal.content_margin_right = 24
	button_style_normal.content_margin_top = 8
	button_style_normal.content_margin_bottom = 8
	
	var button_style_hover = button_style_normal.duplicate()
	button_style_hover.bg_color = Color("#2563EB")
	
	var button_style_pressed = button_style_normal.duplicate()
	button_style_pressed.bg_color = Color("#1D4ED8")
	
	accept_button.add_theme_stylebox_override("normal", button_style_normal)
	accept_button.add_theme_stylebox_override("hover", button_style_hover)
	accept_button.add_theme_stylebox_override("pressed", button_style_pressed)
	accept_button.add_theme_color_override("font_color", Color.WHITE)
	accept_button.add_theme_font_size_override("font_size", 16)
	
	accept_button.pressed.connect(_on_accept_pressed)

func show_level_ups(level_data: Array):
	"""Show level-ups in clean style"""
	_debug_log("Showing %d level-ups" % level_data.size())
	level_ups = level_data
	
	if level_ups.is_empty():
		queue_free()
		return
	
	_create_level_up_display()
	show()

func show_level_ups_with_context(level_data: Array, context: Dictionary):
	"""Show level-ups with context"""
	_debug_log("Showing %d level-ups from %s" % [level_data.size(), context.get("trigger_source", "unknown")])
	level_ups = level_data
	source_name = context.get("trigger_source", "")
	total_stars_gained = context.get("total_stars_earned", 0)
	
	if level_ups.is_empty():
		queue_free()
		return
	
	_create_level_up_display()
	
	# Add context to message
	match source_name:
		"achievement":
			message_label.text = "From achievement claim!"
		"mission":
			message_label.text = "From mission completion!"
		_:
			message_label.text = "Congratulations!"
	
	show()

func _create_level_up_display():
	"""Create the level-up display matching RewardClaimPopup style"""
	# Clear existing
	for child in level_up_container.get_children():
		child.queue_free()
	
	# Create golden panel like RewardClaimPopup
	var level_panel = PanelContainer.new()
	var level_style = StyleBoxFlat.new()
	level_style.bg_color = Color("#FEF3C7")  # Light yellow
	level_style.set_corner_radius_all(8)
	level_style.border_color = Color("#FCD34D")  # Golden
	level_style.set_border_width_all(1)
	level_panel.add_theme_stylebox_override("panel", level_style)
	level_up_container.add_child(level_panel)
	
	var level_margin = MarginContainer.new()
	level_margin.add_theme_constant_override("margin_left", 16)
	level_margin.add_theme_constant_override("margin_right", 16)
	level_margin.add_theme_constant_override("margin_top", 12)
	level_margin.add_theme_constant_override("margin_bottom", 12)
	level_panel.add_child(level_margin)
	
	var level_vbox = VBoxContainer.new()
	level_vbox.add_theme_constant_override("separation", 4)
	level_margin.add_child(level_vbox)
	
	# Level progression text
	var level_label = Label.new()
	if level_ups.size() == 1:
		level_label.text = "Level %d → Level %d" % [level_ups[0].old_level, level_ups[0].new_level]
	else:
		level_label.text = "Level %d → Level %d" % [level_ups[0].old_level, level_ups[-1].new_level]
	
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 20)
	level_label.add_theme_color_override("font_color", Color("#92400E"))
	level_vbox.add_child(level_label)
	
	# Calculate total stars from level-ups
	var level_stars = 0
	for data in level_ups:
		if data.rewards.has("stars"):
			level_stars += data.rewards.stars
	
	# Show star rewards if any
	if level_stars > 0:
		var star_label = Label.new()
		star_label.text = "Level rewards: Earned %d stars from level ups" % level_stars
		star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_label.add_theme_font_size_override("font_size", 16)
		star_label.add_theme_color_override("font_color", Color("#B45309"))
		level_vbox.add_child(star_label)

func _center_popup():
	"""Center popup on screen"""
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_size = viewport_rect.size
	
	position = (viewport_size - size) / 2
	
	# Ensure on screen
	position.x = max(20, min(position.x, viewport_size.x - size.x - 20))
	position.y = max(20, min(position.y, viewport_size.y - size.y - 20))
	
	z_index = 999
	visible = true
	modulate = Color.WHITE

func _on_accept_pressed():
	"""Handle accept button"""
	_debug_log("Accept pressed, closing")
	confirmed.emit()
	queue_free()

func show_rewards(source: String, rewards: Dictionary):
	"""Legacy method for compatibility"""
	_debug_log("show_rewards called but redirecting to level_ups")
	# This shouldn't be called for achievements anymore
	queue_free()
