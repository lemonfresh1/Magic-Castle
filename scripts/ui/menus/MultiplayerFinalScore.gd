# MultiplayerFinalScore.gd - Display final game results with all rounds
# Location: res://Pyramids/scripts/ui/game_ui/MultiplayerFinalScore.gd
# Last Updated: Initial implementation [Date]

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
var total_rounds: int = 10  # Will be set based on game mode
var player_results: Array = []  # Final results data
var local_player_id: String = "player_local"
var game_mode: String = "classic"

# Emoji system (reused from round score)
var emoji_buttons: Array = []
var emoji_on_cooldown: bool = false
var emoji_cooldown_tweens: Array = []
var emoji_lanes: Array = []

# Mock data for testing
var mock_players = [
	{"id": "player_local", "name": "You", "mmr": 1200},
	{"id": "player_2", "name": "Pharaoh", "mmr": 1350},
	{"id": "player_3", "name": "Cleopatra", "mmr": 1100},
	{"id": "player_4", "name": "Sphinx", "mmr": 1250},
	{"id": "player_5", "name": "Anubis", "mmr": 1400},
	{"id": "player_6", "name": "Ra", "mmr": 1050},
	{"id": "player_7", "name": "Osiris", "mmr": 1150},
	{"id": "player_8", "name": "Thoth", "mmr": 1300}
]

func _ready():
	_setup_ui()
	_setup_emoji_system()
	_create_emoji_lanes()
	_connect_signals()
	_apply_styling()
	
	# Test with mock data if running directly
	if get_tree().current_scene == self:
		setup("classic", 10)  # Classic mode with 10 rounds
		display_final_results(_generate_mock_results())

# === SETUP ===

func _setup_ui():
	"""Initialize UI structure"""
	if get_tree().current_scene == self:
		get_window().size = Vector2(1000, 600)  # Wider for two grids
	
	# Title
	if title_label:
		title_label.text = "Final Results!"
	
	# Setup grid columns
	if ranking_grid:
		ranking_grid.columns = 5  # Icon | # | Player | Total | MMR
	
	if score_grid:
		score_grid.columns = 5  # Round | Me | Win Score | Best | Player

func _setup_emoji_system():
	"""Load equipped emojis into buttons - same as round score"""
	emoji_buttons = [emoji_button_1, emoji_button_2, emoji_button_3, emoji_button_4]
	
	if not EquipmentManager:
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
	"""Configure a single emoji button"""
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
	"""Setup mock emojis for testing"""
	for i in range(emoji_buttons.size()):
		var button = emoji_buttons[i]
		button.visible = true
		button.text = ["🎉", "😢", "😠", "❤️"][i]
		button.custom_minimum_size = Vector2(48, 48)
		button.set_meta("emoji_id", "emoji_test_%d" % i)
		button.set_meta("emoji_item", {"id": "emoji_test_%d" % i, "display_name": "Test", "texture_path": ""})
		if UIStyleManager:
			UIStyleManager.apply_button_style(button, "transparent", "medium")

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

func _apply_styling():
	"""Apply theme styling"""
	if background:
		background.z_index = -1
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(0.1, 0.1, 0.2, 0.95))
		gradient.add_point(1.0, Color(0.2, 0.1, 0.3, 0.95))
	
	if styled_panel:
		# Wider panel for final scores
		styled_panel.custom_minimum_size.x = 800
		styled_panel.z_index = 1
	
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 20)
		margin_container.add_theme_constant_override("margin_right", 20)
	
	if title_label and ThemeConstants:
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_title)
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	
	if continue_button:
		continue_button.text = "Continue to Summary"

# === PUBLIC API ===

func setup(mode: String, rounds: int):
	"""Setup the final score screen for a specific game mode"""
	game_mode = mode
	total_rounds = rounds
	
	# RankingGrid is always 5 columns: Rank | Icon | Player | Total | MMR
	# ScoreGrid is always 5 columns: Round | Me | Winner | Winner Score | Best
	# No need to adjust columns dynamically anymore
	
	# Adjust panel width if needed
	if styled_panel:
		styled_panel.custom_minimum_size.x = 900  # Wide enough for both grids

func display_final_results(results: Array):
	"""Display the final results for all players"""
	player_results = results
	_populate_grid()

# === PRIVATE HELPERS ===

func _generate_mock_results() -> Array:
	"""Generate mock final results for testing"""
	var results = []
	
	# Generate results for actual player count (not always 8)
	var player_count = min(mock_players.size(), randi_range(4, 8))
	
	for i in range(player_count):
		var player = mock_players[i]
		var player_result = {
			"player_id": player.id,
			"name": player.name,
			"placement": 0,  # Will be set after sorting
			"total_score": 0,
			"round_scores": [],
			"mmr_before": player.mmr,
			"mmr_change": 0,
			"mmr_after": 0,
			"is_eliminated": false,
			"status": "done"
		}
		
		# Generate scores for each round
		for round in range(total_rounds):
			var round_score = randi_range(400, 950)
			player_result.round_scores.append(round_score)
			player_result.total_score += round_score
		
		results.append(player_result)
	
	# Sort by total score
	results.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	# Assign placements and calculate MMR changes
	for i in range(results.size()):
		results[i]["placement"] = i + 1
		
		# Calculate MMR change based on placement
		var mmr_change = _calculate_mmr_change(i + 1, results.size())
		results[i]["mmr_change"] = mmr_change
		results[i]["mmr_after"] = results[i]["mmr_before"] + mmr_change
		
		# Mark eliminated players (bottom 2 in elimination modes)
		if i >= results.size() - 2 and game_mode != "classic":
			results[i]["is_eliminated"] = true
	
	return results

func _calculate_mmr_change(placement: int, total_players: int) -> int:
	"""Calculate MMR change based on placement"""
	# Simple formula for now - should use RankingSystem later
	var base_change = 50
	var position_factor = float(total_players - placement) / float(total_players - 1)
	var change = int(base_change * (position_factor * 2 - 1))
	return change

func _populate_grid():
	"""Populate both grids with final results"""
	# Clear existing content
	for child in ranking_grid.get_children():
		child.queue_free()
	for child in score_grid.get_children():
		child.queue_free()
	
	# Populate ranking grid (left side)
	_populate_ranking_grid()
	
	# Add spacing between grids
	if grid_hbox:
		grid_hbox.add_theme_constant_override("separation", 30)
	
	# Populate score grid (right side)
	_populate_score_grid()

func _populate_ranking_grid():
	"""Populate the ranking grid with player standings"""
	# Add headers - 5 columns (removed Rank, keeping only #)
	var headers = ["", "#", "Player", "Total", "MMR"]
	for header_text in headers:
		var label = Label.new()
		label.text = header_text
		label.add_theme_color_override("font_color", ThemeConstants.colors.gray_500 if ThemeConstants else Color.GRAY)
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ranking_grid.add_child(label)
	
	# Add player rows
	for i in range(player_results.size()):
		_add_ranking_row(player_results[i], i)

func _populate_score_grid():
	"""Populate the score grid with round-by-round breakdown"""
	# Find winner (1st place player)
	var winner_data = player_results[0] if player_results.size() > 0 else null
	
	# Find local player data
	var local_data = null
	for player in player_results:
		if player.player_id == local_player_id:
			local_data = player
			break
	
	# Add headers - 5 columns now
	var headers = ["Round", "Me", "Win Score", "Best", "Player"]
	for header_text in headers:
		var label = Label.new()
		label.text = header_text
		label.add_theme_color_override("font_color", ThemeConstants.colors.gray_500 if ThemeConstants else Color.GRAY)
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(label)
	
	# Track totals for summary row
	var my_total = 0
	var winner_total = 0
	var best_total = 0
	
	# Add round rows
	for round_idx in range(total_rounds):
		# Round number
		var round_label = Label.new()
		round_label.text = "R%d" % (round_idx + 1)
		round_label.add_theme_font_size_override("font_size", 14)
		round_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(round_label)
		
		# My score
		var my_score = 0
		if local_data and round_idx < local_data.round_scores.size():
			my_score = local_data.round_scores[round_idx]
		my_total += my_score
		
		var my_label = Label.new()
		my_label.text = str(my_score)
		my_label.add_theme_font_size_override("font_size", 14)
		my_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
		my_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(my_label)
		
		# Winner score
		var winner_score = 0
		if winner_data and round_idx < winner_data.round_scores.size():
			winner_score = winner_data.round_scores[round_idx]
		winner_total += winner_score
		
		var winner_score_label = Label.new()
		winner_score_label.text = str(winner_score)
		winner_score_label.add_theme_font_size_override("font_size", 14)
		winner_score_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
		winner_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(winner_score_label)
		
		# Best score for this round
		var best_score = 0
		var best_player_name = ""
		for player in player_results:
			if round_idx < player.round_scores.size():
				if player.round_scores[round_idx] > best_score:
					best_score = player.round_scores[round_idx]
					best_player_name = player.name
		best_total += best_score
		
		var best_label = Label.new()
		best_label.text = str(best_score)
		best_label.add_theme_font_size_override("font_size", 14)
		best_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
		best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_grid.add_child(best_label)
		
		# Player name who got best score
		var player_label = Label.new()
		player_label.text = best_player_name
		player_label.add_theme_font_size_override("font_size", 14)
		# Highlight if it's the local player
		if best_player_name == (local_data.name if local_data else ""):
			player_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
		else:
			player_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
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
	total_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(total_label)
	
	# My total
	var my_total_label = Label.new()
	my_total_label.text = str(my_total)
	my_total_label.add_theme_font_size_override("font_size", 16)
	my_total_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
	my_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(my_total_label)
	
	# Winner total
	var winner_total_label = Label.new()
	winner_total_label.text = str(winner_total)
	winner_total_label.add_theme_font_size_override("font_size", 16)
	winner_total_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
	winner_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(winner_total_label)
	
	# Best possible total
	var best_total_label = Label.new()
	best_total_label.text = str(best_total)
	best_total_label.add_theme_font_size_override("font_size", 16)
	best_total_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
	best_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_grid.add_child(best_total_label)
	
	# Empty cell for player column in total row
	var empty_label = Label.new()
	empty_label.text = ""
	score_grid.add_child(empty_label)

func _add_ranking_row(result_data: Dictionary, index: int):
	"""Add a player's row to the ranking grid"""
	var is_local = result_data.player_id == local_player_id
	var placement = result_data.placement
	
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
	elif result_data.is_eliminated:
		var skull_icon = TextureRect.new()
		if ResourceLoader.exists("res://Pyramids/assets/icons/menu/skull_icon.png"):
			skull_icon.texture = load("res://Pyramids/assets/icons/menu/skull_icon.png")
		skull_icon.custom_minimum_size = Vector2(24, 24)
		skull_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		skull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(skull_icon)
	elif result_data.status == "disconnected":
		var disconnect_label = Label.new()
		disconnect_label.text = "🔌"
		disconnect_label.add_theme_font_size_override("font_size", 20)
		icon_container.add_child(disconnect_label)
	
	ranking_grid.add_child(icon_container)
	
	# # column (position number)
	var rank_label = Label.new()
	rank_label.text = str(placement)
	rank_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body if ThemeConstants else 18)
	if is_local:
		rank_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
	else:
		rank_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_grid.add_child(rank_label)
	
	# Name column
	var name_label = Label.new()
	name_label.text = result_data.name
	name_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body if ThemeConstants else 18)
	if is_local:
		name_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
	else:
		name_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
	ranking_grid.add_child(name_label)
	
	# Total score column
	var total_label = Label.new()
	total_label.text = str(result_data.total_score)
	total_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body if ThemeConstants else 18)
	if is_local:
		total_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
	else:
		total_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900 if ThemeConstants else Color.BLACK)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_grid.add_child(total_label)
	
	# MMR column (final value with change)
	var mmr_label = Label.new()
	var mmr_change_text = "+" if result_data.mmr_change >= 0 else ""
	mmr_change_text += str(result_data.mmr_change)
	mmr_label.text = "%d (%s)" % [result_data.mmr_after, mmr_change_text]
	mmr_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body_small if ThemeConstants else 16)
	if result_data.mmr_change > 0:
		mmr_label.add_theme_color_override("font_color", ThemeConstants.colors.primary if ThemeConstants else Color.GREEN)
	elif result_data.mmr_change < 0:
		mmr_label.add_theme_color_override("font_color", ThemeConstants.colors.error if ThemeConstants else Color.RED)
	else:
		mmr_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700 if ThemeConstants else Color.GRAY)
	mmr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ranking_grid.add_child(mmr_label)

# === EMOJI SYSTEM (same as round score) ===

func _on_emoji_pressed(emoji_index: int):
	"""Handle emoji button press"""
	if emoji_on_cooldown:
		return
	
	var button = emoji_buttons[emoji_index]
	var emoji_id = button.get_meta("emoji_id", "")
	var emoji_item = button.get_meta("emoji_item", null)
	
	if emoji_id == "":
		return
	
	# Find local player's position
	var lane_index = 0
	for i in range(player_results.size()):
		if player_results[i].player_id == local_player_id:
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
	
	# Create emoji display
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
		var emoji_id = emoji_item.id if emoji_item and emoji_item.id != null else ""
		emoji_label.text = test_emojis.get(emoji_id, "❓")
		emoji_label.add_theme_font_size_override("font_size", 32)
		emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_container.add_child(emoji_label)
	
	# Name label
	var name_label = Label.new()
	name_label.text = player_name
	if ThemeConstants:
		name_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_caption)
		name_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_500)
	else:
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
	"""Handle continue button - go to PostGameSummary"""
	if SignalBus and SignalBus.has_signal("final_score_continue"):
		SignalBus.final_score_continue.emit()
	
	# Navigate to PostGameSummary
	if ResourceLoader.exists("res://Pyramids/scenes/ui/game_ui/PostGameSummary.tscn"):
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/game_ui/PostGameSummary.tscn")
	else:
		print("PostGameSummary scene not found")
		queue_free()
