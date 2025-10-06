# MultiplayerRoundScore.gd - Display round scores for all players
# Location: res://Pyramids/scripts/ui/game_ui/MultiplayerRoundScore.gd
# Last Updated: Initial implementation with emoji lanes [Date]

extends Control

# === CONSTANTS ===
const COUNTDOWN_TIME = 5
const MAX_PLAYERS = 8
const EMOJI_FLOAT_HEIGHT = 600  # How high emojis float
const EMOJI_DURATION = 4.0  # Time for emoji to float up

# === NODE REFERENCES ===
@onready var background: ColorRect = $Background
@onready var styled_panel: PanelContainer = $StyledPanel
@onready var margin_container: MarginContainer = $StyledPanel/MarginContainer
@onready var vbox_container: VBoxContainer = $StyledPanel/MarginContainer/VBoxContainer
@onready var title_label: Label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var grid_container: GridContainer = $StyledPanel/MarginContainer/VBoxContainer/GridContainer
@onready var bottom_hbox: HBoxContainer = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox
@onready var continue_button: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/ContinueButton
@onready var emoji_button_1: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton1
@onready var emoji_button_2: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton2
@onready var emoji_button_3: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton3
@onready var emoji_button_4: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton4

# === PROPERTIES ===
var current_round: int = 1
var max_rounds: int = 10
var countdown_timer: float = COUNTDOWN_TIME
var is_counting_down: bool = false
var player_scores: Array = []  # Array of player score dictionaries
var local_player_id: String = "player_local"
var is_final_round: bool = false

# Emoji system
var emoji_buttons: Array = []
var emoji_on_cooldown: bool = false
var emoji_cooldown_tweens: Array = []
var emoji_lanes: Array = []  # 8 lanes for emoji display

# Mock data for testing
var mock_players = [
	{"id": "player_local", "name": "You", "mmr": 1200, "color": Color.GREEN},
	{"id": "player_2", "name": "Pharaoh", "mmr": 1350, "color": Color.BLUE},
	{"id": "player_3", "name": "Cleopatra", "mmr": 1100, "color": Color.MAGENTA},
	{"id": "player_4", "name": "Sphinx", "mmr": 1250, "color": Color.ORANGE},
	{"id": "player_5", "name": "Anubis", "mmr": 1400, "color": Color.RED},
	{"id": "player_6", "name": "Ra", "mmr": 1050, "color": Color.YELLOW},
	{"id": "player_7", "name": "Osiris", "mmr": 1150, "color": Color.CYAN},
	{"id": "player_8", "name": "Thoth", "mmr": 1300, "color": Color.PURPLE}
]

func _ready():
	_setup_ui()
	_setup_emoji_system()
	_create_emoji_lanes()
	_connect_signals()
	_apply_styling()
	
	# Start with mock data if running directly
	if get_tree().current_scene == self:
		setup(3, 10)  # Round 3 of 10
		display_round_scores(_generate_mock_scores())

func _process(delta):
	if is_counting_down:
		countdown_timer -= delta
		if countdown_timer <= 0:
			_handle_continue()
		else:
			_update_continue_button_text()

# === SETUP ===

func _setup_ui():
	"""Initialize UI structure"""
	# Set window size for testing
	if get_tree().current_scene == self:
		get_window().size = Vector2(600, 800)
	
	# Configure grid for player scores
	grid_container.columns = 6  # Icon | Rank | Change | Name | Total | Round

func _setup_emoji_system():
	"""Load equipped emojis into buttons - matches GameLobby pattern"""
	emoji_buttons = [emoji_button_1, emoji_button_2, emoji_button_3, emoji_button_4]
	
	if not EquipmentManager:
		# Fallback for testing
		_setup_mock_emojis()
		return
		
	var equipped_emojis = EquipmentManager.get_equipped_emojis()
	
	for i in range(4):
		var button = emoji_buttons[i]
		if i < equipped_emojis.size():
			var emoji_id = equipped_emojis[i]
			if ItemManager:
				var item = ItemManager.get_item(emoji_id)
				if item and item.get("texture_path"):
					_configure_emoji_button(button, item, i)
				else:
					button.visible = false
		else:
			button.visible = false

func _configure_emoji_button(button: Button, emoji_item: UnifiedItemData, index: int):
	"""Configure a single emoji button - matches GameLobby pattern"""
	button.visible = true
	button.text = ""
	button.tooltip_text = emoji_item.display_name
	
	if UIStyleManager:
		UIStyleManager.apply_button_style(button, "transparent", "medium")
	
	var texture_path = emoji_item.texture_path if emoji_item else ""
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		button.icon = texture
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.custom_minimum_size = Vector2(48, 48)
	
	button.set_meta("emoji_id", emoji_item.id)
	button.set_meta("emoji_item", emoji_item)
	button.set_meta("button_index", index)

func _setup_mock_emojis():
	"""Setup mock emojis for testing when managers aren't available"""
	# Create mock emoji data for testing
	var mock_emojis = [
		{"id": "emoji_happy", "display_name": "Happy", "texture_path": ""},
		{"id": "emoji_sad", "display_name": "Sad", "texture_path": ""},
		{"id": "emoji_angry", "display_name": "Angry", "texture_path": ""},
		{"id": "emoji_love", "display_name": "Love", "texture_path": ""}
	]
	
	for i in range(emoji_buttons.size()):
		var button = emoji_buttons[i]
		if i < mock_emojis.size():
			button.visible = true
			button.text = ["🎉", "😢", "😠", "❤️"][i]  # Fallback emoji text
			button.tooltip_text = mock_emojis[i].display_name
			button.set_meta("emoji_id", mock_emojis[i].id)
			button.set_meta("emoji_item", mock_emojis[i])
			button.custom_minimum_size = Vector2(48, 48)
			
			if UIStyleManager:
				UIStyleManager.apply_button_style(button, "transparent", "medium")
		else:
			button.visible = false

func _create_emoji_lanes():
	"""Create 8 vertical lanes for emoji display - centered on screen"""
	emoji_lanes.clear()
	
	# Create container for emoji lanes with proper z-index
	var emoji_container = Control.new()
	emoji_container.name = "EmojiContainer"
	emoji_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emoji_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_container.z_index = 10  # Higher than panel
	add_child(emoji_container)
	
	# For 1200px screen width - center the lanes
	var viewport_width = 1200  # Your actual screen width
	var lanes_total_width = 800  # Total width for all 8 lanes
	var lane_width = lanes_total_width / MAX_PLAYERS  # 100px per lane
	var start_x = (viewport_width - lanes_total_width) / 2  # This gives us 200px margin on each side
	
	# Create 8 lanes centered on screen
	for i in range(MAX_PLAYERS):
		var lane = Control.new()
		lane.name = "EmojiLane%d" % i
		lane.position.x = start_x + (i * lane_width) + (lane_width / 2)
		lane.size.x = lane_width
		lane.size.y = get_viewport().size.y
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emoji_container.add_child(lane)
		emoji_lanes.append(lane)


func _connect_signals():
	"""Connect all UI signals"""
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect emoji buttons - same as GameLobby
	if emoji_button_1:
		emoji_button_1.pressed.connect(func(): _on_emoji_pressed(0))
	if emoji_button_2:
		emoji_button_2.pressed.connect(func(): _on_emoji_pressed(1))
	if emoji_button_3:
		emoji_button_3.pressed.connect(func(): _on_emoji_pressed(2))
	if emoji_button_4:
		emoji_button_4.pressed.connect(func(): _on_emoji_pressed(3))

func _apply_styling():
	"""Apply theme styling to UI elements"""
	# Background gradient
	if background:
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(0.1, 0.1, 0.2, 0.95))
		gradient.add_point(1.0, Color(0.2, 0.1, 0.3, 0.95))
		# Apply gradient shader if needed
	
	# Make panel wider
	if styled_panel:
		styled_panel.custom_minimum_size.x = 450  # Was 500, now 550
	
	# Add more padding to margin container for wider grid
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 25)  # Was 20
		margin_container.add_theme_constant_override("margin_right", 25)  # Was 20
	
	# Panel is StyledPanel - it styles itself
	# Continue button is StyledButton - it styles itself
	
	# Title styling - using ThemeConstants
	if title_label and ThemeConstants:
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_title)  # 24
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)

# === PUBLIC API ===

func setup(round: int, total_rounds: int):
	"""Setup the score screen for a specific round"""
	current_round = round
	max_rounds = total_rounds
	is_final_round = (round == total_rounds)
	
	if title_label:
		if is_final_round:
			title_label.text = "Final Results!"
		else:
			title_label.text = "Round %d of %d Complete!" % [round, total_rounds]
	
	countdown_timer = COUNTDOWN_TIME
	is_counting_down = true
	_update_continue_button_text()

func display_round_scores(scores: Array):
	"""Display the scores for all players"""
	player_scores = scores
	_populate_grid()

# === PRIVATE HELPERS ===

func _generate_mock_scores() -> Array:
	"""Generate mock scores for testing"""
	var scores = []
	
	# Dynamic player count (not always 8)
	var player_count = randi_range(4, 8)
	var active_players = mock_players.slice(0, player_count)
	
	# Generate random scores for this round
	for player in active_players:
		var round_score = randi_range(500, 950)
		var total_score = round_score * current_round + randi_range(-200, 200)
		
		scores.append({
			"player_id": player.id,
			"name": player.name,
			"round_score": round_score,
			"total_score": total_score,
			"is_eliminated": false,
			"status": "playing"  # playing, done, disconnected
		})
	
	# Sort by total score to get current positions
	scores.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	# Add current positions
	for i in range(scores.size()):
		scores[i]["position"] = i + 1
	
	# Generate realistic previous positions
	# Shuffle slightly for position changes
	var previous_scores = scores.duplicate(true)
	for i in range(previous_scores.size()):
		# Add some randomness to previous round totals
		previous_scores[i]["total_score"] += randi_range(-100, 100)
	
	# Sort previous scores to get previous positions
	previous_scores.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	# Map previous positions back to current scores
	for i in range(previous_scores.size()):
		var player_id = previous_scores[i]["player_id"]
		# Find this player in current scores
		for j in range(scores.size()):
			if scores[j]["player_id"] == player_id:
				scores[j]["previous_position"] = i + 1
				scores[j]["position_change"] = scores[j]["previous_position"] - scores[j]["position"]
				break
	
	# Mark bottom 2 for elimination in certain modes (only if we have enough players)
	if scores.size() >= 3:  # Need at least 3 players for elimination to make sense
		for i in range(scores.size()):
			if i >= scores.size() - 2 and current_round > 2:
				scores[i]["is_eliminated"] = true
	
	return scores

func _populate_grid():
	"""Populate the grid with player scores"""
	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
	
	# Add header row
	_add_header_row()
	
	# Add player rows
	for i in range(player_scores.size()):
		var score_data = player_scores[i]
		_add_player_row(score_data, i)

func _add_header_row():
	"""Add header labels to grid"""
	var headers = ["", "Rank", "Change", "Player", "Total", "Round"]
	
	for header_text in headers:
		var label = Label.new()
		label.text = header_text
		if ThemeConstants:
			label.add_theme_color_override("font_color", ThemeConstants.colors.gray_500)  # Lighter for headers
			label.add_theme_font_size_override("font_size", 20)  # 24 for headers
		else:
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_container.add_child(label)

func _add_player_row(score_data: Dictionary, index: int):
	"""Add a player's score row to the grid"""
	var is_local = score_data.player_id == local_player_id
	
	# Icon/Sprite column - using actual icon files
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(24, 24)
	
	if score_data.position == 1:
		# Crown icon for first place
		var crown_icon = TextureRect.new()
		crown_icon.texture = load("res://Pyramids/assets/icons/menu/crown_icon.png")
		crown_icon.custom_minimum_size = Vector2(24, 24)
		crown_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		crown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(crown_icon)
	elif score_data.is_eliminated:
		# Skull icon for eliminated
		var skull_icon = TextureRect.new()
		skull_icon.texture = load("res://Pyramids/assets/icons/menu/skull_icon.png")
		skull_icon.custom_minimum_size = Vector2(24, 24)
		skull_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		skull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(skull_icon)
	elif score_data.status == "disconnected":
		# Keep emoji for disconnected since no icon provided
		var disconnect_label = Label.new()
		disconnect_label.text = "🔌"
		disconnect_label.add_theme_font_size_override("font_size", 20)
		icon_container.add_child(disconnect_label)
	
	grid_container.add_child(icon_container)
	
	# Rank column
	var rank_label = Label.new()
	rank_label.text = str(score_data.position)
	if ThemeConstants:
		rank_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18
		if is_local:
			rank_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
		else:
			rank_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
	else:
		rank_label.add_theme_font_size_override("font_size", 18)
		rank_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.WHITE)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(rank_label)
	
	# Position change column
	var change_label = Label.new()
	if score_data.position_change > 0:
		change_label.text = "↑%d" % abs(score_data.position_change)
		change_label.add_theme_color_override("font_color", ThemeConstants.colors.success if ThemeConstants else Color.GREEN)
	elif score_data.position_change < 0:
		change_label.text = "↓%d" % abs(score_data.position_change)
		change_label.add_theme_color_override("font_color", ThemeConstants.colors.error if ThemeConstants else Color.RED)
	else:
		change_label.text = "—"
		change_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_500 if ThemeConstants else Color.GRAY)
	if ThemeConstants:
		change_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18
	else:
		change_label.add_theme_font_size_override("font_size", 18)
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(change_label)
	
	# Name column
	var name_label = Label.new()
	name_label.text = score_data.name
	if ThemeConstants:
		name_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18
		if is_local:
			name_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
		else:
			name_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
	else:
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.WHITE)
	grid_container.add_child(name_label)
	
	# Total score column
	var total_label = Label.new()
	total_label.text = str(score_data.total_score)
	if ThemeConstants:
		total_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18
		if is_local:
			total_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
		else:
			total_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
	else:
		total_label.add_theme_font_size_override("font_size", 18)
		total_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.WHITE)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(total_label)
	
	# Round score column
	var round_label = Label.new()
	round_label.text = str(score_data.round_score)
	if ThemeConstants:
		round_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)  # 18
		round_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
	else:
		round_label.add_theme_font_size_override("font_size", 18)
		round_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(round_label)

func _update_continue_button_text():
	"""Update continue button with countdown"""
	if continue_button:
		continue_button.text = "Continue (%d)" % ceil(countdown_timer)

func _handle_continue():
	"""Handle continuation to next round"""
	is_counting_down = false
	
	# Emit signal or change scene
	if SignalBus and SignalBus.has_signal("round_score_continue"):
		SignalBus.round_score_continue.emit()
	
	# For testing, just hide
	if get_tree().current_scene == self:
		print("Continuing to next round...")
		queue_free()

# === EMOJI SYSTEM ===

func _on_emoji_pressed(emoji_index: int):
	"""Handle emoji button press"""
	if emoji_on_cooldown:
		return
	
	var button = emoji_buttons[emoji_index]
	var emoji_id = button.get_meta("emoji_id", "")
	var emoji_item = button.get_meta("emoji_item", null)
	
	if emoji_id == "":
		return
	
	# Find local player's lane index
	var lane_index = 0
	for i in range(player_scores.size()):
		if player_scores[i].player_id == local_player_id:
			lane_index = i
			break
	
	# Create floating emoji in the player's lane
	_create_floating_emoji(emoji_item, lane_index, "You")
	
	# Start cooldown
	_start_global_emoji_cooldown()
	
	# TODO: Send emoji to network
	print("Emoji sent: %s" % emoji_id)

func _start_global_emoji_cooldown():
	"""Start cooldown animation on ALL emoji buttons - matches GameLobby pattern"""
	if emoji_on_cooldown:
		return
	
	emoji_on_cooldown = true
	emoji_cooldown_tweens.clear()
	
	for i in range(emoji_buttons.size()):
		var button = emoji_buttons[i]
		if not button.visible:
			continue
		
		button.disabled = true
		button.modulate = Color(0.3, 0.3, 0.3, 1.0)
		
		var tween = create_tween()
		tween.tween_property(button, "modulate", Color.WHITE, 3.0)
		emoji_cooldown_tweens.append(tween)
		
		if i == emoji_buttons.size() - 1:
			tween.tween_callback(func():
				_clear_emoji_cooldown()
			)

func _clear_emoji_cooldown():
	"""Clear cooldown and reset emoji buttons"""
	for button in emoji_buttons:
		button.disabled = false
		button.modulate = Color.WHITE
	
	emoji_cooldown_tweens.clear()
	emoji_on_cooldown = false

func _create_floating_emoji(emoji_item, lane_index: int, player_name: String):
	"""Create a floating emoji in the specified lane"""
	if lane_index >= emoji_lanes.size():
		return
	
	var lane = emoji_lanes[lane_index]
	
	# Create container for emoji and name
	var emoji_container = VBoxContainer.new()
	emoji_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_container.custom_minimum_size = Vector2(60, 80)
	
	# Start emoji at bottom of visible screen
	var screen_height = 550
	emoji_container.position.y = screen_height - 50  # Start 50px from bottom (visible)
	emoji_container.position.x = 0
	
	# Create emoji display (texture or text fallback)
	if emoji_item and emoji_item.texture_path != null and emoji_item.texture_path != "":
		# Use actual emoji texture
		var texture_rect = TextureRect.new()
		if ResourceLoader.exists(emoji_item.texture_path):
			texture_rect.texture = load(emoji_item.texture_path)
		texture_rect.custom_minimum_size = Vector2(48, 48)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emoji_container.add_child(texture_rect)
	else:
		# Fallback to text for testing
		var emoji_label = Label.new()
		var test_emojis = {"emoji_happy": "🎉", "emoji_sad": "😢", "emoji_angry": "😠", "emoji_love": "❤️"}
		var emoji_id = emoji_item.id if emoji_item and emoji_item.id != null else ""
		emoji_label.text = test_emojis.get(emoji_id, "❓")
		emoji_label.add_theme_font_size_override("font_size", 32)
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_container.add_child(emoji_label)
	
	# Create name label - make it more visible
	var name_label = Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 16)  # Bigger than before
	name_label.add_theme_color_override("font_color", Color.WHITE)  # White for visibility
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_container.add_child(name_label)
	
	lane.add_child(emoji_container)
	
	# Animate floating up - will travel exactly screen height + a bit
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(emoji_container, "position:y", -25, EMOJI_DURATION)  # End just above screen
	tween.tween_property(emoji_container, "modulate:a", 0.5, EMOJI_DURATION)
	tween.chain().tween_callback(func(): emoji_container.queue_free())

# === PUBLIC API FOR NETWORK UPDATES ===

func receive_emoji(player_id: String, emoji_id: String):
	"""Receive emoji from another player"""
	# Find player's lane index
	var lane_index = 0
	var player_name = "Unknown"
	
	for i in range(player_scores.size()):
		if player_scores[i].player_id == player_id:
			lane_index = i
			player_name = player_scores[i].name
			break
	
	# Get emoji item from ItemManager
	var emoji_item = null
	if ItemManager:
		emoji_item = ItemManager.get_item(emoji_id)
	
	# Fallback emoji data for testing
	if not emoji_item:
		emoji_item = {"id": emoji_id, "display_name": emoji_id, "texture_path": ""}
	
	# Create floating emoji
	_create_floating_emoji(emoji_item, lane_index, player_name)
	
func _on_continue_pressed():
	"""Handle continue button press"""
	_handle_continue()
	
