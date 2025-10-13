# MultiplayerScoreScreen.gd - Display round scores for all players
# Location: res://Pyramids/scripts/ui/game_ui/MultiplayerScoreScreen.gd
# Last Updated: Connected to NetworkManager, proper signal flow

extends Control

# === CONSTANTS ===
const COUNTDOWN_TIME = 5
const MAX_PLAYERS = 8
const EMOJI_FLOAT_HEIGHT = 600
const EMOJI_DURATION = 4.0

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
var player_scores: Array = []
var local_player_id: String = ""
var is_final_round: bool = false
var waiting_for_network: bool = true
var all_players_ready: bool = false
var check_timer: Timer
var expected_player_count: int = 1

# Emoji system
var emoji_buttons: Array = []
var emoji_on_cooldown: bool = false
var emoji_cooldown_tweens: Array = []
var emoji_lanes: Array = []

# Debug
var debug_enabled: bool = true

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[MultiplayerScoreScreen] %s" % message)

func _ready():
	debug_log("Score screen loaded for round %d" % current_round)
	
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		local_player_id = supabase.current_user.get("id", "")
	
	_setup_ui()
	_setup_emoji_system()
	_create_emoji_lanes()
	_connect_signals()
	_apply_styling()
	
	# Setup check timer for waiting for all players
	check_timer = Timer.new()
	check_timer.wait_time = 1.5
	check_timer.timeout.connect(_check_all_players_ready)
	add_child(check_timer)
	
	# Get expected player count from lobby
	if has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		var lobby_data = net_manager.get_current_lobby()
		expected_player_count = lobby_data.get("players", []).size()
		if expected_player_count == 0:
			expected_player_count = 1
	
	_connect_network_signals()

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
	if title_label:
		if is_final_round:
			title_label.text = "Final Results!"
		else:
			title_label.text = "Round %d of %d Complete!" % [current_round, max_rounds]
	
	# Configure grid for player scores
	if grid_container:
		grid_container.columns = 6  # Icon | Rank | Change | Name | Total | Round

func _setup_emoji_system():
	"""Load equipped emojis into buttons"""
	emoji_buttons = [emoji_button_1, emoji_button_2, emoji_button_3, emoji_button_4]
	
	if not has_node("/root/EquipmentManager"):
		_setup_mock_emojis()
		return
		
	var equipment = get_node("/root/EquipmentManager")
	var equipped_emojis = equipment.get_equipped_emojis()
	
	for i in range(4):
		var button = emoji_buttons[i]
		if i < equipped_emojis.size():
			var emoji_id = equipped_emojis[i]
			if has_node("/root/ItemManager"):
				var item_manager = get_node("/root/ItemManager")
				var item = item_manager.get_item(emoji_id)
				if item and item.get("texture_path"):
					_configure_emoji_button(button, item, i)
				else:
					button.visible = false
		else:
			button.visible = false

func _configure_emoji_button(button: Button, emoji_item, index: int):
	"""Configure a single emoji button"""
	button.visible = true
	button.text = ""
	button.tooltip_text = emoji_item.display_name if emoji_item else ""
	
	if has_node("/root/UIStyleManager"):
		var style_manager = get_node("/root/UIStyleManager")
		style_manager.apply_button_style(button, "transparent", "medium")
	
	var texture_path = emoji_item.texture_path if emoji_item else ""
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		button.icon = texture
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.custom_minimum_size = Vector2(48, 48)
	
	button.set_meta("emoji_id", emoji_item.id if emoji_item else "")
	button.set_meta("emoji_item", emoji_item)
	button.set_meta("button_index", index)

func _setup_mock_emojis():
	"""Setup mock emojis for testing"""
	for i in range(emoji_buttons.size()):
		var button = emoji_buttons[i]
		button.visible = true
		button.text = ["🎉", "😢", "😠", "❤️"][i]
		button.custom_minimum_size = Vector2(48, 48)
		button.set_meta("emoji_id", "emoji_test_%d" % i)
		button.set_meta("emoji_item", {"id": "emoji_test_%d" % i, "display_name": "Test", "texture_path": ""})

func _create_emoji_lanes():
	"""Create 8 vertical lanes for emoji display"""
	emoji_lanes.clear()
	
	var emoji_container = Control.new()
	emoji_container.name = "EmojiContainer"
	emoji_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emoji_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_container.z_index = 10
	add_child(emoji_container)
	
	var viewport_width = 1200
	var lanes_total_width = 800
	var lane_width = lanes_total_width / MAX_PLAYERS
	var start_x = (viewport_width - lanes_total_width) / 2
	
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
	
	if emoji_button_1:
		emoji_button_1.pressed.connect(func(): _on_emoji_pressed(0))
	if emoji_button_2:
		emoji_button_2.pressed.connect(func(): _on_emoji_pressed(1))
	if emoji_button_3:
		emoji_button_3.pressed.connect(func(): _on_emoji_pressed(2))
	if emoji_button_4:
		emoji_button_4.pressed.connect(func(): _on_emoji_pressed(3))

func _connect_network_signals():
	"""Connect to NetworkManager signals"""
	if not has_node("/root/NetworkManager"):
		debug_log("WARNING: NetworkManager not found!")
		return
	
	var net_manager = get_node("/root/NetworkManager")
	
	if not net_manager.round_scores_ready.is_connected(_on_round_scores_ready):
		net_manager.round_scores_ready.connect(_on_round_scores_ready)
		debug_log("Connected to NetworkManager.round_scores_ready")

func _apply_styling():
	"""Apply theme styling"""
	if background:
		background.z_index = -1
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(0.1, 0.1, 0.2, 0.95))
		gradient.add_point(1.0, Color(0.2, 0.1, 0.3, 0.95))
	
	if styled_panel:
		styled_panel.custom_minimum_size.x = 550
		styled_panel.z_index = 1
	
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 25)
		margin_container.add_theme_constant_override("margin_right", 25)
	
	if title_label and has_node("/root/ThemeConstants"):
		var theme = get_node("/root/ThemeConstants")
		title_label.add_theme_font_size_override("font_size", theme.typography.size_title)
		title_label.add_theme_color_override("font_color", theme.colors.primary)

# === PUBLIC API ===

func setup(round: int, total_rounds: int):
	"""Setup the score screen for a specific round"""
	current_round = round
	max_rounds = total_rounds
	is_final_round = (round == total_rounds)
	
	debug_log("Setup: Round %d of %d" % [round, total_rounds])
	
	if title_label:
		if is_final_round:
			title_label.text = "Final Round Complete!"
		else:
			title_label.text = "Round %d of %d Complete!" % [round, total_rounds]
	
	waiting_for_network = true
	all_players_ready = false
	if continue_button:
		continue_button.text = "Waiting for players..."
		continue_button.disabled = true

func display_round_scores(scores: Array):
	"""Display the scores for all players"""
	debug_log("Displaying %d player scores" % scores.size())
	player_scores = scores
	_populate_grid()
	
	# Don't auto-start countdown anymore
	# if scores.size() > 0:
	#     _start_countdown()

# === NETWORK HANDLERS ===

func _on_round_scores_ready(scores: Array):
	"""Handle scores from NetworkManager"""
	debug_log("✅ Received scores from network: %d players" % scores.size())
	waiting_for_network = false
	display_round_scores(scores)
	
	# Check if all players are done
	if _check_player_count(scores):
		all_players_ready = true
		if check_timer:
			check_timer.stop()
		_start_countdown()
	else:
		# Not all players done yet
		debug_log("Waiting for all players to finish...")
		if continue_button:
			continue_button.text = "Waiting for players..."
			continue_button.disabled = true
		
		# Start checking periodically
		if not check_timer.is_stopped():
			check_timer.start()

# === PRIVATE HELPERS ===

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
	
	var theme_colors = null
	if has_node("/root/ThemeConstants"):
		theme_colors = get_node("/root/ThemeConstants")
	
	for header_text in headers:
		var label = Label.new()
		label.text = header_text
		if theme_colors:
			label.add_theme_color_override("font_color", theme_colors.colors.gray_500)
			label.add_theme_font_size_override("font_size", 20)
		else:
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid_container.add_child(label)

func _add_player_row(score_data: Dictionary, index: int):
	"""Add a player's score row to the grid"""
	var is_local = score_data.get("player_id", "") == local_player_id
	var theme_colors = null
	if has_node("/root/ThemeConstants"):
		theme_colors = get_node("/root/ThemeConstants")
	
	# Icon column
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(24, 24)
	
	var position = score_data.get("position", index + 1)
	if position == 1:
		var crown_icon = TextureRect.new()
		if ResourceLoader.exists("res://Pyramids/assets/icons/menu/crown_icon.png"):
			crown_icon.texture = load("res://Pyramids/assets/icons/menu/crown_icon.png")
		crown_icon.custom_minimum_size = Vector2(24, 24)
		crown_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		crown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(crown_icon)
	elif score_data.get("is_eliminated", false):
		var skull_icon = TextureRect.new()
		if ResourceLoader.exists("res://Pyramids/assets/icons/menu/skull_icon.png"):
			skull_icon.texture = load("res://Pyramids/assets/icons/menu/skull_icon.png")
		skull_icon.custom_minimum_size = Vector2(24, 24)
		skull_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		skull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(skull_icon)
	
	grid_container.add_child(icon_container)
	
	# Rank column
	var rank_label = Label.new()
	rank_label.text = "%d" % position  # Integer format
	rank_label.add_theme_font_size_override("font_size", 18)
	if is_local and theme_colors:
		rank_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	elif theme_colors:
		rank_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		rank_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.WHITE)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(rank_label)
	
	# Position change column
	var change_label = Label.new()
	var position_change = score_data.get("position_change", 0)
	if position_change > 0:
		change_label.text = "↑%d" % abs(position_change)  # Integer format
		change_label.add_theme_color_override("font_color", theme_colors.colors.success if theme_colors else Color.GREEN)
	elif position_change < 0:
		change_label.text = "↓%d" % abs(position_change)  # Integer format
		change_label.add_theme_color_override("font_color", theme_colors.colors.error if theme_colors else Color.RED)
	else:
		change_label.text = "—"
		change_label.add_theme_color_override("font_color", theme_colors.colors.gray_500 if theme_colors else Color.GRAY)
	change_label.add_theme_font_size_override("font_size", 18)
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(change_label)
	
	# Name column
	var name_label = Label.new()
	name_label.text = score_data.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 18)
	if is_local and theme_colors:
		name_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	elif theme_colors:
		name_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		name_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.WHITE)
	grid_container.add_child(name_label)
	
	# Total score column
	var total_label = Label.new()
	total_label.text = "%d" % score_data.get("total_score", 0)  # Integer format
	total_label.add_theme_font_size_override("font_size", 18)
	if is_local and theme_colors:
		total_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	elif theme_colors:
		total_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		total_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.WHITE)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(total_label)
	
	# Round score column
	var round_label = Label.new()
	round_label.text = "%d" % score_data.get("round_score", 0)  # Integer format
	round_label.add_theme_font_size_override("font_size", 18)
	if theme_colors:
		round_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		round_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_container.add_child(round_label)

func _start_countdown():
	"""Start the countdown timer"""
	countdown_timer = COUNTDOWN_TIME
	is_counting_down = true
	if continue_button:
		continue_button.disabled = false
	debug_log("Starting countdown from %d seconds" % COUNTDOWN_TIME)

func _update_continue_button_text():
	"""Update continue button with countdown"""
	if continue_button:
		continue_button.text = "Continue (%d)" % ceil(countdown_timer)

func _handle_continue():
	"""Handle continuation to next round"""
	debug_log("Countdown complete - continuing to next round")
	is_counting_down = false
	
	# Emit signal to GameState
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("multiplayer_round_continue"):
			signal_bus.multiplayer_round_continue.emit()
			debug_log("Emitted multiplayer_round_continue signal")
	
	# Clean up
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
		if player_scores[i].get("player_id", "") == local_player_id:
			lane_index = i
			break
	
	_create_floating_emoji(emoji_item, lane_index, "You")
	_start_global_emoji_cooldown()

func _start_global_emoji_cooldown():
	"""Start cooldown animation on ALL emoji buttons"""
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
	
	var emoji_container = VBoxContainer.new()
	emoji_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_container.custom_minimum_size = Vector2(60, 80)
	
	var screen_height = 550
	emoji_container.position.y = screen_height - 50
	emoji_container.position.x = 0
	
	if emoji_item and emoji_item.texture_path != null and emoji_item.texture_path != "":
		var texture_rect = TextureRect.new()
		if ResourceLoader.exists(emoji_item.texture_path):
			texture_rect.texture = load(emoji_item.texture_path)
		texture_rect.custom_minimum_size = Vector2(48, 48)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emoji_container.add_child(texture_rect)
	else:
		var emoji_label = Label.new()
		var test_emojis = {"emoji_test_0": "🎉", "emoji_test_1": "😢", "emoji_test_2": "😠", "emoji_test_3": "❤️"}
		var emoji_id = emoji_item.get("id", "") if emoji_item else ""
		emoji_label.text = test_emojis.get(emoji_id, "❓")
		emoji_label.add_theme_font_size_override("font_size", 32)
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_container.add_child(emoji_label)
	
	var name_label = Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_container.add_child(name_label)
	
	lane.add_child(emoji_container)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(emoji_container, "position:y", -25, EMOJI_DURATION)
	tween.tween_property(emoji_container, "modulate:a", 0.5, EMOJI_DURATION)
	tween.chain().tween_callback(func(): emoji_container.queue_free())

func _on_continue_pressed():
	"""Handle continue button press"""
	_handle_continue()

func _check_all_players_ready():
	"""Check if all players have submitted scores"""
	if has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		net_manager._fetch_round_scores(current_round)

func _check_player_count(scores: Array) -> bool:
	"""Check if we have scores from all expected players"""
	var players_with_scores = 0
	for score in scores:
		if score.get("round_score", 0) > 0:
			players_with_scores += 1
	
	debug_log("Players with scores: %d/%d" % [players_with_scores, expected_player_count])
	return players_with_scores >= expected_player_count
