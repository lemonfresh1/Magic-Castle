# GameSettingsPanel.gd - Reusable game settings display component
# Location: res://Pyramids/scripts/ui/components/GameSettingsPanel.gd
# Last Updated: Created for multiplayer mode settings display [Date]
#
# Dependencies:
#   - GameModeManager - Mode configurations
#   - UIStyleManager - Consistent styling
#
# Flow: Can be embedded in any VBoxContainer to show game settings
#
# Functionality:
#   • Displays game mode settings in consistent format
#   • Supports read-only and editable modes (future)
#   • Auto-updates when mode changes
#
# Usage:
#   var settings_panel = GameSettingsPanel.new()
#   settings_vbox.add_child(settings_panel)
#   settings_panel.setup_display(mode_id, is_editable)

extends VBoxContainer

# === PROPERTIES ===
var current_mode_id: String = "classic"
var is_editable: bool = false
var show_title: bool = true
var compact_mode: bool = false  # For smaller displays

# === UI REFERENCES ===
var title_label: Label
var separator: HSeparator
var mode_label: Label
var settings_container: VBoxContainer

# === SIGNALS ===
signal setting_changed(setting_name: String, value: Variant)

func _ready():
	# Set default spacing
	add_theme_constant_override("separation", 8)

# === PUBLIC API ===

func setup_display(mode_id: String, editable: bool = false, options: Dictionary = {}) -> void:
	"""Main setup function to display game settings"""
	current_mode_id = mode_id
	is_editable = editable
	show_title = options.get("show_title", true)
	compact_mode = options.get("compact", false)
	
	_clear_display()
	_build_display()

func update_mode(mode_id: String) -> void:
	"""Update display for a different mode"""
	if current_mode_id == mode_id:
		return
	
	current_mode_id = mode_id
	_rebuild_settings()

func set_editable(editable: bool) -> void:
	"""Toggle between read-only and editable modes"""
	if is_editable == editable:
		return
		
	is_editable = editable
	_rebuild_settings()

func refresh() -> void:
	"""Refresh the current display"""
	_rebuild_settings()

# === PRIVATE DISPLAY BUILDERS ===

func _clear_display() -> void:
	"""Clear all existing children"""
	for child in get_children():
		child.queue_free()

func _build_display() -> void:
	"""Build the complete settings display"""
	# Title (optional)
	if show_title:
		title_label = Label.new()
		title_label.text = "Game Settings"
		title_label.add_theme_font_size_override("font_size", 18 if not compact_mode else 16)
		title_label.add_theme_color_override("font_color", Color.BLACK)
		add_child(title_label)
		
		separator = HSeparator.new()
		separator.add_theme_constant_override("separation", 8)
		add_child(separator)
	
	# Mode name
	mode_label = Label.new()
	var mode_name = _get_mode_display_name()
	mode_label.text = "Mode: %s" % mode_name
	mode_label.add_theme_font_size_override("font_size", 16 if not compact_mode else 14)
	mode_label.add_theme_color_override("font_color", Color.BLACK)
	add_child(mode_label)
	
	# Settings container
	settings_container = VBoxContainer.new()
	settings_container.add_theme_constant_override("separation", 6)
	add_child(settings_container)
	
	# Build settings rows
	_build_settings_rows()

func _build_settings_rows() -> void:
	"""Build the individual setting rows"""
	# Get mode config
	var mode_config = {}
	if GameModeManager:
		mode_config = GameModeManager.available_modes.get(current_mode_id, {})
	
	# Define settings to display
	var settings_info = [
		{"icon": "🏁", "key": "rounds", "text": _format_rounds_info(mode_config)},
		{"icon": "⏱️", "key": "timer", "text": _format_timer_info(mode_config)},
		{"icon": "🎴", "key": "draw", "text": _format_draw_info(mode_config)},
		{"icon": "🔓", "key": "slots", "text": _format_slot_info(mode_config)},
		{"icon": "⚡", "key": "combo", "text": _format_combo_info(mode_config)}
	]
	
	# Create rows
	for setting in settings_info:
		if is_editable and _is_setting_editable(setting.key):
			_create_editable_row(setting, mode_config)
		else:
			_create_readonly_row(setting)

func _create_readonly_row(setting: Dictionary) -> void:
	"""Create a read-only setting row"""
	var info_box = HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 8)
	
	# Icon
	var icon = Label.new()
	icon.text = setting.icon
	icon.add_theme_font_size_override("font_size", 14 if compact_mode else 16)
	icon.add_theme_color_override("font_color", Color.BLACK)
	icon.custom_minimum_size.x = 24
	info_box.add_child(icon)
	
	# Label
	var label = Label.new()
	label.text = setting.text
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 13 if compact_mode else 14)
	info_box.add_child(label)
	
	settings_container.add_child(info_box)

func _create_editable_row(setting: Dictionary, mode_config: Dictionary) -> void:
	"""Create an editable setting row (for custom lobbies)"""
	# TODO: Implement editable controls for custom lobby hosts
	# For now, just create readonly
	_create_readonly_row(setting)

func _rebuild_settings() -> void:
	"""Rebuild just the settings portion"""
	if settings_container:
		for child in settings_container.get_children():
			child.queue_free()
		_build_settings_rows()

func _is_setting_editable(key: String) -> bool:
	"""Check if a setting can be edited in custom lobbies"""
	# TODO: Define which settings hosts can change
	match key:
		"rounds", "timer", "draw":
			return true
		_:
			return false

# === FORMATTERS ===

func _get_mode_display_name() -> String:
	"""Get display name for current mode"""
	if GameModeManager:
		var config = GameModeManager.available_modes.get(current_mode_id, {})
		return config.get("display_name", current_mode_id.capitalize())
	
	# Fallback
	match current_mode_id:
		"classic": return "Classic"
		"timed_rush": return "Rush"
		"test": return "Test"
		_: return current_mode_id.capitalize()

func _format_rounds_info(config: Dictionary) -> String:
	"""Format rounds information"""
	var rounds = config.get("max_rounds", 10)
	if rounds == 1:
		return "1 round"
	else:
		return "%d rounds" % rounds

func _format_timer_info(config: Dictionary) -> String:
	"""Format timer information"""
	if not config.get("timer_enabled", false):
		return "No timer"
	
	var base = config.get("base_timer", 60)
	var decrease = config.get("timer_decrease_per_round", 0)
	
	if decrease > 0:
		return "%ds (-%ds/round)" % [base, decrease]
	else:
		return "%ds per round" % base

func _format_draw_info(config: Dictionary) -> String:
	"""Format draw pile information"""
	var base = config.get("base_draw_limit", 24)
	var decrease = config.get("draw_limit_decrease", 0)
	
	if base >= 999:
		return "Unlimited draws"
	elif decrease > 0:
		return "%d draws (-%d/round)" % [base, decrease]
	else:
		return "%d draws" % base

func _format_slot_info(config: Dictionary) -> String:
	"""Format slot unlock information"""
	var slot2 = config.get("slot_2_unlock", 2)
	var slot3 = config.get("slot_3_unlock", 6)
	
	if slot2 >= 999:
		return "Single slot only"
	else:
		return "Unlock at R%d, R%d" % [slot2, slot3]

func _format_combo_info(config: Dictionary) -> String:
	"""Format combo timeout information"""
	var timeout = config.get("combo_timeout", 10.0)
	
	if timeout >= 999:
		return "No combo limit"
	else:
		return "%.0fs combo time" % timeout

# === CUSTOM LOBBY EDITING (Future) ===

func enable_custom_editing() -> void:
	"""Enable editing for custom lobby hosts"""
	# TODO: Implement when custom lobbies are ready
	pass

func get_custom_settings() -> Dictionary:
	"""Get the current custom settings"""
	# TODO: Return modified settings for custom games
	return {}

func apply_preset(preset_name: String) -> void:
	"""Apply a settings preset"""
	# TODO: Quick presets like "Speed Run", "Marathon", etc.
	pass
