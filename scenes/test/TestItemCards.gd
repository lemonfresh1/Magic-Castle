# TestItemCards.gd - Compact layout with all cards visible
extends Control

func _ready():
	# Wait for all systems to initialize
	await get_tree().process_frame
	
	# IMPORTANT: Reset equipment states for testing
	_setup_test_states()
	
	# Create main container
	var container = VBoxContainer.new()
	container.name = "Container"
	container.add_theme_constant_override("separation", 10)
	add_child(container)
	container.position = Vector2(20, 20)
	
	# Load the UnifiedItemCard scene
	var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
	
	print("\n=== TESTING UNIFIED ITEM CARDS ===")
	print("Testing badge states: Shop (price tag), Owned (empty box), Equipped (box+check), Locked (chains)")
	
	# Row 1: Portrait cards - Different ownership states
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	container.add_child(row1)
	
	# Test Case 1: Not owned item in shop
	_create_card(card_scene, "card_mystic", UnifiedItemCard.DisplayMode.SHOP, row1, "Shop\nNot Owned")
	
	# Test Case 2: Owned but not equipped 
	_create_card(card_scene, "card_neon", UnifiedItemCard.DisplayMode.INVENTORY, row1, "Owned\nNot Equipped")
	
	# Test Case 3: Owned and equipped
	_create_card(card_scene, "card_classic", UnifiedItemCard.DisplayMode.INVENTORY, row1, "Owned\nEquipped")
	
	# Row 2: More test cases with locked card
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	container.add_child(row2)
	
	# Test Case 4: LOCKED portrait card (level requirement not met)
	_create_locked_card(card_scene, "card_epic", UnifiedItemCard.DisplayMode.SHOP, row2, "Locked Card\nLevel 10 Required", false)
	
	# Test Case 5: Already owned item in shop (should not show price)
	_create_card(card_scene, "card_neon", UnifiedItemCard.DisplayMode.SHOP, row2, "Shop\nAlready Owned")
	
	# Test Case 6: Profile display mode with equipped item
	_create_card(card_scene, "card_classic", UnifiedItemCard.DisplayMode.PROFILE, row2, "Profile Mode")
	
	# Row 3: Landscape boards including locked
	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	container.add_child(row3)
	
	# Test Case 7: Board not owned in shop
	_create_card(card_scene, "board_pyramids", UnifiedItemCard.DisplayMode.SHOP, row3, "Board Shop\nNot Owned")
	
	# Row 4: Locked landscape board
	var row4 = HBoxContainer.new()
	row4.add_theme_constant_override("separation", 10)
	container.add_child(row4)
	
	# Test Case 8: LOCKED landscape board (level requirement)
	_create_locked_card(card_scene, "board_epic", UnifiedItemCard.DisplayMode.SHOP, row4, "Locked Board\nLevel 15 Required", true)
	
	# Add info label
	var info = Label.new()
	info.text = "Badges: Price tag = Shop | Empty box = Owned | Box+Check = Equipped | Chains = Locked"
	info.position = Vector2(20, 500)
	add_child(info)

func _setup_test_states():
	"""Setup specific equipment states for testing"""
	if not EquipmentManager:
		return
	
	# Ensure we have specific items for testing
	# card_classic - owned and equipped (default)
	if not EquipmentManager.is_item_owned("card_classic"):
		EquipmentManager.grant_item("card_classic", "test")
	EquipmentManager.equip_item("card_classic")
	
	# card_neon - owned but NOT equipped
	if not EquipmentManager.is_item_owned("card_neon"):
		EquipmentManager.grant_item("card_neon", "test")
	# Make sure it's NOT equipped by equipping something else
	if EquipmentManager.is_item_equipped("card_neon"):
		EquipmentManager.equip_item("card_classic")  # Equip classic instead
	
	# card_mystic - NOT owned (we won't grant it)
	# card_epic - NOT owned and will be LOCKED
	# board_pyramids - NOT owned (we won't grant it)
	# board_epic - NOT owned and will be LOCKED
	
	print("Test states setup:")
	print("  card_classic: owned=%s, equipped=%s" % [
		EquipmentManager.is_item_owned("card_classic"),
		EquipmentManager.is_item_equipped("card_classic")
	])
	print("  card_neon: owned=%s, equipped=%s" % [
		EquipmentManager.is_item_owned("card_neon"),
		EquipmentManager.is_item_equipped("card_neon")
	])
	print("  card_mystic: owned=%s" % EquipmentManager.is_item_owned("card_mystic"))

func _create_card(scene: PackedScene, item_id: String, mode, parent: Node, label_text: String):
	if ItemDatabase:
		var item_data = ItemDatabase.get_item(item_id)
		if item_data:
			var card = scene.instantiate()
			parent.add_child(card)
			card.setup(item_data, mode)
			
			# The card should now correctly detect its state from EquipmentManager
			# No need to force states
			
			# Debug label above card - now with proper positioning
			var label = Label.new()
			label.text = label_text
			label.position = Vector2(0, -35)  # Moved up a bit more for 2 lines
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.add_theme_font_size_override("font_size", 10)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(label)
			
			# Debug print the actual state
			print("Card %s - owned: %s, equipped: %s, mode: %s" % [
				item_id, 
				card.is_owned, 
				card.is_equipped,
				UnifiedItemCard.DisplayMode.keys()[mode]
			])
			
			# Connect clicks
			card.clicked.connect(func(): 
				print("Clicked: %s" % item_data.display_name)
				# Test equipping on click
				if card.is_owned and not card.is_equipped:
					EquipmentManager.equip_item(item_id)
					card.setup(item_data, mode)  # Refresh the card
			)

func _create_locked_card(scene: PackedScene, item_id: String, mode, parent: Node, label_text: String, is_landscape: bool = false):
	"""Create a card that's locked due to level requirement"""
	if ItemDatabase:
		# Try to get or create an item with unlock_level
		var item_data = ItemDatabase.get_item(item_id)
		if not item_data:
			# Create a test item if it doesn't exist
			item_data = UnifiedItemData.new()
			item_data.id = item_id
			
			if is_landscape:
				item_data.display_name = "Epic Board"
				item_data.category = "board"
				item_data.rarity = "epic"
				item_data.unlock_level = 15  # Requires level 15
				item_data.base_price = 1000
			else:
				item_data.display_name = "Epic Card"
				item_data.category = "card_front"
				item_data.rarity = "epic"
				item_data.unlock_level = 10  # Requires level 10
				item_data.base_price = 500
		else:
			# Ensure it has a level requirement
			item_data.unlock_level = 10 if not is_landscape else 15
		
		var card = scene.instantiate()
		parent.add_child(card)
		
		# Force locked state for testing
		card.setup(item_data, mode)
		card.is_locked = true  # Force locked state
		card.is_owned = false
		card._update_lock_state()  # Update to show chains
		
		# Debug label
		var label = Label.new()
		label.text = label_text
		label.position = Vector2(0, -35)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_font_size_override("font_size", 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(label)
		
		print("Card %s - LOCKED (level %d required)" % [item_id, item_data.unlock_level])
