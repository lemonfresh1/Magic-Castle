# NetworkManager.gd - Handles all network operations via Supabase (or mock)
# Location: res://Pyramids/scripts/autoloads/NetworkManager.gd
# Last Updated: Initial creation with mock support
#
# Works WITH MultiplayerManager:
# - MultiplayerManager: Game logic, lobby state, player management
# - NetworkManager: Network calls, Supabase operations, real-time sync

extends Node

# === DEPENDENCIES ===
@onready var supabase = get_node("/root/SupabaseManager")
@onready var mp_manager = get_node("/root/MultiplayerManager")

# === STATE ===
var current_lobby_data: Dictionary = {}
var round_scores: Dictionary = {}  # player_id -> Array of scores
var is_connected: bool = false
var pending_callbacks: Dictionary = {}  # For storing temporary data between requests

# === POLLING ===
var poll_timer: Timer
var poll_interval: float = 3.0
var is_polling: bool = false

# === DEBUG ===
var debug_enabled: bool = true
var mock_mode: bool = false  # CHANGED TO FALSE - Using real Supabase now!

# === SIGNALS ===
signal lobby_created(lobby_data: Dictionary)
signal lobby_joined(lobby_data: Dictionary) 
signal lobby_updated(lobby_data: Dictionary)
signal player_joined(player_data: Dictionary)
signal player_left(player_id: String)
signal round_scores_ready(scores: Array)
signal game_completed(final_results: Dictionary)

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[NetworkManager] %s" % message)

func _ready():
	debug_log("NetworkManager initialized")
	
	# Create polling timer
	poll_timer = Timer.new()
	poll_timer.name = "PollTimer"
	poll_timer.wait_time = poll_interval
	poll_timer.timeout.connect(_poll_lobby_status)
	add_child(poll_timer)
	
	# Connect to SupabaseManager
	if supabase:
		supabase.connection_established.connect(_on_connection_established)
		supabase.authenticated.connect(_on_authenticated)
		supabase.request_completed.connect(_on_supabase_response)
		is_connected = supabase.is_authenticated
	
	# Check if we're in mock mode
	mock_mode = false  # Force real mode
	debug_log("Running in REAL MODE - Using Supabase")

# === CONNECTION HANDLERS ===

func _on_connection_established():
	is_connected = true
	debug_log("Connection established")

func _on_authenticated(user_data: Dictionary):
	debug_log("Authenticated as: %s" % user_data.get("id", "unknown"))

# === LOBBY MANAGEMENT ===

func find_or_create_lobby(mode: String) -> void:
	"""Main entry point for matchmaking"""
	debug_log("Finding or creating lobby for mode: %s" % mode)
	
	if mock_mode:
		await _mock_create_lobby(mode)
	else:
		# Real Supabase implementation
		supabase.current_request_type = "find_lobbies"
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		url += "?status=eq.waiting"  # Only waiting lobbies
		url += "&mode=eq." + mode     # Same game mode
		url += "&player_count=lt.8"   # Not full
		url += "&order=created_at.desc"  # Newest first
		url += "&limit=1"              # Just need one
		
		var headers = supabase._get_db_headers()
		supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func create_lobby(mode: String) -> void:
	"""Create a new lobby as host"""
	debug_log("Creating lobby for mode: %s" % mode)
	
	if mock_mode:
		await _mock_create_lobby(mode)
	else:
		var player_data = _build_player_data()
		var lobby_data = {
			"mode": mode,
			"lobby_type": "matchmaking",
			"host_id": supabase.current_user.get("id", ""),
			"players": [player_data],
			"player_count": 1,
			"status": "waiting",
			"current_round": 0,
			"max_rounds": _get_max_rounds_for_mode(mode),
			"settings": {}
		}
		
		supabase.current_request_type = "create_lobby"
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		var headers = supabase._get_db_headers()
		headers.append("Prefer: return=representation")
		
		var body = JSON.stringify(lobby_data)
		supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func join_lobby(lobby_id: String) -> void:
	"""Join an existing lobby"""
	debug_log("Joining lobby: %s" % lobby_id)
	
	if mock_mode:
		_mock_join_lobby(lobby_id)
	else:
		# First get the current lobby data
		supabase.current_request_type = "get_lobby"
		pending_callbacks["join_lobby_id"] = lobby_id
		
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		url += "?id=eq." + lobby_id
		
		var headers = supabase._get_db_headers()
		supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func leave_lobby() -> void:
	"""Leave current lobby"""
	if not current_lobby_data.has("id"):
		return
	
	debug_log("Leaving lobby: %s" % current_lobby_data.id)
	
	if mock_mode:
		_mock_leave_lobby()
	else:
		# Real implementation would go here
		pass

func start_game() -> void:
	"""Host starts the game"""
	if not mp_manager or not mp_manager.is_host:
		push_error("[NetworkManager] Only host can start game")
		return
	
	debug_log("Starting game")
	
	if mock_mode:
		current_lobby_data.status = "playing"
		current_lobby_data.current_round = 1
		lobby_updated.emit(current_lobby_data)

# === SCORE MANAGEMENT ===

func submit_round_score(round: int, score: int, stats: Dictionary = {}) -> void:
	"""Submit score for current round"""
	debug_log("Submitting score for round %d: %d" % [round, score])
	
	var player_id = supabase.current_user.get("id", "mock_user") if supabase else "mock_user"
	
	if mock_mode:
		_mock_submit_score(player_id, round, score, stats)
	else:
		# Real implementation would go here
		pass

func _check_round_complete(round: int) -> void:
	"""Check if all players have submitted scores"""
	debug_log("Checking if round %d is complete" % round)
	
	if mock_mode:
		# In mock mode, generate scores for other players
		await _mock_complete_round(round)
	else:
		# Real implementation would go here
		pass

# === SUPABASE RESPONSE HANDLER ===

func _on_supabase_response(data) -> void:
	"""Handle responses from SupabaseManager"""
	var request_type = supabase.current_request_type
	debug_log("Handling response for: %s" % request_type)
	
	match request_type:
		"find_lobbies":
			if data is Array and data.size() > 0:
				# Join existing lobby
				join_lobby(data[0].id)
			else:
				# No lobbies found, create one
				create_lobby(mp_manager.selected_game_mode if mp_manager else "classic")
		
		"create_lobby":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
			elif data is Dictionary:
				current_lobby_data = data
			
			debug_log("Lobby created: %s" % current_lobby_data.get("id", "unknown"))
			lobby_created.emit(current_lobby_data)
			
			# Start polling for updates
			start_polling()
			
			# Update MultiplayerManager
			if mp_manager:
				mp_manager.current_lobby_id = current_lobby_data.get("id", "")
				mp_manager.is_host = true
		
		"get_lobby":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
				
				# Now add ourselves to the players array
				var lobby_id = pending_callbacks.get("join_lobby_id", "")
				if lobby_id:
					_update_lobby_players(lobby_id)
					pending_callbacks.erase("join_lobby_id")
		
		"update_lobby_players":
			debug_log("Successfully joined lobby")
			lobby_joined.emit(current_lobby_data)
			
			# Start polling for updates
			start_polling()
			
			# Update MultiplayerManager
			if mp_manager:
				mp_manager.current_lobby_id = current_lobby_data.get("id", "")
				mp_manager.is_host = false
		
		"poll_lobby":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
				lobby_updated.emit(current_lobby_data)
				
				# Check if game is starting
				if current_lobby_data.get("status", "") == "playing" and mp_manager:
					if not mp_manager.game_in_progress:
						debug_log("Game is starting!")
						stop_polling()
						# Game will start from signal handler

# === POLLING ===

func start_polling() -> void:
	"""Start polling for lobby updates"""
	if not is_polling:
		is_polling = true
		poll_timer.start()
		debug_log("Started polling every %d seconds" % poll_interval)

func stop_polling() -> void:
	"""Stop polling"""
	if is_polling:
		is_polling = false
		poll_timer.stop()
		debug_log("Stopped polling")

func _poll_lobby_status() -> void:
	"""Poll for lobby updates"""
	if not current_lobby_data.has("id"):
		return
	
	supabase.current_request_type = "poll_lobby"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + current_lobby_data.id
	
	var headers = supabase._get_db_headers()
	supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func _update_lobby_players(lobby_id: String) -> void:
	"""Update lobby with our player data"""
	var player_data = _build_player_data()
	var players = current_lobby_data.get("players", [])
	players.append(player_data)
	
	var update_data = {
		"players": players,
		"player_count": players.size()
	}
	
	supabase.current_request_type = "update_lobby_players"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + lobby_id
	
	var headers = supabase._get_db_headers()
	headers.append("Prefer: return=representation")
	
	var body = JSON.stringify(update_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _mock_create_lobby(mode: String) -> void:
	"""Mock lobby creation"""
	await get_tree().process_frame
	
	var player_data = mp_manager.get_local_player_data() if mp_manager else {
		"id": "mock_player_1",
		"name": "Player 1",
		"mmr": 1200
	}
	
	current_lobby_data = {
		"id": "mock_lobby_%d" % randi(),
		"mode": mode,
		"host_id": player_data.id,
		"players": [player_data],
		"player_count": 1,
		"status": "waiting",
		"current_round": 0,
		"max_rounds": _get_max_rounds_for_mode(mode)
	}
	
	lobby_created.emit(current_lobby_data)
	
	# Simulate other players joining after delay
	if debug_enabled:
		await get_tree().create_timer(2.0).timeout
		_mock_add_bot_players()

func _mock_join_lobby(lobby_id: String) -> void:
	"""Mock joining a lobby"""
	# In mock mode, just emit the signal
	lobby_joined.emit(current_lobby_data)

func _mock_leave_lobby() -> void:
	"""Mock leaving a lobby"""
	current_lobby_data.clear()
	round_scores.clear()

func _mock_add_bot_players() -> void:
	"""Add mock bot players for testing"""
	var bot_count = randi_range(3, 7)  # Random 3-7 bots
	
	for i in range(bot_count):
		var bot = {
			"id": "bot_%d" % i,
			"name": "Bot %d" % (i + 1),
			"mmr": 1000 + randi_range(-200, 200),
			"is_bot": true
		}
		current_lobby_data.players.append(bot)
	
	current_lobby_data.player_count = current_lobby_data.players.size()
	debug_log("Added %d bot players" % bot_count)
	lobby_updated.emit(current_lobby_data)

func _mock_submit_score(player_id: String, round: int, score: int, stats: Dictionary) -> void:
	"""Mock score submission"""
	if not round_scores.has(player_id):
		round_scores[player_id] = []
	
	round_scores[player_id].append({
		"round": round,
		"score": score,
		"stats": stats
	})
	
	# Check if round is complete
	await _check_round_complete(round)

func _mock_complete_round(round: int) -> void:
	"""Generate mock scores for all players"""
	var all_scores = []
	
	for player in current_lobby_data.players:
		var player_id = player.id
		
		# Get real score if submitted, otherwise generate mock
		var score = 0
		if round_scores.has(player_id):
			for round_data in round_scores[player_id]:
				if round_data.round == round:
					score = round_data.score
					break
		else:
			# Generate mock score for bots
			score = randi_range(500, 950)
			if not round_scores.has(player_id):
				round_scores[player_id] = []
			round_scores[player_id].append({
				"round": round,
				"score": score
			})
		
		# Calculate total score
		var total = 0
		for round_data in round_scores[player_id]:
			total += round_data.score
		
		all_scores.append({
			"player_id": player_id,
			"name": player.name,
			"round_score": score,
			"total_score": total,
			"position": 0,  # Will be calculated
			"is_local": player_id == supabase.current_user.get("id", "mock_player_1")
		})
	
	# Sort by total score and assign positions
	all_scores.sort_custom(func(a, b): return a.total_score > b.total_score)
	for i in range(all_scores.size()):
		all_scores[i].position = i + 1
		# Calculate position change (simplified for now)
		all_scores[i].position_change = 0
	
	debug_log("Round %d complete with %d players" % [round, all_scores.size()])
	round_scores_ready.emit(all_scores)
	
	# Check if game is complete
	if round >= current_lobby_data.max_rounds:
		await _mock_end_game()

func _mock_end_game() -> void:
	"""Generate final game results"""
	debug_log("Game complete, generating final results")
	
	var rankings = []
	for player in current_lobby_data.players:
		var total = 0
		var rounds_data = []
		
		if round_scores.has(player.id):
			for round_data in round_scores[player.id]:
				total += round_data.score
				rounds_data.append(round_data.score)
		
		rankings.append({
			"id": player.id,
			"name": player.name,
			"total": total,
			"rounds": rounds_data,
			"mmr": player.get("mmr", 1000),
			"placement": 0
		})
	
	# Sort and assign placements
	rankings.sort_custom(func(a, b): return a.total > b.total)
	for i in range(rankings.size()):
		rankings[i].placement = i + 1
		# Calculate MMR change (simplified)
		var base_change = (rankings.size() - i - 1) * 10 - 20
		rankings[i].mmr_change = base_change
	
	var final_results = {
		"rankings": rankings,
		"lobby_id": current_lobby_data.id,
		"mode": current_lobby_data.mode
	}
	
	game_completed.emit(final_results)

# === HELPER FUNCTIONS ===

func _build_player_data() -> Dictionary:
	"""Build player data object with equipment and stats"""
	var player_data = {
		"id": supabase.current_user.get("id", "unknown") if supabase else "unknown",
		"name": SettingsSystem.player_name if has_node("/root/SettingsSystem") else "Player",
		"level": 1,  # TODO: Get from XPManager
		"mmr": 1000,  # TODO: Get from profile stats
		"equipped": {},
		"displayed": [],
		"stats": {}
	}
	
	# Get equipped items from EquipmentManager
	if has_node("/root/EquipmentManager"):
		var equipment = get_node("/root/EquipmentManager")
		player_data.equipped = {
			"emojis": equipment.get_equipped_emojis(),
			"frame": equipment.get_equipped_item("frame"),
			"mini_profile_card": equipment.get_equipped_item("mini_profile_card")
		}
		player_data.displayed = equipment.get_showcased_items()
	
	# Get multiplayer stats for current mode
	if has_node("/root/StatsManager"):
		var stats = get_node("/root/StatsManager")
		var mode = mp_manager.selected_game_mode if mp_manager else "classic"
		var mp_stats = stats.get_multiplayer_stats(mode)
		player_data.stats = {
			"games": mp_stats.get("games", 0),
			"avg_rank": mp_stats.get("average_rank", 0),
			"mmr": mp_stats.get("mmr", 1000)
		}
	
	return player_data

func _get_max_rounds_for_mode(mode: String) -> int:
	"""Get max rounds for game mode"""
	match mode:
		"classic": return 10
		"rush": return 5
		"test": return 3
		_: return 10

func get_current_lobby() -> Dictionary:
	"""Get current lobby data"""
	return current_lobby_data

func is_in_lobby() -> bool:
	"""Check if currently in a lobby"""
	return current_lobby_data.has("id")

func get_player_count() -> int:
	"""Get current player count in lobby"""
	return current_lobby_data.get("player_count", 0)
