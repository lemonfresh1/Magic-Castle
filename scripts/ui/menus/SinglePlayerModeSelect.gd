# SinglePlayerModeSelect.gd - Full carousel version with proper margins
# Location: res://Pyramids/scripts/ui/menus/SinglePlayerModeSelect.gd
# Last Updated: Complete update with margins and score saving [Date]

extends Control

# Scene references
@onready var back_button: Button = $TopSection/BackButton
@onready var highscores_panel: PanelContainer = $TopSection/HighscoresPanel
@onready var current_rank_label: Label = $TopSection/HighscoresPanel/VBox/CurrentRankLabel
@onready var top_scores_container: VBoxContainer = $TopSection/HighscoresPanel/VBox/TopScoresContainer
@onready var bottom_section: Control = $BottomSection
@onready var card_container: Control = $BottomSection/CardContainer

# Game modes data with unique highscores per mode
var single_player_modes = []

# Carousel variables
var cards: Array = []
var current_mode_index: int = 0
var is_dragging: bool = false
var drag_start_x: float = 0.0
var drag_accumulated: float = 0.0
var carousel_center: Vector2
var carousel_radius: float = 250.0

func _ready():
	# Add gradient background first
	_setup_menu_background()
	
	# Rest of ready code
	_setup_ui()
	_connect_signals()
	_apply_styles()
	_load_modes_from_manager()
	_create_carousel_cards()
	
	# Connect to tree_entered to reload scores when returning to menu
	if not tree_entered.is_connected(_on_tree_entered):
		tree_entered.connect(_on_tree_entered)
	
	# Load scores
	_load_all_mode_scores()
	
	await get_tree().process_frame
	_update_carousel_positions()
	_update_card_visibility(cards[0], true) if cards.size() > 0 else null
	_select_mode(0)

func _on_tree_entered():
	"""Called every time we enter the scene tree (including returns from game)"""
	print("=== ENTERING SINGLE PLAYER MODE SELECT ===")
	# Force reload all scores when entering the scene
	if StatsManager:
		print("StatsManager available, reloading scores...")
		_reload_all_scores()

func _reload_all_scores():
	"""Force reload all scores and update UI"""
	if not StatsManager:
		print("No StatsManager available")
		return
		
	print("Reloading scores for all modes...")
	
	# Update mode data
	for mode in single_player_modes:
		var old_score = mode.best_score
		mode.best_score = StatsManager.get_best_score(mode.id)
		if old_score != mode.best_score:
			print("Mode %s score changed: %d -> %d" % [mode.id, old_score, mode.best_score])
	
	# Update all card displays
	for i in range(cards.size()):
		if i >= single_player_modes.size():
			continue
			
		var card = cards[i]
		var mode = single_player_modes[i]
		var vbox = card.get_node_or_null("VBox")
		
		if vbox:
			var score_label = vbox.get_node_or_null("BestScore")
			if score_label:
				var new_text = "Best: %d" % mode.best_score if mode.best_score > 0 else "New!"
				print("Updating card %d (%s) score label: %s -> %s" % [i, mode.id, score_label.text, new_text])
				score_label.text = new_text
	
	# Refresh the highscores panel for current mode
	if current_mode_index < single_player_modes.size():
		_load_mode_highscores(single_player_modes[current_mode_index])

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			print("SinglePlayerModeSelect became visible")
			_reload_all_scores()

func _load_all_mode_scores():
	"""Load best scores for all modes from StatsManager"""
	print("Loading scores from StatsManager...")
	for mode in single_player_modes:
		if StatsManager:
			var old_score = mode.best_score
			mode.best_score = StatsManager.get_best_score(mode.id)
			print("Mode %s: old score = %d, new score = %d" % [mode.id, old_score, mode.best_score])
			
			# Update the card's score label if it exists
			for i in range(cards.size()):
				if i < single_player_modes.size() and single_player_modes[i].id == mode.id:
					var card = cards[i]
					var vbox = card.get_node_or_null("VBox")
					if vbox:
						var score_label = vbox.get_node_or_null("BestScore")
						if score_label:
							score_label.text = "Best: %d" % mode.best_score if mode.best_score > 0 else "New!"
							print("Updated card %d score label to: %s" % [i, score_label.text])

func _setup_menu_background() -> void:
	# Use existing Background node if it exists
	var bg_rect = get_node_or_null("Background")
	if not bg_rect:
		bg_rect = ColorRect.new()
		bg_rect.name = "Background"
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg_rect)
		move_child(bg_rect, 0)
	
	# Create gradient texture
	var gradient = Gradient.new()
	var gradient_texture = GradientTexture2D.new()
	
	# Set gradient colors - dark forest green to lighter sage green
	gradient.add_point(0.0, Color(0.1, 0.25, 0.15))  # Dark forest green
	gradient.add_point(1.0, Color(0.25, 0.45, 0.3))  # Lighter sage green
	
	# Apply gradient vertically
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)
	
	# Apply to background
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform sampler2D gradient_texture;
	
	void fragment() {
		vec4 gradient_color = texture(gradient_texture, vec2(0.5, UV.y));
		COLOR = gradient_color;
	}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("gradient_texture", gradient_texture)
	
	bg_rect.material = material
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_ui():
	var screen_size = get_viewport().get_visible_rect().size
	
	# Set up 60/40 split with margins
	if has_node("TopSection"):
		var top_section = $TopSection
		# Add margins from screen edges
		top_section.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		top_section.offset_top = UIStyleManager.spacing.space_3  # 12px from top
		top_section.offset_left = UIStyleManager.spacing.space_2  # 8px from left
		top_section.offset_right = -UIStyleManager.spacing.space_2  # 8px from right
		top_section.custom_minimum_size.y = (screen_size.y * 0.4) - UIStyleManager.spacing.space_3
		top_section.size.y = (screen_size.y * 0.4) - UIStyleManager.spacing.space_3
		
		# Make sure TopSection is visible
		top_section.visible = true
		top_section.modulate = Color.WHITE
	
	if has_node("BottomSection"):
		$BottomSection.custom_minimum_size.y = screen_size.y * 0.4
		$BottomSection.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		$BottomSection.anchor_top = 0.6
		$BottomSection.offset_top = 0
		$BottomSection.offset_left = UIStyleManager.spacing.space_2  # 8px from left
		$BottomSection.offset_right = -UIStyleManager.spacing.space_2  # 8px from right
		
		# Calculate carousel center
		carousel_center = Vector2(screen_size.x / 2, $BottomSection.size.y / 2)

func _apply_styles():
	# Position BackButton with proper offset (20,20)
	if back_button:
		back_button.visible = true
		UIStyleManager.apply_button_style(back_button, "primary", "small")
		back_button.text = "Menu"
		
		# Position at 20,20 from top-left
		back_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		back_button.position = Vector2(UIStyleManager.spacing.space_5, UIStyleManager.spacing.space_5)  # 20,20
		
	# Center the HighscoresPanel with proper margins
	if highscores_panel:
		highscores_panel.visible = true
		
		# Set anchors to center it
		highscores_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		highscores_panel.anchor_left = 0.5
		highscores_panel.anchor_right = 0.5
		highscores_panel.anchor_top = 0.35  # Adjusted to not overlap with back button
		highscores_panel.anchor_bottom = 0.85
		
		# Set size
		var panel_width = min(300, get_viewport().get_visible_rect().size.x - (UIStyleManager.spacing.space_8 * 2))  # With margins
		highscores_panel.custom_minimum_size = Vector2(panel_width, 200)
		highscores_panel.offset_left = -panel_width / 2
		highscores_panel.offset_right = panel_width / 2
		highscores_panel.offset_top = 0
		highscores_panel.offset_bottom = 0
		
		# Apply panel style with proper internal padding
		UIStyleManager.apply_panel_style(highscores_panel, "highscores")
		
		# Add internal padding to the panel content
		var vbox = highscores_panel.get_node_or_null("VBox")
		if vbox and vbox is VBoxContainer:
			# Create a margin container if it doesn't exist
			var margin_cont = vbox.get_parent()
			if not margin_cont is MarginContainer:
				var new_margin = MarginContainer.new()
				new_margin.name = "MarginContainer"
				highscores_panel.add_child(new_margin)
				highscores_panel.remove_child(vbox)
				new_margin.add_child(vbox)
				margin_cont = new_margin
			
			# Set internal margins
			margin_cont.add_theme_constant_override("margin_left", UIStyleManager.spacing.space_4)  # 16px
			margin_cont.add_theme_constant_override("margin_right", UIStyleManager.spacing.space_4)
			margin_cont.add_theme_constant_override("margin_top", UIStyleManager.spacing.space_4)
			margin_cont.add_theme_constant_override("margin_bottom", UIStyleManager.spacing.space_4)
	
	if current_rank_label:
		current_rank_label.visible = true
		UIStyleManager.apply_label_style(current_rank_label, "title")

func _connect_signals():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _load_modes_from_manager():
	"""Load game modes dynamically from GameModeManager"""
	single_player_modes.clear()
	
	# UI-specific data that doesn't belong in GameModeManager
	var mode_ui_config = {
		"test": {
			"color": "success",
			"difficulty": 1,
			"description": "Development testing mode with adjustable settings."
		},
		"classic": {
			"color": "primary",
			"difficulty": 2,
			"description": "Traditional pyramid solitaire. Clear all cards to win."
		},
		"timed_rush": {
			"color": "error",
			"difficulty": 3,
			"description": "Race against the clock! Beat the timer to win."
		},
		"zen": {
			"color": "info",
			"difficulty": 1,
			"description": "No timer, unlimited undos. Perfect your strategy."
		},
		"daily_challenge": {
			"color": "warning",
			"difficulty": 4,
			"description": "New puzzle every day. Compete globally!"
		},
		"puzzle_master": {
			"color": "premium",
			"difficulty": 5,
			"description": "Handcrafted puzzles with unique solutions."
		}
	}
	
	# Get modes from GameModeManager
	var available = GameModeManager.available_modes
	for mode_id in available:
		var mode_config = available[mode_id]
		var ui_data = mode_ui_config.get(mode_id, {
			"color": "primary",
			"difficulty": 1,
			"description": "Game mode: " + mode_id
		})
		
		single_player_modes.append({
			"id": mode_id,
			"title": mode_config.get("display_name", mode_id),
			"description": ui_data.description,
			"difficulty": ui_data.difficulty,
			"best_score": 0,
			"locked": not GameModeManager.is_mode_unlocked(mode_id),
			"color": ui_data.color,
			"time_limit": mode_config.get("base_timer", 0),
			"special_rules": _get_special_rules(mode_config)
		})
	
	# Sort modes by difficulty (optional)
	single_player_modes.sort_custom(func(a, b): return a.difficulty < b.difficulty)

func _get_special_rules(mode_config: Dictionary) -> Array:
	"""Extract special rules from mode config"""
	var rules = []
	
	if mode_config.get("timer_enabled", false):
		rules.append("timer")
	if mode_config.get("undo_enabled", false):
		if mode_config.get("undo_penalty", 0) == 0:
			rules.append("unlimited_undo")
			rules.append("no_score_penalty")
	if mode_config.get("base_draw_limit", 24) == 0:
		rules.append("no_draw_pile")
	if mode_config.get("max_rounds", 10) == 1:
		rules.append("single_puzzle")
	
	return rules

func _create_carousel_cards():
	"""Create cards and position them in carousel"""
	# Clear existing cards
	for card in cards:
		card.queue_free()
	cards.clear()
	
	# Create new cards
	for i in range(single_player_modes.size()):
		var card = _create_carousel_card(single_player_modes[i], i)
		card_container.add_child(card)
		cards.append(card)
	
	# Initial positioning
	_update_carousel_positions()

func _create_carousel_card(mode_data: Dictionary, index: int) -> PanelContainer:
	"""Create a card for the carousel"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 250)
	card.size = Vector2(180, 250)
	card.set_meta("index", index)
	card.set_meta("mode_data", mode_data)
	
	# CRITICAL: Remove ALL default theming first
	card.theme = Theme.new()
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	# Enable clipping for the entire card (including children)
	card.clip_contents = true
	
	# MarginContainer that FILLS the card
	var margin_container = MarginContainer.new()
	margin_container.name = "MarginContainer"
	# CRITICAL: Make it fill the entire card
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Set the margins - push content down and add side padding
	margin_container.add_theme_constant_override("margin_left", 10)    # Side padding
	margin_container.add_theme_constant_override("margin_right", 10)   # Side padding
	margin_container.add_theme_constant_override("margin_top", 8)      # Push down by 8px
	margin_container.add_theme_constant_override("margin_bottom", 10)  # Bottom padding
	
	card.add_child(margin_container)
	
	# Main container goes INSIDE the margin container
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(vbox)  # Add to margin_container, not card!
	
	# Title (always at top, always visible)
	var title = Label.new()
	title.name = "Title"
	title.text = mode_data.title
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 30
	vbox.add_child(title)
	
	# Difficulty stars
	var diff_container = HBoxContainer.new()
	diff_container.name = "Difficulty"
	diff_container.alignment = BoxContainer.ALIGNMENT_CENTER
	for j in range(5):
		var star = Label.new()
		star.text = "★" if j < mode_data.difficulty else "☆"
		star.add_theme_font_size_override("font_size", 16)
		if j < mode_data.difficulty:
			star.add_theme_color_override("font_color", Color("#FFB300"))
		else:
			star.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		diff_container.add_child(star)
	vbox.add_child(diff_container)
	
	# Description
	var desc = Label.new()
	desc.name = "Description"
	desc.text = mode_data.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.visible = false
	vbox.add_child(desc)
	
	# Best score - refresh from StatsManager
	var score_label = Label.new()
	score_label.name = "BestScore"
	if StatsManager:
		mode_data.best_score = StatsManager.get_best_score(mode_data.id)
	score_label.text = "Best: %d" % mode_data.best_score if mode_data.best_score > 0 else "New!"
	score_label.add_theme_font_size_override("font_size", 16)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.visible = false
	vbox.add_child(score_label)
	
	# Play button
	var play_btn = Button.new()
	play_btn.name = "PlayButton"
	play_btn.text = "PLAY"
	play_btn.visible = false
	play_btn.custom_minimum_size.y = 40
	play_btn.pressed.connect(func(): _start_game_mode(index))
	vbox.add_child(play_btn)
	
	# Apply card style AFTER removing defaults
	_style_carousel_card(card, mode_data, false)
	
	# Lock overlay if needed - FIXED VERSION
	if mode_data.locked:
		# Create a container that respects rounded corners
		var overlay_container = Control.new()
		overlay_container.name = "LockOverlay"
		overlay_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(overlay_container)
		
		# Dark overlay that respects clip_contents
		var overlay = Panel.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Style the overlay with same corner radius as card
		var overlay_style = StyleBoxFlat.new()
		overlay_style.bg_color = Color(0, 0, 0, 0.7)
		overlay_style.set_corner_radius_all(16)  # Same as card
		overlay.add_theme_stylebox_override("panel", overlay_style)
		overlay_container.add_child(overlay)
		
		# Lock icon - properly centered
		var lock_label = Label.new()
		lock_label.text = "🔒"
		lock_label.add_theme_font_size_override("font_size", 48)
		lock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock_label.position = Vector2(-20, -24)  # Fine-tune centering for emoji
		overlay_container.add_child(lock_label)
	
	# Input handling
	card.gui_input.connect(func(event): _on_card_input(event, index))
	
	return card

func _style_carousel_card(card: PanelContainer, mode_data: Dictionary, is_selected: bool):
	"""Apply styling to carousel card"""
	# Create fresh style
	var style = StyleBoxFlat.new()
	
	var color_key = mode_data.get("color", "primary")
	
	# Special handling for test mode
	if mode_data.get("id") == "test":
		style.bg_color = UIStyleManager.get_color("success") if UIStyleManager else Color(0.3, 0.8, 0.3)
	else:
		style.bg_color = UIStyleManager.get_color(color_key) if UIStyleManager else Color.WHITE
	
	style.border_color = style.bg_color.darkened(0.2)
	style.set_border_width_all(3 if is_selected else 2)
	style.set_corner_radius_all(16)  # Consistent corner radius
	
	# Force complete override
	card.remove_theme_stylebox_override("panel")
	card.add_theme_stylebox_override("panel", style)

func _update_carousel_positions():
	"""Apply calculated positions immediately (for initial setup only)"""
	var states = _calculate_carousel_positions()
	
	for i in range(cards.size()):
		var card = cards[i]
		var state = states[i]
		
		if state.has("visible") and not state.visible:
			card.visible = false
			continue
		
		card.visible = true
		card.position = state.position
		card.scale = state.scale
		card.z_index = state.z_index
		card.modulate.a = state.modulate_a
		
		# Update visibility
		_update_card_visibility(card, i == current_mode_index)

func _update_card_visibility(card: PanelContainer, is_selected: bool):
	"""Update which elements of the card are visible"""
	# VBox is now inside MarginContainer
	var margin_container = card.get_node_or_null("MarginContainer")
	if not margin_container:
		return
		
	var vbox = margin_container.get_node_or_null("VBox")
	if not vbox:
		return
	
	# Rest of the function stays the same...
	var title = vbox.get_node_or_null("Title")
	var desc = vbox.get_node_or_null("Description")
	var btn = vbox.get_node_or_null("PlayButton")
	var diff = vbox.get_node_or_null("Difficulty")
	var score = vbox.get_node_or_null("BestScore")
	
	if is_selected:
		# Selected card shows everything
		if title: 
			title.visible = true
			title.modulate.a = 1.0
		if desc: 
			desc.visible = true
			desc.modulate.a = 1.0
		if btn: 
			btn.visible = true
			btn.modulate.a = 1.0
		if diff: 
			diff.visible = true
			diff.modulate.a = 1.0
		if score: 
			score.visible = true
			score.modulate.a = 1.0
			# Refresh score when card becomes selected
			var mode_data = card.get_meta("mode_data")
			if StatsManager and mode_data:
				var best = StatsManager.get_best_score(mode_data.id)
				score.text = "Best: %d" % best if best > 0 else "New!"
	else:
		# Non-selected cards only show title
		if title: 
			title.visible = true
			title.modulate.a = 1.0
		if desc: 
			desc.visible = false
		if btn: 
			btn.visible = false
		if diff: 
			diff.visible = false
		if score: 
			score.visible = false

func _select_mode(index: int):
	"""Select a mode and update UI"""
	if index < 0 or index >= single_player_modes.size():
		return
	
	var old_mode_index = current_mode_index
	current_mode_index = index
	
	# Store current positions and scales BEFORE any changes
	var card_states = []
	for i in range(cards.size()):
		var card = cards[i]
		card_states.append({
			"position": card.position,
			"scale": card.scale,
			"z_index": card.z_index,
			"modulate_a": card.modulate.a
		})
	
	# Calculate new positions WITHOUT applying them yet
	var new_states = _calculate_carousel_positions()
	
	# Animate the transition
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate each card
	for i in range(cards.size()):
		var card = cards[i]
		var new_state = new_states[i]
		
		# Animate properties
		tween.tween_property(card, "position", new_state.position, 0.3)
		tween.tween_property(card, "scale", new_state.scale, 0.3)
		tween.tween_property(card, "z_index", new_state.z_index, 0.3)
		tween.tween_property(card, "modulate:a", new_state.modulate_a, 0.3)
		
		# Update card style
		_style_carousel_card(card, single_player_modes[i], i == current_mode_index)
		
		# Update visibility AFTER animation
		tween.tween_callback(_update_card_visibility.bind(card, i == current_mode_index))
	
	# Load highscores after animation
	await tween.finished
	_load_mode_highscores(single_player_modes[index])

func _calculate_carousel_positions() -> Array:
	"""Calculate positions without applying them"""
	var card_count = cards.size()
	var states = []
	
	if card_count == 0:
		return states
	
	# Calculate how many cards to show on each side
	var total_side_cards = card_count - 1
	var cards_left = int(ceil(total_side_cards / 2.0))
	var cards_right = int(floor(total_side_cards / 2.0))
	
	# Build the visible card indices
	var visible_positions = []
	
	# Add left side cards
	for i in range(cards_left, 0, -1):
		var card_index = (current_mode_index - i + card_count) % card_count
		visible_positions.append(card_index)
	
	# Add selected card
	visible_positions.append(current_mode_index)
	
	# Add right side cards
	for i in range(1, cards_right + 1):
		var card_index = (current_mode_index + i) % card_count
		visible_positions.append(card_index)
	
	# Card dimensions
	var base_card_width = 180  # Full size card width
	var small_scale = 0.7
	var card_gap = 15  # Gap between cards
	
	# ALWAYS center the selected card at carousel_center.x
	var selected_x = carousel_center.x
	
	# Calculate position for each card
	for i in range(card_count):
		var state = {}
		
		# Find position in visible array
		var position_index = visible_positions.find(i)
		if position_index == -1:
			state = {
				"visible": false,
				"position": cards[i].position,
				"scale": cards[i].scale,
				"z_index": 0,
				"modulate_a": 0
			}
		else:
			state["visible"] = true
			
			# Calculate position offset from center
			var position_offset = position_index - cards_left
			
			# Calculate X position relative to selected card
			var x: float
			if position_offset == 0:
				# This is the selected card - always centered
				x = selected_x
			elif position_offset < 0:
				# Left side cards
				x = selected_x - (base_card_width / 2.0)  # Start from left edge of selected
				x -= card_gap  # Add gap
				# Add small card widths for each card to the left
				for j in range(abs(position_offset)):
					if j > 0:
						x -= card_gap
					x -= base_card_width * small_scale
				x += (base_card_width * small_scale) / 2.0  # Center the card
			else:
				# Right side cards
				x = selected_x + (base_card_width / 2.0)  # Start from right edge of selected
				x += card_gap  # Add gap
				# Add small card widths for each card to the right
				for j in range(position_offset - 1):
					x += base_card_width * small_scale + card_gap
				x += (base_card_width * small_scale) / 2.0  # Center the card
			
			# Y position and scale based on selection
			if position_offset == 0:
				# Selected card
				state["position"] = Vector2(x - base_card_width / 2, carousel_center.y - cards[i].size.y / 2)
				state["scale"] = Vector2.ONE
				state["z_index"] = 20
				state["modulate_a"] = 1.0
			else:
				# Non-selected cards - pushed down more
				var y = carousel_center.y + 120  # Increased from previous value
				state["position"] = Vector2(x - (base_card_width * small_scale) / 2, y - cards[i].size.y / 2)
				state["scale"] = Vector2(small_scale, small_scale)
				state["z_index"] = 10 - abs(position_offset)
				state["modulate_a"] = 0.9
		
		states.append(state)
	
	return states

func _load_mode_highscores(mode: Dictionary):
	"""Load and display highscores for selected mode"""
	if not current_rank_label or not top_scores_container:
		return
	
	# Update current rank
	if StatsManager:
		var rank = StatsManager.get_player_rank(mode.id)
		var best = StatsManager.get_best_score(mode.id)
		current_rank_label.text = "Your Rank: #%d (Best: %d)" % [rank, best]
	else:
		current_rank_label.text = "Your Rank: ---"
	
	# Clear old scores
	for child in top_scores_container.get_children():
		child.queue_free()
	
	# Get top 5 scores for this mode
	var top_scores = []
	if StatsManager:
		top_scores = StatsManager.get_top_scores(mode.id, 5)
	
	# Display scores
	if top_scores.is_empty():
		var no_scores = Label.new()
		no_scores.text = "No scores yet!"
		no_scores.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		top_scores_container.add_child(no_scores)
	else:
		for i in range(top_scores.size()):
			var score_entry = top_scores[i]
			var score_label = Label.new()
			score_label.text = "%d. %s - %d" % [i + 1, score_entry.player_name, score_entry.score]
			
			# Highlight player's score
			if score_entry.is_current_player:
				score_label.add_theme_color_override("font_color", UIStyleManager.get_color("primary"))
			
			top_scores_container.add_child(score_label)

func _input(event: InputEvent):
	"""Handle swipe/drag for carousel"""
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			is_dragging = true
			drag_start_x = event.position.x
			drag_accumulated = 0.0
		else:
			if is_dragging:
				is_dragging = false
				# Check if we should change cards based on drag distance
				if abs(drag_accumulated) > 50:  # 50px threshold
					if drag_accumulated > 0:
						# Swiped right - go to previous card (with wrapping)
						var new_index = (current_mode_index - 1 + cards.size()) % cards.size()
						_select_mode(new_index)
					else:
						# Swiped left - go to next card (with wrapping)
						var new_index = (current_mode_index + 1) % cards.size()
						_select_mode(new_index)
	
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and is_dragging:
		var delta = event.position.x - drag_start_x
		drag_accumulated = delta

func _on_card_input(event: InputEvent, index: int):
	"""Handle card interaction"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if index == current_mode_index:
				# Play if it's the selected card
				if not single_player_modes[index].locked:
					_start_game_mode(index)
			else:
				# Select the clicked card
				_select_mode(index)

func _unhandled_input(event: InputEvent):
	"""Keyboard navigation for testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				var new_index = (current_mode_index - 1 + cards.size()) % cards.size()
				_select_mode(new_index)
			KEY_RIGHT:
				var new_index = (current_mode_index + 1) % cards.size()
				_select_mode(new_index)
			KEY_ENTER, KEY_SPACE:
				if not single_player_modes[current_mode_index].locked:
					_start_game_mode(current_mode_index)
			KEY_T:  # Test key - add a fake score
				if StatsManager and current_mode_index < single_player_modes.size():
					var test_score = randi() % 1000 + 500
					var mode_id = single_player_modes[current_mode_index].id
					print("TEST: Adding score %d to mode %s" % [test_score, mode_id])
					StatsManager.save_score(mode_id, test_score)
					StatsManager.save_stats()
					_reload_all_scores()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")

func _start_game_mode(index: int):
	"""Start the selected game mode"""
	var mode = single_player_modes[index]
	
	print("Starting game mode: ", mode.id)
	
	# Remove this line - GameModeManager already tracks it!
	# GameState.current_game_mode = mode.id  <-- DELETE THIS LINE
	
	# Configure GameModeManager (this already stores the current mode)
	GameModeManager.set_game_mode(mode.id, {
		"time_limit": mode.time_limit,
		"special_rules": mode.special_rules,
		"difficulty": mode.difficulty
	})
	
	# DON'T connect signal here - we'll be destroyed when scene changes!
	# Instead, let PostGameSummary handle the score saving
	
	# Change to game board
	get_tree().change_scene_to_file("res://Pyramids/scenes/game/MobileGameBoard.tscn")

func _on_game_ended(final_score: int):
	"""Save score when game ends"""
	var mode_id = get_meta("current_mode_id", "")
	print("Game ended! Mode: %s, Score: %d" % [mode_id, final_score])
	
	if StatsManager and mode_id != "":
		StatsManager.save_score(mode_id, final_score)
		print("Score saved to StatsManager")
	else:
		print("Failed to save score - StatsManager: %s, mode_id: %s" % [StatsManager != null, mode_id])
