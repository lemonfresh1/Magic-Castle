# GameLobby.gd - Manages the multiplayer game lobby
# Location: res://Pyramids/scripts/ui/menus/GameLobby.gd
# Last Updated: Integrated MultiplayerManager and GameSettingsPanel [Date]
#
# Dependencies:
#   - PlayerSlot: Individual player slot management
#   - MiniProfileCard: Visual player card display
#   - SignalBus: Centralized signal management
#   - UIStyleManager: Consistent UI styling
#   - MultiplayerManager: Game mode and lobby state
#   - GameSettingsPanel: Reusable settings display
#
# Flow: MultiplayerScreen → GameLobby → PlayerSlots → MiniProfileCards
#
# Functionality:
#   • Manages 8 player slots in 4x2 grid
#   • Handles ready states and game start conditions
#   • Host controls (kick players, start game)
#   • Emoji reactions (placeholder)
#   • Leave/invite functionality
#   • Dynamic mode settings display
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
const MIN_PLAYERS = 1  # Changed to 1 for testing (normally 2)
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
@onready var settings_vbox: VBoxContainer = $MainContainer/ContentVBox/PlayersAndSettings/SettingsPanel/SettingsVBox
@onready var bottom_buttons: HBoxContainer = $MainContainer/ContentVBox/BottomButtons
@onready var ready_button: Button = $MainContainer/ContentVBox/BottomButtons/ReadyButton
@onready var start_button: Button = $MainContainer/ContentVBox/BottomButtons/StartButton
@onready var emoji_button_1: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton1
@onready var emoji_button_2: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton2
@onready var emoji_button_3: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton3
@onready var emoji_button_4: Button = $MainContainer/ContentVBox/BottomButtons/EmojiButton4
@onready var leave_button: Button = $MainContainer/ContentVBox/BottomButtons/LeaveButton
@onready var debug_button: Button = null  # Will create dynamically

# === PROPERTIES ===
var player_slots: Array = []
var local_player_id: String = ""
var host_player_id: String = ""
var is_host: bool = false
var is_ready: bool = false
var game_started: bool = false
var showing_debug: bool = false
var current_game_mode: String = "classic"
var is_custom_lobby: bool = false
var network_manager: Node = null
var lobby_id_label: Label  # Add UI element to show lobby ID
var is_voluntarily_leaving: bool = false  # ✅ ADD THIS


var debug_enabled: bool = true
var debug_player_tracking: Array = []  # Track all player add/remove operations

# Components
var game_settings_component: Control  # NEW: Reusable settings panel
var game_settings_panel_script = preload("res://Pyramids/scripts/ui/components/GameSettingsPanel.gd")

# Emoji system
var emoji_buttons: Array = []
var emoji_on_cooldown: bool = false
var emoji_cooldown_overlays: Array = []
var emoji_cooldown_tweens: Array = []
var emoji_progress_bars: Array = []

func debug_log(message: String) -> void:
	if debug_enabled:
		var timestamp = Time.get_ticks_msec()
		var full_message = "[%d] [GameLobby] %s" % [timestamp, message]
		print(full_message)
		debug_player_tracking.append(full_message)

func _ready():
	debug_log("=== GAMELOBBY _ready() START ===")
	
	# Get NetworkManager reference
	if has_node("/root/NetworkManager"):
		network_manager = get_node("/root/NetworkManager")
		debug_log("NetworkManager found")
	
	# CREATE SLOTS FIRST - before loading state!
	debug_log("Creating player slots...")
	_create_player_slots()
	
	# Wait for lobby data if coming from multiplayer
	if network_manager and has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		
		if mp_manager.current_lobby_id != "":
			debug_log("Coming from MultiplayerManager, waiting for lobby data...")
			
			var wait_time = 0.0
			while not network_manager.current_lobby_data.has("id") and wait_time < 5.0:
				await get_tree().create_timer(0.1).timeout
				wait_time += 0.1
				debug_log("  Waiting for lobby... (%0.1fs)" % wait_time)
			
			if network_manager.current_lobby_data.has("id"):
				debug_log("✅ Lobby data received!")
			else:
				debug_log("⚠️ Timeout waiting for lobby data")
	
	debug_log("Calling _load_lobby_state()")
	_load_lobby_state()
	
	print_lobby_state("After _load_lobby_state")
	
	_setup_lobby()
	_connect_signals()
	_apply_ui_styling()
	_setup_emoji_buttons()
	_update_controls_visibility()
	_connect_network_signals()
	
	if network_manager:
		network_manager.start_polling()
		debug_log("Started polling")
		
		# ✅ NEW: Subscribe to realtime emoji events
		if network_manager.is_in_lobby():
			var lobby_id = network_manager.current_lobby_data.get("id", "")
			if lobby_id != "":
				network_manager.subscribe_to_emoji_events(lobby_id, "lobby")
				debug_log("Subscribed to realtime emojis")
	
	var player_count = get_player_count()
	debug_log("Player count after load: %d" % player_count)
	
	if player_count == 0:
		debug_log("No players loaded, calling _auto_join_if_matchmaking()")
		_auto_join_if_matchmaking()
	else:
		debug_log("Players already loaded, skipping auto-join")
	
	print_lobby_state("After _auto_join_if_matchmaking")
	
	var is_direct_run = get_tree().current_scene == self
	var from_mp_manager = has_node("/root/MultiplayerManager") and get_node("/root/MultiplayerManager").current_lobby_id != ""
	
	if is_direct_run and not from_mp_manager and get_player_count() == 0:
		debug_log("Running test lobby (direct scene run)")
		_test_lobby()
	else:
		debug_log("Skipping test mode (is_direct=%s, from_mp=%s, player_count=%d)" % [is_direct_run, from_mp_manager, get_player_count()])
	
	debug_log("=== GAMELOBBY _ready() COMPLETE ===")

# === SETUP ===

func _load_lobby_state():
	debug_log(">>> _load_lobby_state() START")
	
	# Clear all slots first
	debug_log("  Clearing all slots")
	for slot in player_slots:
		if slot.has_method("set_empty"):
			slot.set_empty()
	
	# First try NetworkManager
	if network_manager:
		var lobby_data = network_manager.get_current_lobby()
		debug_log("  Got lobby data from NetworkManager: %s" % ("YES" if lobby_data.has("id") else "NO"))
		
		if lobby_data.has("id"):
			var lobby_id = lobby_data.get("id", "")
			debug_log("  Lobby ID: %s" % lobby_id)
			
			lobby_name = "Lobby: " + lobby_id.substr(0, 8)
			current_game_mode = lobby_data.get("mode", "classic")
			
			var host_id = lobby_data.get("host_id", "")
			debug_log("  Host ID from lobby: %s" % host_id)
			
			if network_manager.supabase and network_manager.supabase.current_user.has("id"):
				local_player_id = network_manager.supabase.current_user.get("id", "")
				is_host = (local_player_id == host_id)
				host_player_id = host_id
				debug_log("  Local Player ID: %s" % local_player_id)
				debug_log("  Am I host? %s" % is_host)
				
				# ✅ NEW: Call set_as_host() to propagate kick button visibility
				if is_host:
					debug_log("  Calling set_as_host(true) to enable kick buttons")
					set_as_host(true)
			
			# Load players
			var players = lobby_data.get("players", [])
			if players is String:
				debug_log("  Players is String, parsing JSON...")
				var json = JSON.new()
				var parse_result = json.parse(players)
				if parse_result == OK:
					players = json.data
					debug_log("  Parsed %d players from JSON" % players.size())
			else:
				debug_log("  Players is already Array with %d players" % players.size())
			
			debug_log("  Loading %d players from lobby data:" % players.size())
			for i in range(players.size()):
				var player_data = players[i]
				debug_log("    Player %d: %s (ID: %s)" % [i, player_data.get("name", "Unknown"), player_data.get("id", "NO_ID")])
				_add_player_to_empty_slot(player_data)
			
			debug_log("<<< _load_lobby_state() COMPLETE (from NetworkManager)")
			return
	
	debug_log("  No NetworkManager data, falling back to MultiplayerManager")
	# Fallback code...
	debug_log("<<< _load_lobby_state() COMPLETE (fallback)")

func _setup_lobby():
	"""Initialize lobby settings and title"""
	if lobby_title:
		var mode_name = _get_mode_display_name()
		
		# Show lobby ID if we have one
		if network_manager:
			var lobby_data = network_manager.get_current_lobby()
			if lobby_data.has("id"):
				var short_id = lobby_data.get("id", "").substr(0, 8)
				lobby_title.text = "%s Mode - Lobby: %s" % [mode_name, short_id]
			else:
				lobby_title.text = "%s Mode Lobby" % mode_name
		else:
			lobby_title.text = "%s Mode Lobby" % mode_name
	
	# Setup settings panel with game mode info
	if settings_panel:
		settings_panel.visible = true
		_setup_game_settings_display()

func _setup_game_settings_display():
	"""Setup the game settings display using GameSettingsPanel component"""
	# Clear existing content
	for child in settings_vbox.get_children():
		child.queue_free()
	
	# Create GameSettingsPanel component (VBoxContainer since the script extends it)
	game_settings_component = VBoxContainer.new()
	game_settings_component.set_script(game_settings_panel_script)
	settings_vbox.add_child(game_settings_component)
	
	# Setup the component
	if game_settings_component.has_method("setup_display"):
		# For custom lobbies, host can edit (future feature)
		var can_edit = is_custom_lobby and is_host
		
		game_settings_component.setup_display(current_game_mode, can_edit, {
			"show_title": true,
			"compact": false
		})

func _get_mode_display_name() -> String:
	"""Get display name for current mode"""
	if has_node("/root/GameModeManager"):
		var config = GameModeManager.available_modes.get(current_game_mode, {})
		return config.get("display_name", current_game_mode.capitalize())
	
	# Fallback
	match current_game_mode:
		"classic": return "Classic"
		"timed_rush": return "Rush"
		"test": return "Test"
		_: return current_game_mode.capitalize()

func _auto_join_if_matchmaking():
	debug_log(">>> _auto_join_if_matchmaking() START")
	debug_log("  is_custom_lobby: %s" % is_custom_lobby)
	
	if not is_custom_lobby and has_node("/root/NetworkManager"):
		var net_manager = get_node("/root/NetworkManager")
		
		# ✅ FIX: Build player data using NetworkManager (has level/prestige/equipment!)
		var player_data = net_manager._build_player_data()
		player_data["is_host"] = is_host
		
		debug_log("  Built player data from NetworkManager:")
		debug_log("    Level: %d, Prestige: %d" % [player_data.get("level", 0), player_data.get("prestige", 0)])
		
		var player_id = player_data.get("id", "")
		
		# FIX: Don't proceed if ID is empty
		if player_id == "":
			debug_log("  ERROR: Player ID is empty! Cannot auto-join.")
			debug_log("<<< _auto_join_if_matchmaking() ABORTED (empty ID)")
			return
		
		debug_log("  AUTO-JOIN TRIGGERED")
		debug_log("  Player to add: %s (ID: %s)" % [player_data.get("name", "Unknown"), player_id])
		debug_log("  Checking if player already exists...")
		
		# Check if already in lobby
		var already_exists = false
		for slot in player_slots:
			if slot.has_method("get_player_id"):
				var existing_id = slot.get_player_id()
				# FIX: Only match if BOTH IDs are non-empty
				if existing_id != "" and existing_id == player_id:
					already_exists = true
					debug_log("  PLAYER ALREADY EXISTS IN SLOT! Skipping add.")
					break
		
		if not already_exists:
			debug_log("  Player not found, calling add_player()")
			add_player(player_data)
		else:
			debug_log("  Player already in lobby, NOT adding")
	else:
		debug_log("  AUTO-JOIN SKIPPED (custom lobby or no MP manager)")
	
	debug_log("<<< _auto_join_if_matchmaking() COMPLETE")

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
	# Button signals
	if start_button:
		if not start_button.pressed.is_connected(_on_start_pressed):
			start_button.pressed.connect(_on_start_pressed)
	
	if leave_button:
		if not leave_button.pressed.is_connected(_on_leave_pressed):
			leave_button.pressed.connect(_on_leave_pressed)
	
	if ready_button:
		if not ready_button.pressed.is_connected(_on_ready_pressed):
			ready_button.pressed.connect(_on_ready_pressed)
	
	# Emoji button signals
	if emoji_button_1:
		if not emoji_button_1.pressed.is_connected(_on_emoji_pressed.bind(0)):
			emoji_button_1.pressed.connect(_on_emoji_pressed.bind(0))
	
	if emoji_button_2:
		if not emoji_button_2.pressed.is_connected(_on_emoji_pressed.bind(1)):
			emoji_button_2.pressed.connect(_on_emoji_pressed.bind(1))
	
	if emoji_button_3:
		if not emoji_button_3.pressed.is_connected(_on_emoji_pressed.bind(2)):
			emoji_button_3.pressed.connect(_on_emoji_pressed.bind(2))
	
	if emoji_button_4:
		if not emoji_button_4.pressed.is_connected(_on_emoji_pressed.bind(3)):
			emoji_button_4.pressed.connect(_on_emoji_pressed.bind(3))
	
	# ✅ Connect kick signals from all player slots
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		if slot and slot.has_signal("player_kicked"):
			if not slot.player_kicked.is_connected(_on_player_kick_requested):
				slot.player_kicked.connect(_on_player_kick_requested)
				debug_log("Connected kick signal for slot %d" % i)

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
		UIStyleManager.apply_button_style(ready_button, "warning", "medium")
	
	if start_button:
		UIStyleManager.apply_button_style(start_button, "success", "medium")
		start_button.add_theme_font_size_override("font_size", 20)
	
	if leave_button:
		UIStyleManager.apply_button_style(leave_button, "danger", "medium")

# === PUBLIC API ===

func set_as_host(host: bool = true):
	"""Set this player as the host"""
	debug_log(">>> set_as_host(%s)" % host)
	is_host = host
	_update_controls_visibility()
	
	# Update all slots to show/hide kick buttons
	debug_log("  Updating %d player slots with host viewing" % player_slots.size())
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		if slot.has_method("set_host_viewing"):
			debug_log("    Slot %d: Calling set_host_viewing(%s)" % [i, is_host])
			slot.set_host_viewing(is_host)
		else:
			debug_log("    Slot %d: ERROR - no set_host_viewing() method" % i)
	
	# Update settings panel if it's a custom lobby
	if is_custom_lobby and game_settings_component and game_settings_component.has_method("set_editable"):
		game_settings_component.set_editable(is_host)
	
	debug_log("<<< set_as_host() complete")

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
	var player_id = player_data.get("id", "")
	debug_log(">>> add_player() called for: %s (ID: %s)" % [player_data.get("name", "Unknown"), player_id])
	
	# Check if player already exists
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			debug_log("  Player already in lobby, updating instead")
			if slot.has_method("set_player"):
				slot.set_player(player_data)
			debug_log("<<< add_player() COMPLETE (updated existing)")
			return true
	
	# Add to empty slot
	debug_log("  Player not found, adding to empty slot")
	var result = _add_player_to_empty_slot(player_data)
	debug_log("<<< add_player() COMPLETE (result: %s)" % result)
	return result

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
	debug_log(">>> set_player_ready(%s, %s)" % [player_id.substr(0, 8), ready])
	
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.has_method("set_ready"):
				slot.set_ready(ready)
			if SignalBus.has_signal("lobby_player_ready_changed"):
				SignalBus.lobby_player_ready_changed.emit(player_id, ready)
			
			debug_log("  Calling _update_start_button_state()")
			_update_start_button_state()
			
			debug_log("  Calling _check_all_ready()")
			_check_all_ready()
			break
	
	debug_log("<<< set_player_ready()")

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
		button.modulate = Color(0.3, 0.3, 0.3, 1.0)
		
		var tween = create_tween()
		tween.tween_property(button, "modulate", Color.WHITE, 3.0)
		emoji_cooldown_tweens.append(tween)
		
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
	debug_log(">>> _update_controls_visibility()")
	debug_log("  is_host: %s" % is_host)
	debug_log("  game_started: %s" % game_started)
	debug_log("  is_ready: %s" % is_ready)
	
	if start_button:
		start_button.visible = is_host
		var can_start = _can_start_game()
		start_button.disabled = not can_start or game_started
		
		debug_log("  start_button.visible: %s" % start_button.visible)
		debug_log("  can_start: %s" % can_start)
		debug_log("  start_button.disabled: %s" % start_button.disabled)
		
		if start_button.disabled:
			start_button.modulate = Color(1, 1, 1, 0.7)
		else:
			start_button.modulate = Color.WHITE
	
	if ready_button:
		ready_button.visible = true
		ready_button.disabled = game_started
		ready_button.text = "Ready" if not is_ready else "Unready"
		
		if is_ready:
			UIStyleManager.apply_button_style(ready_button, "success", "medium")
		else:
			UIStyleManager.apply_button_style(ready_button, "warning", "medium")
		
		if ready_button.disabled:
			ready_button.modulate = Color(1, 1, 1, 0.7)
		else:
			ready_button.modulate = Color.WHITE
	
	if leave_button:
		leave_button.disabled = is_ready or game_started
		
		if leave_button.disabled:
			leave_button.modulate = Color(1, 1, 1, 0.7)
		else:
			leave_button.modulate = Color.WHITE
	
	debug_log("<<< _update_controls_visibility()")

func _update_start_button_state():
	"""Update start button based on game conditions"""
	debug_log(">>> _update_start_button_state()")
	if start_button and is_host:
		var can_start = _can_start_game()
		start_button.disabled = not can_start
		debug_log("  Updated start_button.disabled to: %s" % start_button.disabled)
	else:
		if not start_button:
			debug_log("  ERROR: start_button is null!")
		if not is_host:
			debug_log("  Not host, skipping start button update")
	debug_log("<<< _update_start_button_state()")

func _can_start_game() -> bool:
	"""Check if game can start"""
	debug_log("  >>> _can_start_game()")
	debug_log("    game_started: %s" % game_started)
	
	if game_started:
		debug_log("    Result: false (already started)")
		return false
	
	var player_count = get_player_count()
	debug_log("    player_count: %d" % player_count)
	debug_log("    MIN_PLAYERS: %d" % MIN_PLAYERS)
	
	if player_count < MIN_PLAYERS:
		debug_log("    Result: false (not enough players)")
		return false
	
	if require_all_ready:
		var ready_count = get_ready_count()
		debug_log("    require_all_ready: true")
		debug_log("    ready_count: %d" % ready_count)
		var result = ready_count == player_count
		debug_log("    Result: %s (ready check)" % result)
		return result
	
	debug_log("    Result: true (no ready requirement)")
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
	# TODO: Open invite dialog

func _on_player_ready_changed(player_id: String, ready: bool):
	"""Handle ready state change from PlayerSlot"""
	if SignalBus.has_signal("lobby_player_ready_changed"):
		SignalBus.lobby_player_ready_changed.emit(player_id, ready)

func _on_ready_pressed():
	"""Handle ready button toggle with network sync"""
	debug_log(">>> _on_ready_pressed()")
	debug_log("  Current is_ready: %s" % is_ready)
	
	is_ready = not is_ready
	
	debug_log("  New is_ready: %s" % is_ready)
	debug_log("  local_player_id: %s" % local_player_id)
	
	# Update local display immediately
	set_player_ready(local_player_id, is_ready)
	_update_controls_visibility()
	
	# Sync to network
	if network_manager:
		debug_log("  Syncing to network...")
		network_manager.update_player_ready_state(local_player_id, is_ready)
	else:
		debug_log("  WARNING: No NetworkManager to sync ready state")
	
	debug_log("<<< _on_ready_pressed()")

func _on_start_pressed():
	"""Handle start game button (host only)"""
	debug_log(">>> _on_start_pressed()")
	
	if not _can_start_game():
		debug_log("  Cannot start game (conditions not met)")
		debug_log("<<< _on_start_pressed() ABORTED")
		return
	
	if game_started:
		debug_log("  Game already started")
		debug_log("<<< _on_start_pressed() ABORTED")
		return
	
	debug_log("Host starting game...")
	
	# DON'T set game_started yet - let _start_game_from_network() do it
	# game_started = true  // REMOVED
	
	# Disable button to prevent double-clicks
	start_button.disabled = true
	start_button.modulate = Color(1, 1, 1, 0.7)
	
	if SignalBus.has_signal("lobby_start_requested"):
		SignalBus.lobby_start_requested.emit()
	
	debug_log("Starting game with mode: %s, players: %d" % [current_game_mode, get_player_count()])
	
	# Update lobby status in Supabase to "playing"
	if network_manager and network_manager.current_lobby_data.has("id"):
		var lobby_id = network_manager.current_lobby_data.get("id", "")
		
		debug_log("  Updating lobby status to 'playing'...")
		
		# Stop polling BEFORE updating status
		network_manager.stop_polling()
		
		# Update lobby status
		network_manager.supabase.current_request_type = "update_lobby_status"
		var url = network_manager.supabase.SUPABASE_URL + "/rest/v1/pyramids_lobbies"
		url += "?id=eq." + lobby_id
		
		var headers = network_manager.supabase._get_db_headers()
		headers.append("Content-Type: application/json")
		headers.append("Prefer: return=representation")
		
		var body = JSON.stringify({
			"status": "playing",
			"current_round": 1
		})
		network_manager.supabase.db_request.request(url, headers, HTTPClient.METHOD_PATCH, body)
		
		debug_log("  Waiting for status update to propagate...")
		# Wait for the update to propagate
		await get_tree().create_timer(1.0).timeout
		
		debug_log("  Calling _start_game_from_network()...")
		# Then start the game
		_start_game_from_network()
	else:
		debug_log("  No NetworkManager, starting game directly...")
		# Fallback for non-networked games
		if has_node("/root/MultiplayerManager"):
			var mp_manager = get_node("/root/MultiplayerManager")
			mp_manager.start_game()
		else:
			if has_node("/root/GameModeManager"):
				GameModeManager.set_game_mode(current_game_mode, {})
			get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")
	
	debug_log("<<< _on_start_pressed()")

func _on_leave_pressed():
	"""Handle leave lobby button"""
	debug_log(">>> _on_leave_pressed()")
	debug_log("  is_ready: %s, game_started: %s" % [is_ready, game_started])
	debug_log("  OS: %s" % OS.get_name())
	
	if not is_ready and not game_started:
		debug_log("Leaving lobby")
		
		is_voluntarily_leaving = true

		leave_button.disabled = true
		
		# FIRST: Remove from database (and WAIT for it)
		if network_manager and network_manager.current_lobby_data.has("id"):
			debug_log("  Removing self from lobby database...")
			network_manager.leave_lobby()
			
			# Wait for the database update to complete
			debug_log("  Waiting for database update...")
			await get_tree().create_timer(0.5).timeout
			debug_log("  Database update should be complete")
		
		# THEN: Stop polling and cleanup
		if network_manager:
			debug_log("  Force stopping all network activity...")
			network_manager.stop_polling()
			network_manager.unsubscribe_from_emoji_events()
			
			# Disconnect signals to prevent callbacks during transition
			if network_manager.lobby_updated.is_connected(_on_network_lobby_updated):
				network_manager.lobby_updated.disconnect(_on_network_lobby_updated)
			if network_manager.emoji_received.is_connected(_on_emoji_received):
				network_manager.emoji_received.disconnect(_on_emoji_received)
			
			# Reset network state
			network_manager.current_lobby_data = {}
			network_manager.is_polling = false
			
			debug_log("  Network activity stopped and signals disconnected")
		
		# Notify MultiplayerManager
		if has_node("/root/MultiplayerManager"):
			debug_log("  Notifying MultiplayerManager...")
			var mp_manager = get_node("/root/MultiplayerManager")
			mp_manager.leave_current_lobby()
		
		# Android needs more time - wait 2 frames
		var os_name = OS.get_name()
		if os_name == "Android" or os_name == "iOS":
			debug_log("  Mobile platform detected - waiting 2 frames...")
			await get_tree().process_frame
			await get_tree().process_frame
		
		# Finally: Change scene
		debug_log("  Scheduling deferred scene change...")
		call_deferred("_change_scene_to_multiplayer")
	else:
		debug_log("Cannot leave - is_ready=%s or game_started=%s" % [is_ready, game_started])
	
	debug_log("<<< _on_leave_pressed()")
	

func _change_scene_to_multiplayer():
	"""Deferred scene change helper"""
	debug_log(">>> _change_scene_to_multiplayer() ATTEMPT 1")
	
	# Final safety check - ensure we're not in the middle of another scene change
	if not is_inside_tree():
		debug_log("  ERROR: Node not in tree! Cannot change scene.")
		return
	
	var scene_tree = get_tree()
	if not scene_tree:
		debug_log("  ERROR: No SceneTree!")
		return
	
	# Try to change scene
	var result = scene_tree.change_scene_to_file("res://Pyramids/scenes/ui/menus/MultiPlayerScreen.tscn")
	debug_log("  Scene change result: %d (0=OK)" % result)
	
	if result != OK:
		debug_log("  ERROR: Scene change failed with code %d! Trying alternative method..." % result)
		
		# Alternative method: Load scene manually and switch
		await get_tree().create_timer(0.1).timeout
		
		debug_log(">>> _change_scene_to_multiplayer() ATTEMPT 2")
		
		if not is_inside_tree():
			debug_log("  ERROR: Node no longer in tree after wait!")
			return
		
		var scene_path = "res://Pyramids/scenes/ui/menus/MultiPlayerScreen.tscn"
		if ResourceLoader.exists(scene_path):
			debug_log("  Loading scene resource...")
			var packed_scene = load(scene_path)
			
			if packed_scene:
				debug_log("  Scene loaded, instantiating...")
				var new_scene = packed_scene.instantiate()
				
				if new_scene:
					debug_log("  Scene instantiated, switching...")
					# Get root and swap scenes manually
					var root = scene_tree.root
					var current_scene = scene_tree.current_scene
					
					if current_scene:
						debug_log("  Removing current scene...")
						root.remove_child(current_scene)
						current_scene.queue_free()
					
					debug_log("  Adding new scene...")
					root.add_child(new_scene)
					scene_tree.current_scene = new_scene
					debug_log("  ✅ Scene switched successfully!")
				else:
					debug_log("  ERROR: Failed to instantiate scene!")
			else:
				debug_log("  ERROR: Failed to load packed scene!")
		else:
			debug_log("  ERROR: Scene file doesn't exist!")
	else:
		debug_log("  ✅ Scene change successful on first attempt!")
	
	debug_log("<<< _change_scene_to_multiplayer()")

func _on_emoji_pressed(emoji_index: int):
	"""Handle emoji button press with cooldown"""
	if emoji_on_cooldown:
		return
	
	var button = emoji_buttons[emoji_index - 1]
	var emoji_id = button.get_meta("emoji_id", "")
	if emoji_id == "":
		return
	
	_start_global_emoji_cooldown()
	
	# Show emoji on local player's card
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == local_player_id:
			if slot.mini_profile_card and slot.mini_profile_card.has_method("show_emoji"):
				slot.mini_profile_card.show_emoji(emoji_id)
			break
	
	# ✅ NEW: Send emoji to network
	if network_manager:
		network_manager.send_emoji(emoji_id, "lobby")
		debug_log("Sent emoji to network: %s" % emoji_id)

func _on_emoji_received(emoji_data: Dictionary) -> void:
	"""Handle emoji from another player"""
	var player_id = emoji_data.get("player_id", "")
	var emoji_id = emoji_data.get("emoji_id", "")
	var screen = emoji_data.get("screen", "")
	var player_name = emoji_data.get("player_name", "Player")
	
	# Skip if wrong screen
	if screen != "lobby":
		return
	
	# Skip our own emojis
	var local_id = network_manager.supabase.current_user.get("id", "") if network_manager else ""
	if player_id == local_id:
		return
	
	debug_log("Received emoji '%s' from %s" % [emoji_id, player_name])
	
	# Find player's slot and show emoji
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.mini_profile_card and slot.mini_profile_card.has_method("show_emoji"):
				slot.mini_profile_card.show_emoji(emoji_id)
				debug_log("Displayed emoji on slot for %s" % player_name)
			break

# === TEST/DEBUG ===

func _test_lobby():
	"""Test the lobby with mock data - MVP auto-join style"""
	print("=== Testing GameLobby (Direct Run) ===")
	
	var mock_player = {
		"id": "player_local",
		"name": "TestPlayer",
		"level": 42,
		"prestige": 3,
		"stats": {"games": 1250, "win_rate": 0.68, "mmr": 2850},
		"display_items": ["first_win", "combo_master", "speed_demon"],
		"frame_id": "",
		"is_ready": false,
		"is_host": true
	}
	
	host_player_id = mock_player["id"]
	local_player_id = mock_player["id"]
	set_as_host(true)
	set_local_player(mock_player["id"])
	add_player(mock_player)

func _on_debug_pressed():
	"""Toggle between game settings and debug panel"""
	showing_debug = not showing_debug
	
	if showing_debug:
		# Hide settings component, show debug
		if game_settings_component:
			game_settings_component.visible = false
		_setup_debug_panel()
	else:
		# Show settings component, hide debug
		if game_settings_component:
			game_settings_component.visible = true
		else:
			_setup_game_settings_display()
		
		# Clear debug content
		for child in settings_vbox.get_children():
			if child != game_settings_component:
				child.queue_free()

func _setup_debug_panel():
	"""Setup debug controls in settings panel"""
	# Title
	var title = Label.new()
	title.text = "🛠️ Debug Controls"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(title)
	
	var sep = HSeparator.new()
	settings_vbox.add_child(sep)
	
	# Perspective controls
	var perspective_label = Label.new()
	perspective_label.text = "Perspective:"
	perspective_label.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(perspective_label)
	
	var host_btn = Button.new()
	host_btn.text = "Become Host"
	host_btn.pressed.connect(func():
		is_host = true
		host_player_id = local_player_id
		set_as_host(true)
		for slot in player_slots:
			if slot.has_method("get_player_data"):
				slot.set_player(slot.player_data)
		print("Switched to HOST perspective")
	)
	settings_vbox.add_child(host_btn)
	
	var player_btn = Button.new()
	player_btn.text = "Become Player"
	player_btn.pressed.connect(func():
		is_host = false
		host_player_id = "player_2"
		set_as_host(false)
		for slot in player_slots:
			if slot.has_method("get_player_data"):
				slot.set_player(slot.player_data)
		print("Switched to PLAYER perspective")
	)
	settings_vbox.add_child(player_btn)
	
	settings_vbox.add_child(HSeparator.new())
	
	# Player management
	var players_label = Label.new()
	players_label.text = "Players:"
	players_label.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(players_label)
	
	var add_player_btn = Button.new()
	add_player_btn.text = "Add Random Player"
	add_player_btn.pressed.connect(func():
		var random_names = ["Pharaoh", "Cleopatra", "Sphinx", "Osiris", "Ra"]
		var mock_player = {
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
		add_player(mock_player)
	)
	settings_vbox.add_child(add_player_btn)
	
	var all_ready_btn = Button.new()
	all_ready_btn.text = "All Ready"
	all_ready_btn.pressed.connect(func():
		for slot in player_slots:
			if not slot.is_empty():
				set_player_ready(slot.get_player_id(), true)
	)
	settings_vbox.add_child(all_ready_btn)
	
	# Mode switcher
	settings_vbox.add_child(HSeparator.new())
	var mode_label = Label.new()
	mode_label.text = "Test Mode Switch:"
	mode_label.add_theme_color_override("font_color", Color.BLACK)
	settings_vbox.add_child(mode_label)
	
	var modes = ["classic", "timed_rush", "test"]
	for mode in modes:
		var mode_btn = Button.new()
		mode_btn.text = mode.capitalize()
		mode_btn.pressed.connect(func():
			current_game_mode = mode
			if lobby_title:
				lobby_title.text = "%s Mode Lobby" % _get_mode_display_name()
			if game_settings_component and game_settings_component.has_method("update_mode"):
				game_settings_component.update_mode(mode)
			print("Switched to mode: %s" % mode)
		)
		settings_vbox.add_child(mode_btn)

func _connect_network_signals():
	"""Connect to NetworkManager signals for real-time updates"""
	if not network_manager:
		print("[GameLobby] No NetworkManager available")
		return
	
	# Connect signals if not already connected
	if not network_manager.lobby_updated.is_connected(_on_network_lobby_updated):
		network_manager.lobby_updated.connect(_on_network_lobby_updated)
	
	if not network_manager.player_joined.is_connected(_on_network_player_joined):
		network_manager.player_joined.connect(_on_network_player_joined)
	
	if not network_manager.player_left.is_connected(_on_network_player_left):
		network_manager.player_left.connect(_on_network_player_left)
	
	# ✅ NEW: Connect emoji signal
	if not network_manager.emoji_received.is_connected(_on_emoji_received):
		network_manager.emoji_received.connect(_on_emoji_received)
		debug_log("Connected to emoji_received signal")
	
	print("[GameLobby] Connected to NetworkManager signals")
	
func _on_network_lobby_updated(lobby_data: Dictionary):
	debug_log(">>> _on_network_lobby_updated()")
	
	debug_log("  Raw lobby data player_count: %d" % lobby_data.get("player_count", -1))
	
	# Update lobby data
	if network_manager:
		network_manager.current_lobby_data = lobby_data
	
	# Extract players
	var players = lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	debug_log("Found %d players in lobby update" % players.size())
	
	# Build a map of player IDs from the lobby data
	var player_ids_in_lobby = {}
	for player_data in players:
		var pid = player_data.get("id", "")
		if pid != "":
			player_ids_in_lobby[pid] = player_data
	
	debug_log("  Player IDs in lobby: %s" % str(player_ids_in_lobby.keys()))
	
	# Update existing players or add new ones
	for player_id in player_ids_in_lobby:
		var player_data = player_ids_in_lobby[player_id]
		var found = false
		
		# Check if player already in a slot
		for slot in player_slots:
			if slot.has_method("get_player_id"):
				var existing_id = slot.get_player_id()
				if existing_id == player_id:
					debug_log("  Player %s already in slot" % player_id.substr(0, 8))
					
					# ✅ NEW: Only update if data actually changed
					if _player_data_changed(slot, player_data):
						debug_log("    → Data changed, updating slot")
						if slot.has_method("set_player"):
							slot.set_player(player_data)
					else:
						debug_log("    → No changes, skipping update")
					
					# ✅ Always update ready state (it changes frequently)
					if slot.has_method("set_ready"):
						var new_ready = player_data.get("is_ready", false)
						var current_ready = slot.is_ready() if slot.has_method("is_ready") else false
						if new_ready != current_ready:
							slot.set_ready(new_ready)
					
					found = true
					break
		
		# Add new player if not found
		if not found:
			debug_log("  Player %s not in slots, adding" % player_id.substr(0, 8))
			_add_player_to_empty_slot(player_data)
	
	# Remove players who left (skip empty IDs)
	for slot in player_slots:
		if slot.has_method("is_empty") and not slot.is_empty():
			var slot_player_id = slot.get_player_id()
			if slot_player_id != "" and not player_ids_in_lobby.has(slot_player_id):
				debug_log("  Player %s left, removing from slot" % slot_player_id.substr(0, 8))
				slot.set_empty()
	
	# Update start button state
	_update_start_button_state()
	
	if local_player_id != "" and not player_ids_in_lobby.has(local_player_id):
		if is_voluntarily_leaving:
			debug_log("Local player removed (voluntary leave)")
			# Don't show kicked popup - we're leaving on purpose
		else:
			debug_log("⚠️ Local player was kicked from lobby!")
			_handle_being_kicked()
		return
	
	# Check if game is starting
	if lobby_data.get("status", "") == "playing" and not game_started:
		debug_log("Game is starting - transitioning all clients!")
		_start_game_from_network()
	
	debug_log("<<< _on_network_lobby_updated()")

func _player_data_changed(slot, new_data: Dictionary) -> bool:
	"""Check if player data actually changed (excluding ready state)"""
	# Get current player data from slot
	if not slot.has_method("get_player_data"):
		return true  # Can't compare, assume changed
	
	var old_data = slot.get_player_data()
	if not old_data:
		return true  # No old data, definitely changed
	
	# Compare key fields that affect visuals (excluding is_ready)
	var fields_to_check = ["name", "level", "prestige"]
	
	for field in fields_to_check:
		var old_value = old_data.get(field, null)
		var new_value = new_data.get(field, null)
		
		if old_value != new_value:
			debug_log("    Field '%s' changed: %s → %s" % [field, old_value, new_value])
			return true
	
	# Check equipped items (these change the showcase)
	var old_equipped = old_data.get("equipped", {})
	var new_equipped = new_data.get("equipped", {})
	
	# Only check showcase items
	var old_showcase = old_equipped.get("mini_profile_card_showcased_items", [])
	var new_showcase = new_equipped.get("mini_profile_card_showcased_items", [])
	
	if old_showcase != new_showcase:
		debug_log("    Showcase items changed")
		return true
	
	return false

func _add_player_to_empty_slot(player_data: Dictionary) -> bool:
	var player_id = player_data.get("id", "")
	var player_name = player_data.get("name", "Unknown")
	
	debug_log(">>> _add_player_to_empty_slot() for: %s (ID: %s)" % [player_name, player_id])
	debug_log("  Level: %d, Prestige: %d" % [player_data.get("level", 0), player_data.get("prestige", 0)])
	debug_log("  Stats: %s" % str(player_data.get("stats", {})))
	debug_log("  Equipped: %s" % str(player_data.get("equipped", {}).keys()))
	
	# Ensure equipment data
	if not player_data.has("equipped") and EquipmentManager:
		player_data["equipped"] = EquipmentManager.get_equipped_items()
	
	# Find first empty slot
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		if slot.has_method("is_empty") and slot.is_empty():
			debug_log("  Found empty slot: %d" % i)
			
			var is_local = player_data.get("id", "") == local_player_id
			if is_local:
				debug_log("  This is the LOCAL player")
				if slot.has_method("set_as_local_player"):
					slot.set_as_local_player(true)
			
			if player_data.get("id", "") == host_player_id:
				debug_log("  This is the HOST")
				if slot.has_method("set_as_host"):
					slot.set_as_host()
			
			if slot.has_method("set_player"):
				slot.set_player(player_data)
			
			if SignalBus.has_signal("lobby_player_joined"):
				SignalBus.lobby_player_joined.emit(player_id, player_data)
			
			_update_start_button_state()
			debug_log("<<< _add_player_to_empty_slot() SUCCESS (slot %d)" % i)
			return true
	
	debug_log("<<< _add_player_to_empty_slot() FAILED (no empty slots)")
	return false

func _on_network_player_joined(player_data: Dictionary):
	"""Handle new player joining from network"""
	print("[GameLobby] Player joined: %s" % player_data.get("name", "Unknown"))
	add_player(player_data)

func _on_network_player_left(player_id: String):
	"""Handle player leaving from network"""
	print("[GameLobby] Player left: %s" % player_id)
	remove_player(player_id)

func _start_game_from_network():
	"""Start the game when host triggers it or status changes to playing"""
	debug_log(">>> _start_game_from_network()")
	
	if game_started:
		debug_log("  Game already started, ignoring duplicate call")
		return
	
	debug_log("  Setting game_started = true")
	game_started = true
	
	# Stop polling BEFORE scene change
	if network_manager and network_manager.is_polling:
		network_manager.stop_polling()
	
	# Get lobby seed from database
	var lobby_seed = 0
	if network_manager and network_manager.current_lobby_data.has("game_seed"):
		lobby_seed = int(network_manager.current_lobby_data.get("game_seed", 0))
		debug_log("  Using lobby seed: %d" % lobby_seed)
	else:
		debug_log("  WARNING: No game_seed in lobby data!")
	
	# Store necessary data
	if has_node("/root/MultiplayerManager"):
		var mp_manager = get_node("/root/MultiplayerManager")
		mp_manager.lobby_players = network_manager.current_lobby_data.get("players", []) if network_manager else []
		mp_manager.current_lobby_id = network_manager.current_lobby_data.get("id", "") if network_manager else ""
	
	# Configure GameModeManager
	if has_node("/root/GameModeManager"):
		GameModeManager.set_game_mode(current_game_mode, {})
	
	# Set GameState
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		game_state.game_mode = "multi"
		game_state.is_multiplayer = true
		
		# Store lobby seed for game to use
		if lobby_seed > 0:
			game_state.set_meta("multiplayer_lobby_seed", lobby_seed)
			debug_log("  Stored lobby seed in GameState metadata: %d" % lobby_seed)
	
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")
	
	debug_log("<<< _start_game_from_network() COMPLETE")

func _exit_tree():
	"""Cleanup when leaving the scene"""
	if network_manager:
		network_manager.stop_polling()
		network_manager.unsubscribe_from_emoji_events()

func _on_lobby_updated(lobby_data: Dictionary):
	"""Handle lobby updates from network"""
	var players = lobby_data.get("players", [])
	if players is String:
		var json = JSON.new()
		var parse_result = json.parse(players)
		if parse_result == OK:
			players = json.data
	
	# DON'T call _refresh_player_list
	# Instead, use the existing player slot system:
	
	# Clear all slots
	for slot in player_slots:
		if slot.has_method("set_empty"):
			slot.set_empty()
	
	# Re-add all players
	for player_data in players:
		add_player(player_data)

func print_lobby_state(context: String) -> void:
	"""Print complete lobby state for debugging"""
	debug_log("=== LOBBY STATE: %s ===" % context)
	debug_log("  Current Lobby ID: %s" % (network_manager.current_lobby_data.get("id", "NONE") if network_manager else "NO NETWORK"))
	debug_log("  Local Player ID: %s" % local_player_id)
	debug_log("  Is Host: %s" % is_host)
	
	# Count occupied slots
	var occupied = 0
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		if slot.has_method("is_empty") and not slot.is_empty():
			occupied += 1
			var player_id = slot.get_player_id() if slot.has_method("get_player_id") else "UNKNOWN"
			var player_name = slot.get_player_name() if slot.has_method("get_player_name") else "UNKNOWN"
			debug_log("    Slot %d: %s (ID: %s)" % [i, player_name, player_id])
		else:
			debug_log("    Slot %d: EMPTY" % i)
	
	debug_log("  Total Occupied Slots: %d" % occupied)
	debug_log("=== END STATE ===")

func _on_player_kick_requested(player_id: String):
	"""Handle kick request from a player slot"""
	debug_log("Kick requested for player: %s" % player_id)

	# Verify we're the host
	if not network_manager:
		debug_log("ERROR: NetworkManager not available")
		return

	var local_id = network_manager.supabase.current_user.get("id", "")
	var host_id = network_manager.current_lobby_data.get("host_id", "")

	if local_id != host_id:
		debug_log("ERROR: Only host can kick!")
		return

	# Find player name
	var player_name = "Player"
	for slot in player_slots:
		if slot.has_method("get_player_id") and slot.get_player_id() == player_id:
			if slot.has_method("get_player_name"):
				player_name = slot.get_player_name()
			break

	# Load KickDialog
	var popup_scene_path = "res://Pyramids/scenes/ui/popups/KickDialog.tscn"
	if not ResourceLoader.exists(popup_scene_path):
		debug_log("ERROR: KickDialog scene not found, kicking directly")
		network_manager.kick_player_from_lobby(player_id)
		return

	var popup_scene = load(popup_scene_path)
	var popup = popup_scene.instantiate()

	# Setup
	popup.setup(player_name)

	# Connect signals
	popup.confirmed.connect(func():
		debug_log("Kick confirmed for: %s" % player_name)
		network_manager.kick_player_from_lobby(player_id)
	)

	popup.cancelled.connect(func():
		debug_log("Kick cancelled")
	)

	# Show
	get_tree().root.add_child(popup)
	debug_log("Showing kick dialog for: %s" % player_name)

func _show_kicked_popup():
	"""Show 'You've been kicked' popup"""
	var popup_scene_path = "res://Pyramids/scenes/ui/popups/KickedDialog.tscn"

	if not ResourceLoader.exists(popup_scene_path):
		debug_log("ERROR: KickedDialog scene not found")
		_return_to_multiplayer_screen()
		return

	var popup_scene = load(popup_scene_path)
	var popup = popup_scene.instantiate()

	# Setup (no parameters needed, just sets title)
	popup.setup()

	# Connect
	popup.confirmed.connect(func():
		debug_log("Kicked dialog closed")
		_return_to_multiplayer_screen()
	)

	# Show
	get_tree().root.add_child(popup)
	debug_log("Kicked dialog displayed")

func _handle_being_kicked():
	"""Handle being kicked from the lobby"""
	debug_log(">>> _handle_being_kicked()")
	
	# Stop polling immediately
	if network_manager:
		network_manager.stop_polling()
		network_manager.unsubscribe_from_emoji_events()
	
	# Show kicked popup
	_show_kicked_popup()
	
	debug_log("<<< _handle_being_kicked()")

func _return_to_multiplayer_screen():
	"""Return to multiplayer screen after being kicked"""
	debug_log(">>> _return_to_multiplayer_screen() START")
	debug_log("  OS: %s" % OS.get_name())
	
	# FORCE CLEANUP
	if network_manager:
		debug_log("  Force stopping all network activity...")
		network_manager.stop_polling()
		network_manager.unsubscribe_from_emoji_events()
		
		# Disconnect signals
		if network_manager.lobby_updated.is_connected(_on_network_lobby_updated):
			network_manager.lobby_updated.disconnect(_on_network_lobby_updated)
		if network_manager.emoji_received.is_connected(_on_emoji_received):
			network_manager.emoji_received.disconnect(_on_emoji_received)
		
		# Reset state
		network_manager.reset_for_new_game()
		debug_log("  Cleanup complete")
	
	# Use call_deferred for scene change
	debug_log("  Scheduling deferred scene change...")
	call_deferred("_change_scene_to_multiplayer")
	
	debug_log("<<< _return_to_multiplayer_screen() COMPLETE")
