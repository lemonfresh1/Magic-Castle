# MultiplayerManager.gd - Manages multiplayer state and lobby logic
# Location: res://Pyramids/scripts/managers/MultiplayerManager.gd
# Last Updated: Updated to use LobbyType enum [Date]
#
# Dependencies:
#   - GameModeManager - Game mode configurations
#   - SignalBus - Global signal management
#
# Flow: MultiplayerScreen → select mode → Play → GameLobby → Start Game
#
# Functionality:
#   • Stores selected game mode for multiplayer
#   • Manages lobby state and player data
#   • Handles matchmaking logic (TODO)
#   • Coordinates with NetworkManager (TODO)
#
# Signals Out:
#   - lobby_found via SignalBus
#   - lobby_created via SignalBus
#   - matchmaking_started via SignalBus

extends Node

# === DEBUG FLAGS ===
var debug_enabled: bool = false
var global_debug: bool = false

# === ENUMS ===
enum LobbyType {
	MATCHMAKING,  # Affects MMR
	CUSTOM,       # No MMR
	TOURNAMENT    # Separate tournament scoring
}

# === CONSTANTS ===
const MAX_PLAYERS_PER_LOBBY = 8
const MIN_PLAYERS_TO_START = 1  # For testing, normally would be 2

# === LOBBY STATE ===
var current_lobby_id: String = ""
var selected_game_mode: String = "classic"  # Default mode
var current_lobby_type: LobbyType = LobbyType.MATCHMAKING  # REPLACED is_custom_lobby
var lobby_players: Array = []
var local_player_data: Dictionary = {}
var is_host: bool = false

# === MATCHMAKING STATE ===
var is_searching: bool = false
var search_start_time: float = 0.0

# === GAME STATE ===
var game_in_progress: bool = false
var player_scores: Dictionary = {}  # player_id -> score
var round_results: Array = []  # Array of round data

# === SIGNALS (local, plus we use SignalBus) ===
signal lobby_found(lobby_data: Dictionary)
signal lobby_created(lobby_id: String)
signal matchmaking_started()
signal matchmaking_stopped()

# === DEBUG FUNCTION ===
func debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[MultiplayerManager] %s" % message)

func _ready():
	debug_log("Initialized")
	
	# TODO: Connect to NetworkManager when available
	# SignalBus signals are already available globally

# === PUBLIC API ===

func select_game_mode(mode_id: String) -> void:
	"""Set the selected game mode for multiplayer"""
	if GameModeManager and GameModeManager.available_modes.has(mode_id):
		selected_game_mode = mode_id
		debug_log("Game mode selected: %s" % mode_id)
	else:
		push_error("[MultiplayerManager] Invalid game mode: %s" % mode_id)

func get_selected_mode() -> String:
	"""Get the currently selected game mode"""
	return selected_game_mode

func get_selected_mode_config() -> Dictionary:
	"""Get the configuration for selected mode"""
	if GameModeManager:
		return GameModeManager.available_modes.get(selected_game_mode, {})
	return {}

func start_matchmaking() -> void:
	"""Start searching for a lobby or create one"""
	if is_searching:
		debug_log("Already searching for lobby")
		return
	
	debug_log("Starting matchmaking for mode: %s" % selected_game_mode)
	current_lobby_type = LobbyType.MATCHMAKING  # Matchmaking affects MMR
	is_searching = true
	search_start_time = Time.get_ticks_msec() / 1000.0
	matchmaking_started.emit()
	
	# TODO: Implement actual network lobby scanning
	# For now, immediately create a new lobby
	_create_new_lobby()

func stop_matchmaking() -> void:
	"""Stop searching for lobbies"""
	if not is_searching:
		return
		
	is_searching = false
	debug_log("Matchmaking stopped")
	matchmaking_stopped.emit()

func join_or_create_lobby() -> void:
	"""Main entry point for Play button - finds or creates lobby"""
	debug_log("Join or create lobby for mode: %s" % selected_game_mode)
	
	# This is from Quick Play/matchmaking - affects MMR
	current_lobby_type = LobbyType.MATCHMAKING
	
	# Use NetworkManager for real matchmaking
	if has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		
		# Connect to signals if not already connected
		if not net_manager.lobby_created.is_connected(_on_network_lobby_created):
			net_manager.lobby_created.connect(_on_network_lobby_created)
		if not net_manager.lobby_joined.is_connected(_on_network_lobby_joined):
			net_manager.lobby_joined.connect(_on_network_lobby_joined)
		
		# This will find or create a lobby
		net_manager.find_or_create_lobby(selected_game_mode)
	else:
		debug_log("NetworkManager not found, creating local lobby")
		_create_new_lobby()

func _on_network_lobby_joined(lobby_data: Dictionary):
	"""Handle successful lobby join from NetworkManager"""
	debug_log("Joined network lobby: %s" % lobby_data.get("id", "unknown"))
	
	# Update our local state
	current_lobby_id = lobby_data.get("id", "")
	
	# Extract players
	var players = lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	lobby_players = players
	is_host = false
	
	lobby_found.emit(lobby_data)
	
	# ✅ ADD THIS: Navigate to GameLobby
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")

func create_custom_lobby(settings: Dictionary = {}) -> String:
	"""Create a custom/private lobby with specific settings"""
	current_lobby_type = LobbyType.CUSTOM  # Custom lobbies don't affect MMR
	current_lobby_id = _generate_lobby_id()
	is_host = true
	
	debug_log("Creating custom lobby in Supabase: %s" % current_lobby_id)
	
	# Use NetworkManager to create the actual Supabase lobby
	if has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		net_manager.create_lobby(selected_game_mode)
		
		# Listen for the lobby creation response
		if not net_manager.lobby_created.is_connected(_on_network_lobby_created):
			net_manager.lobby_created.connect(_on_network_lobby_created)
	else:
		debug_log("ERROR: NetworkManager not found - creating local lobby only")
		lobby_created.emit(current_lobby_id)
	
	return current_lobby_id

func _on_network_lobby_created(lobby_data: Dictionary):
	"""Handle successful lobby creation from NetworkManager"""
	debug_log("Joined network lobby: %s" % lobby_data.get("id", "unknown"))
	
	# Update our local state
	current_lobby_id = lobby_data.get("id", "")
	lobby_players.clear()
	
	# Extract players from lobby data
	var players = lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	lobby_players = players
	is_host = true
	
	lobby_created.emit(current_lobby_id)
	
	# ✅ ADD THIS: Navigate to GameLobby
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")


func create_tournament_lobby(tournament_id: String) -> String:
	"""Create a tournament lobby"""
	current_lobby_type = LobbyType.TOURNAMENT  # Tournament has separate scoring
	current_lobby_id = _generate_lobby_id()
	is_host = true
	
	debug_log("Created tournament lobby: %s for tournament %s" % [current_lobby_id, tournament_id])
	lobby_created.emit(current_lobby_id)
	
	return current_lobby_id

func leave_current_lobby() -> void:
	"""Leave the current lobby and cleanup"""
	if current_lobby_id == "":
		return
		
	debug_log("Leaving lobby: %s" % current_lobby_id)
	
	# TODO: Notify server/other players
	
	# Reset state
	current_lobby_id = ""
	lobby_players.clear()
	is_host = false
	current_lobby_type = LobbyType.MATCHMAKING  # Reset to default

func get_lobby_info() -> Dictionary:
	"""Get current lobby information"""
	return {
		"lobby_id": current_lobby_id,
		"game_mode": selected_game_mode,
		"lobby_type": current_lobby_type,  # REPLACED is_custom
		"player_count": lobby_players.size(),
		"max_players": MAX_PLAYERS_PER_LOBBY,
		"is_host": is_host,
		"players": lobby_players
	}

func get_lobby_type() -> LobbyType:
	"""Get the current lobby type"""
	return current_lobby_type

func is_custom_lobby() -> bool:
	"""Check if current lobby is custom (for backward compatibility)"""
	return current_lobby_type == LobbyType.CUSTOM

func affects_mmr() -> bool:
	"""Check if current lobby type affects MMR"""
	return current_lobby_type == LobbyType.MATCHMAKING

func set_local_player_data(data: Dictionary) -> void:
	"""Set local player information"""
	local_player_data = data
	if not data.has("id"):
		data["id"] = "player_" + str(OS.get_unique_id())

func get_local_player_data() -> Dictionary:
	"""Get local player information"""
	# Get ID from SupabaseManager first (most reliable)
	var player_id = ""
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		if supabase.current_user.has("id"):
			player_id = supabase.current_user.get("id", "")
	
	# Fallback to SettingsSystem
	if player_id == "" and SettingsSystem:
		player_id = SettingsSystem.player_id
	
	# Final fallback
	if player_id == "":
		player_id = "player_" + str(OS.get_unique_id())
	
	# Get name from SettingsSystem or ProfileManager
	var player_name = "Player"
	if SettingsSystem and SettingsSystem.player_name != "":
		player_name = SettingsSystem.player_name
	elif has_node("/root/ProfileManager"):
		var profile = get_node("/root/ProfileManager")
		if profile.player_name != "":
			player_name = profile.player_name
	
	local_player_data = {
		"id": player_id,
		"name": player_name,
		"level": 1,
		"prestige": 0,
		"equipped": {},
		"stats": {},
		"frame_id": "",
		"is_ready": false,
		"is_host": is_host
	}
	
	# Get equipped items from EquipmentManager
	if EquipmentManager:
		local_player_data["equipped"] = {
			"card_back": EquipmentManager.get_equipped_item("card_back"),
			"card_front": EquipmentManager.get_equipped_item("card_front"), 
			"board": EquipmentManager.get_equipped_item("board"),
			"mini_profile_card_showcased_items": EquipmentManager.get_showcased_items()
		}
	
	# Get multiplayer stats for current mode
	if StatsManager:
		local_player_data["stats"] = StatsManager.get_multiplayer_stats(selected_game_mode)
	else:
		local_player_data["stats"] = {
			"games": 0,
			"win_rate": 0.0,
			"mmr": 1200
		}
	
	debug_log("Built local_player_data: ID=%s, Name=%s" % [player_id, player_name])
	
	return local_player_data

func start_game() -> void:
	"""Start the game with current lobby settings"""
	if not is_host:
		push_error("[MultiplayerManager] Only host can start the game")
		return
	
	game_in_progress = true
	player_scores.clear()
	round_results.clear()
	
	# Initialize scores for all players
	for player in lobby_players:
		player_scores[player.id] = 0
	
	debug_log("Starting game with mode: %s, lobby type: %s" % [selected_game_mode, LobbyType.keys()[current_lobby_type]])
	
	# Configure GameModeManager
	if GameModeManager:
		GameModeManager.set_game_mode(selected_game_mode, {})
	
	# Set GameState to multiplayer mode
	if GameState:
		GameState.game_mode = "multi"
	
	# TODO: Notify all players via network
	
	# Load game scene
	get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")

# === PRIVATE HELPERS ===

func _find_existing_lobby() -> Dictionary:
	"""Scan for existing lobbies matching criteria"""
	# TODO: Implement actual network scanning
	# TODO: Check for:
	#   - Same game mode
	#   - Not full (< MAX_PLAYERS_PER_LOBBY)
	#   - Not in progress
	#   - Good connection/ping
	
	# For MVP, always return empty (no lobbies found)
	return {}

func _join_existing_lobby(lobby_data: Dictionary) -> void:
	"""Join an existing lobby"""
	current_lobby_id = lobby_data.get("id", "")
	is_host = false
	
	debug_log("Joining lobby: %s" % current_lobby_id)
	
	# TODO: Connect to lobby host
	# TODO: Sync player data
	
	lobby_found.emit(lobby_data)
	
	# Navigate to GameLobby
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")

func _create_new_lobby() -> void:
	"""Create a new lobby as host"""
	current_lobby_id = _generate_lobby_id()
	is_host = true
	# Don't change lobby type here - it's set by the calling function
	lobby_players.clear()
	
	# Add self as first player
	var player_data = get_local_player_data()
	player_data["is_host"] = true
	lobby_players.append(player_data)
	
	debug_log("Created new lobby: %s (type: %s)" % [current_lobby_id, LobbyType.keys()[current_lobby_type]])
	lobby_created.emit(current_lobby_id)
	
	# Navigate to GameLobby
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")

func _generate_lobby_id() -> String:
	"""Generate a unique lobby ID"""
	# Simple ID generation for MVP
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 9999
	return "lobby_%d_%04d" % [timestamp, random_suffix]

# === GAME TRACKING ===

func update_player_score(player_id: String, score: int) -> void:
	"""Update a player's score"""
	player_scores[player_id] = score
	# TODO: Broadcast to other players

func get_final_placements() -> Array:
	"""Get final placements sorted by score"""
	var sorted_players = []
	for player_id in player_scores:
		sorted_players.append({
			"id": player_id,
			"score": player_scores[player_id]
		})
	
	# Sort by score (highest first)
	sorted_players.sort_custom(func(a, b): return a.score > b.score)
	
	return sorted_players

func get_player_placement(player_id: String) -> int:
	"""Get a specific player's placement"""
	var placements = get_final_placements()
	for i in range(placements.size()):
		if placements[i].id == player_id:
			return i + 1  # 1-indexed
	return -1  # Not found

# === DEBUG/TEST ===

func debug_print_state() -> void:
	"""Print current manager state for debugging"""
	debug_log("=== MultiplayerManager State ===")
	debug_log("Selected Mode: %s" % selected_game_mode)
	debug_log("Current Lobby: %s" % current_lobby_id)
	debug_log("Lobby Type: %s" % LobbyType.keys()[current_lobby_type])
	debug_log("Is Host: %s" % str(is_host))
	debug_log("Player Count: %d" % lobby_players.size())
	debug_log("Is Searching: %s" % str(is_searching))
