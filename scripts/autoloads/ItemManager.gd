# ItemManager.gd - Central registry for all cosmetic items in the game
# Location: res://Pyramids/scripts/autoloads/ItemManager.gd
# Last Updated: Enhanced with procedural caching and better queries, removed legacy code [Date]
#
# ItemManager handles:
# - Loading all item definitions from .tres files
# - Caching procedural item instances
# - Providing query interfaces for items
# - Managing bundles
# - Item granting (delegates ownership to EquipmentManager)
#
# Flow: .tres files → ItemManager → EquipmentManager (ownership) → UIs
# Dependencies: UnifiedItemData (resource), ProceduralItemRegistry (for procedural items)

extends Node

# Signals for item events
signal items_loaded(count: int)
signal item_registered(item_id: String)
signal bundle_purchased(bundle_id: String, items: Array)
signal database_ready()

# Paths
const ITEMS_PATH = "res://Pyramids/resources/items/"
const BUNDLES_PATH = "res://Pyramids/resources/bundles/"
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

# Runtime data (loaded from resources)
var all_items: Dictionary = {}  # id -> UnifiedItemData
var all_bundles: Dictionary = {}  # id -> BundleData
var items_by_category: Dictionary = {}  # category -> Array of UnifiedItemData
var items_by_rarity: Dictionary = {}  # rarity -> Array of UnifiedItemData
var items_by_source: Dictionary = {}  # source -> Array of UnifiedItemData
var items_by_set: Dictionary = {}  # set_name -> Array of UnifiedItemData
var procedural_instances: Dictionary = {}  # item_id -> instance (for animated items)

# Loading state
var is_loaded: bool = false
var load_progress: float = 0.0

func _ready():
	print("ItemManager initializing...")
	_initialize_collections()
	_create_directory_structure()
	load_all_items()
	print("ItemManager ready with %d items and %d bundles" % [all_items.size(), all_bundles.size()])
	
	# Debug check for specific items
	_debug_check_items()

func _initialize_collections():
	"""Initialize empty collections for organization"""
	# Initialize category arrays
	for category in CATEGORIES:
		items_by_category[category] = []
	
	# Initialize rarity arrays
	for rarity in ["common", "uncommon", "rare", "epic", "legendary", "mythic"]:
		items_by_rarity[rarity] = []
	
	# Initialize source arrays
	for source in UnifiedItemData.Source.values():
		items_by_source[source] = []

func _create_directory_structure():
	"""Ensure directory structure exists"""
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(ITEMS_PATH):
		dir.make_dir_recursive(ITEMS_PATH)
		for category in CATEGORIES:
			var cat_path = ITEMS_PATH + category
			if not dir.dir_exists(cat_path):
				dir.make_dir(cat_path)
		print("ItemManager: Created item directory structure")
	
	if not dir.dir_exists(BUNDLES_PATH):
		dir.make_dir_recursive(BUNDLES_PATH)
		print("ItemManager: Created bundles directory")

# === MAIN LOADING ===

func load_all_items():
	"""Load all items from resources and procedural sources"""
	var start_time = Time.get_ticks_msec()
	
	# Try to load from cache first
	if not load_cache():
		# Load from directories
		_load_resource_items()
		# Save cache for next time
		save_cache()
	
	# Load procedural items (always fresh, not cached)
	_load_procedural_items()
	
	# Load bundles
	_load_all_bundles()
	
	# Build indexes
	_organize_items()
	
	# Create default items if missing
	_ensure_default_items()
	
	var load_time = Time.get_ticks_msec() - start_time
	print("ItemManager: Loaded %d items in %d ms" % [all_items.size(), load_time])
	
	is_loaded = true
	database_ready.emit()
	items_loaded.emit(all_items.size())

func _load_resource_items():
	"""Load all .tres item resources"""
	for category in CATEGORIES:
		var path = ITEMS_PATH + category + "/"
		
		# Skip future categories that don't have folders yet
		if not DirAccess.dir_exists_absolute(path):
			if category in ["mini_profiles", "topbars", "combo_effects", "menu_backgrounds"]:
				print("ItemManager: Skipping future category: %s" % category)
				continue
			else:
				print("ItemManager: Creating missing directory: %s" % path)
				DirAccess.make_dir_recursive_absolute(path)
				continue
		
		_load_items_from_directory(path, category)

func _load_items_from_directory(path: String, category: String):
	"""Scan a directory for item resources"""
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = path + file_name
			var item = load(resource_path) as UnifiedItemData
			if item and item.id != "":
				register_item(item)
				print("  ✓ Loaded: '%s' (id: %s) from %s" % [item.display_name, item.id, category])
			else:
				if item and item.id == "":
					push_warning("ItemManager: Item has empty ID in " + resource_path)
				else:
					push_warning("ItemManager: Invalid resource type in " + resource_path)
		file_name = dir.get_next()

func _load_procedural_items():
	"""Load all procedural item definitions"""
	if not ProceduralItemRegistry:
		push_warning("ItemManager: ProceduralItemRegistry not found")
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
		
		# Let the instance create its own UnifiedItemData
		var unified: UnifiedItemData
		if instance.has_method("create_item_data"):
			unified = instance.create_item_data()
		else:
			# Fallback: create manually
			unified = UnifiedItemData.new()
			unified.id = instance.get("item_id") if instance.get("item_id") else item_id
			unified.display_name = instance.get("display_name") if instance.get("display_name") else ""
			
			# Convert category string to enum
			if typeof(proc_data.category) == TYPE_STRING:
				unified.category = _string_to_category(proc_data.category)
			else:
				unified.category = proc_data.category
				
			unified.is_procedural = true
			unified.is_animated = instance.get("is_animated") if instance.get("is_animated") != null else false
			unified.procedural_script_path = proc_data.script_path
		
		# Store the instance for later use
		procedural_instances[unified.id] = instance
		
		# Register the item
		register_item(unified)
		print("  ✓ Loaded procedural: '%s' (id: %s)" % [unified.display_name, unified.id])

func _load_all_bundles():
	"""Load bundle definitions"""
	var dir = DirAccess.open(BUNDLES_PATH)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = BUNDLES_PATH + file_name
			var bundle = load(resource_path) as BundleData
			if bundle and bundle.id != "":
				all_bundles[bundle.id] = bundle
				print("ItemManager: Loaded bundle '%s'" % bundle.display_name)
		file_name = dir.get_next()

func _ensure_default_items():
	"""Create default items if they don't exist"""
	# Card Classic
	if not all_items.has("card_classic"):
		var classic_cards = UnifiedItemData.new()
		classic_cards.id = "card_classic"
		classic_cards.display_name = "Classic Cards"
		classic_cards.description = "The original card design"
		classic_cards.category = UnifiedItemData.Category.CARD_FRONT
		classic_cards.rarity = UnifiedItemData.Rarity.COMMON
		classic_cards.source = UnifiedItemData.Source.DEFAULT
		classic_cards.base_price = 0
		classic_cards.is_purchasable = false
		register_item(classic_cards)
		print("ItemManager: Created default card_classic item")
	
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
		print("ItemManager: Created default board_green item")

func _organize_items():
	"""Build category, rarity, source, and set indexes"""
	# Clear existing organization
	for category in items_by_category:
		items_by_category[category].clear()
	for rarity in items_by_rarity:
		items_by_rarity[rarity].clear()
	for source in items_by_source:
		items_by_source[source].clear()
	items_by_set.clear()
	
	# Sort items into collections
	for item_id in all_items:
		var item = all_items[item_id]
		
		# Skip if item is null or not UnifiedItemData
		if not item or not item is UnifiedItemData:
			push_warning("ItemManager: Invalid item in collection: " + item_id)
			continue
		
		# Add to category list - convert enum to string
		var category_str = _category_to_string(item.category)
		if items_by_category.has(category_str):
			items_by_category[category_str].append(item)
		
		# Add to rarity list - convert enum to string
		var rarity_str = item.get_rarity_name().to_lower()
		if items_by_rarity.has(rarity_str):
			items_by_rarity[rarity_str].append(item)
		
		# Add to source list
		if items_by_source.has(item.source):
			items_by_source[item.source].append(item)
		
		# Add to set list
		if item.set_name != "":
			if not items_by_set.has(item.set_name):
				items_by_set[item.set_name] = []
			items_by_set[item.set_name].append(item)
	
	# Sort each category by sort_order
	for category in items_by_category:
		items_by_category[category].sort_custom(func(a, b): return a.sort_order < b.sort_order)

# === REGISTRATION ===

func register_item(item: UnifiedItemData) -> bool:
	"""Register an item in the database"""
	if item.id == "":
		push_error("ItemManager: Cannot register item with empty ID")
		return false
	
	if all_items.has(item.id):
		push_warning("ItemManager: Item already registered: " + item.id)
		return false
	
	all_items[item.id] = item
	item_registered.emit(item.id)
	
	return true

# === QUERIES ===

func get_item(item_id: String) -> UnifiedItemData:
	"""Get a single item by ID"""
	var item = all_items.get(item_id)
	if item and item is UnifiedItemData:
		return item
	return null

func get_procedural_instance(item_id: String):
	"""Get the procedural instance for animated items"""
	if procedural_instances.has(item_id):
		return procedural_instances[item_id]
	
	# Try to get from ProceduralItemRegistry
	if ProceduralItemRegistry and ProceduralItemRegistry.procedural_items.has(item_id):
		var instance = ProceduralItemRegistry.procedural_items[item_id].instance
		procedural_instances[item_id] = instance
		return instance
	
	return null

func get_all_items() -> Dictionary:
	"""Get all items as a dictionary"""
	return all_items.duplicate()

func get_items_by_category(category) -> Array:
	"""Get all items in a category (accepts enum or string)"""
	var category_str = ""
	
	if category is String:
		category_str = category
	elif category is int:  # Enum value
		category_str = _category_to_string(category)
	
	return items_by_category.get(category_str, [])

func get_items_by_rarity(rarity) -> Array:
	"""Get all items of a specific rarity (accepts enum or string)"""
	var rarity_str = ""
	
	if rarity is String:
		rarity_str = rarity.to_lower()
	elif rarity is int:  # Enum value
		# Convert enum to string
		match rarity:
			UnifiedItemData.Rarity.COMMON: rarity_str = "common"
			UnifiedItemData.Rarity.UNCOMMON: rarity_str = "uncommon"
			UnifiedItemData.Rarity.RARE: rarity_str = "rare"
			UnifiedItemData.Rarity.EPIC: rarity_str = "epic"
			UnifiedItemData.Rarity.LEGENDARY: rarity_str = "legendary"
			UnifiedItemData.Rarity.MYTHIC: rarity_str = "mythic"
	
	return items_by_rarity.get(rarity_str, [])

func get_items_by_source(source: UnifiedItemData.Source) -> Array:
	"""Get all items from a specific source"""
	return items_by_source.get(source, [])

func get_items_by_set(set_name: String) -> Array:
	"""Get all items in a set"""
	return items_by_set.get(set_name, [])

func search_items(query: String) -> Array:
	"""Search items by name or description"""
	var results = []
	var search_term = query.to_lower()
	
	for item_id in all_items:
		var item = all_items[item_id]
		if search_term in item.display_name.to_lower() or search_term in item.description.to_lower():
			results.append(item)
	
	return results

func get_owned_items() -> Array:
	"""Get all items owned by the player (queries EquipmentManager)"""
	if not EquipmentManager:
		return []
	
	var owned = []
	for item_id in all_items:
		if EquipmentManager.is_item_owned(item_id):
			owned.append(all_items[item_id])
	return owned

func get_owned_items_by_category(category) -> Array:
	"""Get owned items in a category"""
	if not EquipmentManager:
		return []
	
	var owned = []
	for item in get_items_by_category(category):
		if EquipmentManager.is_item_owned(item.id):
			owned.append(item)
	return owned

func get_equipped_items() -> Array:
	"""Get all currently equipped items (queries EquipmentManager)"""
	if not EquipmentManager:
		return []
	
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

# === BUNDLES ===

func get_bundle(bundle_id: String) -> BundleData:
	"""Get a bundle by ID"""
	return all_bundles.get(bundle_id)

func get_all_bundles() -> Array:
	"""Get all available bundles"""
	return all_bundles.values()

func get_bundle_price(bundle_id: String) -> int:
	"""Calculate bundle price"""
	var bundle = all_bundles.get(bundle_id) as BundleData
	if not bundle:
		return -1
	return bundle.calculate_price(all_items)

func purchase_bundle(bundle_id: String) -> bool:
	"""Process bundle purchase (delegates to EquipmentManager for ownership)"""
	var bundle = all_bundles.get(bundle_id) as BundleData
	if not bundle:
		push_error("ItemManager: Bundle not found: " + bundle_id)
		return false
	
	if not EquipmentManager:
		push_error("ItemManager: EquipmentManager not available")
		return false
	
	# Grant all items in bundle through EquipmentManager
	var granted_items = []
	for item_id in bundle.item_ids:
		if not EquipmentManager.is_item_owned(item_id):
			if EquipmentManager.grant_item(item_id, "bundle"):
				granted_items.append(item_id)
	
	# Grant bonus rewards
	if bundle.bonus_stars > 0 and StarManager:
		StarManager.add_stars(bundle.bonus_stars, "bundle_" + bundle_id)
	if bundle.bonus_xp > 0 and XPManager:
		XPManager.add_xp(bundle.bonus_xp, "bundle_" + bundle_id)
	
	bundle_purchased.emit(bundle_id, granted_items)
	return granted_items.size() > 0

# === CACHE MANAGEMENT ===

func save_cache():
	"""Save item cache to disk for faster loading"""
	var cache_data = {
		"version": 1,
		"items": {},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Convert items to saveable format (exclude procedural items)
	for item_id in all_items:
		var item = all_items[item_id]
		if not item.is_procedural:  # Don't cache procedural items
			cache_data.items[item_id] = item
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(cache_data)
		file.close()
		print("ItemManager: Cache saved with %d items" % cache_data.items.size())

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
		print("ItemManager: Cache too old, ignoring")
		return false
	
	# Load cached items with type checking
	for item_id in cache_data.items:
		var item = cache_data.items[item_id]
		if item and item is UnifiedItemData:
			all_items[item_id] = item
		else:
			push_warning("ItemManager: Invalid cached item skipped: " + item_id)
	
	print("ItemManager: Loaded %d items from cache" % all_items.size())
	return all_items.size() > 0  # Return false if no valid items loaded

# === EXPORT/IMPORT ===

func export_to_json(path: String = "user://items_export.json"):
	"""Export all items to JSON for external tools"""
	var export_data = {}
	
	for item_id in all_items:
		var item = all_items[item_id]
		export_data[item_id] = {
			"display_name": item.display_name,
			"description": item.description,
			"category": _category_to_string(item.category),
			"rarity": item.get_rarity_name(),
			"price": item.base_price,
			"is_procedural": item.is_procedural,
			"is_animated": item.is_animated,
			"is_purchasable": item.is_purchasable
		}
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export_data, "\t"))
		file.close()
		print("ItemManager: Exported %d items to %s" % [export_data.size(), path])

# === CATEGORY HELPERS ===

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
			push_warning("ItemManager: Unknown category string: " + category_str)
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

# === DEBUG ===

func _debug_check_items():
	"""Check for specific items we expect to exist"""
	print("\n=== CHECKING EXPECTED ITEMS ===")
	
	# Check pyramid board
	var pyramid_board = get_item("board_pyramids")
	if pyramid_board:
		print("✓ Pyramid board loaded: ", pyramid_board.display_name)
		print("  - Animated: ", pyramid_board.is_animated)
		print("  - Scene: ", pyramid_board.background_scene_path)
	else:
		print("✗ Pyramid board NOT found")
	
	# Check gold card back
	var gold_back = get_item("card_back_classic_pyramids_gold")
	if gold_back:
		print("✓ Gold card back loaded: ", gold_back.display_name)
		print("  - Procedural: ", gold_back.is_procedural)
		print("  - Script: ", gold_back.procedural_script_path)
		if procedural_instances.has(gold_back.id):
			print("  - Instance cached: Yes")
	else:
		print("✗ Gold card back NOT found")
	
	print("================================\n")

func debug_status():
	"""Print comprehensive status"""
	print("\n=== ITEM MANAGER STATUS ===")
	print("Total items: %d" % all_items.size())
	print("Total bundles: %d" % all_bundles.size())
	print("Procedural items: %d" % procedural_instances.size())
	
	print("\nBy category:")
	for category in items_by_category:
		var count = items_by_category[category].size()
		if count > 0:
			print("  %s: %d items" % [category, count])
	
	print("\nBy rarity:")
	for rarity in items_by_rarity:
		var count = items_by_rarity[rarity].size()
		if count > 0:
			print("  %s: %d items" % [rarity, count])
	
	print("\nSets: %d unique sets" % items_by_set.size())
	for set_name in items_by_set:
		print("  %s: %d items" % [set_name, items_by_set[set_name].size()])
	
	print("============================\n")

func debug_future_categories():
	"""Show status of future category implementation"""
	print("\n=== FUTURE CATEGORIES STATUS ===")
	
	var future_cats = ["mini_profiles", "topbars", "combo_effects", "menu_backgrounds"]
	
	for category in future_cats:
		var items = get_items_by_category(category)
		if items.size() > 0:
			print("✓ %s: %d items ready" % [category, items.size()])
		else:
			print("✗ %s: TODO - Not implemented" % category)
			
			# Show what needs to be done
			match category:
				"mini_profiles":
					print("  - Create mini profile card designs")
					print("  - Implement showcase UI")
					print("  - Add to ProfileUI")
				"topbars":
					print("  - Create topbar skin designs")
					print("  - Apply to MobileTopBar")
				"combo_effects":
					print("  - Create effect animations")
					print("  - Integrate with Card.gd")
				"menu_backgrounds":
					print("  - Create background scenes")
					print("  - Apply to MainMenu")
	
	print("================================\n")
