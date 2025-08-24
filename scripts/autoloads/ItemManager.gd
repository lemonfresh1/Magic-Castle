# ItemManager.gd - Central registry for all cosmetic items in the game
# Location: res://Pyramids/scripts/autoloads/ItemManager.gd
# Last Updated: Cleaned up, removed ProceduralItemRegistry dependency [Date]
#
# ItemManager handles:
# - Loading all item definitions from .tres files
# - Discovering and caching procedural items
# - Providing query interfaces for items
# - Managing bundles
#
# Flow: .tres files & procedural scripts → ItemManager → EquipmentManager (ownership) → UIs
# Dependencies: UnifiedItemData (resource), EquipmentManager (for ownership queries)

extends Node

# === SIGNALS ===
signal items_loaded(count: int)
signal item_registered(item_id: String)
signal bundle_purchased(bundle_id: String, items: Array)
signal database_ready()

# === CONSTANTS ===
const ITEMS_PATH = "res://Pyramids/resources/items/"
const BUNDLES_PATH = "res://Pyramids/resources/bundles/"
const PROCEDURAL_BASE_PATH = "res://Pyramids/scripts/items/"
const CACHE_PATH = "user://item_cache.dat"

const CATEGORIES = [
	"card_fronts",
	"card_backs", 
	"boards",
	"frames",
	"avatars",
	"emojis",
	"mini_profile_card"
]

# === PROPERTIES ===
var all_items: Dictionary = {}  # id -> UnifiedItemData
var all_bundles: Dictionary = {}  # id -> BundleData
var items_by_category: Dictionary = {}  # category -> Array of UnifiedItemData
var items_by_rarity: Dictionary = {}  # rarity -> Array of UnifiedItemData
var items_by_source: Dictionary = {}  # source -> Array of UnifiedItemData
var items_by_set: Dictionary = {}  # set_name -> Array of UnifiedItemData
var procedural_instances: Dictionary = {}  # item_id -> instance

var is_loaded: bool = false

# === LIFECYCLE ===

func _ready():
	print("ItemManager initializing...")
	_initialize_collections()
	_create_directory_structure()
	load_all_items()
	print("ItemManager ready with %d items and %d bundles" % [all_items.size(), all_bundles.size()])

# === INITIALIZATION ===

func _initialize_collections():
	"""Initialize empty collections"""
	for category in CATEGORIES:
		items_by_category[category] = []
	
	for rarity in ["common", "uncommon", "rare", "epic", "legendary", "mythic"]:
		items_by_rarity[rarity] = []
	
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
	
	if not dir.dir_exists(BUNDLES_PATH):
		dir.make_dir_recursive(BUNDLES_PATH)

# === LOADING ===

func load_all_items():
	"""Main loading orchestrator"""
	var start_time = Time.get_ticks_msec()
	
	# Try cache first
	if not _load_from_cache():
		_load_resource_items()
		_save_cache()
	
	# Load procedural items (always fresh)
	_discover_procedural_items()
	
	# Load bundles and organize
	_load_bundles()
	_organize_items()
	_ensure_defaults()
	
	var load_time = Time.get_ticks_msec() - start_time
	print("ItemManager: Loaded %d items in %d ms" % [all_items.size(), load_time])
	
	is_loaded = true
	database_ready.emit()
	items_loaded.emit(all_items.size())

func _load_resource_items():
	"""Load all .tres item resources"""
	for category in CATEGORIES:
		var path = ITEMS_PATH + category + "/"
		
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)
			continue
		
		var dir = DirAccess.open(path)
		if not dir:
			continue
		
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var resource_path = path + file_name
				var item = load(resource_path) as UnifiedItemData
				if item and item.id != "":
					register_item(item)
			file_name = dir.get_next()

func _discover_procedural_items():
	"""Discover and load procedural items directly"""
	for category in CATEGORIES:
		var path = PROCEDURAL_BASE_PATH + category + "/procedural/"
		_scan_procedural_directory(path, category)

func _scan_procedural_directory(base_path: String, category: String):
	"""Recursively scan for procedural item scripts"""
	if not DirAccess.dir_exists_absolute(base_path):
		return
	
	var dir = DirAccess.open(base_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var name = dir.get_next()
	
	while name != "":
		var full_path = base_path + "/" + name
		
		if dir.current_is_dir() and name != "." and name != "..":
			# Recurse into subdirectories
			_scan_procedural_directory(full_path, category)
		elif name.ends_with(".gd"):
			# Load the script
			var script = load(full_path)
			if script:
				var instance = script.new()
				if instance and instance.has_method("draw_card_back") or instance.has_method("draw_card_front") or instance.has_method("draw_board_background"):
					_register_procedural_item(instance, category, full_path)
		
		name = dir.get_next()

func _register_procedural_item(instance, category: String, script_path: String):
	"""Register a procedural item from its instance"""
	# Create UnifiedItemData
	var item = UnifiedItemData.new()
	
	# Get properties from instance
	item.id = instance.get("item_id") if instance.get("item_id") else ""
	item.display_name = instance.get("display_name") if instance.get("display_name") else ""
	item.description = instance.get("description") if instance.get("description") else ""
	item.category = _string_to_category(category)
	item.is_procedural = true
	item.is_animated = instance.get("is_animated") if instance.get("is_animated") != null else false
	item.procedural_script_path = script_path
	
	# Get rarity
	if instance.get("item_rarity") != null:
		item.rarity = instance.get("item_rarity")
	
	# Get pricing
	if instance.get("base_price") != null:
		item.base_price = instance.get("base_price")
	
	# Store instance for later use
	if item.id != "":
		procedural_instances[item.id] = instance
		register_item(item)

func _load_bundles():
	"""Load bundle definitions"""
	var dir = DirAccess.open(BUNDLES_PATH)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var bundle = load(BUNDLES_PATH + file_name) as BundleData
			if bundle and bundle.id != "":
				all_bundles[bundle.id] = bundle
		file_name = dir.get_next()

func _ensure_defaults():
	"""Create default items if missing"""
	if not all_items.has("card_classic"):
		var classic = UnifiedItemData.new()
		classic.id = "card_classic"
		classic.display_name = "Classic Cards"
		classic.description = "The original card design"
		classic.category = UnifiedItemData.Category.CARD_FRONT
		classic.rarity = UnifiedItemData.Rarity.COMMON
		classic.source = UnifiedItemData.Source.DEFAULT
		classic.base_price = 0
		classic.is_purchasable = false
		register_item(classic)
	
	if not all_items.has("board_green"):
		var green = UnifiedItemData.new()
		green.id = "board_green"
		green.display_name = "Classic Green"
		green.description = "The classic green felt board"
		green.category = UnifiedItemData.Category.BOARD
		green.rarity = UnifiedItemData.Rarity.COMMON
		green.source = UnifiedItemData.Source.DEFAULT
		green.base_price = 0
		green.is_purchasable = false
		green.colors = {"primary": Color(0.2, 0.5, 0.2)}
		register_item(green)

func _organize_items():
	"""Build category, rarity, and set indexes"""
	# Clear existing
	for key in items_by_category:
		items_by_category[key].clear()
	for key in items_by_rarity:
		items_by_rarity[key].clear()
	for key in items_by_source:
		items_by_source[key].clear()
	items_by_set.clear()
	
	# Organize
	for item_id in all_items:
		var item = all_items[item_id]
		if not item is UnifiedItemData:
			continue
		
		# Category
		var category_str = _category_to_string(item.category)
		if items_by_category.has(category_str):
			items_by_category[category_str].append(item)
		
		# Rarity
		var rarity_str = item.get_rarity_name().to_lower()
		if items_by_rarity.has(rarity_str):
			items_by_rarity[rarity_str].append(item)
		
		# Source
		if items_by_source.has(item.source):
			items_by_source[item.source].append(item)
		
		# Set
		if item.set_name != "":
			if not items_by_set.has(item.set_name):
				items_by_set[item.set_name] = []
			items_by_set[item.set_name].append(item)

# === PUBLIC INTERFACE ===

func register_item(item: UnifiedItemData) -> bool:
	"""Register an item in the database"""
	if item.id == "":
		push_error("ItemManager: Cannot register item with empty ID")
		return false
	
	if all_items.has(item.id):
		return false  # Already registered
	
	all_items[item.id] = item
	item_registered.emit(item.id)
	return true

func get_item(item_id: String) -> UnifiedItemData:
	"""Get a single item by ID"""
	var item = all_items.get(item_id)
	if item and item is UnifiedItemData:
		return item
	return null

func get_procedural_instance(item_id: String):
	"""Get the procedural instance for animated items"""
	return procedural_instances.get(item_id)

func get_items_by_category(category: String) -> Array:
	"""Get all items in a specific category"""
	var result = []
	
	# Map string category to enum
	var target_category = _string_to_category(category)
	if target_category == -1:
		push_warning("ItemManager: Unknown category: " + category)
		return result
	
	for item_id in all_items:
		var item = all_items[item_id]
		if item and item.category == target_category:
			result.append(item)
	
	return result

func get_items_by_rarity(rarity) -> Array:
	"""Get all items of a specific rarity"""
	var rarity_str = ""
	if rarity is String:
		rarity_str = rarity.to_lower()
	elif rarity is int:
		match rarity:
			UnifiedItemData.Rarity.COMMON: rarity_str = "common"
			UnifiedItemData.Rarity.UNCOMMON: rarity_str = "uncommon"
			UnifiedItemData.Rarity.RARE: rarity_str = "rare"
			UnifiedItemData.Rarity.EPIC: rarity_str = "epic"
			UnifiedItemData.Rarity.LEGENDARY: rarity_str = "legendary"
			UnifiedItemData.Rarity.MYTHIC: rarity_str = "mythic"
	
	return items_by_rarity.get(rarity_str, [])

func get_bundle(bundle_id: String) -> BundleData:
	"""Get a bundle by ID"""
	return all_bundles.get(bundle_id)

# === CACHE MANAGEMENT ===

func _save_cache():
	"""Save non-procedural items to cache"""
	var cache_data = {
		"version": 1,
		"items": {},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	for item_id in all_items:
		var item = all_items[item_id]
		if not item.is_procedural:
			cache_data.items[item_id] = item
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(cache_data)
		file.close()

func _load_from_cache() -> bool:
	"""Load items from cache"""
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	
	var file = FileAccess.open(CACHE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var cache_data = file.get_var()
	file.close()
	
	if not cache_data or not cache_data.has("version"):
		return false
	
	# Check age (24 hours)
	var age = Time.get_unix_time_from_system() - cache_data.get("timestamp", 0)
	if age > 86400:
		return false
	
	# Load items
	for item_id in cache_data.items:
		var item = cache_data.items[item_id]
		if item and item is UnifiedItemData:
			all_items[item_id] = item
	
	return all_items.size() > 0

# === HELPERS ===

func _string_to_category(category_str: String) -> int:
	"""Convert string category to UnifiedItemData.Category enum"""
	match category_str:
		"card_fronts", "card_front": return UnifiedItemData.Category.CARD_FRONT
		"card_backs", "card_back": return UnifiedItemData.Category.CARD_BACK
		"boards", "board": return UnifiedItemData.Category.BOARD
		"avatars", "avatar": return UnifiedItemData.Category.AVATAR
		"frames", "frame": return UnifiedItemData.Category.FRAME
		"emojis", "emoji": return UnifiedItemData.Category.EMOJI
		"mini_profile_cards", "mini_profile_card": return UnifiedItemData.Category.MINI_PROFILE_CARD
		_: return -1

func _category_to_string(category: UnifiedItemData.Category) -> String:
	"""Convert category enum to string"""
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
			return "mini_profile_card"
		_:
			return "unknown"

func get_all_items() -> Dictionary:
	"""Get all items as a dictionary"""
	return all_items.duplicate()

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

func get_all_bundles() -> Array:
	"""Get all available bundles"""
	return all_bundles.values()

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
