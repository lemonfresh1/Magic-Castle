# NetworkManager.gd - Handles all network operations via Supabase
# Location: res://Pyramids/scripts/autoloads/NetworkManager.gd
# Last Updated: Fixed race condition between lobby and emoji polling

extends Node

# === DEPENDENCIES ===
@onready var supabase = get_node("/root/SupabaseManager")
@onready var mp_manager = get_node("/root/MultiplayerManager")

# === STATE ===
var current_lobby_data: Dictionary = {}
var round_scores: Dictionary = {}  # player_id -> Array of scores
var is_connected: bool = false
var pending_callbacks: Dictionary = {}

# === POLLING ===
var poll_timer: Timer
var poll_interval: float = 1.0  # ✅ FAST POLLING (changed from 3.0)
var is_polling: bool = false
var last_final_results_fetch: float = 0.0
var fetch_cooldown: float = 2.0
var lobby_poll_request: HTTPRequest = null  # ✅ NEW: Dedicated request for lobby polling

# === EMOJI POLLING ===
var emoji_poll_timer: Timer = null
var emoji_current_screen: String = ""
var emoji_last_poll_time: int = 0
var emoji_poll_request: HTTPRequest = null  # ✅ NEW: Dedicated request for emoji polling
var displayed_emoji_ids: Array = []  # ✅ NEW: Track displayed emojis to prevent duplicates
const MAX_EMOJI_HISTORY: int = 50  # Keep last 50 emoji IDs

# === DEBUG ===
var debug_enabled: bool = true
var mock_mode: bool = false

# === SIGNALS ===
signal lobby_created(lobby_data: Dictionary)
signal lobby_joined(lobby_data: Dictionary) 
signal lobby_updated(lobby_data: Dictionary)
signal player_joined(player_data: Dictionary)
signal player_left(player_id: String)
signal round_scores_ready(scores: Array)
signal game_completed(final_results: Dictionary)
signal highscores_received(highscores: Array)
signal emoji_received(emoji_data: Dictionary)

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
	
	debug_log("Running in %s MODE" % ("MOCK" if mock_mode else "REAL"))

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
		supabase.current_request_type = "find_lobbies"
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		url += "?status=eq.waiting"
		url += "&mode=eq." + mode
		url += "&player_count=lt.8"
		url += "&order=created_at.desc"
		url += "&limit=1"
		
		var headers = supabase._get_db_headers()
		supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func create_lobby(mode: String) -> void:
	"""Create a new lobby as host"""
	debug_log("Creating lobby for mode: %s" % mode)
	
	if mock_mode:
		await _mock_create_lobby(mode)
	else:
		var player_data = _build_player_data()
		
		# Generate shared seed for all players
		var lobby_seed = randi() % 2147483647
		debug_log("Generated shared lobby seed: %d" % lobby_seed)
		
		var lobby_data = {
			"mode": mode,
			"lobby_type": "matchmaking",
			"host_id": supabase.current_user.get("id", ""),
			"players": [player_data],
			"player_count": 1,
			"status": "waiting",
			"current_round": 0,
			"max_rounds": _get_max_rounds_for_mode(mode),
			"settings": {},
			"game_seed": lobby_seed
		}
		
		supabase.current_request_type = "create_lobby"
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		var headers = supabase._get_db_headers()
		headers.append("Prefer: return=representation")
		headers.append("Content-Type: application/json")
		
		var body = JSON.stringify(lobby_data)
		supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func ensure_lobby_exists(mode: String) -> void:
	"""Ensure we have a lobby before submitting scores (for solo testing)"""
	if current_lobby_data.has("id"):
		debug_log("Lobby already exists: %s" % current_lobby_data.id)
		return
	
	debug_log("No lobby exists - creating one for solo testing")
	create_lobby(mode)

func join_lobby(lobby_id: String) -> void:
	"""Join an existing lobby"""
	debug_log("Joining lobby: %s" % lobby_id)
	
	if mock_mode:
		_mock_join_lobby(lobby_id)
	else:
		supabase.current_request_type = "get_lobby"
		pending_callbacks["join_lobby_id"] = lobby_id
		
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		url += "?id=eq." + lobby_id
		
		var headers = supabase._get_db_headers()
		supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func leave_lobby() -> void:
	"""Remove current player from lobby and update database"""
	if mock_mode:
		return
	
	if not current_lobby_data.has("id"):
		debug_log("No lobby to leave")
		return
	
	var lobby_id = current_lobby_data.get("id", "")
	var player_id = supabase.current_user.get("id", "") if supabase else ""
	
	if player_id == "":
		debug_log("ERROR: Cannot leave lobby - no player ID")
		return
	
	debug_log("Leaving lobby: %s" % lobby_id)
	debug_log("  Removing player: %s" % player_id.substr(0, 8))
	
	# Get current players array
	var players = current_lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	# Remove this player from the array
	var new_players = []
	for player in players:
		if player.get("id", "") != player_id:
			new_players.append(player)
	
	debug_log("  Players before: %d" % players.size())
	debug_log("  Players after: %d" % new_players.size())
	
	# If this was the last player, mark lobby as completed
	var new_status = current_lobby_data.get("status", "waiting")
	if new_players.size() == 0:
		new_status = "completed"
		debug_log("  Last player left - marking lobby as completed")
	
	# Update lobby in database
	supabase.current_request_type = "leave_lobby"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + lobby_id
	
	var headers = supabase._get_db_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: return=representation")
	
	var update_data = {
		"players": new_players,
		"player_count": new_players.size(),
		"status": new_status
	}
	
	var body = JSON.stringify(update_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)
	
	debug_log("✅ Leave lobby request sent")

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
		# Check if we have a lobby
		if not current_lobby_data.has("id"):
			debug_log("⚠️ No lobby exists - creating one for solo testing")
			pending_callbacks["pending_score_submission"] = {
				"round": round,
				"score": score,
				"stats": stats
			}
			var mode = "test"
			if has_node("/root/GameModeManager"):
				mode = get_node("/root/GameModeManager").get_current_mode()
			create_lobby(mode)
			return
		
		var score_data = {
			"lobby_id": current_lobby_data.id,
			"player_id": player_id,
			"round": round,
			"score": score,
			"stats": stats
		}
		
		supabase.current_request_type = "submit_round_score"
		pending_callbacks["submitted_round"] = round
		pending_callbacks["submitted_score"] = score
		
		var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_round_scores"
		var headers = supabase._get_db_headers()
		headers.append("Prefer: return=representation")
		
		var body = JSON.stringify(score_data)
		debug_log("Sending score to DB: %s" % body)
		supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _fetch_round_scores(round: int) -> void:
	"""Fetch all scores for a round"""
	if not current_lobby_data.has("id"):
		debug_log("⚠️ Cannot fetch scores - no lobby_id")
		return
	
	debug_log("Fetching scores for round %d" % round)
	supabase.current_request_type = "fetch_round_scores"
	pending_callbacks["fetch_round"] = round
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_round_scores"
	url += "?lobby_id=eq." + current_lobby_data.id
	url += "&round=eq." + str(round)
	
	var headers = supabase._get_db_headers()
	supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func _check_round_complete(round: int) -> void:
	"""Check if all players have submitted scores"""
	debug_log("Checking if round %d is complete" % round)
	
	if mock_mode:
		await _mock_complete_round(round)

# === SUPABASE RESPONSE HANDLER ===

func _on_supabase_response(data) -> void:
	"""Handle responses from SupabaseManager"""
	var request_type = supabase.current_request_type
	debug_log("Handling response for: %s" % request_type)
	
	match request_type:
		"find_lobbies":
			if data is Array and data.size() > 0:
				join_lobby(data[0].id)
			else:
				var mode = "test"
				if has_node("/root/GameModeManager"):
					mode = get_node("/root/GameModeManager").get_current_mode()
				create_lobby(mode)
		
		"get_lobby_by_id":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
				var lobby_id = pending_callbacks.get("join_target_lobby_id", "")
				
				var players = current_lobby_data.get("players", [])
				if players is String:
					var json = JSON.new()
					var parse_result = json.parse(players)
					if parse_result == OK:
						current_lobby_data["players"] = json.data
				
				if lobby_id:
					_add_self_to_lobby(lobby_id)
					pending_callbacks.erase("join_target_lobby_id")
			else:
				debug_log("Lobby not found!")
				lobby_joined.emit({"error": "Lobby not found"})
		
		"update_lobby_join":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
			elif data is Dictionary:
				current_lobby_data = data
			
			debug_log("✅ Successfully joined lobby")
			lobby_joined.emit(current_lobby_data)
			start_polling()
		
		"create_lobby":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
			elif data is Dictionary:
				current_lobby_data = data
			
			var players = current_lobby_data.get("players", [])
			if players is String:
				var json = JSON.new()
				var parse_result = json.parse(players)
				if parse_result == OK:
					current_lobby_data["players"] = json.data
					debug_log("Parsed players from string: %d players" % json.data.size())
			
			debug_log("✅ Lobby created: %s" % current_lobby_data.get("id", "unknown"))
			debug_log("Lobby players: %s" % str(current_lobby_data.get("players", [])))
			lobby_created.emit(current_lobby_data)
			
			if pending_callbacks.has("pending_score_submission"):
				var pending = pending_callbacks["pending_score_submission"]
				pending_callbacks.erase("pending_score_submission")
				debug_log("Re-submitting pending score now that lobby exists")
				submit_round_score(pending.round, pending.score, pending.stats)
			
			start_polling()
			
			if mp_manager:
				mp_manager.current_lobby_id = current_lobby_data.get("id", "")
				mp_manager.is_host = true

		"get_lobby":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
				var lobby_id = pending_callbacks.get("join_lobby_id", "")
				if lobby_id:
					_update_lobby_players(lobby_id)
					pending_callbacks.erase("join_lobby_id")
		
		"update_lobby_players":
			debug_log("✅ Successfully joined lobby")
			lobby_joined.emit(current_lobby_data)
			start_polling()
			
			if mp_manager:
				mp_manager.current_lobby_id = current_lobby_data.get("id", "")
				mp_manager.is_host = false

		"submit_round_score":
			debug_log("✅ Score submitted successfully!")
			var submitted_round = pending_callbacks.get("submitted_round", 0)
			pending_callbacks.erase("submitted_round")
			pending_callbacks.erase("submitted_score")
			
			await get_tree().create_timer(0.5).timeout
			_fetch_round_scores(submitted_round)
			
			var max_rounds = current_lobby_data.get("max_rounds", 10)
			if submitted_round >= max_rounds:
				debug_log("🏁 Game complete! Fetching ALL round scores for final results...")
				pending_callbacks["from_round_submit"] = true
				await get_tree().create_timer(2.0).timeout
				_fetch_all_rounds_for_final_results()

		"fetch_round_scores":
			var round = pending_callbacks.get("fetch_round", 0)
			pending_callbacks.erase("fetch_round")
			
			debug_log("Processing %d score entries from DB" % (data.size() if data is Array else 0))
			
			var scores_array = []
			if data is Array:
				for score_entry in data:
					var player_data = {}
					for player in current_lobby_data.get("players", []):
						if player.get("id", "") == score_entry.player_id:
							player_data = player
							break
					
					scores_array.append({
						"player_id": score_entry.player_id,
						"name": player_data.get("name", "Unknown"),
						"round_score": score_entry.score,
						"total_score": score_entry.score,
						"position": 0,
						"position_change": 0,
						"is_local": score_entry.player_id == supabase.current_user.get("id", "")
					})
			
			scores_array.sort_custom(func(a, b): return a.round_score > b.round_score)
			
			var position = 1
			for i in range(scores_array.size()):
				scores_array[i].position = position
				position += 1
			
			debug_log("✅ Emitting round_scores_ready with %d players" % scores_array.size())
			round_scores_ready.emit(scores_array)
			
			var max_rounds = current_lobby_data.get("max_rounds", 10)
			if round >= max_rounds:
				debug_log("🏁 Game complete! Fetching ALL round scores for final results...")
				await get_tree().create_timer(0.3).timeout
				_fetch_all_rounds_for_final_results()

		"fetch_all_rounds":
			debug_log("Processing ALL rounds data from DB")
			
			if not current_lobby_data.has("id"):
				debug_log("ERROR: No lobby data available!")
				return
			
			var player_rounds = {}
			
			if data is Array:
				debug_log("Found %d score entries in database" % data.size())
				for score_entry in data:
					var player_id = str(score_entry.get("player_id", "")).strip_edges()
					var round_num = score_entry.get("round", 0)
					var score = score_entry.get("score", 0)
					
					debug_log("  Entry: player=%s, round=%d, score=%d" % [player_id.substr(0, 8), round_num, score])
					
					if not player_rounds.has(player_id):
						player_rounds[player_id] = {}
					
					player_rounds[player_id][round_num] = score
			
			debug_log("player_rounds structure: %s" % JSON.stringify(player_rounds))
			debug_log("player_rounds keys: %s" % str(player_rounds.keys()))
			
			var rankings = []
			var lobby_players = current_lobby_data.get("players", [])
			
			if lobby_players is String:
				debug_log("Players is a string, parsing JSON...")
				var json = JSON.new()
				var parse_result = json.parse(lobby_players)
				if parse_result == OK:
					lobby_players = json.data
					debug_log("Parsed %d players from JSON" % lobby_players.size())
				else:
					debug_log("ERROR: Failed to parse players JSON")
					lobby_players = []
			
			if lobby_players.size() == 0 and player_rounds.size() > 0:
				debug_log("WARNING: No players in lobby, creating from scores")
				for player_id in player_rounds:
					lobby_players.append({
						"id": player_id,
						"name": "Player",
						"mmr": 1000
					})
			
			debug_log("Lobby has %d players" % lobby_players.size())
			
			for player in lobby_players:
				var player_id = str(player.get("id", "")).strip_edges()
				var player_name = player.get("name", "Player")
				
				debug_log("Processing player: id='%s', name=%s" % [player_id, player_name])
				
				var rounds_data = []
				var total = 0
				var found_scores = false
				
				if player_rounds.has(player_id):
					debug_log("  Found player in player_rounds with full ID")
					found_scores = true
				else:
					for key in player_rounds.keys():
						if key.begins_with(player_id.substr(0, 8)):
							debug_log("  Found player with partial match: %s" % key)
							player_id = key
							found_scores = true
							break
				
				var max_rounds = current_lobby_data.get("max_rounds", 2)
				for r in range(1, max_rounds + 1):
					var round_score = 0
					
					if found_scores and player_rounds.has(player_id):
						if player_rounds[player_id].has(r):
							round_score = player_rounds[player_id][r]
						elif player_rounds[player_id].has(float(r)):
							round_score = player_rounds[player_id][float(r)]
						elif player_rounds[player_id].has(str(r)):
							round_score = player_rounds[player_id][str(r)]
					
					rounds_data.append(round_score)
					total += round_score
				
				debug_log("  Player %s: total=%d, rounds=%s" % [player_name, total, str(rounds_data)])
				
				rankings.append({
					"id": player.get("id", ""),
					"name": player_name,
					"total": total,
					"rounds": rounds_data,
					"mmr": player.get("mmr", 1000),
					"placement": 0,
					"mmr_change": 0,
					"is_complete": total > 0
				})
			
			rankings.sort_custom(func(a, b): return a.total > b.total)
			
			var placement = 1
			for i in range(rankings.size()):
				if rankings[i].total > 0:
					rankings[i].placement = placement
					placement += 1
					var base_change = (rankings.size() - rankings[i].placement) * 10 - 5
					rankings[i].mmr_change = base_change
				else:
					rankings[i].placement = 999
					rankings[i].mmr_change = 0
			
			var final_results = {
				"rankings": rankings,
				"lobby_id": current_lobby_data.get("id", ""),
				"mode": current_lobby_data.get("mode", "test"),
				"all_complete": rankings.all(func(r): return r.total > 0)
			}
			
			debug_log("✅ Emitting game_completed with %d players (%d complete)" % 
				[rankings.size(), rankings.filter(func(r): return r.total > 0).size()])
			
			game_completed.emit(final_results)
			
			if not has_meta("highscore_saved_this_game") and has_node("/root/GameState"):
				var game_state = get_node("/root/GameState")
				
				if game_state.is_eligible_for_global_leaderboard():
					var actual_total = game_state.total_score
					var game_seed = game_state.get_game_seed()
					
					debug_log("Saving highscore: %d (seed: %d) - ELIGIBLE for leaderboards" % [actual_total, game_seed])
					
					if actual_total > 0:
						save_highscore_to_db(
							actual_total,
							current_lobby_data.get("mode", "test"),
							"multi",
							game_seed
						)
						set_meta("highscore_saved_this_game", true)
				else:
					debug_log("NOT saving highscore - seeded/tournament game not eligible for leaderboards")
			else:
				if has_meta("highscore_saved_this_game"):
					debug_log("Highscore already saved for this game")
				else:
					debug_log("GameState not available")

		"save_highscore":
			if data:
				debug_log("✅ Highscore saved successfully!")
			else:
				debug_log("⚠️ Failed to save highscore")

		"fetch_highscores":
			debug_log("Received highscores from DB")
			
			var highscores = []
			
			if data is Array:
				debug_log("Found %d highscore entries" % data.size())
				
				for entry in data:
					var timestamp_str = entry.get("created_at", "")
					var formatted_date = _format_date_string(timestamp_str)
					
					highscores.append({
						"player_name": entry.get("player_name", "Unknown"),
						"player_id": entry.get("player_id", ""),
						"score": entry.get("score", 0),
						"highscore": entry.get("score", 0),
						"seed": entry.get("seed", 0),
						"timestamp": timestamp_str,
						"date": formatted_date,
						"mode": entry.get("mode", ""),
						"game_type": entry.get("game_type", ""),
						"is_current_player": entry.get("player_id", "") == supabase.current_user.get("id", "")
					})
			else:
				debug_log("No highscores found or invalid response")
			
			debug_log("✅ Emitting highscores_received with %d entries" % highscores.size())
			highscores_received.emit(highscores)

		"update_player_ready":
			if data:
				debug_log("✅ Ready state updated successfully")
				if data is Array and data.size() > 0:
					current_lobby_data = data[0]
				elif data is Dictionary:
					current_lobby_data = data
				
				var players = current_lobby_data.get("players", [])
				if players is String:
					var json = JSON.new()
					var parse_result = json.parse(players)
					if parse_result == OK:
						current_lobby_data["players"] = json.data
				
				lobby_updated.emit(current_lobby_data)

		"send_emoji":
			debug_log("✅ Emoji sent successfully")
			
		"mark_lobby_completed":
			debug_log("✅ Lobby marked as completed")
			# Optionally clear local lobby data
			current_lobby_data.clear()

		"cleanup_stale_lobbies":
			debug_log("✅ Stale lobbies cleaned up")
			
		"cleanup_old_completed":
			debug_log("✅ Old completed lobbies cleaned up")

		"kick_player":
			if data is Array and data.size() > 0:
				current_lobby_data = data[0]
			elif data is Dictionary:
				current_lobby_data = data
			
			debug_log("✅ Player kicked successfully")
			lobby_updated.emit(current_lobby_data)

		"leave_lobby":
			debug_log("✅ Left lobby successfully")

func request_final_results() -> void:
	"""Public method to request final game results - with cooldown"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_final_results_fetch < fetch_cooldown:
		debug_log("⏱️ Skipping fetch - too soon (%.1fs since last)" % (current_time - last_final_results_fetch))
		return
	
	debug_log("Requesting final game results...")
	last_final_results_fetch = current_time
	
	if not current_lobby_data.has("id"):
		debug_log("⚠️ Cannot fetch final results - no lobby")
		return
	
	_fetch_all_rounds_for_final_results()

func _fetch_all_rounds_for_final_results() -> void:
	"""Fetch all rounds from DB for final results"""
	if not current_lobby_data.has("id"):
		debug_log("⚠️ Cannot fetch all rounds - no lobby_id")
		return
	
	var lobby_id = current_lobby_data.get("id", "")
	debug_log("Fetching ALL rounds for lobby: %s" % lobby_id)
	supabase.current_request_type = "fetch_all_rounds"
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_round_scores"
	url += "?lobby_id=eq." + lobby_id
	url += "&order=round.asc"
	
	var headers = supabase._get_db_headers()
	supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

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
	"""Poll for lobby updates using dedicated HTTPRequest"""
	if not current_lobby_data.has("id"):
		debug_log("No lobby to poll")
		return
	
	var our_lobby_id = current_lobby_data.get("id", "")
	debug_log("Polling lobby: %s" % our_lobby_id)
	
	# ✅ Create dedicated request if doesn't exist
	if not lobby_poll_request:
		lobby_poll_request = HTTPRequest.new()
		lobby_poll_request.name = "LobbyPollRequest"
		add_child(lobby_poll_request)
		lobby_poll_request.request_completed.connect(_on_lobby_poll_completed)
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + our_lobby_id
	
	var headers = supabase._get_db_headers()
	lobby_poll_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_lobby_poll_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle dedicated lobby poll response"""
	if response_code != 200:
		debug_log("Lobby poll failed: %d" % response_code)
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		debug_log("Failed to parse lobby poll response")
		return
	
	var data = json.data
	
	if data is Array and data.size() > 0:
		var response_data = data[0]
		
		# Validate this is actually a lobby
		if not response_data.has("players") or not response_data.has("status"):
			debug_log("ERROR: Poll returned non-lobby data!")
			return
		
		var old_id = current_lobby_data.get("id", "none")
		var new_id = response_data.get("id", "none")
		
		if old_id == new_id:
			debug_log("✅ Lobby poll successful - emitting lobby_updated")
			current_lobby_data = response_data
			lobby_updated.emit(current_lobby_data)
			
			# Check if game is starting
			if current_lobby_data.get("status", "") == "playing" and mp_manager:
				if not mp_manager.game_in_progress:
					debug_log("Game is starting!")
					stop_polling()
		else:
			debug_log("ERROR: Poll returned different lobby!")
	else:
		debug_log("Poll returned no lobby data")

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

# === EMOJI SYSTEM ===

func subscribe_to_emoji_events(lobby_id: String, screen: String) -> void:
	"""Subscribe to emoji events for current lobby and screen (HTTP polling)"""
	if not supabase:
		debug_log("Cannot subscribe to emojis - no Supabase")
		return
	
	debug_log("Subscribing to emoji events: lobby=%s, screen=%s" % [lobby_id, screen])
	
	emoji_current_screen = screen
	
	# Create polling timer if doesn't exist
	if not emoji_poll_timer:
		emoji_poll_timer = Timer.new()
		emoji_poll_timer.name = "EmojiPollTimer"
		emoji_poll_timer.wait_time = 1.0  # Poll every 1 second
		emoji_poll_timer.timeout.connect(_poll_emoji_events)
		add_child(emoji_poll_timer)
	
	emoji_poll_timer.start()
	emoji_last_poll_time = Time.get_unix_time_from_system()
	debug_log("✅ Emoji polling started (1s interval)")

func unsubscribe_from_emoji_events() -> void:
	"""Unsubscribe from emoji polling and clear tracking"""
	if emoji_poll_timer:
		emoji_poll_timer.stop()
		debug_log("Unsubscribed from emoji events")
	
	# ✅ Clear displayed emoji tracking
	displayed_emoji_ids.clear()
	debug_log("Cleared emoji tracking")

func _poll_emoji_events() -> void:
	"""Poll for new emoji events using dedicated HTTPRequest"""
	if not current_lobby_data.has("id"):
		return
	
	# ✅ Create dedicated request if doesn't exist
	if not emoji_poll_request:
		emoji_poll_request = HTTPRequest.new()
		emoji_poll_request.name = "EmojiPollRequest"
		add_child(emoji_poll_request)
		emoji_poll_request.request_completed.connect(_on_emoji_poll_completed)
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_emoji_events"
	url += "?lobby_id=eq." + current_lobby_data.id
	url += "&screen=eq." + emoji_current_screen
	url += "&order=created_at.desc"
	url += "&limit=10"
	
	var headers = supabase._get_db_headers()
	emoji_poll_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_emoji_poll_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle dedicated emoji poll response with duplicate prevention"""
	if response_code != 200:
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		return
	
	var data = json.data
	
	if data is Array:
		for emoji_event in data:
			# Get unique identifier for this emoji event
			var emoji_id = emoji_event.get("id", "")  # Database row ID
			
			# ✅ Skip if we've already displayed this emoji
			if emoji_id in displayed_emoji_ids:
				continue
			
			# Skip our own emojis
			var event_player_id = emoji_event.get("player_id", "")
			var local_id = supabase.current_user.get("id", "")
			
			if event_player_id == local_id:
				# Still track it even though we don't display it
				displayed_emoji_ids.append(emoji_id)
				continue
			
			# ✅ NEW EMOJI - Display it!
			debug_log("Displaying new emoji from %s: %s" % [emoji_event.get("player_name", "Player"), emoji_event.get("emoji_id", "")])
			
			emoji_received.emit({
				"player_id": event_player_id,
				"player_name": emoji_event.get("player_name", "Player"),
				"emoji_id": emoji_event.get("emoji_id", ""),
				"screen": emoji_event.get("screen", "")
			})
			
			# ✅ Track this emoji as displayed
			displayed_emoji_ids.append(emoji_id)
			
			# ✅ Keep array size manageable (circular buffer)
			if displayed_emoji_ids.size() > MAX_EMOJI_HISTORY:
				displayed_emoji_ids.pop_front()

func send_emoji(emoji_id: String, screen: String) -> void:
	"""Send emoji event to other players"""
	if not current_lobby_data.has("id"):
		debug_log("Cannot send emoji - no lobby")
		return
	
	var player_name = "Player"
	if has_node("/root/SettingsSystem"):
		var settings = get_node("/root/SettingsSystem")
		player_name = settings.player_name
	
	var emoji_data = {
		"lobby_id": current_lobby_data.id,
		"player_id": supabase.current_user.get("id", ""),
		"player_name": player_name,
		"emoji_id": emoji_id,
		"screen": screen
	}
	
	debug_log("Sending emoji: %s in %s" % [emoji_id, screen])
	
	supabase.current_request_type = "send_emoji"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_emoji_events"
	var headers = supabase._get_db_headers()
	headers.append("Content-Type: application/json")
	
	var body = JSON.stringify(emoji_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)

# === MOCK FUNCTIONS ===

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

func _mock_join_lobby(lobby_id: String) -> void:
	"""Mock joining a lobby"""
	lobby_joined.emit(current_lobby_data)

func _mock_leave_lobby() -> void:
	"""Mock leaving a lobby"""
	current_lobby_data.clear()
	round_scores.clear()

func _mock_submit_score(player_id: String, round: int, score: int, stats: Dictionary) -> void:
	"""Mock score submission"""
	if not round_scores.has(player_id):
		round_scores[player_id] = []
	
	round_scores[player_id].append({
		"round": round,
		"score": score,
		"stats": stats
	})
	
	await _check_round_complete(round)

func _mock_complete_round(round: int) -> void:
	"""Generate mock scores for all players"""
	var all_scores = []
	
	for player in current_lobby_data.players:
		var player_id = player.id
		var score = 0
		
		if round_scores.has(player_id):
			for round_data in round_scores[player_id]:
				if round_data.round == round:
					score = round_data.score
					break
		
		var total = 0
		for round_data in round_scores.get(player_id, []):
			total += round_data.score
		
		all_scores.append({
			"player_id": player_id,
			"name": player.name,
			"round_score": score,
			"total_score": total,
			"position": 0,
			"is_local": player_id == supabase.current_user.get("id", "mock_player_1")
		})
	
	all_scores.sort_custom(func(a, b): return a.total_score > b.total_score)
	for i in range(all_scores.size()):
		all_scores[i].position = i + 1
		all_scores[i].position_change = 0
	
	debug_log("✅ Round %d complete with %d players" % [round, all_scores.size()])
	round_scores_ready.emit(all_scores)

# === HELPER FUNCTIONS ===

func _build_player_data() -> Dictionary:
	"""Build player data object"""
	var player_id = ""
	var player_name = "Guest%d" % (randi() % 9999)
	
	if supabase and supabase.current_user.has("id"):
		player_id = supabase.current_user.get("id", "")
	
	if has_node("/root/SettingsSystem"):
		var settings = get_node("/root/SettingsSystem")
		if "player_name" in settings and settings.player_name != "":
			player_name = settings.player_name
	elif has_node("/root/ProfileManager"):
		var profile = get_node("/root/ProfileManager")
		if profile.player_name != "" and profile.player_name != "Player":
			player_name = profile.player_name
	
	var level = 1
	var prestige = 0
	if has_node("/root/XPManager"):
		var xp_manager = get_node("/root/XPManager")
		level = xp_manager.get_current_level()  
		prestige = xp_manager.current_prestige  
	elif has_node("/root/ProfileManager"):
		var profile = get_node("/root/ProfileManager")
		level = profile.player_level
		prestige = profile.prestige
	
	var player_data = {
		"id": player_id,
		"name": player_name,
		"level": level,  
		"prestige": prestige,
		"mmr": 1000,
		"equipped": {},
		"stats": {},
		"is_ready": false
	}
	
	debug_log("=== BUILDING PLAYER DATA ===")
	debug_log("  Player ID: %s" % player_id)
	debug_log("  Player Name: %s" % player_name)
	debug_log("  Level: %d, Prestige: %d" % [level, prestige])
	
	if has_node("/root/StatsManager"):
		var stats_mgr = get_node("/root/StatsManager")
		var current_mode = "classic"
		if has_node("/root/MultiplayerManager"):
			var mp_mgr = get_node("/root/MultiplayerManager")
			current_mode = mp_mgr.get_selected_mode()
		
		var mode_stats = stats_mgr.get_multiplayer_stats(current_mode)
		
		var win_rate = 0.0
		if mode_stats.games > 0:
			win_rate = float(mode_stats.first_place) / float(mode_stats.games)
		
		player_data["stats"] = {
			"games": mode_stats.games,
			"win_rate": win_rate,
			"average_rank": mode_stats.average_rank
		}
		
		debug_log("Populated stats from StatsManager: games=%d, win_rate=%.2f, avg_rank=%.2f" % 
			[mode_stats.games, win_rate, mode_stats.average_rank])
	else:
		debug_log("⚠️ StatsManager not available")
	
	if has_node("/root/EquipmentManager"):
		var equipment = get_node("/root/EquipmentManager")
		
		player_data.equipped = {
			"emojis": equipment.get_equipped_emojis() if equipment.has_method("get_equipped_emojis") else [],
			"frame": equipment.get_equipped_item("frame") if equipment.has_method("get_equipped_item") else "",
			"mini_profile_card": equipment.get_equipped_item("mini_profile_card") if equipment.has_method("get_equipped_item") else "",
			"mini_profile_card_showcased_items": equipment.get_showcased_items() if equipment.has_method("get_showcased_items") else [],
			"card_back": equipment.get_equipped_item("card_back") if equipment.has_method("get_equipped_item") else "",
			"card_front": equipment.get_equipped_item("card_front") if equipment.has_method("get_equipped_item") else "",
			"board": equipment.get_equipped_item("board") if equipment.has_method("get_equipped_item") else ""
		}
	
	debug_log("=== FINAL PLAYER DATA ===")
	debug_log("  ID: %s" % player_data.get("id", "NONE"))
	debug_log("  Name: %s" % player_data.get("name", "NONE"))
	debug_log("  Level: %d, Prestige: %d" % [player_data.get("level", 0), player_data.get("prestige", 0)])
	debug_log("  Equipped items: %s" % str(player_data.get("equipped", {}).keys()))
	debug_log("  Stats: %s" % str(player_data.get("stats", {})))
	debug_log("============================")

	return player_data

func _get_max_rounds_for_mode(mode: String) -> int:
	"""Get max rounds for game mode"""
	match mode:
		"classic": return 10
		"rush": return 5
		"test": return 2
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

func reset_for_new_game() -> void:
	"""Reset NetworkManager state for a new game"""
	debug_log("Resetting NetworkManager for new game")
	
	stop_polling()
	
	current_lobby_data.clear()
	round_scores.clear()
	pending_callbacks.clear()
	displayed_emoji_ids.clear()  # ✅ NEW: Clear emoji tracking
	is_connected = true
	
	if has_meta("highscore_saved_this_game"):
		remove_meta("highscore_saved_this_game")
	
	debug_log("NetworkManager reset complete")

func save_highscore_to_db(final_score: int, mode: String, game_type: String = "multi", seed: int = 0) -> void:
	"""Save highscore to pyramids_highscores table"""
	debug_log("Saving highscore: %d for mode: %s (%s) with seed: %d" % [final_score, mode, game_type, seed])
	
	if not supabase or not supabase.current_user.has("id"):
		debug_log("ERROR: Cannot save highscore - no user")
		return
		
	var player_name = "Player"
	if has_node("/root/SettingsSystem"):
		var settings = get_node("/root/SettingsSystem")
		player_name = settings.player_name
	
	var highscore_data = {
		"player_id": supabase.current_user.get("id", ""),
		"player_name": player_name,
		"score": final_score,
		"mode": mode,
		"game_type": game_type,
		"seed": seed
	}
	
	supabase.current_request_type = "save_highscore"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_highscores"
	var headers = supabase._get_db_headers()
	headers.append("Content-Type: application/json")
	
	var body = JSON.stringify(highscore_data)
	debug_log("Saving highscore with body: %s" % body)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func fetch_highscores_from_db(mode: String, game_type: String = "multi", limit: int = 50) -> void:
	"""Fetch top highscores from pyramids_highscores table"""
	debug_log("Fetching highscores from DB: mode=%s, type=%s, limit=%d" % [mode, game_type, limit])
	
	if not supabase:
		debug_log("ERROR: SupabaseManager not available")
		highscores_received.emit([])
		return
	
	supabase.current_request_type = "fetch_highscores"
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_highscores"
	url += "?mode=eq." + mode
	url += "&game_type=eq." + game_type
	url += "&order=score.desc"
	url += "&limit=" + str(limit)
	
	var headers = supabase._get_db_headers()
	supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)

func _format_date_string(timestamp_str: String) -> String:
	"""Convert database timestamp to MM/DD format"""
	if timestamp_str == "":
		return ""
	
	var parts = timestamp_str.split(" ")
	if parts.size() == 1:
		parts = timestamp_str.split("T")
	
	if parts.size() == 0:
		return timestamp_str
	
	var date_part = parts[0]
	var date_parts = date_part.split("-")
	if date_parts.size() != 3:
		return date_part
	
	var month = date_parts[1]
	var day = date_parts[2]
	return "%s/%s" % [month, day]

func join_lobby_by_id(lobby_id: String) -> void:
	"""Join a specific lobby by its ID"""
	debug_log("Joining lobby by ID: %s" % lobby_id)
	
	if mock_mode:
		_mock_join_lobby(lobby_id)
		return
	
	supabase.current_request_type = "get_lobby_by_id"
	pending_callbacks["join_target_lobby_id"] = lobby_id
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + lobby_id
	
	var headers = supabase._get_db_headers()
	supabase.db_request.request(url, headers, HTTPClient.METHOD_GET)
	
func _add_self_to_lobby(lobby_id: String) -> void:
	"""Add ourselves to an existing lobby"""
	var player_data = _build_player_data()
	var players = current_lobby_data.get("players", [])
	
	for player in players:
		if player.get("id", "") == player_data.get("id", ""):
			debug_log("Already in lobby, just rejoining")
			lobby_joined.emit(current_lobby_data)
			start_polling()
			return
	
	players.append(player_data)
	
	var update_data = {
		"players": players,
		"player_count": players.size()
	}
	
	supabase.current_request_type = "update_lobby_join"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + lobby_id
	
	var headers = supabase._get_db_headers()
	headers.append("Prefer: return=representation")
	headers.append("Content-Type: application/json")
	
	var body = JSON.stringify(update_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func update_player_ready_state(player_id: String, is_ready: bool) -> void:
	"""Update a player's ready state in the lobby"""
	if not current_lobby_data.has("id"):
		debug_log("ERROR: No lobby to update ready state")
		return
	
	debug_log("Updating ready state for player %s to %s" % [player_id, is_ready])
	
	var players = current_lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	var player_found = false
	for i in range(players.size()):
		if players[i].get("id", "") == player_id:
			players[i]["is_ready"] = is_ready
			player_found = true
			break
	
	if not player_found:
		debug_log("ERROR: Player %s not found in lobby" % player_id)
		return
	
	var update_data = {
		"players": players
	}
	
	supabase.current_request_type = "update_player_ready"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + current_lobby_data.id
	
	var headers = supabase._get_db_headers()
	headers.append("Prefer: return=representation")
	headers.append("Content-Type: application/json")
	
	var body = JSON.stringify(update_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func mark_lobby_completed() -> void:
	"""Mark lobby as completed when game ends"""
	if not current_lobby_data.has("id"):
		debug_log("No lobby to mark completed")
		return
	
	var lobby_id = current_lobby_data.get("id", "")
	debug_log("Marking lobby as completed: %s" % lobby_id)
	
	var update_data = {
		"status": "completed"
		# Optional: "finished_at": Time.get_datetime_string_from_system()
	}
	
	supabase.current_request_type = "mark_lobby_completed"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + lobby_id
	
	var headers = supabase._get_db_headers()
	headers.append("Content-Type: application/json")
	
	var body = JSON.stringify(update_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func cleanup_stale_lobbies() -> void:
	"""Delete stale lobbies (waiting > 1 hour) and old completed lobbies (> 24 hours)"""
	debug_log("Cleaning up stale and old lobbies...")
	
	if mock_mode:
		return
	
	# Calculate timestamps
	var current_time = Time.get_unix_time_from_system()
	var one_hour_ago = current_time - 3600  # 3600 seconds = 1 hour
	var one_day_ago = current_time - 86400  # 86400 seconds = 24 hours
	
	# Convert to ISO 8601 format with timezone for Postgres
	var one_hour_ago_dt = Time.get_datetime_dict_from_unix_time(one_hour_ago)
	var iso_one_hour = "%04d-%02d-%02dT%02d:%02d:%02d+00:00" % [
		one_hour_ago_dt.year,
		one_hour_ago_dt.month,
		one_hour_ago_dt.day,
		one_hour_ago_dt.hour,
		one_hour_ago_dt.minute,
		one_hour_ago_dt.second
	]
	
	var one_day_ago_dt = Time.get_datetime_dict_from_unix_time(one_day_ago)
	var iso_one_day = "%04d-%02d-%02dT%02d:%02d:%02d+00:00" % [
		one_day_ago_dt.year,
		one_day_ago_dt.month,
		one_day_ago_dt.day,
		one_day_ago_dt.hour,
		one_day_ago_dt.minute,
		one_day_ago_dt.second
	]
	
	debug_log("  Current time (UTC): %s" % Time.get_datetime_string_from_system(true))
	debug_log("  Deleting 'waiting' lobbies older than: %s" % iso_one_hour)
	debug_log("  Deleting 'completed' lobbies older than: %s" % iso_one_day)
	
	# Delete stale waiting lobbies (> 1 hour old)
	supabase.current_request_type = "cleanup_stale_lobbies"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?status=eq.waiting"
	url += "&created_at=lt." + iso_one_hour
	
	var headers = supabase._get_db_headers()
	supabase.db_request.request(url, headers, HTTPClient.METHOD_DELETE)
	
	# Small delay between requests
	await get_tree().create_timer(0.1).timeout
	
	# Delete old completed lobbies (> 24 hours old)
	supabase.current_request_type = "cleanup_old_completed"
	var url2 = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url2 += "?status=eq.completed"
	url2 += "&created_at=lt." + iso_one_day
	
	supabase.db_request.request(url2, headers, HTTPClient.METHOD_DELETE)

func kick_player_from_lobby(player_id: String) -> void:
	"""Remove a player from the current lobby (host only)"""
	if not current_lobby_data.has("id"):
		debug_log("ERROR: No lobby to kick from")
		return
	
	var local_id = supabase.current_user.get("id", "")
	var host_id = current_lobby_data.get("host_id", "")
	
	# Verify we're the host
	if local_id != host_id:
		debug_log("ERROR: Only host can kick players")
		return
	
	debug_log("Kicking player: %s" % player_id)
	
	var players = current_lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	# Remove the player
	var new_players = []
	for player in players:
		if player.get("id", "") != player_id:
			new_players.append(player)
	
	# Update lobby
	var update_data = {
		"players": new_players,
		"player_count": new_players.size()
	}
	
	supabase.current_request_type = "kick_player"
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?id=eq." + current_lobby_data.id
	
	var headers = supabase._get_db_headers()
	headers.append("Prefer: return=representation")
	headers.append("Content-Type: application/json")
	
	var body = JSON.stringify(update_data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _exit_tree():
	"""Cleanup when leaving"""
	if lobby_poll_request:
		lobby_poll_request.queue_free()
	if emoji_poll_request:
		emoji_poll_request.queue_free()
