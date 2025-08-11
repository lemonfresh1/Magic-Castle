# ShopManager.gd - Manages shop inventory, purchases, sales, and multi-currency support
# Location: res://Pyramids/scripts/autoloads/ShopManager.gd
# Last Updated: Integrated with ItemManager, removed CosmeticManager dependency [Date]

extends Node

signal item_purchased(item_id: String, price: int, currency: String)
signal item_equipped(item_id: String, category: String)
signal shop_refreshed(new_sales: Array)
signal preview_requested(item_id: String)
signal insufficient_funds(needed: int, current: int, currency: String)

const SAVE_PATH = "user://shop_data.save"

# Match AchievementManager's rarity system
enum Rarity {
	COMMON,      # Gray - 50 stars
	UNCOMMON,    # Green - 100 stars
	RARE,        # Blue - 250 stars
	EPIC,        # Purple - 500 stars
	LEGENDARY,   # Orange - 1000 stars
	MYTHIC       # Red - Not purchasable
}

# Base prices matching design doc
const RARITY_PRICES = {
	Rarity.COMMON: 50,
	Rarity.UNCOMMON: 100,
	Rarity.RARE: 250,
	Rarity.EPIC: 500,
	Rarity.LEGENDARY: 1000,
	Rarity.MYTHIC: -1  # Not for sale
}

# Category price multipliers
const CATEGORY_MULTIPLIERS = {
	"card_skins": 1.0,
	"board_skins": 1.0,
	"avatars": 0.5,
	"frames": 0.5,
	"emojis": 0.5,
	"sounds": 0.5,      # Future
	"music": 0.5,       # Future
	"sound_emojis": 0.5 # Future (higher rarities only)
}

# Shop item structure
class ShopItem extends Resource:
	@export var id: String = ""
	@export var display_name: String = ""
	@export var category: String = ""
	@export var rarity: Rarity = Rarity.COMMON
	@export var base_price: int = 50
	@export var currency_type: String = "stars"  # stars, event_tokens, etc
	@export var preview_texture_path: String = ""  # Path to texture
#	@export var resource_path: String = ""  # Path to actual skin/cosmetic
	@export var unlock_level: int = 0  # Level required to purchase
	@export var is_featured: bool = false
	@export var bundle_items: Array[String] = []  # IDs of bundled items
	@export var placeholder_icon: String = ""  # For food icons during development

# Shop save data
var shop_data = {
	"owned_items": [],
	"equipped": {
		"card_skin": "default",
		"board_skin": "green",
		"avatar": "default",
		"frame": "basic",
		"selected_emojis": []  # 8 max
	},
	"purchase_history": [],
	"last_shop_refresh": "",
	"current_sales": [],
	"trial_used": []
}

# Launch inventory - using food placeholders for now
var shop_inventory = {}

func _ready():
	_initialize_shop_inventory()
	_sync_with_item_manager() 
	load_shop_data()
	_check_daily_refresh()
	
	# Connect to StarManager for purchase validation
	if StarManager and not StarManager.stars_changed.is_connected(_on_stars_changed):
		StarManager.stars_changed.connect(_on_stars_changed)

func _initialize_shop_inventory():
	# Card Skins
	_add_item("card_classic", "Classic", "card_skins", Rarity.COMMON, "01_dish.png")
	_add_item("card_neon", "Neon", "card_skins", Rarity.UNCOMMON, "02_dish_2.png")
	_add_item("card_wood", "Wooden", "card_skins", Rarity.RARE, "03_dish_pile.png")
	_add_item("card_metal", "Metal", "card_skins", Rarity.EPIC, "04_bowl.png")
	_add_item("card_galaxy", "Galaxy", "card_skins", Rarity.LEGENDARY, "05_apple_pie.png")
	
	# Board Skins
	_add_item("board_green", "Green", "board_skins", Rarity.COMMON, "07_bread.png")
	_add_item("board_blue", "Ocean Blue", "board_skins", Rarity.UNCOMMON, "08_bread_dish.png")
	_add_item("board_sunset", "Sunset", "board_skins", Rarity.RARE, "09_baguette.png")
	_add_item("board_night", "Night Sky", "board_skins", Rarity.EPIC, "10_baguette_dish.png")
	_add_item("board_castle", "Castle", "board_skins", Rarity.LEGENDARY, "11_bun.png")
	
	# Avatars (50% price)
	_add_item("avatar_knight", "Knight", "avatars", Rarity.UNCOMMON, "15_burger.png")
	_add_item("avatar_wizard", "Wizard", "avatars", Rarity.UNCOMMON, "16_burger_dish.png")
	
	# Frames (50% price)
	_add_item("frame_bronze", "Bronze", "frames", Rarity.COMMON, "26_chocolate.png")
	_add_item("frame_silver", "Silver", "frames", Rarity.RARE, "27_chocolate_dish.png")
	
	# Emojis (50% price)
	_add_item("emoji_smile", "Smile", "emojis", Rarity.COMMON, "57_icecream.png")
	_add_item("emoji_frown", "Frown", "emojis", Rarity.COMMON, "58_icecream_bowl.png")

	# card bacls
	_add_item("card_back_classic_pyramids_gold", "Classic Pyramids Gold", "card_backs", Rarity.EPIC, "04_bowl.png")

	# Set some defaults as owned
	shop_data.owned_items.append("card_classic")
	shop_data.owned_items.append("board_green")
	shop_data.owned_items.append("avatar_default")
	shop_data.owned_items.append("frame_basic")

func _add_item(id: String, name: String, category: String, rarity: Rarity, icon: String):
	var item = ShopItem.new()
	item.id = id
	item.display_name = name
	item.category = category
	item.rarity = rarity
	item.base_price = _calculate_item_price(category, rarity)
	item.placeholder_icon = icon
	shop_inventory[id] = item

func _calculate_item_price(category: String, rarity: Rarity) -> int:
	var base_price = RARITY_PRICES[rarity]
	if base_price == -1:  # Mythic
		return -1
	
	var multiplier = CATEGORY_MULTIPLIERS.get(category, 1.0)
	return int(base_price * multiplier)

func can_afford_item(item_id: String) -> bool:
	var item = shop_inventory.get(item_id)
	if not item:
		return false
		
	var price = get_item_price(item_id)
	
	match item.currency_type:
		"stars":
			return StarManager.get_balance() >= price
		"event_tokens":
			# Future: return EventManager.get_tokens() >= price
			return false
		_:
			return false

func purchase_item(item_id: String) -> bool:
	var item = shop_inventory.get(item_id)
	if not item:
		print("Item not found: ", item_id)
		return false
		
	if is_item_owned(item_id):
		print("Item already owned: ", item_id)
		return false
		
	var price = get_item_price(item_id)
	
	if not can_afford_item(item_id):
		var current = StarManager.get_balance() if item.currency_type == "stars" else 0
		insufficient_funds.emit(price, current, item.currency_type)
		return false
	
	# Check level requirement
	if item.unlock_level > 0:
		# Future: Check XPManager.get_current_level()
		pass
	
	# Spend currency
	var success = false
	match item.currency_type:
		"stars":
			success = StarManager.spend_stars(price, "shop_purchase")
		"event_tokens":
			# Future: success = EventManager.spend_tokens(price)
			pass
	
	if success:
		# Add to owned items
		shop_data.owned_items.append(item_id)
		
		# Track purchase
		shop_data.purchase_history.append({
			"item_id": item_id,
			"price": price,
			"currency": item.currency_type,
			"date": Time.get_datetime_string_from_system()
		})
		
		save_shop_data()
		item_purchased.emit(item_id, price, item.currency_type)
		
		# Grant item through ItemManager
		if ItemManager:
			ItemManager.grant_item(item_id, ItemData.Source.SHOP)
		
		return true
	
	return false

func grant_item(item_id: String) -> bool:
	"""Grant an item through ItemManager - DEPRECATED, use ItemManager directly"""
	push_warning("ShopManager.grant_item() is deprecated. Use ItemManager.grant_item() directly.")
	
	if ItemManager:
		# Use SHOP source for backward compatibility
		return ItemManager.grant_item(item_id, ItemData.Source.SHOP)
	else:
		push_error("ShopManager: ItemManager not found!")
		return false

func _update_cosmetic_managers(item_id: String, category: String):
	# This function is deprecated - ItemManager handles everything now
	# Keeping empty for compatibility
	pass

func equip_item(item_id: String) -> bool:
	# Delegate to ItemManager
	if ItemManager:
		return ItemManager.equip_item(item_id)
	
	# Fallback to old system if ItemManager not available
	var item = shop_inventory.get(item_id)
	if not item or not is_item_owned(item_id):
		return false
		
	# Update equipped items
	match item.category:
		"card_skins":
			shop_data.equipped.card_skin = item_id
		"board_skins":
			shop_data.equipped.board_skin = item_id
		"avatars":
			shop_data.equipped.avatar = item_id
		"frames":
			shop_data.equipped.frame = item_id
		"emojis":
			if item_id not in shop_data.equipped.selected_emojis:
				if shop_data.equipped.selected_emojis.size() < 8:
					shop_data.equipped.selected_emojis.append(item_id)
	
	save_shop_data()
	item_equipped.emit(item_id, item.category)
	return true

func get_item_price(item_id: String) -> int:
	var item = shop_inventory.get(item_id)
	if not item:
		return -1
		
	# Check if on sale
	if item_id in shop_data.current_sales:
		return int(item.base_price * 0.67)  # 33% off
		
	return item.base_price

func is_item_on_sale(item_id: String) -> bool:
	return item_id in shop_data.current_sales

func is_item_owned(item_id: String) -> bool:
	# Check ItemManager first (source of truth)
	if ItemManager:
		return ItemManager.is_item_owned(item_id)
	# Fallback to local data
	return item_id in shop_data.owned_items

func is_item_new(item_id: String) -> bool:
	# Check if added in last 7 days
	# For now, just return featured status
	var item = shop_inventory.get(item_id)
	return item and item.is_featured

func get_items_by_category(category: String) -> Array:
	var items = []
	
	# First try to get from ItemManager for accurate data
	if ItemManager and category == "board_skins":
		var boards = ItemManager.get_items_by_category(ItemData.Category.BOARD)
		for board in boards:
			# Convert ItemData to ShopItem for compatibility
			if shop_inventory.has(board.id):
				items.append(shop_inventory[board.id])
			else:
				# Create temporary ShopItem from ItemData
				var shop_item = _create_shop_item_from_itemdata(board)
				items.append(shop_item)
		return items
	
	# Fallback to existing logic
	for id in shop_inventory:
		if shop_inventory[id].category == category:
			items.append(shop_inventory[id])
	return items

func get_all_items() -> Array:
	var items = []
	for id in shop_inventory:
		items.append(shop_inventory[id])
	return items

func get_featured_items() -> Array:
	var items = []
	for id in shop_inventory:
		var item = shop_inventory[id]
		if item.is_featured or is_item_on_sale(id):
			items.append(item)
	return items

func _check_daily_refresh():
	var current_date = Time.get_datetime_string_from_system().split("T")[0]
	var last_refresh = shop_data.last_shop_refresh.split("T")[0] if shop_data.last_shop_refresh else ""
	
	if current_date != last_refresh:
		refresh_daily_sale()

func refresh_daily_sale():
	# Select random item for sale (excluding already owned and mythic)
	var eligible_items = []
	for id in shop_inventory:
		var item = shop_inventory[id]
		if not is_item_owned(id) and item.rarity != Rarity.MYTHIC:
			eligible_items.append(id)
	
	if eligible_items.size() > 0:
		shop_data.current_sales.clear()
		var sale_item = eligible_items[randi() % eligible_items.size()]
		shop_data.current_sales.append(sale_item)
		
	shop_data.last_shop_refresh = Time.get_datetime_string_from_system()
	save_shop_data()
	shop_refreshed.emit(shop_data.current_sales)

func get_rarity_color(rarity: Rarity) -> Color:
	# Match AchievementManager colors
	match rarity:
		Rarity.COMMON: return Color(0.6, 0.6, 0.6)      # Gray
		Rarity.UNCOMMON: return Color(0.3, 0.8, 0.3)    # Green
		Rarity.RARE: return Color(0.3, 0.5, 0.9)        # Blue
		Rarity.EPIC: return Color(0.7, 0.3, 0.9)        # Purple
		Rarity.LEGENDARY: return Color(0.9, 0.6, 0.2)   # Orange
		Rarity.MYTHIC: return Color(0.9, 0.2, 0.2)      # Red
		_: return Color.WHITE

func save_shop_data():
	var save_dict = {
		"version": 1,
		"data": shop_data
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_dict)
		file.close()

func load_shop_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var save_dict = file.get_var()
			file.close()
			
			if save_dict and save_dict.has("data"):
				shop_data = save_dict.data
				# Migrate if needed based on version

func _on_stars_changed(new_amount: int):
	# Could update UI here if needed
	pass

func reset_shop_data():
	shop_data = {
		"owned_items": ["card_classic", "board_green", "avatar_default", "frame_basic"],
		"equipped": {
			"card_skin": "card_classic",
			"board_skin": "board_green", 
			"avatar": "avatar_default",
			"frame": "frame_basic",
			"selected_emojis": []
		},
		"purchase_history": [],
		"last_shop_refresh": "",
		"current_sales": [],
		"trial_used": []
	}
	save_shop_data()

# Add this function to ShopManager.gd:

# Update ShopManager.gd to use icons from ItemData:

func _sync_with_item_manager():
	"""Load items from ItemManager and use their actual icons"""
	if not ItemManager:
		return
	
	# Sync all categories INCLUDING CARD_BACK
	_sync_category(ItemData.Category.CARD_FRONT, "card_fronts")
	_sync_category(ItemData.Category.CARD_BACK, "card_backs")  # ADD THIS
	_sync_category(ItemData.Category.BOARD, "board_skins")
	_sync_category(ItemData.Category.AVATAR, "avatars")
	_sync_category(ItemData.Category.FRAME, "frames")
	_sync_category(ItemData.Category.EMOJI, "emojis")

func _sync_category(item_category: ItemData.Category, shop_category: String):
	"""Sync a specific category from ItemManager"""
	var items = ItemManager.get_items_by_category(item_category)
	
	for item in items:
		# Only skip if explicitly not purchasable
		if not item.is_purchasable:
			continue
		
		# Check if already in shop inventory
		if shop_inventory.has(item.id):
			# Update existing item with ItemData info
			var shop_item = shop_inventory[item.id]
			shop_item.preview_texture_path = item.icon_path  # Use actual icon!
		else:
			# Create new shop item from ItemData
			var shop_item = ShopItem.new()
			shop_item.id = item.id
			shop_item.display_name = item.display_name
			shop_item.category = shop_category
			shop_item.rarity = item.rarity
			shop_item.base_price = item.base_price if item.base_price > 0 else _calculate_item_price(shop_category, item.rarity)
			shop_item.currency_type = item.currency_type
			shop_item.preview_texture_path = item.icon_path  # Use actual icon!
			shop_item.unlock_level = item.unlock_level
			shop_item.is_featured = item.is_new or item.is_limited
			
			# Only use placeholder if no icon path is set
			if item.icon_path == "" or not ResourceLoader.exists(item.icon_path):
				shop_item.placeholder_icon = _get_placeholder_icon_for_rarity(item.rarity)
			
			shop_inventory[item.id] = shop_item

func _get_placeholder_icon_for_rarity(rarity: ItemData.Rarity) -> String:
	"""Return placeholder icon based on rarity"""
	match rarity:
		ItemData.Rarity.COMMON: return "07_bread.png"
		ItemData.Rarity.UNCOMMON: return "08_bread_dish.png"
		ItemData.Rarity.RARE: return "09_baguette.png"
		ItemData.Rarity.EPIC: return "10_baguette_dish.png"
		ItemData.Rarity.LEGENDARY: return "11_bun.png"
		_: return "01_dish.png"

func _create_shop_item_from_itemdata(item_data: ItemData) -> ShopItem:
	"""Convert ItemData to ShopItem for display"""
	var shop_item = ShopItem.new()
	shop_item.id = item_data.id
	shop_item.display_name = item_data.display_name
	shop_item.category = _get_shop_category_from_itemdata(item_data.category)
	shop_item.rarity = item_data.rarity
	shop_item.base_price = item_data.base_price
	shop_item.currency_type = item_data.currency_type
	shop_item.preview_texture_path = item_data.icon_path  # Use the actual icon!
	shop_item.unlock_level = item_data.unlock_level
	shop_item.is_featured = item_data.is_new
	return shop_item

func _get_shop_category_from_itemdata(category: ItemData.Category) -> String:
	match category:
		ItemData.Category.CARD_FRONT: return "card_fronts"  # Changed from card_skins
		ItemData.Category.CARD_BACK: return "card_backs"   # This is correct
		ItemData.Category.BOARD: return "board_skins"
		ItemData.Category.FRAME: return "frames"
		ItemData.Category.AVATAR: return "avatars"
		ItemData.Category.EMOJI: return "emojis"
		_: return "misc"
