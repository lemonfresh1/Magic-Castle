# LoginButton.gd - Attach to any Button node for quick test login
extends Button

@export_enum("Player1", "Player2", "Player3", "Player4") var test_account: String = "Player1"

func _ready():
	# Set button text based on selected account
	text = "Login as " + test_account
	
	# Connect button press
	pressed.connect(_on_login_pressed)
	
	# Optional: Style the button
	custom_minimum_size = Vector2(200, 50)

func _on_login_pressed():
	print("[LoginButton] Logging in as %s..." % test_account)
	
	# Get the test account number
	var account_number = 1
	match test_account:
		"Player1": account_number = 1
		"Player2": account_number = 2
		"Player3": account_number = 3
		"Player4": account_number = 4
	
	# Disable button during login
	disabled = true
	text = "Logging in..."
	
	# Quick login via SupabaseManager
	var supabase = get_node("/root/SupabaseManager")
	supabase.quick_test_login(account_number)
	
	# Wait for profile to load
	var profile_manager = get_node("/root/ProfileManager")
	await profile_manager.profile_loaded
	
	print("[LoginButton] Successfully logged in as: %s" % profile_manager.player_name)
	
	# Update button to show logged in status
	disabled = false
	text = "Logged in as " + test_account
	modulate = Color(0.7, 1.0, 0.7)  # Slight green tint to show success
