# CardManager.gd - Central card and deck management system for Magic Castle Solitaire
# Path: res://Pyramids/scripts/autoloads/CardManager.gd
# Last Updated: Enhanced documentation, added debug system, reorganized functions
#
# Purpose: Manages all card-related operations including deck creation, shuffling with
# deterministic seeds, dealing to board/draw pile, card selection validation, slot management,
# combo tracking, and move validation. Acts as the central authority for card state and
# enforces game rules for valid card sequences and slot unlocking.
#
# Dependencies:
# - GameState (autoload) - Round state, seed management, game flow control
# - GameConstants (autoload) - Card counts, board size, game rules
# - GameModeManager (autoload) - Mode-specific rules, slot unlocking, draw limits
# - SignalBus (autoload) - Event broadcasting for card selection, combos, draws
# - StatsManager (autoload) - Tracking card clicks, draws, combos for stats
# - CardData (resource) - Card data structure with suit/rank/validation
#
# Card Flow:
# 1. Round starts → Create standard 52-card deck
# 2. Shuffle deck using deterministic seed from GameState
# 3. Deal 28 cards to board pyramid, 24 to draw pile
# 4. Draw initial card to slot 1
# 5. Player selects board cards → Validate against slot cards
# 6. Build combos → Unlock slots 2 and 3 at thresholds
# 7. Draw from pile resets slots and combo
# 8. Check for valid moves after each action
# 9. End round when board cleared or no valid moves
#
# Slot System:
# - Slot 1: Always active, receives drawn cards
# - Slot 2: Unlocks at combo threshold (mode-dependent)
# - Slot 3: Unlocks at higher combo threshold
# - Auto-draw to new slots respects draw limit
# - Drawing from pile resets to single slot
#
# Note: Works closely with MobileGameBoard for UI updates
# See also: res://docs/Seedsystem.txt

extends Node

# Debug configuration
var debug_enabled: bool = false
var global_debug: bool = false

# === DECK STATE ===
var full_deck: Array[CardData] = []
var board_cards: Array[CardData] = []
var draw_pile: Array[CardData] = []
var slot_cards: Array[CardData] = [null, null, null]

# === GAME STATE ===
var game_board: Control = null
var active_slots: int = 1
var current_combo: int = 0
var cards_drawn: int = 0

# === INITIALIZATION ===

func _ready() -> void:
	debug_log("CardManager initializing...")
	_create_standard_deck()
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	debug_log("CardManager ready with %d cards" % full_deck.size())

func _create_standard_deck() -> void:
	full_deck.clear()
	for suit in range(4):
		for rank in range(1, 14):
			var card = CardData.new(suit, rank)
			full_deck.append(card)

func set_game_board(board: Control) -> void:
	game_board = board

# === ROUND MANAGEMENT ===

func _on_round_started(round: int) -> void:
	debug_log("Starting round %d" % round)
	_reset_round_state()
	_create_standard_deck()  # Reset deck order
	_shuffle_deck(GameState.deck_seed)
	_deal_cards()
	_draw_initial_card()

func _reset_round_state() -> void:
	board_cards.clear()
	draw_pile.clear()
	slot_cards = [null, null, null]
	active_slots = 1
	current_combo = 0
	cards_drawn = 0

func _shuffle_deck(seed_value: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	# Fisher-Yates shuffle
	var deck_copy = full_deck.duplicate()
	for i in range(deck_copy.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = deck_copy[i]
		deck_copy[i] = deck_copy[j]
		deck_copy[j] = temp
	
	full_deck = deck_copy

func _deal_cards() -> void:
	# Deal 28 cards to board
	for i in range(28):
		board_cards.append(full_deck[i])
	
	# Remaining 24 cards go to draw pile
	for i in range(28, 52):
		draw_pile.append(full_deck[i])
	
	debug_log("Dealt %d board cards, %d draw pile" % [board_cards.size(), draw_pile.size()])

func _draw_initial_card() -> void:
	if draw_pile.size() > 0:
		slot_cards[0] = draw_pile.pop_front()
		cards_drawn += 1

# === CARD SELECTION ===

func _on_card_selected(card: Control) -> void:
	if not card or not card.card_data:
		return
	
	# Find which slot this card can go to
	var target_slot = get_valid_slot_for_card(card.card_data)
	if target_slot == -1:
		return
	
	# Move card to slot
	slot_cards[target_slot] = card.card_data
	
	# Update combo
	current_combo += 1
	SignalBus.combo_updated.emit(current_combo)
	
	# Check for slot unlocks (this might draw cards if under limit)
	_check_slot_unlocks()
	
	# Track stats
	StatsManager.track_card_clicked()
	StatsManager.track_combo(current_combo)
	
	# Update board state
	GameState.cards_cleared += 1
	
	# Check if board is cleared
	if GameState.cards_cleared >= GameConstants.BOARD_CARDS:
		GameState.board_cleared = true
		debug_log("Board cleared!")
		await get_tree().create_timer(1.0).timeout
		GameState.check_round_end()
		return
	
	# Otherwise check for valid moves after cards update
	await get_tree().create_timer(0.5).timeout
	
	# Force board update
	if game_board:
		game_board.update_all_cards()
		await get_tree().process_frame
	
	if not has_valid_moves():
		debug_log("No valid moves after card selection - ending round")
		await get_tree().create_timer(1.0).timeout
		GameState.check_round_end()

func get_valid_slot_for_card(card_data: CardData) -> int:
	# Check each active slot for valid placement
	for i in range(active_slots):
		if slot_cards[i] and card_data.is_valid_next_card(slot_cards[i]):
			return i
	return -1

func _check_slot_unlocks() -> void:
	# Check if we should unlock more slots based on combo
	if active_slots < 2 and GameModeManager.should_unlock_slot(current_combo, 2):
		active_slots = 2
		debug_log("Unlocked slot 2 at combo %d" % current_combo)
		
		# Check draw limit before auto-drawing
		var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
		if draw_pile.size() > 0 and slot_cards[1] == null and cards_drawn < draw_limit:
			slot_cards[1] = draw_pile.pop_front()
			cards_drawn += 1  # This DOES count against the limit!
			debug_log("Auto-drew card to slot 2 (cards_drawn: %d/%d)" % [cards_drawn, draw_limit])
		
		# Update UI
		if game_board and game_board.mobile_top_bar:
			game_board.mobile_top_bar.call_deferred("update_slots")
		
	if active_slots < 3 and GameModeManager.should_unlock_slot(current_combo, 3):
		active_slots = 3
		debug_log("Unlocked slot 3 at combo %d" % current_combo)
		
		# Check draw limit before auto-drawing
		var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
		if draw_pile.size() > 0 and slot_cards[2] == null and cards_drawn < draw_limit:
			slot_cards[2] = draw_pile.pop_front()
			cards_drawn += 1  # This DOES count against the limit!
			debug_log("Auto-drew card to slot 3 (cards_drawn: %d/%d)" % [cards_drawn, draw_limit])
		
		# Update UI
		if game_board and game_board.mobile_top_bar:
			game_board.mobile_top_bar.call_deferred("update_slots")

# === DRAW PILE MANAGEMENT ===

func _on_draw_pile_clicked() -> void:
	# Check if we can draw
	var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
	if cards_drawn >= draw_limit or draw_pile.is_empty():
		debug_log("Cannot draw: limit=%d, drawn=%d, pile=%d" % [draw_limit, cards_drawn, draw_pile.size()])
		return
	
	# Reset slots when drawing
	slot_cards[1] = null
	slot_cards[2] = null
	active_slots = 1
	
	# Draw new card to slot 1
	if draw_pile.size() > 0:
		slot_cards[0] = draw_pile.pop_front()
		cards_drawn += 1
		debug_log("Drew card to slot 1 (cards_drawn: %d/%d)" % [cards_drawn, draw_limit])
	
	# Reset combo on draw
	current_combo = 0
	SignalBus.combo_updated.emit(0)
	
	# Track stats
	StatsManager.track_card_drawn()
	
	# Update UI
	if game_board and game_board.mobile_top_bar:
		game_board.mobile_top_bar.call_deferred("update_slots")
	
	# Check for valid moves after drawing
	await get_tree().create_timer(0.5).timeout
	if not has_valid_moves():
		debug_log("No valid moves after draw - ending round")
		GameState.check_round_end()

# === VALIDATION ===

func has_valid_moves() -> bool:
	# First check if we can draw more cards
	var draw_limit = GameModeManager.get_draw_pile_limit(GameState.current_round)
	if cards_drawn < draw_limit and not draw_pile.is_empty():
		return true
	
	# Check only selectable cards on the board
	if not game_board:
		return false
	
	# Count cards that are both visible AND can be played
	var valid_move_found = false
	var selectable_count = 0
	var playable_count = 0
	
	for card_node in game_board.board_card_nodes:
		if card_node and card_node.is_on_board:
			if card_node.is_selectable:
				selectable_count += 1
				# This card is selectable, now check if it can be played
				var target_slot = get_valid_slot_for_card(card_node.card_data)
				if target_slot != -1:
					playable_count += 1
					valid_move_found = true
	
	return valid_move_found

# === DEBUG FUNCTIONS ===

func debug_log(message: String) -> void:
	"""Debug logging with component prefix"""
	if debug_enabled and global_debug:
		print("[CARDMANAGER] %s" % message)

func get_debug_info() -> Dictionary:
	return {
		"board_cards": board_cards.size(),
		"draw_pile": draw_pile.size(),
		"cards_drawn": cards_drawn,
		"active_slots": active_slots,
		"current_combo": current_combo,
		"slot_1": slot_cards[0].get_display_value() if slot_cards[0] else "empty",
		"slot_2": slot_cards[1].get_display_value() if slot_cards[1] else "empty",
		"slot_3": slot_cards[2].get_display_value() if slot_cards[2] else "empty"
	}

func print_deck_state() -> void:
	debug_log("=== DECK STATE ===")
	debug_log("Board cards: %d" % board_cards.size())
	debug_log("Draw pile: %d" % draw_pile.size())
	debug_log("Cards drawn: %d" % cards_drawn)
	debug_log("Active slots: %d" % active_slots)
	debug_log("Slots: [%s, %s, %s]" % [
		slot_cards[0].get_display_value() if slot_cards[0] else "empty",
		slot_cards[1].get_display_value() if slot_cards[1] else "empty",
		slot_cards[2].get_display_value() if slot_cards[2] else "empty"
	])
	debug_log("==================")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			print_deck_state()
