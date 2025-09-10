# DisplaySelectorPopup.gd - Popup for selecting showcase display items
# Location: res://Pyramids/scripts/ui/popups/DisplaySelectorPopup.gd
# FIXED: Scroll preservation, achievement support, optimized updates

extends Control

# === SIGNALS ===
signal display_selected(slot_index: int, item_id: String)
signal popup_closed()

# === NODE REFERENCES ===
@onready var styled_panel: StyledPanel = $StyledPanel
@onready var title_label: Label = $StyledPanel/MarginContainer/VBoxContainer/HeaderContainer/VBoxContainer/TitleLabel
@onready var filter_button: OptionButton = $StyledPanel/MarginContainer/VBoxContainer/HeaderContainer/VBoxContainer/FilterButton
@onready var button_slot_1: Button = $StyledPanel/MarginContainer/VBoxContainer/HeaderContainer/SlotContainer/ButtonSlot1
@onready var button_slot_2: Button = $StyledPanel/MarginContainer/VBoxContainer/HeaderContainer/SlotContainer/ButtonSlot2
@onready var button_slot_3: Button = $StyledPanel/MarginContainer/VBoxContainer/HeaderContainer/SlotContainer/ButtonSlot3
@onready var scroll_container: ScrollContainer = $StyledPanel/MarginContainer/VBoxContainer/ScrollContainer
@onready var confirm_button: StyledButton = $StyledPanel/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var close_button: StyledButton = $StyledPanel/MarginContainer/VBoxContainer/ButtonContainer/CloseButton

# === PROPERTIES ===
var current_slot: int = 0
var selected_item_id: String = ""
var selected_item_card = null
var item_cards: Array = []
var unified_item_card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")

# Slot management
var display_slot_buttons: Array[Button] = []
var showcase_cards: Array = []

# Scroll preservation
var saved_scroll_position: float = 0.0
var needs_scroll_restore: bool = false

# Filter categories
const FILTER_OPTIONS = [
	{"id": "all", "name": "All Types"},
	{"id": "card_front", "name": "Card Fronts"},
	{"id": "card_back", "name": "Card Backs"},
	{"id": "board", "name": "Boards"},
	{"id": "emoji", "name": "Emojis"},
	{"id": "achievement", "name": "Achievements"},
	{"id": "mini_profile_card", "name": "Mini Profiles"}
]

var current_filter: String = "all"
var debug_enabled: bool = true

# === LIFECYCLE ===

func _ready():
	if not is_node_ready():
		return
	
	_debug_log("DisplaySelectorPopup ready")
	
	# Apply styling to StyledPanel
	if styled_panel and UIStyleManager:
		UIStyleManager.apply_panel_style(styled_panel, "display_selector_popup")
	
	# Setup arrays
	display_slot_buttons = [button_slot_1, button_slot_2, button_slot_3]
	
	# Setup filter button
	_setup_filter_button()
	
	# Setup showcase slots
	_setup_showcase_slots()
	
	# Connect signals
	if filter_button:
		filter_button.item_selected.connect(_on_filter_changed)
	
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
		_update_confirm_button_state()
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		close_button.text = "Close"
	
	# Populate on load - this prevents empty scene
	setup(0)

func _debug_log(message: String):
	if debug_enabled:
		print("[DisplaySelector] " + message)

# === SETUP ===

func setup(slot_index: int):
	"""Setup popup for specific slot"""
	current_slot = slot_index
	selected_item_id = ""
	selected_item_card = null
	
	_debug_log("Setting up for slot %d" % slot_index)
	
	# Update title
	if title_label:
		title_label.text = "Selecting Display %d" % (slot_index + 1)
	
	# Update slot button toggle states
	for i in range(display_slot_buttons.size()):
		var btn = display_slot_buttons[i]
		if btn:
			btn.button_pressed = (i == slot_index)
	
	# Reset filter
	current_filter = "all"
	if filter_button:
		filter_button.select(0)
	
	# Update showcase displays
	_update_showcase_slots()
	
	# Populate items without scroll reset
	_populate_items(false)
	
	# Update confirm button
	_update_confirm_button_state()

func _setup_filter_button():
	"""Setup filter dropdown options"""
	if not filter_button:
		_debug_log("Filter button not found!")
		return
	
	filter_button.clear()
	for option in FILTER_OPTIONS:
		filter_button.add_item(option.name)
	
	filter_button.select(0)
	
	# Apply UIStyleManager styling
	if UIStyleManager and UIStyleManager.has_method("style_filter_button"):
		var theme_color = Color("#a487ff")  # Purple theme
		UIStyleManager.style_filter_button(filter_button, theme_color)
		_debug_log("Applied UIStyleManager filter styling")
	
	_debug_log("Filter button setup with %d options" % FILTER_OPTIONS.size())

func _setup_showcase_slots():
	"""Create UnifiedItemCard instances for each showcase button - mouse disabled"""
	var buttons = [button_slot_1, button_slot_2, button_slot_3]
	
	for i in range(3):
		var button = buttons[i]
		if not button:
			continue
		
		# Make button toggle mode
		button.toggle_mode = true
		
		# Create UnifiedItemCard instance
		var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
		if not ResourceLoader.exists(card_scene_path):
			_debug_log("UnifiedItemCard scene not found")
			continue
		
		var card_scene = load(card_scene_path)
		var card = card_scene.instantiate()
		
		# Use SHOWCASE preset and disable ALL mouse interaction
		card.size_preset = card.SizePreset.SHOWCASE
		card.custom_minimum_size = Vector2(44, 44)
		card.size = Vector2(44, 44)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_process_input(false)  # Disable input processing
		card.set_process_unhandled_input(false)
		
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
		
		# Set button text alignment
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		_debug_log("Setup showcase slot %d with UnifiedItemCard (mouse disabled)" % i)

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
		
		# Clean up any existing emoji displays first
		for child in button.get_children():
			if child.name == "EmojiDisplay":
				child.queue_free()
		
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
					# SPECIAL HANDLING FOR EMOJIS
					if item.category == UnifiedItemData.Category.EMOJI:
						# Hide the UnifiedItemCard
						card.visible = false
						
						# Create simple emoji display
						var emoji_rect = TextureRect.new()
						emoji_rect.name = "EmojiDisplay"
						emoji_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
						emoji_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						emoji_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
						
						if item.texture_path and ResourceLoader.exists(item.texture_path):
							emoji_rect.texture = load(item.texture_path)
						
						emoji_rect.custom_minimum_size = Vector2(36, 36)
						emoji_rect.size = Vector2(36, 36)
						emoji_rect.set_anchors_preset(Control.PRESET_CENTER)
						emoji_rect.position = Vector2(-18, -18)
						
						button.add_child(emoji_rect)
						_debug_log("Slot %d: showing emoji %s" % [i, item_id])
					else:
						# Regular item handling
						# Reset card size first
						card.custom_minimum_size = Vector2(44, 44)
						card.size = Vector2(44, 44)
						card.position = Vector2(-22, -22)
						
						# Setup the card with the item
						if card.has_method("setup"):
							card.setup(item, card.DisplayMode.SHOWCASE if "DisplayMode" in card else 0)
							# Ensure mouse is disabled
							card.mouse_filter = Control.MOUSE_FILTER_IGNORE
							card.set_process_input(false)
						card.visible = true
						_debug_log("Slot %d: showing %s" % [i, item_id])
				else:
					# Check if it's an achievement
					if not item and _is_achievement(item_id):
						_setup_achievement_slot_card(card, item_id)
					# Check if it's an emoji without ItemManager lookup
					elif "emoji_" in item_id:
						_setup_emoji_direct(button, item_id)
					else:
						button.text = "?"
						if card:
							card.visible = false
						_debug_log("Slot %d: item not found (%s)" % [i, item_id])
			else:
				button.text = "?"
				if card:
					card.visible = false

func _is_achievement(item_id: String) -> bool:
	"""Check if an item_id is an achievement"""
	if not AchievementManager:
		return false
	var base_achievements = AchievementManager.get_all_base_achievements()
	return item_id in base_achievements

func _is_owned_or_achievement(item_id: String) -> bool:
	"""Check if item is owned through EquipmentManager OR is an unlocked achievement"""
	# First check normal ownership
	if EquipmentManager and EquipmentManager.is_item_owned(item_id):
		return true
	
	# Then check if it's an unlocked achievement
	if AchievementManager and _is_achievement(item_id):
		var highest_tier = AchievementManager.get_unlocked_tier(item_id)
		return highest_tier > 0
	
	return false

func _setup_achievement_slot_card(card, achievement_id: String):
	"""Setup a showcase card for an achievement using fake item approach"""
	if not card:
		return
	
	# CHECK IF IT'S AN EMOJI FIRST (in case it gets here)
	if "emoji_" in achievement_id:
		# Get the button (card's parent)
		var button = card.get_parent()
		if button:
			_setup_emoji_direct(button, achievement_id)
			card.visible = false
		return
	
	# ORIGINAL ACHIEVEMENT HANDLING
	if not AchievementManager:
		return
	
	# Create fake item for achievement
	var fake_item = UnifiedItemData.new()
	fake_item.id = achievement_id
	fake_item.display_name = achievement_id.capitalize().replace("_", " ")
	
	# Get highest tier for icon
	var highest_tier = AchievementManager.get_unlocked_tier(achievement_id)
	if highest_tier > 0:
		var tiered_id = "%s_tier_%d" % [achievement_id, highest_tier]
		var achievement = AchievementManager.get_achievement(tiered_id)
		if achievement:
			# Try with white_icons_cut path first, then fallback
			var icon_filename = achievement.get("icon", "")
			var icon_paths = [
				"res://Pyramids/assets/icons/achievements/white_icons_cut/%s" % icon_filename
			]
			
			for path in icon_paths:
				if ResourceLoader.exists(path):
					fake_item.texture_path = path
					fake_item.icon_path = path
					_debug_log("Found achievement icon at: %s" % path)
					break
	
	# Reset card size for achievements in showcase
	card.custom_minimum_size = Vector2(44, 44)
	card.size = Vector2(44, 44)
	card.position = Vector2(-22, -22)
	
	# Setup with SHOWCASE mode and ensure mouse is disabled
	if card.has_method("setup"):
		card.setup(fake_item, card.DisplayMode.SHOWCASE)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_process_input(false)
	card.visible = true
	_debug_log("Setup achievement showcase card: %s" % achievement_id)

func _setup_emoji_direct(button: Button, emoji_id: String):
	"""Setup emoji display directly on button without UnifiedItemCard"""
	# Clean up any existing emoji displays
	for child in button.get_children():
		if child.name == "EmojiDisplay":
			child.queue_free()
	
	# Hide the card if it exists
	for child in button.get_children():
		if child is PanelContainer:  # This is the UnifiedItemCard
			child.visible = false
	
	# Create simple emoji display
	var emoji_rect = TextureRect.new()
	emoji_rect.name = "EmojiDisplay"
	emoji_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	emoji_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emoji_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Try to get emoji texture
	if ItemManager:
		var emoji_item = ItemManager.get_item(emoji_id)
		if emoji_item and emoji_item.texture_path and ResourceLoader.exists(emoji_item.texture_path):
			emoji_rect.texture = load(emoji_item.texture_path)
		else:
			# Fallback - try direct path
			var direct_path = "res://Pyramids/assets/icons/emoji/%s.png" % emoji_id
			if ResourceLoader.exists(direct_path):
				emoji_rect.texture = load(direct_path)
	else:
		# No ItemManager - try direct path
		var direct_path = "res://Pyramids/assets/icons/emoji/%s.png" % emoji_id
		if ResourceLoader.exists(direct_path):
			emoji_rect.texture = load(direct_path)
	
	emoji_rect.custom_minimum_size = Vector2(36, 36)
	emoji_rect.size = Vector2(36, 36)
	emoji_rect.set_anchors_preset(Control.PRESET_CENTER)
	emoji_rect.position = Vector2(-18, -18)
	
	button.add_child(emoji_rect)
	button.text = ""  # Clear any text
	_debug_log("Setup emoji display: %s" % emoji_id)

func _on_showcase_slot_pressed(slot_index: int):
	"""Handle showcase slot button press - switch to editing that slot WITHOUT scroll reset"""
	_debug_log("Showcase slot %d pressed" % slot_index)
	
	# Save current scroll position before any updates
	_save_scroll_position()
	
	# Update current slot
	current_slot = slot_index
	
	# Update title
	if title_label:
		title_label.text = "Selecting Display %d" % (slot_index + 1)
	
	# Update toggle states
	for i in range(display_slot_buttons.size()):
		var btn = display_slot_buttons[i]
		if btn:
			btn.button_pressed = (i == slot_index)
	
	# Clear current selection
	if selected_item_card and is_instance_valid(selected_item_card):
		_clear_selection_visual(selected_item_card)
	
	selected_item_id = ""
	selected_item_card = null
	_update_confirm_button_state()
	
	# Just update selection states, don't rebuild
	_update_item_selection_states()

# === POPULATE ITEMS ===

func _save_scroll_position():
	"""Save current scroll position"""
	if scroll_container:
		saved_scroll_position = scroll_container.get_v_scroll_bar().value
		_debug_log("Saved scroll position: %f" % saved_scroll_position)

func _restore_scroll_position():
	"""Restore saved scroll position after rebuild"""
	if not scroll_container:
		return
		
	# Wait for next frame to ensure content is laid out
	await get_tree().process_frame
	
	if scroll_container and scroll_container.get_v_scroll_bar():
		scroll_container.get_v_scroll_bar().value = saved_scroll_position
		_debug_log("Restored scroll position to: %f" % saved_scroll_position)

func _populate_items(preserve_scroll: bool = true):
	"""Populate the scroll container with items"""
	if not scroll_container:
		_debug_log("ScrollContainer not found!")
		return
	
	# Save scroll position if requested
	if preserve_scroll:
		_save_scroll_position()
	
	_debug_log("Populating items with filter: %s" % current_filter)
	
	# Clear existing content
	for child in scroll_container.get_children():
		child.queue_free()
	item_cards.clear()
	
	# Wait for cleanup
	await get_tree().process_frame
	
	# Create main container
	var container = VBoxContainer.new()
	container.name = "FlowContainer"
	container.add_theme_constant_override("separation", 15)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(container)
	
	# Get items by type
	var items_by_type = _get_items_by_type()
	_debug_log("Found item types: %s" % str(items_by_type.keys()))
	
	# Sort types alphabetically
	var sorted_types = items_by_type.keys()
	sorted_types.sort()
	
	var total_items_added = 0
	
	for type_key in sorted_types:
		# Skip if filtered out
		if current_filter != "all" and type_key != current_filter:
			continue
		
		var items = items_by_type[type_key]
		if items.is_empty():
			continue
		
		_debug_log("Adding %d items for type: %s" % [items.size(), type_key])
		
		# Add type header
		var header = Label.new()
		header.text = _get_type_display_name(type_key)
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color("#111827"))
		container.add_child(header)
		
		# Create row container
		var current_row = null
		var current_columns_used = 0
		var MAX_COLUMNS = 6
		
		# Sort items by display name
		items.sort_custom(func(a, b):
			var name_a = a.get("display_name", "") if a is Dictionary else (a.display_name if a else "")
			var name_b = b.get("display_name", "") if b is Dictionary else (b.display_name if b else "")
			return name_a < name_b
		)
		
		for item in items:
			var columns_needed = _get_columns_for_item(item, type_key)
			
			# Create new row if needed
			if current_row == null or current_columns_used + columns_needed > MAX_COLUMNS:
				current_row = HBoxContainer.new()
				current_row.add_theme_constant_override("separation", 10)
				current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				container.add_child(current_row)
				current_columns_used = 0
			
			# Create card
			var card = _create_display_card(item, type_key)
			if card:
				current_row.add_child(card)
				item_cards.append(card)
				current_columns_used += columns_needed
				total_items_added += 1
		
		# Add spacer
		if current_row and current_columns_used < MAX_COLUMNS:
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_child(spacer)
	
	_debug_log("Total items added: %d" % total_items_added)
	
	# Restore scroll position if requested
	if preserve_scroll:
		_restore_scroll_position()

func _update_item_selection_states():
	"""Update just the selection states of existing cards without rebuilding"""
	_debug_log("Updating selection states for slot %d" % current_slot)
	
	# Get current showcase items
	var current_showcase = []
	if EquipmentManager:
		current_showcase = EquipmentManager.get_showcased_items()
	
	# Update each card's visual state
	for card in item_cards:
		if not is_instance_valid(card):
			continue
			
		var item_id = card.get_meta("item_id", "")
		if item_id == "":
			continue
		
		# Check if item is in current slot
		var is_in_current_slot = false
		if current_slot >= 0 and current_slot < current_showcase.size():
			is_in_current_slot = (current_showcase[current_slot] == item_id)
		
		# Update visual state
		if is_in_current_slot:
			# Item is already in this slot - dim it
			card.modulate = Color(0.9, 0.9, 0.9, 0.7)
		else:
			# Reset to normal
			card.modulate = Color.WHITE

func _get_items_by_type() -> Dictionary:
	"""Get all available items organized by type"""
	var items_by_type = {}
	
	# Get owned items
	if EquipmentManager and ItemManager:
		var owned_items = EquipmentManager.get_owned_items()
		_debug_log("Found %d owned items" % owned_items.size())
		
		for item_id in owned_items:
			var item = ItemManager.get_item(item_id)
			if not item:
				continue
			
			var category_key = item.get_category_name()
			if not items_by_type.has(category_key):
				items_by_type[category_key] = []
			items_by_type[category_key].append(item)
	
	# Get achievements  
	if AchievementManager:
		var achievements = []
		var base_achievements = AchievementManager.get_all_base_achievements()
		_debug_log("Found %d base achievements" % base_achievements.size())
		
		for base_id in base_achievements:
			var highest_tier = AchievementManager.get_unlocked_tier(base_id)
			
			if highest_tier > 0:
				var achievement_id = "%s_tier_%d" % [base_id, highest_tier]
				var achievement = AchievementManager.get_achievement(achievement_id)
				if achievement:
					# Build the icon path with fallback
					var icon_filename = achievement.get("icon", "")
					var icon_paths = [
						"res://Pyramids/assets/icons/achievements/white_icons_cut/%s" % icon_filename,
						"res://Pyramids/assets/icons/achievements/%s" % icon_filename
					]
					
					var final_icon_path = ""
					for path in icon_paths:
						if ResourceLoader.exists(path):
							final_icon_path = path
							break
					
					if final_icon_path == "":
						_debug_log("Warning: No icon found for achievement %s" % base_id)
					
					achievements.append({
						"id": base_id,
						"display_name": achievement.get("name", "Achievement"),
						"icon_path": final_icon_path,
						"tier": highest_tier,
						"is_achievement": true
					})
		
		_debug_log("Added %d unlocked achievements" % achievements.size())
		if not achievements.is_empty():
			items_by_type["achievement"] = achievements
	
	return items_by_type

func _create_display_card(item, type_key: String):
	"""Create a card for display item"""
	var card = null
	
	if type_key == "achievement":
		# Create custom achievement card
		card = _create_custom_achievement_card(item)
	else:
		# Regular items using UnifiedItemCard
		if item is UnifiedItemData:
			card = unified_item_card_scene.instantiate()
			card.setup(item, UnifiedItemCard.DisplayMode.SELECTION)
			
			# Set size based on type - FIX FOR EMOJIS
			if type_key == "emoji":
				# Smaller size for emojis to fit better
				card.custom_minimum_size = Vector2(44, 44)
			elif type_key in ["board", "mini_profile_card"]:
				card.custom_minimum_size = Vector2(156, 100)
			else:
				card.custom_minimum_size = Vector2(72, 100)
			
			# Store metadata
			var item_id = item.id
			card.set_meta("item_id", item_id)
			card.set_meta("item_data", item)
			
			_debug_log("Creating card for: %s (type: %s)" % [item_id, type_key])
			
			# Connect to UnifiedItemCard's clicked signal
			if card.has_signal("clicked"):
				card.clicked.connect(_on_unified_card_clicked.bind(card))
				_debug_log("  ✓ Connected to UnifiedItemCard's 'clicked' signal")
			
			# Check if already in slot
			if EquipmentManager:
				var current_showcase = EquipmentManager.get_showcased_items()
				if current_slot >= 0 and current_slot < current_showcase.size():
					if current_showcase[current_slot] == item_id:
						card.modulate = Color(0.9, 0.9, 0.9, 0.7)
						_debug_log("  Item already in current slot - dimmed")
	
	return card

func _create_custom_achievement_card(achievement_data: Dictionary) -> Control:
	"""Create custom achievement card with proper sizing and font"""
	var card_container = PanelContainer.new()
	# Match regular item card size
	card_container.custom_minimum_size = Vector2(90, 128)
	card_container.size = Vector2(90, 128)
	
	# Store metadata
	var item_id = achievement_data.get("id", "")
	card_container.set_meta("item_id", item_id)
	card_container.set_meta("item_data", achievement_data)
	card_container.set_meta("is_achievement", true)
	
	# Style based on tier with UIStyleManager colors
	var tier = achievement_data.get("tier", 1)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Fully transparent like regular cards
	
	# Map tiers to rarity colors using UIStyleManager
	var border_color = Color.WHITE
	if UIStyleManager:
		match tier:
			1: border_color = UIStyleManager.get_rarity_color("common")      # Gray
			2: border_color = UIStyleManager.get_rarity_color("uncommon")    # Green
			3: border_color = UIStyleManager.get_rarity_color("rare")        # Blue
			4: border_color = UIStyleManager.get_rarity_color("epic")        # Purple
			5: border_color = UIStyleManager.get_rarity_color("legendary")   # Gold/Yellow
			_: border_color = UIStyleManager.get_rarity_color("mythic")      # Red (for future tiers)
	else:
		# Fallback colors if UIStyleManager not available
		match tier:
			1: border_color = Color("#6B7280")  # Gray
			2: border_color = Color("#10B981")  # Green
			3: border_color = Color("#3B82F6")  # Blue
			4: border_color = Color("#9333EA")  # Purple
			5: border_color = Color("#F59E0B")  # Gold
			_: border_color = Color("#EF4444")  # Red
	
	style.border_color = border_color
	style.set_border_width_all(3 if tier >= 2 else 2)
	style.set_corner_radius_all(0)  # Square corners to match items
	card_container.add_theme_stylebox_override("panel", style)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card_container.add_child(vbox)
	
	# Icon container
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(80, 80)
	vbox.add_child(icon_container)
	icon_container.position = Vector2(5, 6)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(60, 60)
	icon.size = Vector2(60, 60)
	icon_container.add_child(icon)
	icon.position = Vector2(12, 6)  # Center in container
	
	# Load icon texture
	var icon_path = achievement_data.get("icon_path", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
		_debug_log("Loaded achievement icon: %s" % icon_path)
	
	# Name label with padding
	var text_margin = MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left", 2)
	text_margin.add_theme_constant_override("margin_right", 2)
	vbox.add_child(text_margin)
	
	var name_label = Label.new()
	name_label.text = achievement_data.get("display_name", "Achievement")
	name_label.add_theme_font_size_override("font_size", 10)  # Readable font
	name_label.add_theme_color_override("font_color", Color("#111827"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_margin.add_child(name_label)
	
	# Make clickable
	card_container.gui_input.connect(_on_achievement_card_input.bind(card_container))
	card_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	_debug_log("Created custom achievement card for: %s" % item_id)
	
	return card_container

func _on_achievement_card_input(event: InputEvent, card: Control):
	"""Handle achievement card clicks"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item_id = card.get_meta("item_id", "")
			_debug_log("Achievement card clicked: %s" % item_id)
			_on_card_selected(card)

func _on_unified_card_clicked(item_data: UnifiedItemData, card: UnifiedItemCard):
	"""Handle UnifiedItemCard's clicked signal"""
	_debug_log("UnifiedItemCard clicked via signal: %s" % item_data.id)
	_on_card_selected(card)

func _on_card_selected(card: Control):
	"""Handle any card selection"""
	var item_id = card.get_meta("item_id", "")
	_debug_log("Card selected: %s" % item_id)
	
	# Deselect previous
	if selected_item_card and is_instance_valid(selected_item_card):
		_clear_selection_visual(selected_item_card)
	
	# Select new
	selected_item_card = card
	selected_item_id = item_id
	
	# Show selection
	_show_selection_visual(card)
	
	# Update confirm button
	_update_confirm_button_state()

func _show_selection_visual(card: Control):
	"""Show selection visual on card"""
	# For UnifiedItemCard, use equipped badge
	if card.has_method("get_node_or_null"):
		var badge = card.get_node_or_null("OverlayContainer/EquippedBadge")
		if badge:
			badge.visible = true
			badge.modulate = Color("#10B981")  # Green
	
	# Highlight the card
	card.modulate = Color(1.1, 1.1, 1.1)
	
	# Add border effect for achievement cards
	if card.get_meta("is_achievement", false):
		var style = card.get_theme_stylebox("panel")
		if style and style is StyleBoxFlat:
			var new_style = style.duplicate()
			new_style.border_color = Color("#10B981")
			new_style.set_border_width_all(4)
			card.add_theme_stylebox_override("panel", new_style)

func _clear_selection_visual(card: Control):
	"""Clear selection visual from card"""
	# For UnifiedItemCard
	if card.has_method("get_node_or_null"):
		var badge = card.get_node_or_null("OverlayContainer/EquippedBadge")
		if badge:
			var item_id = card.get_meta("item_id", "")
			# Only hide if not actually equipped
			if not EquipmentManager or not EquipmentManager.is_item_equipped(item_id):
				badge.visible = false
	
	# Reset modulation
	card.modulate = Color.WHITE
	
	# Reset achievement card border
	if card.get_meta("is_achievement", false):
		var tier = 1
		var item_data = card.get_meta("item_data", {})
		if item_data is Dictionary:
			tier = item_data.get("tier", 1)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)  # Transparent
		
		# Restore original tier color
		match tier:
			1: style.border_color = Color("#CD7F32")
			2: style.border_color = Color("#C0C0C0")
			3: style.border_color = Color("#FFD700")
			_: style.border_color = Color("#B9F2FF")
		
		style.set_border_width_all(3 if tier >= 2 else 2)
		style.set_corner_radius_all(0)
		card.add_theme_stylebox_override("panel", style)

func _get_columns_for_item(item, type_key: String) -> int:
	"""Get columns needed for item"""
	if type_key in ["board", "mini_profile_card"]:
		return 2
	return 1

func _get_type_display_name(type_key: String) -> String:
	"""Get display name for type"""
	match type_key:
		"card_front": return "Card Fronts"
		"card_back": return "Card Backs"
		"board": return "Boards"
		"mini_profile_card": return "Mini Profile Cards"
		"emoji": return "Emojis"
		"achievement": return "Achievements"
		"avatar": return "Avatars"
		"frame": return "Frames"
		_: return type_key.capitalize().replace("_", " ")

func _update_confirm_button_state():
	"""Update confirm button state"""
	if not confirm_button:
		return
	
	if selected_item_id == "":
		confirm_button.text = "Choosing..."
		confirm_button.modulate = Color(0.5, 0.5, 0.5)
		confirm_button.disabled = true
	else:
		confirm_button.text = "Confirm"
		confirm_button.modulate = Color(0.5, 1.0, 0.5)
		confirm_button.disabled = false

func _on_confirm_pressed():
	"""Handle confirm button - saves and updates showcase slots"""
	_debug_log("Confirm pressed: %s for slot %d" % [selected_item_id, current_slot])
	
	if selected_item_id == "" or current_slot < 0:
		return
	
	# Save scroll position before any updates
	_save_scroll_position()
	
	# Use normal EquipmentManager method for everything (items AND achievements)
	if EquipmentManager:
		EquipmentManager.set_showcase_item(current_slot, selected_item_id)
		_debug_log("Updated showcase slot %d with %s" % [current_slot, selected_item_id])
	
	# Update the showcase display immediately
	_update_showcase_slots()
	
	# Clear selection visual
	if selected_item_card and is_instance_valid(selected_item_card):
		_clear_selection_visual(selected_item_card)
	
	# Flash confirm button green for feedback
	var original_modulate = confirm_button.modulate
	confirm_button.modulate = Color(0.2, 1.0, 0.2)
	await get_tree().create_timer(0.3).timeout
	confirm_button.modulate = original_modulate
	
	# Emit signal (ProfileUI will also update)
	display_selected.emit(current_slot, selected_item_id)
	
	# Reset selection state
	selected_item_id = ""
	selected_item_card = null
	_update_confirm_button_state()
	
	# Update selection states instead of rebuilding
	_update_item_selection_states()
	
	# Restore scroll position
	_restore_scroll_position()

func _on_close_pressed():
	"""Handle close button"""
	_debug_log("Close pressed - closing popup")
	
	# Clear selection
	selected_item_id = ""
	selected_item_card = null
	
	# Hide popup
	hide()
	popup_closed.emit()

func _on_filter_changed(index: int):
	"""Handle filter change - this one needs full rebuild"""
	if index >= 0 and index < FILTER_OPTIONS.size():
		current_filter = FILTER_OPTIONS[index].id
		_debug_log("Filter changed to: %s" % current_filter)
		# Filter changes need full rebuild, but preserve scroll
		_populate_items(true)

# === PUBLIC API ===

func show_selector():
	"""Show the popup"""
	visible = true
	if get_parent() == get_tree().root:
		position = (get_viewport_rect().size - size) / 2

func hide_selector():
	"""Hide the popup"""
	visible = false
	popup_closed.emit()
