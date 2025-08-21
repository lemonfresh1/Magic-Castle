# TestUnifiedItemCards.gd - Comprehensive test with scrolling and explanations
# Location: res://Pyramids/scripts/tests/TestUnifiedItemCards.gd
# Tests: All sizes, reward types, states, and animations

extends Control

var card_scene: PackedScene
var animation_timers: Dictionary = {}  # Track animation timing for each card

func _ready():
	# Wait for all systems to initialize
	await get_tree().process_frame
	
	# Load the UnifiedItemCard scene FIRST
	card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
	if not card_scene:
		push_error("UnifiedItemCard.tscn not found!")
		return
	
	# === RUN DIAGNOSTICS FIRST ===
	print("\n🔬 RUNNING ARCTIC ITEM DIAGNOSTICS...")
	await _run_arctic_diagnostics()
	print("🔬 DIAGNOSTICS COMPLETE - Starting normal tests...\n")
	
	print("\n" + "============================================================")
	print("UNIFIED ITEM CARD TEST - WHAT TO LOOK FOR:")
	print("============================================================")
	print("1. ANIMATIONS: Green 'CLAIMABLE' cards should pulse every 5 seconds")
	print("2. LOCK CHAINS: Red 'LOCKED' cards show animated chain overlay")
	print("3. DIMMING: Gray 'CLAIMED' cards are 50% transparent")
	print("4. SIZES: Cards should match their labeled dimensions")
	print("5. CLICK: Any card should open an expanded view popup")
	print("============================================================\n")
	
	# Reset equipment states for consistent testing
	_setup_test_states()
	
	# Create main scroll container - SIMPLE SETUP
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	# Use anchors to fill most of the screen (leave room at bottom for instructions)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.set_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -60  # Leave 60px at bottom for instructions
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_top = 10
	
	# Enable vertical scrolling
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	add_child(scroll)
	
	# Main container inside scroll - let it grow naturally
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.add_theme_constant_override("separation", 15)
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Don't set any vertical size constraints - let it grow!
	scroll.add_child(main_container)
	
	# Add top margin
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 10)
	main_container.add_child(top_margin)
	
	# === SECTION 1: SIZE PRESETS ===
	_add_section_header(main_container, "📏 SIZE PRESETS", 
		"These show all 5 size configurations.")
	_test_size_presets(main_container)
	
	# Add separator
	main_container.add_child(HSeparator.new())
	
	# === SECTION 2: REWARD TYPES ===
	_add_section_header(main_container, "💰 BATTLE PASS REWARDS", 
		"Raw dictionaries for battle pass.")
	_test_reward_types(main_container)
	
	# Add separator
	main_container.add_child(HSeparator.new())
	
	# === SECTION 3: ANIMATION STATES ===
	_add_section_header(main_container, "🎬 ANIMATION STATES", 
		"Green cards animate every 5 seconds.")
	_test_reward_states(main_container)
	
	# Add separator
	main_container.add_child(HSeparator.new())
	
	# === SECTION 4: SHOP vs INVENTORY ===
	_add_section_header(main_container, "🛍️ DISPLAY MODES", 
		"Shop shows prices, Inventory shows ownership.")
	_test_display_modes(main_container)
	
	# Add separator
	main_container.add_child(HSeparator.new())
	
	# === SECTION 5: ITEM STATES ===
	_add_section_header(main_container, "🔒 OWNERSHIP STATES", 
		"Price tag = Shop | Box = Owned | Check = Equipped | Chains = Locked")
	_test_item_states(main_container)
	
	# Add separator
	main_container.add_child(HSeparator.new())
	
	# === SECTION 6: EXISTING PROJECT ITEMS ===
	_add_section_header(main_container, "🎨 EXISTING ITEMS", 
		"Actual items from your project files.")
	_test_existing_items(main_container)
	
	# Add bottom margin - IMPORTANT for scrolling past last item
	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 200)  # Big margin so you can scroll past
	main_container.add_child(bottom_margin)
	
	# Instructions panel at bottom (fixed position)
	var instructions = Panel.new()
	instructions.name = "InstructionsPanel"
	instructions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instructions.offset_top = -50
	instructions.offset_bottom = 0
	instructions.z_index = 10
	
	# Simple background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	instructions.add_theme_stylebox_override("panel", style)
	
	add_child(instructions)
	
	var info = Label.new()
	info.text = "⏱️ Animations every 5s | 🖱️ Click cards for popup | ⌨️ R=Reload, S=Status | Scroll to see all sections"
	info.add_theme_font_size_override("font_size", 12)
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_child(info)
	
	# Debug print to verify setup
	await get_tree().process_frame
	print("Window size: ", get_window().size)
	print("Scroll size: ", scroll.size)
	print("Content height: ", main_container.get_combined_minimum_size().y)
	print("Scrollable: ", main_container.get_combined_minimum_size().y > scroll.size.y)

func _add_section_header(parent: Node, title: String, description: String):
	"""Add a section header with title and description"""
	var vbox = VBoxContainer.new()
	parent.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color("#FFB75A"))
	vbox.add_child(title_label)
	
	# Description
	if description != "":
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color("#AAAAAA"))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

func _test_size_presets(parent: Node):
	"""Test all size presets with Arctic Aurora items"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	parent.add_child(container)
	
	# Use Arctic Aurora items for each size preset
	var sizes = [
		# MINI_DISPLAY - 2 examples
		{"preset": UnifiedItemCard.SizePreset.MINI_DISPLAY, "label": "MINI_DISPLAY\n50×50px", "item": "arctic_aurora_front"},
		{"preset": UnifiedItemCard.SizePreset.MINI_DISPLAY, "label": "MINI_DISPLAY\n50×50px", "item": "arctic_aurora_board"},
		
		# PASS_REWARD - 2 examples  
		{"preset": UnifiedItemCard.SizePreset.PASS_REWARD, "label": "PASS_REWARD\n86×86px", "item": "arctic_aurora_back"},
		{"preset": UnifiedItemCard.SizePreset.PASS_REWARD, "label": "PASS_REWARD\n86×86px", "item": "arctic_aurora_board"},
		
		# SHOWCASE - 2 examples
		{"preset": UnifiedItemCard.SizePreset.SHOWCASE, "label": "SHOWCASE\n60×80px", "item": "arctic_aurora_front"},
		{"preset": UnifiedItemCard.SizePreset.SHOWCASE, "label": "SHOWCASE\n60×80px", "item": "arctic_aurora_back"},
		
		# INVENTORY - Portrait
		{"preset": UnifiedItemCard.SizePreset.INVENTORY, "label": "INVENTORY\n90×126px", "item": "arctic_aurora_front"},
		
		# SHOP - Portrait and Landscape
		{"preset": UnifiedItemCard.SizePreset.SHOP, "label": "SHOP Portrait\n90×126px", "item": "arctic_aurora_back"},
		{"preset": UnifiedItemCard.SizePreset.SHOP, "label": "SHOP Landscape\n192×126px", "item": "arctic_aurora_board"}
	]
	
	for size_data in sizes:
		var card = _create_item_card_with_preset(size_data.item, UnifiedItemCard.DisplayMode.SHOWCASE, size_data.preset)
		if card:
			# ADD WHITE BACKGROUND for mini display and pass reward
			if size_data.preset in [UnifiedItemCard.SizePreset.MINI_DISPLAY, UnifiedItemCard.SizePreset.PASS_REWARD]:
				_add_card_with_label(container, card, size_data.label)
			else:
				_add_card_with_label(container, card, size_data.label)
		else:
			# Fallback if Arctic item not found
			var fallback = _create_item_card("card_classic", UnifiedItemCard.DisplayMode.SHOWCASE)
			if fallback:
				fallback.size_preset = size_data.preset
				fallback._apply_size_preset()
				if size_data.preset in [UnifiedItemCard.SizePreset.MINI_DISPLAY, UnifiedItemCard.SizePreset.PASS_REWARD]:
					_add_card_with_white_background(container, fallback, size_data.label + "\n(fallback)")
				else:
					_add_card_with_label(container, fallback, size_data.label + "\n(fallback)")

func _add_card_with_white_background(parent: Node, card: UnifiedItemCard, label_text: String):
	"""Add a card with white background and label below it"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(vbox)
	
	# Create white background container
	var bg_container = PanelContainer.new()
	var white_style = StyleBoxFlat.new()
	white_style.bg_color = Color.WHITE
	white_style.set_corner_radius_all(4)
	white_style.set_content_margin_all(4)  # Small padding around card
	bg_container.add_theme_stylebox_override("panel", white_style)
	
	# Set container size to be slightly larger than card
	bg_container.custom_minimum_size = card.size + Vector2(8, 8)  # 4px padding on each side
	
	vbox.add_child(bg_container)
	
	# Add the card to the white background
	bg_container.add_child(card)
	
	# Center the card in the background
	card.position = Vector2(4, 4)  # Account for padding
	
	# Add label
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#CCCCCC"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = bg_container.size.x
	vbox.add_child(label)

func _create_item_card_with_preset(item_id: String, mode: UnifiedItemCard.DisplayMode, preset: UnifiedItemCard.SizePreset) -> UnifiedItemCard:
	"""Create a card with specific size preset"""
	var card = _create_item_card(item_id, mode)
	if card:
		card.size_preset = preset
		card._apply_size_preset()
	return card


func _test_reward_types(parent: Node):
	"""Test different reward dictionary types"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	parent.add_child(container)
	
	# Different reward amounts and types
	var rewards = [
		{"data": {"stars": 50}, "label": "50 Stars\n(Common reward)"},
		{"data": {"stars": 100}, "label": "100 Stars\n(Standard)"},
		{"data": {"stars": 250}, "label": "250 Stars\n(Rare)"},
		{"data": {"stars": 500}, "label": "500 Stars\n(Epic)"},
		{"data": {"stars": 1000}, "label": "1000 Stars\n(Legendary)"},
		{"data": {"xp": 100}, "label": "100 XP\n(Experience)"},
		{"data": {"xp": 500}, "label": "500 XP\n(Bonus XP)"},
		{"data": {"cosmetic_type": "emoji", "cosmetic_id": "fire"}, "label": "Fire Emoji\n(Cosmetic)"},
		{"data": {"cosmetic_type": "card_skin", "cosmetic_id": "golden"}, "label": "Golden Cards\n(Skin)"}
	]
	
	for i in range(rewards.size()):
		var reward = rewards[i]
		var card = card_scene.instantiate()
		card.setup_from_dict(reward.data, UnifiedItemCard.SizePreset.PASS_REWARD)
		# Make first 3 claimable (animated), rest locked or claimed
		if i < 3:
			card.set_reward_state(true, false)  # Claimable - WILL ANIMATE
		elif i < 6:
			card.set_reward_state(false, false)  # Locked
		else:
			card.set_reward_state(true, true)  # Claimed
		
		# Add with white background since these are PASS_REWARD preset
		_add_card_with_white_background(container, card, reward.label)

func _test_reward_states(parent: Node):
	"""Test the three animation states for rewards"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 30)
	parent.add_child(container)
	
	# Create identical rewards in different states to show the difference
	var test_sets = [
		{"type": "stars", "data": {"stars": 150}, "name": "Stars"},
		{"type": "xp", "data": {"xp": 300}, "name": "XP"},
		{"type": "cosmetic", "data": {"cosmetic_type": "emoji", "cosmetic_id": "gem"}, "name": "Cosmetic"}
	]
	
	for test_set in test_sets:
		var state_container = VBoxContainer.new()
		state_container.add_theme_constant_override("separation", 10)
		container.add_child(state_container)
		
		# Label for this set
		var set_label = Label.new()
		set_label.text = test_set.name
		set_label.add_theme_font_size_override("font_size", 14)
		set_label.add_theme_color_override("font_color", Color("#FFB75A"))
		state_container.add_child(set_label)
		
		# CLAIMABLE - Should animate (with white background)
		var claimable = card_scene.instantiate()
		claimable.setup_from_dict(test_set.data, UnifiedItemCard.SizePreset.PASS_REWARD)
		claimable.set_reward_state(true, false)
		_add_card_with_white_background(state_container, claimable, "✨ CLAIMABLE\n(Animates)")
		animation_timers[claimable] = 0.0
		
		# LOCKED - Should be static (with white background)
		var locked = card_scene.instantiate()
		locked.setup_from_dict(test_set.data, UnifiedItemCard.SizePreset.PASS_REWARD)
		locked.set_reward_state(false, false)
		_add_card_with_white_background(state_container, locked, "🔒 LOCKED\n(Static)")
		
		# CLAIMED - Should be dimmed (with white background)
		var claimed = card_scene.instantiate()
		claimed.setup_from_dict(test_set.data, UnifiedItemCard.SizePreset.PASS_REWARD)
		claimed.set_reward_state(true, true)
		_add_card_with_white_background(state_container, claimed, "✓ CLAIMED\n(Dimmed)")


func _test_display_modes(parent: Node):
	"""Test different display modes with Arctic items"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	parent.add_child(container)
	
	# Same item in different modes using Arctic
	var modes = [
		{"mode": UnifiedItemCard.DisplayMode.SHOP, "label": "SHOP MODE\n(Shows price)", "item": "arctic_aurora_front"},
		{"mode": UnifiedItemCard.DisplayMode.INVENTORY, "label": "INVENTORY\n(No price)", "item": "arctic_aurora_back"},
		{"mode": UnifiedItemCard.DisplayMode.PROFILE, "label": "PROFILE\n(Display only)", "item": "arctic_aurora_front"},
		{"mode": UnifiedItemCard.DisplayMode.SHOWCASE, "label": "SHOWCASE\n(Compact)", "item": "arctic_aurora_board"},
		{"mode": UnifiedItemCard.DisplayMode.SELECTION, "label": "SELECTION\n(Choosing)", "item": "arctic_aurora_back"}
	]
	
	for mode_data in modes:
		var card = _create_item_card(mode_data.item, mode_data.mode)
		if not card:
			# Fallback to default items if Arctic not found
			card = _create_item_card("card_classic", mode_data.mode)
		if card:
			_add_card_with_label(container, card, mode_data.label)

func _test_item_states(parent: Node):
	"""Test owned/equipped/locked states"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	parent.add_child(container)
	
	# Different ownership states
	var states = [
		{"item": "card_mystic", "mode": UnifiedItemCard.DisplayMode.SHOP, "label": "NOT OWNED\n🏷️ For Sale"},
		{"item": "card_neon", "mode": UnifiedItemCard.DisplayMode.INVENTORY, "label": "OWNED\n📦 Available"},
		{"item": "card_classic", "mode": UnifiedItemCard.DisplayMode.INVENTORY, "label": "EQUIPPED\n✅ In Use"},
		{"item": "locked_epic", "mode": UnifiedItemCard.DisplayMode.SHOP, "label": "LOCKED\n🔒 Level 15", "locked": true}
	]
	
	for state_data in states:
		var card
		if state_data.get("locked", false):
			card = _create_locked_card(state_data.item, 15)
		else:
			card = _create_item_card(state_data.item, state_data.mode)
		
		if card:
			_add_card_with_label(container, card, state_data.label)

func _create_item_card(item_id: String, mode: UnifiedItemCard.DisplayMode) -> UnifiedItemCard:
	"""Create a card from an item ID"""
	if not ItemManager:
		push_error("ItemManager not available")
		return null
	
	var item_data = ItemManager.get_item(item_id)
	if not item_data:
		# Create a test item if it doesn't exist
		item_data = UnifiedItemData.new()
		item_data.id = item_id
		item_data.display_name = item_id.capitalize().replace("_", " ")
		item_data.description = "Test item for " + item_id
		item_data.category = UnifiedItemData.Category.CARD_FRONT if "card" in item_id else UnifiedItemData.Category.BOARD
		
		# Set different rarities for visual variety
		if "epic" in item_id:
			item_data.rarity = UnifiedItemData.Rarity.EPIC
			item_data.base_price = 500
		elif "mystic" in item_id or "golden" in item_id:
			item_data.rarity = UnifiedItemData.Rarity.LEGENDARY
			item_data.base_price = 1000
		elif "neon" in item_id:
			item_data.rarity = UnifiedItemData.Rarity.RARE
			item_data.base_price = 250
		else:
			item_data.rarity = UnifiedItemData.Rarity.COMMON
			item_data.base_price = 100
		
		item_data.is_purchasable = true
	
	var card = card_scene.instantiate()
	card.setup(item_data, mode)
	
	# Connect click for testing
	if card.has_signal("expanded_view_requested"):
		card.expanded_view_requested.connect(func(): 
			print("Expanded view requested for: %s" % item_data.display_name)
		)
	
	return card

func _create_locked_card(item_id: String, level_req: int) -> UnifiedItemCard:
	"""Create a locked card with level requirement"""
	var item_data = UnifiedItemData.new()
	item_data.id = item_id
	item_data.display_name = "Epic Reward"
	item_data.description = "Requires level %d to unlock" % level_req
	item_data.category = UnifiedItemData.Category.CARD_FRONT
	item_data.rarity = UnifiedItemData.Rarity.EPIC
	item_data.unlock_level = level_req
	item_data.base_price = 750
	item_data.is_purchasable = false  # Can't buy locked items
	
	var card = card_scene.instantiate()
	card.setup(item_data, UnifiedItemCard.DisplayMode.SHOP)
	
	# Force locked state
	card.is_locked = true
	card.is_owned = false
	card._update_lock_state()
	
	return card

func _add_card_with_label(parent: Node, card: UnifiedItemCard, label_text: String, label_color: Color = Color("#CCCCCC")):
	"""Add a card with a label below it"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(vbox)
	
	# Add the card
	vbox.add_child(card)
	
	# Add label
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", label_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = card.size.x
	vbox.add_child(label)

func _process(delta):
	"""Update animation timer display"""
	var timer_display = get_node_or_null("TimerDisplay")
	if timer_display:
		# Find any animated card to check timer
		for card in animation_timers:
			if is_instance_valid(card) and card.animation_enabled:
				var time_until_next = card.animation_interval - card.animation_timer
				timer_display.text = "Next animation: %.1fs" % time_until_next
				break

func _setup_test_states():
	"""Setup specific equipment states for testing"""
	if not EquipmentManager:
		return
	
	print("Setting up test states...")
	
	# Ensure some items are owned for testing
	# card_classic - owned and equipped
	if not EquipmentManager.is_item_owned("card_classic"):
		EquipmentManager.grant_item("card_classic", "test")
	EquipmentManager.equip_item("card_classic")
	
	# card_neon - owned but NOT equipped
	if not EquipmentManager.is_item_owned("card_neon"):
		EquipmentManager.grant_item("card_neon", "test")
	if EquipmentManager.is_item_equipped("card_neon"):
		EquipmentManager.unequip_item("card_neon")
	
	# board_green - owned
	if not EquipmentManager.is_item_owned("board_green"):
		EquipmentManager.grant_item("board_green", "test")
	
	print("Test states configured")

# Keyboard shortcuts for testing
func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				# Refresh the test
				get_tree().reload_current_scene()
			KEY_S:
				# Print status
				print("\n============================================================")
				print("STATUS CHECK:")
				if EquipmentManager:
					EquipmentManager.debug_status()
				if ItemManager:
					print("ItemManager: %d items loaded" % ItemManager.all_items.size())
				print("============================================================\n")
			KEY_A:
				# Add test stars
				if StarManager:
					StarManager.add_stars(1000, "test")
					print("Added 1000 stars (balance: %d)" % StarManager.get_balance())
			KEY_T:
				# Trigger animations manually
				print("Manually triggering animations...")
				for card in animation_timers:
					if is_instance_valid(card) and card.animation_enabled:
						card._play_animation()

func _check_existing_items():
	"""Check what items actually exist in ItemManager"""
	if not ItemManager:
		push_error("ItemManager not available!")
		return
	
	print("\n=== CHECKING EXISTING ITEMS ===")
	print("Total items loaded: %d" % ItemManager.all_items.size())
	
	# Check for Arctic Aurora items specifically
	var arctic_ids = [
		"arctic_aurora_board",
		"arctic_aurora_back", 
		"arctic_aurora_front",
		"arcticauroraboard",  # Try without underscores
		"arcticauroracardback",
		"arcticauroracardfront",
		"ArcticAuroraBoard",  # Try with capitals
		"ArcticAuroraCardBack",
		"ArcticAuroraCardFront"
	]
	
	print("\nSearching for Arctic Aurora items:")
	for item_id in arctic_ids:
		var item = ItemManager.get_item(item_id)
		if item:
			print("✓ Found: %s (%s)" % [item.id, item.display_name])
			print("  - Category: %s" % item.get_category_name())
			print("  - Procedural: %s" % item.is_procedural)
			print("  - Script: %s" % item.procedural_script_path)
			if item.is_animated:
				print("  - Animated: true")
	
	# Search for any items containing "arctic" or "aurora"
	print("\nAll Arctic/Aurora items in database:")
	for item_id in ItemManager.all_items:
		if "arctic" in item_id.to_lower() or "aurora" in item_id.to_lower():
			var item = ItemManager.get_item(item_id)
			print("  - %s: %s (%s)" % [item_id, item.display_name, item.get_category_name()])
	
	# List all procedural items
	print("\nAll procedural items:")
	for item_id in ItemManager.all_items:
		var item = ItemManager.get_item(item_id)
		if item and item.is_procedural:
			print("  - %s: %s" % [item_id, item.procedural_script_path])
	
	print("============================\n")

func _test_existing_items(parent: Node):
	"""Test with Arctic Aurora items from the project"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 20)
	parent.add_child(container)
	
	# Arctic Aurora items - these are procedural (.gd files)
	var arctic_items = [
		{"id": "arctic_aurora_board", "label": "Arctic Board\n(Procedural)"},
		{"id": "arctic_aurora_back", "label": "Arctic Card Back\n(Procedural)"},
		{"id": "arctic_aurora_front", "label": "Arctic Card Front\n(Procedural)"},
	]
	
	# Display Arctic items with proper sizing
	for item_info in arctic_items:
		var item = ItemManager.get_item(item_info.id)
		if item:
			var card = card_scene.instantiate()
			
			# Determine display mode based on ownership
			var mode = UnifiedItemCard.DisplayMode.INVENTORY
			if EquipmentManager and not EquipmentManager.is_item_owned(item_info.id):
				mode = UnifiedItemCard.DisplayMode.SHOP
			
			card.setup(item, mode)
			
			# Apply appropriate size based on category
			if item.category == UnifiedItemData.Category.BOARD:
				# Boards should be landscape (wider)
				card.size_preset = UnifiedItemCard.SizePreset.SHOP
			else:
				# Cards should be portrait
				card.size_preset = UnifiedItemCard.SizePreset.INVENTORY
			
			card._apply_size_preset()
			_add_card_with_label(container, card, item_info.label)
		else:
			print("Arctic item not found: %s" % item_info.id)
			# Try without underscores (in case the IDs are different)
			var alt_id = item_info.id.replace("_", "")
			item = ItemManager.get_item(alt_id)
			if item:
				print("  Found as: %s" % alt_id)
				var card = card_scene.instantiate()
				card.setup(item, UnifiedItemCard.DisplayMode.SHOP)
				_add_card_with_label(container, card, item_info.label + "\n(alt ID)")
	
	# Also show any other Arctic items that might exist
	var found_other = false
	for item_id in ItemManager.all_items:
		if "arctic" in item_id.to_lower() or "aurora" in item_id.to_lower():
			# Skip ones we already showed
			var already_shown = false
			for shown in arctic_items:
				if shown.id == item_id:
					already_shown = true
					break
			
			if not already_shown:
				if not found_other:
					# Add separator
					var sep = VSeparator.new()
					container.add_child(sep)
					found_other = true
				
				var item = ItemManager.get_item(item_id)
				if item:
					var card = card_scene.instantiate()
					card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
					_add_card_with_label(container, card, item.display_name + "\n(Found)")

# Add this diagnostic section to TestUnifiedItemCards.gd
# Place at the beginning of _ready() function after loading card_scene

func _run_arctic_diagnostics():
	"""Comprehensive Arctic item loading diagnosis"""
	print("\n========================================")
	print("ARCTIC ITEM DIAGNOSTIC - STARTING")
	print("========================================\n")
	
	# Safety check
	if not card_scene:
		push_error("Card scene not loaded! Cannot run diagnostics.")
		return
	
	if not ItemManager:
		push_error("ItemManager not available! Cannot run diagnostics.")
		return
	
	# STEP 1: Inventory Arctic items
	print("STEP 1: FINDING ARCTIC ITEMS IN ITEMMANAGER")
	print("----------------------------------------")
	
	var arctic_items = []
	var arctic_ids = []
	
	for item_id in ItemManager.all_items:
		if "arctic" in item_id.to_lower() or "aurora" in item_id.to_lower():
			var item = ItemManager.get_item(item_id)
			if item:
				arctic_items.append(item)
				arctic_ids.append(item_id)
				print("✓ Found: %s" % item_id)
				print("  - Display: %s" % item.display_name)
				print("  - Category: %s" % item.get_category_name())
				print("  - Procedural: %s" % item.is_procedural)
				print("  - Animated: %s" % item.is_animated)
				if item.procedural_script_path:
					print("  - Script: %s" % item.procedural_script_path)
	
	if arctic_items.is_empty():
		print("❌ NO ARCTIC ITEMS FOUND!")
		return
	
	print("\nFound %d Arctic items total\n" % arctic_items.size())
	
	# STEP 2: Test each loading scenario
	print("STEP 2: TESTING LOAD SCENARIOS")
	print("----------------------------------------")
	
	# Create a test container (not added to scene yet)
	var test_container = Control.new()
	test_container.name = "DiagnosticTestContainer"
	
	for item in arctic_items:
		print("\nTesting item: %s" % item.id)
		print("================")
		
		# Scenario A: Normal setup (like EXISTING ITEMS section)
		print("\nA) Normal setup() only:")
		var result_a = await _test_card_creation(item, "normal_setup", test_container)
		_report_card_status(result_a.card, result_a.status)
		
		# Scenario B: Setup THEN size preset (like current SIZE PRESETS section)
		print("\nB) setup() THEN _apply_size_preset():")
		var result_b = await _test_card_creation(item, "setup_then_size", test_container)
		_report_card_status(result_b.card, result_b.status)
		
		# Scenario C: Size preset BEFORE setup
		print("\nC) Size preset BEFORE setup():")
		var result_c = await _test_card_creation(item, "size_before_setup", test_container)
		_report_card_status(result_c.card, result_c.status)
		
		# Scenario D: Using the helper function from test
		print("\nD) Using _create_item_card_with_preset():")
		var result_d = await _test_card_creation(item, "helper_function", test_container)
		_report_card_status(result_d.card, result_d.status)
		
		# Clean up test cards
		for result in [result_a, result_b, result_c, result_d]:
			if result.card and is_instance_valid(result.card):
				result.card.queue_free()
	
	# Clean up test container
	test_container.queue_free()
	
	# STEP 3: Check for procedural script issues
	print("\nSTEP 3: CHECKING PROCEDURAL SCRIPTS")
	print("----------------------------------------")
	
	for item in arctic_items:
		if item.is_procedural and item.procedural_script_path:
			print("\nChecking script: %s" % item.procedural_script_path)
			
			if ResourceLoader.exists(item.procedural_script_path):
				var script = load(item.procedural_script_path)
				if script:
					print("  ✓ Script loads successfully")
					
					# Try to create instance
					var instance = script.new()
					if instance:
						print("  ✓ Instance created")
						
						# Check for required methods
						var methods_to_check = [
							"draw_board_background",
							"draw_card_back", 
							"draw_card_front",
							"_draw_aurora_ribbons"  # The problematic method
						]
						
						for method in methods_to_check:
							if instance.has_method(method):
								print("  ✓ Has method: %s" % method)
						
						# Check properties
						if "is_animated" in instance:
							print("  - is_animated: %s" % instance.is_animated)
						if "animation_phase" in instance:
							print("  - animation_phase: %s" % instance.animation_phase)
					else:
						print("  ❌ Failed to create instance")
				else:
					print("  ❌ Failed to load script")
			else:
				print("  ❌ Script path doesn't exist: %s" % item.procedural_script_path)
	
	print("\n========================================")
	print("DIAGNOSTIC COMPLETE")
	print("========================================\n")

func _test_card_creation(item: UnifiedItemData, method: String, container: Control) -> Dictionary:
	"""Test different card creation methods"""
	var card = null
	var status = {}
	
	# Create the card based on method
	match method:
		"normal_setup":
			card = card_scene.instantiate()
			if card:
				container.add_child(card)  # Must be in tree for _ready to work
				card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		
		"setup_then_size":
			card = card_scene.instantiate()
			if card:
				container.add_child(card)
				card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
				card.size_preset = UnifiedItemCard.SizePreset.MINI_DISPLAY
				card._apply_size_preset()
		
		"size_before_setup":
			card = card_scene.instantiate()
			if card:
				container.add_child(card)
				card.size_preset = UnifiedItemCard.SizePreset.MINI_DISPLAY
				card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		
		"helper_function":
			# Use the existing helper from the test
			card = _create_item_card_with_preset(
				item.id, 
				UnifiedItemCard.DisplayMode.SHOWCASE,
				UnifiedItemCard.SizePreset.MINI_DISPLAY
			)
			if card:
				container.add_child(card)  # Add to container for consistency
	
	# Wait for processing
	if card:
		await get_tree().process_frame
		
		# Gather status info
		status["created"] = true
		status["size"] = card.size
		status["procedural_visible"] = false
		status["background_visible"] = false
		status["has_draw_canvas"] = false
		
		# Check procedural canvas
		var proc_canvas = card.get_node_or_null("ProceduralCanvas")
		if proc_canvas:
			status["procedural_visible"] = proc_canvas.visible
			
			# Look for DrawCanvas child
			for child in proc_canvas.get_children():
				if child.name == "DrawCanvas":
					status["has_draw_canvas"] = true
					status["draw_canvas_size"] = child.size
		
		# Check background texture
		var bg_texture = card.get_node_or_null("BackgroundTexture")
		if bg_texture:
			status["background_visible"] = bg_texture.visible
			status["has_texture"] = bg_texture.texture != null
		
		# Remove from container after checking
		if card.get_parent() == container:
			container.remove_child(card)
	else:
		status["created"] = false
	
	return {"card": card, "status": status}

func _report_card_status(card: Control, status: Dictionary):
	"""Report the status of a card"""
	if not status.get("created", false):
		print("  ❌ Card creation FAILED")
		return
	
	print("  ✓ Card created")
	print("    Size: %s" % status.get("size", "unknown"))
	
	# Check what's visible
	var rendering_method = "UNKNOWN"
	if status.get("procedural_visible", false):
		if status.get("has_draw_canvas", false):
			rendering_method = "PROCEDURAL (DrawCanvas)"
			print("    ✅ Procedural rendering ACTIVE")
			print("    DrawCanvas size: %s" % status.get("draw_canvas_size", "unknown"))
		else:
			rendering_method = "PROCEDURAL (no canvas)"
			print("    ⚠️ Procedural visible but NO DrawCanvas")
	elif status.get("background_visible", false):
		if status.get("has_texture", false):
			rendering_method = "TEXTURE"
			print("    📄 Using texture fallback")
		else:
			rendering_method = "BACKGROUND (no texture)"
			print("    ⚠️ Background visible but NO texture")
	else:
		rendering_method = "NOTHING"
		print("    ❌ NOTHING is rendering!")
	
	print("    Rendering: %s" % rendering_method)
