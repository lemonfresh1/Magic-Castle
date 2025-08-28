# MultiplayerLeaderboard.gd - Multiplayer-specific leaderboard display
# Location: res://Pyramids/scripts/ui/components/MultiplayerLeaderboard.gd
# Last Updated: Created for mode-specific multiplayer scores [2025-08-28]

extends "res://Pyramids/scripts/ui/components/HighscoresPanel.gd"

# Current selected mode
var current_mode_id: String = "classic"
var is_loading: bool = false

func _ready():
	super._ready()
	
	# Configure for multiplayer display
	_configure_for_multiplayer()
	
	# Load initial scores
	refresh_for_mode(current_mode_id)

func _configure_for_multiplayer():
	"""Set up the panel specifically for multiplayer leaderboards"""
	setup({
		"title": "Leaderboard - Classic",  # Will update with mode
		"columns": [
			{"key": "rank", "label": "#", "width": 40, "align": "center", "format": "rank"},
			{"key": "player_name", "label": "Name", "width": 140, "align": "left", "format": "player"},
			{"key": "score", "label": "Points", "width": 100, "align": "center", "format": "number"},
			{"key": "timestamp", "label": "Date", "width": 80, "align": "right", "format": "date"}
		],
		"filters": [
			{"id": "global", "label": "Global", "default": true}
			# Only Global tab as requested
		],
		"row_actions": ["replay"],  # Replay button to be implemented
		"filter_position": "top",
		"max_rows": 10,  # Show top 10
		"show_title": true,
		"show_filters": false,  # Hide filter tabs since we only have Global
		"data_provider": _fetch_multiplayer_scores
	})

func refresh_for_mode(mode_id: String) -> void:
	"""Update leaderboard for a specific game mode"""
	current_mode_id = mode_id
	
	# Update title based on mode
	var mode_display_name = _get_mode_display_name(mode_id)
	panel_title = "Leaderboard - %s" % mode_display_name
	
	# Update title label if it exists
	if title_label:
		title_label.text = panel_title
	
	# Refresh the scores
	refresh()

func _fetch_multiplayer_scores(context: Dictionary) -> Array:
	"""Fetch scores from StatsManager for current mode"""
	if not StatsManager:
		print("[MultiplayerLeaderboard] StatsManager not found")
		return _get_placeholder_data()
	
	# Get top scores for the current multiplayer mode
	var mode_key = current_mode_id + "_mp"  # e.g., "classic_mp"
	var scores = StatsManager.get_top_scores(mode_key, 10)
	
	# If no real scores yet, show placeholder data
	if scores.is_empty():
		return _get_placeholder_data()
	
	# Format scores for display
	var formatted_scores = []
	for i in range(scores.size()):
		var score_data = scores[i]
		formatted_scores.append({
			"rank": i + 1,
			"player_name": score_data.get("player_name", "Unknown"),
			"score": score_data.get("score", 0),
			"timestamp": score_data.get("timestamp", Time.get_unix_time_from_system()),
			"is_current_player": score_data.get("is_current_player", false)
		})
	
	return formatted_scores

func _get_placeholder_data() -> Array:
	"""Generate placeholder data for testing/empty state"""
	var placeholder = []
	
	# Add some mock data to show the layout works
	for i in range(5):
		placeholder.append({
			"rank": i + 1,
			"player_name": "Player%d" % (i + 1),
			"score": 5000 - (i * 500),
			"timestamp": Time.get_unix_time_from_system() - (i * 86400),  # Days ago
			"is_current_player": false
		})
	
	return placeholder

func _get_mode_display_name(mode_id: String) -> String:
	"""Convert mode ID to display name"""
	match mode_id:
		"classic":
			return "Classic"
		"timed_rush":
			return "Rush"
		"test":
			return "Test"
		_:
			return "Classic"

func set_loading_state(loading: bool) -> void:
	"""Show loading indicator"""
	is_loading = loading
	
	if loading:
		_display_empty_state("Loading...")
	else:
		refresh()

# Override to handle replay button
func _get_action_icon(action: String) -> String:
	if action == "replay":
		return "🎬"
	else:
		return super._get_action_icon(action)

func _get_action_tooltip(action: String) -> String:
	if action == "replay":
		return "Watch Replay"
	else:
		return super._get_action_tooltip(action)
