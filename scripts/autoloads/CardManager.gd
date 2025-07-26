# CardManager.gd - Improved version with separated concerns
extends Node

# === DECK STATE ===
var full_deck: Array[CardData] = []
var current_deck: Array[CardData] = []
var draw_pile: Array[CardData] = []
var board_cards: Array[CardData] = []

# === SLOT STATE ===
var slot_cards: Array[CardData] = [null, null, null]
var active_slots: int = 1

# === GAME STATE ===
var current_combo: int = 0
var cards_drawn: int = 0
var game_board: Node = null

func _ready() -> void:
	print("CardManager initialized")
	_create_full_deck()
	_connect_signals()

# === INITIALIZATION ===
func _create_full_deck() -> void:
	full_deck.clear()
	for suit in range(4):
		for rank in range(1, 14):
			var card = CardData.new()
			card.suit = suit
			card.rank = rank
			full_deck.append(card)
	print("Created full deck with %d cards" % full_deck.size())

func _connect_signals() -> void:
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.card_invalid_selected.connect(_on_card_invalid_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	SignalBus.round_started.connect(_on_round_started)

func set_game_board(board: Node) -> void:
	game_board = board

# === DECK MANAGEMENT ===
func shuffle_deck(seed_value: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	current_deck = full_deck.duplicate()
	
	# Fisher-Yates shuffle
	for i in range(current_deck.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = current_deck[i]
		current_deck[i] = current_deck[j]
		current_deck[j] = temp
	
	print("Deck shuffled with seed: %d" % seed_value)

func deal_new_round() -> void:
	print("Dealing new round from %d cards" % current_deck.size())
	
	# Split deck
	board_cards = current_deck.slice(0, GameConstants.BOARD_CARDS)
	draw_pile = current_deck.slice(GameConstants.BOARD_CARDS, GameConstants.TOTAL_CARDS)
	
	# Initialize slots
	_reset_slots()
	_draw_initial_card()
	
	current_combo = 0
	print("Board: %d cards, Draw pile: %d cards" % [board_cards.size(), draw_pile.size()])

func _reset_slots() -> void:
	slot_cards = [null, null, null]
	active_slots = 1

func _draw_initial_card() -> void:
	if not draw_pile.is_empty():
		slot_cards[0] = draw_pile.pop_front()
		cards_drawn = 1
		print("Starting card: %s" % slot_cards[0].get_display_value())

# === SLOT VALIDATION ===
func get_valid_slot_for_card(card_data: CardData) -> int:
	print("=== CHECKING CARD VALIDITY ===")
	print("Checking card: %s" % card_data.get_display_value())
	print("Active slots: %d" % active_slots)
	
	# Check each active slot in order
	for i in range(active_slots):
		if slot_cards[i]:
			print("Slot %d has: %s" % [i, slot_cards[i].get_display_value()])
			var is_valid = card_data.is_valid_next_card(slot_cards[i])
			print("Is %s valid on %s? %s" % [card_data.get_display_value(), slot_cards[i].get_display_value(), is_valid])
			if is_valid:
				print("VALID: Card %s can go to slot %d" % [card_data.get_display_value(), i])
				return i
		else:
			print("Slot %d is empty!" % i)
	
	print("INVALID: No valid slots for %s" % card_data.get_display_value())
	return -1

# === CARD SELECTION ===
func select_card(card_data: CardData) -> void:
	var valid_slot = get_valid_slot_for_card(card_data)
	if valid_slot == -1:
		return
	
	_process_combo_progression()
	_place_card_in_slot(card_data, valid_slot)
	_update_game_state(card_data)

func _process_combo_progression() -> void:
	current_combo += 1  # Increment FIRST
	
	# Unlock slots based on NEW combo value
	if current_combo == GameConstants.SLOT_2_UNLOCK_COMBO and active_slots == 1:
		_unlock_slot(2)
	elif current_combo == GameConstants.SLOT_3_UNLOCK_COMBO and active_slots == 2:
		_unlock_slot(3)
	
	SignalBus.combo_updated.emit(current_combo)

func _unlock_slot(slot_number: int) -> void:
	# Check BOTH conditions - physical cards AND draw limit
	if draw_pile.is_empty():
		print("Cannot unlock slot %d - draw pile is empty" % slot_number)
		return
	
	# ALSO check if we've reached the draw limit
	if cards_drawn >= GameConstants.get_draw_pile_limit(GameState.current_round):
		print("Cannot unlock slot %d - draw limit reached (%d/%d)" % [
			slot_number, 
			cards_drawn, 
			GameConstants.get_draw_pile_limit(GameState.current_round)
		])
		return
	
	var slot_index = slot_number - 1
	slot_cards[slot_index] = draw_pile.pop_front()
	cards_drawn += 1  # INCREMENT cards_drawn when unlocking a slot!
	active_slots = slot_number
	
	print("Combo %d! Unlocked slot %d with %s (cards drawn: %d)" % [
		current_combo, 
		slot_number, 
		slot_cards[slot_index].get_display_value(),
		cards_drawn
	])

func _place_card_in_slot(card_data: CardData, slot_index: int) -> void:
	slot_cards[slot_index] = card_data
	print("Card %s placed in slot %d" % [card_data.get_display_value(), slot_index + 1])

func _update_game_state(card_data: CardData) -> void:
	# Remove from board data
	var index = board_cards.find(card_data)
	if index != -1:
		board_cards.remove_at(index)
		GameState.cards_cleared += 1
		print("Card cleared! Total: %d/%d" % [GameState.cards_cleared, GameConstants.BOARD_CARDS])

func _check_game_end_conditions() -> void:
	if GameState.cards_cleared == GameConstants.BOARD_CARDS:
		print("Board cleared!")
		GameState.check_round_end()
	elif not has_valid_moves():
		print("No valid moves remaining!")
		GameState.check_round_end()

# === DRAW PILE ===
func draw_from_pile() -> bool:
	if not _can_draw():
		await _check_game_end_after_draw_fail()  # Add await here
		return false
	
	# ... rest of the function remains the same
	
	var new_card = draw_pile.pop_front()
	cards_drawn += 1
	
	# Reset combo FIRST
	_reset_combo()
	
	# THEN reset slots (now combo is 0, so no extra slots will unlock)
	_reset_slots_after_draw(new_card)
	
	print("Drew: %s (%d/%d)" % [
		new_card.get_display_value(), 
		cards_drawn, 
		GameConstants.get_draw_pile_limit(GameState.current_round)
	])
	
	# Force update of board cards
	if game_board:
		await get_tree().process_frame
		game_board.update_all_cards()
	
	# Only check for game end after cards are updated
	await get_tree().process_frame
	if not has_valid_moves():
		GameState.check_round_end()
	
	return true

func _can_draw() -> bool:
	return not draw_pile.is_empty() and cards_drawn < GameConstants.get_draw_pile_limit(GameState.current_round)

func _reset_slots_after_draw(new_card: CardData) -> void:
	# Drawing ALWAYS resets to just 1 slot, no matter what combo you had
	slot_cards = [new_card, null, null]
	active_slots = 1
	
	# DON'T re-unlock slots - combo is broken by drawing!
	print("Slots reset after draw. Active slots: 1")

func _reset_combo() -> void:
	current_combo = 0
	SignalBus.combo_updated.emit(0)
	
	# Also stop the combo timer in ScoreSystem
	if ScoreSystem.combo_timer:
		ScoreSystem.combo_timer.stop()

func _check_game_end_after_draw_fail() -> void:
	# Update board first if available
	if game_board:
		game_board.update_all_cards()
		# Need to wait for update to complete
		await get_tree().process_frame
	
	if not has_valid_moves():
		print("No moves left after draw failure!")
		GameState.check_round_end()

# === MOVE VALIDATION ===
func has_valid_moves() -> bool:
	print("=== CHECKING FOR VALID MOVES ===")
	print("Draw pile size: %d, Cards drawn: %d, Limit: %d" % [
		draw_pile.size(), 
		cards_drawn, 
		GameConstants.get_draw_pile_limit(GameState.current_round)
	])
	
	# Can we draw more cards?
	if _can_draw():
		print("Can still draw cards")
		return true
	
	# Check visual board if available
	if game_board:
		var selectable_count = _count_selectable_visual_cards()
		print("Selectable cards on board: %d" % selectable_count)
		return selectable_count > 0
	
	# Fallback: check data array
	var has_moves = _has_valid_moves_in_data()
	print("Has valid moves in data: %s" % has_moves)
	return has_moves

func _count_selectable_visual_cards() -> int:
	var count = 0
	for card_node in game_board.board_card_nodes:
		if card_node and card_node.is_on_board and card_node.is_selectable:
			count += 1
			print("Card %s is selectable" % card_node.card_data.get_display_value())
	return count

func _has_valid_moves_in_data() -> bool:
	for card_data in board_cards:
		if get_valid_slot_for_card(card_data) != -1:
			return true
	return false

# === SIGNAL HANDLERS ===
func _on_card_selected(card: Control) -> void:
	if get_valid_slot_for_card(card.card_data) != -1:
		select_card(card.card_data)
		
		# ALWAYS check if board is cleared first!
		if GameState.cards_cleared >= GameConstants.BOARD_CARDS:
			print("All board cards cleared! Win!")
			GameState.board_cleared = true
			GameState.check_round_end()
			return
		
		# Otherwise, check for no moves
		await get_tree().create_timer(0.3).timeout
		
		if game_board:
			game_board.update_all_cards()
			await get_tree().process_frame
		
		if not has_valid_moves():
			print("No valid moves after card selection!")
			GameState.check_round_end()
	else:
		SignalBus.card_invalid_selected.emit(card)

func _on_card_invalid_selected(card: Control) -> void:
	print("Invalid selection: %s" % card.card_data.get_display_value())
	SignalBus.score_changed.emit(GameConstants.INVALID_CLICK_PENALTY, "invalid_click")

func _on_draw_pile_clicked() -> void:
	var success = await draw_from_pile()
	# Force board update even if draw failed
	if game_board:
		await get_tree().process_frame
		game_board.update_all_cards()
	
	# Then check for valid moves
	await get_tree().create_timer(0.1).timeout
	if not has_valid_moves():
		print("No valid moves after draw attempt!")
		GameState.check_round_end()

func _on_round_started(round_number: int) -> void:
	shuffle_deck(GameState.deck_seed)
	deal_new_round()
