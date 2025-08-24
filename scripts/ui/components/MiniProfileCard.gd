# MiniProfileCard.gd - Compact player profile card for lobbies and multiplayer
# Location: res://Pyramids/scripts/ui/components/MiniProfileCard.gd
# Last Updated: Phase A complete - 3-panel structure, emoji stats, typography [Date]
#
# MiniProfileCard handles:
# - Displaying player profile in compact 200x200 format
# - Managing empty (invite) and occupied states
# - Showing profile frame with level/prestige
# - Displaying 3 emoji stats (MMR, Win Rate, Games)
# - Showcasing 3 display items (achievements/items)
# - Host controls (kick button) and ready state
#
# Flow: PlayerData → MiniProfileCard → ProfileFrame + DisplayCards → Visual Output
# Dependencies: ProfileFrame (scene), DisplayItemCard (scene), UIStyleManager (typography),
#              AchievementManager (achievements), ItemManager (items), EquipmentManager (ownership)
#
# TODO:
# - [ ] Phase B: Replace DisplayItemCard with UnifiedItemCard for animations
# - [ ] Implement subtle animations (sway, float, shadow layers)
# - [ ] Add theme system for stats panel (parchment, LED, glass, wood)
# - [ ] Implement EffectOverlay usage (glass overlay, fire borders)
# - [ ] Add ProfileFrame custom items support
# - [ ] Create responsive sizing for different screen resolutions
# - [ ] Add haptic feedback for mobile touches
# - [ ] Implement expanded view on item click
# - [ ] Add sound effects for state changes
# - [ ] Support custom backgrounds/textures per player prestige
# - [ ] Add connection status indicator
# - [ ] Implement spectator mode display variant

extends PanelContainer

# === SIGNALS ===
signal player_clicked(player_id: String)
signal kick_requested(player_id: String)
signal invite_clicked(slot_index: int)
signal display_item_clicked(item_id: String)

# === CONSTANTS ===
const EMPTY_CARD_DATA = {
	"id": "",
	"name": "",
	"level": 0,
	"prestige": 0,
	"stats": {
		"games": 0,
		"win_rate": 0.0,
		"mmr": 0
	},
	"frame_id": "",
	"display_items": ["", "", ""],
	"is_ready": false,
	"is_host": false,
	"is_empty": true
}

# === EXPORTS ===
@export var slot_index: int = 0
@export var show_kick_button: bool = false  # Only for host
@export var clickable: bool = true

# === NODE REFERENCES ===
# Main structure (from scene)
@onready var effect_overlay: Control = $EffectOverlay
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox_container: VBoxContainer = $MarginContainer/VBoxContainer

# Top: Name
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel

# Middle: Profile + Stats
@onready var middle_section: HBoxContainer = $MarginContainer/VBoxContainer/MiddleSection
@onready var profile_container: Control = $MarginContainer/VBoxContainer/MiddleSection/ProfileContainer
@onready var stats_panel: PanelContainer = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel
@onready var stats_vbox: VBoxContainer = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox

# Stats (using scene nodes)
@onready var mmr_label: Label = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox/MMRLabel
@onready var win_rate_label: Label = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox/WinRateLabel
@onready var games_label: Label = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox/GamesLabel

# Bottom: Display items
@onready var bot_section: PanelContainer = $MarginContainer/VBoxContainer/BotSection
@onready var display_container: HBoxContainer = $MarginContainer/VBoxContainer/BotSection/DisplayContainer

# Overlay controls
@onready var kick_button: Button = $KickButton
@onready var ready_sign: TextureRect = $ReadySign

# === MEMBER VARIABLES ===
var profile_frame: PanelContainer = null  # Will be created dynamically
var display_cards: Array[PanelContainer] = []  # Will hold the 3 display cards
var player_data: Dictionary = {}
var is_empty: bool = true
var plus_label: Label = null  # For empty state
var applied_theme: ProceduralMiniProfileCard = null  # NEW: For custom themes

# === LIFECYCLE ===

func _ready() -> void:
	# Setup base appearance
	_setup_card_style()
	
	# Configure existing scene nodes
	_configure_scene_nodes()
	
	# Create dynamic components
	_create_profile_frame()
	_create_display_cards()
	
	# Setup controls
	_setup_overlay_controls()
	
	# Connect input
	if clickable:
		gui_input.connect(_on_gui_input)
	
	# Test mode if running directly
	if get_tree().current_scene == self:
		await get_tree().process_frame
		_test_card_states()

# === CONFIGURATION ===

func _configure_scene_nodes() -> void:
	"""Configure the nodes that exist in the scene"""
	
	# Effect overlay for future use
	if effect_overlay:
		effect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Name label styling - Using UIStyleManager typography
	if name_label:
		var name_font_size = UIStyleManager.typography["size_body_large"] if UIStyleManager else 20
		
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.set_offsets_preset(Control.PRESET_TOP_WIDE)
		name_label.offset_left = 0
		name_label.offset_right = -10
		name_label.custom_minimum_size = Vector2(0, 26)
	
	# Profile container setup
	if profile_container:
		profile_container.clip_contents = false
		profile_container.custom_minimum_size = Vector2(75, 75)
		profile_container.size = Vector2(75, 75)
	
	# Stats panel setup with padding
	if stats_panel:
		stats_panel.custom_minimum_size = Vector2(100, 65)
		stats_panel.modulate = Color.WHITE
		var panel_style = stats_panel.get_theme_stylebox("panel")
		if not panel_style:
			panel_style = StyleBoxFlat.new()
			panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.2)
			panel_style.border_color = Color(0.2, 0.2, 0.2, 0.3)
			panel_style.set_border_width_all(1)
			panel_style.set_corner_radius_all(4)
		if panel_style is StyleBoxFlat:
			panel_style.set_content_margin_all(4)
			stats_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Stats VBox setup
	if stats_vbox:
		stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_vbox.add_theme_constant_override("separation", 1)
	
	# Configure emoji stats labels
	_configure_stat_labels()
	
	# Bottom section styling
	if bot_section:
		var bot_style = StyleBoxFlat.new()
		bot_style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
		bot_style.border_color = Color(0.3, 0.3, 0.3, 0.3)
		bot_style.set_border_width_all(1)
		bot_style.set_corner_radius_all(4)
		bot_section.add_theme_stylebox_override("panel", bot_style)
		bot_section.custom_minimum_size = Vector2(0, 68)
	
	# Display container setup
	if display_container:
		display_container.alignment = BoxContainer.ALIGNMENT_CENTER
		display_container.add_theme_constant_override("separation", 6)

func _configure_stat_labels() -> void:
	"""Configure the stat labels for emoji display using UIStyleManager typography"""
	var labels = [mmr_label, win_rate_label, games_label]
	
	var stat_font_size = 16
	if UIStyleManager and UIStyleManager.typography:
		stat_font_size = UIStyleManager.typography.get("size_body_small", 16)
	
	for label in labels:
		if label:
			label.add_theme_font_size_override("font_size", stat_font_size)
			label.custom_minimum_size = Vector2(80, 20)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.modulate = Color.WHITE

func _setup_card_style() -> void:
	"""Setup the main panel style"""
	# Check if we have a custom theme applied
	if applied_theme:
		_apply_theme_styles()
		return
	
	# Default style if no theme
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style.set_corner_radius_all(8)
	
	add_theme_stylebox_override("panel", style)
	
	# Don't clip contents to allow animations
	clip_contents = false
	if margin_container:
		margin_container.clip_contents = false
	if vbox_container:
		vbox_container.clip_contents = false
	if middle_section:
		middle_section.clip_contents = false

func _setup_overlay_controls() -> void:
	"""Setup kick button and ready sign"""
	if kick_button:
		kick_button.pressed.connect(_on_kick_button_pressed)
		kick_button.visible = false
		kick_button.text = "✕"
		kick_button.add_theme_font_size_override("font_size", 16)
		kick_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		kick_button.size = Vector2(20, 20)
	
	if ready_sign:
		ready_sign.visible = false
		ready_sign.size = Vector2(24, 24)

# === DYNAMIC COMPONENT CREATION ===

func _create_profile_frame() -> void:
	"""Create ProfileFrame dynamically"""
	var frame_scene_path = "res://Pyramids/scenes/ui/components/ProfileFrame.tscn"
	if not ResourceLoader.exists(frame_scene_path):
		push_error("ProfileFrame.tscn not found at: " + frame_scene_path)
		var fallback = ColorRect.new()
		fallback.color = Color(0.3, 0.3, 0.3, 1.0)
		fallback.size = Vector2(60, 60)
		fallback.position = Vector2(10, 3)
		profile_container.add_child(fallback)
		return
	
	var frame_scene = load(frame_scene_path)
	profile_frame = frame_scene.instantiate()
	
	profile_frame.frame_size = 60
	profile_frame.show_level = true
	profile_frame.enable_animations = true
	
	profile_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	profile_frame.position = Vector2(10, 3)
	profile_frame.size = Vector2(60, 60)
	
	profile_container.add_child(profile_frame)
	profile_frame.frame_clicked.connect(_on_profile_frame_clicked)

func _create_display_cards() -> void:
	"""Create 3 DisplayItemCard instances"""
	if not display_container:
		return
	
	for child in display_container.get_children():
		if child.name.begins_with("DisplayCard"):
			continue
		child.queue_free()
	
	var card_scene_path = "res://Pyramids/scenes/ui/components/DisplayItemCard.tscn"
	var has_scene = ResourceLoader.exists(card_scene_path)
	
	display_cards.clear()
	for i in range(3):
		var card
		
		if has_scene:
			var scene = load(card_scene_path)
			card = scene.instantiate()
		else:
			card = PanelContainer.new()
			card.set_script(preload("res://Pyramids/scripts/ui/components/DisplayItemCard.gd"))
		
		card.custom_minimum_size = Vector2(50, 50)
		card.size = Vector2(50, 50)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		card.name = "DisplayCard%d" % (i + 1)
		display_container.add_child(card)
		display_cards.append(card)
		
		if card.has_signal("clicked"):
			card.clicked.connect(_on_display_item_clicked)

# === STATE MANAGEMENT ===

func set_player_data(data: Dictionary) -> void:
	"""Main entry point for updating card data"""
	player_data = data
	is_empty = data.get("is_empty", false)
	
	if is_empty:
		set_empty_state()
	else:
		set_occupied_state()

func set_empty_state() -> void:
	"""Configure for empty invite slot"""
	is_empty = true
	player_data = EMPTY_CARD_DATA.duplicate(true)
	
	_setup_empty_card_style()
	
	if name_label:
		name_label.text = "Invite Player"
		name_label.modulate = Color(0.5, 0.5, 0.5, 0.5)
		
		var invite_font_size = UIStyleManager.typography["size_body_small"] if UIStyleManager else 16
		
		name_label.add_theme_font_size_override("font_size", invite_font_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.offset_left = 0
		name_label.add_theme_constant_override("margin_left", 0)
	
	if profile_frame:
		profile_frame.visible = false
	
	_show_plus_symbol()
	
	if stats_panel:
		stats_panel.visible = false
	
	if bot_section:
		bot_section.visible = false
	
	if kick_button:
		kick_button.visible = false
	if ready_sign:
		ready_sign.visible = false

func set_occupied_state() -> void:
	"""Configure for occupied player slot"""
	is_empty = false
	
	_setup_occupied_card_style()
	
	_hide_plus_symbol()
	
	if name_label:
		name_label.text = player_data.get("name", "Player")
		name_label.modulate = Color.WHITE
		
		var name_font_size = UIStyleManager.typography["size_body_large"] if UIStyleManager else 20
		
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.offset_left = 10
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.visible = true
	
	if profile_frame:
		profile_frame.visible = true
		var level = player_data.get("level", 1)
		var prestige = player_data.get("prestige", 0)
		profile_frame.set_player_level(level, prestige)
		
		if profile_frame.has_method("set_frame_size"):
			profile_frame.set_frame_size(60)
		
		var frame_id = player_data.get("frame_id", "")
		if frame_id != "":
			profile_frame.set_custom_frame(frame_id)
	
	if stats_panel:
		stats_panel.visible = true
		stats_panel.modulate = Color.WHITE
	
	_update_stats_display()
	
	if bot_section:
		bot_section.visible = true
		_update_display_items()
	
	_update_overlay_controls()


func _setup_empty_card_style() -> void:
	"""Style for empty slots"""
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		style.bg_color = Color(0.1, 0.1, 0.1, 0.3)

func _setup_occupied_card_style() -> void:
	"""Style for occupied slots"""
	# Check if we have a custom theme applied
	if applied_theme:
		_apply_theme_styles()
		# Special handling for host (golden border)
		if player_data.get("is_host", false):
			var style = get_theme_stylebox("panel")
			if style and style is StyleBoxFlat:
				var host_style = style.duplicate()
				host_style.border_color = Color(1.0, 0.84, 0, 1.0)
				host_style.set_border_width_all(3)
				add_theme_stylebox_override("panel", host_style)
		return
	
	# Default style if no theme
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
		
		if player_data.get("is_host", false):
			style.border_color = Color(1.0, 0.84, 0, 1.0)
			style.set_border_width_all(3)

# === UPDATE FUNCTIONS ===

func _update_stats_display() -> void:
	"""Update stats with emoji format"""
	var stats = player_data.get("stats", {})
	
	var stat_font_size = 16
	if UIStyleManager and UIStyleManager.typography:
		stat_font_size = UIStyleManager.typography.get("size_body_small", 16)
	
	if mmr_label:
		var mmr = stats.get("mmr", 0)
		if mmr >= 1000:
			mmr_label.text = "👑 %.1fK" % (mmr / 1000.0)
		else:
			mmr_label.text = "👑 %d" % mmr
		mmr_label.modulate = Color.WHITE
		mmr_label.add_theme_color_override("font_color", Color.WHITE)
		mmr_label.add_theme_font_size_override("font_size", stat_font_size)
		mmr_label.visible = true
	
	if win_rate_label:
		var win_rate = stats.get("win_rate", 0.0)
		win_rate_label.text = "🎯 %d%%" % int(win_rate * 100)
		win_rate_label.modulate = Color.WHITE
		win_rate_label.add_theme_color_override("font_color", Color.WHITE)
		win_rate_label.add_theme_font_size_override("font_size", stat_font_size)
		win_rate_label.visible = true
	
	if games_label:
		var games = stats.get("games", 0)
		games_label.text = "⚔️ %d" % games
		games_label.modulate = Color.WHITE
		games_label.add_theme_color_override("font_color", Color.WHITE)
		games_label.add_theme_font_size_override("font_size", stat_font_size)
		games_label.visible = true

func _update_display_items() -> void:
	"""Update the 3 display item cards"""
	var display_items = player_data.get("display_items", ["", "", ""])
	
	for i in range(min(3, display_cards.size())):
		if i < display_items.size():
			var item_id = display_items[i]
			var card = display_cards[i]
			
			if item_id == "":
				if card.has_method("set_empty"):
					card.set_empty()
			else:
				if AchievementManager and AchievementManager.achievements.has(item_id):
					if card.has_method("set_achievement"):
						card.set_achievement(item_id)
				else:
					if card.has_method("set_item"):
						card.set_item(item_id)

func _update_overlay_controls() -> void:
	"""Update ready sign and kick button visibility"""
	if kick_button:
		kick_button.set_position(Vector2(size.x - 25, 5))
		var is_host_viewing = show_kick_button
		var is_self = player_data.get("is_host", false)
		kick_button.visible = is_host_viewing and not is_self and not is_empty
	
	if ready_sign:
		ready_sign.set_position(Vector2(5, 5))
		ready_sign.visible = player_data.get("is_ready", false)
		if ready_sign.visible and not ready_sign.texture:
			_create_ready_checkmark()

# === HELPER FUNCTIONS ===

func _show_plus_symbol() -> void:
	"""Show + symbol for empty state"""
	_hide_plus_symbol()
	
	plus_label = Label.new()
	plus_label.name = "PlusLabel"
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 32)
	plus_label.modulate = Color(0.5, 0.5, 0.5, 0.5)
	plus_label.set_anchors_preset(Control.PRESET_CENTER)
	plus_label.position = Vector2(-15, -20)
	plus_label.size = Vector2(30, 40)
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	profile_container.add_child(plus_label)

func _hide_plus_symbol() -> void:
	"""Remove plus symbol if it exists"""
	if plus_label and is_instance_valid(plus_label):
		plus_label.queue_free()
		plus_label = null
	
	for child in profile_container.get_children():
		if child.name == "PlusLabel":
			child.queue_free()

func _create_ready_checkmark() -> void:
	"""Create a simple checkmark texture"""
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	
	for x in range(24):
		for y in range(24):
			if (x >= 4 and x <= 8 and y >= 12 and y <= 16 - (x - 4)) or \
			   (x >= 8 and x <= 18 and y >= 16 - (x - 8) and y <= 18 - (x - 8)):
				image.set_pixel(x, y, Color(0.0, 1.0, 0.0, 1.0))
	
	var texture = ImageTexture.create_from_image(image)
	ready_sign.texture = texture

# === SIGNAL HANDLERS ===

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_empty:
				invite_clicked.emit(slot_index)
			else:
				var player_id = player_data.get("id", "")
				player_clicked.emit(player_id)

func _on_kick_button_pressed() -> void:
	var player_id = player_data.get("id", "")
	kick_requested.emit(player_id)

func _on_profile_frame_clicked() -> void:
	if not is_empty:
		var player_id = player_data.get("id", "")
		player_clicked.emit(player_id)

func _on_display_item_clicked(item_id: String, item_type: String) -> void:
	display_item_clicked.emit(item_id)

# === PUBLIC API ===

func set_ready(ready: bool) -> void:
	"""Set player ready state"""
	player_data["is_ready"] = ready
	_update_overlay_controls()

func set_host_viewing(is_host: bool) -> void:
	"""Set whether host is viewing (shows kick button)"""
	show_kick_button = is_host
	_update_overlay_controls()

func highlight() -> void:
	"""Highlight the card"""
	modulate = Color(1.2, 1.2, 1.2)

func unhighlight() -> void:
	"""Remove highlight"""
	modulate = Color.WHITE

# === PUBLIC API ===

func apply_mini_profile_theme(theme_id: String) -> void:
	"""Apply a mini profile card theme by ID"""
	if not theme_id or theme_id == "":
		applied_theme = null
		_setup_card_style()  # Reset to default
		return
	
	# Try to load the theme from ItemManager
	if ItemManager:
		var item = ItemManager.get_item(theme_id)
		if item and item.category == UnifiedItemData.Category.MINI_PROFILE_CARD:
			# Get the procedural instance
			if ProceduralItemRegistry:
				var instance = ProceduralItemRegistry.get_procedural_item(theme_id)
				if instance and instance is ProceduralMiniProfileCard:
					applied_theme = instance
					_apply_theme_styles()
				else:
					push_warning("Mini profile theme not found in registry: " + theme_id)
			else:
				push_warning("ProceduralItemRegistry not available")
		else:
			push_warning("Invalid mini profile theme ID: " + theme_id)

func _apply_theme_styles() -> void:
	"""Apply the current theme to all panels"""
	if not applied_theme:
		return
	
	# Apply to main panel
	var main_style = applied_theme.get_main_panel_style()
	if main_style:
		add_theme_stylebox_override("panel", main_style)
	
	# Apply to stats panel
	if stats_panel:
		var stats_style = applied_theme.get_stats_panel_style()
		if stats_style:
			stats_panel.add_theme_stylebox_override("panel", stats_style)
	
	# Apply to bottom section
	if bot_section:
		var bot_style = applied_theme.get_bot_section_style()
		if bot_style:
			bot_section.add_theme_stylebox_override("panel", bot_style)

# === DEBUG FUNCTIONS ===

func debug_populate_with_mock_data() -> void:
	"""Populate with test data"""
	var mock_data = {
		"id": "player_test",
		"name": "TestPlayer",
		"level": 42,
		"prestige": 8,
		"stats": {
			"games": 250,
			"win_rate": 0.68,
			"mmr": 2450
		},
		"frame_id": "",
		"display_items": ["first_game", "", "combo_5"],
		"is_ready": false,
		"is_host": false,
		"is_empty": false
	}
	print("Setting mock player data...")
	set_player_data(mock_data)

func _test_card_states() -> void:
	"""Run through different card states for testing"""
	print("=== Testing MiniProfileCard States ===")
	
	print("Test 1: Empty card")
	set_empty_state()
	await get_tree().create_timer(2.0).timeout
	
	print("Test 2: Regular player")
	debug_populate_with_mock_data()
	await get_tree().create_timer(2.0).timeout
	
	print("Test 3: Ready state")
	set_ready(true)
	await get_tree().create_timer(2.0).timeout
	
	print("=== Test Complete ===")

func debug_check_nodes() -> void:
	"""Debug function to verify all nodes are found"""
	print("=== NODE CHECK ===")
	print("stats_panel exists: ", stats_panel != null)
	print("stats_vbox exists: ", stats_vbox != null)
	print("mmr_label exists: ", mmr_label != null)
	print("win_rate_label exists: ", win_rate_label != null)
	print("games_label exists: ", games_label != null)
	
	if stats_panel:
		print("stats_panel path: ", stats_panel.get_path())
		print("stats_panel visible: ", stats_panel.visible)
	
	if stats_vbox:
		print("stats_vbox children count: ", stats_vbox.get_child_count())
		for child in stats_vbox.get_children():
			print("  - Child: ", child.name, " type: ", child.get_class())
