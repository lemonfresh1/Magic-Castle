# AuthManager.gd - Dedicated authentication and token management
# Location: res://Pyramids/scripts/autoloads/AuthManager.gd
# Last Updated: Complete auth system with token persistence

extends Node

# === SIGNALS ===
signal login_started()
signal login_completed(user_data: Dictionary)
signal login_failed(error: String)
signal logout_completed()
signal anonymous_account_created()
signal account_upgraded(user_data: Dictionary)

# === AUTH STATE ===
var is_authenticated: bool = false
var is_anonymous: bool = false
var current_user: Dictionary = {}
var access_token: String = ""
var refresh_token: String = ""

# === TOKEN PERSISTENCE ===
const TOKEN_SAVE_PATH = "user://auth_tokens.save"
const TOKEN_ENCRYPTION_KEY = "PyramidsSolitaire2025"  # Change in production

# === DEBUG ===
var debug_enabled: bool = true

func debug_log(message: String) -> void:
	if debug_enabled:
		print("[AuthManager] %s" % message)

func _ready():
	_connect_signals()
	
	# Don't auto-login here - let LoginUI handle it
	# Auto-login will be triggered by LoginUI when it's ready

func _connect_signals() -> void:
	# Connect to SupabaseManager
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.authenticated.connect(_on_supabase_authenticated)
		supabase.authentication_failed.connect(_on_authentication_failed)

# === AUTO LOGIN ===

func attempt_auto_login() -> void:
	"""Try to login with saved tokens or create anonymous - PUBLIC method for LoginUI to call"""
	debug_log("Attempting auto-login...")
	
	# Try to load saved tokens
	if _load_saved_tokens():
		debug_log("Found saved tokens, validating...")
		_validate_saved_session()
	else:
		debug_log("No saved session found")
		# Don't auto-create anonymous here - let LoginUI decide

func _validate_saved_session() -> void:
	"""Validate saved access token and restore session"""
	# For now, assume token is valid and try to use it
	
	if not access_token.is_empty():
		is_authenticated = true
		debug_log("Using saved session")
		
		# Update SupabaseManager with the token
		if has_node("/root/SupabaseManager"):
			var supabase = get_node("/root/SupabaseManager")
			supabase.access_token = access_token
			supabase.refresh_token = refresh_token
			supabase.is_authenticated = true
			supabase.current_user = current_user
			
			# Load profile for the restored session
			debug_log("Loading profile for restored session...")
			supabase._ensure_profile_exists()
		
		# Emit login completed so LoginUI knows we're authenticated
		login_completed.emit(current_user)
	else:
		debug_log("No valid access token in saved session")
		login_anonymous()

# === ANONYMOUS AUTH ===

func login_anonymous() -> void:
	"""Create anonymous account for seamless start"""
	debug_log("Creating anonymous account...")
	login_started.emit()
	
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.login_anonymous()
	else:
		push_error("SupabaseManager not found!")
		login_failed.emit("System not initialized")

# === EMAIL AUTH ===

func login_with_email(email: String, password: String) -> void:
	"""Login with email and password"""
	debug_log("Logging in with email: %s" % email)
	login_started.emit()
	
	# Validate inputs
	if email.is_empty() or password.is_empty():
		login_failed.emit("Email and password required")
		return
	
	if not _is_valid_email(email):
		login_failed.emit("Invalid email format")
		return
	
	if password.length() < 6:
		login_failed.emit("Password too short")
		return
	
	# Perform login
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.sign_in_with_email(email, password)

func register_with_email(email: String, password: String, display_name: String = "") -> void:
	"""Register new account with email"""
	debug_log("Registering with email: %s" % email)
	login_started.emit()
	
	# Validate inputs
	if email.is_empty() or password.is_empty():
		login_failed.emit("Email and password required")
		return
	
	if not _is_valid_email(email):
		login_failed.emit("Invalid email format")
		return
	
	if password.length() < 6:
		login_failed.emit("Password must be at least 6 characters")
		return
	
	if display_name.is_empty():
		display_name = "Player%d" % (randi() % 9999)
	
	# Perform registration
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.sign_up_with_email(email, password, display_name)

func upgrade_anonymous_account(email: String, password: String) -> void:
	"""Upgrade anonymous account to permanent email account"""
	if not is_anonymous:
		debug_log("Account is not anonymous")
		login_failed.emit("Account already has email")
		return
	
	debug_log("Upgrading anonymous account to: %s" % email)
	
	# Validate inputs
	if not _is_valid_email(email):
		login_failed.emit("Invalid email format")
		return
	
	if password.length() < 6:
		login_failed.emit("Password must be at least 6 characters")
		return
	
	# In Supabase, this is done via update user endpoint
	# For now, we'll create a new account and transfer data
	# This would need custom Supabase Edge Function in production
	
	# TODO: Implement actual upgrade via Supabase Edge Function
	debug_log("Account upgrade not yet implemented - create new account instead")
	register_with_email(email, password)

# === LOGOUT ===

func logout() -> void:
	"""Logout current user"""
	debug_log("Logging out...")
	
	# Clear tokens
	access_token = ""
	refresh_token = ""
	current_user.clear()
	is_authenticated = false
	is_anonymous = false
	
	# Clear saved tokens
	_clear_saved_tokens()
	
	# Clear ProfileManager
	if has_node("/root/ProfileManager"):
		var profile_manager = get_node("/root/ProfileManager")
		profile_manager.clear_cache()
	
	# Sign out from Supabase
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		supabase.sign_out()
	
	logout_completed.emit()
	debug_log("Logout complete")

# === TOKEN MANAGEMENT ===

func _save_tokens() -> void:
	"""Save auth tokens to disk with detailed debugging"""
	if access_token.is_empty():
		debug_log("No access token to save")
		return
	
	var data = {
		"access_token": access_token,
		"refresh_token": refresh_token,
		"user_id": current_user.get("id", ""),
		"is_anonymous": is_anonymous,
		"saved_at": Time.get_ticks_msec()
	}
	
	# Convert to JSON string
	var json_string = JSON.stringify(data)
	debug_log("JSON to save (length %d): %s..." % [json_string.length(), json_string.substr(0, 50)])
	
	# Get the actual file path for debugging
	var actual_path = OS.get_user_data_dir() + "/auth_tokens.save"
	debug_log("Attempting to save to: %s" % actual_path)
	
	# Try to open file with detailed error checking
	var file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		debug_log("ERROR: Failed to open file for writing. Error code: %d" % error)
		debug_log("Possible reasons: Permission denied, invalid path, or disk full")
		
		# Try to create the directory first
		var dir = DirAccess.open("user://")
		if dir:
			debug_log("User directory exists: %s" % dir.get_current_dir())
			# List files to see what's there
			dir.list_dir_begin()
			var file_name = dir.get_next()
			var files = []
			while file_name != "":
				files.append(file_name)
				file_name = dir.get_next()
			debug_log("Files in user directory: %s" % str(files))
		else:
			debug_log("ERROR: Cannot open user directory")
		return
	
	# Write the file
	file.store_string(json_string)
	file.close()
	debug_log("File write completed")
	
	# Verify file was created with multiple checks
	if FileAccess.file_exists(TOKEN_SAVE_PATH):
		debug_log("✅ Token file verified at: %s" % TOKEN_SAVE_PATH)
		
		# Double check by trying to read it back
		var verify_file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.READ)
		if verify_file:
			var content = verify_file.get_as_text()
			verify_file.close()
			debug_log("✅ Verified file content (length %d)" % content.length())
		else:
			debug_log("❌ File exists but cannot read it back")
		
		# Check the actual filesystem path
		debug_log("Full filesystem path: %s" % actual_path)
	else:
		debug_log("❌ ERROR: Token file not found after save!")
		debug_log("This shouldn't happen - file write succeeded but file doesn't exist")

func _load_saved_tokens() -> bool:
	"""Load saved auth tokens"""
	debug_log("Checking for saved tokens at: %s" % TOKEN_SAVE_PATH)
	
	if not FileAccess.file_exists(TOKEN_SAVE_PATH):
		debug_log("No token file exists")
		return false
	
	debug_log("Token file exists, opening...")
	var file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.READ)
	if not file:
		debug_log("Failed to open token file")
		return false
	
	var file_content = file.get_as_text()
	file.close()
	debug_log("Read file content length: %d" % file_content.length())
	
	# TEMPORARY: Try to parse as plain JSON (no decryption)
	# TODO: Re-implement with proper encryption
	var json = JSON.new()
	var parse_result = json.parse(file_content)
	
	if parse_result != OK:
		debug_log("Failed to parse JSON: %s" % json.get_error_message())
		debug_log("File might be from old encryption format, clearing...")
		_clear_saved_tokens()
		return false
	
	var data = json.data
	debug_log("Parsed data successfully")
	
	if data and data is Dictionary:
		debug_log("Data is valid dictionary with keys: %s" % str(data.keys()))
		# Check if tokens are not too old (7 days)
		var saved_time = data.get("saved_at", 0)
		var current_time = Time.get_ticks_msec()
		var seven_days_ms = 7 * 24 * 60 * 60 * 1000
		
		if current_time - saved_time > seven_days_ms:
			debug_log("Saved tokens expired (older than 7 days)")
			_clear_saved_tokens()
			return false
		
		access_token = data.get("access_token", "")
		refresh_token = data.get("refresh_token", "")
		current_user["id"] = data.get("user_id", "")
		is_anonymous = data.get("is_anonymous", false)
		
		debug_log("Loaded saved tokens for user: %s" % current_user.get("id", "unknown"))
		debug_log("Tokens loaded - Access: %s... Refresh: %s..." % [
			access_token.substr(0, 10) if access_token.length() > 10 else "none",
			refresh_token.substr(0, 10) if refresh_token.length() > 10 else "none"
		])
		
		# Mark as authenticated
		is_authenticated = true
		
		return true
	
	debug_log("Data is not a valid dictionary")
	return false

func _clear_saved_tokens() -> void:
	"""Delete saved tokens"""
	if FileAccess.file_exists(TOKEN_SAVE_PATH):
		DirAccess.remove_absolute(TOKEN_SAVE_PATH)
		debug_log("Saved tokens cleared")

func _simple_encrypt(text: String) -> String:
	"""Simple XOR encryption (replace with proper encryption in production)"""
	var result = ""
	var key_bytes = TOKEN_ENCRYPTION_KEY.to_utf8_buffer()
	var text_bytes = text.to_utf8_buffer()
	
	for i in range(text_bytes.size()):
		var encrypted_byte = text_bytes[i] ^ key_bytes[i % key_bytes.size()]
		result += char(encrypted_byte)
	
	return Marshalls.raw_to_base64(result.to_utf8_buffer())

func _simple_decrypt(encrypted: String) -> String:
	"""Simple XOR decryption"""
	var bytes = Marshalls.base64_to_raw(encrypted)
	var result = ""
	var key_bytes = TOKEN_ENCRYPTION_KEY.to_utf8_buffer()
	
	for i in range(bytes.size()):
		var decrypted_byte = bytes[i] ^ key_bytes[i % key_bytes.size()]
		result += char(decrypted_byte)
	
	return result

# === VALIDATION ===

func _is_valid_email(email: String) -> bool:
	"""Basic email validation"""
	var regex = RegEx.new()
	regex.compile("^[^@]+@[^@]+\\.[^@]+$")
	return regex.search(email) != null

# === SIGNAL HANDLERS ===

func _on_supabase_authenticated(user_data: Dictionary) -> void:
	"""Handle successful authentication from Supabase"""
	debug_log("Authentication callback received")
	current_user = user_data
	is_authenticated = true
	
	# Check if anonymous
	is_anonymous = user_data.get("is_anonymous", false)
	if not is_anonymous and user_data.has("email"):
		is_anonymous = user_data.get("email", "").is_empty()
	
	# Get tokens from SupabaseManager
	if has_node("/root/SupabaseManager"):
		var supabase = get_node("/root/SupabaseManager")
		access_token = supabase.access_token
		refresh_token = supabase.refresh_token
		debug_log("Got tokens - Access: %s... Refresh: %s..." % [
			access_token.substr(0, 10) if access_token.length() > 10 else "none",
			refresh_token.substr(0, 10) if refresh_token.length() > 10 else "none"
		])
	
	# Save tokens for next session
	_save_tokens()
	
	debug_log("Authentication successful - User: %s (Anonymous: %s)" % 
		[current_user.get("id", "unknown"), is_anonymous])
	
	if is_anonymous:
		anonymous_account_created.emit()
	
	login_completed.emit(current_user)

func _on_authentication_failed(error: String) -> void:
	"""Handle authentication failure"""
	debug_log("Authentication failed: %s" % error)
	login_failed.emit(error)

# === GETTERS ===

func get_user_id() -> String:
	return current_user.get("id", "")

func is_logged_in() -> bool:
	return is_authenticated

func is_anonymous_account() -> bool:
	return is_anonymous

func get_user_email() -> String:
	if is_anonymous:
		return ""
	return current_user.get("email", "")
