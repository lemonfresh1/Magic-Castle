# LoginUI.gd - Login/Registration UI controller
# Location: res://Pyramids/scenes/ui/menus/LoginUI.gd
# Last Updated: Complete auth UI with validation and feedback

extends Control

# === UI REFERENCES ===
@onready var tab_container: TabContainer = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer
@onready var status_label: Label = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/BottomVBox/StatusLabel
@onready var loading_indicator: ProgressBar = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/BottomVBox/LoadingIndicator
@onready var close_button: Node = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/BottomVBox/CloseButton  # StyledButton

# Login tab
@onready var email_input: LineEdit = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Login/EmailSection/EmailInput
@onready var password_input: LineEdit = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Login/PasswordSection/PasswordInput
@onready var remember_check: CheckBox = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Login/RememberCheck
@onready var login_button: Node = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Login/LoginButton  # StyledButton

# Register tab  
@onready var display_name_input: LineEdit = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Register/DisplayNameSection/DisplayNameInput
@onready var register_email_input: LineEdit = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Register/EmailSection/RegisterEmailInput
@onready var register_password_input: LineEdit = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Register/PasswordSection/RegisterPasswordInput
@onready var confirm_password_input: LineEdit = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Register/ConfirmSection/ConfirmPasswordInput
@onready var register_button: Node = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Register/RegisterButton  # StyledButton

# Guest tab
@onready var guest_button: Node = $CenterContainer/LoginPanel/MarginContainer/VBoxContainer/TabContainer/Guest/GuestButton  # StyledButton

# === STATE ===
var is_loading: bool = false
var is_guest_mode: bool = false
var auth_manager: Node
var profile_manager: Node

# === COLORS ===
const COLOR_ERROR = Color(1, 0.3, 0.3)
const COLOR_SUCCESS = Color(0.3, 1, 0.3)
const COLOR_INFO = Color(0.8, 0.8, 0.8)

func _ready():
	# Get managers
	auth_manager = get_node("/root/AuthManager")
	profile_manager = get_node("/root/ProfileManager")
	
	# Debug: Check user data path
	print("User data directory: ", OS.get_user_data_dir())
	print("Token file would be at: ", OS.get_user_data_dir() + "/auth_tokens.save")
	
	# Connect auth signals
	auth_manager.login_started.connect(_on_login_started)
	auth_manager.login_completed.connect(_on_login_completed)
	auth_manager.login_failed.connect(_on_login_failed)
	
	# Setup UI
	_setup_background()
	_setup_ui()
	
	# Defer login check to ensure nodes are ready
	call_deferred("_check_login_status")

func _check_login_status() -> void:
	"""Check login status after nodes are ready"""
	# First, try to use saved tokens
	auth_manager.attempt_auto_login()
	
	# Wait a moment for auto-login to complete
	await get_tree().create_timer(0.5).timeout
	
	if auth_manager.is_logged_in():
		# Already logged in from saved token, go straight to main menu
		print("LoginUI: Already authenticated from saved session, going to main menu")
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")
	else:
		# Not logged in, show the login UI and create anonymous account
		print("LoginUI: No saved session, creating anonymous account")
		show()
		# Auto-create anonymous account for seamless experience
		auth_manager.login_anonymous()

func _setup_background():
	"""Apply UIStyleManager gradient background"""
	if has_node("/root/UIStyleManager"):
		var style_manager = get_node("/root/UIStyleManager")
		style_manager.apply_menu_gradient_background(self)

func _setup_ui() -> void:
	# Hide loading initially
	if loading_indicator:
		loading_indicator.hide()
		loading_indicator.indeterminate = true
	
	# Clear status
	_set_status("")
	
	# Setup input filters
	if email_input:
		email_input.placeholder_text = "your@email.com"
	if password_input:
		password_input.placeholder_text = "Enter password"
		password_input.secret = true
	if register_email_input:
		register_email_input.placeholder_text = "your@email.com"
	if register_password_input:
		register_password_input.placeholder_text = "Minimum 6 characters"
		register_password_input.secret = true
	if confirm_password_input:
		confirm_password_input.placeholder_text = "Re-enter password"
		confirm_password_input.secret = true
	if display_name_input:
		display_name_input.placeholder_text = "Your display name"
		display_name_input.max_length = 30
	
	# Setup close button text
	_update_close_button()

func _show_upgrade_prompt() -> void:
	"""Show UI for anonymous users to upgrade"""
	if not tab_container:
		push_error("TabContainer not ready")
		return
		
	is_guest_mode = true
	tab_container.current_tab = 1  # Show register tab
	_set_status("Playing as guest - Register to save progress!", COLOR_INFO)
	_update_close_button()

func _update_close_button() -> void:
	"""Update close button text based on state"""
	if close_button:
		if auth_manager.is_anonymous_account():
			close_button.text = "Continue as Guest"
		else:
			close_button.text = "Close"

# === LOGIN ===

func _on_login_pressed() -> void:
	if is_loading:
		return
	
	var email = email_input.text.strip_edges()
	var password = password_input.text
	
	# Validate
	if email.is_empty() or password.is_empty():
		_set_status("Email and password required", COLOR_ERROR)
		return
	
	# Perform login
	auth_manager.login_with_email(email, password)

# === REGISTER ===

func _on_register_pressed() -> void:
	if is_loading:
		return
	
	var display_name = display_name_input.text.strip_edges()
	var email = register_email_input.text.strip_edges()
	var password = register_password_input.text
	var confirm = confirm_password_input.text
	
	# Validate
	if email.is_empty() or password.is_empty():
		_set_status("Email and password required", COLOR_ERROR)
		return
	
	if password != confirm:
		_set_status("Passwords don't match", COLOR_ERROR)
		return
	
	if password.length() < 6:
		_set_status("Password must be at least 6 characters", COLOR_ERROR)
		return
	
	if display_name.is_empty():
		display_name = "Player%d" % (randi() % 9999)
	
	# Check if upgrading anonymous account
	if auth_manager.is_anonymous_account():
		auth_manager.upgrade_anonymous_account(email, password)
	else:
		auth_manager.register_with_email(email, password, display_name)

# === GUEST ===

func _on_guest_pressed() -> void:
	if is_loading:
		return
	
	# Create anonymous account
	_set_status("Creating guest account...", COLOR_INFO)
	auth_manager.login_anonymous()
	# The _on_login_completed callback will handle the scene transition

# === UI CALLBACKS ===

func _on_close_pressed() -> void:
	# Close button acts as "Skip" for anonymous users or "Close" for logged in users
	
	if auth_manager.is_logged_in():
		# Already logged in (anonymous or email), go to main menu
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")
	else:
		# Not logged in at all, create anonymous account first
		_set_status("Creating guest account...", COLOR_INFO)
		auth_manager.login_anonymous()
		# Wait for completion via _on_login_completed callback

func _on_tab_changed(tab: int) -> void:
	# Clear status when switching tabs
	_set_status("")
	
	# Clear inputs when switching
	_clear_all_inputs()

# === AUTH CALLBACKS ===

func _on_login_started() -> void:
	is_loading = true
	_set_status("Connecting...", COLOR_INFO)
	_set_ui_enabled(false)
	if loading_indicator:
		loading_indicator.show()

func _on_login_completed(user_data: Dictionary) -> void:
	is_loading = false
	_set_ui_enabled(true)
	if loading_indicator:
		loading_indicator.hide()
	
	# Wait for profile to load
	if not profile_manager.is_loaded:
		await profile_manager.profile_loaded
	
	var display_name = profile_manager.get_display_name()
	
	if auth_manager.is_anonymous_account():
		_set_status("Playing as guest!", COLOR_SUCCESS)
		# For anonymous, go straight to main menu
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")
	else:
		_set_status("Welcome back, %s!" % display_name, COLOR_SUCCESS)
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")
	
	# Emit signal for other systems
	SignalBus.auth_state_changed.emit({"logged_in": true})

func _on_login_failed(error: String) -> void:
	is_loading = false
	_set_ui_enabled(true)
	if loading_indicator:
		loading_indicator.hide()
	
	# Parse error for user-friendly message
	var user_message = _parse_error(error)
	_set_status(user_message, COLOR_ERROR)

# === HELPERS ===

func _set_status(text: String, color: Color = COLOR_INFO) -> void:
	if status_label:
		status_label.text = text
		status_label.modulate = color

func _set_ui_enabled(enabled: bool) -> void:
	# Disable all interactive elements during loading
	var buttons = [login_button, register_button, guest_button]
	for button in buttons:
		if button:
			button.disabled = not enabled
	
	var inputs = [email_input, password_input, display_name_input, 
				  register_email_input, register_password_input, confirm_password_input]
	for input in inputs:
		if input:
			input.editable = enabled

func _clear_all_inputs() -> void:
	var inputs = [email_input, password_input, display_name_input,
				  register_email_input, register_password_input, confirm_password_input]
	for input in inputs:
		if input:
			input.text = ""

func _parse_error(error: String) -> String:
	"""Convert technical errors to user-friendly messages"""
	if "Invalid login credentials" in error:
		return "Invalid email or password"
	elif "Email not confirmed" in error:
		return "Please confirm your email first"
	elif "User already registered" in error:
		return "This email is already registered"
	elif "Password should be at least" in error:
		return "Password must be at least 6 characters"
	elif "Invalid email" in error:
		return "Please enter a valid email"
	elif "HTTP 401" in error:
		return "Authentication failed - please try again"
	elif "HTTP 400" in error:
		return "Invalid request - check your inputs"
	elif "HTTP 429" in error:
		return "Too many attempts - please wait a moment"
	elif "HTTP 500" in error:
		return "Server error - please try again later"
	else:
		return error

# === KEYBOARD SHORTCUTS ===

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER:
			# Submit current tab
			match tab_container.current_tab:
				0: _on_login_pressed()
				1: _on_register_pressed()
				2: _on_guest_pressed()
			get_viewport().set_input_as_handled()

# === PUBLIC API ===

func show_login() -> void:
	"""Show the login UI"""
	show()
	tab_container.current_tab = 0
	_clear_all_inputs()
	_set_status("")
	
	# Focus email input
	if email_input:
		email_input.grab_focus()

func show_register() -> void:
	"""Show the register UI"""
	show()
	tab_container.current_tab = 1
	_clear_all_inputs()
	_set_status("")
	
	# Focus display name input
	if display_name_input:
		display_name_input.grab_focus()

func show_guest_info() -> void:
	"""Show guest info tab"""
	show()
	tab_container.current_tab = 2
	_set_status("Play as guest or create an account", COLOR_INFO)
