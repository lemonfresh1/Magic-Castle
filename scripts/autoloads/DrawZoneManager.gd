# DrawZoneManager.gd - Autoload for managing draw zones and draw pile
# Path: res://Pyramids/scripts/autoloads/DrawZoneManager.gd
# Last Updated: Initial creation - handles all draw zone logic
#
# DrawZoneManager handles:
# - Draw zone state management (left/right/both/none)
# - Availability checking based on game rules
# - Visual state updates (pulsing, disabled appearance)
# - Zone input handling and click animations
# - Draw pile triggering with rule validation
# - Sync with SettingsSystem for user preferences
#
# Flow: User input/Game state → DrawZoneManager → Visual updates → Draw pile action
# Dependencies: CardManager (pile state), GameModeManager (draw limits), UIStyleManager (visuals)

extends Node

# === DRAW ZONE CONFIGURATION ===
enum DrawZoneMode {
	LEFT_ONLY,
	RIGHT_ONLY,
	BOTH,
	NONE  # For potential PC mode
}

# === STATE ===
var current_mode: DrawZoneMode = DrawZoneMode.BOTH
var left_zone_enabled: bool = true
var right_zone_enabled: bool = true
var zones_available: bool = true
var pulse_animation_active: bool = false

# === VISUAL SETTINGS ===
const PULSE_DURATION: float = 1.0
const PULSE_ALPHA_MIN: float = 0.5
const PULSE_ALPHA_MAX: float = 1.0
const UNAVAILABLE_ALPHA: float = 0.2
const CLICK_SCALE: float = 0.9
const CLICK_DURATION: float = 0.05

# === CACHED REFERENCES ===
var left_zone_node: Control = null
var right_zone_node: Control = null
var active_pulse_tweens: Array[Tween] = []

# === SIGNALS ===
signal draw_zone_clicked(zone_side: String)
signal draw_zones_updated()
signal availability_changed(available: bool)

func _ready() -> void:
	print("DrawZoneManager initialized")
	_load_draw_zone_preferences()
	
	# Connect to relevant signals
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.draw_pile_mode_changed.connect(_on_draw_mode_changed)

func _load_draw_zone_preferences() -> void:
	"""Load user's draw zone preferences from settings"""
	left_zone_enabled = SettingsSystem.is_left_draw_enabled()
	right_zone_enabled = SettingsSystem.is_right_draw_enabled()
	
	# Determine mode based on enabled zones
	if left_zone_enabled and right_zone_enabled:
		current_mode = DrawZoneMode.BOTH
	elif left_zone_enabled:
		current_mode = DrawZoneMode.LEFT_ONLY
	elif right_zone_enabled:
		current_mode = DrawZoneMode.RIGHT_ONLY
	else:
		# Mobile should always have at least one zone
		# Default to both if somehow both are disabled
		current_mode = DrawZoneMode.BOTH
		left_zone_enabled = true
		right_zone_enabled = true
		SettingsSystem.set_left_draw_enabled(true)
		SettingsSystem.set_right_draw_enabled(true)

# === PUBLIC API ===

func setup_draw_zones(left_zone: Control, right_zone: Control) -> void:
	"""Initialize draw zones with node references"""
	left_zone_node = left_zone
	right_zone_node = right_zone
	
	_configure_zone_visibility()
	_setup_zone_visuals()
	_connect_zone_inputs()
	
	print("Draw zones configured - Left: %s, Right: %s" % [left_zone_enabled, right_zone_enabled])

func update_availability() -> void:
	"""Update draw zone availability based on game state"""
	if not CardManager:
		zones_available = false
		return
	
	var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
	var cards_drawn = CardManager.cards_drawn
	var pile_size = CardManager.draw_pile.size()
	
	var was_available = zones_available
	zones_available = pile_size > 0 and cards_drawn < draw_limit
	
	# Notify if availability changed
	if was_available != zones_available:
		availability_changed.emit(zones_available)
	
	# Update visual state
	_update_zone_states()

func get_zone_width() -> float:
	"""Get the width for draw zones"""
	if UIStyleManager:
		return UIStyleManager.get_game_dimension("draw_zone_width")
	return 80.0  # Default fallback

func get_active_zones() -> Array[String]:
	"""Get list of active zone sides"""
	var zones: Array[String] = []
	if left_zone_enabled:
		zones.append("left")
	if right_zone_enabled:
		zones.append("right")
	return zones

func get_draw_mode() -> DrawZoneMode:
	"""Get current draw zone mode"""
	return current_mode

func set_draw_mode(mode: DrawZoneMode) -> void:
	"""Set draw zone mode"""
	current_mode = mode
	
	match mode:
		DrawZoneMode.LEFT_ONLY:
			left_zone_enabled = true
			right_zone_enabled = false
		DrawZoneMode.RIGHT_ONLY:
			left_zone_enabled = false
			right_zone_enabled = true
		DrawZoneMode.BOTH:
			left_zone_enabled = true
			right_zone_enabled = true
		DrawZoneMode.NONE:
			left_zone_enabled = false
			right_zone_enabled = false
	
	# Note: Removed SettingsSystem updates to prevent recursion
	# SettingsSystem should be the one calling DrawZoneManager, not vice versa
	
	# Update visuals if zones exist
	if left_zone_node or right_zone_node:
		_configure_zone_visibility()
		_setup_zone_visuals()
	
	# Notify listeners
	draw_zones_updated.emit()
	SignalBus.draw_pile_mode_changed.emit(mode)

func trigger_draw_pile() -> void:
	"""Trigger a draw pile action"""
	if zones_available:
		SignalBus.draw_pile_clicked.emit()
		update_availability()

func handle_zone_click(zone_side: String) -> void:
	"""Handle click on a draw zone"""
	if not zones_available:
		return
	
	# Animate the clicked zone
	var zone = left_zone_node if zone_side == "left" else right_zone_node
	if zone:
		animate_zone_click(zone)
	
	# Emit signals
	draw_zone_clicked.emit(zone_side)
	trigger_draw_pile()

# === VISUAL MANAGEMENT ===

func _configure_zone_visibility() -> void:
	"""Set visibility of draw zones based on mode"""
	if left_zone_node:
		left_zone_node.visible = left_zone_enabled
	if right_zone_node:
		right_zone_node.visible = right_zone_enabled

func _setup_zone_visuals() -> void:
	"""Setup visual appearance of draw zones"""
	if left_zone_enabled and left_zone_node:
		_setup_single_zone_visual(left_zone_node)
	
	if right_zone_enabled and right_zone_node:
		_setup_single_zone_visual(right_zone_node)

func _setup_single_zone_visual(zone: Control) -> void:
	"""Setup visual for a single draw zone"""
	# Clear existing children
	for child in zone.get_children():
		child.queue_free()
	
	# Create background panel
	var background = Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Apply style from UIStyleManager if available
	if UIStyleManager:
		var style = UIStyleManager.apply_draw_zone_style(zone)
		background.add_theme_stylebox_override("panel", style)
	else:
		# Fallback style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.3, 0.4, 0.3)
		style.border_color = Color(0.4, 0.5, 0.6, 0.6)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		background.add_theme_stylebox_override("panel", style)
	
	zone.add_child(background)
	
	# Setup initial state
	update_availability()

func _connect_zone_inputs() -> void:
	"""Connect input handlers for draw zones"""
	if left_zone_node and not left_zone_node.gui_input.is_connected(_on_left_zone_input):
		left_zone_node.gui_input.connect(_on_left_zone_input)
		left_zone_node.mouse_filter = Control.MOUSE_FILTER_PASS
		left_zone_node.z_index = 5
	
	if right_zone_node and not right_zone_node.gui_input.is_connected(_on_right_zone_input):
		right_zone_node.gui_input.connect(_on_right_zone_input)
		right_zone_node.mouse_filter = Control.MOUSE_FILTER_PASS
		right_zone_node.z_index = 5

func _update_zone_states() -> void:
	"""Update visual states of draw zones based on availability"""
	if left_zone_enabled and left_zone_node:
		_update_single_zone_state(left_zone_node)
	
	if right_zone_enabled and right_zone_node:
		_update_single_zone_state(right_zone_node)

func _update_single_zone_state(zone: Control) -> void:
	"""Update visual state of a single zone"""
	var background = zone.get_node_or_null("Background")
	if not background:
		return
	
	# Stop existing pulse animation
	_stop_pulse_animation(zone)
	
	if zones_available:
		# Start pulse animation
		_start_pulse_animation(zone, background)
		background.modulate.a = PULSE_ALPHA_MAX
	else:
		# Set to unavailable state
		background.modulate.a = UNAVAILABLE_ALPHA

func _start_pulse_animation(zone: Control, background: Control) -> void:
	"""Start pulse animation for available zone"""
	var tween = zone.create_tween()
	tween.set_loops()
	
	tween.tween_property(
		background, 
		"modulate:a", 
		PULSE_ALPHA_MIN, 
		PULSE_DURATION / 2
	)
	tween.tween_property(
		background, 
		"modulate:a", 
		PULSE_ALPHA_MAX, 
		PULSE_DURATION / 2
	)
	
	# Store tween reference
	zone.set_meta("pulse_tween", tween)
	active_pulse_tweens.append(tween)

func _stop_pulse_animation(zone: Control) -> void:
	"""Stop pulse animation for a zone"""
	if zone.has_meta("pulse_tween"):
		var tween = zone.get_meta("pulse_tween")
		if tween and tween.is_valid():
			tween.kill()
		zone.remove_meta("pulse_tween")

func animate_zone_click(zone: Control) -> void:
	"""Animate zone when clicked"""
	if UIStyleManager:
		UIStyleManager.animate_draw_zone_click(zone)
	else:
		# Fallback animation
		var tween = zone.create_tween()
		tween.tween_property(zone, "scale", Vector2(CLICK_SCALE, CLICK_SCALE), CLICK_DURATION)
		tween.tween_property(zone, "scale", Vector2.ONE, CLICK_DURATION)

# === INPUT HANDLERS ===

func _on_left_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_zone_click("left")

func _on_right_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_zone_click("right")

# === SIGNAL HANDLERS ===

func _on_draw_pile_clicked() -> void:
	"""Handle draw pile click from other sources"""
	update_availability()

func _on_round_started(_round: int) -> void:
	"""Handle round start"""
	update_availability()

func _on_draw_mode_changed(mode: int) -> void:
	"""Handle draw mode change from settings"""
	if mode != current_mode:
		set_draw_mode(mode as DrawZoneMode)

# === UTILITY FUNCTIONS ===

func get_draws_remaining() -> int:
	"""Get number of draws remaining"""
	if not CardManager:
		return 0
	
	var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
	var cards_drawn = CardManager.cards_drawn
	var pile_size = CardManager.draw_pile.size()
	
	var draws_remaining = min(pile_size, draw_limit - cards_drawn)
	return max(0, draws_remaining)

func can_draw() -> bool:
	"""Check if drawing is currently possible"""
	return zones_available

func get_zone_positions(board_size: Vector2) -> Dictionary:
	"""Get positions for draw zones"""
	var zone_width = get_zone_width()
	
	return {
		"left": {
			"position": Vector2(0, 0),
			"size": Vector2(zone_width, board_size.y)
		},
		"right": {
			"position": Vector2(board_size.x - zone_width, 0),
			"size": Vector2(zone_width, board_size.y)
		}
	}

# === DEBUG ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"mode": DrawZoneMode.keys()[current_mode],
		"left_enabled": left_zone_enabled,
		"right_enabled": right_zone_enabled,
		"available": zones_available,
		"draws_remaining": get_draws_remaining(),
		"active_zones": get_active_zones()
	}

func print_debug() -> void:
	"""Print debug information"""
	print("=== DRAW ZONE MANAGER DEBUG ===")
	var info = get_debug_info()
	for key in info:
		print("%s: %s" % [key, info[key]])
	print("==============================")
