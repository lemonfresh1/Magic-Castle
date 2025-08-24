# GameLobby.gd - Manages the multiplayer game lobby
# Location: res://Pyramids/scripts/ui/menus/GameLobby.gd
# Last Updated: Refactored for existing scene structure [August 24, 2025]
#
# Dependencies:
#   - PlayerSlot: Individual player slot management
#   - MiniProfileCard: Visual player card display
#   - SignalBus: Centralized signal management
#   - UIStyleManager: Consistent UI styling
#
# Flow: MultiplayerScreen → GameLobby → PlayerSlots → MiniProfileCards
#
# Functionality:
#   • Manages 8 player slots in 4x2 grid
#   • Handles ready states and game start conditions
#   • Host controls (kick players, start game)
#   • Emoji reactions (placeholder)
#   • Leave/invite functionality
#
# Signals In:
#   - player_data_received from NetworkManager (TODO)
#   - host_changed from NetworkManager (TODO)
# Signals Out:
#   - lobby_player_joined via SignalBus
#   - lobby_start_requested via SignalBus

extends Control

# === CONSTANTS ===
const MAX_PLAYERS = 8  # 4x2 grid
const MIN_PLAYERS = 2
const PLAYER_SLOT_SCENE = "res://Pyramids/scenes/ui/components/PlayerSlot.tscn"

# === EXPORTS ===
@export var lobby_name: String = "Desert Duel"
@export var require_all_ready: bool = true
@export var enable_kick_confirmation: bool = true

# === NODE REFERENCES ===
@onready var background: ColorRect = $Background
@onready var main_container: MarginContainer = $MainContainer
@onready var content_v_box: VBoxContainer = $MainContainer/ContentVBox
@onready var header_panel: PanelContainer = $MainContainer/ContentVBox/HeaderPanel
@onready var lobby_title: Label = $MainContainer/ContentVBox/HeaderPanel/LobbyTitle
@onready var players_and_settings: HBoxContainer = $MainContainer/ContentVBox/PlayersAndSettings
@onready var players_grid: GridContainer = $MainContainer/ContentVBox/PlayersAndSettings/PlayersGrid
@onready var settings_panel: PanelContainer = $MainContainer/ContentVBox/PlayersAndSettings/SettingsPanel
@onready var settings_v_box: VBoxContainer = $MainContainer/ContentVBox/PlayersAndSettings/SettingsPanel/SettingsVBox
@onready var bottom_buttons: HBoxContainer = $MainContainer/ContentVBox/BottomButtons
@onready var ready_button: Button = $MainContainer/ContentVBox/BottomButtons/ReadyButton
@onready var start_button: Button = $MainContainer/ContentVBox/BottomButtons/StartButton
@onready var emoji_button_1: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton1
@onready var emoji_button_2: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton2
@onready var emoji_button_3: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton3
@onready var emoji_button_4: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton4
@onready var leave_button: Button = $MainContainer/ContentVBox/BottomButtons/LeaveButton

# === PROPERTIES ===
var player_slots: Array = []
var local_player_id: String = ""
var host_player_id: String = ""
var is_host: bool = false
var is_ready: bool = false
var game_started: bool = false

# Emoji system
var emoji_buttons: Array = []
var emoji_on_cooldown: bool = false  # Global cooldown state
var emoji_cooldown_overlays: Array = []  # Track all overlays
var emoji_cooldown_tweens: Array = []
var emoji_progress_bars: Array = []

func _ready():
	_setup_lobby()
	_create_player_slots()
	_connect_signals()
	_apply_ui_styling()
	_setup_emoji_buttons()  # NEW
	_update_controls_visibility()
	
	# Test mode if running directly
	if get_tree().current_scene == self:
		_test_lobby()

# === SETUP ===

func _setup_lobby():
	"""Initialize lobby settings and title"""
	if lobby_title:
		lobby_title.text = lobby_name
	
	# Hide settings panel for now (Phase 3)
	if settings_panel:
		settings_panel.visible = true
		# TODO: Implement settings panel in Phase 3

func _create_player_slots():
	"""Create 8 PlayerSlot instances in the grid"""
	player_slots.clear()
	
	# Clear any existing children (pink placeholders)
	for child in players_grid.get_children():
		child.queue_free()
	
	# Load PlayerSlot script if it exists
	var PlayerSlotScript = null
	if ResourceLoader.exists("res://Pyramids/scripts/ui/multiplayer/PlayerSlot.gd"):
		PlayerSlotScript = load("res://Pyramids/scripts/ui/multiplayer/PlayerSlot.gd")
	
	# Create 8 slots
	for i in range(MAX_PLAYERS):
		var slot
		
		# Try to load the scene
		if ResourceLoader.exists(PLAYER_SLOT_SCENE):
			var scene = load(PLAYER_SLOT_SCENE)
			slot = scene.instantiate()
		elif PlayerSlotScript:
			# Create from script if scene doesn't exist
			slot = PanelContainer.new()
			slot.set_script(PlayerSlotScript)
		else:
			# Fallback: create a basic panel
			slot = PanelContainer.new()
			print("Warning: PlayerSlot script not found, using fallback")
		
		if slot.has_method("_ready"):
			slot.slot_index = i
		
		slot.name = "PlayerSlot%d" % i
		
		# Connect slot signals if they exist
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_slot_clicked)
		if slot.has_signal("player_kicked"):
			slot.player_kicked.connect(_on_player_kicked)
		if slot.has_signal("invite_sent"):
			slot.invite_sent.connect(_on_invite_sent)
		if slot.has_signal("player_ready_changed"):
			slot.player_ready_changed.connect(_on_player_ready_changed)
		
		players_grid.add_child(slot)
		player_slots.append(slot)

func _connect_signals():
	"""Connect all UI signals"""
	if ready_button:
		ready_button.pressed.connect(_on_ready_pressed)
	
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	
	if leave_button:
		leave_button.pressed.connect(_on_leave_pressed)
	
	# Emoji buttons (placeholder functionality)
	if emoji_button_1:
		emoji_button_1.pressed.connect(func(): _on_emoji_pressed(1))
	if emoji_button_2:
		emoji_button_2.pressed.connect(func(): _on_emoji_pressed(2))
	if emoji_button_3:
		emoji_button_3.pressed.connect(func(): _on_emoji_pressed(3))
	if emoji_button_4:
		emoji_button_4.pressed.connect(func(): _on_emoji_pressed(4))

func _apply_ui_styling():
	"""Apply UIStyleManager styling to UI elements"""
	if not UIStyleManager:
		return
	
	# Apply gradient background
	if background:
		UIStyleManager.apply_menu_gradient_background(self)
	
	# Style the header panel WITHOUT SHADOW
	if header_panel:
		UIStyleManager.apply_panel_style_no_shadow(header_panel, "lobby_header")
	
	# Style the lobby title label
	if lobby_title:
		UIStyleManager.apply_label_style(lobby_title, "title")
	
	# Style the settings panel WITHOUT SHADOW
	if settings_panel:
		UIStyleManager.apply_panel_style_no_shadow(settings_panel, "settings_panel")
	
	# Style buttons with proper types
	if ready_button:
		# Apply warning style initially (not ready state)
		UIStyleManager.apply_button_style(ready_button, "warning", "medium")
	
	if start_button:
		# Green success button with medium size
		UIStyleManager.apply_button_style(start_button, "success", "medium")
		# Override font size to be slightly bigger
		start_button.add_theme_font_size_override("font_size", 20)
	
	if leave_button:
		# Red danger button
		UIStyleManager.apply_button_style(leave_button, "danger", "medium")

# === PUBLIC API ===

func set_as_host(host: bool = true):
	"""Set this player as the host"""
	is_host = host
	_update_controls_visibility()
	
	# Update all slots to show/hide kick buttons
	for slot in player_slots:
		if slot.has_method("set_host_viewing"):
			slot.set_host_viewing(is_host)

func set_local_player(player_id: String):
	"""Set the local player ID"""
	local_player_id = player_id
	
	# Find and mark local player slot
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.has_method("set_as_local_player"):
				slot.set_as_local_player(true)
			break

func add_player(player_data: Dictionary) -> bool:
	"""Add a player to the lobby"""
	# Find first empty slot
	for slot in player_slots:
		if slot.has_method("is_empty") and slot.is_empty():
			# Check if this is the local player
			var is_local = player_data.get("id", "") == local_player_id
			if is_local and slot.has_method("set_as_local_player"):
				slot.set_as_local_player(true)
			
			# Check if this is the host
			if player_data.get("id", "") == host_player_id:
				if slot.has_method("set_as_host"):
					slot.set_as_host()
			
			if slot.has_method("set_player"):
				slot.set_player(player_data)
			
			# Emit signal
			if SignalBus.has_signal("lobby_player_joined"):
				SignalBus.lobby_player_joined.emit(
					player_data.get("id", ""),
					player_data
				)
			
			_update_start_button_state()
			return true
	
	return false  # Lobby full

func remove_player(player_id: String) -> bool:
	"""Remove a player from the lobby"""
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.has_method("set_empty"):
				slot.set_empty()
			if SignalBus.has_signal("lobby_player_left"):
				SignalBus.lobby_player_left.emit(player_id)
			_update_start_button_state()
			return true
	
	return false

func update_player(player_id: String, data: Dictionary):
	"""Update player data"""
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.has_method("set_player"):
				slot.set_player(data)
			break

func set_player_ready(player_id: String, ready: bool):
	"""Set a player's ready status"""
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.has_method("set_ready"):
				slot.set_ready(ready)
			if SignalBus.has_signal("lobby_player_ready_changed"):
				SignalBus.lobby_player_ready_changed.emit(player_id, ready)
			_update_start_button_state()
			_check_all_ready()
			break

func _setup_emoji_buttons():
	"""Load equipped emojis into buttons"""
	emoji_buttons = [emoji_button_1, emoji_button_2, emoji_button_3, emoji_button_4]
	
	if not EquipmentManager:
		return
		
	var equipped_emojis = EquipmentManager.get_equipped_emojis()
	
	for i in range(4):
		var button = emoji_buttons[i]
		if i < equipped_emojis.size():
			var emoji_id = equipped_emojis[i]
			if ItemManager:
				var item = ItemManager.get_item(emoji_id)
				if item and item.get("texture_path"):
					_configure_emoji_button(button, item, i)
				else:
					button.visible = false
		else:
			button.visible = false

# === PRIVATE HELPERS ===

func _configure_emoji_button(button: Button, emoji_item: UnifiedItemData, index: int):
	"""Configure a single emoji button"""
	button.visible = true
	button.text = ""
	button.tooltip_text = emoji_item.display_name
	
	if UIStyleManager:
		UIStyleManager.apply_button_style(button, "transparent", "medium")
	
	var texture_path = emoji_item.texture_path if emoji_item else ""
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		button.icon = texture
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.custom_minimum_size = Vector2(48, 48)
	
	button.set_meta("emoji_id", emoji_item.id)
	button.set_meta("button_index", index)

func _start_global_emoji_cooldown():
	"""Start cooldown animation on ALL emoji buttons using color modulation"""
	if emoji_on_cooldown:
		return
	
	emoji_on_cooldown = true
	emoji_cooldown_tweens.clear()
	
	for i in range(emoji_buttons.size()):
		var button = emoji_buttons[i]
		if not button.visible:
			continue
		
		button.disabled = true
		
		# Start with grey modulation
		button.modulate = Color(0.3, 0.3, 0.3, 1.0)
		
		# Create tween to animate back to normal color
		var tween = create_tween()
		tween.tween_property(button, "modulate", Color.WHITE, 3.0)
		emoji_cooldown_tweens.append(tween)
		
		# Only the last button triggers the cleanup
		if i == emoji_buttons.size() - 1:
			tween.tween_callback(func():
				_clear_emoji_cooldown()
			)

func _clear_emoji_cooldown():
	"""Clear cooldown and reset emoji buttons"""
	for button in emoji_buttons:
		button.disabled = false
		button.modulate = Color.WHITE
	
	emoji_cooldown_tweens.clear()
	emoji_on_cooldown = false

func _update_controls_visibility():
	"""Update button visibility based on role and state"""
	if start_button:
		start_button.visible = is_host
		var can_start = _can_start_game()
		start_button.disabled = not can_start or game_started
		
		# Apply modulation for disabled state
		if start_button.disabled:
			start_button.modulate = Color(1, 1, 1, 0.7)  # 70% opacity
		else:
			start_button.modulate = Color.WHITE  # Full opacity

	if ready_button:
		ready_button.visible = true
		ready_button.disabled = game_started
		ready_button.text = "Ready"  # Always show "Ready" text
		
		# Update button style based on ready state
		if is_ready:
			UIStyleManager.apply_button_style(ready_button, "success", "medium")
		else:
			UIStyleManager.apply_button_style(ready_button, "warning", "medium")
		
		# Apply modulation for disabled state
		if ready_button.disabled:
			ready_button.modulate = Color(1, 1, 1, 0.7)  # 70% opacity
		else:
			ready_button.modulate = Color.WHITE  # Full opacity
	
	if leave_button:
		leave_button.disabled = is_ready or game_started
		
		# Apply modulation for disabled state
		if leave_button.disabled:
			leave_button.modulate = Color(1, 1, 1, 0.7)  # 70% opacity
		else:
			leave_button.modulate = Color.WHITE  # Full opacity

func _update_start_button_state():
	"""Update start button based on game conditions"""
	if start_button and is_host:
		start_button.disabled = not _can_start_game()

func _can_start_game() -> bool:
	"""Check if game can start"""
	if game_started:
		return false
		
	var player_count = get_player_count()
	
	if player_count < MIN_PLAYERS:
		return false
	
	if require_all_ready:
		return get_ready_count() == player_count
	
	return true

func _check_all_ready():
	"""Check if all players are ready"""
	if require_all_ready:
		var player_count = get_player_count()
		var ready_count = get_ready_count()
		
		if player_count >= MIN_PLAYERS and ready_count == player_count:
			if SignalBus.has_signal("lobby_all_players_ready"):
				SignalBus.lobby_all_players_ready.emit()

func get_player_count() -> int:
	"""Get number of players in lobby"""
	var count = 0
	for slot in player_slots:
		if slot.has_method("is_empty") and not slot.is_empty():
			count += 1
	return count

func get_ready_count() -> int:
	"""Get number of ready players"""
	var count = 0
	for slot in player_slots:
		if slot.has_method("is_empty") and not slot.is_empty():
			if slot.has_method("is_ready") and slot.is_ready():
				count += 1
	return count

func get_all_players() -> Array:
	"""Get all player data"""
	var players = []
	for slot in player_slots:
		if slot.has_method("is_empty") and not slot.is_empty():
			if slot.has_property("player_data"):
				players.append(slot.player_data)
	return players

# === SIGNAL HANDLERS ===

func _on_slot_clicked(slot_index: int):
	"""Handle slot click - expand profile view"""
	var slot = player_slots[slot_index]
	if slot.has_method("is_empty") and not slot.is_empty():
		if slot.has_method("get_player_name"):
			print("Player profile clicked: %s" % slot.get_player_name())
		# TODO: Show expanded profile view

func _on_player_kicked(player_id: String):
	"""Handle player kick request from host"""
	if not is_host:
		return
	
	if enable_kick_confirmation:
		# TODO: Show confirmation dialog
		print("Kick player confirmation needed: %s" % player_id)
		_kick_player_confirmed(player_id)
	else:
		_kick_player_confirmed(player_id)

func _kick_player_confirmed(player_id: String):
	"""Actually kick the player after confirmation"""
	remove_player(player_id)
	if SignalBus.has_signal("lobby_player_kicked"):
		SignalBus.lobby_player_kicked.emit(player_id)
	# TODO: Send network message to kick player

func _on_invite_sent(slot_index: int):
	"""Handle invite request for empty slot"""
	print("Invite requested for slot %d" % slot_index)
	if SignalBus.has_signal("lobby_invite_requested"):
		SignalBus.lobby_invite_requested.emit(slot_index)
	# TODO: Open invite dialog in Phase 2

func _on_player_ready_changed(player_id: String, ready: bool):
	"""Handle ready state change from PlayerSlot"""
	if SignalBus.has_signal("lobby_player_ready_changed"):
		SignalBus.lobby_player_ready_changed.emit(player_id, ready)

func _on_ready_pressed():
	"""Handle ready button toggle"""
	is_ready = not is_ready
	set_player_ready(local_player_id, is_ready)
	_update_controls_visibility()

func _on_start_pressed():
	"""Handle start game button (host only)"""
	if _can_start_game():
		game_started = true
		
		# Immediately update visual state
		start_button.disabled = true
		start_button.modulate = Color(1, 1, 1, 0.7)
		
		if SignalBus.has_signal("lobby_start_requested"):
			SignalBus.lobby_start_requested.emit()
		
		_update_controls_visibility()
		print("Starting game with %d players" % get_player_count())
		# TODO: Transition to game scene

func _on_leave_pressed():
	"""Handle leave lobby button"""
	if not is_ready and not game_started:
		print("Leaving lobby")
		# TODO: Return to MultiplayerScreen
		if ResourceLoader.exists("res://Pyramids/scenes/ui/menus/MultiplayerScreen.tscn"):
			get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MultiplayerScreen.tscn")

func _on_emoji_pressed(emoji_index: int):
	"""Handle emoji button press with cooldown"""
	# Check if ANY emoji is on cooldown
	if emoji_on_cooldown:
		return  # All emojis are on cooldown
	
	var button = emoji_buttons[emoji_index - 1]
	var emoji_id = button.get_meta("emoji_id", "")
	if emoji_id == "":
		return
	
	# Apply cooldown to ALL emoji buttons
	_start_global_emoji_cooldown()
	
	# Show emoji on local player's card
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == local_player_id:
			if slot.mini_profile_card and slot.mini_profile_card.has_method("show_emoji"):
				slot.mini_profile_card.show_emoji(emoji_id)
			break
	
	# TODO: Send emoji to network for other players to see
	print("Emoji sent: %s" % emoji_id)

# === TEST/DEBUG ===

func _test_lobby():
	"""Test the lobby with mock data"""
	print("=== Testing GameLobby ===")
	
	# Simulate being the host
	var mock_host = _get_mock_player_data()[0]
	host_player_id = mock_host["id"]
	local_player_id = mock_host["id"]
	set_as_host(true)
	set_local_player(mock_host["id"])
	
	# Add mock players
	for player_data in _get_mock_player_data():
		add_player(player_data)

# === MOCK DATA ===

func _get_mock_player_data() -> Array:
	"""Return mock player data for testing"""
	return [
		{
			"id": "player_1",
			"name": "DesertKing",
			"level": 42,
			"prestige": 3,
			"stats": {"games": 1250, "win_rate": 0.68, "mmr": 2850},
			"display_items": ["first_win", "combo_master", "speed_demon"],
			"frame_id": "",
			"is_ready": false,
			"is_host": true
		},
		{
			"id": "player_2", 
			"name": "PyramidQueen",
			"level": 38,
			"prestige": 2,
			"stats": {"games": 890, "win_rate": 0.72, "mmr": 2650},
			"display_items": ["veteran", "", "perfect_game"],
			"frame_id": "",
			"is_ready": false,
			"is_host": false
		},
		{
			"id": "player_3",
			"name": "Anubis",
			"level": 15,
			"prestige": 0,
			"stats": {"games": 120, "win_rate": 0.45, "mmr": 1200},
			"display_items": ["first_game", "", ""],
			"frame_id": "",
			"is_ready": false,
			"is_host": false
		},
		{
			"id": "player_4",
			"name": "SandStorm",
			"level": 55,
			"prestige": 5,
			"stats": {"games": 3200, "win_rate": 0.82, "mmr": 3500},
			"display_items": ["legend", "speed_demon", "perfect_game"],
			"frame_id": "",
			"is_ready": false,
			"is_host": false
		}
	]
