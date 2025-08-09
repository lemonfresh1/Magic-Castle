# ItemData.gd - Resource class for item definitions
# Location: res://Magic-Castle/scripts/resources/ItemData.gd
# Last Updated: Created as resource for item system [Date]

class_name ItemData
extends Resource

# Item categories
enum Category {
	CARD_FRONT,
	CARD_BACK,
	BOARD,
	FRAME,
	AVATAR,
	EMOJI,
	MINI_PROFILE_CARD
}

# Item sources for tracking
enum Source {
	DEFAULT,        # Starting items
	SHOP,          # Purchased with stars
	SEASON_PASS,   # Season pass rewards
	HOLIDAY_EVENT, # Holiday event rewards
	ACHIEVEMENT,   # Achievement rewards
	XP_REWARD,     # Level up rewards
	REFERRAL,      # Friend referral rewards
	GIFT,          # Gifted items
	BUNDLE         # Part of a bundle
}

# Item rarity (matching ShopManager)
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

@export_group("Basic Info")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.CARD_FRONT
@export var rarity: Rarity = Rarity.COMMON

@export_group("Categorization")
@export var subcategory: String = ""  # Theme like "pyramids", "medieval", "neon"
@export var tags: Array[String] = []  # For filtering/searching
@export var set_name: String = ""  # Collection set name

@export_group("Acquisition")
@export var source: Source = Source.SHOP
@export var base_price: int = 0
@export var currency_type: String = "stars"
@export var bundle_id: String = ""  # If part of a bundle
@export var unlock_level: int = 0  # Level requirement
@export var is_purchasable: bool = true  # Can be bought in shop
@export var is_tradeable: bool = false  # Future: trading system

@export_group("Visuals")
@export var icon_path: String = ""  # Small icon for UI
@export var texture_path: String = ""  # Full texture/sprite
@export var preview_texture_path: String = ""  # Preview image
@export var is_animated: bool = false
@export var animation_frames: int = 0
@export var background_scene_path: String = ""  # ADD THIS - Path to packed scene for animated backgrounds
@export var background_type: String = "color"  # ADD THIS - "color", "sprite", "scene"

@export_group("Display")
@export var sort_order: int = 0  # For display ordering
@export var is_new: bool = false  # Show "NEW" badge
@export var is_limited: bool = false  # Limited time item
@export var available_until: String = ""  # Expiry date if limited

@export_group("Effects & Metadata")
@export var effects: Dictionary = {}  # Visual effects data
@export var colors: Dictionary = {}  # Color customization data
@export var stats: Dictionary = {}  # Any stat modifications
@export var metadata: Dictionary = {}  # Extra data for specific items

# Helper functions
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.6, 0.6, 0.6)      # Gray
		Rarity.UNCOMMON: return Color(0.3, 0.8, 0.3)    # Green
		Rarity.RARE: return Color(0.3, 0.5, 0.9)        # Blue
		Rarity.EPIC: return Color(0.7, 0.3, 0.9)        # Purple
		Rarity.LEGENDARY: return Color(0.9, 0.6, 0.2)   # Orange
		Rarity.MYTHIC: return Color(0.9, 0.2, 0.2)      # Red
		_: return Color.WHITE

func get_rarity_name() -> String:
	return Rarity.keys()[rarity]

func get_category_name() -> String:
	return Category.keys()[category]

func get_source_name() -> String:
	return Source.keys()[source]

func can_be_purchased_by_player() -> bool:
	if not is_purchasable:
		return false
	if unlock_level > 0 and XPManager.get_current_level() < unlock_level:
		return false
	return true
