# MiniProfileCard.gd - Compact player profile card for lobbies and multiplayer
# Location: res://Pyramids/scripts/ui/components/MiniProfileCard.gd
# Last Updated: Initial implementation with ProfileFrame integration

extends PanelContainer

signal player_clicked(player_id: String)
signal kick_requested(player_id: String)
signal invite_clicked(slot_index: int)
signal display_item_clicked(item_id: String)

# Card configuration
@export var slot_index: int = 0
@export var show_kick_button: bool = false  # Only for host
@export var clickable: bool = true

# Node references - Main structure
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox_container: VBoxContainer = $MarginContainer/VBoxContainer

# Top section nodes
@onready var top_section: HBoxContainer = $MarginContainer/VBoxContainer/TopSection
@onready var profile_container: Control = $MarginContainer/VBoxContainer/TopSection/ProfileContainer
@onready var profile_frame_placeholder: ColorRect = $MarginContainer/VBoxContainer/TopSection/ProfileContainer/ColorRect
@onready var name_label: Label = $MarginContainer/VBoxContainer/TopSection/ProfileContainer/Label
@onready var stats_container: VBoxContainer = $MarginContainer/VBoxContainer/TopSection/StatsContainer
@onready var win_rate_label: Label = $MarginContainer/VBoxContainer/TopSection/StatsContainer/WinRateLabel
@onready var games_label: Label = $MarginContainer/VBoxContainer/TopSection/StatsContainer/GamesLabel
@onready var mmr_label: Label = $MarginContainer/VBoxContainer/TopSection/StatsContainer/MMRLabel
@onready var stat4_label: Label = $MarginContainer/VBoxContainer/TopSection/StatsContainer/Stat4Label

# Bottom section nodes
@onready var bot_section: PanelContainer = $MarginContainer/VBoxContainer/BotSection
@onready var display_container: HBoxContainer = $MarginContainer/VBoxContainer/BotSection/DisplayContainer

# Display item cards (will be created dynamically)
var display_cards: Array[PanelContainer] = []

# Overlay controls
@onready var kick_button: Button = $KickButton
@onready var ready_sign: TextureRect = $ReadySign

# ProfileFrame instance (will be created dynamically)
var profile_frame: PanelContainer = null

# Current player data
var player_data: Dictionary = {}
var is_empty: bool = true

# Default empty card data
const EMPTY_CARD_DATA = {
	"id": "",
	"name": "",
	"level": 0,
	"prestige": 0,
	"stats": {
		"games": 0,
		"win_rate": 0.0,
		"mmr": 0,
		"streak": 0
	},
	"frame_id": "",
	"display_items": ["", "", ""],
	"is_ready": false,
	"is_host": false,
	"is_empty": true
}

func _ready() -> void:
	# Setup card appearance
	_setup_card_style()
	
	# Setup profile container for circular frame
	_setup_profile_container()
	
	# Setup stats container sizing
	_setup_stats_container()
	
	# NEW: Configure bot section to not expand
	if bot_section:
		bot_section.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bot_section.custom_minimum_size.y = 68  # Lock height
	
	# Create and add ProfileFrame
	_create_profile_frame()
	
	# Create display item cards
	_create_display_cards()
	
	# Connect overlay controls
	if kick_button:
		kick_button.pressed.connect(_on_kick_button_pressed)
		kick_button.visible = false  # Hidden by default
		kick_button.text = "✕"
		kick_button.add_theme_font_size_override("font_size", 16)
		kick_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		# Position in top-right corner
		kick_button.set_position(Vector2(size.x - 25, 5))
		kick_button.size = Vector2(20, 20)
	else:
		print("MiniProfileCard: KickButton node not found")
	
	if ready_sign:
		ready_sign.visible = false  # Hidden by default
		# Position in top-left corner
		ready_sign.set_position(Vector2(5, 5))
		ready_sign.size = Vector2(24, 24)
		# We'll set the texture when ready state changes
	else:
		print("MiniProfileCard: ReadySign node not found")
	
	# Connect to input for click detection
	if clickable:
		gui_input.connect(_on_gui_input)
	
	# TODO: Responsive sizing
	print("TODO: Implement responsive sizing for MiniProfileCard - Base size: 200x200")
	
	# DEBUG: Auto-populate with test data when running scene directly
	if get_tree().current_scene == self:
		print("MiniProfileCard: Running in test mode, populating with mock data")
		await get_tree().process_frame  # Wait for nodes to be ready
		_test_card_states()

func _setup_stats_container() -> void:
	"""Ensure stats container takes remaining space without over-expanding"""
	if not stats_container:
		return
		
	# Stats should expand to fill remaining horizontal space
	stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Give it a minimum width to prevent crushing
	stats_container.custom_minimum_size.x = 100

func _setup_profile_container() -> void:
	"""Setup the profile container to maintain square aspect for circular frame"""
	if not profile_container:
		return
	
	# Set fixed size for profile container to ensure square
	var container_size = Vector2(65, 65)  # Space for 50x50 frame + name below
	profile_container.custom_minimum_size = container_size
	profile_container.size = container_size
	
	# IMPORTANT: Don't clip so animations can extend beyond
	profile_container.clip_contents = false
	
	# IMPORTANT: Set proper size flags - shrink center vertically
	profile_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Changed from SIZE_FILL
	profile_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	profile_container.size_flags_stretch_ratio = 0.0  # Don't stretch
	
	# Also constrain the TopSection HBoxContainer
	if top_section:
		top_section.size_flags_horizontal = Control.SIZE_FILL
		top_section.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # Keep content centered
		top_section.alignment = BoxContainer.ALIGNMENT_BEGIN  # Align items to the left
		top_section.add_theme_constant_override("separation", 10)

func _create_profile_frame() -> void:
	# Check if ProfileFrame scene exists
	var frame_scene_path = "res://Pyramids/scenes/ui/components/ProfileFrame.tscn"
	if not ResourceLoader.exists(frame_scene_path):
		push_error("ProfileFrame.tscn not found! Please create it at: " + frame_scene_path)
		push_error("Follow the ProfileFrame Scene Structure instructions to create it")
		# Create a fallback colored rect
		if profile_frame_placeholder:
			profile_frame_placeholder.color = Color(0.5, 0.5, 0.5, 1.0)
			profile_frame_placeholder.custom_minimum_size = Vector2(50, 50)
		return
	
	# Load ProfileFrame scene
	var frame_scene = load(frame_scene_path)
	profile_frame = frame_scene.instantiate()
	
	# Configure frame - smaller to leave room for effects
	profile_frame.frame_size = 50  # Frame itself is 50x50
	profile_frame.show_level = true
	profile_frame.enable_animations = true
	
	# IMPORTANT: Use TOP_LEFT anchor instead of CENTER
	# This ensures the frame stays in the correct position
	profile_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	profile_frame.set_offsets_preset(Control.PRESET_TOP_LEFT)
	
	# Position at top-left of container with margin for effects
	profile_frame.position = Vector2(7.5, -7.5)  # Changed Y from 7.5 to 0
	profile_frame.size = Vector2(50, 50)
	
	# Replace placeholder with actual frame
	if profile_frame_placeholder:
		profile_frame_placeholder.queue_free()
	
	# Add frame to container
	profile_container.add_child(profile_frame)
	
	# Position the name label below the frame
	if name_label:
		name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		name_label.position = Vector2(0, 50)  # Changed from (0, 52) to align better
		name_label.size = Vector2(65, 15)
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Connect frame signals
	profile_frame.frame_clicked.connect(_on_profile_frame_clicked)

func set_player_data(data: Dictionary) -> void:
	player_data = data
	is_empty = data.get("is_empty", false)
	
	if is_empty:
		set_empty_state()
	else:
		set_occupied_state()

func set_empty_state() -> void:
	is_empty = true
	player_data = EMPTY_CARD_DATA.duplicate(true)
	
	# Update appearance for empty slot
	_setup_empty_card_style()
	
	# Hide profile frame
	if profile_frame:
		profile_frame.visible = false
	
	# Show invite prompt in center of profile container
	if name_label:
		name_label.text = "+"
		name_label.add_theme_font_size_override("font_size", 32)
		name_label.modulate = Color(0.5, 0.5, 0.5, 0.5)
		# Center the + in the profile container using TOP_LEFT anchor
		name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		name_label.position = Vector2(17.5, 17.5)  # Center in 65x65 container
		name_label.size = Vector2(30, 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Hide stats
	if stats_container:
		stats_container.visible = false
	
	# Hide display items
	if bot_section:
		bot_section.visible = false
	
	# Hide overlay controls
	if kick_button:
		kick_button.visible = false
	if ready_sign:
		ready_sign.visible = false

func set_occupied_state() -> void:
	is_empty = false
	
	# Update appearance for occupied slot
	_setup_occupied_card_style()
	
	# Show and update profile frame
	if profile_frame:
		profile_frame.visible = true
		var level = player_data.get("level", 1)
		var prestige = player_data.get("prestige", 0)
		profile_frame.set_player_level(level, prestige)
		
		# Set custom frame if available
		var frame_id = player_data.get("frame_id", "")
		if frame_id != "":
			profile_frame.set_custom_frame(frame_id)
	
	# Update name (position it below the frame)
	if name_label:
		name_label.text = player_data.get("name", "Player")
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.modulate = Color.WHITE
		# Position below frame - using TOP_LEFT anchor
		name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		name_label.position = Vector2(0, 50)
		name_label.size = Vector2(65, 15)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Rest of the function remains the same...
	# Update stats
	if stats_container:
		stats_container.visible = true
		_update_stats_display()
	
	# Update display items
	if bot_section:
		bot_section.visible = true
		_update_display_items()
	
	# Update overlay controls
	_update_overlay_controls()

func _update_stats_display() -> void:
	var stats = player_data.get("stats", {})
	
	# Win Rate
	if win_rate_label:
		var win_rate = stats.get("win_rate", 0.0)
		win_rate_label.text = "WR: %d%%" % int(win_rate * 100)
	
	# Games Played
	if games_label:
		var games = stats.get("games", 0)
		games_label.text = "G: %d" % games
	
	# MMR
	if mmr_label:
		var mmr = stats.get("mmr", 0)
		if mmr >= 1000:
			mmr_label.text = "MMR: %.1fK" % (mmr / 1000.0)
		else:
			mmr_label.text = "MMR: %d" % mmr
	
	# Streak (4th stat)
	if stat4_label:
		var streak = stats.get("streak", 0)
		if streak > 0:
			stat4_label.text = "🔥 %d" % streak
			stat4_label.modulate = Color(1.0, 0.5, 0.0)  # Orange for win streak
		elif streak < 0:
			stat4_label.text = "❄️ %d" % abs(streak)
			stat4_label.modulate = Color(0.5, 0.7, 1.0)  # Blue for loss streak
		else:
			stat4_label.text = "Streak: 0"
			stat4_label.modulate = Color.WHITE

func _create_display_cards() -> void:
	"""Create 3 DisplayItemCard instances in the display container"""
	if not display_container:
		print("MiniProfileCard: DisplayContainer not found")
		return
	
	# Configure display container for proper centering
	display_container.alignment = BoxContainer.ALIGNMENT_CENTER
	display_container.add_theme_constant_override("separation", 6)  # 6px between cards
	
	# Setup bot section with proper margins for 9px vertical padding
	if bot_section:
		var bot_margin = MarginContainer.new()
		bot_margin.name = "BotMargin"
		bot_margin.add_theme_constant_override("margin_top", 9)
		bot_margin.add_theme_constant_override("margin_bottom", 9)
		bot_margin.add_theme_constant_override("margin_left", 7)
		bot_margin.add_theme_constant_override("margin_right", 7)
		
		# Reparent display_container to margin container if not already
		if display_container.get_parent() == bot_section:
			display_container.reparent(bot_margin)
			bot_section.add_child(bot_margin)
	
	# Clear any existing ColorRect placeholders
	for child in display_container.get_children():
		child.queue_free()
	
	# Check if DisplayItemCard scene exists
	var card_scene_path = "res://Pyramids/scenes/ui/components/DisplayItemCard.tscn"
	var has_scene = ResourceLoader.exists(card_scene_path)
	
	# Create 3 display cards
	display_cards.clear()
	for i in range(3):
		var card
		
		if has_scene:
			# Load from scene
			var scene = load(card_scene_path)
			card = scene.instantiate()
		else:
			# Create programmatically
			card = PanelContainer.new()
			card.set_script(preload("res://Pyramids/scripts/ui/components/DisplayItemCard.gd"))
		
		# FIXED: Enforce size on each card
		card.custom_minimum_size = Vector2(50, 50)
		card.size = Vector2(50, 50)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		card.name = "DisplayCard%d" % (i + 1)
		display_container.add_child(card)
		display_cards.append(card)
		
		# Connect click signal
		if card.has_signal("clicked"):
			card.clicked.connect(_on_display_item_clicked)

func _update_display_items() -> void:
	var display_items = player_data.get("display_items", ["", "", ""])
	
	# Update each display card
	for i in range(min(3, display_cards.size())):
		if i < display_items.size():
			var item_id = display_items[i]
			var card = display_cards[i]
			
			if item_id == "":
				# Empty slot
				if card.has_method("set_empty"):
					card.set_empty()
			else:
				# Check if it's an achievement by looking in AchievementManager
				if AchievementManager and AchievementManager.achievements.has(item_id):
					# It's an achievement
					if card.has_method("set_achievement"):
						card.set_achievement(item_id)
				else:
					# It's a regular item
					if card.has_method("set_item"):
						card.set_item(item_id)

func _on_display_item_clicked(item_id: String, item_type: String) -> void:
	print("MiniProfileCard: Display item clicked - ID: %s, Type: %s" % [item_id, item_type])
	display_item_clicked.emit(item_id)

func _update_overlay_controls() -> void:
	# Update ready sign
	if ready_sign:
		ready_sign.visible = player_data.get("is_ready", false)
		if ready_sign.visible:
			# Draw a checkmark procedurally if no texture
			if not ready_sign.texture:
				_create_ready_checkmark()
	
	# Update kick button (only visible to host for other players)
	if kick_button:
		var is_host_viewing = show_kick_button  # Set by lobby when creating cards
		var is_self = player_data.get("is_host", false)
		kick_button.visible = is_host_viewing and not is_self and not is_empty

func _create_ready_checkmark() -> void:
	"""Create a simple checkmark texture for the ready sign"""
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	
	# Draw a simple checkmark (this is a placeholder - ideally load a proper icon)
	for x in range(24):
		for y in range(24):
			# Simple checkmark shape
			if (x >= 4 and x <= 8 and y >= 12 and y <= 16 - (x - 4)) or \
			   (x >= 8 and x <= 18 and y >= 16 - (x - 8) and y <= 18 - (x - 8)):
				image.set_pixel(x, y, Color(0.0, 1.0, 0.0, 1.0))  # Green
	
	var texture = ImageTexture.create_from_image(image)
	ready_sign.texture = texture

func _setup_card_style() -> void:
	# Base card style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	add_theme_stylebox_override("panel", style)
	
	# Don't clip contents on parent containers to allow animations
	if margin_container:
		margin_container.clip_contents = false
	if vbox_container:
		vbox_container.clip_contents = false
	if top_section:
		top_section.clip_contents = false

func _setup_empty_card_style() -> void:
	# Dashed border effect for empty slots
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
		# TODO: Implement actual dashed border
		print("TODO: Add dashed border shader for empty card slots")

func _setup_occupied_card_style() -> void:
	# Solid style for occupied slots
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
		
		# Add glow for host
		if player_data.get("is_host", false):
			style.border_color = Color(1.0, 0.84, 0, 1.0)  # Gold for host
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_empty:
				print("MiniProfileCard: Invite clicked for slot %d" % slot_index)
				invite_clicked.emit(slot_index)
			else:
				var player_id = player_data.get("id", "")
				print("MiniProfileCard: Player clicked - ID: %s" % player_id)
				player_clicked.emit(player_id)

func _on_kick_button_pressed() -> void:
	var player_id = player_data.get("id", "")
	print("MiniProfileCard: Kick requested for player: %s" % player_id)
	kick_requested.emit(player_id)

func _on_profile_frame_clicked() -> void:
	if not is_empty:
		var player_id = player_data.get("id", "")
		print("MiniProfileCard: Profile frame clicked - ID: %s" % player_id)
		player_clicked.emit(player_id)

# Public methods for lobby to use
func set_ready(ready: bool) -> void:
	player_data["is_ready"] = ready
	_update_overlay_controls()

func set_host_viewing(is_host: bool) -> void:
	show_kick_button = is_host
	_update_overlay_controls()

func highlight() -> void:
	modulate = Color(1.2, 1.2, 1.2)

func unhighlight() -> void:
	modulate = Color.WHITE

# Debug function
func debug_populate_with_mock_data() -> void:
	var mock_data = {
		"id": "player_test",
		"name": "TestPlayer",
		"level": 42,
		"prestige": 8,  # Silver III
		"stats": {
			"games": 250,
			"win_rate": 0.68,
			"mmr": 2450,
			"streak": 3
		},
		"frame_id": "",
		"display_items": ["first_game", "", "combo_5"],  # Real achievement IDs
		"is_ready": false,
		"is_host": false,
		"is_empty": false
	}
	set_player_data(mock_data)

func _test_card_states() -> void:
	print("=== Testing MiniProfileCard States ===")
	
	# Test 1: Empty state
	print("Test 1: Empty card (invite slot)")
	set_empty_state()
	await get_tree().create_timer(2.0).timeout
	
	# Test 2: Regular player
	print("Test 2: Regular player")
	debug_populate_with_mock_data()
	await get_tree().create_timer(2.0).timeout
	
	# Test 3: Ready player
	print("Test 3: Player ready state")
	set_ready(true)
	await get_tree().create_timer(2.0).timeout
	
	# Test 4: Host player
	print("Test 4: Host player with gold border")
	var host_data = {
		"id": "host_player",
		"name": "HostPlayer",
		"level": 50,
		"prestige": 13,  # Gold III
		"stats": {
			"games": 500,
			"win_rate": 0.75,
			"mmr": 3200,
			"streak": 7
		},
		"frame_id": "",
		"display_items": ["board_clear", "combo_10", "all_peaks"],  # Real achievement IDs
		"is_ready": true,
		"is_host": true,
		"is_empty": false
	}
	set_player_data(host_data)
	await get_tree().create_timer(2.0).timeout
	
	# Test 5: Show kick button (simulate host viewing other player)
	print("Test 5: Host view - showing kick button")
	debug_populate_with_mock_data()  # Back to regular player
	set_host_viewing(true)  # Simulate host viewing
	await get_tree().create_timer(2.0).timeout
	
	# Test 6: Different prestige levels
	print("Test 6: Cycling through prestige levels")
	var prestige_tests = [
		{"level": 25, "prestige": 0, "name": "Newbie"},  # No prestige
		{"level": 50, "prestige": 3, "name": "BronzeIII"},  # Bronze
		{"level": 50, "prestige": 18, "name": "DiamondIII"},  # Diamond
	]
	
	for test in prestige_tests:
		var test_data = {
			"id": "prestige_test",
			"name": test.name,
			"level": test.level,
			"prestige": test.prestige,
			"stats": {
				"games": 100,
				"win_rate": 0.5,
				"mmr": 1500,
				"streak": -2  # Loss streak to test ice emoji
			},
			"frame_id": "",
			"display_items": ["", "", ""],
			"is_ready": false,
			"is_host": false,
			"is_empty": false
		}
		print("  - Testing: %s (Level %d, Prestige %d)" % [test.name, test.level, test.prestige])
		set_player_data(test_data)
		await get_tree().create_timer(1.5).timeout
	
	print("=== Test Complete ===")
	print("Click the card to test player_clicked signal")
	print("Check console for any errors or TODOs")
