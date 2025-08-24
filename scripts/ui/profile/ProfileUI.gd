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
	
	# Player info
	var name_label = Label.new()
	name_label.text = "Player Name: Stefan"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	vbox.add_child(name_label)
	
	var level_label = Label.new()
	var level = XPManager.current_level if XPManager else 1
	level_label.text = "Player Level: %d" % level
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
	
	# Equipped items summary
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
