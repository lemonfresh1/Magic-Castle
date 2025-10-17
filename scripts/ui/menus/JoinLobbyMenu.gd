# JoinLobbyMenu.gd - Lobby browser for joining existing games
# Location: res://Pyramids/scenes/ui/menus/JoinLobbyMenu.gd
# Last Updated: Initial creation for multiplayer lobby browsing

extends Control

# Scene references
@onready var lobby_grid: GridContainer = $StyledPanel/MarginContainer/VBoxContainer/GridContainer
@onready var title_label: Label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var leave_button: Button = $StyledPanel/MarginContainer/VBoxContainer/LeaveButton
@onready var backdrop: ColorRect = $ColorRect

# Polling timer
var refresh_timer: Timer
var refresh_interval: float = 5.0  # Refresh lobby list every 5 seconds
var is_active: bool = false

# Lobby data cache
var current_lobbies: Array = []

func _ready():
	# Connect backdrop click
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_input)
	
	# Apply theme to title
	if ThemeConstants:
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_title)
	
	# Set title text
	title_label.text = "Lobby List"
	
	# Set grid columns
	lobby_grid.columns = 4
	
	# Connect leave button
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Create refresh timer
	refresh_timer = Timer.new()
	refresh_timer.name = "RefreshTimer"
	refresh_timer.wait_time = refresh_interval
	refresh_timer.timeout.connect(_refresh_lobby_list)
	add_child(refresh_timer)
	
	# Connect to SupabaseManager for responses
	if SupabaseManager:
		SupabaseManager.request_completed.connect(_on_lobbies_received)
	
	# Add headers
	_create_headers()
	
	# Start refreshing
	_start_browsing()

func _create_headers():
	"""Create header labels for the grid"""
	var headers = ["ID", "Game Mode", "Players", "Join"]
	
	for header_text in headers:
		var header = Label.new()
		header.text = header_text
		
		# Apply theme styling
		if ThemeConstants:
			header.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
			header.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
		
		lobby_grid.add_child(header)

func _start_browsing():
	"""Start browsing available lobbies"""
	is_active = true
	refresh_timer.start()
	_refresh_lobby_list()

func _stop_browsing():
	"""Stop refreshing lobby list"""
	is_active = false
	refresh_timer.stop()

func _refresh_lobby_list():
	"""Query for available lobbies - only active ones"""
	if not SupabaseManager or not SupabaseManager.is_authenticated:
		print("[JoinLobbyMenu] Not authenticated, cannot query lobbies")
		return
	
	# ✅ REMOVED: Cleanup now happens in MultiplayerScreen._ready()
	# No longer needed here since it runs when entering multiplayer mode
	
	# Query lobbies immediately
	SupabaseManager.current_request_type = "get_open_lobbies"
	var url = SupabaseManager.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
	url += "?status=eq.waiting"  # Only waiting lobbies (not completed)
	url += "&player_count=lt.8"  # Not full
	url += "&order=created_at.desc"  # Newest first
	
	var headers = SupabaseManager._get_db_headers()
	SupabaseManager.db_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_lobbies_received(data):
	"""Handle lobby list response"""
	if SupabaseManager.current_request_type != "get_open_lobbies":
		return
	
	# Clear existing lobby rows (keep headers)
	var children_to_remove = []
	for i in range(4, lobby_grid.get_child_count()):
		children_to_remove.append(lobby_grid.get_child(i))
	
	for child in children_to_remove:
		child.queue_free()
	
	# Store lobby data
	current_lobbies = data if data is Array else []
	
	# Add lobby rows
	for lobby in current_lobbies:
		_add_lobby_row(lobby)
	
	# If no lobbies, show message
	if current_lobbies.is_empty():
		_add_no_lobbies_message()

func _add_lobby_row(lobby_data: Dictionary):
	"""Add a row for a lobby"""
	# ID label (shortened)
	var id_label = Label.new()
	var full_id = lobby_data.get("id", "unknown")
	id_label.text = full_id.substr(0, 8) + "..."
	id_label.tooltip_text = full_id  # Show full ID on hover
	
	# Mode label
	var mode_label = Label.new()
	mode_label.text = lobby_data.get("mode", "classic").capitalize()
	
	# Players label
	var players_label = Label.new()
	var player_count = lobby_data.get("player_count", 0)
	var max_players = 8
	players_label.text = "%d/%d" % [player_count, max_players]
	
	# Apply theme to labels
	for label in [id_label, mode_label, players_label]:
		if ThemeConstants:
			label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
			label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
	
	# Join button - create StyledButton directly
	var join_button = StyledButton.new()
	join_button.text = "Join"
	join_button.button_style = "primary"
	join_button.button_size = "medium"
	join_button.pressed.connect(_on_join_pressed.bind(full_id))
	
	# Add all to grid
	lobby_grid.add_child(id_label)
	lobby_grid.add_child(mode_label)
	lobby_grid.add_child(players_label)
	lobby_grid.add_child(join_button)

func _add_no_lobbies_message():
	"""Show message when no lobbies available"""
	var message = Label.new()
	message.text = "No open lobbies found"
	
	if ThemeConstants:
		message.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
		message.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
	
	lobby_grid.add_child(message)
	
	# Add empty cells to maintain grid
	for i in range(3):
		var empty = Control.new()
		lobby_grid.add_child(empty)

func _on_join_pressed(lobby_id: String):
	"""Join a specific lobby"""
	print("[JoinLobbyMenu] Joining lobby: %s" % lobby_id)
	
	# Stop refreshing
	_stop_browsing()
	
	# Join via NetworkManager
	if NetworkManager:
		# Check which function exists and use it
		if NetworkManager.has_method("join_lobby_by_id"):
			NetworkManager.join_lobby_by_id(lobby_id)  # New function from my changes
		elif NetworkManager.has_method("join_lobby"):
			NetworkManager.join_lobby(lobby_id)  # Existing function
		
		# Connect to response
		if not NetworkManager.lobby_joined.is_connected(_on_lobby_joined):
			NetworkManager.lobby_joined.connect(_on_lobby_joined, CONNECT_ONE_SHOT)
	
	# Close this menu
	hide()

func _on_lobby_joined(lobby_data: Dictionary):
	"""Handle successful lobby join"""
	print("[JoinLobbyMenu] Successfully joined lobby")
	
	# Navigate to GameLobby scene
	if has_node("/root/SceneTransitionManager"):
		get_node("/root/SceneTransitionManager").go_to_scene("res://Pyramids/scenes/ui/menus/GameLobby.tscn")
	else:
		get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/GameLobby.tscn")

func _on_leave_pressed():
	"""Leave the lobby browser"""
	_stop_browsing()
	hide()
	queue_free()

func _on_backdrop_input(event: InputEvent):
	"""Handle backdrop clicks to close menu"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Close the menu just like the leave button
		_on_leave_pressed()

func _exit_tree():
	"""Cleanup on exit"""
	_stop_browsing()# JoinLobbyMenu.gd - Lobby browser for joining existing games
