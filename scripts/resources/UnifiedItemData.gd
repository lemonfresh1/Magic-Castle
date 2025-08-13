# UnifiedItemData.gd - Unified item data structure for all cosmetic items
# Location: res://Pyramids/scripts/resources/UnifiedItemData.gd
# Last Updated: Reorganized export groups [Date]

class_name UnifiedItemData
extends Resource

# Item categories
enum Category {
	CARD_FRONT,
	CARD_BACK,
	BOARD,
	FRAME,
	AVATAR,
	EMOJI,
	MINI_PROFILE_CARD,
	# Future categories
	TOPBAR,
	COMBO_EFFECT,
	MENU_BACKGROUND
}

# Item rarity
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
	MYTHIC
}

# Item sources for tracking
enum Source {
	DEFAULT,        # Starting items
	SHOP,          # Purchased with stars
	ACHIEVEMENT,   # Achievement rewards
	EVENT,         # Event rewards
	BUNDLE,        # Part of a bundle
	REFERRAL,      # Friend referral rewards
	SEASON_PASS,   # Season pass rewards
	HOLIDAY_EVENT, # Holiday event rewards
	XP_REWARD,     # Level up rewards
	GIFT,          # Gifted items
	# Future sources
	TOURNAMENT,    # Tournament rewards
	QUEST         # Quest rewards
}

@export_group("Core Identity")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("Categorization")
@export var category: Category = Category.CARD_FRONT
@export var rarity: Rarity = Rarity.COMMON
@export var set_name: String = ""
@export var subcategory: String = ""

@export_group("Visuals")
@export var icon_path: String = ""  # For UI display
@export var texture_path: String = ""  # For static items
@export var preview_texture_path: String = ""  # For shop/inventory preview

@export_group("Procedural/Animation")
@export var is_procedural: bool = false
@export var is_animated: bool = false
@export var procedural_script_path: String = ""  # Path to procedural generator script
@export var animation_metadata: Dictionary = {}  # Animation settings

@export_group("Board Settings")
@export var background_type: String = "color"  # color, sprite, scene, procedural
@export var background_scene_path: String = ""
@export var colors: Dictionary = {}  # primary, secondary, etc.
@export var can_be_menu_background: bool = false  # TODO: Allow boards to be menu backgrounds

@export_group("Mini Profile Settings")
@export_enum("standard", "compact", "detailed", "animated") var mini_profile_layout: String = "standard"
@export var showcase_slots: int = 3  # How many items/achievements/stats can be shown
@export var stat_positions: Dictionary = {}  # Where stats appear on the card
@export var achievement_positions: Dictionary = {}  # Where achievements appear
@export var item_positions: Dictionary = {}  # Where showcased items appear
@export var supports_animation: bool = false  # If the mini profile can animate

@export_group("TopBar Settings")
@export var topbar_gradient: Gradient  # Background gradient for topbar
@export var topbar_button_style: String = "default"  # Button visual style
@export var topbar_font: String = ""  # Custom font for topbar
@export var timer_bar_color: Color = Color.WHITE
@export var draw_pile_tint: Color = Color.WHITE

@export_group("Combo Effect Settings")
@export var combo_threshold: int = 5  # When effect starts
@export var effect_intensity_curve: Curve  # How effect scales with combo
@export var particle_scene_path: String = ""  # Path to particle effect
@export var border_shader_path: String = ""  # Path to border shader
@export var sound_effect_path: String = ""  # Path to combo sound
@export_enum("fire", "lightning", "ice", "rainbow", "cosmic") var effect_type: String = "fire"
@export var max_combo_visuals: int = 20  # Cap for performance

@export_group("Economy")
@export var base_price: int = 0
@export var currency_type: String = "stars"  # ADD THIS LINE - stars, event_tokens, etc.
@export var is_purchasable: bool = true
@export var is_tradeable: bool = false
@export var unlock_level: int = 0

@export_group("Acquisition")
@export var source: Source = Source.SHOP
@export var achievement_id: String = ""  # If from achievement
@export var event_id: String = ""  # If from event
@export var quest_id: String = ""  # TODO: If from quest system
@export var bundle_id: String = ""  # If part of a bundle

@export_group("Display Metadata")
@export var sort_order: int = 0
@export var tags: Array[String] = []
@export var release_date: String = ""
@export var is_limited_time: bool = false
@export var expiry_date: String = ""
@export var is_new: bool = false  # Show "NEW" badge
@export var is_limited: bool = false  # Limited availability

@export_group("Effects & Stats")
@export var effects: Dictionary = {}  # Visual effects data
@export var stats: Dictionary = {}  # Any stat modifications
@export var metadata: Dictionary = {}  # Extra data for specific items

@export_group("Future Features")
@export var supports_color_customization: bool = false  # TODO: Allow color picker
@export var supports_user_upload: bool = false  # TODO: Custom avatars/frames
@export var blockchain_id: String = ""  # TODO: NFT integration (maybe never)
@export var workshop_id: String = ""  # TODO: Steam Workshop support

# Helper functions
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return UIStyleManager.get_rarity_color("common")
		Rarity.UNCOMMON: return UIStyleManager.get_rarity_color("uncommon")
		Rarity.RARE: return UIStyleManager.get_rarity_color("rare")
		Rarity.EPIC: return UIStyleManager.get_rarity_color("epic")
		Rarity.LEGENDARY: return UIStyleManager.get_rarity_color("legendary")
		Rarity.MYTHIC: return UIStyleManager.get_rarity_color("mythic")
		_: return Color.WHITE

func get_rarity_name() -> String:
	return Rarity.keys()[rarity]

func get_category_name() -> String:
	return Category.keys()[category]

func get_source_name() -> String:
	return Source.keys()[source]

func get_price_with_rarity_multiplier() -> int:
	var multiplier = 1.0
	match rarity:
		Rarity.UNCOMMON: multiplier = 1.5
		Rarity.RARE: multiplier = 2.0
		Rarity.EPIC: multiplier = 3.0
		Rarity.LEGENDARY: multiplier = 5.0
		Rarity.MYTHIC: multiplier = 10.0
	
	return int(base_price * multiplier)

func can_be_purchased_by_player() -> bool:
	if not is_purchasable:
		return false
	if unlock_level > 0 and XPManager.get_current_level() < unlock_level:
		return false
	return true

func is_owned() -> bool:
	# Check with EquipmentManager
	if EquipmentManager:
		return EquipmentManager.is_item_owned(id)
	return false

func is_equipped() -> bool:
	# Check with EquipmentManager
	if EquipmentManager:
		return EquipmentManager.is_item_equipped(id)
	return false

# Future category helpers
func is_future_category() -> bool:
	"""Check if this item is from a not-yet-implemented category"""
	return category in [Category.TOPBAR, Category.COMBO_EFFECT, Category.MENU_BACKGROUND]

func get_todo_message() -> String:
	"""Get the TODO message for this category"""
	match category:
		Category.MINI_PROFILE_CARD: return "TODO: Implement mini profile card system"
		Category.TOPBAR: return "TODO: Implement topbar customization"
		Category.COMBO_EFFECT: return "TODO: Implement combo visual effects"
		Category.MENU_BACKGROUND: return "TODO: Implement menu background system"
		_: return ""

# ShopManager compatibility helpers
func from_shop_item(item: ShopManager.ShopItem) -> void:
	"""Convert from ShopManager.ShopItem format"""
	id = item.id
	display_name = item.display_name
	description = ""  # ShopItem doesn't have description, use empty or generate one
	
	# Map ShopManager category to our category
	category = _map_shop_category(item.category)
	rarity = _map_shop_rarity(item.rarity)
	
	icon_path = item.preview_texture_path
	texture_path = item.preview_texture_path
	
	base_price = item.base_price
	is_purchasable = true
	unlock_level = item.unlock_level

func _map_shop_category(cat: String) -> Category:
	match cat:
		"card_skins", "card_fronts": return Category.CARD_FRONT
		"card_backs": return Category.CARD_BACK
		"board_skins", "boards": return Category.BOARD
		"frames": return Category.FRAME
		"avatars": return Category.AVATAR
		"emojis": return Category.EMOJI
		"mini_profiles": return Category.MINI_PROFILE_CARD
		"topbars": return Category.TOPBAR
		"combo_effects": return Category.COMBO_EFFECT
		_: return Category.CARD_FRONT

func _map_shop_rarity(r: ShopManager.Rarity) -> Rarity:
	match r:
		ShopManager.Rarity.COMMON: return Rarity.COMMON
		ShopManager.Rarity.UNCOMMON: return Rarity.UNCOMMON
		ShopManager.Rarity.RARE: return Rarity.RARE
		ShopManager.Rarity.EPIC: return Rarity.EPIC
		ShopManager.Rarity.LEGENDARY: return Rarity.LEGENDARY
		ShopManager.Rarity.MYTHIC: return Rarity.MYTHIC
		_: return Rarity.COMMON

# Procedural instance helpers
func from_procedural_instance(instance: Object, item_category: Category) -> void:
	"""Convert from procedural item instance"""
	if not instance:
		return
		
	if instance.has_method("get"):
		id = instance.get("item_id") if instance.get("item_id") else ""
		display_name = instance.get("display_name") if instance.get("display_name") else ""
		category = item_category
		
		is_procedural = true
		is_animated = instance.get("is_animated") if instance.get("is_animated") != null else false
		
		# Get rarity if available
		if instance.get("item_rarity") != null:
			var inst_rarity = instance.get("item_rarity")
			if typeof(inst_rarity) == TYPE_STRING:
				rarity = _string_to_rarity(inst_rarity)
			elif typeof(inst_rarity) == TYPE_INT:
				rarity = inst_rarity as Rarity

func _string_to_rarity(rarity_str: String) -> Rarity:
	"""Convert string to Rarity enum"""
	match rarity_str.to_lower():
		"common": return Rarity.COMMON
		"uncommon": return Rarity.UNCOMMON
		"rare": return Rarity.RARE
		"epic": return Rarity.EPIC
		"legendary": return Rarity.LEGENDARY
		"mythic": return Rarity.MYTHIC
		_: return Rarity.COMMON
