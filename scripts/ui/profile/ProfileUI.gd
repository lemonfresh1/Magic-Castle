# ProfileUI.gd - Profile interface showing player stats and equipped items
# Location: res://Pyramids/scripts/ui/profile/ProfileUI.gd
# Last Updated: Removed all inventory functionality - now just shows stats and equipped items [August 24, 2025]
#
# ProfileUI handles:
# - Displaying player stats (level, games played)
# - Showing equipped items summary (view only)
# - Player overview
#
# Flow: EquipmentManager → ProfileUI (display only)
# Dependencies: EquipmentManager (for equipped items), XPManager (for level), StatsManager (for stats)

extends PanelContainer

# === SIGNALS ===
signal profile_closed

# === NODE REFERENCES ===
@onready var tab_container: TabContainer = $MarginContainer/TabContainer

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	if UIStyleManager:
		UIStyleManager.apply_panel_style(self, "profile_ui")
	
	if EquipmentManager:
		if not EquipmentManager.item_equipped.is_connected(_on_item_equipped):
			EquipmentManager.item_equipped.connect(_on_item_equipped)
		if not EquipmentManager.item_unequipped.is_connected(_on_item_unequipped):
			EquipmentManager.item_unequipped.connect(_on_item_unequipped)
	
	_update_overview()

# === CORE FUNCTIONALITY ===

func _update_overview():
	"""Update the overview tab with player stats and equipped items"""
	var overview_tab = tab_container.get_node_or_null("Overview")
	if not overview_tab:
		return
	
	var vbox = overview_tab.find_child("VBoxContainer", true, false)
	if not vbox:
		return
	
	# Clear existing
	for child in vbox.get_children():
		child.queue_free()
	
	# === PLAYER NAME INPUT SECTION ===
	var name_container = HBoxContainer.new()
	name_container.add_theme_constant_override("separation", 10)
	vbox.add_child(name_container)
	
	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	name_label.custom_minimum_size = Vector2(60, 0)
	name_container.add_child(name_label)
	
	# NAME INPUT FIELD
	var name_input = LineEdit.new()
	name_input.custom_minimum_size = Vector2(200, 40)
	name_input.text = SettingsSystem.player_name if SettingsSystem else "Player"
	name_input.max_length = 20  # Character limit
	name_input.placeholder_text = "Enter your name"
	name_input.add_theme_font_size_override("font_size", 18)
	
	# Style the input field
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color.WHITE
	input_style.border_color = Color(0.7, 0.7, 0.7, 1)
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(8)
	name_input.add_theme_stylebox_override("normal", input_style)
	
	# Focused style
	var focused_style = input_style.duplicate()
	focused_style.border_color = Color(0.3, 0.5, 0.9, 1)  # Blue when focused
	focused_style.set_border_width_all(3)
	name_input.add_theme_stylebox_override("focus", focused_style)
	
	name_container.add_child(name_input)
	
	# Connect input changes to SettingsSystem
	name_input.text_changed.connect(func(new_text):
		if SettingsSystem:
			SettingsSystem.set_player_name(new_text)
			# Update ProfileCard if it exists
			var profile_card = get_tree().get_nodes_in_group("profile_card")
			if profile_card.size() > 0 and profile_card[0].has_method("_update_display"):
				profile_card[0]._update_display()
	)
	
	# Add some spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# === PLAYER STATS ===
	var level_label = Label.new()
	var level = XPManager.current_level if XPManager else 1
	level_label.text = "Level: %d" % level
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	vbox.add_child(level_label)
	
	var games_label = Label.new()
	var games = 0
	if StatsManager:
		var stats = StatsManager.get_total_stats()
		games = stats.games_played
	games_label.text = "Games Played: %d" % games
	games_label.add_theme_font_size_override("font_size", 18)
	games_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	vbox.add_child(games_label)
	
	# === EQUIPPED ITEMS ===
	var equipped_label = Label.new()
	equipped_label.text = "\nEquipped Items:"
	equipped_label.add_theme_font_size_override("font_size", 20)
	equipped_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	vbox.add_child(equipped_label)
	
	if EquipmentManager:
		var equipped_items = EquipmentManager.get_equipped_items()
		
		# Card Front
		_add_equipped_item_label(vbox, "card_front", "Card Front", equipped_items)
		
		# Card Back
		_add_equipped_item_label(vbox, "card_back", "Card Back", equipped_items)
		
		# Board
		_add_equipped_item_label(vbox, "board", "Board", equipped_items)
		
		# Avatar
		_add_equipped_item_label(vbox, "avatar", "Avatar", equipped_items)
		
		# Frame
		_add_equipped_item_label(vbox, "frame", "Frame", equipped_items)

# === PUBLIC INTERFACE ===

func show_profile():
	"""Show the profile UI"""
	visible = true
	_update_overview()

func hide_profile():
	"""Hide the profile UI"""
	visible = false
	profile_closed.emit()

# === PRIVATE HELPERS ===

func _add_equipped_item_label(parent: Node, category: String, display_name: String, equipped_items: Dictionary):
	"""Helper to add a label for an equipped item"""
	var item_id = equipped_items.get(category, "")
	if item_id != "" and ItemManager:
		var item = ItemManager.get_item(item_id)
		if item:
			var label = Label.new()
			label.text = "%s: %s" % [display_name, item.display_name]
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
			parent.add_child(label)

# === SIGNAL HANDLERS ===

func _on_item_equipped(item_id: String, category: String):
	"""Called when any item is equipped via EquipmentManager"""
	_update_overview()

func _on_item_unequipped(item_id: String, category: String):
	"""Called when any item is unequipped via EquipmentManager"""
	_update_overview()
