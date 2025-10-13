# MultiplayerFinalScore.gd - Display final game results with all rounds
# Location: res://Pyramids/scripts/ui/game_ui/MultiplayerFinalScore.gd
# Last Updated: Connected to NetworkManager, proper signal flow

extends Control

# === CONSTANTS ===
const MAX_PLAYERS = 8
const EMOJI_FLOAT_HEIGHT = 500
const EMOJI_DURATION = 5.0

# === NODE REFERENCES ===
@onready var background: ColorRect = $Background
@onready var styled_panel: PanelContainer = $StyledPanel
@onready var margin_container: MarginContainer = $StyledPanel/MarginContainer
@onready var vbox_container: VBoxContainer = $StyledPanel/MarginContainer/VBoxContainer
@onready var title_label: Label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var grid_hbox: HBoxContainer = $StyledPanel/MarginContainer/VBoxContainer/GridHBox
@onready var ranking_grid: GridContainer = $StyledPanel/MarginContainer/VBoxContainer/GridHBox/RankingGrid
@onready var score_grid: GridContainer = $StyledPanel/MarginContainer/VBoxContainer/GridHBox/ScoreGrid
@onready var bottom_hbox: HBoxContainer = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox
@onready var continue_button: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/ContinueButton
@onready var emoji_button_1: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton1
@onready var emoji_button_2: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton2
@onready var emoji_button_3: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton3
@onready var emoji_button_4: Button = $StyledPanel/MarginContainer/VBoxContainer/BottomHBox/EmojiButton4

# === PROPERTIES ===
var total_rounds: int = 10
var player_results: Array = []
var local_player_id: String = ""
var game_mode: String = "classic"
var update_timer: Timer
var is_updating: bool = false
var all_players_complete: bool = false

# Emoji system
var emoji_buttons: Array = []
var emoji_on_cooldown: bool = false
var emoji_cooldown_tweens: Array = []
var emoji_lanes: Array = []

# Debug
var debug_enabled: bool = true

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[MultiplayerFinalScore] %s" % message)

func _ready():
	debug_log("Final score screen loaded")
	
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		local_player_id = supabase.current_user.get("id", "")
	
	_setup_ui()
	_setup_emoji_system()
	_create_emoji_lanes()
	_connect_signals()
	_apply_styling()
	
	update_timer = Timer.new()
	update_timer.wait_time = 2.0
	update_timer.timeout.connect(_request_update)
	add_child(update_timer)
	
	_connect_network_signals()
	_request_initial_data()

# === SETUP ===

func _setup_ui():
	"""Initialize UI structure"""
	if title_label:
		title_label.text = "Final Results!"
	
	# Setup grid columns
	if ranking_grid:
		ranking_grid.columns = 5  # Icon | # | Player | Total | MMR
	
	if score_grid:
		score_grid.columns = 5  # Round | Me | Win Score | Best | Player

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
	
	var viewport_width = 900
	var lanes_total_width = 800
	var lane_width = lanes_total_width / MAX_PLAYERS
	var start_x = (viewport_width - lanes_total_width) / 2
	
	for i in range(MAX_PLAYERS):
		var lane = Control.new()
		lane.name = "EmojiLane%d" % i
		lane.position.x = start_x + (i * lane_width) + (lane_width / 2)
		lane.size.x = lane_width
		lane.size.y = 600
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
	
	if not net_manager.game_completed.is_connected(_on_game_completed):
		net_manager.game_completed.connect(_on_game_completed)
		debug_log("Connected to NetworkManager.game_completed")

func _apply_styling():
	"""Apply theme styling"""
	# Set HIGH z-index to appear in front of game cards
	z_index = 150
	
	if background:
		background.z_index = 149  # Just behind panel
		# Semi-transparent dark background
		background.color = Color(0.0, 0.0, 0.0, 0.7)  # 70% opacity black
	
	if styled_panel:
		styled_panel.custom_minimum_size.x = 900
		styled_panel.z_index = 150  # In front of everything
	
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 20)
		margin_container.add_theme_constant_override("margin_right", 20)
	
	if title_label and has_node("/root/ThemeConstants"):
		var theme = get_node("/root/ThemeConstants")
		title_label.add_theme_font_size_override("font_size", theme.typography.size_title)
		title_label.add_theme_color_override("font_color", theme.colors.primary)
	
	if continue_button:
		continue_button.text = "Continue to Summary"

# === PUBLIC API ===

func setup(mode: String, rounds: int):
	"""Setup the final score screen for a specific game mode"""
	game_mode = mode
	total_rounds = rounds
	debug_log("Setup: Mode=%s, Rounds=%d" % [mode, rounds])

func display_final_results(results: Array):
	"""Display the final results for all players"""
	debug_log("Displaying final results for %d players" % results.size())
	player_results = results
	_populate_grid()

# === NETWORK HANDLERS ===

func _on_game_completed(final_results: Dictionary):
	"""Handle game completion from NetworkManager"""
	debug_log("✅ Received game completed signal")
	
	all_players_complete = final_results.get("all_complete", false)
	
	if all_players_complete:
		debug_log("All players complete!")
		if update_timer:
			update_timer.stop()
			is_updating = false
	else:
		debug_log("Some players still playing - will continue polling")
	
	var rankings = final_results.get("rankings", [])
	display_final_results(rankings)

# === PRIVATE HELPERS ===

func _populate_grid():
	"""Populate both grids with final results"""
	# Clear existing content
	for child in ranking_grid.get_children():
		child.queue_free()
	for child in score_grid.get_children():
		child.queue_free()
	
	_populate_ranking_grid()
	
	if grid_hbox:
		grid_hbox.add_theme_constant_override("separation", 30)
	
	_populate_score_grid()

func _populate_ranking_grid():
	"""Populate the ranking grid with player standings"""
	var theme_colors = null
	if has_node("/root/ThemeConstants"):
		theme_colors = get_node("/root/ThemeConstants")
	
	# Add headers
	var headers = ["", "#", "Player", "Total", "MMR"]
	for header_text in headers:
		var label = Label.new()
		label.text = header_text
		if theme_colors:
			label.add_theme_color_override("font_color", theme_colors.colors.gray_500)
		else:
			label.add_theme_color_override("font_color", Color.GRAY)
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ranking_grid.add_child(label)
	
	# Add player rows
	for i in range(player_results.size()):
		_add_ranking_row(player_results[i], i)

func _populate_score_grid():
	"""Populate the score grid with round-by-round breakdown"""
	var theme_colors = null
	if has_node("/root/ThemeConstants"):
		theme_colors = get_node("/root/ThemeConstants")
	
	# Find winner and local player
	var winner_data = player_results[0] if player_results.size() > 0 else null
	var local_data = null
	for player in player_results:
		if player.get("id", "") == local_player_id:
			local_data = player
			break
	
	# Add headers
	var headers = ["Round", "Me", "Win Score", "Best", "Player"]
	for header_text in headers:
		var label = Label.new()
		label.text = header_text
		if theme_colors:
			label.add_theme_color_override("font_color", theme_colors.colors.gray_500)
		else:
			label.add_theme_color_override("font_color", Color.GRAY)
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(label)
	
	# Track totals
	var my_total = 0
	var winner_total = 0
	var best_total = 0
	
	# Add round rows
	for round_idx in range(total_rounds):
		# Round number
		var round_label = Label.new()
		round_label.text = "R%d" % (round_idx + 1)
		round_label.add_theme_font_size_override("font_size", 14)
		if theme_colors:
			round_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
		else:
			round_label.add_theme_color_override("font_color", Color.BLACK)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(round_label)
		
		# My score
		var my_score = 0
		if local_data and local_data.has("rounds") and round_idx < local_data.rounds.size():
			my_score = local_data.rounds[round_idx]
		my_total += my_score
		
		var my_label = Label.new()
		my_label.text = "%d" % my_score  # Integer format
		my_label.add_theme_font_size_override("font_size", 14)
		if theme_colors:
			my_label.add_theme_color_override("font_color", theme_colors.colors.primary)
		else:
			my_label.add_theme_color_override("font_color", Color.GREEN)
		my_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(my_label)
		
		# Winner score
		var winner_score = 0
		if winner_data and winner_data.has("rounds") and round_idx < winner_data.rounds.size():
			winner_score = winner_data.rounds[round_idx]
		winner_total += winner_score
		
		var winner_score_label = Label.new()
		winner_score_label.text = "%d" % winner_score  # Integer format
		winner_score_label.add_theme_font_size_override("font_size", 14)
		if theme_colors:
			winner_score_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
		else:
			winner_score_label.add_theme_color_override("font_color", Color.BLACK)
		winner_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(winner_score_label)
		
		# Best score for this round
		var best_score = 0
		var best_player_name = ""
		for player in player_results:
			if player.has("rounds") and round_idx < player.rounds.size():
				if player.rounds[round_idx] > best_score:
					best_score = player.rounds[round_idx]
					best_player_name = player.get("name", "Unknown")
		best_total += best_score
		
		var best_label = Label.new()
		best_label.text = "%d" % best_score  # Integer format
		best_label.add_theme_font_size_override("font_size", 14)
		if theme_colors:
			best_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
		else:
			best_label.add_theme_color_override("font_color", Color.BLACK)
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(best_label)
		
		# Player name who got best score
		var player_label = Label.new()
		player_label.text = best_player_name
		player_label.add_theme_font_size_override("font_size", 14)
		if best_player_name == (local_data.get("name", "") if local_data else ""):
			if theme_colors:
				player_label.add_theme_color_override("font_color", theme_colors.colors.primary)
			else:
				player_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			if theme_colors:
				player_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
			else:
				player_label.add_theme_color_override("font_color", Color.BLACK)
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(player_label)
	
	# Add separator
	for i in range(5):
		var separator = HSeparator.new()
		score_grid.add_child(separator)
	
	# Add totals row
	var total_label = Label.new()
	total_label.text = "Total"
	total_label.add_theme_font_size_override("font_size", 16)
	if theme_colors:
		total_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		total_label.add_theme_color_override("font_color", Color.BLACK)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(total_label)
	
	# My total
	var my_total_label = Label.new()
	my_total_label.text = "%d" % my_total  # Integer format
	my_total_label.add_theme_font_size_override("font_size", 16)
	if theme_colors:
		my_total_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	else:
		my_total_label.add_theme_color_override("font_color", Color.GREEN)
	my_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(my_total_label)
	
	# Winner total
	var winner_total_label = Label.new()
	winner_total_label.text = "%d" % winner_total  # Integer format
	winner_total_label.add_theme_font_size_override("font_size", 16)
	if theme_colors:
		winner_total_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		winner_total_label.add_theme_color_override("font_color", Color.BLACK)
	winner_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(winner_total_label)
	
	# Best possible total
	var best_total_label = Label.new()
	best_total_label.text = "%d" % best_total  # Integer format
	best_total_label.add_theme_font_size_override("font_size", 16)
	if theme_colors:
		best_total_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		best_total_label.add_theme_color_override("font_color", Color.BLACK)
	best_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(best_total_label)
	
	# Empty cell for player column in total row
	var empty_label = Label.new()
	empty_label.text = ""
	score_grid.add_child(empty_label)

func _add_ranking_row(result_data: Dictionary, index: int):
	"""Add a player's row to the ranking grid"""
	var is_local = result_data.get("id", "") == local_player_id
	var placement = result_data.get("placement", index + 1)
	var theme_colors = null
	if has_node("/root/ThemeConstants"):
		theme_colors = get_node("/root/ThemeConstants")
	
	# Icon column
	var icon_container = Control.new()
	icon_container.custom_minimum_size = Vector2(24, 24)
	
	if placement == 1:
		var crown_icon = TextureRect.new()
		if ResourceLoader.exists("res://Pyramids/assets/icons/menu/crown_icon.png"):
			crown_icon.texture = load("res://Pyramids/assets/icons/menu/crown_icon.png")
		crown_icon.custom_minimum_size = Vector2(24, 24)
		crown_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		crown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(crown_icon)
	
	ranking_grid.add_child(icon_container)
	
	# # column
	var rank_label = Label.new()
	rank_label.text = "%d" % placement  # Integer format
	rank_label.add_theme_font_size_override("font_size", 18)
	if is_local and theme_colors:
		rank_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	elif theme_colors:
		rank_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		rank_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.BLACK)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_grid.add_child(rank_label)
	
	# Name column
	var name_label = Label.new()
	name_label.text = result_data.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 18)
	if is_local and theme_colors:
		name_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	elif theme_colors:
		name_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		name_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.BLACK)
	ranking_grid.add_child(name_label)
	
	# Total score column
	var total_label = Label.new()
	total_label.text = "%d" % result_data.get("total", 0)  # Integer format
	total_label.add_theme_font_size_override("font_size", 18)
	if is_local and theme_colors:
		total_label.add_theme_color_override("font_color", theme_colors.colors.primary)
	elif theme_colors:
		total_label.add_theme_color_override("font_color", theme_colors.colors.gray_900)
	else:
		total_label.add_theme_color_override("font_color", Color.GREEN if is_local else Color.BLACK)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_grid.add_child(total_label)
	
	# MMR column
	var mmr_label = Label.new()
	var mmr_change = result_data.get("mmr_change", 0)
	var mmr_after = result_data.get("mmr", 1000) + mmr_change
	var mmr_change_text = "+" if mmr_change >= 0 else ""
	mmr_change_text += "%d" % mmr_change  # Integer format
	mmr_label.text = "%d (%s)" % [mmr_after, mmr_change_text]  # Integer format
	mmr_label.add_theme_font_size_override("font_size", 16)
	if mmr_change > 0:
		if theme_colors:
			mmr_label.add_theme_color_override("font_color", theme_colors.colors.primary)
		else:
			mmr_label.add_theme_color_override("font_color", Color.GREEN)
	elif mmr_change < 0:
		if theme_colors:
			mmr_label.add_theme_color_override("font_color", theme_colors.colors.error)
		else:
			mmr_label.add_theme_color_override("font_color", Color.RED)
	else:
		if theme_colors:
			mmr_label.add_theme_color_override("font_color", theme_colors.colors.gray_700)
		else:
			mmr_label.add_theme_color_override("font_color", Color.GRAY)
	mmr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_grid.add_child(mmr_label)

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
	
	var lane_index = 0
	for i in range(player_results.size()):
		if player_results[i].get("id", "") == local_player_id:
			lane_index = i
			break
	
	_create_floating_emoji(emoji_item, lane_index, "You")
	_start_global_emoji_cooldown()

func _create_floating_emoji(emoji_item, lane_index: int, player_name: String):
	"""Create a floating emoji in the specified lane"""
	if lane_index >= emoji_lanes.size():
		return
	
	var lane = emoji_lanes[lane_index]
	
	var emoji_container = VBoxContainer.new()
	emoji_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_container.custom_minimum_size = Vector2(60, 80)
	emoji_container.position.y = 500
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
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_container.add_child(name_label)
	
	lane.add_child(emoji_container)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(emoji_container, "position:y", -100, EMOJI_DURATION)
	tween.tween_property(emoji_container, "modulate:a", 0.5, EMOJI_DURATION)
	tween.chain().tween_callback(func(): emoji_container.queue_free())

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

# === SIGNAL HANDLERS ===

func _on_continue_pressed():
	"""Handle continue button - trigger GameState._end_game()"""
	debug_log("Continue pressed - calling GameState._end_game()")
	
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("multiplayer_game_complete"):
			signal_bus.multiplayer_game_complete.emit()
	
	# CRITICAL: Call GameState._end_game() to set metadata and load PostGameSummary
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		if game_state.has_method("_end_game"):
			debug_log("Calling GameState._end_game()")
			game_state._end_game()
		else:
			push_error("GameState has no _end_game() method!")
	
	# Clean up this screen
	queue_free()

func _request_initial_data():
	"""Request initial data when screen loads"""
	debug_log("Requesting initial final results data...")
	
	if has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		
		await get_tree().create_timer(0.5).timeout
		
		net_manager.request_final_results()
		
		if not is_updating:
			is_updating = true
			update_timer.start()
			debug_log("Started polling for updates every 2 seconds")

func _request_update():
	"""Poll for updated results"""
	if all_players_complete:
		update_timer.stop()
		is_updating = false
		debug_log("All players complete - stopped polling")
		return
	
	if has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		net_manager.request_final_results()
		debug_log("Polling for updated results...")

func _exit_tree():
	if update_timer:
		update_timer.stop()
		update_timer.queue_free()
