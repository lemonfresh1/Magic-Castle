# ProfileUI.gd - Profile interface showing player stats and equipped items
# Location: res://Pyramids/scripts/ui/profile/ProfileUI.gd
# Last Updated: Added direct emoji selection system [December 2024]
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
@onready var customize_tab: StyledPanel = $StyledPanel/MarginContainer/TabContainer/Customize
@onready var mini_profile_section: VBoxContainer = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection
@onready var preview_container: Control = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection/PreviewContainer
@onready var h_box_container: HBoxContainer = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection/HBoxContainer
@onready var button_slot_1: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection/HBoxContainer/ButtonSlot1
@onready var button_slot_2: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection/HBoxContainer/ButtonSlot2
@onready var button_slot_3: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection/HBoxContainer/ButtonSlot3
@onready var clear_display_btn: StyledButton = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/MiniProfileSection/ClearDisplayButton

# Customize tab - Emoji section
@onready var emoji_section: VBoxContainer = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection
@onready var emoji_slot_1: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot1
@onready var emoji_slot_2: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot2
@onready var emoji_slot_3: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot3
@onready var emoji_slot_4: Button = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection/EmojiSlotsContainer/HBoxContainer/EmojiSlot4
@onready var emoji_grid_scroll: ScrollContainer = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection/ScrollContainer
@onready var emoji_grid: GridContainer = $StyledPanel/MarginContainer/TabContainer/Customize/MarginContainer/ScrollContainer/HBoxContainer/EmojiSection/ScrollContainer/GridContainer

# Dynamically created components
var mini_profile_card = null  # Will be created dynamically like in PlayerSlot
var card_initialized: bool = false  # Prevent duplicate initialization

# Store references for easy iteration
var emoji_slot_buttons: Array[Button] = []
var current_edit_slot: int = -1  # Track which display slot is being edited

# Showcase display slots
var display_slot_buttons: Array[Button] = []
var showcase_cards: Array = []  # UnifiedItemCards at 50x50

# Emoji selection system
var selected_emoji_slot: int = -1  # -1 = none selected, 0-3 = slot index
var emoji_grid_buttons: Array = []  # Buttons in the grid

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	# Prevent duplicate initialization
	if card_initialized:
		_debug_log("WARNING: ProfileUI already initialized, skipping")
		return
	
	_debug_log("ProfileUI ready, setting up components")
	
	# Clean up any existing showcase cards first
	for card in showcase_cards:
		if is_instance_valid(card):
			card.queue_free()
	showcase_cards.clear()
	
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
		# Connect to showcase changes
		if not EquipmentManager.showcase_items_changed.is_connected(_update_showcase_slots):
			EquipmentManager.showcase_items_changed.connect(_update_showcase_slots)
	
	# Setup button arrays - with null checks
	var emoji_buttons: Array[Button] = []
	for btn in [emoji_slot_1, emoji_slot_2, emoji_slot_3, emoji_slot_4]:
		if btn:
			emoji_buttons.append(btn)
			# Make emoji slot buttons toggle mode
			btn.toggle_mode = true
	emoji_slot_buttons = emoji_buttons
	
	# Setup display slot buttons
	display_slot_buttons = [button_slot_1, button_slot_2, button_slot_3]
	
	# Connect button signals
	_connect_button_signals()
	
	# Setup showcase slots
	_setup_showcase_slots()
	
	# Setup emoji grid for direct selection
	_setup_emoji_grid()
	
	# Create MiniProfileCard immediately (like PlayerSlot does)
	_create_mini_profile_card()
	
	# Update showcase slots with current data
	_update_showcase_slots()
	
	# Mark as initialized
	card_initialized = true

func _setup_showcase_slots():
	"""Create UnifiedItemCard instances for each showcase button"""
	var buttons = [button_slot_1, button_slot_2, button_slot_3]
	
	for i in range(3):
		var button = buttons[i]
		if not button:
			continue
			
		# Create UnifiedItemCard instance
		var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
		if not ResourceLoader.exists(card_scene_path):
			_debug_log("UnifiedItemCard scene not found at: " + card_scene_path)
			continue
			
		var card_scene = load(card_scene_path)
		var card = card_scene.instantiate()
		
		# Use SHOWCASE preset to avoid ExpandedItemView popup behavior
		card.size_preset = card.SizePreset.SHOWCASE
		card.custom_minimum_size = Vector2(44, 44)
		card.size = Vector2(44, 44)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let button handle clicks
		
		# Add to button and center it
		button.add_child(card)
		card.set_anchors_preset(Control.PRESET_CENTER)
		card.position = Vector2(-22, -22)  # Half of 44x44 to center
		
		# Initially hidden
		card.visible = false
		
		# Store reference
		showcase_cards.append(card)
		
		# Connect button click
		if not button.pressed.is_connected(_on_showcase_slot_pressed):
			button.pressed.connect(_on_showcase_slot_pressed.bind(i))
		
		# Set button text alignment to center
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		_debug_log("Setup showcase slot %d with UnifiedItemCard" % i)

func _setup_emoji_grid():
	"""Setup the emoji grid using pre-existing buttons in the scene"""
	if not emoji_grid:
		_debug_log("emoji_grid (GridContainer) not found in scene")
		return
	
	# Clear our button array
	emoji_grid_buttons.clear()
	
	# Get all button children from the grid
	var all_buttons = []
	for child in emoji_grid.get_children():
		if child is Button:
			all_buttons.append(child)
			child.visible = false  # Hide all by default
	
	# Get owned emojis
	var owned_emojis = _get_owned_emojis()
	_debug_log("Setting up emoji grid with %d owned emojis" % owned_emojis.size())
	
	# Check if we have enough buttons
	if owned_emojis.size() > all_buttons.size():
		push_warning("[ProfileUI] NEED MORE EMOJI BUTTONS! Have %d buttons but %d emojis. Add more buttons to GridContainer in the scene!" % [all_buttons.size(), owned_emojis.size()])
	
	# Setup each owned emoji
	for i in range(owned_emojis.size()):
		if i >= all_buttons.size():
			break  # No more buttons available
		
		var btn = all_buttons[i]
		var emoji = owned_emojis[i]
		
		# Configure the button
		btn.visible = true
		btn.tooltip_text = emoji.display_name
		
		# Load emoji texture
		if emoji.texture_path and emoji.texture_path != "":
			var texture = load(emoji.texture_path)
			if texture:
				btn.icon = texture
				btn.expand_icon = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Store emoji id in metadata
		btn.set_meta("emoji_id", emoji.id)
		
		# Disconnect any previous signals
		if btn.pressed.is_connected(_on_emoji_grid_pressed):
			btn.pressed.disconnect(_on_emoji_grid_pressed)
		
		# Connect button press
		btn.pressed.connect(_on_emoji_grid_pressed.bind(emoji.id))
		
		# Add to our tracking array
		emoji_grid_buttons.append(btn)
	
	_debug_log("Configured %d emoji grid buttons" % emoji_grid_buttons.size())

func _get_owned_emojis() -> Array:
	"""Get all owned emoji items"""
	var owned = []
	
	if not ItemManager or not EquipmentManager:
		return owned
	
	var all_emojis = ItemManager.get_items_by_category("emoji")
	
	for emoji in all_emojis:
		if EquipmentManager.is_item_owned(emoji.id):
			owned.append(emoji)
	
	return owned

func _update_emoji_grid_state():
	pass

func _update_showcase_slots():
	"""Update the display of showcase slots"""
	if not EquipmentManager:
		return
		
	var showcased_items = EquipmentManager.get_showcased_items()
	_debug_log("Updating showcase slots with items: " + str(showcased_items))
	
	for i in range(3):
		var item_id = showcased_items[i] if i < showcased_items.size() else ""
		var button = display_slot_buttons[i] if i < display_slot_buttons.size() else null
		var card = showcase_cards[i] if i < showcase_cards.size() else null
		
		if not button:
			continue
			
		if item_id == "":
			# Empty slot - show "+" text
			button.text = "+"
			if card:
				card.visible = false
			_debug_log("Slot %d: empty (showing +)" % i)
		else:
			# Has item - show card
			button.text = ""
			if ItemManager:
				var item = ItemManager.get_item(item_id)
				if item and card:
					# Setup the card with the item
					if card.has_method("setup"):
						card.setup(item, card.DisplayMode.SHOWCASE)
					card.visible = true
					_debug_log("Slot %d: showing %s" % [i, item_id])
				else:
					# Item not found or card missing
					button.text = "?"
					if card:
						card.visible = false
					_debug_log("Slot %d: item not found (%s)" % [i, item_id])
			else:
				button.text = "?"
				if card:
					card.visible = false

func _on_showcase_slot_pressed(slot_index: int):
	"""Handle showcase slot button press"""
	var showcased_items = EquipmentManager.get_showcased_items() if EquipmentManager else []
	var current_item = showcased_items[slot_index] if slot_index < showcased_items.size() else ""
	
	_debug_log("Showcase slot %d pressed. Current item: %s" % [slot_index, current_item if current_item != "" else "empty"])
	
	# Store which slot is being edited
	current_edit_slot = slot_index
	
	# TODO: Open ItemSelectorPopup for this slot

func _create_mini_profile_card():
	"""Create and setup the MiniProfileCard dynamically (following PlayerSlot pattern)"""
	
	# Check if already exists
	if mini_profile_card != null and is_instance_valid(mini_profile_card):
		_debug_log("MiniProfileCard already exists, skipping creation")
		return
	
	# Try to find preview_container if not already set
	if not preview_container:
		preview_container = find_child("PreviewContainer", true, false)
		if not preview_container:
			push_error("PreviewContainer not found - cannot add MiniProfileCard!")
			return
	
	# FORCE CONTAINER SIZE to prevent expansion
	preview_container.custom_minimum_size = Vector2(200, 200)
	preview_container.size = Vector2(200, 200)
	preview_container.clip_contents = true  # Clip anything that goes over
	
	# CRITICAL FIX FROM SCRIPT 2: Ensure visibility before adding card
	preview_container.visible = true
	if mini_profile_section:
		mini_profile_section.visible = true
	
	# Clean up any existing MiniProfileCard in the container
	for child in preview_container.get_children():
		if child.name == "MiniProfileCard" or child.has_method("set_player_data"):
			_debug_log("Removing existing MiniProfileCard from container")
			child.queue_free()
	
	# Create MiniProfileCard dynamically like PlayerSlot does
	var card_scene_path = "res://Pyramids/scenes/ui/components/MiniProfileCard.tscn"
	
	if ResourceLoader.exists(card_scene_path):
		var scene = load(card_scene_path)
		mini_profile_card = scene.instantiate()
		_debug_log("Created MiniProfileCard from scene")
	else:
		push_error("MiniProfileCard scene not found at: " + card_scene_path)
		return
	
	# FORCE EXACT SIZE - no expansion allowed
	mini_profile_card.set_custom_minimum_size(Vector2(200, 200))
	mini_profile_card.size = Vector2(200, 200)
	mini_profile_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	
	# Prevent any size expansion
	mini_profile_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mini_profile_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Alternative: completely disable size flags
	mini_profile_card.set_h_size_flags(0)  
	mini_profile_card.set_v_size_flags(0)
	
	# Force clip contents to maintain size
	mini_profile_card.clip_contents = true
	
	# Make sure it's visible
	mini_profile_card.visible = true
	
	# Ensure mouse interaction is enabled for display items
	mini_profile_card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect signals
	if mini_profile_card.has_signal("display_item_clicked"):
		if not mini_profile_card.display_item_clicked.is_connected(_on_display_item_clicked):
			mini_profile_card.display_item_clicked.connect(_on_display_item_clicked)
			_debug_log("Connected to MiniProfileCard display_item_clicked signal")
	
	# Add to preview container
	preview_container.add_child(mini_profile_card)
	_debug_log("Added MiniProfileCard to preview container")
	
	# CRITICAL FIX FROM SCRIPT 2: Wait for it to be in tree then refresh
	await mini_profile_card.ready
	await get_tree().process_frame
	
	# Force refresh after everything is ready
	_refresh_mini_profile_card()

func _refresh_mini_profile_card():
	"""Deferred refresh of the mini profile card after it's in the tree"""
	if mini_profile_card and is_instance_valid(mini_profile_card):
		# Force a full redraw
		mini_profile_card.queue_redraw()
		
		# Call the debug refresh method if it exists (from Script 2)
		if mini_profile_card.has_method("debug_force_display_refresh"):
			mini_profile_card.debug_force_display_refresh()
			_debug_log("Called debug_force_display_refresh on MiniProfileCard")
		
		# Also ensure all child nodes are visible
		if mini_profile_card.has_method("_ensure_display_items_visible"):
			mini_profile_card._ensure_display_items_visible()
		
		# DEBUG: Check if display cards are clickable
		_debug_check_display_cards_clickability()
		
		_debug_log("MiniProfileCard refresh complete")

func _debug_check_display_cards_clickability():
	"""Debug function to check if display cards are properly set up for clicks"""
	if not mini_profile_card:
		_debug_log("ERROR: No mini_profile_card to check")
		return
	
	# Check if MiniProfileCard has display_cards property
	if "display_cards" in mini_profile_card:
		var display_cards = mini_profile_card.display_cards
		_debug_log("Found %d display cards in MiniProfileCard" % display_cards.size())
		
		for i in range(display_cards.size()):
			var card = display_cards[i]
			if card:
				_debug_log("  Card %d: %s" % [i, card.get_class()])
				_debug_log("    - Visible: %s" % card.visible)
				_debug_log("    - Mouse filter: %s" % card.mouse_filter)
				
				# Check if card has clicked signal
				if card.has_signal("clicked"):
					_debug_log("    - Has 'clicked' signal: YES")
					var connections = card.clicked.get_connections()
					_debug_log("    - Signal connections: %d" % connections.size())
				else:
					_debug_log("    - Has 'clicked' signal: NO - THIS IS THE PROBLEM!")
				
				# Try to make it clickable
				card.mouse_filter = Control.MOUSE_FILTER_PASS
				_debug_log("    - Set mouse_filter to PASS")
			else:
				_debug_log("  Card %d is null" % i)
	else:
		_debug_log("WARNING: MiniProfileCard doesn't have display_cards property")
		
		# Try to check display_container instead
		if "display_container" in mini_profile_card:
			var display_container = mini_profile_card.display_container
			if display_container:
				_debug_log("Found display_container with %d children" % display_container.get_child_count())
				for i in range(display_container.get_child_count()):
					var child = display_container.get_child(i)
					_debug_log("  Child %d: %s (visible: %s)" % [i, child.get_class(), child.visible])

func _connect_button_signals():
	"""Connect all button signals from scene nodes"""
	# Emoji slot buttons
	for i in range(emoji_slot_buttons.size()):
		var btn = emoji_slot_buttons[i]
		if btn and is_instance_valid(btn):
			if not btn.pressed.is_connected(_on_emoji_slot_pressed):
				btn.pressed.connect(_on_emoji_slot_pressed.bind(i))
				_debug_log("Connected emoji slot %d button" % i)
	
	# Showcase slot buttons (if not already connected in _setup_showcase_slots)
	for i in range(display_slot_buttons.size()):
		var btn = display_slot_buttons[i]
		if btn and is_instance_valid(btn):
			if not btn.pressed.is_connected(_on_showcase_slot_pressed):
				btn.pressed.connect(_on_showcase_slot_pressed.bind(i))
				_debug_log("Connected showcase slot %d button" % i)
	
	# Clear display button
	if clear_display_btn and is_instance_valid(clear_display_btn):
		if not clear_display_btn.pressed.is_connected(_on_clear_display_pressed):
			clear_display_btn.pressed.connect(_on_clear_display_pressed)

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
		
		# 3. Force refresh after data update (key fix from Script 2)
		call_deferred("_refresh_mini_profile_card")
	else:
		_debug_log("WARNING: MiniProfileCard is null or invalid!")
	
	# Update emoji slot buttons  
	_update_emoji_slots()
	
	# Update emoji grid state
	_update_emoji_grid_state()
	
	# Update showcase slots (now handled by signals, but call for initial update)
	_update_showcase_slots()

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
					if btn and is_instance_valid(btn):
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
			if btn and is_instance_valid(btn):
				btn.queue_redraw()

# === PUBLIC INTERFACE ===

func show_profile():
	"""Show the profile UI"""
	visible = true
	
	# Clean up old showcase cards before updating
	_cleanup_showcase_cards()
	
	# Recreate showcase slots
	_setup_showcase_slots()
	
	# Re-setup emoji grid with existing scene buttons
	_setup_emoji_grid()  # <-- Just call the setup again, don't create new buttons!
	
	# Update content (card should already exist from _ready)
	if mini_profile_card and is_instance_valid(mini_profile_card):
		_update_overview()
		_update_customize_tab()
	else:
		_debug_log("WARNING: MiniProfileCard not found when showing profile")

func hide_profile():
	"""Hide the profile UI"""
	visible = false
	
	# Clean up showcase cards to prevent tween issues
	_cleanup_showcase_cards()
	
	profile_closed.emit()

func _cleanup_showcase_cards():
	"""Properly clean up showcase cards to prevent tween/redraw issues"""
	for card in showcase_cards:
		if is_instance_valid(card):
			# Stop any running tweens on the card
			card.remove_from_group("_tween_processed")
			for child in card.get_children():
				if child is Tween:
					child.kill()
			card.queue_free()
	showcase_cards.clear()
	_debug_log("Cleaned up showcase cards")

# === PRIVATE HELPERS ===

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
		
		# Get display items (showcase items) - USE THE NEW FUNCTION
		data.display_items = EquipmentManager.get_showcased_items()
	
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
		#_update_customize_tab()
		
		# Update emoji grid if emoji was equipped
		if category == "emoji":
			_update_emoji_grid_state()

func _on_item_unequipped(item_id: String, category: String):
	"""Called when any item is unequipped via EquipmentManager"""
	# Only update if profile is visible to avoid unnecessary updates
	if visible:
		_update_overview()
		#_update_customize_tab()
		
		# Update emoji grid if emoji was unequipped
		if category == "emoji":
			_update_emoji_grid_state()

func _on_emoji_slot_pressed(slot_index: int):
	"""Handle emoji slot button press - now with direct selection"""
	_debug_log("Emoji slot %d pressed" % slot_index)
	
	# Toggle slot selection
	if selected_emoji_slot == slot_index:
		# Clicking same slot - deselect
		selected_emoji_slot = -1
		emoji_slot_buttons[slot_index].button_pressed = false
		_debug_log("Deselected slot %d" % slot_index)
	else:
		# Select new slot
		# Untoggle previous
		if selected_emoji_slot >= 0 and selected_emoji_slot < emoji_slot_buttons.size():
			emoji_slot_buttons[selected_emoji_slot].button_pressed = false
		
		# Toggle new
		selected_emoji_slot = slot_index
		emoji_slot_buttons[slot_index].button_pressed = true
		_debug_log("Selected slot %d for emoji placement" % slot_index)
	
	# Update visual state of emoji grid
	_update_emoji_grid_state()

func _on_emoji_grid_pressed(emoji_id: String):
	"""Handle clicking an emoji from the available grid"""
	_debug_log("Emoji grid pressed: %s" % emoji_id)
	
	if selected_emoji_slot < 0:
		# No slot selected - flash the slot buttons to hint
		_debug_log("No slot selected - select a slot first")
		# Optional: Flash slot buttons
		for btn in emoji_slot_buttons:
			if btn:
				var original_modulate = btn.modulate
				btn.modulate = Color(1.5, 1.5, 1.5)  # Bright flash
				await get_tree().create_timer(0.2).timeout
				btn.modulate = original_modulate
		return
	
	# Directly equip to selected slot
	_equip_emoji_to_slot(selected_emoji_slot, emoji_id)
	
	# Update the slot button display immediately
	_update_emoji_slots()
	
	# Update grid state to show new equipped status
	_update_emoji_grid_state()
	
	# Keep slot selected for quick changes
	# (uncomment next line to deselect after equipping)
	# selected_emoji_slot = -1
	# emoji_slot_buttons[selected_emoji_slot].button_pressed = false

func _equip_emoji_to_slot(slot: int, emoji_id: String):
	"""Helper to equip emoji at specific slot"""
	_debug_log("Equipping %s to slot %d" % [emoji_id, slot])
	
	if not EquipmentManager:
		return
	
	# Get current equipped emojis
	var current = EquipmentManager.get_equipped_emojis()
	while current.size() < 4:
		current.append("")
	
	# Check if emoji is already in another slot
	var existing_slot = current.find(emoji_id)
	if existing_slot >= 0 and existing_slot != slot:
		# Swap emojis between slots
		var old_emoji = current[slot]
		current[slot] = emoji_id
		current[existing_slot] = old_emoji
		_debug_log("Swapped emoji from slot %d to slot %d" % [existing_slot, slot])
	else:
		# Simple replacement
		var old_emoji = current[slot]
		current[slot] = emoji_id
		
		# Emit unequip for old emoji if it existed
		if old_emoji != "" and old_emoji != emoji_id:
			EquipmentManager.item_unequipped.emit(old_emoji, "emoji")
	
	# Update EquipmentManager
	EquipmentManager.save_data.equipped.emoji = current
	EquipmentManager.save_data_to_file()
	
	# Emit signals
	if emoji_id != "":
		EquipmentManager.item_equipped.emit(emoji_id, "emoji")
	EquipmentManager.equipment_changed.emit("emoji")
	
	_debug_log("Emoji equipped successfully")

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
	"""Handle click on display slot in MiniProfileCard - receives item_id from signal"""
	_debug_log("Display item clicked in MiniProfileCard: %s" % item_id)
	
	# The MiniProfileCard shows items from showcase array, not equipped items
	# So we need to find which slot this item is in the showcase array
	if not EquipmentManager:
		return
	
	var showcase_items = EquipmentManager.get_showcased_items()
	
	# Find which slot index this item_id corresponds to
	var slot_index = -1
	for i in range(showcase_items.size()):
		if showcase_items[i] == item_id:
			slot_index = i
			break
	
	if slot_index == -1:
		_debug_log("WARNING: Clicked item not found in showcase: %s" % item_id)
		return
	
	# Trigger the same handler as clicking the button
	_on_showcase_slot_pressed(slot_index)

func _debug_container_hierarchy():
	"""Debug function to check all parent containers for click blocking"""
	_debug_log("=== Checking container hierarchy for click blocking ===")
	
	# Check all the containers in the hierarchy
	var containers_to_check = [
		["styled_panel", styled_panel],
		["tab_container", tab_container],
		["customize_tab", customize_tab],
		["mini_profile_section", mini_profile_section],
		["preview_container", preview_container],
		["clear_display_btn", clear_display_btn]
	]
	
	for container_info in containers_to_check:
		var name = container_info[0]
		var node = container_info[1]
		if node:
			_debug_log("%s:" % name)
			_debug_log("  - Class: %s" % node.get_class())
			_debug_log("  - Visible: %s" % node.visible)
			_debug_log("  - Mouse filter: %s (0=STOP, 1=PASS, 2=IGNORE)" % node.mouse_filter)
			
			# Check if there's any Control node on top blocking clicks
			if node is Control:
				var rect = node.get_global_rect()
				_debug_log("  - Global rect: %s" % rect)
				_debug_log("  - Z-index: %s" % node.z_index)
		else:
			_debug_log("%s: NULL" % name)
	
	# Check for any overlapping controls
	if preview_container and mini_profile_card:
		var preview_rect = preview_container.get_global_rect()
		var card_rect = mini_profile_card.get_global_rect()
		_debug_log("Preview container rect: %s" % preview_rect)
		_debug_log("MiniProfileCard rect: %s" % card_rect)
		
		# Check if they actually overlap
		if not preview_rect.intersects(card_rect):
			_debug_log("WARNING: MiniProfileCard is outside preview_container bounds!")

func _on_clear_display_pressed():
	"""Clear all display items from mini profile"""
	_debug_log("Clear display button pressed!")
	if EquipmentManager:
		# Clear all showcase slots
		for i in range(3):
			EquipmentManager.update_showcased_item(i, "")
		_debug_log("Cleared all showcase items")
