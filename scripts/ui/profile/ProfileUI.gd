# ProfileUI.gd - Profile interface showing player stats and equipped items
# Location: res://Pyramids/scripts/ui/profile/ProfileUI.gd
# Last Updated: Fixed duplicate MiniProfileCard, proper cleanup [December 2024]
#
# Purpose: Main profile interface for viewing and customizing player profile
# Dependencies: EquipmentManager, XPManager, StatsManager, SettingsSystem, ItemManager
# Use Cases: Player opens profile to view stats, change name, customize mini profile display
# Flow: 1) Load player data → 2) Display in tabs → 3) Handle customization interactions
# Notes: MiniProfileCard created dynamically in code, emojis loaded from ItemManager
#
# ProfileUI handles:
# - Displaying player stats (level, games played)
# - Player name editing
# - Showing equipped items summary (view only)
# - Mini profile card customization (display items + emojis)
# - Player overview

extends Control

# === SIGNALS ===
signal profile_closed

# === DEBUG FLAGS ===
var debug_enabled: bool = true
var global_debug: bool = true

# === NODE REFERENCES ===
# Root structure
@onready var styled_panel: StyledPanel = $StyledPanel
@onready var tab_container: TabContainer = $StyledPanel/MarginContainer/TabContainer

# Overview tab nodes (if they exist in scene)
@onready var overview_tab = $StyledPanel/MarginContainer/TabContainer/Overview
@onready var overview_content = $StyledPanel/MarginContainer/TabContainer/Overview/MarginContainer/ScrollContainer/VBoxContainer

# Customize tab - containers only (MiniProfileCard will be created dynamically)
@onready var customize_tab = $StyledPanel/MarginContainer/TabContainer/Customize
@onready var mini_profile_section = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/MiniProfileSection
@onready var preview_container = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/MiniProfileSection/PreviewContainer
@onready var clear_display_btn = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/MiniProfileSection/ClearDisplayButton

# Customize tab - Emoji section
@onready var emoji_slot_1 = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot1
@onready var emoji_slot_2 = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot2
@onready var emoji_slot_3 = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot3
@onready var emoji_slot_4 = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot4
@onready var clear_emojis_btn = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/EmojiSection/ClearEmojisButton

# Dynamically created components
var mini_profile_card = null  # Will be created dynamically like in PlayerSlot

# Store references for easy iteration
var emoji_slot_buttons: Array[Button] = []
var current_edit_slot: int = -1  # Track which display slot is being edited

# Track initialization state
static var initialized_instances = []

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	# Clean up any duplicate MiniProfileCards from previous instances
	_cleanup_duplicate_cards()
	
	# Check if this instance was already initialized
	if self in initialized_instances:
		_debug_log("WARNING: ProfileUI instance already initialized, skipping")
		return
	
	initialized_instances.append(self)
	
	_debug_log("ProfileUI ready, setting up components")
	
	# Debug: Check what ItemManager has for emojis
	if ItemManager:
		var test_emoji = ItemManager.get_item("emoji_cool")
		if test_emoji:
			_debug_log("Found emoji_cool in ItemManager: " + test_emoji.display_name)
			_debug_log("  Texture path: " + str(test_emoji.texture_path))
			_debug_log("  Icon path: " + str(test_emoji.icon_path))
		else:
			_debug_log("emoji_cool NOT found in ItemManager")
		
		var all_emojis = ItemManager.get_items_by_category("emoji")
		_debug_log("Total emojis in ItemManager: " + str(all_emojis.size()))
	
	# Debug: Check what EquipmentManager has
	if EquipmentManager:
		var equipped = EquipmentManager.get_equipped_items()
		_debug_log("Current equipped items from EquipmentManager: " + str(equipped))
		var emojis = EquipmentManager.get_equipped_emojis()
		_debug_log("Current equipped emojis: " + str(emojis))
	
	# Connect to managers
	if EquipmentManager:
		if not EquipmentManager.item_equipped.is_connected(_on_item_equipped):
			EquipmentManager.item_equipped.connect(_on_item_equipped)
		if not EquipmentManager.item_unequipped.is_connected(_on_item_unequipped):
			EquipmentManager.item_unequipped.connect(_on_item_unequipped)
	
	# Setup button arrays - with null checks
	var emoji_buttons: Array[Button] = []
	for btn in [emoji_slot_1, emoji_slot_2, emoji_slot_3, emoji_slot_4]:
		if btn:
			emoji_buttons.append(btn)
	emoji_slot_buttons = emoji_buttons
	
	# Connect button signals
	_connect_button_signals()
	
	# DON'T create MiniProfileCard here - wait for show_profile()

func _cleanup_duplicate_cards():
	"""Clean up any duplicate MiniProfileCards from previous instances"""
	if preview_container:
		# Remove all existing MiniProfileCards
		for child in preview_container.get_children():
			if child.name == "MiniProfileCard" or child.has_method("set_player_data"):
				_debug_log("Removing duplicate MiniProfileCard: " + child.name)
				child.queue_free()

func _create_mini_profile_card():
	"""Create and setup the MiniProfileCard dynamically (following PlayerSlot pattern)"""
	
	# Clean up any existing cards first
	_cleanup_duplicate_cards()
	
	# Reset our reference
	mini_profile_card = null
	
	# Try to find preview_container if not already set
	if not preview_container:
		# Try different possible paths
		var possible_paths = [
			"StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/VBoxContainer/MiniProfileSection/PreviewContainer",
			"StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollableContainer/VBoxContainer/MiniProfileSection/PreviewContainer",
		]
		
		for path in possible_paths:
			var node = get_node_or_null(NodePath(path))
			if node:
				preview_container = node
				_debug_log("Found preview_container at: " + path)
				break
		
		# If still not found, try to find it recursively
		if not preview_container:
			var mini_profile_section = find_child("MiniProfileSection", true, false)
			if mini_profile_section:
				preview_container = mini_profile_section.find_child("PreviewContainer", true, false)
				if preview_container:
					_debug_log("Found preview_container via recursive search")
	
	if not preview_container:
		push_error("PreviewContainer not found - cannot add MiniProfileCard!")
		return
	
	# CRITICAL: Ensure the entire hierarchy is visible before creating the card
	preview_container.visible = true
	if mini_profile_section:
		mini_profile_section.visible = true
	
	# Make sure the Customize tab is active
	if tab_container:
		tab_container.current_tab = 1  # Switch to Customize tab
		
		# Wait for tab switch to complete
		await get_tree().process_frame
	
	# Create MiniProfileCard dynamically like PlayerSlot does
	var card_scene_path = "res://Pyramids/scenes/ui/components/MiniProfileCard.tscn"
	
	if ResourceLoader.exists(card_scene_path):
		var scene = load(card_scene_path)
		mini_profile_card = scene.instantiate()
		_debug_log("Created MiniProfileCard from scene")
	else:
		# Try to create from script if scene doesn't exist
		var card_script_path = "res://Pyramids/scripts/ui/components/MiniProfileCard.gd"
		if ResourceLoader.exists(card_script_path):
			var script = load(card_script_path)
			mini_profile_card = PanelContainer.new()
			mini_profile_card.set_script(script)
			_debug_log("Created MiniProfileCard from script")
		else:
			push_error("MiniProfileCard not found (neither scene nor script)")
			return
	
	# Configure size
	mini_profile_card.custom_minimum_size = Vector2(200, 200)
	mini_profile_card.size = Vector2(200, 200)
	
	# Make sure it's visible
	mini_profile_card.visible = true
	
	# Connect signals
	if mini_profile_card.has_signal("display_item_clicked"):
		mini_profile_card.display_item_clicked.connect(_on_display_item_clicked)
		_debug_log("Connected to MiniProfileCard display_item_clicked signal")
	
	# Add to preview container
	if preview_container:
		preview_container.add_child(mini_profile_card)
		_debug_log("Added MiniProfileCard to preview container")
		
		# Wait for the card to be fully in the scene tree
		await mini_profile_card.ready
		
		# Give it another frame to ensure all children are ready
		await get_tree().process_frame
		
		# Force a full redraw of the card and its children
		mini_profile_card.queue_redraw()
		
		_debug_log("MiniProfileCard fully ready and refreshed")

func _connect_button_signals():
	"""Connect all button signals from scene nodes"""
	# Emoji slot buttons
	for i in range(emoji_slot_buttons.size()):
		var btn = emoji_slot_buttons[i]
		if btn and is_instance_valid(btn):
			if not btn.pressed.is_connected(_on_emoji_slot_pressed):
				btn.pressed.connect(_on_emoji_slot_pressed.bind(i))
				_debug_log("Connected emoji slot %d button" % i)
	
	# Clear buttons
	if clear_display_btn and is_instance_valid(clear_display_btn):
		if not clear_display_btn.pressed.is_connected(_on_clear_display_pressed):
			clear_display_btn.pressed.connect(_on_clear_display_pressed)
	
	if clear_emojis_btn and is_instance_valid(clear_emojis_btn):
		if not clear_emojis_btn.pressed.is_connected(_on_clear_emojis_pressed):
			clear_emojis_btn.pressed.connect(_on_clear_emojis_pressed)

# === UPDATE FUNCTIONS ===

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

func _update_customize_tab():
	"""Update customize tab with current data - following PlayerSlot's exact flow"""
	# Update MiniProfileCard preview
	if mini_profile_card and is_instance_valid(mini_profile_card):
		# EXACTLY like PlayerSlot does it:
		# 1. Apply theme FIRST (if equipped)
		if EquipmentManager:
			var equipped = EquipmentManager.get_equipped_items()
			var theme_id = equipped.get("mini_profile_card", "")
			if theme_id != "" and mini_profile_card.has_method("apply_mini_profile_theme"):
				mini_profile_card.apply_mini_profile_theme(theme_id)
				_debug_log("Applied mini profile theme: " + theme_id)
		
		# 2. THEN set player data (exactly like PlayerSlot's set_player)
		var player_data = _get_current_player_data()
		if mini_profile_card.has_method("set_player_data"):
			mini_profile_card.set_player_data(player_data)
			_debug_log("Updated MiniProfileCard with player data")
			_debug_log("Player data sent: " + str(player_data))
		else:
			_debug_log("WARNING: MiniProfileCard doesn't have set_player_data method!")
	else:
		_debug_log("WARNING: MiniProfileCard is null or invalid!")
	
	# Update emoji slot buttons  
	_update_emoji_slots()

func _update_emoji_slots():
	"""Update the emoji slot buttons with equipped emojis - handling StyledButton"""
	if not EquipmentManager:
		_debug_log("EquipmentManager not available")
		return
	
	if not ItemManager:
		_debug_log("ItemManager not available")
		return
	
	# Get equipped emojis directly from EquipmentManager
	var equipped_emojis = EquipmentManager.get_equipped_emojis()
	_debug_log("Equipped emojis from EquipmentManager: " + str(equipped_emojis))
	
	# Ensure we have 4 slots
	while equipped_emojis.size() < 4:
		equipped_emojis.append("")
	
	# Update each slot button
	for i in range(min(4, emoji_slot_buttons.size())):
		var btn = emoji_slot_buttons[i]
		if not btn or not is_instance_valid(btn):
			continue
		
		# Debug button type
		_debug_log("Button %d class: %s" % [i, btn.get_class()])
		
		var emoji_id = equipped_emojis[i] if i < equipped_emojis.size() else ""
		
		if emoji_id != "":
			# Get the emoji item from ItemManager
			var emoji_item = ItemManager.get_item(emoji_id)
			if emoji_item:
				var texture = null
				
				# Try to get texture from the item
				if emoji_item.texture_path and emoji_item.texture_path != "":
					texture = load(emoji_item.texture_path)
					_debug_log("Loading texture from texture_path: " + emoji_item.texture_path)
				elif emoji_item.icon_path and emoji_item.icon_path != "":
					texture = load(emoji_item.icon_path)
					_debug_log("Loading texture from icon_path: " + emoji_item.icon_path)
				else:
					_debug_log("No texture or icon path for emoji: " + emoji_id)
				
				if texture:
					# Clear text first
					btn.text = ""
					
					# Try different methods for StyledButton
					if btn.has_method("set_icon"):
						btn.set_icon(texture)
						_debug_log("Used set_icon method")
					else:
						btn.icon = texture
						_debug_log("Set icon property directly")
					
					# Try to set expand_icon (just set it, don't check)
					btn.expand_icon = true
					
					# Try to set icon_alignment (Button class has this)
					if btn.get_class() == "Button" or btn is Button:
						btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
					
					# For TextureButton compatibility
					if btn.get_class() == "TextureButton":
						btn.texture_normal = texture
						_debug_log("Also set texture_normal for TextureButton")
					
					# Remove text margins
					btn.add_theme_constant_override("h_separation", 0)
					btn.tooltip_text = emoji_item.display_name
					
					# Force visual update
					btn.queue_redraw()
					
					_debug_log("Set emoji %s on slot %d (button class: %s)" % [emoji_id, i, btn.get_class()])
				else:
					_debug_log("Failed to load texture for emoji: " + emoji_id)
					btn.icon = null
					btn.text = "?"
					btn.tooltip_text = "Missing texture: " + emoji_id
			else:
				_debug_log("Emoji item not found in ItemManager: " + emoji_id)
				btn.icon = null
				btn.text = "?"
				btn.tooltip_text = "Unknown emoji: " + emoji_id
		else:
			# Empty slot
			btn.icon = null
			btn.text = "+"
			if btn.get_class() == "TextureButton":
				btn.texture_normal = null
			btn.expand_icon = false
			btn.tooltip_text = "Click to select emoji"
			btn.queue_redraw()

# === PUBLIC INTERFACE ===

func show_profile():
	"""Show the profile UI"""
	visible = true
	
	# Create MiniProfileCard if it doesn't exist
	if not mini_profile_card or not is_instance_valid(mini_profile_card):
		_debug_log("Creating MiniProfileCard on show")
		await _create_mini_profile_card()
	
	# Update content
	_update_overview()
	_update_customize_tab()
	
	# Add delay to allow textures to load properly
	await get_tree().create_timer(0.2).timeout
	_debug_log("Profile fully shown")

func hide_profile():
	"""Hide the profile UI"""
	visible = false
	profile_closed.emit()

# === PRIVATE HELPERS ===

func _get_available_emojis() -> Array:
	"""Get all available emoji items from ItemManager for popup selector"""
	if not ItemManager:
		_debug_log("ItemManager not available for getting emojis")
		return []
	
	# Get all emoji items from ItemManager
	var emojis = ItemManager.get_items_by_category("emoji")
	_debug_log("Available emojis from ItemManager: " + str(emojis.size()))
	
	# Debug print first few
	for i in range(min(3, emojis.size())):
		var emoji = emojis[i]
		_debug_log("  Emoji %d: %s (texture: %s)" % [i, emoji.id, emoji.texture_path])
	
	return emojis

func _get_current_player_data() -> Dictionary:
	"""Get current player data for mini profile preview (following PlayerSlot format)"""
	var data = {
		"id": "player_self",
		"name": SettingsSystem.player_name if SettingsSystem else "Player",
		"level": XPManager.current_level if XPManager else 1,
		"prestige": 0,  # TODO: Get from prestige system when available
		"stats": {},
		"frame_id": "",
		"equipped": {},
		"display_items": [],
		"is_ready": false,
		"is_host": false,
		"is_empty": false
	}
	
	# Get equipped items - this is crucial for MiniProfileCard display
	if EquipmentManager:
		data.equipped = EquipmentManager.get_equipped_items()
		
		# Get frame specifically if equipped
		if data.equipped.has("frame"):
			data.frame_id = data.equipped.frame
		
		# Get display items (showcase items)
		if EquipmentManager.save_data.has("equipped"):
			var equipped = EquipmentManager.save_data.equipped
			if equipped.has("mini_profile_card_showcased_items"):
				data.display_items = equipped.mini_profile_card_showcased_items
			else:
				# Default to empty if not set
				data.display_items = ["", "", ""]
		else:
			data.display_items = ["", "", ""]
	
	# Get real stats from StatsManager
	if StatsManager:
		var stats = StatsManager.get_total_stats()
		var win_rate = 0.0
		if stats.games_played > 0:
			# Assuming wins are tracked in stats
			win_rate = float(stats.get("wins", 0)) / float(stats.games_played)
		
		data.stats = {
			"games": stats.games_played,
			"win_rate": win_rate,
			"average_rank": stats.get("average_rank", 2.5)
		}
	else:
		# Default stats if no StatsManager
		data.stats = {
			"games": 0,
			"win_rate": 0.0,
			"average_rank": 0.0
		}
	
	_debug_log("Player data for MiniProfileCard: " + str(data))
	return data

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[ProfileUI] %s" % message)

# === SIGNAL HANDLERS ===

func _on_item_equipped(item_id: String, category: String):
	"""Called when any item is equipped via EquipmentManager"""
	# Only update if profile is visible to avoid unnecessary updates
	if visible:
		_update_overview()
		_update_customize_tab()

func _on_item_unequipped(item_id: String, category: String):
	"""Called when any item is unequipped via EquipmentManager"""
	# Only update if profile is visible to avoid unnecessary updates
	if visible:
		_update_overview()
		_update_customize_tab()

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

func _on_display_item_clicked(item_id: String):
	"""Handle click on display slot in MiniProfileCard"""
	_debug_log("Display item clicked: " + item_id)  # Debug to see if clicks work
	
	if not EquipmentManager:
		return
		
	# Get current showcase items
	var showcase_items = []
	if EquipmentManager.save_data.has("equipped") and EquipmentManager.save_data.equipped.has("mini_profile_card_showcased_items"):
		showcase_items = EquipmentManager.save_data.equipped.mini_profile_card_showcased_items.duplicate()
	
	# Ensure we have 3 slots
	while showcase_items.size() < 3:
		showcase_items.append("")
	
	# Find which slot was clicked
	var slot_index = -1
	for i in range(showcase_items.size()):
		if showcase_items[i] == item_id:
			slot_index = i
			break
	
	# If item not found, find first empty slot
	if slot_index == -1:
		for i in range(showcase_items.size()):
			if showcase_items[i] == "":
				slot_index = i
				break
	
	# If still no slot, use first slot
	if slot_index == -1:
		slot_index = 0
	
	current_edit_slot = slot_index
	_debug_log("Display slot %d clicked (current item: %s) - TODO: Show ItemSelectorPopup" % [slot_index, item_id])
	# TODO: Show ItemSelectorPopup for this slot

func _on_emoji_slot_pressed(slot_index: int):
	"""Handle emoji slot button press"""
	_debug_log("Emoji slot %d pressed - TODO: Show EmojiSelectorPopup" % slot_index)
	# TODO: Show EmojiSelectorPopup for this slot

func _on_clear_display_pressed():
	"""Clear all display items from mini profile"""
	_debug_log("Clearing display items")
	if EquipmentManager:
		# Clear the showcase items
		if not EquipmentManager.save_data.has("equipped"):
			EquipmentManager.save_data.equipped = {}
		EquipmentManager.save_data.equipped.mini_profile_card_showcased_items = ["", "", ""]
		EquipmentManager.save_data_changed.emit()
		_update_customize_tab()

func _on_clear_emojis_pressed():
	"""Clear all equipped emojis"""
	_debug_log("Clearing all emojis")
	if EquipmentManager:
		# Clear all emoji slots
		if not EquipmentManager.save_data.has("equipped"):
			EquipmentManager.save_data.equipped = {}
		EquipmentManager.save_data.equipped.emojis = ["", "", "", ""]
		EquipmentManager.save_data_changed.emit()
		_update_emoji_slots()

# === CLEANUP ===

func _exit_tree():
	"""Clean up when leaving the tree"""
	# Remove from initialized instances
	if self in initialized_instances:
		initialized_instances.erase(self)
