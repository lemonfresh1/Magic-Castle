# ProceduralItemTest.gd - Test scene for all procedural items
# Location: res://Pyramids/test/ProceduralItemTest.gd
# Last Updated: Slot-based preview system for multiple items [Date]

extends Control

# UI References
@onready var item_type_option: OptionButton = $VBoxContainer/Controls/ItemTypeButton
@onready var item_list: ItemList = $VBoxContainer/Controls/ItemList
@onready var preview_container: Control = $PreviewContainer
@onready var animation_toggle: CheckBox = $VBoxContainer/Controls/AnimationToggle
@onready var export_button: Button = $VBoxContainer/Controls/ExportButton
@onready var info_label: Label = $VBoxContainer/InfoLabel

# Preview slots (5 fixed slots)
var ui_toggle_button: Button
var board_slot: Control  # Full screen background
var card_slots: Array[Control] = []  # 4 slots for cards (can be fronts or backs)

# Current state
var current_item_type: String = "boards"
var current_items = {
	"board": null,
	"card_front": null,
	"card_back": null
}
var animation_tween: Tween
var show_all_items: bool = false  # Show all equipped items at once

func _ready():
	_setup_ui()
	_create_ui_toggle_button()  # ADD THIS
	_populate_item_types()
	_create_preview_slots()
	_load_items_for_type("boards")

func _setup_ui():
	item_type_option.item_selected.connect(_on_item_type_changed)
	item_list.item_selected.connect(_on_item_selected)
	animation_toggle.toggled.connect(_on_animation_toggled)
	export_button.pressed.connect(_on_export_pressed)
	
	# Setup UI toggle button (now a separate button)
	if ui_toggle_button:
		ui_toggle_button.pressed.connect(_toggle_ui_visibility)
		ui_toggle_button.text = "Hide UI"
		ui_toggle_button.z_index = 100  # Always on top
		# Position it in top-right corner
		ui_toggle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		ui_toggle_button.position = Vector2(-120, 10)  # Adjust as needed
		ui_toggle_button.size = Vector2(100, 30)
	
	# Make VBoxContainer overlay on top (but below the toggle button)
	$VBoxContainer.z_index = 10

func _on_ui_visibility_toggled(toggled: bool):
	# Toggle UI visibility for clean preview
	$VBoxContainer.visible = not toggled
	
	# If hiding UI and in loadout mode, ensure everything is visible
	if toggled and current_item_type == "loadout":
		_show_full_loadout()

func _populate_item_types():
	item_type_option.add_item("Boards")
	item_type_option.add_item("Card Fronts")
	item_type_option.add_item("Card Backs")
	item_type_option.add_item("Full Loadout")  # New option

func _create_preview_slots():
	# Slot 0: Board (full screen background)
	board_slot = Control.new()
	board_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_slot.draw.connect(_draw_board_slot)
	board_slot.visible = false
	preview_container.add_child(board_slot)
	
	# Create centered container for cards
	var cards_center = CenterContainer.new()
	cards_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_container.add_child(cards_center)
	
	var cards_margin = MarginContainer.new()
	cards_margin.add_theme_constant_override("margin_top", 30)
	cards_center.add_child(cards_margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	cards_margin.add_child(hbox)
	
	# Create 5 card slots instead of 4
	for i in range(5):  # CHANGED from 4 to 5
		var card_slot = Control.new()
		card_slot.custom_minimum_size = Vector2(180, 252)
		card_slot.set_meta("slot_index", i)
		card_slot.set_meta("card_type", "")
		card_slot.set_meta("rank", "")
		card_slot.set_meta("suit", 0)
		card_slot.draw.connect(_draw_card_slot.bind(card_slot))
		card_slot.visible = false
		hbox.add_child(card_slot)
		card_slots.append(card_slot)

func _on_item_type_changed(index: int):
	match index:
		0: 
			current_item_type = "boards"
			show_all_items = false
		1: 
			current_item_type = "card_fronts"
			show_all_items = false
		2: 
			current_item_type = "card_backs"
			show_all_items = false
		3:  # Full Loadout
			current_item_type = "loadout"
			show_all_items = true
			_show_full_loadout()
			return
	
	_load_items_for_type(current_item_type)
	_update_preview()

func _on_item_selected(index: int):
	if current_item_type == "loadout":
		return  # Don't select items in loadout mode
	
	var items = ProceduralItemRegistry.get_items_by_category(current_item_type)
	
	if index >= 0 and index < items.size():
		var item = items[index]
		
		# Store the selected item
		match current_item_type:
			"boards":
				current_items.board = item
			"card_fronts":
				current_items.card_front = item
			"card_backs":
				current_items.card_back = item
		
		_update_preview()

func _on_show_all_toggled(toggled: bool):
	show_all_items = toggled
	_update_preview()

func _update_preview():
	# Hide all slots first
	_hide_all_slots()
	
	if show_all_items or current_item_type == "loadout":
		_show_full_loadout()
	else:
		# Show only the selected item type
		match current_item_type:
			"boards":
				if current_items.board:
					board_slot.visible = true
					board_slot.queue_redraw()
			"card_fronts":
				if current_items.card_front:
					_setup_card_fronts()
			"card_backs":
				if current_items.card_back:
					_setup_card_back()
	
	_update_info()
	
	# Start animation if needed
	if animation_toggle.button_pressed:
		_start_animation()

func _show_full_loadout():
	# Show everything we have
	if current_items.board:
		board_slot.visible = true
		board_slot.queue_redraw()
	
	var slot_index = 0
	
	# First slot: card back
	if current_items.card_back and slot_index < 5:
		var slot = card_slots[slot_index]
		slot.set_meta("card_type", "back")
		slot.visible = true
		slot.queue_redraw()
		slot_index += 1
	
	# Remaining slots: card fronts with different ranks
	if current_items.card_front:
		var test_cards = [
			{"rank": "A", "suit": 0},  # Ace of Spades
			{"rank": "K", "suit": 1},  # King of Hearts
			{"rank": "Q", "suit": 2},  # Queen of Clubs
			{"rank": "J", "suit": 3}   # Jack of Diamonds
		]
		
		for card_data in test_cards:
			if slot_index < 5:  # We have 5 slots total now
				var slot = card_slots[slot_index]
				slot.set_meta("card_type", "front")
				slot.set_meta("rank", card_data.rank)
				slot.set_meta("suit", card_data.suit)
				slot.visible = true
				slot.queue_redraw()
				slot_index += 1

func _setup_card_fronts():
	# Show 4 different card fronts
	var test_cards = [
		{"rank": "A", "suit": 0},  # Ace of Spades
		{"rank": "K", "suit": 1},  # King of Hearts
		{"rank": "Q", "suit": 2},  # Queen of Clubs
		{"rank": "J", "suit": 3}   # Jack of Diamonds
	]
	
	for i in range(4):
		var slot = card_slots[i]
		slot.set_meta("card_type", "front")
		slot.set_meta("rank", test_cards[i].rank)
		slot.set_meta("suit", test_cards[i].suit)
		slot.visible = true
		slot.queue_redraw()

func _setup_card_back():
	# Show just one centered card back
	var slot = card_slots[0]
	slot.set_meta("card_type", "back")
	slot.visible = true
	slot.queue_redraw()

func _hide_all_slots():
	board_slot.visible = false
	for slot in card_slots:
		slot.visible = false
	
	if animation_tween:
		animation_tween.kill()
		animation_tween = null

func _draw_board_slot():
	if current_items.board and current_items.board.has_method("draw_board_background"):
		current_items.board.draw_board_background(board_slot, board_slot.size)

func _draw_card_slot(slot: Control):
	var card_type = slot.get_meta("card_type", "")
	
	match card_type:
		"front":
			if current_items.card_front and current_items.card_front.has_method("draw_card_front"):
				var rank = slot.get_meta("rank", "A")
				var suit = slot.get_meta("suit", 0)
				current_items.card_front.draw_card_front(slot, slot.size, rank, suit)
		"back":
			if current_items.card_back and current_items.card_back.has_method("draw_card_back"):
				current_items.card_back.draw_card_back(slot, slot.size)

func _load_items_for_type(type: String):
	item_list.clear()
	
	if type == "loadout":
		item_list.add_item("Board: %s" % (current_items.board.display_name if current_items.board else "None"))
		item_list.add_item("Card Front: %s" % (current_items.card_front.display_name if current_items.card_front else "None"))
		item_list.add_item("Card Back: %s" % (current_items.card_back.display_name if current_items.card_back else "None"))
		info_label.text = "Current loadout"
		return
	
	var items = ProceduralItemRegistry.get_items_by_category(type)
	
	if items.is_empty():
		item_list.add_item("No items found")
		info_label.text = "No procedural %s found." % type
		return
	
	for item in items:
		var display_text = "%s (%s)" % [item.display_name, item.item_id]
		item_list.add_item(display_text)
	
	info_label.text = "Found %d procedural %s" % [items.size(), type]

func _update_info():
	if current_item_type == "loadout" or show_all_items:
		var items_shown = []
		if current_items.board: items_shown.append("Board")
		if current_items.card_front: items_shown.append("Front")
		if current_items.card_back: items_shown.append("Back")
		info_label.text = "Showing: %s" % ", ".join(items_shown)
	else:
		var current_item = null
		match current_item_type:
			"boards": current_item = current_items.board
			"card_fronts": current_item = current_items.card_front
			"card_backs": current_item = current_items.card_back
		
		if current_item:
			var rarity_text = "Unknown"
			if current_item.get("item_rarity") != null:
				var rarity_value = current_item.item_rarity
				if rarity_value is int:
					match rarity_value:
						UnifiedItemData.Rarity.COMMON: rarity_text = "Common"
						UnifiedItemData.Rarity.UNCOMMON: rarity_text = "Uncommon"
						UnifiedItemData.Rarity.RARE: rarity_text = "Rare"
						UnifiedItemData.Rarity.EPIC: rarity_text = "Epic"
						UnifiedItemData.Rarity.LEGENDARY: rarity_text = "Legendary"
						UnifiedItemData.Rarity.MYTHIC: rarity_text = "Mythic"
			
			info_label.text = "Showing: %s\nAnimated: %s\nRarity: %s" % [
				current_item.display_name,
				"Yes" if current_item.is_animated else "No",
				rarity_text
			]

func _start_animation():
	if animation_tween:
		animation_tween.kill()
	
	var animated_items = []
	if current_items.board and current_items.board.is_animated:
		animated_items.append(current_items.board)
	if current_items.card_front and current_items.card_front.is_animated:
		animated_items.append(current_items.card_front)
	if current_items.card_back and current_items.card_back.is_animated:
		animated_items.append(current_items.card_back)
	
	if animated_items.is_empty():
		return
	
	animation_tween = create_tween()
	animation_tween.set_loops()
	animation_tween.tween_method(
		_update_animation_phase,
		0.0,
		1.0,
		animated_items[0].animation_duration  # Use first item's duration
	)

func _update_animation_phase(phase: float):
	# Update all animated items
	if current_items.board and current_items.board.is_animated:
		current_items.board.animation_phase = phase
		if board_slot.visible:
			board_slot.queue_redraw()
	
	if current_items.card_front and current_items.card_front.is_animated:
		current_items.card_front.animation_phase = phase
		for slot in card_slots:
			if slot.visible and slot.get_meta("card_type") == "front":
				slot.queue_redraw()
	
	if current_items.card_back and current_items.card_back.is_animated:
		current_items.card_back.animation_phase = phase
		for slot in card_slots:
			if slot.visible and slot.get_meta("card_type") == "back":
				slot.queue_redraw()

func _on_animation_toggled(pressed: bool):
	if pressed:
		_start_animation()
	elif animation_tween:
		animation_tween.kill()
		animation_tween = null
		# Reset animation phases
		if current_items.board: current_items.board.animation_phase = 0.0
		if current_items.card_front: current_items.card_front.animation_phase = 0.0
		if current_items.card_back: current_items.card_back.animation_phase = 0.0

func _on_export_pressed():
	# Export currently visible item
	var item_to_export = null
	
	match current_item_type:
		"boards": item_to_export = current_items.board
		"card_fronts": item_to_export = current_items.card_front
		"card_backs": item_to_export = current_items.card_back
	
	if not item_to_export:
		info_label.text = "No item selected to export"
		return
	
	if item_to_export.has_method("export_to_png"):
		info_label.text = "Exporting %s..." % item_to_export.display_name
		await item_to_export.export_to_png()
		info_label.text = "Export complete! Check assets/icons/"

func _create_ui_toggle_button():
	# Create the button dynamically
	ui_toggle_button = Button.new()
	ui_toggle_button.text = "Hide UI"
	ui_toggle_button.size = Vector2(100, 30)
	ui_toggle_button.z_index = 100  # Always on top
	
	# Position in top-right corner
	ui_toggle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ui_toggle_button.position = Vector2(-110, 10)
	
	# Add directly to the root (self)
	add_child(ui_toggle_button)
	
	# Connect the signal
	ui_toggle_button.pressed.connect(_toggle_ui_visibility)
	
	print("DEBUG: UI Toggle button created at position: ", ui_toggle_button.position)

func _toggle_ui_visibility():
	var vbox = $VBoxContainer
	vbox.visible = not vbox.visible
	
	# Update button text
	ui_toggle_button.text = "Show UI" if not vbox.visible else "Hide UI"
	
	# If hiding UI and in loadout mode, ensure everything is visible
	if not vbox.visible and current_item_type == "loadout":
		_show_full_loadout()
