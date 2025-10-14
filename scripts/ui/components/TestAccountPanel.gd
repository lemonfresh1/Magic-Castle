# TestAccountPanel.gd - Complete test account management
extends PanelContainer

# Account configuration
const TEST_ACCOUNTS = [
	{"email": "stefanschmittnewsletter+alpha@gmail.com", "password": "test123456", "name": "AlphaWolf"},
	{"email": "stefan.schmitt.de+beta@gmail.com", "password": "test123456", "name": "BetaFox"},
	{"email": "stefanschmittnewsletter+gamma@gmail.com", "password": "test123456", "name": "GammaBear"},
	{"email": "stefanschmittnewsletter+delta@gmail.com", "password": "test123456", "name": "DeltaEagle"}
]

@onready var status_label: Label = $VBox/StatusLabel
@onready var current_user_label: Label = $VBox/CurrentUserLabel
@onready var buttons_container: VBoxContainer = $VBox/ButtonsContainer
@onready var create_all_button: Button = $VBox/CreateAllButton

var account_buttons: Array[Button] = []

func _ready():
	custom_minimum_size = Vector2(300, 400)
	
	# Setup UI
	_setup_ui()
	
	# Check current login status
	_update_current_user()

func _setup_ui():
	# Create the UI structure if nodes don't exist
	if not has_node("VBox"):
		var vbox = VBoxContainer.new()
		vbox.name = "VBox"
		add_child(vbox)
		
		# Title
		var title = Label.new()
		title.text = "Test Account Manager"
		title.add_theme_font_size_override("font_size", 18)
		vbox.add_child(title)
		
		# Status
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.text = "Ready"
		vbox.add_child(status_label)
		
		# Current user
		current_user_label = Label.new()
		current_user_label.name = "CurrentUserLabel"
		current_user_label.text = "Not logged in"
		current_user_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(current_user_label)
		
		vbox.add_child(HSeparator.new())
		
		# Create all button
		create_all_button = Button.new()
		create_all_button.name = "CreateAllButton"
		create_all_button.text = "Create All Test Accounts"
		create_all_button.pressed.connect(_create_all_accounts)
		vbox.add_child(create_all_button)
		
		vbox.add_child(HSeparator.new())
		
		# Account buttons container
		buttons_container = VBoxContainer.new()
		buttons_container.name = "ButtonsContainer"
		vbox.add_child(buttons_container)
	
	# Create login buttons for each account
	for i in range(TEST_ACCOUNTS.size()):
		var account = TEST_ACCOUNTS[i]
		
		var hbox = HBoxContainer.new()
		buttons_container.add_child(hbox)
		
		# Login button
		var login_btn = Button.new()
		login_btn.text = "Login: " + account.name
		login_btn.custom_minimum_size.x = 200
		login_btn.pressed.connect(func(): _login_account(i))
		hbox.add_child(login_btn)
		account_buttons.append(login_btn)
		
		# Status indicator
		var status = Label.new()
		status.text = "●"
		status.add_theme_color_override("font_color", Color.GRAY)
		status.set_meta("account_index", i)
		hbox.add_child(status)
	
	# Logout button
	var logout_btn = Button.new()
	logout_btn.text = "Logout Current User"
	logout_btn.pressed.connect(_logout)
	buttons_container.add_child(logout_btn)

func _create_all_accounts():
	"""Create all test accounts in Supabase"""
	status_label.text = "Creating accounts..."
	create_all_button.disabled = true
	
	var supabase = get_node("/root/SupabaseManager")
	
	for i in range(TEST_ACCOUNTS.size()):
		var account = TEST_ACCOUNTS[i]
		status_label.text = "Creating: " + account.name
		
		# Create the account
		var body = {
			"email": account.email,
			"password": account.password
		}
		
		supabase.current_request_type = "auth_signup"
		var url = supabase.SUPABASE_URL + "/auth/v1/signup"
		var headers = PackedStringArray()
		headers.append("apikey: " + supabase.SUPABASE_KEY)
		headers.append("Content-Type: application/json")
		
		supabase.auth_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
		
		# Wait for completion
		await get_tree().create_timer(1.5).timeout
		
		# Now create the profile with the custom name
		if supabase.is_authenticated:
			var profile_data = {
				"id": supabase.current_user.get("id", ""),
				"display_name": account.name,
				"username": account.name.to_lower(),
				"level": 1,
				"mmr": 1000,
				"stats": {},
				"equipped": {}
			}
			
			await _save_profile(profile_data)
			
			# Logout before creating next
			supabase.sign_out()
			await get_tree().create_timer(0.5).timeout
	
	status_label.text = "✓ All accounts created!"
	status_label.add_theme_color_override("font_color", Color.GREEN)
	create_all_button.text = "Accounts Ready!"
	create_all_button.disabled = false

func _login_account(index: int):
	"""Quick login to specific test account"""
	var account = TEST_ACCOUNTS[index]
	status_label.text = "Logging in as " + account.name + "..."
	
	# Disable all buttons during login
	for btn in account_buttons:
		btn.disabled = true
	
	var supabase = get_node("/root/SupabaseManager")
	
	# Logout first if needed
	if supabase.is_authenticated:
		supabase.sign_out()
		await get_tree().create_timer(0.3).timeout
	
	# Login with email/password
	supabase.sign_in_with_email(account.email, account.password)
	
	# Wait for auth
	await supabase.authenticated
	
	# Wait for profile load
	var profile = get_node("/root/ProfileManager")
	if not profile.is_loaded:
		await profile.profile_loaded
	
	# Update UI
	_update_current_user()
	status_label.text = "✓ Logged in!"
	
	# Re-enable buttons
	for btn in account_buttons:
		btn.disabled = false
	
	# Update button colors
	for i in range(account_buttons.size()):
		if i == index:
			account_buttons[i].modulate = Color.GREEN
		else:
			account_buttons[i].modulate = Color.WHITE

func _logout():
	"""Logout current user"""
	status_label.text = "Logging out..."
	
	var supabase = get_node("/root/SupabaseManager")
	supabase.sign_out()
	
	var profile = get_node("/root/ProfileManager")
	profile.clear_cache()
	
	_update_current_user()
	status_label.text = "Logged out"
	
	# Reset button colors
	for btn in account_buttons:
		btn.modulate = Color.WHITE

func _update_current_user():
	"""Update current user display"""
	var profile = get_node("/root/ProfileManager")
	if profile.is_loaded and profile.player_name != "":
		current_user_label.text = "Current: " + profile.player_name
		current_user_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		current_user_label.text = "Not logged in"
		current_user_label.add_theme_color_override("font_color", Color.YELLOW)

func _save_profile(data: Dictionary):
	"""Helper to save profile data"""
	var supabase = get_node("/root/SupabaseManager")
	supabase.current_request_type = "upsert_profile"
	
	var url = supabase.SUPABASE_URL + "/rest/v1/pyramids_profiles"
	var headers = supabase._get_db_headers()
	headers.append("Content-Type: application/json")
	headers.append("Prefer: resolution=merge-duplicates")
	
	var body = JSON.stringify(data)
	supabase.db_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	await get_tree().create_timer(0.5).timeout
