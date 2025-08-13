# ItemDatabase.gd - Central repository for all item definitions and instances
# Location: res://Pyramids/scripts/autoloads/ItemDatabase.gd
# Last Updated: Created with lazy loading and caching [Date]

extends Node

# Signals
signal items_loaded(count: int)
signal item_registered(item_id: String)
signal database_ready()

# Paths
const ITEMS_BASE_PATH = "res://Pyramids/resources/items/"
const PROCEDURAL_BASE_PATH = "res://Pyramids/scripts/items/"
const CACHE_PATH = "user://item_cache.dat"

# Categories to scan - including future ones
const CATEGORIES = [
	"card_fronts",
	"card_backs",
	"boards",
	"frames",
	"avatars",
	"emojis",
	"mini_profiles",     # TODO: Implement mini profile cards
	"topbars",          # TODO: Implement topbar skins
	"combo_effects",    # TODO: Implement combo visual effects
	"menu_backgrounds"  # TODO: Implement menu backgrounds
]

# Runtime storage
var all_items: Dictionary = {}  # item_id -> UnifiedItemData
var items_by_category: Dictionary = {}  # category -> Array[UnifiedItemData]
var items_by_rarity: Dictionary = {}  # rarity -> Array[UnifiedItemData]
var items_by_set: Dictionary = {}  # set_name -> Array[UnifiedItemData]
var procedural_instances: Dictionary = {}  # item_id -> instance (for animated items)

# Loading state
var is_loaded: bool = false
var load_progress: float = 0.0

func _ready():
	print("ItemDatabase initializing...")
	_initialize_categories()
	load_all_items()
	
	# DEBUG: Check if your items loaded
	print("\n=== CHECKING NEW ITEMS ===")
	var pyramid_board = get_item("board_pyramids")
	if pyramid_board:
		print("✓ Board loaded: ", pyramid_board.display_name)
		print("  - Animated: ", pyramid_board.is_animated)
		print("  - Scene: ", pyramid_board.background_scene_path)
	else:
		print("✗ Board NOT found")
		
	var gold_back = get_item("card_back_classic_pyramids_gold")
	if gold_back:
		print("✓ Card back loaded: ", gold_back.display_name)
		print("  - Procedural: ", gold_back.is_procedural)
		print("  - Script: ", gold_back.procedural_script_path)
	else:
		print("✗ Card back NOT found")

func _initialize_categories():
	"""Initialize empty arrays for all categories"""
	for category in CATEGORIES:
		items_by_category[category] = []
	
	# Initialize rarity arrays
	for rarity in ["common", "uncommon", "rare", "epic", "legendary", "mythic"]:
		items_by_rarity[rarity] = []

# === MAIN LOADING ===

func load_all_items():
	"""Load all items from resources and procedural sources"""
	var start_time = Time.get_ticks_msec()
	
	# Load static resources
	_load_resource_items()
	
	# Load procedural items
	_load_procedural_items()
	
	# Migrate from old systems
	_import_from_legacy_systems()
	
	# Build indexes
	_build_indexes()
	
	# Create default items if missing
	_ensure_default_items()
	
	var load_time = Time.get_ticks_msec() - start_time
	print("ItemDatabase: Loaded %d items in %d ms" % [all_items.size(), load_time])
	
	is_loaded = true
	database_ready.emit()
	items_loaded.emit(all_items.size())

func _load_resource_items():
	"""Load all .tres item resources"""
	for category in CATEGORIES:
		var path = ITEMS_BASE_PATH + category + "/"
		
		# Skip future categories that don't have folders yet
		if not DirAccess.dir_exists_absolute(path):
			if category in ["mini_profiles", "topbars", "combo_effects", "menu_backgrounds"]:
				print("ItemDatabase: Skipping future category: %s" % category)
				continue
			else:
				print("ItemDatabase: Creating missing directory: %s" % path)
				DirAccess.make_dir_recursive_absolute(path)
				continue
		
		_scan_directory_for_items(path, category)

func _scan_directory_for_items(path: String, category: String):
	"""Scan a directory for item resources"""
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = path + file_name
			_load_item_resource(resource_path, category)
		
		file_name = dir.get_next()

func _load_item_resource(path: String, category: String):
	"""Load a single item resource and convert to UnifiedItemData"""
	var resource = load(path)
	
	if not resource:
		push_warning("ItemDatabase: Failed to load resource: " + path)
		return
	
	var unified: UnifiedItemData
	
	# Check if it's already a UnifiedItemData
	if resource is UnifiedItemData:
		unified = resource
	else:
		push_warning("ItemDatabase: Resource is not UnifiedItemData: " + path)
		return
	
	# Validate and register
	if unified.id != "":
		register_item(unified)
	else:
		push_warning("ItemDatabase: Item has no ID: " + path)

func _load_procedural_items():
	"""Load all procedural item definitions"""
	if not ProceduralItemRegistry:
		push_warning("ItemDatabase: ProceduralItemRegistry not found")
		return
	
	# Ensure ProceduralItemRegistry has discovered items
	if ProceduralItemRegistry.procedural_items.is_empty():
		ProceduralItemRegistry.discover_and_register_all()
	
	# Import all procedural items
	for item_id in ProceduralItemRegistry.procedural_items:
		var proc_data = ProceduralItemRegistry.procedural_items[item_id]
		var instance = proc_data.instance
		
		if not instance:
			continue
		
		var unified = UnifiedItemData.new()
		
		# Convert string category to enum
		var category_enum = _string_to_category(proc_data.category)
		unified.from_procedural_instance(instance, category_enum)
		
		# Ensure ID is set
		if unified.id == "":
			unified.id = item_id
		
		# Mark as procedural and store instance
		unified.is_procedural = true
		unified.procedural_script_path = proc_data.script_path
		procedural_instances[item_id] = instance
		
		register_item(unified)

func _import_from_legacy_systems():
	"""Import items from ItemManager and ShopManager"""
	var imported_count = 0
	
	# Import from ItemManager
	if ItemManager and ItemManager.all_items:
		for item_id in ItemManager.all_items:
			if not all_items.has(item_id):
				var item_data = ItemManager.all_items[item_id]
				# ItemManager already stores UnifiedItemData
				if item_data is UnifiedItemData:
					register_item(item_data)
					imported_count += 1
	
	# Import from ShopManager
	if ShopManager and ShopManager.shop_inventory:
		for shop_item_id in ShopManager.shop_inventory:
			if not all_items.has(shop_item_id):
				var shop_item = ShopManager.shop_inventory[shop_item_id]
				var unified = UnifiedItemData.new()
				unified.from_shop_item(shop_item)
				register_item(unified)
				imported_count += 1
	
	if imported_count > 0:
		print("ItemDatabase: Imported %d items from legacy systems" % imported_count)

func _ensure_default_items():
	"""Create default items if they don't exist"""
	# Card Classic
	if not all_items.has("card_classic"):
		var classic_card = UnifiedItemData.new()
		classic_card.id = "card_classic"
		classic_card.display_name = "Classic Cards"
		classic_card.description = "The original card design"
		classic_card.category = UnifiedItemData.Category.CARD_FRONT
		classic_card.rarity = UnifiedItemData.Rarity.COMMON
		classic_card.source = UnifiedItemData.Source.DEFAULT
		classic_card.base_price = 0
		classic_card.is_purchasable = false
		register_item(classic_card)
		print("ItemDatabase: Created default card_classic")
	
	# Board Green
	if not all_items.has("board_green"):
		var green_board = UnifiedItemData.new()
		green_board.id = "board_green"
		green_board.display_name = "Classic Green"
		green_board.description = "The classic green felt board"
		green_board.category = UnifiedItemData.Category.BOARD
		green_board.rarity = UnifiedItemData.Rarity.COMMON
		green_board.source = UnifiedItemData.Source.DEFAULT
		green_board.base_price = 0
		green_board.is_purchasable = false
		green_board.colors = {"primary": Color(0.2, 0.5, 0.2)}
		register_item(green_board)
		print("ItemDatabase: Created default board_green")

func _build_indexes():
	"""Build category, rarity, and set indexes"""
	# Clear existing indexes
	for category in items_by_category:
		items_by_category[category].clear()
	for rarity in items_by_rarity:
		items_by_rarity[rarity].clear()
	items_by_set.clear()
	
	# Rebuild indexes
	for item_id in all_items:
		var item = all_items[item_id]
		
		# Add to category index - convert enum to string
		var category_str = _category_to_string(item.category)
		if items_by_category.has(category_str):
			items_by_category[category_str].append(item)
		
		# Add to rarity index - convert enum to string
		var rarity_str = item.get_rarity_name().to_lower()
		if items_by_rarity.has(rarity_str):
			items_by_rarity[rarity_str].append(item)
		
		# Add to set index
		if item.set_name != "":
			if not items_by_set.has(item.set_name):
				items_by_set[item.set_name] = []
			items_by_set[item.set_name].append(item)
	
	# Sort categories by sort_order
	for category in items_by_category:
		items_by_category[category].sort_custom(func(a, b): return a.sort_order < b.sort_order)

# === REGISTRATION ===

func register_item(item: UnifiedItemData) -> bool:
	"""Register an item in the database"""
	if item.id == "":
		push_error("ItemDatabase: Cannot register item with empty ID")
		return false
	
	if all_items.has(item.id):
		push_warning("ItemDatabase: Item already registered: " + item.id)
		return false
	
	all_items[item.id] = item
	item_registered.emit(item.id)
	
	return true

# === QUERIES ===

func get_item(item_id: String) -> UnifiedItemData:
	"""Get a single item by ID"""
	return all_items.get(item_id)

func get_procedural_instance(item_id: String):
	"""Get the procedural instance for animated items"""
	return procedural_instances.get(item_id)

func get_items_by_category(category: String) -> Array:
	"""Get all items in a category"""
	return items_by_category.get(category, [])

func get_items_by_rarity(rarity: String) -> Array:
	"""Get all items of a specific rarity"""
	return items_by_rarity.get(rarity, [])

func get_items_by_set(set_name: String) -> Array:
	"""Get all items in a set"""
	return items_by_set.get(set_name, [])

func get_all_items() -> Dictionary:
	"""Get all items as a dictionary"""
	return all_items.duplicate()

func get_owned_items() -> Array:
	"""Get all items owned by the player"""
	var owned = []
	for item_id in all_items:
		if EquipmentManager.is_item_owned(item_id):
			owned.append(all_items[item_id])
	return owned

func get_equipped_items() -> Array:
	"""Get all currently equipped items"""
	var equipped = []
	var equipped_data = EquipmentManager.get_equipped_items()
	
	for category in equipped_data:
		var value = equipped_data[category]
		
		if value is String and value != "":
			var item = get_item(value)
			if item:
				equipped.append(item)
		elif value is Array:  # For emojis
			for item_id in value:
				var item = get_item(item_id)
				if item:
					equipped.append(item)
	
	return equipped

func search_items(query: String) -> Array:
	"""Search items by name or description"""
	var results = []
	var search_term = query.to_lower()
	
	for item_id in all_items:
		var item = all_items[item_id]
		if search_term in item.display_name.to_lower() or search_term in item.description.to_lower():
			results.append(item)
	
	return results

# === FUTURE CATEGORY HELPERS === TODO: Implement these when categories are ready

func get_mini_profile_layouts() -> Array:
	"""Get all available mini profile layouts"""
	var layouts = []
	for item in get_items_by_category("mini_profile"):
		if not item.mini_profile_layout in layouts:
			layouts.append(item.mini_profile_layout)
	return layouts

func get_combo_effects() -> Array:
	"""Get all available combo effects"""
	return get_items_by_category("combo_effect")

func get_topbar_skins() -> Array:
	"""Get all available topbar skins"""
	return get_items_by_category("topbar")

func get_menu_backgrounds() -> Array:
	"""Get all menu backgrounds (includes boards if applicable)"""
	var backgrounds = get_items_by_category("menu_background")
	
	# Add boards that can be backgrounds
	for board in get_items_by_category("board"):
		if board.can_be_menu_background:
			backgrounds.append(board)
	
	return backgrounds

# === CACHE MANAGEMENT ===

func save_cache():
	"""Save item cache to disk for faster loading"""
	var cache_data = {
		"version": 1,
		"items": {},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Convert items to saveable format
	for item_id in all_items:
		var item = all_items[item_id]
		if not item.is_procedural:  # Don't cache procedural items
			cache_data.items[item_id] = item
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(cache_data)
		file.close()
		print("ItemDatabase: Cache saved with %d items" % cache_data.items.size())

func load_cache() -> bool:
	"""Load item cache from disk"""
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var cache_data = file.get_var()
	file.close()
	
	if not cache_data or not cache_data.has("version"):
		return false
	
	# Check cache age (invalidate if older than 1 day)
	var age = Time.get_unix_time_from_system() - cache_data.get("timestamp", 0)
	if age > 86400:  # 24 hours
		print("ItemDatabase: Cache too old, ignoring")
		return false
	
	# Load cached items
	for item_id in cache_data.items:
		all_items[item_id] = cache_data.items[item_id]
	
	print("ItemDatabase: Loaded %d items from cache" % cache_data.items.size())
	return true

# === EXPORT/IMPORT ===

func export_to_json(path: String = "user://items_export.json"):
	"""Export all items to JSON for external tools"""
	var export_data = {}
	
	for item_id in all_items:
		var item = all_items[item_id]
		export_data[item_id] = {
			"display_name": item.display_name,
			"description": item.description,
			"category": item.category,
			"rarity": item.rarity,
			"price": item.base_price,
			"is_procedural": item.is_procedural,
			"is_animated": item.is_animated
		}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export_data, "\t"))
		file.close()
		print("ItemDatabase: Exported %d items to %s" % [export_data.size(), path])

# === DEBUG ===

func debug_status():
	print("\n=== ITEM DATABASE STATUS ===")
	print("Total items: %d" % all_items.size())
	print("By category:")
	for category in items_by_category:
		var count = items_by_category[category].size()
		if count > 0:
			print("  %s: %d items" % [category, count])
	print("By rarity:")
	for rarity in items_by_rarity:
		var count = items_by_rarity[rarity].size()
		if count > 0:
			print("  %s: %d items" % [rarity, count])
	print("Procedural items: %d" % procedural_instances.size())
	print("Sets: %d" % items_by_set.size())
	print("============================\n")

func debug_future_categories():
	"""Show status of future category implementation"""
	print("\n=== FUTURE CATEGORIES STATUS ===")
	
	var future_cats = ["mini_profile", "topbar", "combo_effect", "menu_background"]
	
	for category in future_cats:
		var items = get_items_by_category(category)
		if items.size() > 0:
			print("✓ %s: %d items ready" % [category, items.size()])
		else:
			print("✗ %s: TODO - Not implemented" % category)
			
			# Show what needs to be done
			match category:
				"mini_profile":
					print("  - Create mini profile card designs")
					print("  - Implement showcase UI")
					print("  - Add to ProfileUI")
				"topbar":
					print("  - Create topbar skin designs")
					print("  - Apply to MobileTopBar")
				"combo_effect":
					print("  - Create effect animations")
					print("  - Integrate with Card.gd")
				"menu_background":
					print("  - Create background scenes")
					print("  - Apply to MainMenu")
	
	print("================================\n")

func _string_to_category(category_str: String) -> UnifiedItemData.Category:
	"""Convert string category to enum"""
	match category_str:
		"card_fronts", "card_front":
			return UnifiedItemData.Category.CARD_FRONT
		"card_backs", "card_back":
			return UnifiedItemData.Category.CARD_BACK
		"boards", "board":
			return UnifiedItemData.Category.BOARD
		"frames", "frame":
			return UnifiedItemData.Category.FRAME
		"avatars", "avatar":
			return UnifiedItemData.Category.AVATAR
		"emojis", "emoji":
			return UnifiedItemData.Category.EMOJI
		"mini_profiles", "mini_profile":
			return UnifiedItemData.Category.MINI_PROFILE_CARD
		"topbars", "topbar":
			return UnifiedItemData.Category.TOPBAR
		"combo_effects", "combo_effect":
			return UnifiedItemData.Category.COMBO_EFFECT
		"menu_backgrounds", "menu_background":
			return UnifiedItemData.Category.MENU_BACKGROUND
		_:
			push_warning("ItemDatabase: Unknown category string: " + category_str)
			return UnifiedItemData.Category.CARD_FRONT

func _category_to_string(category: UnifiedItemData.Category) -> String:
	"""Convert category enum to string for indexing"""
	match category:
		UnifiedItemData.Category.CARD_FRONT:
			return "card_fronts"
		UnifiedItemData.Category.CARD_BACK:
			return "card_backs"
		UnifiedItemData.Category.BOARD:
			return "boards"
		UnifiedItemData.Category.FRAME:
			return "frames"
		UnifiedItemData.Category.AVATAR:
			return "avatars"
		UnifiedItemData.Category.EMOJI:
			return "emojis"
		UnifiedItemData.Category.MINI_PROFILE_CARD:
			return "mini_profiles"
		UnifiedItemData.Category.TOPBAR:
			return "topbars"
		UnifiedItemData.Category.COMBO_EFFECT:
			return "combo_effects"
		UnifiedItemData.Category.MENU_BACKGROUND:
			return "menu_backgrounds"
		_:
			return "unknown"
