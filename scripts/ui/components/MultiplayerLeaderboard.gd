# MultiplayerLeaderboard.gd - Multiplayer-specific leaderboard display
# Location: res://Pyramids/scripts/ui/components/MultiplayerLeaderboard.gd
# Last Updated: Fixed infinite recursion, added image icons

extends "res://Pyramids/scripts/ui/components/HighscoresPanel.gd"

# Icon paths and sizing
const REPLAY_ICON_PATH = "res://Pyramids/assets/icons/menu/replay_icon.png"
const SEED_ICON_PATH = "res://Pyramids/assets/icons/menu/seed_icon.png"
const PLAYER_ICON_PATH = "res://Pyramids/assets/icons/menu/player_icon.png"
const ICON_SIZE = Vector2(18, 18)

# Current selected mode
var current_mode_id: String = "classic"
var is_solo_mode: bool = false

# Mode indicator UI element
var mode_indicator: Label = null

var debug_enabled: bool = true

func _ready():
	super._ready()
	
	# Connect to parent's action signal
	if not action_triggered.is_connected(_on_action_triggered):
		action_triggered.connect(_on_action_triggered)
	
	configure_for_multiplayer()
	refresh_for_mode(current_mode_id)

func configure_for_multiplayer():
	"""Set up the panel specifically for multiplayer leaderboards"""
	setup({
		"title": "Test",
		"columns": [
			{"key": "rank", "label": "#", "width": 40, "align": "center", "format": "rank"},
			{"key": "player_name", "label": "Name", "width": 80, "align": "left", "format": "player"},
			{"key": "score", "label": "Score", "width": 70, "align": "center", "format": "number"},
			{"key": "date", "label": "Date", "width": 70, "align": "right", "format": "date"}
		],
		"filters": [],
		"row_actions": ["player", "seed", "replay"],  # Added player as first action
		"filter_position": "top",
		"max_rows": 20,
		"show_title": true,
		"show_filters": false,
		"data_provider": fetch_multiplayer_scores,
		"compact_mode": false
	})
	
	_create_mode_indicator()
	_apply_consistent_styling()

func _create_mode_indicator():
	"""Create indicator showing Solo or Multiplayer mode"""
	if not title_label or not title_label.get_parent():
		return
	
	var title_parent = title_label.get_parent()
	
	# Create container for mode indicator
	var indicator_container = PanelContainer.new()
	indicator_container.name = "ModeIndicator"
	indicator_container.custom_minimum_size = Vector2(100, 30)
	
	# Create label
	mode_indicator = Label.new()
	mode_indicator.text = "Multiplayer"
	mode_indicator.add_theme_font_size_override("font_size", 14)
	mode_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_indicator.add_theme_color_override("font_color", Color.WHITE)
	
	_update_mode_indicator_style()
	
	# Add to container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	indicator_container.add_child(margin)
	margin.add_child(mode_indicator)
	
	# Position to the right of title
	if title_parent is HBoxContainer:
		title_parent.add_child(indicator_container)
	else:
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		hbox.add_theme_constant_override("separation", 10)
		
		var parent = title_label.get_parent()
		var title_index = title_label.get_index()
		parent.remove_child(title_label)
		parent.add_child(hbox)
		parent.move_child(hbox, title_index)
		
		hbox.add_child(title_label)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(spacer)
		
		hbox.add_child(indicator_container)

func _update_mode_indicator_style():
	"""Update the mode indicator colors"""
	if not mode_indicator:
		return
	
	var panel_style = StyleBoxFlat.new()
	
	if ThemeConstants:
		if is_solo_mode:
			panel_style.bg_color = ThemeConstants.colors.play_solo
			panel_style.border_color = ThemeConstants.colors.play_solo_dark
			mode_indicator.text = "Solo"
		else:
			panel_style.bg_color = ThemeConstants.colors.play_multiplayer
			panel_style.border_color = ThemeConstants.colors.play_multiplayer_dark
			mode_indicator.text = "Multiplayer"
	else:
		# Fallback colors
		if is_solo_mode:
			panel_style.bg_color = Color(0.2, 0.7, 0.5)
			panel_style.border_color = Color(0.15, 0.55, 0.4)
			mode_indicator.text = "Solo"
		else:
			panel_style.bg_color = Color(0.9, 0.3, 0.3)
			panel_style.border_color = Color(0.7, 0.2, 0.2)
			mode_indicator.text = "Multiplayer"
	
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	
	mode_indicator.add_theme_color_override("font_color", Color.WHITE)
	
	if mode_indicator.get_parent() and mode_indicator.get_parent().get_parent() is PanelContainer:
		mode_indicator.get_parent().get_parent().add_theme_stylebox_override("panel", panel_style)

func _apply_consistent_styling():
	"""Apply styling to match MultiplayerScreen stats"""
	if title_label and ThemeConstants:
		title_label.add_theme_font_size_override("font_size", 18)
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)

func refresh_for_mode(mode_id: String) -> void:
	"""Update leaderboard for a specific game mode"""
	# Handle suffix parsing
	if mode_id.ends_with("_mp"):
		is_solo_mode = false
		current_mode_id = mode_id.replace("_mp", "")
	elif mode_id.ends_with("_solo"):
		is_solo_mode = true
		current_mode_id = mode_id.replace("_solo", "")
	else:
		current_mode_id = mode_id
	
	_update_mode_indicator_style()
	
	# Update title
	var mode_display_name = get_mode_display_name(current_mode_id)
	panel_title = mode_display_name
	
	if title_label:
		title_label.text = panel_title
	
	refresh()

func set_mode_type(solo: bool) -> void:
	"""Explicitly set whether showing solo or multiplayer scores"""
	is_solo_mode = solo
	_update_mode_indicator_style()
	refresh()

func fetch_multiplayer_scores(context: Dictionary) -> Array:
	"""Route to appropriate data source based on mode"""
	if is_solo_mode:
		# Solo always uses local data
		return _fetch_local_scores(context)
	else:
		# Multiplayer will use network when available
		return _fetch_network_scores(context)

func _fetch_local_scores(context: Dictionary) -> Array:
	"""Fetch scores from local StatsManager"""
	if not StatsManager:
		print("[MultiplayerLeaderboard] StatsManager not found")
		return get_placeholder_data()
	
	# Determine the correct key
	var mode_key = current_mode_id
	if is_solo_mode:
		mode_key = current_mode_id + "_solo"
	else:
		mode_key = current_mode_id + "_mp"
	
	var scores = StatsManager.get_top_scores(mode_key, 20)
	
	var player_name = "Player"
	if SettingsSystem:
		player_name = SettingsSystem.player_name
	
	return _format_scores_for_display(scores, player_name)

func _fetch_network_scores(context: Dictionary) -> Array:
	"""Fetch scores from database via NetworkManager"""
	if not has_node("/root/NetworkManager"):
		print("[MultiplayerLeaderboard] NetworkManager not found, using local fallback")
		return _fetch_local_scores(context)
	
	var net_manager = get_node("/root/NetworkManager")
	
	# Check if we already have cached network data
	if has_meta("cached_network_scores"):
		var cached = get_meta("cached_network_scores")
		if cached.mode == current_mode_id and Time.get_ticks_msec() - cached.timestamp < 5000:
			debug_log("Using cached network scores")
			return cached.scores
	
	# Request fresh data from database
	debug_log("Requesting fresh scores from database for mode: %s" % current_mode_id)
	
	# Connect to signal if not already connected
	if not net_manager.highscores_received.is_connected(_on_highscores_received):
		net_manager.highscores_received.connect(_on_highscores_received)
	
	# Request data
	net_manager.fetch_highscores_from_db(current_mode_id, "multi", 50)
	
	# Return placeholder while loading (or cached data if available)
	if has_meta("cached_network_scores"):
		return get_meta("cached_network_scores").scores
	else:
		return get_placeholder_data()

func _format_scores_for_display(scores: Array, player_name: String) -> Array:
	"""Format scores consistently regardless of source"""
	var formatted_scores = []
	
	if scores.is_empty():
		return get_placeholder_data()
	
	for i in range(scores.size()):
		var score_data = scores[i]
		var is_current = score_data.get("player_name", "") == player_name
		
		# Format the date properly
		var date_value = score_data.get("date", score_data.get("timestamp", ""))
		var formatted_date = date_value
		
		# If date looks like a timestamp string, format it
		if date_value is String and date_value.contains("-"):
			formatted_date = _format_database_date(date_value)
		elif date_value is float or date_value is int:
			# Unix timestamp - convert to MM/DD
			formatted_date = _format_unix_timestamp(date_value)
		
		formatted_scores.append({
			"rank": i + 1,
			"player_name": score_data.get("player_name", "Unknown"),
			"score": score_data.get("score", score_data.get("highscore", 0)),
			"date": formatted_date,  # Use formatted date
			"is_current_player": is_current,
			"replay_id": score_data.get("replay_id", ""),
			"player_id": score_data.get("player_profile_id", score_data.get("player_id", "")),
			"seed": score_data.get("seed", 0)
		})
	
	return formatted_scores

func _format_database_date(timestamp_str: String) -> String:
	"""Convert database timestamp to MM/DD format"""
	# Input formats: 
	# "2025-10-13 21:53:43.954105" (space separator)
	# "2025-10-13T22:08:27.111863" (ISO 8601 with T)
	# Output format: "10/13"
	
	if timestamp_str == "":
		return ""
	
	# Split by both space and T to handle both formats
	var parts = timestamp_str.split(" ")
	if parts.size() == 1:
		# Try splitting by T for ISO format
		parts = timestamp_str.split("T")
	
	if parts.size() == 0:
		return timestamp_str
	
	# Get just the date part
	var date_part = parts[0]
	
	# Split date by hyphen
	var date_parts = date_part.split("-")
	if date_parts.size() != 3:
		return date_part
	
	# Format as MM/DD
	var month = date_parts[1]
	var day = date_parts[2]
	return "%s/%s" % [month, day]

func _format_unix_timestamp(timestamp: float) -> String:
	"""Convert Unix timestamp to MM/DD format"""
	var datetime = Time.get_datetime_dict_from_unix_time(int(timestamp))
	return "%02d/%02d" % [datetime.month, datetime.day]

func get_placeholder_data() -> Array:
	"""Generate placeholder data for testing/empty state"""
	var placeholder = []
	
	for i in range(5):
		placeholder.append({
			"rank": i + 1,
			"player_name": "Player%d" % (i + 1),
			"score": 5000 - (i * 500),
			"date": Time.get_unix_time_from_system() - (i * 86400),
			"is_current_player": false,
			"seed": 12345 + i
		})
	
	return placeholder

func get_mode_display_name(mode_id: String) -> String:
	"""Convert mode ID to display name"""
	var clean_id = mode_id.replace("_mp", "").replace("_solo", "")
	
	match clean_id:
		"classic":
			return "Classic"
		"timed_rush":
			return "Rush"  
		"test":
			return "Test"
		_:
			return "Classic"

# Override parent's action icon method to return image paths
func _get_action_icon(action: String) -> String:
	"""Get icon path for action button"""
	match action:
		"replay":
			return REPLAY_ICON_PATH
		"seed":
			return SEED_ICON_PATH
		"player":
			return PLAYER_ICON_PATH
		_:
			return super._get_action_icon(action)

func _get_action_tooltip(action: String) -> String:
	"""Get tooltip for action button"""
	match action:
		"replay":
			return "Watch Replay"
		"seed":
			return "Copy Seed"
		"player":
			return "View Profile"
		_:
			return super._get_action_tooltip(action)

# Handle action button clicks
func _on_action_triggered(action: String, score_data: Dictionary):
	"""Handle action button clicks - use proper popups"""
	print("[MultiplayerLeaderboard] Action triggered: %s" % action)
	print("[MultiplayerLeaderboard] Score data: %s" % score_data)
	
	match action:
		"replay":
			_show_replay_popup(score_data)
			
		"seed":
			_show_seed_popup(score_data)
			
		"player", "player_name":
			_show_profile_popup(score_data)
		
		_:
			print("[MultiplayerLeaderboard] Unknown action: %s" % action)

func _on_highscores_received(highscores: Array) -> void:
	"""Handle highscores received from NetworkManager"""
	debug_log("Received %d highscores from network" % highscores.size())
	
	# Cache the results
	set_meta("cached_network_scores", {
		"mode": current_mode_id,
		"timestamp": Time.get_ticks_msec(),
		"scores": highscores
	})
	
	# Format and display
	var player_name = "Player"
	if SettingsSystem:
		player_name = SettingsSystem.player_name
	
	scores_data = _format_scores_for_display(highscores, player_name)
	_display_scores()

func _show_profile_popup(score_data: Dictionary):
	"""Show player profile dialog"""
	var dialog_scene = preload("res://Pyramids/scenes/ui/popups/PlayerDialog.tscn")
	if not dialog_scene:
		print("[MultiplayerLeaderboard] Failed to load PlayerDialog scene")
		return
		
	var dialog = dialog_scene.instantiate()
	dialog.setup(score_data)
	
	# Connect signals if we want to handle them
	dialog.add_friend_pressed.connect(func(player_name):
		print("[MultiplayerLeaderboard] Add friend: %s" % player_name)
	)
	dialog.send_message_pressed.connect(func(player_name):
		print("[MultiplayerLeaderboard] Send message to: %s" % player_name)
	)
	
	get_tree().root.add_child(dialog)

func _show_replay_popup(score_data: Dictionary):
	"""Show replay viewer dialog"""
	var dialog_scene = preload("res://Pyramids/scenes/ui/popups/ReplayDialog.tscn")
	if not dialog_scene:
		print("[MultiplayerLeaderboard] Failed to load ReplayDialog scene")
		return
		
	var dialog = dialog_scene.instantiate()
	dialog.setup(score_data)
	
	# Connect watch signal if needed
	dialog.watch_pressed.connect(func(replay_data):
		print("[MultiplayerLeaderboard] Watch replay requested")
	)
	
	get_tree().root.add_child(dialog)

func _show_seed_popup(score_data: Dictionary):
	"""Show seed actions dialog with full score data"""
	var dialog_scene = preload("res://Pyramids/scenes/ui/popups/SeedDialog.tscn")
	if not dialog_scene:
		print("[MultiplayerLeaderboard] Failed to load SeedDialog scene")
		return
		
	var dialog = dialog_scene.instantiate()
	
	# Pass the full score_data dictionary
	dialog.setup(score_data)
	
	# Connect signals
	dialog.play_pressed.connect(func(seed_val, mode):
		print("[MultiplayerLeaderboard] Play with seed: %d, mode: %s" % [seed_val, mode])
		# Could navigate to game with seed and mode here if needed
	)
	dialog.copy_pressed.connect(func(seed_val):
		print("[MultiplayerLeaderboard] Seed %d copied to clipboard" % seed_val)
	)
	
	get_tree().root.add_child(dialog)

# Inject scores from NetworkManager (future use)
func inject_network_scores(scores: Array) -> void:
	"""Called by NetworkManager to inject fetched scores"""
	var player_name = "Player"
	if SettingsSystem:
		player_name = SettingsSystem.player_name
	
	scores_data = _format_scores_for_display(scores, player_name)
	_display_scores()

func debug_log(message: String) -> void:
	"""Debug logging helper"""
	if debug_enabled:
		print("[MultiplayerLeaderboard] %s" % message)
