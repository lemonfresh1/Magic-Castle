# UnifiedItemData.gd - Unified item data structure for all cosmetic items
# Location: res://Pyramids/scripts/resources/UnifiedItemData.gd
# Last Updated: Removed ShopManager dependencies [Date]
#
# UnifiedItemData is the core data structure for all items.
# Used by ItemManager (definitions), EquipmentManager (ownership), and ShopManager (commerce)

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
@export_enum("standard", "compact", "detailed", "animated") var mini_profile_card_layout: String = "standard"
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
@export var currency_type: String = "stars"  # stars, gems, event_tokens, etc.
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

# === HELPER FUNCTIONS ===

func get_rarity_color() -> Color:
	"""Get the display color for this item's rarity"""
	var rarity_str = get_rarity_name().to_lower()
	
	if UIStyleManager:
		return UIStyleManager.get_rarity_color(rarity_str)
	else:
		# Fallback colors if UIStyleManager not available
		match rarity:
			Rarity.COMMON: return Color(0.6, 0.6, 0.6)
			Rarity.UNCOMMON: return Color(0.3, 0.8, 0.3)
			Rarity.RARE: return Color(0.3, 0.5, 0.9)
			Rarity.EPIC: return Color(0.7, 0.3, 0.9)
			Rarity.LEGENDARY: return Color(0.9, 0.6, 0.2)
			Rarity.MYTHIC: return Color(0.9, 0.2, 0.2)
			_: return Color.WHITE

func get_rarity_name() -> String:
	"""Get the string name of this item's rarity"""
	return Rarity.keys()[rarity].to_lower()

func get_category_name() -> String:
	"""Get the string name of this item's category"""
	return Category.keys()[category].to_lower()

func get_category_folder() -> String:
	"""Get the folder name for this category"""
	match category:
		Category.CARD_FRONT: return "card_fronts"
		Category.CARD_BACK: return "card_backs"  
		Category.BOARD: return "boards"
		Category.FRAME: return "frames"
		Category.AVATAR: return "avatars"
		Category.EMOJI: return "emojis"
		Category.MINI_PROFILE_CARD: return "mini_profile_cards"
		_: return get_category_name() + "s"

func get_source_name() -> String:
	"""Get the string name of this item's source"""
	return Source.keys()[source]

func get_price_with_rarity_multiplier() -> int:
	"""Calculate price with rarity multiplier applied"""
	var multiplier = 1.0
	match rarity:
		Rarity.UNCOMMON: multiplier = 1.5
		Rarity.RARE: multiplier = 2.0
		Rarity.EPIC: multiplier = 3.0
		Rarity.LEGENDARY: multiplier = 5.0
		Rarity.MYTHIC: multiplier = 10.0
	
	return int(base_price * multiplier)

func can_be_purchased_by_player() -> bool:
	"""Check if the current player can purchase this item"""
	if not is_purchasable:
		return false
	
	# Check level requirement
	if unlock_level > 0:
		if XPManager and XPManager.has("current_level"):
			if XPManager.current_level < unlock_level:
				return false
		elif XPManager and XPManager.has_method("get_current_level"):
			if XPManager.get_current_level() < unlock_level:
				return false
	
	return true

func is_owned() -> bool:
	"""Check if player owns this item"""
	if EquipmentManager:
		return EquipmentManager.is_item_owned(id)
	return false

func is_equipped() -> bool:
	"""Check if this item is currently equipped"""
	if EquipmentManager:
		return EquipmentManager.is_item_equipped(id)
	return false

# === FUTURE CATEGORY HELPERS ===

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

# === CONVERSION HELPERS ===

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
				rarity = string_to_rarity(inst_rarity)
			elif typeof(inst_rarity) == TYPE_INT:
				rarity = inst_rarity as Rarity
		
		# Get price if available
		if instance.get("base_price") != null:
			base_price = instance.get("base_price")
		
		# Get other properties
		if instance.get("description") != null:
			description = instance.get("description")
		if instance.get("currency_type") != null:
			currency_type = instance.get("currency_type")

func from_dictionary(data: Dictionary) -> void:
	"""Load item data from a dictionary (for migration/import)"""
	if data.has("id"):
		id = data.id
	if data.has("display_name"):
		display_name = data.display_name
	if data.has("description"):
		description = data.description
	
	if data.has("category"):
		if typeof(data.category) == TYPE_STRING:
			category = string_to_category(data.category)
		else:
			category = data.category
	
	if data.has("rarity"):
		if typeof(data.rarity) == TYPE_STRING:
			rarity = string_to_rarity(data.rarity)
		else:
			rarity = data.rarity
	
	if data.has("base_price"):
		base_price = data.base_price
	if data.has("currency_type"):
		currency_type = data.currency_type
	if data.has("is_purchasable"):
		is_purchasable = data.is_purchasable
	if data.has("unlock_level"):
		unlock_level = data.unlock_level

func to_dictionary() -> Dictionary:
	"""Export item data to dictionary (for saving/export)"""
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"category": get_category_name(),
		"rarity": get_rarity_name(),
		"base_price": base_price,
		"currency_type": currency_type,
		"is_purchasable": is_purchasable,
		"is_procedural": is_procedural,
		"is_animated": is_animated,
		"unlock_level": unlock_level,
		"source": get_source_name(),
		"set_name": set_name,
		"tags": tags,
		"is_new": is_new,
		"is_limited": is_limited
	}

# === STATIC CONVERSION UTILITIES ===

static func string_to_rarity(rarity_str: String) -> Rarity:
	"""Convert string to Rarity enum"""
	match rarity_str.to_lower():
		"common": return Rarity.COMMON
		"uncommon": return Rarity.UNCOMMON
		"rare": return Rarity.RARE
		"epic": return Rarity.EPIC
		"legendary": return Rarity.LEGENDARY
		"mythic": return Rarity.MYTHIC
		_: return Rarity.COMMON

static func string_to_category(category_str: String) -> Category:
	"""Convert string to Category enum"""
	match category_str.to_lower():
		"card_front", "card_fronts", "card_skins":
			return Category.CARD_FRONT
		"card_back", "card_backs":
			return Category.CARD_BACK
		"board", "boards", "board_skins":
			return Category.BOARD
		"frame", "frames":
			return Category.FRAME
		"avatar", "avatars":
			return Category.AVATAR
		"emoji", "emojis":
			return Category.EMOJI
		"mini_profile_card", "mini_profile_cards":
			return Category.MINI_PROFILE_CARD
		"topbar", "topbars":
			return Category.TOPBAR
		"combo_effect", "combo_effects":
			return Category.COMBO_EFFECT
		"menu_background", "menu_backgrounds":
			return Category.MENU_BACKGROUND
		_:
			return Category.CARD_FRONT

static func string_to_source(source_str: String) -> Source:
	"""Convert string to Source enum"""
	match source_str.to_lower():
		"default": return Source.DEFAULT
		"shop": return Source.SHOP
		"achievement": return Source.ACHIEVEMENT
		"event": return Source.EVENT
		"bundle": return Source.BUNDLE
		"referral": return Source.REFERRAL
		"season_pass": return Source.SEASON_PASS
		"holiday_event": return Source.HOLIDAY_EVENT
		"xp_reward": return Source.XP_REWARD
		"gift": return Source.GIFT
		"tournament": return Source.TOURNAMENT
		"quest": return Source.QUEST
		_: return Source.SHOP

# === VALIDATION ===

func validate() -> bool:
	"""Validate that this item has all required data"""
	if id == "":
		push_warning("UnifiedItemData: Item has no ID")
		return false
	
	if display_name == "":
		push_warning("UnifiedItemData: Item %s has no display name" % id)
		return false
	
	# Procedural items need script path
	if is_procedural and procedural_script_path == "":
		push_warning("UnifiedItemData: Procedural item %s has no script path" % id)
		return false
	
	# Board items with scene background need scene path
	if category == Category.BOARD and background_type == "scene" and background_scene_path == "":
		push_warning("UnifiedItemData: Board %s has scene type but no scene path" % id)
		return false
	
	return true

# === DEBUG ===

func debug_print() -> void:
	"""Print item details for debugging"""
	print("\n=== ITEM: %s ===" % id)
	print("  Name: %s" % display_name)
	print("  Category: %s" % get_category_name())
	print("  Rarity: %s" % get_rarity_name())
	print("  Price: %d %s" % [base_price, currency_type])
	print("  Procedural: %s, Animated: %s" % [is_procedural, is_animated])
	print("  Owned: %s, Equipped: %s" % [is_owned(), is_equipped()])
	print("==================\n")
