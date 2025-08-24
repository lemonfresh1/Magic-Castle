# GameLobbyDebugPanel.gd - Debug controls for testing the lobby
# Location: res://Pyramids/scripts/ui/debug/GameLobbyDebugPanel.gd
# Last Updated: Created for lobby testing [August 24, 2025]

extends PanelContainer

# Reference to the GameLobby
var game_lobby: Control = null

@onready var settings_vbox: VBoxContainer = $SettingsVBox

func _ready():
	# Find the GameLobby (our parent's parent)
	game_lobby = get_node("/root/GameLobby")
	if not game_lobby:
		push_error("GameLobby not found!")
		return
	
	_create_debug_controls()

func _create_debug_controls():
	"""Create all debug controls in the settings panel"""
	
	# === PERSPECTIVE SECTION ===
	var perspective_label = Label.new()
	perspective_label.text = "Perspective:"
	perspective_label.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(perspective_label)
	
	# Switch to Host button
	var host_btn = Button.new()
	host_btn.text = "Become Host"
	host_btn.pressed.connect(_on_become_host)
	settings_vbox.add_child(host_btn)
	
	# Switch to Player button
	var player_btn = Button.new()
	player_btn.text = "Become Player"
	player_btn.pressed.connect(_on_become_player)
	settings_vbox.add_child(player_btn)
	
	settings_vbox.add_child(HSeparator.new())
	
	# === PLAYER MANAGEMENT SECTION ===
	var players_label = Label.new()
	players_label.text = "Players:"
	players_label.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(players_label)
	
	# Add Random Player button
	var add_player_btn = Button.new()
	add_player_btn.text = "Add Random Player"
	add_player_btn.pressed.connect(_on_add_random_player)
	settings_vbox.add_child(add_player_btn)
	
	# Remove Random Player button
	var remove_player_btn = Button.new()
	remove_player_btn.text = "Remove Random Player"
	remove_player_btn.pressed.connect(_on_remove_random_player)
	settings_vbox.add_child(remove_player_btn)
	
	# Clear All Players button
	var clear_btn = Button.new()
	clear_btn.text = "Clear All Players"
	clear_btn.pressed.connect(_on_clear_all_players)
	settings_vbox.add_child(clear_btn)
	
	settings_vbox.add_child(HSeparator.new())
	
	# === READY STATES SECTION ===
	var ready_label = Label.new()
	ready_label.text = "Ready States:"
	ready_label.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(ready_label)
	
	# Make All Ready button
	var all_ready_btn = Button.new()
	all_ready_btn.text = "All Ready"
	all_ready_btn.pressed.connect(_on_all_ready)
	settings_vbox.add_child(all_ready_btn)
	
	# Make All Not Ready button
	var none_ready_btn = Button.new()
	none_ready_btn.text = "None Ready"
	none_ready_btn.pressed.connect(_on_none_ready)
	settings_vbox.add_child(none_ready_btn)
	
	settings_vbox.add_child(HSeparator.new())
	
	# === INFO SECTION ===
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.text = "Status: Host Mode"
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color.BLACK)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_vbox.add_child(info_label)

# === PERSPECTIVE SWITCHING ===

func _on_become_host():
	print("Switching to HOST perspective")
	game_lobby.is_host = true
	game_lobby.host_player_id = game_lobby.local_player_id
	game_lobby.set_as_host(true)
	
	# REFRESH ALL CARDS to update host indicator
	for slot in game_lobby.player_slots:
		if not slot.is_empty():
			slot.set_player(slot.player_data)  # Re-apply data to refresh
	
	_update_info("Status: Host Mode")

func _on_become_player():
	print("Switching to PLAYER perspective")
	game_lobby.is_host = false
	game_lobby.host_player_id = "player_2"  # Someone else is host
	game_lobby.set_as_host(false)
	
	# REFRESH ALL CARDS to update host indicator
	for slot in game_lobby.player_slots:
		if not slot.is_empty():
			slot.set_player(slot.player_data)  # Re-apply data to refresh
	
	_update_info("Status: Player Mode")

# === PLAYER MANAGEMENT ===

func _on_add_random_player():
	var random_names = ["Pharaoh", "Cleopatra", "Sphinx", "Osiris", "Ra", "Horus", "Bastet", "Thoth"]
	var player_data = {
		"id": "player_" + str(randi() % 1000),
		"name": random_names[randi() % random_names.size()],
		"level": randi_range(1, 60),
		"prestige": randi_range(0, 5),
		"stats": {
			"games": randi_range(10, 2000),
			"win_rate": randf_range(0.3, 0.9),
			"mmr": randi_range(800, 3500)
		},
		"display_items": ["first_win", "", ""],
		"frame_id": "",
		"is_ready": false,
		"is_host": false
	}
	
	if game_lobby.add_player(player_data):
		_update_info("Added: " + player_data.name)
	else:
		_update_info("Lobby Full!")

func _on_remove_random_player():
	# Get all non-local players
	var removable_players = []
	for slot in game_lobby.player_slots:
		if not slot.is_empty() and slot.get_player_id() != game_lobby.local_player_id:
			removable_players.append(slot.get_player_id())
	
	if removable_players.size() > 0:
		var player_to_remove = removable_players[randi() % removable_players.size()]
		game_lobby.remove_player(player_to_remove)
		_update_info("Removed player")
	else:
		_update_info("No players to remove")

func _on_clear_all_players():
	for slot in game_lobby.player_slots:
		if not slot.is_empty() and slot.get_player_id() != game_lobby.local_player_id:
			game_lobby.remove_player(slot.get_player_id())
	_update_info("Cleared all players")

# === READY STATES ===

func _on_all_ready():
	for slot in game_lobby.player_slots:
		if not slot.is_empty():
			game_lobby.set_player_ready(slot.get_player_id(), true)
	_update_info("All players ready")

func _on_none_ready():
	for slot in game_lobby.player_slots:
		if not slot.is_empty():
			game_lobby.set_player_ready(slot.get_player_id(), false)
	_update_info("All players not ready")

# === HELPERS ===

func _update_info(text: String):
	var info_label = settings_vbox.get_node_or_null("InfoLabel")
	if info_label:
		info_label.text = text
		
	# Also update player count
	var player_count = game_lobby.get_player_count()
	var ready_count = game_lobby.get_ready_count()
	info_label.text += "// Players: %d/8 | Ready: %d" % [player_count, ready_count]
