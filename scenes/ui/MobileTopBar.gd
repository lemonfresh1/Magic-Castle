# MobileTopBar.gd - Fixed version that works with existing scene structure
extends Control

# === UI ELEMENTS ===
@onready var hbox_container: HBoxContainer = $HBoxContainer
@onready var left_info_container: HBoxContainer = $HBoxContainer/LeftInfo
@onready var slots_container: HBoxContainer = $HBoxContainer/SlotsContainer  
@onready var right_info_container: HBoxContainer = $HBoxContainer/RightInfo

# Left side elements
@onready var timer_label: Label = $HBoxContainer/LeftInfo/TimerLabel
@onready var combo_label: Label = $HBoxContainer/LeftInfo/ComboLabel
@onready var draw_counter_label: Label = $HBoxContainer/LeftInfo/DrawCounterLabel

# Right side elements  
@onready var current_score_label: Label = $HBoxContainer/RightInfo/CurrentScoreLabel
@onready var lobby_scores_container: VBoxContainer = $HBoxContainer/RightInfo/LobbyScores

# Card slot elements
var slot_cards: Array[Control] = []
var card_scene = preload("res://Magic-Castle/scenes/game/Card.tscn")

# === MOBILE DIMENSIONS ===
const MOBILE_CARD_WIDTH: int = 80
const MOBILE_CARD_HEIGHT: int = 110
const TOPBAR_HEIGHT: int = 140
const SLOT_SPACING: int = 10

func _ready() -> void:
	_setup_mobile_layout()
	_connect_signals()
	_initialize_slots()
	set_process(true)

func _setup_mobile_layout() -> void:
	# Set topbar size
	custom_minimum_size.y = TOPBAR_HEIGHT
	
	# Configure layout
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	
	# Set up the HBoxContainer to have fixed slot sizes
	if slots_container:
		# Set minimum size for slots container to ensure it doesn't shrink
		var total_slots_width = (MOBILE_CARD_WIDTH * 3) + (SLOT_SPACING * 2)
		slots_container.custom_minimum_size = Vector2(total_slots_width, MOBILE_CARD_HEIGHT)
		
		# Add spacers to keep slots centered
		hbox_container.add_theme_constant_override("separation", 10)
		
		# Make left and right containers have equal minimum width
		left_info_container.custom_minimum_size.x = 200
		right_info_container.custom_minimum_size.x = 200

func _connect_signals() -> void:
	SignalBus.combo_updated.connect(_on_combo_updated)
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.score_changed.connect(_on_score_changed)

func _initialize_slots() -> void:
	# Clear existing slots
	for child in slots_container.get_children():
		child.queue_free()
	
	slot_cards.clear()
	
	# Create 3 card slot placeholders with fixed sizes
	for i in range(3):
		var slot_container = Control.new()
		slot_container.custom_minimum_size = Vector2(MOBILE_CARD_WIDTH, MOBILE_CARD_HEIGHT)
		slot_container.size = Vector2(MOBILE_CARD_WIDTH, MOBILE_CARD_HEIGHT)
		slot_container.name = "Slot_%d" % (i + 1)
		slots_container.add_child(slot_container)
		slot_cards.append(null)
		
		# Add background
		var background = ColorRect.new()
		background.color = Color(0.2, 0.2, 0.2, 0.3)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.z_index = -10
		slot_container.add_child(background)
		
		# Add spacing between slots (except after last slot)
		if i < 2:
			var spacer = Control.new()
			spacer.custom_minimum_size.x = SLOT_SPACING
			slots_container.add_child(spacer)

func _process(_delta: float) -> void:
	if GameState.is_round_active:
		_update_timer_display()
		_update_draw_counter()

func _update_timer_display() -> void:
	var time_left = int(GameState.time_remaining)
	timer_label.text = "⏱ %d" % time_left
	
	if time_left < 10:
		timer_label.modulate = Color.RED
	elif time_left < 30:
		timer_label.modulate = Color.YELLOW
	else:
		timer_label.modulate = Color.WHITE

func _update_draw_counter() -> void:
	if CardManager:
		var draw_limit = GameConstants.get_draw_pile_limit(GameState.current_round)
		var cards_already_drawn = CardManager.cards_drawn
		var pile_size = CardManager.draw_pile.size()
		
		var draws_remaining = min(pile_size, draw_limit - cards_already_drawn)
		draws_remaining = max(0, draws_remaining)
		
		draw_counter_label.text = "🃏 %d" % draws_remaining

func update_slots() -> void:
	print("=== UPDATE SLOTS CALLED ===")
	print("Active slots: %d" % CardManager.active_slots)
	print("Slot cards: %s" % [
		CardManager.slot_cards[0].get_display_value() if CardManager.slot_cards[0] else "null",
		CardManager.slot_cards[1].get_display_value() if CardManager.slot_cards[1] else "null", 
		CardManager.slot_cards[2].get_display_value() if CardManager.slot_cards[2] else "null"
	])
	
	# Update all 3 slots based on CardManager state
	var slot_index = 0
	for i in range(slots_container.get_child_count()):
		var child = slots_container.get_child(i)
		
		# Skip spacers
		if not child.name.begins_with("Slot_"):
			continue
			
		# Clear existing card
		if slot_index < slot_cards.size() and slot_cards[slot_index]:
			slot_cards[slot_index].queue_free()
			slot_cards[slot_index] = null
		
		var background = child.get_child(0) if child.get_child_count() > 0 else null
		
		# Show the current card if this slot has one
		if slot_index < CardManager.active_slots and CardManager.slot_cards[slot_index] != null:
			print("Showing card in slot %d: %s" % [slot_index, CardManager.slot_cards[slot_index].get_display_value()])
			
			var card = card_scene.instantiate()
			child.add_child(card)
			card.setup(CardManager.slot_cards[slot_index], -1)
			
			card.position = Vector2.ZERO
			card.size = Vector2(MOBILE_CARD_WIDTH, MOBILE_CARD_HEIGHT)
			
			card.set_selectable(false)
			card.z_index = 25
			
			if slot_index < slot_cards.size():
				slot_cards[slot_index] = card
			
			# Show slot and background
			child.modulate = Color.WHITE
			if background:
				background.visible = true
		else:
			# Show empty background for active but empty slots
			if slot_index < CardManager.active_slots:
				if background:
					background.visible = true
				child.modulate = Color(0.7, 0.7, 0.7, 0.7)
			else:
				# Hide completely for inactive slots
				if background:
					background.visible = false
				child.modulate = Color(0.5, 0.5, 0.5, 0.3)
		
		slot_index += 1

# === SIGNAL HANDLERS ===
func _on_combo_updated(combo: int) -> void:
	combo_label.text = "⚡ %d" % combo
	
	if combo > 0:
		combo_label.modulate = Color.YELLOW
		var tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.1)
	else:
		combo_label.modulate = Color.WHITE

func _on_round_started(_round: int) -> void:
	combo_label.text = "⚡ 0"
	combo_label.modulate = Color.WHITE
	current_score_label.text = "💰 0"
	
	call_deferred("update_slots")

func _on_score_changed(_points: int, _reason: String) -> void:
	current_score_label.text = "💰 %d" % GameState.current_score
	
	var tween = create_tween()
	tween.tween_property(current_score_label, "modulate", Color.GREEN, 0.1)
	tween.tween_property(current_score_label, "modulate", Color.WHITE, 0.2)

# === MULTIPLAYER LOBBY SCORES (Foundation) ===
func update_lobby_scores(scores: Array[Dictionary]) -> void:
	# Clear existing scores
	for child in lobby_scores_container.get_children():
		child.queue_free()
	
	# Show top 3 scores (including player if in top 3)
	var top_scores = scores.slice(0, 3)
	
	for i in range(top_scores.size()):
		var score_data = top_scores[i]
		var score_label = Label.new()
		score_label.text = "%d. %s: %d" % [i + 1, score_data.get("name", "Player"), score_data.get("score", 0)]
		score_label.add_theme_font_size_override("font_size", SettingsSystem.get_scaled_font_size(12))
		
		# Highlight current player
		if score_data.get("is_current_player", false):
			score_label.modulate = Color.CYAN
		
		lobby_scores_container.add_child(score_label)
