# CardData.gd - Resource class for individual cards
# Path: res://Magic-Castle/scripts/game/CardData.gd
extends Resource
class_name CardData

# === CARD ENUMS ===
enum Suit { 
	SPADES = 0, 
	HEARTS = 1, 
	CLUBS = 2, 
	DIAMONDS = 3 
}

enum Rank { 
	ACE = 1, TWO = 2, THREE = 3, FOUR = 4, FIVE = 5, SIX = 6, 
	SEVEN = 7, EIGHT = 8, NINE = 9, TEN = 10, JACK = 11, QUEEN = 12, KING = 13 
}

# === CARD PROPERTIES ===
@export var suit: Suit = Suit.SPADES
@export var rank: Rank = Rank.ACE

func _init(card_suit: Suit = Suit.SPADES, card_rank: Rank = Rank.ACE):
	suit = card_suit
	rank = card_rank

# === DISPLAY METHODS ===
func get_display_value() -> String:
	var rank_str = ""
	match rank:
		Rank.ACE: rank_str = "A"
		Rank.JACK: rank_str = "J"
		Rank.QUEEN: rank_str = "Q"
		Rank.KING: rank_str = "K"
		_: rank_str = str(rank)
	
	var suit_str = ""
	match suit:
		Suit.SPADES: suit_str = "♠"
		Suit.HEARTS: suit_str = "♥"
		Suit.CLUBS: suit_str = "♣"
		Suit.DIAMONDS: suit_str = "♦"
	
	return rank_str + suit_str

func get_rank_name() -> String:
	match rank:
		Rank.ACE: return "ace"
		Rank.TWO: return "two"
		Rank.THREE: return "three"
		Rank.FOUR: return "four"
		Rank.FIVE: return "five"
		Rank.SIX: return "six"
		Rank.SEVEN: return "seven"
		Rank.EIGHT: return "eight"
		Rank.NINE: return "nine"
		Rank.TEN: return "ten"
		Rank.JACK: return "jack"
		Rank.QUEEN: return "queen"
		Rank.KING: return "king"
		_: return "unknown"

func get_suit_name() -> String:
	match suit:
		Suit.SPADES: return "spades"
		Suit.HEARTS: return "hearts"
		Suit.CLUBS: return "clubs"
		Suit.DIAMONDS: return "diamonds"
		_: return "unknown"

func get_color() -> Color:
	if suit == Suit.HEARTS or suit == Suit.DIAMONDS:
		return Color.RED
	else:
		return Color.BLACK

func get_color_name() -> String:
	return "red" if get_color() == Color.RED else "black"

# === CARD IMAGE HELPERS ===
func get_card_image_path() -> String:
	return "res://Magic-Castle/assets/cards/%s_of_%s.png" % [get_rank_name(), get_suit_name()]

func get_card_back_path() -> String:
	return "res://Magic-Castle/assets/cards/pink_backing.png"

# === GAME LOGIC ===
func is_valid_next_card(other_card: CardData) -> bool:
	"""Check if this card can be placed on top of other_card according to tri-peaks rules"""
	if not other_card:
		return false
	
	var diff = abs(rank - other_card.rank)
	
	# Handle Ace wrapping (Ace = 1, King = 13)
	if (rank == Rank.ACE and other_card.rank == Rank.KING) or \
	   (rank == Rank.KING and other_card.rank == Rank.ACE):
		return true
	
	# Standard ±1 rule
	return diff == 1

func can_stack_on(other_card: CardData) -> bool:
	"""Alias for is_valid_next_card for clarity"""
	return is_valid_next_card(other_card)

func get_rank_value() -> int:
	"""Get numeric value of rank for calculations"""
	return rank

func is_same_suit(other_card: CardData) -> bool:
	"""Check if cards have the same suit (for suit bonus)"""
	if not other_card:
		return false
	return suit == other_card.suit

func is_same_color(other_card: CardData) -> bool:
	"""Check if cards have the same color"""
	if not other_card:
		return false
	return get_color() == other_card.get_color()

func is_same_rank(other_card: CardData) -> bool:
	"""Check if cards have the same rank"""
	if not other_card:
		return false
	return rank == other_card.rank

# === COMPARISON & UTILITY ===
func is_equal_to(other_card: CardData) -> bool:
	"""Check if two cards are identical"""
	if not other_card:
		return false
	return suit == other_card.suit and rank == other_card.rank

func compare_rank(other_card: CardData) -> int:
	"""Compare ranks: returns -1, 0, or 1"""
	if not other_card:
		return 0
	if rank < other_card.rank:
		return -1
	elif rank > other_card.rank:
		return 1
	else:
		return 0

func get_rank_distance(other_card: CardData) -> int:
	"""Get distance between ranks (considering wrapping)"""
	if not other_card:
		return -1
	
	var direct_distance = abs(rank - other_card.rank)
	var wrap_distance = 13 - direct_distance  # For Ace-King wrapping
	
	return min(direct_distance, wrap_distance)

# === DEBUGGING ===
func get_debug_info() -> Dictionary:
	return {
		"display": get_display_value(),
		"rank": rank,
		"suit": suit,
		"color": get_color_name(),
		"rank_name": get_rank_name(),
		"suit_name": get_suit_name()
	}

# === VALIDATION ===
func is_valid_card() -> bool:
	"""Check if card has valid suit and rank"""
	return suit >= Suit.SPADES and suit <= Suit.DIAMONDS and \
		   rank >= Rank.ACE and rank <= Rank.KING

# === STATIC HELPERS ===
static func create_deck() -> Array[CardData]:
	"""Create a standard 52-card deck"""
	var deck: Array[CardData] = []
	
	for suit_value in range(4):
		for rank_value in range(1, 14):
			var card = CardData.new(suit_value, rank_value)
			deck.append(card)
	
	return deck

static func get_all_suits() -> Array[Suit]:
	return [Suit.SPADES, Suit.HEARTS, Suit.CLUBS, Suit.DIAMONDS]

static func get_all_ranks() -> Array[Rank]:
	var ranks: Array[Rank] = []
	for i in range(1, 14):
		ranks.append(i)
	return ranks
