# MiniProfileCard.gd - Compact player profile card for lobbies and multiplayer
# Location: res://Pyramids/scripts/ui/components/MiniProfileCard.gd
# Last Updated: Phase A complete - 3-panel structure, emoji stats, typography [Date]
#
# MiniProfileCard handles:
# - Displaying player profile in compact 200x200 format
# - Managing empty (invite) and occupied states
# - Showing profile frame with level/prestige
# - Displaying 3 emoji stats (MMR, Win Rate, Games)
# - Showcasing 3 display items (achievements/items)
# - Host controls (kick button) and ready state
#
# Flow: PlayerData → MiniProfileCard → ProfileFrame + DisplayCards → Visual Output
# Dependencies: ProfileFrame (scene), DisplayItemCard (scene), UIStyleManager (typography),
#              AchievementManager (achievements), ItemManager (items), EquipmentManager (ownership)
#
# TODO:
# - [ ] Phase B: Replace DisplayItemCard with UnifiedItemCard for animations
# - [ ] Implement subtle animations (sway, float, shadow layers)
# - [ ] Add theme system for stats panel (parchment, LED, glass, wood)
# - [ ] Implement EffectOverlay usage (glass overlay, fire borders)
# - [ ] Add ProfileFrame custom items support
# - [ ] Create responsive sizing for different screen resolutions
# - [ ] Add haptic feedback for mobile touches
# - [ ] Implement expanded view on item click
# - [ ] Add sound effects for state changes
# - [ ] Support custom backgrounds/textures per player prestige
# - [ ] Add connection status indicator
# - [ ] Implement spectator mode display variant

extends PanelContainer

# === SIGNALS ===
signal player_clicked(player_id: String)
signal kick_requested(player_id: String)
signal invite_clicked(slot_index: int)
signal display_item_clicked(item_id: String)

# === CONSTANTS ===
const EMPTY_CARD_DATA = {
	"id": "",
	"name": "",
	"level": 0,
	"prestige": 0,
	"stats": {
		"games": 0,
		"win_rate": 0.0,
		"mmr": 0
	},
	"frame_id": "",
	"display_items": ["", "", ""],
	"is_ready": false,
	"is_host": false,
	"is_empty": true
}

# === EXPORTS ===
@export var slot_index: int = 0
@export var show_kick_button: bool = false  # Only for host
@export var clickable: bool = true

# === NODE REFERENCES ===
# Main structure (from scene)
@onready var effect_overlay: Control = $EffectOverlay
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox_container: VBoxContainer = $MarginContainer/VBoxContainer

# Top: Name
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel

# Middle: Profile + Stats
@onready var middle_section: HBoxContainer = $MarginContainer/VBoxContainer/MiddleSection
@onready var profile_container: Control = $MarginContainer/VBoxContainer/MiddleSection/ProfileContainer
@onready var stats_panel: PanelContainer = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel
@onready var stats_vbox: VBoxContainer = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox

# Stats (using scene nodes)
@onready var mmr_label: Label = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox/MMRLabel
@onready var win_rate_label: Label = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox/WinRateLabel
@onready var games_label: Label = $MarginContainer/VBoxContainer/MiddleSection/StatsPanel/StatsVBox/GamesLabel

# Bottom: Display items
@onready var bot_section: PanelContainer = $MarginContainer/VBoxContainer/BotSection
@onready var display_container: HBoxContainer = $MarginContainer/VBoxContainer/BotSection/DisplayContainer

# Overlay controls
@onready var kick_button: Button = $KickButton
@onready var ready_sign: TextureRect = $ReadySign
@onready var emoji_container: Control = $EmojiContainer
@onready var emoji_texture_rect: TextureRect = $EmojiContainer/EmojiTextureRect

# === MEMBER VARIABLES ===
var profile_frame: PanelContainer = null
var display_cards: Array[PanelContainer] = []
var player_data: Dictionary = {}
var is_empty: bool = true
var plus_label: Label = null
var applied_theme: ProceduralMiniProfileCard = null
var host_indicator = null
var active_emoji = null 

# === LIFECYCLE ===

func _ready() -> void:
	# Setup base appearance
	_setup_card_style()
	
	# Configure existing scene nodes
	_configure_scene_nodes()
	
	# Create dynamic components
	_create_profile_frame()
	_create_display_cards()
	
	# Setup controls
	_setup_overlay_controls()
	
	# Connect input
	if clickable:
		gui_input.connect(_on_gui_input)
	
	# Test mode if running directly
	if get_tree().current_scene == self:
		await get_tree().process_frame
		_test_card_states()

# === CONFIGURATION ===

func _configure_scene_nodes() -> void:
	"""Configure the nodes that exist in the scene"""
	
	# Effect overlay for future use
	if effect_overlay:
		effect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Name label styling - Using UIStyleManager typography
	if name_label:
		var name_font_size = UIStyleManager.typography["size_body_large"] if UIStyleManager else 20
		
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.set_offsets_preset(Control.PRESET_TOP_WIDE)
		name_label.offset_left = 0
		name_label.offset_right = -10
		name_label.custom_minimum_size = Vector2(0, 26)
	
	# Profile container setup
	if profile_container:
		profile_container.clip_contents = false
		profile_container.custom_minimum_size = Vector2(75, 75)
		profile_container.size = Vector2(75, 75)
	
	# Stats panel setup with padding
	if stats_panel:
		stats_panel.custom_minimum_size = Vector2(100, 65)
		stats_panel.modulate = Color.WHITE
		var panel_style = stats_panel.get_theme_stylebox("panel")
		if not panel_style:
			panel_style = StyleBoxFlat.new()
			panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.2)
			panel_style.border_color = Color(0.2, 0.2, 0.2, 0.3)
			panel_style.set_border_width_all(1)
			panel_style.set_corner_radius_all(4)
		if panel_style is StyleBoxFlat:
			panel_style.set_content_margin_all(4)
			stats_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Stats VBox setup
	if stats_vbox:
		stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_vbox.add_theme_constant_override("separation", 1)
	
	# Configure emoji stats labels
	_configure_stat_labels()
	
	# Bottom section styling
	if bot_section:
		var bot_style = StyleBoxFlat.new()
		bot_style.bg_color = Color(0.1, 0.1, 0.1, 0.3)
		bot_style.border_color = Color(0.3, 0.3, 0.3, 0.3)
		bot_style.set_border_width_all(1)
		bot_style.set_corner_radius_all(4)
		bot_section.add_theme_stylebox_override("panel", bot_style)
		bot_section.custom_minimum_size = Vector2(0, 68)
	
	# Display container setup
	if display_container:
		display_container.alignment = BoxContainer.ALIGNMENT_CENTER
		display_container.add_theme_constant_override("separation", 6)

func _configure_stat_labels() -> void:
	"""Configure the stat labels for emoji display using UIStyleManager typography"""
	# Update label references to match new stats
	# win_rate_label stays the same
	# games_label stays the same  
	# mmr_label becomes avg_rank_label
	
	var labels = [win_rate_label, games_label, mmr_label]  # mmr_label will show avg rank
	
	var stat_font_size = 16
	if UIStyleManager and UIStyleManager.typography:
		stat_font_size = UIStyleManager.typography.get("size_body_small", 16)
	
	for label in labels:
		if label:
			label.add_theme_font_size_override("font_size", stat_font_size)
			label.custom_minimum_size = Vector2(80, 20)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.modulate = Color.WHITE

func _setup_card_style() -> void:
	"""Setup the main panel style"""
	# Check if we have a custom theme applied
	if applied_theme:
		_apply_theme_styles()
		return
	
	# Default style if no theme
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	style.set_corner_radius_all(8)
	
	add_theme_stylebox_override("panel", style)
	
	# Don't clip contents to allow animations
	clip_contents = false
	if margin_container:
		margin_container.clip_contents = false
	if vbox_container:
		vbox_container.clip_contents = false
	if middle_section:
		middle_section.clip_contents = false

func _setup_overlay_controls() -> void:
	"""Setup kick button and ready sign"""
	if kick_button:
		kick_button.pressed.connect(_on_kick_button_pressed)
		kick_button.visible = false
		kick_button.text = "✕"
		kick_button.add_theme_font_size_override("font_size", 16)
		kick_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		kick_button.size = Vector2(20, 20)
	
	if ready_sign:
		ready_sign.visible = false
		ready_sign.size = Vector2(24, 24)

# === DYNAMIC COMPONENT CREATION ===

func _create_profile_frame() -> void:
	"""Create ProfileFrame dynamically"""
	var frame_scene_path = "res://Pyramids/scenes/ui/components/ProfileFrame.tscn"
	if not ResourceLoader.exists(frame_scene_path):
		push_error("ProfileFrame.tscn not found at: " + frame_scene_path)
		var fallback = ColorRect.new()
		fallback.color = Color(0.3, 0.3, 0.3, 1.0)
		fallback.size = Vector2(60, 60)
		fallback.position = Vector2(10, 3)
		profile_container.add_child(fallback)
		return
	
	var frame_scene = load(frame_scene_path)
	profile_frame = frame_scene.instantiate()
	
	profile_frame.frame_size = 60
	profile_frame.show_level = true
	profile_frame.enable_animations = true
	
	profile_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	profile_frame.position = Vector2(10, 3)
	profile_frame.size = Vector2(60, 60)
	
	profile_container.add_child(profile_frame)
	profile_frame.frame_clicked.connect(_on_profile_frame_clicked)

func _create_display_cards() -> void:
	"""Create 3 UnifiedItemCard instances with MINI_DISPLAY preset"""
	if not display_container:
		return
	
	# Clear any existing children
	for child in display_container.get_children():
		child.queue_free()
	
	# Load UnifiedItemCard scene
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if not ResourceLoader.exists(card_scene_path):
		push_error("UnifiedItemCard scene not found")
		return
	
	var card_scene = load(card_scene_path)
	
	display_cards.clear()
	for i in range(3):
		var card = card_scene.instantiate()
		
		# Set size to 50x50 using MINI_DISPLAY preset
		card.custom_minimum_size = Vector2(50, 50)
		card.size = Vector2(50, 50)
		
		# Center the card in the container
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		card.name = "DisplayCard%d" % (i + 1)
		display_container.add_child(card)
		display_cards.append(card)
		
		# Connect click signal
		if card.has_signal("clicked"):
			card.clicked.connect(_on_display_item_clicked)

# === STATE MANAGEMENT ===
	# FOR set_player_data
	# TODO: Future Enhancement - ProfileUI Display Configuration
	# Allow players to select up to 3 items to display on their MiniProfileCard:
	# - Equipped cosmetics (card_back, card_front, board) 
	# - Achievement badges (first_win, combo_master, speed_demon, etc.)
	# - Special titles or unlocks
	# Players would configure this in ProfileUI and it would save to their profile
	# For now, we're hardcoding to show the 3 equipped cosmetic items
	
	# === TEMPORARY: Replace display_items with equipped items ===
	# Original achievement-based display items are commented out
	# if data.has("display_items"):
	#     # This would show achievements/badges selected by player
	#     pass

func set_player_data(data: Dictionary) -> void:
	"""Main entry point for updating card data"""
	player_data = data
	is_empty = data.get("is_empty", false)
	
	if not is_empty and StatsManager:
		# Get the current game mode from MultiplayerManager if available
		var current_mode = "classic"
		if has_node("/root/MultiplayerManager"):
			var mp_manager = get_node("/root/MultiplayerManager")
			current_mode = mp_manager.get_selected_mode()
		
		# Get stats for the current mode
		var mode_stats = StatsManager.get_multiplayer_stats(current_mode)
		
		# Calculate win rate as percentage
		var win_rate = 0.0
		if mode_stats.games > 0:
			win_rate = float(mode_stats.first_place) / float(mode_stats.games)
		
		# Override stats with real data from new structure
		player_data["stats"] = {
			"games": mode_stats.games,
			"win_rate": win_rate,
			"average_rank": mode_stats.average_rank
		}
	
	# NEW: Use showcased items if available, otherwise fall back to equipped
	var equipped = data.get("equipped", {})
	var showcase_items = equipped.get("mini_profile_card_showcased_items", [])
	
	# Check if showcase is actually populated (not empty strings)
	var has_showcase = false
	for item in showcase_items:
		if item != "":
			has_showcase = true
			break
	
	if has_showcase:
		# Use the showcase items directly
		player_data["display_items"] = showcase_items
		print("[MiniProfileCard] Using showcase items: ", showcase_items)
	else:
		# Fall back to equipped items (original behavior)
		var equipped_items = []
		
		if equipped.has("card_back") and equipped.card_back != "":
			equipped_items.append(equipped.card_back)
		else:
			equipped_items.append("")
			
		if equipped.has("card_front") and equipped.card_front != "":
			equipped_items.append(equipped.card_front)  
		else:
			equipped_items.append("")
			
		if equipped.has("board") and equipped.board != "":
			equipped_items.append(equipped.board)
		else:
			equipped_items.append("")
		
		player_data["display_items"] = equipped_items
		print("[MiniProfileCard] Using fallback equipped items: ", equipped_items)
	
	if is_empty:
		set_empty_state()
	else:
		set_occupied_state()

func set_empty_state() -> void:
	"""Configure for empty invite slot"""
	is_empty = true
	player_data = EMPTY_CARD_DATA.duplicate(true)
	
	_setup_empty_card_style()
	
	if name_label:
		name_label.text = "Invite Player"
		name_label.modulate = Color(0.5, 0.5, 0.5, 0.5)
		
		var invite_font_size = UIStyleManager.typography["size_body_small"] if UIStyleManager else 16
		
		name_label.add_theme_font_size_override("font_size", invite_font_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.offset_left = 0
		name_label.add_theme_constant_override("margin_left", 0)
	
	if profile_frame:
		profile_frame.visible = false
	
	_show_plus_symbol()
	
	if stats_panel:
		stats_panel.visible = false
	
	if bot_section:
		bot_section.visible = false
	
	if kick_button:
		kick_button.visible = false
	if ready_sign:
		ready_sign.visible = false
	# DEBUG: Print size
	await get_tree().process_frame
	print("[EMPTY] MiniProfileCard %d size: %s | Min size: %s" % [slot_index, size, custom_minimum_size])

func set_occupied_state() -> void:
	"""Configure for occupied player slot"""
	is_empty = false
	
	_setup_occupied_card_style()
	
	_hide_plus_symbol()
	
	if name_label:
		# Use SettingsSystem name if available, otherwise fall back to player_data
		var display_name = player_data.get("name", "Player")
		if SettingsSystem:
			display_name = SettingsSystem.player_name
		
		name_label.text = display_name
		name_label.modulate = Color.WHITE
		
		var name_font_size = UIStyleManager.typography["size_body_large"] if UIStyleManager else 20
		
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.offset_left = 10
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.visible = true
	
	if profile_frame:
		profile_frame.visible = true
		var level = player_data.get("level", 1)
		var prestige = player_data.get("prestige", 0)
		profile_frame.set_player_level(level, prestige)
		
		if profile_frame.has_method("set_frame_size"):
			profile_frame.set_frame_size(60)
		
		var frame_id = player_data.get("frame_id", "")
		if frame_id != "":
			profile_frame.set_custom_frame(frame_id)
	
	if stats_panel:
		stats_panel.visible = true
		stats_panel.modulate = Color.WHITE
	
	_update_stats_display()
	
	if bot_section:
		bot_section.visible = true
		_update_display_items()
	
	_update_overlay_controls()
	# DEBUG: Print size  
	await get_tree().process_frame
	print("[OCCUPIED] MiniProfileCard %d size: %s | Min size: %s" % [slot_index, size, custom_minimum_size])

func _setup_empty_card_style() -> void:
	"""Style for empty slots"""
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = Color(0.4, 0.4, 0.4, 0.5)
		style.bg_color = Color(0.1, 0.1, 0.1, 0.3)

func _setup_occupied_card_style() -> void:
	"""Style for occupied slots"""
	# Check if we have a custom theme applied
	if applied_theme:
		_apply_theme_styles()
		# REMOVED: Special handling for host (golden border)
		return
	
	# Default style if no theme
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = Color(0.4, 0.4, 0.4, 1.0)
		style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
		# REMOVED: Host border changes - keep consistent border for all
		style.set_border_width_all(1)  # Same for everyone

# === EMOJI DISPLAY ===

func show_emoji(emoji_id: String):
	"""Display emoji animation over card"""
	if not ItemManager:
		return
	
	var item = ItemManager.get_item(emoji_id)
	if not item:
		return
		
	var texture_path = item.texture_path
	if not texture_path or texture_path == "" or not ResourceLoader.exists(texture_path):
		return
	
	# Set the texture
	emoji_texture_rect.texture = load(texture_path)
	
	# Reset and show
	emoji_container.visible = true
	emoji_container.scale = Vector2.ZERO
	emoji_container.rotation = 0
	
	# Create animation
	var tween = create_tween()
	
	# Pop up
	tween.tween_property(emoji_container, "scale", Vector2(1.2, 1.2), 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(emoji_container, "scale", Vector2.ONE, 0.1)
	
	# Wiggle
	tween.tween_property(emoji_container, "rotation", deg_to_rad(5), 0.2)
	tween.tween_property(emoji_container, "rotation", deg_to_rad(-5), 0.2)
	tween.tween_property(emoji_container, "rotation", 0.0, 0.2)
	
	# Stay
	tween.tween_interval(1.7)
	
	# Shrink away
	tween.tween_property(emoji_container, "scale", Vector2.ZERO, 0.3)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	# Hide
	tween.tween_callback(func():
		emoji_container.visible = false
	)

# === UPDATE FUNCTIONS ===

func _update_stats_display() -> void:
	"""Update stats with emoji format - Win Rate, Games, Average Rank"""
	var stats = player_data.get("stats", {})
	
	var stat_font_size = 16
	if UIStyleManager and UIStyleManager.typography:
		stat_font_size = UIStyleManager.typography.get("size_body_small", 16)
	
	# Win Rate (keep as is)
	if win_rate_label:
		var win_rate = stats.get("win_rate", 0.0)
		win_rate_label.text = "🎯 %d%%" % int(win_rate * 100)
		win_rate_label.modulate = Color.WHITE
		win_rate_label.add_theme_color_override("font_color", Color.WHITE)
		win_rate_label.add_theme_font_size_override("font_size", stat_font_size)
		win_rate_label.visible = true
	
	# Games Played (keep as is)
	if games_label:
		var games = stats.get("games", 0)
		games_label.text = "🎮 %d" % games
		games_label.modulate = Color.WHITE
		games_label.add_theme_color_override("font_color", Color.WHITE)
		games_label.add_theme_font_size_override("font_size", stat_font_size)
		games_label.visible = true
	
	# Average Rank (replace MMR display)
	if mmr_label:  # Reusing mmr_label to show average rank
		var avg_rank = stats.get("average_rank", 0.0)
		if avg_rank > 0:
			mmr_label.text = "⭐ %.1f" % avg_rank
		else:
			mmr_label.text = "⭐ -"  # No games played yet
		mmr_label.modulate = Color.WHITE
		mmr_label.add_theme_color_override("font_color", Color.WHITE)
		mmr_label.add_theme_font_size_override("font_size", stat_font_size)
		mmr_label.visible = true

func _update_display_items() -> void:
	"""Update the 3 display item cards without recreating them"""
	var display_items = player_data.get("display_items", ["", "", ""])
	
	print("[MiniProfileCard] _update_display_items called")
	print("  - display_items: ", display_items)
	
	# DEBUG: Check container state
	if display_container:
		print("  - display_container class: ", display_container.get_class())
		print("  - display_container child count: ", display_container.get_child_count())
		print("  - display_container alignment: ", display_container.alignment)
		print("  - display_container separation: ", display_container.get_theme_constant("separation"))
	
	# Make sure we have cards
	if display_cards.size() == 0:
		_create_display_cards()
		await get_tree().process_frame
	
	# DEBUG: Check all cards before ANY updates
	print("[DEBUG] === BEFORE ANY UPDATES ===")
	for i in range(display_cards.size()):
		var card = display_cards[i]
		if card and is_instance_valid(card):
			print("  Card %d:" % i)
			print("    Parent: ", card.get_parent().name if card.get_parent() else "NO PARENT")
			print("    Parent class: ", card.get_parent().get_class() if card.get_parent() else "N/A")
			print("    Position: ", card.position)
			print("    Global Position: ", card.global_position)
			print("    Size: ", card.size)
			print("    Min size: ", card.custom_minimum_size)
	
	# Update existing cards
	for i in range(min(3, display_cards.size())):
		var card = display_cards[i]
		if not card or not is_instance_valid(card):
			continue
		
		# DEBUG: State BEFORE setup_with_preset
		print("[DEBUG] Card %d BEFORE setup_with_preset:" % i)
		print("  Parent: ", card.get_parent().name if card.get_parent() else "NO PARENT")
		print("  Position: ", card.position)
		print("  Anchors: L=%.2f T=%.2f R=%.2f B=%.2f" % [card.anchor_left, card.anchor_top, card.anchor_right, card.anchor_bottom])
		print("  Size flags H: ", card.size_flags_horizontal)
		print("  Size flags V: ", card.size_flags_vertical)
		print("  Size: ", card.size)
		print("  Min size: ", card.custom_minimum_size)
		
		if i >= display_items.size() or display_items[i] == "":
			card.visible = false
			continue
		
		var item_id = display_items[i]
		card.visible = true
		
		# Check if achievement
		var is_achievement = false
		if AchievementManager:
			for base_id in AchievementManager.get_all_base_achievements():
				if item_id == base_id:
					is_achievement = true
					break
		
		# THE PROBLEMATIC CALL
		if is_achievement:
			var fake_item = _create_achievement_item_data(item_id)
			if fake_item:
				card.setup_with_preset(fake_item, card.SizePreset.MINI_DISPLAY)
		else:
			var item_data = ItemManager.get_item(item_id) if ItemManager else null
			if item_data:
				card.setup_with_preset(item_data, card.SizePreset.MINI_DISPLAY)
		
		# DEBUG: State AFTER setup_with_preset
		print("[DEBUG] Card %d AFTER setup_with_preset:" % i)
		print("  Parent: ", card.get_parent().name if card.get_parent() else "NO PARENT")
		print("  Position: ", card.position)
		print("  Anchors: L=%.2f T=%.2f R=%.2f B=%.2f" % [card.anchor_left, card.anchor_top, card.anchor_right, card.anchor_bottom])
		print("  Size flags H: ", card.size_flags_horizontal)
		print("  Size flags V: ", card.size_flags_vertical)
		print("  Size: ", card.size)
		print("  Min size: ", card.custom_minimum_size)
	
	# DEBUG: Check all cards AFTER updates
	print("[DEBUG] === AFTER ALL UPDATES ===")
	for i in range(display_cards.size()):
		var card = display_cards[i]
		if card and is_instance_valid(card):
			print("  Card %d final state:" % i)
			print("    Parent: ", card.get_parent().name if card.get_parent() else "NO PARENT")
			print("    Position: ", card.position)
			print("    Global Position: ", card.global_position)
			print("    Visible: ", card.visible)
	
	# DEBUG: Force container to re-layout
	if display_container:
		display_container.queue_sort()
		print("[DEBUG] Called queue_sort on display_container")

func _create_achievement_item_data(achievement_id: String) -> UnifiedItemData:
	"""Create a fake UnifiedItemData for achievement display"""
	if not AchievementManager:
		return null
	
	var tier = AchievementManager.get_unlocked_tier(achievement_id)
	if tier <= 0:
		return null
	
	var fake_item = UnifiedItemData.new()
	fake_item.id = achievement_id
	fake_item.display_name = achievement_id.capitalize().replace("_", " ")
	
	# USE EMOJI CATEGORY - This makes it use icon display mode!
	fake_item.category = UnifiedItemData.Category.EMOJI
	
	# Store tier for color handling
	fake_item.set_meta("achievement_tier", tier)
	
	# Still set a basic rarity for compatibility
	fake_item.rarity = UnifiedItemData.Rarity.COMMON
	
	# Build icon path
	var icon_filename = "%s_ach_t%d.png" % [achievement_id, tier]
	var icon_path = "res://Pyramids/assets/icons/achievements/white_icons_cut/%s" % icon_filename
	
	if ResourceLoader.exists(icon_path):
		fake_item.texture_path = icon_path
		fake_item.icon_path = icon_path
		print("[MiniProfileCard] Found achievement icon at: %s" % icon_path)
	else:
		push_warning("[MiniProfileCard] Achievement icon not found: %s" % icon_path)
	
	return fake_item

func debug_check_display_cards() -> void:
	"""Debug function to check display cards state"""
	print("[MiniProfileCard] Debug check:")
	print("  - display_container: ", display_container)
	print("  - display_cards size: ", display_cards.size())
	print("  - display_container children: ", display_container.get_child_count() if display_container else 0)
	
	if display_container:
		for i in range(display_container.get_child_count()):
			var child = display_container.get_child(i)
			print("    Child ", i, ": ", child.name, " (", child.get_class(), ")")

func _update_overlay_controls() -> void:
	"""Update ready sign and kick button visibility"""
	
	# Ready sign stays top-left
	if ready_sign:
		ready_sign.set_position(Vector2(5, 5))
		ready_sign.visible = player_data.get("is_ready", false)
		if ready_sign.visible and not ready_sign.texture:
			_create_ready_checkmark()
	
	# Kick button OR host indicator (top-right)
	if player_data.get("is_host", false):
		# Hide kick button, show host indicator
		if kick_button:
			kick_button.visible = false
		_show_host_indicator()
	else:
		# Hide host indicator, potentially show kick button
		if host_indicator:
			host_indicator.visible = false  # HIDE THE HOST INDICATOR!
		
		if kick_button:
			kick_button.set_position(Vector2(size.x - 25, 5))
			var is_host_viewing = show_kick_button
			kick_button.visible = is_host_viewing and not is_empty

# === HELPER FUNCTIONS ===

func _show_host_indicator() -> void:
	"""Show host indicator in top-right corner"""
	if not host_indicator:
		# Use a Label instead of TextureRect
		var label = Label.new()
		label.name = "HostIndicator"
		label.text = "H"
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1.0, 0.84, 0, 1.0))  # Gold
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		
		# YOUR INSTRUCTIONS - SIZE FLAGS
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		
		label.size = Vector2(20, 20)
		add_child(label)
		host_indicator = label
	
	host_indicator.visible = true

func _show_plus_symbol() -> void:
	"""Show + symbol for empty state"""
	_hide_plus_symbol()
	
	plus_label = Label.new()
	plus_label.name = "PlusLabel"
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 32)
	plus_label.modulate = Color(0.5, 0.5, 0.5, 0.5)
	plus_label.set_anchors_preset(Control.PRESET_CENTER)
	plus_label.position = Vector2(-15, -20)
	plus_label.size = Vector2(30, 40)
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	profile_container.add_child(plus_label)

func _hide_plus_symbol() -> void:
	"""Remove plus symbol if it exists"""
	if plus_label and is_instance_valid(plus_label):
		plus_label.queue_free()
		plus_label = null
	
	for child in profile_container.get_children():
		if child.name == "PlusLabel":
			child.queue_free()

func _create_ready_checkmark() -> void:
	"""Create a simple checkmark texture"""
	var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	
	for x in range(24):
		for y in range(24):
			if (x >= 4 and x <= 8 and y >= 12 and y <= 16 - (x - 4)) or \
			   (x >= 8 and x <= 18 and y >= 16 - (x - 8) and y <= 18 - (x - 8)):
				image.set_pixel(x, y, Color(0.0, 1.0, 0.0, 1.0))
	
	var texture = ImageTexture.create_from_image(image)
	ready_sign.texture = texture

# === SIGNAL HANDLERS ===

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_empty:
				invite_clicked.emit(slot_index)
			else:
				var player_id = player_data.get("id", "")
				player_clicked.emit(player_id)

func _on_kick_button_pressed() -> void:
	var player_id = player_data.get("id", "")
	kick_requested.emit(player_id)

func _on_profile_frame_clicked() -> void:
	if not is_empty:
		var player_id = player_data.get("id", "")
		player_clicked.emit(player_id)

func _on_display_item_clicked(item_id: String, item_type: String) -> void:
	display_item_clicked.emit(item_id)

# === PUBLIC API ===

func set_ready(ready: bool) -> void:
	"""Set player ready state"""
	player_data["is_ready"] = ready
	_update_overlay_controls()

func set_host_viewing(is_host: bool) -> void:
	"""Set whether host is viewing (shows kick button)"""
	show_kick_button = is_host
	_update_overlay_controls()

func highlight() -> void:
	"""Highlight the card"""
	modulate = Color(1.2, 1.2, 1.2)

func unhighlight() -> void:
	"""Remove highlight"""
	modulate = Color.WHITE

# === PUBLIC API ===

func apply_mini_profile_theme(theme_id: String) -> void:
	"""Apply a mini profile card theme by ID"""
	if not theme_id or theme_id == "":
		applied_theme = null
		_setup_card_style()  # Reset to default
		return
	
	# Try to load the theme from ItemManager
	if ItemManager:
		var item = ItemManager.get_item(theme_id)
		if item and item.category == UnifiedItemData.Category.MINI_PROFILE_CARD:
			# Get the procedural instance
			if ProceduralItemRegistry:
				var instance = ProceduralItemRegistry.get_procedural_item(theme_id)
				if instance and instance is ProceduralMiniProfileCard:
					applied_theme = instance
					_apply_theme_styles()
				else:
					push_warning("Mini profile theme not found in registry: " + theme_id)
			else:
				push_warning("ProceduralItemRegistry not available")
		else:
			push_warning("Invalid mini profile theme ID: " + theme_id)

func _apply_theme_styles() -> void:
	"""Apply the current theme to all panels"""
	if not applied_theme:
		return
	
	# Apply to main panel
	var main_style = applied_theme.get_main_panel_style()
	if main_style:
		add_theme_stylebox_override("panel", main_style)
	
	# Apply to stats panel
	if stats_panel:
		var stats_style = applied_theme.get_stats_panel_style()
		if stats_style:
			stats_panel.add_theme_stylebox_override("panel", stats_style)
	
	# Apply to bottom section
	if bot_section:
		var bot_style = applied_theme.get_bot_section_style()
		if bot_style:
			bot_section.add_theme_stylebox_override("panel", bot_style)

# === DEBUG FUNCTIONS ===

func debug_populate_with_mock_data() -> void:
	"""Populate with test data"""
	var mock_data = {
		"id": "player_test",
		"name": "TestPlayer",
		"level": 42,
		"prestige": 8,
		"stats": {
			"games": 25,
			"win_rate": 0.32,  # 32% first place rate
			"average_rank": 2.4  # Average placement
		},
		"frame_id": "",
		"display_items": ["first_game", "", "combo_5"],
		"is_ready": false,
		"is_host": false,
		"is_empty": false
	}
	print("Setting mock player data...")
	set_player_data(mock_data)

func _test_card_states() -> void:
	"""Run through different card states for testing"""
	print("=== Testing MiniProfileCard States ===")
	
	print("Test 1: Empty card")
	set_empty_state()
	await get_tree().create_timer(2.0).timeout
	
	print("Test 2: Regular player")
	debug_populate_with_mock_data()
	await get_tree().create_timer(2.0).timeout
	
	print("Test 3: Ready state")
	set_ready(true)
	await get_tree().create_timer(2.0).timeout
	
	print("=== Test Complete ===")

func debug_check_nodes() -> void:
	"""Debug function to verify all nodes are found"""
	print("=== NODE CHECK ===")
	print("stats_panel exists: ", stats_panel != null)
	print("stats_vbox exists: ", stats_vbox != null)
	print("mmr_label exists: ", mmr_label != null)
	print("win_rate_label exists: ", win_rate_label != null)
	print("games_label exists: ", games_label != null)
	
	if stats_panel:
		print("stats_panel path: ", stats_panel.get_path())
		print("stats_panel visible: ", stats_panel.visible)
	
	if stats_vbox:
		print("stats_vbox children count: ", stats_vbox.get_child_count())
		for child in stats_vbox.get_children():
			print("  - Child: ", child.name, " type: ", child.get_class())
