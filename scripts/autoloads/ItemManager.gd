# ItemManager.gd - Central registry for all cosmetic items in the game
# Location: res://Magic-Castle/scripts/autoloads/ItemManager.gd
# Last Updated: Refactored to use Resource files [Date]

extends Node

# Signals for item events
signal item_granted(item_id: String, source: String)
signal item_equipped(item_id: String, category: String)
signal item_unequipped(item_id: String, category: String)
signal bundle_purchased(bundle_id: String, items: Array)
signal items_loaded(count: int)

# Paths
const ITEMS_PATH = "res://Magic-Castle/resources/items/"
const BUNDLES_PATH = "res://Magic-Castle/resources/bundles/"
const SAVE_PATH = "user://player_items.save"
const SAVE_VERSION = 1

# Save data structure (minimal - only player data)
var save_data = {
	"version": SAVE_VERSION,
	"owned_items": [],  # Array of item IDs
	"equipped": {
		"card_front": "card_classic",
		"card_back": "",  # Empty means using front's back
		"board": "board_green",
		"frame": "",  # Empty means no frame
		"avatar": "",  # Empty means default
		"emojis": [],  # Array of equipped emoji IDs (max 8)
		"mini_profile_slots": {}  # Dict of slot configurations
	},
	"item_sources": {},  # Dict of item_id: source (as int)
	"unlock_dates": {},  # Dict of item_id: timestamp
	"bundle_history": [],  # Array of purchased bundle IDs
	"metadata": {}  # Extra data for future use
}

# Runtime data (loaded from resources)
var all_items: Dictionary = {}  # id -> ItemData
var all_bundles: Dictionary = {}  # id -> BundleData
var items_by_category: Dictionary = {}  # category -> Array of ItemData
var items_by_source: Dictionary = {}  # source -> Array of ItemData
var items_by_set: Dictionary = {}  # set_name -> Array of ItemData

func _ready():
	print("ItemManager initializing...")
	_create_directory_structure()
	_load_all_items()
	_load_all_bundles()
	load_player_data()
	_organize_items()
	print("ItemManager ready with %d items and %d bundles" % [all_items.size(), all_bundles.size()])
	items_loaded.emit(all_items.size())

func _create_directory_structure():
	# Ensure directory structure exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(ITEMS_PATH):
		dir.make_dir_recursive(ITEMS_PATH)
		dir.make_dir(ITEMS_PATH + "card_fronts")
		dir.make_dir(ITEMS_PATH + "card_backs")
		dir.make_dir(ITEMS_PATH + "boards")
		dir.make_dir(ITEMS_PATH + "frames")
		dir.make_dir(ITEMS_PATH + "avatars")
		dir.make_dir(ITEMS_PATH + "emojis")
		dir.make_dir(ITEMS_PATH + "mini_profiles")
		print("ItemManager: Created item directory structure")
	
	if not dir.dir_exists(BUNDLES_PATH):
		dir.make_dir_recursive(BUNDLES_PATH)
		print("ItemManager: Created bundles directory")

func _load_all_items():
	# Load items from each category directory
	var categories = [
		"card_fronts",
		"card_backs",
		"boards",
		"frames",
		"avatars",
		"emojis",
		"mini_profiles"
	]
	
	for category in categories:
		_load_items_from_directory(ITEMS_PATH + category + "/")
	
	# Create default items if they don't exist
	_ensure_default_items()

func _load_items_from_directory(path: String):
	print("Loading items from: ", path)  # ADD THIS
	var dir = DirAccess.open(path)
	if not dir:
		print("  - Directory not found!")  # ADD THIS
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		print("  - Found file: ", file_name)  # ADD THIS
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = path + file_name
			var item = load(resource_path) as ItemData
			if item and item.id != "":
				all_items[item.id] = item
				print("    ✓ Loaded: '%s' (id: %s)" % [item.display_name, item.id])  # MODIFY THIS
			else:
				if item:
					print("    ✗ Invalid: ID is empty for ", file_name)  # ADD THIS
				else:
					print("    ✗ Invalid: Not an ItemData resource")  # ADD THIS
				push_warning("ItemManager: Invalid item resource at " + resource_path)
		file_name = dir.get_next()

func _load_all_bundles():
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
	# Create default items programmatically if they don't exist as resources
	if not all_items.has("card_classic"):
		var classic_cards = ItemData.new()
		classic_cards.id = "card_classic"
		classic_cards.display_name = "Classic Cards"
		classic_cards.description = "The original card design"
		classic_cards.category = ItemData.Category.CARD_FRONT
		classic_cards.rarity = ItemData.Rarity.COMMON
		classic_cards.source = ItemData.Source.DEFAULT
		classic_cards.base_price = 0
		classic_cards.is_purchasable = false
		all_items["card_classic"] = classic_cards
		
		# Save as resource for future
		ResourceSaver.save(classic_cards, ITEMS_PATH + "card_fronts/classic.tres")
		print("ItemManager: Created default card_classic item")
	
	if not all_items.has("board_green"):
		var green_board = ItemData.new()
		green_board.id = "board_green"
		green_board.display_name = "Classic Green"
		green_board.description = "The classic green felt board"
		green_board.category = ItemData.Category.BOARD
		green_board.rarity = ItemData.Rarity.COMMON
		green_board.source = ItemData.Source.DEFAULT
		green_board.base_price = 0
		green_board.is_purchasable = false
		green_board.colors = {"primary": Color(0.2, 0.5, 0.2)}
		all_items["board_green"] = green_board
		
		# Save as resource for future
		ResourceSaver.save(green_board, ITEMS_PATH + "boards/green.tres")
		print("ItemManager: Created default board_green item")
	
	# Ensure default items are owned
	if "card_classic" not in save_data.owned_items:
		save_data.owned_items.append("card_classic")
		save_data.item_sources["card_classic"] = ItemData.Source.DEFAULT
	
	if "board_green" not in save_data.owned_items:
		save_data.owned_items.append("board_green")
		save_data.item_sources["board_green"] = ItemData.Source.DEFAULT

func _organize_items():
	# Clear existing organization
	items_by_category.clear()
	items_by_source.clear()
	items_by_set.clear()
	
	# Initialize category arrays
	for category in ItemData.Category.values():
		items_by_category[category] = []
	
	# Initialize source arrays
	for source in ItemData.Source.values():
		items_by_source[source] = []
	
	# Sort items into categories, sources, and sets
	for item_id in all_items:
		var item = all_items[item_id] as ItemData
		
		# Add to category list
		items_by_category[item.category].append(item)
		
		# Add to source list
		items_by_source[item.source].append(item)
		
		# Add to set list
		if item.set_name != "":
			if not items_by_set.has(item.set_name):
				items_by_set[item.set_name] = []
			items_by_set[item.set_name].append(item)
	
	# Sort each category by sort_order
	for category in items_by_category:
		items_by_category[category].sort_custom(func(a, b): return a.sort_order < b.sort_order)

# === GRANTING ITEMS ===
func grant_item(item_id: String, source: ItemData.Source = ItemData.Source.SHOP) -> bool:
	print("[ItemManager] grant_item called - item_id: %s, source: %s" % [item_id, source])
	
	if not all_items.has(item_id):
		push_error("ItemManager: Item not found: " + item_id)
		# Debug: List what items ARE available
		print("[ItemManager] Available items:")
		for id in all_items.keys():
			print("  - %s" % id)
		return false
	
	if is_item_owned(item_id):
		push_warning("ItemManager: Item already owned: " + item_id)
		return false
	
	var item = all_items[item_id] as ItemData
	
	# Check level requirement
	if item.unlock_level > 0 and XPManager.get_current_level() < item.unlock_level:
		push_warning("ItemManager: Level requirement not met for " + item_id)
		return false
	
	# Add to owned items
	save_data.owned_items.append(item_id)
	save_data.item_sources[item_id] = source
	save_data.unlock_dates[item_id] = Time.get_unix_time_from_system()
	
	# Auto-equip if first of its category
	if should_auto_equip(item):
		equip_item(item_id)
	
	save_player_data()
	item_granted.emit(item_id, item.get_source_name())
	
	print("[ItemManager] Successfully granted item '%s' from %s" % [item.display_name, item.get_source_name()])
	return true

func should_auto_equip(item: ItemData) -> bool:
	# Auto-equip if no item of this category is equipped
	match item.category:
		ItemData.Category.CARD_FRONT:
			return save_data.equipped.card_front == ""
		ItemData.Category.CARD_BACK:
			return save_data.equipped.card_back == ""
		ItemData.Category.BOARD:
			return save_data.equipped.board == ""
		ItemData.Category.FRAME:
			return save_data.equipped.frame == ""
		ItemData.Category.AVATAR:
			return save_data.equipped.avatar == ""
		_:
			return false

# === EQUIPPING ITEMS ===
func equip_item(item_id: String) -> bool:
	if not is_item_owned(item_id):
		push_error("ItemManager: Cannot equip unowned item: " + item_id)
		return false
	
	var item = all_items.get(item_id) as ItemData
	if not item:
		push_error("ItemManager: Item not found: " + item_id)
		return false
	
	var old_equipped = ""
	var category_name = item.get_category_name()
	
	# Update equipped state based on category
	match item.category:
		ItemData.Category.CARD_FRONT:
			old_equipped = save_data.equipped.card_front
			save_data.equipped.card_front = item_id
		ItemData.Category.CARD_BACK:
			old_equipped = save_data.equipped.card_back
			save_data.equipped.card_back = item_id
		ItemData.Category.BOARD:
			old_equipped = save_data.equipped.board
			save_data.equipped.board = item_id
		ItemData.Category.FRAME:
			old_equipped = save_data.equipped.frame
			save_data.equipped.frame = item_id
		ItemData.Category.AVATAR:
			old_equipped = save_data.equipped.avatar
			save_data.equipped.avatar = item_id
		ItemData.Category.EMOJI:
			# Emojis are added to selection, not replaced
			if item_id not in save_data.equipped.emojis and save_data.equipped.emojis.size() < 8:
				save_data.equipped.emojis.append(item_id)
		ItemData.Category.MINI_PROFILE_CARD:
			# Handle mini profile slots separately
			pass
	
	save_player_data()
	
	if old_equipped != "":
		item_unequipped.emit(old_equipped, category_name)
	
	item_equipped.emit(item_id, category_name)
	return true

# === QUERIES ===
func is_item_owned(item_id: String) -> bool:
	return item_id in save_data.owned_items

func get_item(item_id: String) -> ItemData:
	return all_items.get(item_id)

func get_owned_items() -> Array:
	var owned = []
	for item_id in save_data.owned_items:
		if all_items.has(item_id):
			owned.append(all_items[item_id])
	return owned

func get_items_by_category(category: ItemData.Category) -> Array:
	return items_by_category.get(category, [])

func get_owned_items_by_category(category: ItemData.Category) -> Array:
	var owned = []
	for item in get_items_by_category(category):
		if is_item_owned(item.id):
			owned.append(item)
	return owned

func get_equipped_item(category: ItemData.Category) -> String:
	match category:
		ItemData.Category.CARD_FRONT:
			return save_data.equipped.card_front
		ItemData.Category.CARD_BACK:
			return save_data.equipped.card_back
		ItemData.Category.BOARD:
			return save_data.equipped.board
		ItemData.Category.FRAME:
			return save_data.equipped.frame
		ItemData.Category.AVATAR:
			return save_data.equipped.avatar
		_:
			return ""

# === BUNDLES ===
func purchase_bundle(bundle_id: String) -> bool:
	var bundle = all_bundles.get(bundle_id) as BundleData
	if not bundle:
		push_error("ItemManager: Bundle not found: " + bundle_id)
		return false
	
	# Check if already purchased
	if bundle_id in save_data.bundle_history:
		push_warning("ItemManager: Bundle already purchased: " + bundle_id)
		return false
	
	# Check purchase limit
	var purchase_count = save_data.bundle_history.count(bundle_id)
	if bundle.max_purchases > 0 and purchase_count >= bundle.max_purchases:
		push_warning("ItemManager: Bundle purchase limit reached")
		return false
	
	# Grant all items in bundle
	var granted_items = []
	for item_id in bundle.item_ids:
		if not is_item_owned(item_id):
			if grant_item(item_id, ItemData.Source.BUNDLE):
				granted_items.append(item_id)
	
	# Grant bonus rewards
	if bundle.bonus_stars > 0:
		StarManager.add_stars(bundle.bonus_stars, "bundle_" + bundle_id)
	if bundle.bonus_xp > 0:
		XPManager.add_xp(bundle.bonus_xp, "bundle_" + bundle_id)
	
	# Record bundle purchase
	save_data.bundle_history.append(bundle_id)
	save_player_data()
	
	bundle_purchased.emit(bundle_id, granted_items)
	return granted_items.size() > 0

func get_bundle_price(bundle_id: String) -> int:
	var bundle = all_bundles.get(bundle_id) as BundleData
	if not bundle:
		return -1
	return bundle.calculate_price(all_items)

# === PERSISTENCE ===
func save_player_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_player_data():
	if not FileAccess.file_exists(SAVE_PATH):
		print("ItemManager: No save file found, using defaults")
		_ensure_default_items()  # Make sure defaults are owned
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var loaded_data = file.get_var()
		file.close()
		
		if loaded_data and loaded_data.has("version"):
			# Check version and migrate if needed
			if loaded_data.version == SAVE_VERSION:
				save_data = loaded_data
			else:
				_migrate_save_data(loaded_data)

func _migrate_save_data(old_data: Dictionary):
	# Handle save migration from older versions
	print("ItemManager: Migrating save from version %d to %d" % [old_data.get("version", 0), SAVE_VERSION])
	# Add migration logic here as needed

func reset_all_items():
	save_data = {
		"version": SAVE_VERSION,
		"owned_items": ["card_classic", "board_green"],
		"equipped": {
			"card_front": "card_classic",
			"card_back": "",
			"board": "board_green",
			"frame": "",
			"avatar": "",
			"emojis": [],
			"mini_profile_slots": {}
		},
		"item_sources": {
			"card_classic": ItemData.Source.DEFAULT,
			"board_green": ItemData.Source.DEFAULT
		},
		"unlock_dates": {},
		"bundle_history": [],
		"metadata": {}
	}
	save_player_data()

# === DEBUG ===
func debug_create_sample_items():
	"""Create sample items for testing"""
	# Create a sample card front
	var neon_card = ItemData.new()
	neon_card.id = "card_neon"
	neon_card.display_name = "Neon Cards"
	neon_card.description = "Futuristic neon glow cards"
	neon_card.category = ItemData.Category.CARD_FRONT
	neon_card.rarity = ItemData.Rarity.RARE
	neon_card.base_price = 250
	neon_card.subcategory = "futuristic"
	neon_card.set_name = "Cyberpunk Collection"
	ResourceSaver.save(neon_card, ITEMS_PATH + "card_fronts/neon.tres")
	
	# Create a sample board
	var sunset_board = ItemData.new()
	sunset_board.id = "board_sunset"
	sunset_board.display_name = "Sunset Board"
	sunset_board.description = "Beautiful sunset gradient"
	sunset_board.category = ItemData.Category.BOARD
	sunset_board.rarity = ItemData.Rarity.UNCOMMON
	sunset_board.base_price = 150
	sunset_board.colors = {"primary": Color(1.0, 0.5, 0.2), "secondary": Color(0.8, 0.2, 0.4)}
	ResourceSaver.save(sunset_board, ITEMS_PATH + "boards/sunset.tres")
	
	print("ItemManager: Created sample items")

func debug_print_status():
	print("\n=== ITEM MANAGER STATUS ===")
	print("Total items loaded: %d" % all_items.size())
	print("Total bundles loaded: %d" % all_bundles.size())
	print("Owned items: %d" % save_data.owned_items.size())
	print("Equipped:")
	for key in save_data.equipped:
		var value = save_data.equipped[key]
		if value != "" and value != []:
			print("  %s: %s" % [key, value])
	print("===========================\n")

# Add this debug function to ItemManager.gd and call it from _ready():

func debug_pyramid_board():
	print("\n=== PYRAMID BOARD DEBUG ===")
	
	# 1. Check if the file exists
	var pyramid_path = "res://Magic-Castle/resources/items/boards/pyramids.tres"
	if ResourceLoader.exists(pyramid_path):
		print("✓ File exists at: ", pyramid_path)
	else:
		print("✗ File NOT found at: ", pyramid_path)
		return
	
	# 2. Try to load it manually
	var pyramid_resource = load(pyramid_path)
	if pyramid_resource:
		print("✓ Resource loads successfully")
		print("  - Resource type: ", pyramid_resource.get_class())
		
		# 3. Check if it's an ItemData
		if pyramid_resource is ItemData:
			print("✓ Resource is ItemData")
			var item = pyramid_resource as ItemData
			print("  - ID: ", item.id)
			print("  - Display Name: ", item.display_name)
			print("  - Category: ", item.category)
			print("  - Background Type: ", item.background_type)
			print("  - Scene Path: ", item.background_scene_path)
			
			# 4. Check if ID is empty (common issue)
			if item.id == "":
				print("✗ ERROR: Item ID is empty! This prevents loading.")
				print("  FIX: Set the 'id' field to 'board_pyramids' in the resource")
			
			# 5. Check if it's in all_items
			if all_items.has(item.id):
				print("✓ Item IS in all_items dictionary")
			else:
				print("✗ Item NOT in all_items dictionary")
				print("  Attempting to register manually...")
				all_items[item.id] = item
				if all_items.has(item.id):
					print("  ✓ Manual registration successful!")
		else:
			print("✗ Resource is NOT ItemData, it's: ", pyramid_resource.get_class())
			print("  FIX: Make sure the resource has ItemData as its script")
	else:
		print("✗ Failed to load resource")
	
	print("=========================\n")
