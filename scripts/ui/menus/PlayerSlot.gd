# PlayerSlot.gd - Container for a player in the lobby
# Location: res://Pyramids/scripts/ui/multiplayer/PlayerSlot.gd
# Last Updated: Initial creation with dynamic typing [August 24, 2025]
#
# Dependencies:
#   - MiniProfileCard: Visual display of player info
#   - EquipmentManager: For equipped mini profile themes
#
# Flow: GameLobby → PlayerSlot → MiniProfileCard
#
# Functionality:
#   • Manages single player slot (empty or occupied)
#   • Loads and configures MiniProfileCard
#   • Handles player-specific actions (kick, ready, invite)

extends PanelContainer

class_name PlayerSlot

# === SIGNALS ===
signal slot_clicked(slot_index: int)
signal player_kicked(player_id: String)
signal invite_sent(slot_index: int)
signal player_ready_changed(player_id: String, ready: bool)

# === EXPORTS ===
@export var slot_index: int = 0

# === PROPERTIES ===
var mini_profile_card = null  # MiniProfileCard instance (untyped)
var player_data: Dictionary = {}
var is_occupied: bool = false
var is_local_player: bool = false
var is_host_slot: bool = false
var show_kick_button: bool = false

# === LIFECYCLE ===

func _ready():
	_setup_slot()
	_create_mini_profile_card()
	set_empty()  # Start as empty slot

# === SETUP ===

func _setup_slot():
	"""Configure the slot container"""
	# Remove default panel style (transparent container)
	var empty_style = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)
	
	# Set size
	custom_minimum_size = Vector2(200, 200)
	size = Vector2(200, 200)

func _create_mini_profile_card():
	"""Create and setup the MiniProfileCard"""
	var card_scene_path = "res://Pyramids/scenes/ui/components/MiniProfileCard.tscn"
	
	if ResourceLoader.exists(card_scene_path):
		var scene = load(card_scene_path)
		mini_profile_card = scene.instantiate()
	else:
		# Try to create from script if scene doesn't exist
		var card_script_path = "res://Pyramids/scripts/ui/components/MiniProfileCard.gd"
		if ResourceLoader.exists(card_script_path):
			var script = load(card_script_path)
			mini_profile_card = PanelContainer.new()
			mini_profile_card.set_script(script)
		else:
			push_error("MiniProfileCard not found (neither scene nor script)")
			# Create fallback panel
			mini_profile_card = PanelContainer.new()
			mini_profile_card.custom_minimum_size = Vector2(200, 200)
			var label = Label.new()
			label.text = "Card Missing"
			label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			mini_profile_card.add_child(label)
			add_child(mini_profile_card)
			return

	# Connect signals
	if mini_profile_card.has_signal("player_clicked"):
		mini_profile_card.player_clicked.connect(_on_player_clicked)
	if mini_profile_card.has_signal("kick_requested"):
		mini_profile_card.kick_requested.connect(_on_kick_requested)
	if mini_profile_card.has_signal("invite_clicked"):
		mini_profile_card.invite_clicked.connect(_on_invite_clicked)
	add_child(mini_profile_card)

# === PUBLIC API ===

func set_player(data: Dictionary):
	"""Set player data for occupied slot - only update if changed"""
	
	# ✅ Check if data actually changed (excluding ready state)
	if is_occupied and player_data.size() > 0 and not _player_data_changed(data):
		# Data unchanged - only update ready state if needed
		var new_ready = data.get("is_ready", false)
		var current_ready = player_data.get("is_ready", false)
		
		if new_ready != current_ready:
			player_data["is_ready"] = new_ready
			if mini_profile_card and mini_profile_card.has_method("set_ready"):
				mini_profile_card.set_ready(new_ready)
		
		return  # ✅ Skip full update!
	
	# Data changed - do full update
	player_data = data.duplicate()
	is_occupied = true
	
	# Add slot-specific data
	player_data["is_host"] = is_host_slot
	
	# Apply equipped mini profile theme if this is the local player
	if mini_profile_card and mini_profile_card.has_method("apply_mini_profile_theme"):
		var equipped = data.get("equipped", {})
		var theme_id = equipped.get("mini_profile_card", "")
		
		if theme_id != "":
			print("[PlayerSlot] Applying theme '%s' for player %s" % [theme_id, data.get("name", "Unknown")])
			mini_profile_card.apply_mini_profile_theme(theme_id)
		else:
			print("[PlayerSlot] No theme for player %s" % data.get("name", "Unknown"))
	
	# Set data on the card
	if mini_profile_card and mini_profile_card.has_method("set_player_data"):
		mini_profile_card.set_player_data(player_data)

func _player_data_changed(new_data: Dictionary) -> bool:
	"""Check if player data changed (excluding ready state)"""
	if player_data.is_empty():
		return true  # First time, definitely changed
	
	# Compare fields that affect visuals (excluding is_ready)
	var fields_to_check = ["id", "name", "level", "prestige"]
	
	for field in fields_to_check:
		var old_value = player_data.get(field, null)
		var new_value = new_data.get(field, null)
		
		if old_value != new_value:
			return true
	
	# Check equipped items (showcase can change)
	var old_equipped = player_data.get("equipped", {})
	var new_equipped = new_data.get("equipped", {})
	
	var old_showcase = old_equipped.get("mini_profile_card_showcased_items", [])
	var new_showcase = new_equipped.get("mini_profile_card_showcased_items", [])
	
	if old_showcase != new_showcase:
		return true
	
	# Check stats (though these shouldn't change in lobby)
	var old_stats = player_data.get("stats", {})
	var new_stats = new_data.get("stats", {})
	
	if old_stats != new_stats:
		return true
	
	return false  # No changes detected

func set_empty():
	"""Set slot as empty/invite"""
	player_data = {}
	is_occupied = false
	
	var empty_data = {
		"is_empty": true,
		"id": "",
		"name": "Invite Player",
		"level": 0
	}
	
	if mini_profile_card and mini_profile_card.has_method("set_player_data"):
		mini_profile_card.set_player_data(empty_data)

func set_ready(ready: bool):
	"""Set player ready status"""
	if is_occupied:
		player_data["is_ready"] = ready
		if mini_profile_card and mini_profile_card.has_method("set_ready"):
			mini_profile_card.set_ready(ready)
		player_ready_changed.emit(get_player_id(), ready)

func set_as_host():
	"""Mark this slot as the host"""
	is_host_slot = true
	if player_data.size() > 0:
		player_data["is_host"] = true
		if mini_profile_card and mini_profile_card.has_method("set_player_data"):
			mini_profile_card.set_player_data(player_data)

func set_host_viewing(is_host: bool):
	"""Set whether the host is viewing (shows kick buttons)"""
	print("[PlayerSlot %d] >>> set_host_viewing(%s)" % [slot_index, is_host])
	print("[PlayerSlot %d]   is_host_slot: %s" % [slot_index, is_host_slot])
	print("[PlayerSlot %d]   Calculating: is_host=%s AND not is_host_slot=%s" % [slot_index, is_host, not is_host_slot])
	
	show_kick_button = is_host and not is_host_slot
	
	print("[PlayerSlot %d]   Result: show_kick_button = %s" % [slot_index, show_kick_button])
	
	if mini_profile_card and mini_profile_card.has_method("set_host_viewing"):
		print("[PlayerSlot %d]   Calling mini_profile_card.set_host_viewing(%s)" % [slot_index, is_host])
		mini_profile_card.set_host_viewing(is_host)
	else:
		if not mini_profile_card:
			print("[PlayerSlot %d]   ERROR: mini_profile_card is null!" % slot_index)
		else:
			print("[PlayerSlot %d]   ERROR: mini_profile_card has no set_host_viewing() method!" % slot_index)
	
	print("[PlayerSlot %d] <<< set_host_viewing() complete" % slot_index)

func set_as_local_player(is_local: bool = true):
	"""Mark this as the local player's slot"""
	is_local_player = is_local
	
	# Re-apply to trigger theme
	if is_local and is_occupied:
		set_player(player_data)

func update_player_stats(stats: Dictionary):
	"""Update just the stats portion of player data"""
	if is_occupied:
		player_data["stats"] = stats
		if mini_profile_card and mini_profile_card.has_method("set_player_data"):
			mini_profile_card.set_player_data(player_data)

func update_display_items(items: Array):
	"""Update the showcase items"""
	if is_occupied:
		player_data["display_items"] = items
		if mini_profile_card and mini_profile_card.has_method("set_player_data"):
			mini_profile_card.set_player_data(player_data)

# === VISUAL STATES ===

func highlight():
	"""Highlight this slot"""
	if mini_profile_card and mini_profile_card.has_method("highlight"):
		mini_profile_card.highlight()

func unhighlight():
	"""Remove highlight"""
	if mini_profile_card and mini_profile_card.has_method("unhighlight"):
		mini_profile_card.unhighlight()

func set_enabled(enabled: bool):
	"""Enable/disable the slot"""
	if mini_profile_card:
		if mini_profile_card.has_property("clickable"):
			mini_profile_card.clickable = enabled
		mini_profile_card.modulate.a = 1.0 if enabled else 0.5

# === GETTERS ===

func get_player_id() -> String:
	"""Get the player ID in this slot"""
	return player_data.get("id", "")

func get_player_name() -> String:
	"""Get the player name in this slot"""
	return player_data.get("name", "")

func is_ready() -> bool:
	"""Check if player is ready"""
	return player_data.get("is_ready", false)

func is_empty() -> bool:
	"""Check if slot is empty"""
	return not is_occupied

# === SIGNAL HANDLERS ===

func _on_player_clicked(player_id: String):
	"""Handle player card click"""
	if is_occupied:
		slot_clicked.emit(slot_index)

func _on_kick_requested(player_id: String):
	"""Handle kick button press"""
	if is_occupied:
		player_kicked.emit(player_data.get("id", ""))

func _on_invite_clicked(slot_idx: int):
	"""Handle invite click on empty slot"""
	if not is_occupied:
		invite_sent.emit(slot_index)

# === DEBUG ===

func debug_set_mock_player():
	"""Set a mock player for testing"""
	var mock_data = {
		"id": "test_player_%d" % slot_index,
		"name": "TestPlayer%d" % slot_index,
		"level": randi_range(1, 60),
		"prestige": randi_range(0, 5),
		"stats": {
			"games": randi_range(10, 1000),
			"win_rate": randf_range(0.3, 0.9),
			"mmr": randi_range(800, 3000)
		},
		"display_items": ["first_win", "", ""],
		"frame_id": "",
		"is_ready": false,
		"is_host": slot_index == 0
	}
	set_player(mock_data)
