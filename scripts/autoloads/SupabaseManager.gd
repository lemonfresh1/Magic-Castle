# SupabaseManager.gd - Pure HTTP Supabase implementation (NO PLUGIN)
# Location: res://Pyramids/scripts/autoloads/SupabaseManager.gd
# Last Updated: Complete HTTP-only version with no plugin dependencies

extends Node

# === CONFIGURATION ===
const SUPABASE_URL = "https://nlawlwzjaliewvjetqzf.supabase.co"
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sYXdsd3pqYWxpZXd2amV0cXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3MjMwOTcsImV4cCI6MjA3NDI5OTA5N30.TVcRp_KjZzLLayXqOc4AmpexjnsQeZN23UZ2PwJHH0o"

# === HTTP REQUEST NODES ===
var auth_request: HTTPRequest
var db_request: HTTPRequest
var realtime_request: HTTPRequest

# === REQUEST TRACKING ===
var current_request_type: String = ""
var pending_callbacks: Dictionary = {}

# === STATE ===
var current_user: Dictionary = {}
var access_token: String = ""
var refresh_token: String = ""
var is_authenticated: bool = false
var profile: Dictionary = {}
var mock_mode: bool = false  # For compatibility with NetworkManager

# Retry configuration
const MAX_RETRIES: int = 3
const RETRY_DELAY: float = 1.0
var retry_counts: Dictionary = {}  # request_id -> count

# Request queue for offline mode
var request_queue: Array[Dictionary] = []
var is_offline: bool = false

var skip_auto_login: bool = false


# === DEBUG ===
var debug_enabled: bool = true

# === SIGNALS ===
signal authenticated(user_data: Dictionary)
signal profile_loaded(profile_data: Dictionary)
signal authentication_failed(error: String)
signal connection_established()
signal connection_failed(error: String)
signal request_completed(data)
signal request_failed(error: String)

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[SupabaseManager] %s" % message)

func _ready():
	debug_log("Initializing pure HTTP Supabase client...")
	
	# Create HTTP request nodes for different operations
	auth_request = HTTPRequest.new()
	auth_request.name = "AuthRequest"
	auth_request.timeout = 10.0
	add_child(auth_request)
	auth_request.request_completed.connect(_on_auth_request_completed)
	
	db_request = HTTPRequest.new()
	db_request.name = "DBRequest"
	db_request.timeout = 10.0
	add_child(db_request)
	db_request.request_completed.connect(_on_db_request_completed)
	
	realtime_request = HTTPRequest.new()
	realtime_request.name = "RealtimeRequest"
	realtime_request.timeout = 10.0
	add_child(realtime_request)
	realtime_request.request_completed.connect(_on_realtime_request_completed)
	
	debug_log("HTTP client ready")
	
	# Emit connection established
	await get_tree().process_frame
	connection_established.emit()
	
	# NO AUTO-LOGIN HERE - LoginUI handles all authentication
	# The skip_auto_login flag is no longer needed
	debug_log("SupabaseManager ready - waiting for authentication requests")

# === AUTHENTICATION METHODS ===

func login_anonymous() -> void:
	"""Sign in anonymously - creates a new anonymous user"""
	debug_log("Attempting anonymous sign in...")
	current_request_type = "auth_anonymous"
	
	var url = SUPABASE_URL + "/auth/v1/signup"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]
	
	# Anonymous signup with empty body
	var body = JSON.stringify({})
	
	var error = auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		debug_log("Failed to make request: %d" % error)
		authentication_failed.emit("Request failed")

func sign_out() -> void:
	"""Sign out current user"""
	debug_log("Signing out...")
	current_user = {}
	access_token = ""
	refresh_token = ""
	is_authenticated = false
	profile = {}

# === DATABASE METHODS ===

func query(table_name: String) -> DatabaseQuery:
	"""Create a new database query (returns helper object)"""
	var query = DatabaseQuery.new()
	query.table = table_name
	query.manager = self
	return query

func insert(table_name: String, data: Dictionary) -> void:
	"""Insert a record into a table"""
	debug_log("Inserting into %s" % table_name)
	current_request_type = "insert"
	
	var url = SUPABASE_URL + "/rest/v1/" + table_name
	var headers = _get_db_headers()
	headers.append("Prefer: return=representation")
	
	var body = JSON.stringify(data)
	db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func update(table_name: String, data: Dictionary, filters: Dictionary) -> void:
	"""Update records in a table"""
	debug_log("Updating %s" % table_name)
	current_request_type = "update"
	
	# Build filter string
	var filter_parts = []
	for key in filters:
		filter_parts.append("%s=eq.%s" % [key, filters[key]])
	
	var url = SUPABASE_URL + "/rest/v1/" + table_name + "?" + "&".join(filter_parts)
	var headers = _get_db_headers()
	headers.append("Prefer: return=representation")
	
	var body = JSON.stringify(data)
	db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)

func select(table_name: String, columns: String = "*", filter: String = "") -> void:
	"""Select records from a table"""
	debug_log("Selecting from %s" % table_name)
	current_request_type = "select"
	
	var url = SUPABASE_URL + "/rest/v1/" + table_name
	url += "?select=" + columns
	if filter:
		url += "&" + filter
	
	var headers = _get_db_headers()
	db_request.request(url, headers, HTTPClient.METHOD_GET)

# === PROFILE METHODS ===

func _ensure_profile_exists() -> void:
	"""Check if profile exists, create if not"""
	if not is_authenticated or current_user.is_empty():
		debug_log("Cannot check profile - not authenticated")
		return
	
	var user_id = current_user.get("id", "")
	if user_id == "":
		debug_log("No user ID for profile check")
		return
	
	debug_log("Checking profile for user: %s" % user_id)
	current_request_type = "profile_check"
	
	# Query for existing profile
	var url = SUPABASE_URL + "/rest/v1/pyramids_profiles?id=eq." + user_id
	var headers = _get_db_headers()
	
	db_request.request(url, headers, HTTPClient.METHOD_GET)

func _create_new_profile() -> void:
	"""Create a new profile for current user"""
	var user_id = current_user.get("id", "")
	debug_log("Creating profile for user: %s" % user_id)
	
	current_request_type = "profile_create"
	
	var display_name = "Player"
	if has_node("/root/SettingsSystem"):
		var settings = get_node("/root/SettingsSystem")
		if "player_name" in settings:
			display_name = settings.player_name
	
	var new_profile = {
		"id": user_id,
		"username": "player_%s" % user_id.substr(0, 8),
		"display_name": display_name,
		"mmr": 1000,
		"stats": {}
	}
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_profiles"
	var headers = _get_db_headers()
	headers.append("Prefer: return=representation")
	
	var body = JSON.stringify(new_profile)
	db_request.request(url, headers, HTTPClient.METHOD_POST, body)

# === REQUEST HANDLERS ===

func _on_auth_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	debug_log("Auth response code: %d" % response_code)
	
	if response_code >= 200 and response_code < 300:
		var json = JSON.new()
		var parse_result = json.parse(response_text)
		
		if parse_result == OK:
			var data = json.data
			
			# ✅ Handle token refresh separately
			if current_request_type == "token_refresh":
				if data.has("access_token"):
					access_token = data.access_token
					refresh_token = data.get("refresh_token", refresh_token)  # Use new or keep old
					debug_log("✅ Token refreshed successfully")
					
					# Update current user
					if data.has("user"):
						current_user = data.user
					
					is_authenticated = true
					authenticated.emit(current_user)
					
					# Check/create profile
					_ensure_profile_exists()
				else:
					debug_log("❌ Token refresh failed - no access_token in response")
					authentication_failed.emit("Refresh failed")
				return
			
			# Handle regular auth response (login/signup)
			if data.has("access_token"):
				access_token = data.access_token
				debug_log("Got access token")
			
			if data.has("refresh_token"):
				refresh_token = data.refresh_token
			
			if data.has("user"):
				current_user = data.user
				is_authenticated = true
				debug_log("Authenticated user: %s" % current_user.get("id", "unknown"))
				authenticated.emit(current_user)
				
				# Check/create profile
				_ensure_profile_exists()
			else:
				debug_log("No user in auth response")
				authentication_failed.emit("No user data")
		else:
			debug_log("Failed to parse auth response")
			authentication_failed.emit("Invalid response format")
	else:
		debug_log("Auth failed with code %d: %s" % [response_code, response_text])
		authentication_failed.emit("HTTP %d" % response_code)

func _on_db_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	debug_log("DB response code: %d for request: %s" % [response_code, current_request_type])
	
	if response_code >= 200 and response_code < 300:
		# Handle 204 No Content (successful request with no response body)
		if response_code == 204:
			debug_log("✅ Request successful (204 No Content)")
			
			# Handle specific request types that return 204
			match current_request_type:
				"mark_lobby_completed":
					debug_log("✅ Lobby marked as completed")
				"cleanup_stale_lobbies":
					debug_log("✅ Stale lobbies cleaned up")
				"cleanup_old_completed":
					debug_log("✅ Old completed lobbies cleaned up")
				_:
					debug_log("✅ Operation completed successfully")
			
			request_completed.emit(null)
			return
		
		# For all other 2xx responses, parse JSON
		var json = JSON.new()
		var parse_result = json.parse(response_text)
		
		if parse_result == OK:
			var data = json.data
			
			# Handle based on request type
			match current_request_type:
				"profile_check":
					if response_code == 401:
						# Token expired
						debug_log("Token expired during profile check")
						authentication_failed.emit("Token expired")
						
						# Tell AuthManager to handle expired token
						if has_node("/root/AuthManager"):
							var auth = get_node("/root/AuthManager")
							auth._on_token_expired()
						return
					
					if data is Array and data.size() > 0:
						profile = data[0]
						debug_log("Profile found: %s" % profile.get("display_name", "Unknown"))
						profile_loaded.emit(profile)
					else:
						debug_log("No profile found, creating...")
						_create_new_profile()
				
				"profile_create":
					if data is Array and data.size() > 0:
						profile = data[0]
					elif data is Dictionary:
						profile = data
					debug_log("Profile created successfully")
					profile_loaded.emit(profile)
				
				"profile_upsert":
					if data is Array and data.size() > 0:
						profile = data[0]
					elif data is Dictionary:
						profile = data
					debug_log("Profile upserted successfully")
					profile_loaded.emit(profile)
				
				"save_highscore":
					debug_log("✅ Highscore saved successfully!")
					request_completed.emit(data)
				
				"get_highscores":
					debug_log("✅ Retrieved %d highscores" % data.size())
					request_completed.emit(data)
				
				"insert":
					debug_log("✅ Insert successful")
					request_completed.emit(data)
				
				"update":
					debug_log("✅ Update successful")
					request_completed.emit(data)
				
				"select":
					debug_log("✅ Select returned %d records" % data.size())
					request_completed.emit(data)
				
				"test":
					debug_log("✅ Database connection successful!")
					is_offline = false
					_on_connection_restored()
					request_completed.emit(data)
				
				"stats_upsert":
					if data is Array and data.size() > 0:
						debug_log("✅ Stats synced successfully")
					elif data is Dictionary:
						debug_log("✅ Stats synced successfully (single record)")
					else:
						debug_log("✅ Stats sync completed")
					request_completed.emit(data)
				
				"mp_stats_upsert":
					debug_log("✅ Multiplayer stats synced successfully")
					request_completed.emit(data)
				
				"achievement_upsert":
					debug_log("✅ Achievement synced successfully")
					request_completed.emit(data)
				
				"stats_load":
					if data is Array and data.size() > 0:
						var stats_data = data[0]
						debug_log("✅ Stats loaded from database")
						
						# Pass to StatsManager to merge with local
						if has_node("/root/StatsManager"):
							var stats_mgr = get_node("/root/StatsManager")
							stats_mgr.load_stats_from_db(stats_data)
					else:
						debug_log("No stats found in database - will create on first sync")
					request_completed.emit(data)
				
				"inventory_load":
					debug_log("✅ Inventory loaded (Chunk 3)")
					request_completed.emit(data)
				
				"achievement_load":
					debug_log("✅ Achievements loaded (Chunk 4)")
					request_completed.emit(data)
				
				"mission_load":
					debug_log("✅ Missions loaded (Chunk 5)")
					request_completed.emit(data)
				
				_:
					request_completed.emit(data)
		else:
			debug_log("Failed to parse DB response")
			request_failed.emit("Parse error")
	else:
		# Enhanced error handling
		_handle_db_error(response_code, response_text)

func _on_realtime_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	# Placeholder for realtime functionality
	pass

# === HELPER METHODS ===

func _get_db_headers() -> PackedStringArray:
	"""Get headers for database requests"""
	var headers = PackedStringArray()
	headers.append("apikey: " + SUPABASE_KEY)
	
	# Use access token if we have one, otherwise use anon key
	if access_token:
		headers.append("Authorization: Bearer " + access_token)
	else:
		headers.append("Authorization: Bearer " + SUPABASE_KEY)
	
	headers.append("Content-Type: application/json")
	return headers

# === GAME OPERATIONS ===

func save_highscore(mode: String, score: int, seed: int) -> void:
	"""Save a highscore to the leaderboard"""
	debug_log("Saving highscore - Mode: %s, Score: %d" % [mode, score])
	
	# Ensure seed fits in PostgreSQL INTEGER range
	if seed > 2147483647:
		seed = seed % 2147483647
	
	var highscore_data = {
		"mode": mode,
		"player_id": current_user.get("id", ""),
		"player_name": profile.get("display_name", "Unknown"),
		"score": score,
		"seed": seed
	}
	
	current_request_type = "save_highscore"
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_highscores"
	var headers = _get_db_headers()
	headers.append("Prefer: return=representation")
	
	var body = JSON.stringify(highscore_data)
	db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func get_highscores(mode: String, limit: int = 20) -> void:
	"""Get top highscores for a mode"""
	debug_log("Getting highscores for mode: %s" % mode)
	
	current_request_type = "get_highscores"
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_highscores"
	url += "?mode=eq." + mode
	url += "&order=score.desc"
	url += "&limit=" + str(limit)
	
	var headers = _get_db_headers()
	db_request.request(url, headers, HTTPClient.METHOD_GET)

func test_connection() -> void:
	"""Test database connectivity"""
	debug_log("Testing database connection...")
	current_request_type = "test"
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_profiles?limit=1"
	var headers = _get_db_headers()
	
	db_request.request(url, headers, HTTPClient.METHOD_GET)

func get_connection_status() -> Dictionary:
	"""Get current connection status"""
	return {
		"supabase_exists": true,  # We're always "connected" with HTTP
		"auth_exists": auth_request != null,
		"database_exists": db_request != null,
		"is_authenticated": is_authenticated,
		"has_profile": not profile.is_empty(),
		"user_id": current_user.get("id", "none")
	}

# === HELPER CLASS ===

class DatabaseQuery:
	"""Helper class for building database queries"""
	var table: String = ""
	var manager: Node = null
	var filters: Array = []
	var select_columns: String = "*"
	
	func select(columns: String = "*") -> DatabaseQuery:
		select_columns = columns
		return self
	
	func eq(column: String, value) -> DatabaseQuery:
		filters.append("%s=eq.%s" % [column, str(value)])
		return self
	
	func execute() -> void:
		if manager and table:
			var filter_string = "&".join(filters)
			manager.select(table, select_columns, filter_string)

# === TEST AUTH FUNCTIONS ===
func quick_test_login(test_number: int) -> void:
	"""Quick login for testing - just use test1, test2, etc"""
	var email = "test%d@test.com" % test_number
	var password = "test123456"
	sign_in_with_email(email, password)

func quick_create_test_accounts() -> void:
	"""One-time setup to create test accounts"""
	for i in range(1, 9):  # Create test1 through test8
		var email = "test%d@test.com" % i
		var password = "test123456"
		var player_name = "Player%d" % i
		sign_up_with_email(email, password, player_name)
		await get_tree().create_timer(0.5).timeout  # Avoid rate limiting

func sign_up_with_email(email: String, password: String, player_name: String = "Player") -> void:
	"""Sign up with email and password"""
	print("[SupabaseManager] Signing up with email: %s" % email)
	
	var body = {
		"email": email,
		"password": password,
		"data": {
			"player_name": player_name
		}
	}
	
	current_request_type = "auth_signup"
	
	var url = SUPABASE_URL + "/auth/v1/signup"
	var headers = _get_auth_headers()
	headers.append("Content-Type: application/json")
	
	auth_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func sign_in_with_email(email: String, password: String) -> void:
	"""Sign in with email and password"""
	print("[SupabaseManager] Signing in with email: %s" % email)
	
	var body = {
		"email": email,
		"password": password
	}
	
	current_request_type = "auth_signin"
	
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=password"
	var headers = _get_auth_headers()
	headers.append("Content-Type: application/json")
	
	auth_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _get_auth_headers() -> PackedStringArray:
	"""Get headers for auth requests"""
	var headers = PackedStringArray()
	headers.append("apikey: " + SUPABASE_KEY)
	return headers

func fetch_data(table: String, column: String, value: String) -> Array:
	"""Generic fetch helper"""
	current_request_type = "fetch_profile"
	var url = SUPABASE_URL + "/rest/v1/" + table
	url += "?" + column + "=eq." + value
	
	var headers = _get_db_headers()
	db_request.request(url, headers, HTTPClient.METHOD_GET)
	
	# Wait for response
	await request_completed
	# Return the response data (you'll need to store it in the response handler)
	return []  # Placeholder - implement based on your response handling

func insert_data(table: String, data: Dictionary) -> void:
	"""Generic insert helper"""
	current_request_type = "insert_profile"
	var url = SUPABASE_URL + "/rest/v1/" + table
	
	var headers = _get_db_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: return=representation")
	
	var body = JSON.stringify(data)
	db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func upsert_profile(profile_data: Dictionary) -> void:
	"""Insert or update profile (handles conflicts)"""
	debug_log("Upserting profile for user: %s" % profile_data.get("id", "unknown"))
	current_request_type = "profile_upsert"
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_profiles"
	var headers = _get_db_headers()
	headers.append("Prefer: resolution=merge-duplicates,return=representation")
	
	var body = JSON.stringify(profile_data)
	db_request.request(url, headers, HTTPClient.METHOD_POST, body)

func _retry_request(request_data: Dictionary) -> void:
	"""Retry a failed request"""
	var request_id = request_data.get("id", "")
	var retry_count = retry_counts.get(request_id, 0)
	
	if retry_count >= MAX_RETRIES:
		debug_log("Max retries reached for request: %s" % request_id)
		request_failed.emit("Max retries exceeded")
		retry_counts.erase(request_id)
		return
	
	retry_count += 1
	retry_counts[request_id] = retry_count
	
	debug_log("Retrying request %s (attempt %d/%d)" % [request_id, retry_count, MAX_RETRIES])
	
	# Wait before retry
	await get_tree().create_timer(RETRY_DELAY * retry_count).timeout
	
	# Retry based on request type
	match request_data.get("type", ""):
		"profile_update":
			update("pyramids_profiles", request_data.get("data", {}), {"id": request_data.get("user_id", "")})
		"profile_insert":
			insert("pyramids_profiles", request_data.get("data", {}))
		_:
			debug_log("Unknown request type for retry")

func _queue_request(request_data: Dictionary) -> void:
	"""Queue request for later when connection is restored"""
	request_queue.append(request_data)
	debug_log("Request queued (total: %d)" % request_queue.size())

func _process_queued_requests() -> void:
	"""Process all queued requests when connection is restored"""
	if request_queue.is_empty():
		return
	
	debug_log("Processing %d queued requests..." % request_queue.size())
	
	for request in request_queue:
		match request.get("type", ""):
			"profile_update":
				update("pyramids_profiles", request.get("data", {}), {"id": request.get("user_id", "")})
			"profile_insert":
				insert("pyramids_profiles", request.get("data", {}))
		
		await get_tree().create_timer(0.5).timeout  # Space out requests
	
	request_queue.clear()
	
func _handle_db_error(response_code: int, response_text: String) -> void:
	"""Enhanced error handling with retry logic"""
	debug_log("Database error %d: %s" % [response_code, response_text])
	
	var should_retry = false
	var error_message = ""
	
	match response_code:
		401:  # Unauthorized - Token expired
			error_message = "Authentication expired"
			
			# Special handling for profile_check - token is expired
			if current_request_type == "profile_check":
				debug_log("Token expired during profile check")
				authentication_failed.emit("Token expired")
				
				# Tell AuthManager to handle expired token
				if has_node("/root/AuthManager"):
					var auth = get_node("/root/AuthManager")
					auth._on_token_expired()
				return  # Don't continue with normal error handling
			
			# For other 401s, might need token refresh
			# TODO: Implement token refresh
			
		409:  # Conflict
			error_message = "Data conflict"
			if current_request_type == "profile_create":
				debug_log("Profile already exists, loading it instead")
				_ensure_profile_exists()
				return
				
		429:  # Rate limited
			error_message = "Rate limited"
			should_retry = true
			
		500, 502, 503, 504:  # Server errors
			error_message = "Server error"
			should_retry = true
			
		0:  # Network error
			error_message = "Network error"
			is_offline = true
			_handle_offline_mode()
			return
			
		_:
			error_message = "Request failed: %d" % response_code
	
	if should_retry:
		var request_data = {
			"id": str(Time.get_ticks_msec()),
			"type": current_request_type,
			"data": {},
			"user_id": current_user.get("id", "")
		}
		_retry_request(request_data)
	else:
		request_failed.emit(error_message)

func _handle_offline_mode() -> void:
	"""Switch to offline mode"""
	debug_log("Entering offline mode")
	is_offline = true
	connection_failed.emit("No connection")
	
	# Try to reconnect periodically
	_schedule_reconnect()

func _schedule_reconnect() -> void:
	"""Schedule reconnection attempt"""
	await get_tree().create_timer(5.0).timeout
	
	if is_offline:
		debug_log("Attempting to reconnect...")
		test_connection()
		
		# If still offline, schedule another attempt
		if is_offline:
			_schedule_reconnect()
			
func _on_connection_restored() -> void:
	"""Handle connection restoration"""
	debug_log("Connection restored!")
	is_offline = false
	connection_established.emit()
	
	# Process any queued requests
	_process_queued_requests()

func load_stats_from_db(profile_id: String) -> void:
	"""Load stats for a profile from database"""
	debug_log("Loading stats for profile: %s" % profile_id)
	
	current_request_type = "stats_load"
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_stats?profile_id=eq." + profile_id
	var headers = _get_db_headers()
	
	db_request.request(url, headers, HTTPClient.METHOD_GET)

func load_multiplayer_stats_from_db(profile_id: String, mode: String = "") -> void:
	"""Load multiplayer stats for a profile"""
	debug_log("Loading multiplayer stats for profile: %s" % profile_id)
	
	current_request_type = "mp_stats_load"
	
	var url = SUPABASE_URL + "/rest/v1/pyramids_multiplayer_stats?profile_id=eq." + profile_id
	if mode != "":
		url += "&mode_id=eq." + mode
	
	var headers = _get_db_headers()
	db_request.request(url, headers, HTTPClient.METHOD_GET)

func refresh_session(refresh_tok: String) -> void:
	"""Refresh expired access token using refresh token"""
	debug_log("Refreshing session...")
	
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]
	
	var body = JSON.stringify({
		"refresh_token": refresh_tok
	})
	
	current_request_type = "token_refresh"
	
	var error = auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		debug_log("Failed to refresh token: %d" % error)
		authentication_failed.emit("Refresh failed")
