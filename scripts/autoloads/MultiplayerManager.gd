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
	
	# TODO: First scan for existing lobbies with same mode
	var existing_lobby = _find_existing_lobby()
	
	if existing_lobby:
		_join_existing_lobby(existing_lobby)
	else:
		_create_new_lobby()

func create_custom_lobby(settings: Dictionary = {}) -> String:
	"""Create a custom/private lobby with specific settings"""
	current_lobby_type = LobbyType.CUSTOM  # Custom lobbies don't affect MMR
	current_lobby_id = _generate_lobby_id()
	is_host = true
	
	debug_log("Created custom lobby: %s" % current_lobby_id)
	lobby_created.emit(current_lobby_id)
	
	return current_lobby_id

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
	# Always rebuild from current data to stay in sync
	local_player_data = {
		"id": SettingsSystem.player_id if SettingsSystem else "player_" + str(OS.get_unique_id()),
		"name": SettingsSystem.player_name if SettingsSystem else "Player",
		"level": 1,  # TODO: Add level/progression system
		"prestige": 0,
		"equipped": {},  # Will be populated below
		"stats": {},  # Will be populated below
		"frame_id": "",  # TODO: Add frame selection
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
		
		debug_log("Showcase items being sent: %s" % str(local_player_data["equipped"]["mini_profile_card_showcased_items"]))
	
	# Get multiplayer stats for current mode
	if StatsManager:
		local_player_data["stats"] = StatsManager.get_multiplayer_stats(selected_game_mode)
	else:
		# Fallback stats
		local_player_data["stats"] = {
			"games": 0,
			"win_rate": 0.0,
			"mmr": 1200
		}
	
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
