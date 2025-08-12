# UnifiedItemData.gd - Unified item data structure for all cosmetic items
# Location: res://Pyramids/scripts/resources/UnifiedItemData.gd
# Last Updated: Created with future category placeholders [Date]

class_name UnifiedItemData
extends Resource

# Core identification
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Categorization - INCLUDING FUTURE CATEGORIES
@export_enum("card_front", "card_back", "board", "frame", "avatar", "emoji", "mini_profile", "topbar", "combo_effect", "menu_background") var category: String = "card_front"
@export_enum("common", "uncommon", "rare", "epic", "legendary", "mythic") var rarity: String = "common"
@export var set_name: String = ""
@export var subcategory: String = ""

# Visuals
@export var icon_path: String = ""  # For UI display
@export var texture_path: String = ""  # For static items
@export var preview_texture_path: String = ""  # For shop/inventory preview

# Procedural/Animation
@export var is_procedural: bool = false
@export var is_animated: bool = false
@export var procedural_script_path: String = ""  # Path to procedural generator script
@export var animation_metadata: Dictionary = {}  # Animation settings

# Board specific (also used for menu_background)
@export var background_type: String = "color"  # color, sprite, scene
@export var background_scene_path: String = ""
@export var colors: Dictionary = {}  # primary, secondary, etc.
@export var can_be_menu_background: bool = false  # TODO: Allow boards to be menu backgrounds

# Mini Profile Card specific - TODO: Implement mini profile system
@export_group("Mini Profile Settings")
@export_enum("standard", "compact", "detailed", "animated") var mini_profile_layout: String = "standard"
@export var showcase_slots: int = 3  # How many items/achievements/stats can be shown
@export var stat_positions: Dictionary = {}  # Where stats appear on the card
@export var achievement_positions: Dictionary = {}  # Where achievements appear
@export var item_positions: Dictionary = {}  # Where showcased items appear
@export var supports_animation: bool = false  # If the mini profile can animate

# TopBar skin specific - TODO: Implement topbar customization
@export_group("TopBar Settings")
@export var topbar_gradient: Gradient  # Background gradient for topbar
@export var topbar_button_style: String = "default"  # Button visual style
@export var topbar_font: String = ""  # Custom font for topbar
@export var timer_bar_color: Color = Color.WHITE
@export var draw_pile_tint: Color = Color.WHITE

# Combo Effect specific - TODO: Implement combo visual effects
@export_group("Combo Effect Settings")
@export var combo_threshold: int = 5  # When effect starts
@export var effect_intensity_curve: Curve  # How effect scales with combo
@export var particle_scene_path: String = ""  # Path to particle effect
@export var border_shader_path: String = ""  # Path to border shader
@export var sound_effect_path: String = ""  # Path to combo sound
@export_enum("fire", "lightning", "ice", "rainbow", "cosmic") var effect_type: String = "fire"
@export var max_combo_visuals: int = 20  # Cap for performance

# Economy
@export var base_price: int = 0
@export var is_purchasable: bool = true
@export var is_tradeable: bool = false
@export var unlock_level: int = 0

# Source and acquisition
@export_enum("default", "shop", "achievement", "event", "bundle", "referral", "season_pass", "tournament", "quest") var source: String = "shop"
@export var achievement_id: String = ""  # If from achievement
@export var event_id: String = ""  # If from event
@export var quest_id: String = ""  # TODO: If from quest system

# Metadata
@export var sort_order: int = 0
@export var tags: Array[String] = []
@export var release_date: String = ""
@export var is_limited_time: bool = false
@export var expiry_date: String = ""

# Future features placeholders
@export_group("Future Features")
@export var supports_color_customization: bool = false  # TODO: Allow color picker
@export var supports_user_upload: bool = false  # TODO: Custom avatars/frames
@export var blockchain_id: String = ""  # TODO: NFT integration (maybe never)
@export var workshop_id: String = ""  # TODO: Steam Workshop support

# Conversion helpers
func from_item_data(item: ItemData) -> void:
	"""Convert from old ItemData format"""
	id = item.id
	display_name = item.display_name
	description = item.description
	
	# Map category enum to string
	category = _map_item_category(item.category)
	rarity = _map_rarity(item.rarity)
	
	set_name = item.set_name
	subcategory = item.subcategory
	
	icon_path = item.icon_path
	texture_path = item.texture_path
	preview_texture_path = item.preview_texture_path
	
	background_type = item.background_type
	background_scene_path = item.background_scene_path
	colors = item.colors
	
	base_price = item.base_price
	is_purchasable = item.is_purchasable
	is_tradeable = item.is_tradeable
	unlock_level = item.unlock_level
	
	source = _map_source(item.source)
	achievement_id = item.achievement_id
	event_id = item.event_id
	
	sort_order = item.sort_order
	tags = item.tags
	release_date = item.release_date
	is_limited_time = item.is_limited_time
	expiry_date = item.expiry_date

func from_shop_item(item: ShopManager.ShopItem) -> void:
	"""Convert from ShopManager.ShopItem format"""
	id = item.id
	display_name = item.display_name
	description = item.description
	
	category = _map_shop_category(item.category)
	rarity = _map_shop_rarity(item.rarity)
	
	icon_path = item.preview_texture_path
	texture_path = item.preview_texture_path
	
	base_price = item.price
	is_purchasable = true
	unlock_level = item.level_requirement

func from_procedural_instance(instance: Object, item_category: String) -> void:
	"""Convert from procedural item instance"""
	if not instance:
		return
		
	if instance.has_method("get"):
		id = instance.get("item_id") if instance.get("item_id") else ""
		display_name = instance.get("display_name") if instance.get("display_name") else ""
		category = item_category
		
		is_procedural = true
		is_animated = instance.get("is_animated") if instance.get("is_animated") else false
		
		# Store rarity if available
		if instance.get("item_rarity"):
			rarity = _map_item_rarity_enum(instance.item_rarity)

func to_item_data() -> ItemData:
	"""Convert to old ItemData format for compatibility"""
	var item = ItemData.new()
	
	item.id = id
	item.display_name = display_name
	item.description = description
	
	item.category = _unmap_item_category(category)
	item.rarity = _unmap_rarity(rarity)
	
	item.set_name = set_name
	item.subcategory = subcategory
	
	item.icon_path = icon_path
	item.texture_path = texture_path
	item.preview_texture_path = preview_texture_path
	
	item.background_type = background_type
	item.background_scene_path = background_scene_path
	item.colors = colors
	
	item.base_price = base_price
	item.is_purchasable = is_purchasable
	item.is_tradeable = is_tradeable
	item.unlock_level = unlock_level
	
	item.source = _unmap_source(source)
	item.achievement_id = achievement_id
	item.event_id = event_id
	
	item.sort_order = sort_order
	item.tags = tags
	item.release_date = release_date
	item.is_limited_time = is_limited_time
	item.expiry_date = expiry_date
	
	return item

# Mapping functions
func _map_item_category(cat: ItemData.Category) -> String:
	match cat:
		ItemData.Category.CARD_FRONT: return "card_front"
		ItemData.Category.CARD_BACK: return "card_back"
		ItemData.Category.BOARD: return "board"
		ItemData.Category.FRAME: return "frame"
		ItemData.Category.AVATAR: return "avatar"
		ItemData.Category.EMOJI: return "emoji"
		ItemData.Category.MINI_PROFILE_CARD: return "mini_profile"
		_: return "card_front"

func _unmap_item_category(cat: String) -> ItemData.Category:
	match cat:
		"card_front": return ItemData.Category.CARD_FRONT
		"card_back": return ItemData.Category.CARD_BACK
		"board": return ItemData.Category.BOARD
		"frame": return ItemData.Category.FRAME
		"avatar": return ItemData.Category.AVATAR
		"emoji": return ItemData.Category.EMOJI
		"mini_profile": return ItemData.Category.MINI_PROFILE_CARD
		# Future categories default to CARD_FRONT for now
		"topbar", "combo_effect", "menu_background": 
			push_warning("TODO: Add ItemData.Category for " + cat)
			return ItemData.Category.CARD_FRONT
		_: return ItemData.Category.CARD_FRONT

func _map_shop_category(cat: String) -> String:
	match cat:
		"card_skins", "card_fronts": return "card_front"
		"card_backs": return "card_back"
		"board_skins", "boards": return "board"
		"frames": return "frame"
		"avatars": return "avatar"
		"emojis": return "emoji"
		"mini_profiles": return "mini_profile"
		"topbars": return "topbar"
		"combo_effects": return "combo_effect"
		_: return "card_front"

func _map_rarity(r: ItemData.Rarity) -> String:
	match r:
		ItemData.Rarity.COMMON: return "common"
		ItemData.Rarity.UNCOMMON: return "uncommon"
		ItemData.Rarity.RARE: return "rare"
		ItemData.Rarity.EPIC: return "epic"
		ItemData.Rarity.LEGENDARY: return "legendary"
		ItemData.Rarity.MYTHIC: return "mythic"
		_: return "common"

func _unmap_rarity(r: String) -> ItemData.Rarity:
	match r:
		"common": return ItemData.Rarity.COMMON
		"uncommon": return ItemData.Rarity.UNCOMMON
		"rare": return ItemData.Rarity.RARE
		"epic": return ItemData.Rarity.EPIC
		"legendary": return ItemData.Rarity.LEGENDARY
		"mythic": return ItemData.Rarity.MYTHIC
		_: return ItemData.Rarity.COMMON

func _map_shop_rarity(r: ShopManager.Rarity) -> String:
	match r:
		ShopManager.Rarity.COMMON: return "common"
		ShopManager.Rarity.UNCOMMON: return "uncommon"
		ShopManager.Rarity.RARE: return "rare"
		ShopManager.Rarity.EPIC: return "epic"
		ShopManager.Rarity.LEGENDARY: return "legendary"
		ShopManager.Rarity.MYTHIC: return "mythic"
		_: return "common"

func _map_item_rarity_enum(r) -> String:
	if r == ItemData.Rarity.COMMON: return "common"
	elif r == ItemData.Rarity.UNCOMMON: return "uncommon"
	elif r == ItemData.Rarity.RARE: return "rare"
	elif r == ItemData.Rarity.EPIC: return "epic"
	elif r == ItemData.Rarity.LEGENDARY: return "legendary"
	elif r == ItemData.Rarity.MYTHIC: return "mythic"
	else: return "common"

func _map_source(s: ItemData.Source) -> String:
	match s:
		ItemData.Source.DEFAULT: return "default"
		ItemData.Source.SHOP: return "shop"
		ItemData.Source.ACHIEVEMENT: return "achievement"
		ItemData.Source.EVENT: return "event"
		ItemData.Source.BUNDLE: return "bundle"
		ItemData.Source.REFERRAL: return "referral"
		ItemData.Source.SEASON_PASS: return "season_pass"
		_: return "shop"

func _unmap_source(s: String) -> ItemData.Source:
	match s:
		"default": return ItemData.Source.DEFAULT
		"shop": return ItemData.Source.SHOP
		"achievement": return ItemData.Source.ACHIEVEMENT
		"event": return ItemData.Source.EVENT
		"bundle": return ItemData.Source.BUNDLE
		"referral": return ItemData.Source.REFERRAL
		"season_pass": return ItemData.Source.SEASON_PASS
		# Future sources
		"tournament", "quest":
			push_warning("TODO: Add ItemData.Source for " + s)
			return ItemData.Source.SHOP
		_: return ItemData.Source.SHOP

# Utility functions
func get_rarity_color() -> Color:
	match rarity:
		"common": return UIStyleManager.get_rarity_color("common")
		"uncommon": return UIStyleManager.get_rarity_color("uncommon")
		"rare": return UIStyleManager.get_rarity_color("rare")
		"epic": return UIStyleManager.get_rarity_color("epic")
		"legendary": return UIStyleManager.get_rarity_color("legendary")
		"mythic": return UIStyleManager.get_rarity_color("mythic")
		_: return Color.WHITE

func get_price_with_rarity_multiplier() -> int:
	var multiplier = 1.0
	match rarity:
		"uncommon": multiplier = 1.5
		"rare": multiplier = 2.0
		"epic": multiplier = 3.0
		"legendary": multiplier = 5.0
		"mythic": multiplier = 10.0
	
	return int(base_price * multiplier)

func is_owned() -> bool:
	# TODO: Check with EquipmentManager when it exists
	push_warning("TODO: Implement is_owned() with EquipmentManager")
	return false

func is_equipped() -> bool:
	# TODO: Check with EquipmentManager when it exists
	push_warning("TODO: Implement is_equipped() with EquipmentManager")
	return false

# Future category helpers
func is_future_category() -> bool:
	"""Check if this item is from a not-yet-implemented category"""
	return category in ["topbar", "combo_effect", "menu_background"]

func get_todo_message() -> String:
	"""Get the TODO message for this category"""
	match category:
		"mini_profile": return "TODO: Implement mini profile card system"
		"topbar": return "TODO: Implement topbar customization"
		"combo_effect": return "TODO: Implement combo visual effects"
		"menu_background": return "TODO: Implement menu background system"
		_: return ""
