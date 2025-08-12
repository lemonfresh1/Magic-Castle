# EquipmentManager.gd - Single source of truth for ALL equipment management
# Location: res://Pyramids/scripts/autoloads/EquipmentManager.gd
# Last Updated: Created with future category support [Date]

extends Node

# Signals for equipment changes
signal item_equipped(item_id: String, category: String)
signal item_unequipped(item_id: String, category: String)
signal equipment_changed(category: String)
signal ownership_changed(item_id: String, owned: bool)

# Save data
const SAVE_PATH = "user://equipment_data.save"
const SAVE_VERSION = 1

var save_data = {
	"version": SAVE_VERSION,
	"owned_items": [],  # Array of all owned item IDs
	"equipped": {
		# Current categories
		"card_front": "card_classic",
		"card_back": "",
		"board": "board_green",
		"frame": "",
		"avatar": "",
		"emoji": [],  # Array for multiple emojis
		
		# Future categories - TODO: Implement these systems
		"mini_profile": "",
		"mini_profile_showcased_items": [],  # Items shown on mini profile
		"mini_profile_showcased_stats": [],  # Stats shown on mini profile
		"mini_profile_showcased_achievements": [],  # Achievements shown
		
		"topbar": "",  # TODO: Implement topbar customization
		"combo_effect": "",  # TODO: Implement combo effects
		"menu_background": "",  # TODO: Can be same as board or separate
		"use_board_as_menu_bg": false  # TODO: Toggle for using board as menu bg
	},
	"favorites": {},  # category -> [item_ids] for quick swap
	"history": {},  # category -> [last 5 equipped items]
	"unlock_dates": {},  # item_id -> timestamp when unlocked
	"item_sources": {},  # item_id -> how it was obtained
	"stats": {
		"total_items_owned": 0,
		"items_by_category": {},
		"items_by_rarity": {},
		"total_equipped_time": {}  # item_id -> seconds equipped
	}
}

# Runtime cache
var items_by_category: Dictionary = {}  # category -> [item_ids]
var unified_items: Dictionary = {}  # item_id -> UnifiedItemData

func _ready():
	print("EquipmentManager initializing...")
	load_save_data()
	_migrate_from_old_systems()
	_ensure_defaults()
	_build_cache()
	print("EquipmentManager ready - %d items owned" % save_data.owned_items.size())

func _build_cache():
	"""Build runtime cache of items by category"""
	items_by_category.clear()
	
	# Initialize all categories including future ones
	var all_categories = ["card_front", "card_back", "board", "frame", "avatar", 
						  "emoji", "mini_profile", "topbar", "combo_effect", "menu_background"]
	
	for category in all_categories:
		items_by_category[category] = []
	
	# Sort owned items into categories
	for item_id in save_data.owned_items:
		var item = get_item_data(item_id)
		if item:
			if items_by_category.has(item.category):
				items_by_category[item.category].append(item_id)

# === CORE FUNCTIONS ===

func equip_item(item_id: String) -> bool:
	"""Equip an item - returns true if successful"""
	if not is_item_owned(item_id):
		push_error("EquipmentManager: Cannot equip unowned item: " + item_id)
		return false
	
	var item = get_item_data(item_id)
	if not item:
		push_error("EquipmentManager: Item not found: " + item_id)
		return false
	
	# Handle future categories
	if item.is_future_category():
		push_warning("EquipmentManager: " + item.get_todo_message())
		# Still allow equipping for testing
	
	var old_equipped = ""
	var category = item.category
	
	# Handle different category types
	match category:
		"emoji":
			# Emojis can have multiple equipped
			if not item_id in save_data.equipped.emoji:
				if save_data.equipped.emoji.size() < 8:  # Max 8 emojis
					save_data.equipped.emoji.append(item_id)
				else:
					push_warning("EquipmentManager: Max emojis equipped")
					return false
		
		"mini_profile":
			# TODO: Special handling for mini profile
			old_equipped = save_data.equipped.mini_profile
			save_data.equipped.mini_profile = item_id
			push_warning("TODO: Implement mini profile showcase UI")
		
		"combo_effect":
			# TODO: Apply combo effect to game
			old_equipped = save_data.equipped.combo_effect
			save_data.equipped.combo_effect = item_id
			push_warning("TODO: Apply combo effect in CardManager")
		
		"topbar":
			# TODO: Apply topbar skin
			old_equipped = save_data.equipped.topbar
			save_data.equipped.topbar = item_id
			push_warning("TODO: Apply topbar skin to MobileTopBar")
		
		"menu_background":
			# TODO: Apply menu background
			old_equipped = save_data.equipped.menu_background
			save_data.equipped.menu_background = item_id
			push_warning("TODO: Apply background to MainMenu")
		
		_:
			# Standard single-equip categories
			old_equipped = save_data.equipped.get(category, "")
			save_data.equipped[category] = item_id
	
	# Update history
	_add_to_history(category, item_id)
	
	# Track equipped time
	if not save_data.stats.total_equipped_time.has(item_id):
		save_data.stats.total_equipped_time[item_id] = 0
	
	# Save and emit signals
	save_data_to_file()
	
	if old_equipped != "" and old_equipped != item_id:
		item_unequipped.emit(old_equipped, category)
	
	item_equipped.emit(item_id, category)
	equipment_changed.emit(category)
	
	print("EquipmentManager: Equipped %s in category %s" % [item_id, category])
	return true

func unequip_item(item_id: String) -> bool:
	"""Unequip an item - returns true if successful"""
	var item = get_item_data(item_id)
	if not item:
		return false
	
	var category = item.category
	
	match category:
		"emoji":
			save_data.equipped.emoji.erase(item_id)
		"mini_profile":
			if save_data.equipped.mini_profile == item_id:
				save_data.equipped.mini_profile = ""
				# Also clear showcased items
				save_data.equipped.mini_profile_showcased_items.clear()
				save_data.equipped.mini_profile_showcased_stats.clear()
				save_data.equipped.mini_profile_showcased_achievements.clear()
		_:
			if save_data.equipped.get(category, "") == item_id:
				save_data.equipped[category] = ""
	
	save_data_to_file()
	item_unequipped.emit(item_id, category)
	equipment_changed.emit(category)
	
	return true

func grant_item(item_id: String, source: String = "shop") -> bool:
	"""Grant an item to the player"""
	if is_item_owned(item_id):
		push_warning("EquipmentManager: Item already owned: " + item_id)
		return false
	
	save_data.owned_items.append(item_id)
	save_data.unlock_dates[item_id] = Time.get_unix_time_from_system()
	save_data.item_sources[item_id] = source
	
	# Update stats
	save_data.stats.total_items_owned += 1
	
	var item = get_item_data(item_id)
	if item:
		# Update category stats
		if not save_data.stats.items_by_category.has(item.category):
			save_data.stats.items_by_category[item.category] = 0
		save_data.stats.items_by_category[item.category] += 1
		
		# Update rarity stats
		if not save_data.stats.items_by_rarity.has(item.rarity):
			save_data.stats.items_by_rarity[item.rarity] = 0
		save_data.stats.items_by_rarity[item.rarity] += 1
		
		# Update cache
		if items_by_category.has(item.category):
			items_by_category[item.category].append(item_id)
		
		# Auto-equip if first of category
		if should_auto_equip(item):
			equip_item(item_id)
	
	save_data_to_file()
	ownership_changed.emit(item_id, true)
	
	print("EquipmentManager: Granted item %s from %s" % [item_id, source])
	return true

# === QUERY FUNCTIONS ===

func is_item_owned(item_id: String) -> bool:
	return item_id in save_data.owned_items

func is_item_equipped(item_id: String) -> bool:
	var item = get_item_data(item_id)
	if not item:
		return false
	
	match item.category:
		"emoji":
			return item_id in save_data.equipped.emoji
		_:
			return save_data.equipped.get(item.category, "") == item_id

func get_equipped_item(category: String) -> String:
	"""Get the currently equipped item for a category"""
	if category == "emoji":
		push_warning("Use get_equipped_emojis() for emoji category")
		return ""
	return save_data.equipped.get(category, "")

func get_equipped_emojis() -> Array:
	"""Get all equipped emojis"""
	return save_data.equipped.emoji.duplicate()

func get_equipped_items() -> Dictionary:
	"""Get all equipped items as a dictionary"""
	return save_data.equipped.duplicate(true)

func get_owned_items(category: String = "") -> Array:
	"""Get all owned items, optionally filtered by category"""
	if category == "":
		return save_data.owned_items.duplicate()
	
	return items_by_category.get(category, []).duplicate()

func get_item_data(item_id: String) -> UnifiedItemData:
	"""Get UnifiedItemData for an item"""
	# Check cache first
	if unified_items.has(item_id):
		return unified_items[item_id]
	
	# Try to load from various sources
	var item_data = _load_item_from_sources(item_id)
	if item_data:
		unified_items[item_id] = item_data
	
	return item_data

# === MINI PROFILE SPECIFIC === TODO: Implement UI for these

func set_mini_profile_showcase(items: Array, stats: Array, achievements: Array) -> void:
	"""Set what's displayed on the mini profile card"""
	if not save_data.equipped.mini_profile:
		push_warning("No mini profile equipped")
		return
	
	var profile = get_item_data(save_data.equipped.mini_profile)
	if not profile:
		return
	
	# Validate limits
	var max_slots = profile.showcase_slots if profile else 3
	
	save_data.equipped.mini_profile_showcased_items = items.slice(0, min(items.size(), max_slots))
	save_data.equipped.mini_profile_showcased_stats = stats.slice(0, min(stats.size(), max_slots))
	save_data.equipped.mini_profile_showcased_achievements = achievements.slice(0, min(achievements.size(), max_slots))
	
	save_data_to_file()
	equipment_changed.emit("mini_profile_showcase")
	
	push_warning("TODO: Update mini profile display in UI")

# === MENU BACKGROUND SPECIFIC === TODO: Implement in MainMenu

func toggle_board_as_menu_background(enabled: bool) -> void:
	"""Toggle using the game board as menu background"""
	save_data.equipped.use_board_as_menu_bg = enabled
	save_data_to_file()
	equipment_changed.emit("menu_background")
	push_warning("TODO: Apply to MainMenu scene")

func get_menu_background() -> String:
	"""Get the current menu background (board or dedicated background)"""
	if save_data.equipped.use_board_as_menu_bg:
		return save_data.equipped.board
	return save_data.equipped.menu_background if save_data.equipped.menu_background else save_data.equipped.board

# === HELPER FUNCTIONS ===

func should_auto_equip(item: UnifiedItemData) -> bool:
	"""Check if an item should auto-equip when granted"""
	if item.category == "emoji":
		return save_data.equipped.emoji.size() < 8
	
	return save_data.equipped.get(item.category, "") == ""

func _add_to_history(category: String, item_id: String) -> void:
	"""Add item to equipment history for quick swap"""
	if not save_data.history.has(category):
		save_data.history[category] = []
	
	var history = save_data.history[category]
	
	# Remove if already in history
	history.erase(item_id)
	
	# Add to front
	history.insert(0, item_id)
	
	# Keep only last 5
	if history.size() > 5:
		history.resize(5)

func _load_item_from_sources(item_id: String) -> UnifiedItemData:
	"""Try to load item data from various sources"""
	var unified = UnifiedItemData.new()
	
	# Try ItemManager first
	if ItemManager and ItemManager.all_items.has(item_id):
		unified.from_item_data(ItemManager.all_items[item_id])
		return unified
	
	# Try ShopManager
	if ShopManager:
		var shop_item = ShopManager.get_item_by_id(item_id)
		if shop_item:
			unified.from_shop_item(shop_item)
			return unified
	
	# Try ProceduralItemRegistry
	if ProceduralItemRegistry and ProceduralItemRegistry.procedural_items.has(item_id):
		var proc_data = ProceduralItemRegistry.procedural_items[item_id]
		unified.from_procedural_instance(proc_data.instance, proc_data.category)
		return unified
	
	return null

func _migrate_from_old_systems() -> void:
	"""Migrate data from ItemManager and ShopManager"""
	var migrated = false
	
	# Migrate from ItemManager
	if ItemManager and ItemManager.save_data:
		for item_id in ItemManager.save_data.owned_items:
			if not item_id in save_data.owned_items:
				save_data.owned_items.append(item_id)
				migrated = true
		
		# Migrate equipped items
		if ItemManager.save_data.equipped.card_front:
			save_data.equipped.card_front = ItemManager.save_data.equipped.card_front
		if ItemManager.save_data.equipped.card_back:
			save_data.equipped.card_back = ItemManager.save_data.equipped.card_back
		if ItemManager.save_data.equipped.board:
			save_data.equipped.board = ItemManager.save_data.equipped.board
	
	# Migrate from ShopManager
	if ShopManager and ShopManager.shop_data:
		for item_id in ShopManager.shop_data.owned_items:
			if not item_id in save_data.owned_items:
				save_data.owned_items.append(item_id)
				migrated = true
	
	if migrated:
		print("EquipmentManager: Migrated data from old systems")
		save_data_to_file()

func _ensure_defaults() -> void:
	"""Ensure default items are owned and equipped"""
	# Default items that should always be owned
	var defaults = {
		"card_front": "card_classic",
		"board": "board_green"
	}
	
	for category in defaults:
		var item_id = defaults[category]
		
		# Ensure owned
		if not item_id in save_data.owned_items:
			save_data.owned_items.append(item_id)
			save_data.item_sources[item_id] = "default"
		
		# Ensure equipped if nothing else is
		if save_data.equipped.get(category, "") == "":
			save_data.equipped[category] = item_id

# === PERSISTENCE ===

func save_data_to_file() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("EquipmentManager: No save file found, using defaults")
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var loaded_data = file.get_var()
		file.close()
		
		if loaded_data and loaded_data.has("version"):
			if loaded_data.version == SAVE_VERSION:
				save_data = loaded_data
			else:
				_migrate_save_data(loaded_data)

func _migrate_save_data(old_data: Dictionary) -> void:
	"""Handle save data migration from older versions"""
	print("EquipmentManager: Migrating save from version %d to %d" % [old_data.get("version", 0), SAVE_VERSION])
	# Add migration logic as needed

func reset_all_equipment() -> void:
	"""Reset to default state"""
	save_data = {
		"version": SAVE_VERSION,
		"owned_items": ["card_classic", "board_green"],
		"equipped": {
			"card_front": "card_classic",
			"card_back": "",
			"board": "board_green",
			"frame": "",
			"avatar": "",
			"emoji": [],
			"mini_profile": "",
			"mini_profile_showcased_items": [],
			"mini_profile_showcased_stats": [],
			"mini_profile_showcased_achievements": [],
			"topbar": "",
			"combo_effect": "",
			"menu_background": "",
			"use_board_as_menu_bg": false
		},
		"favorites": {},
		"history": {},
		"unlock_dates": {},
		"item_sources": {
			"card_classic": "default",
			"board_green": "default"
		},
		"stats": {
			"total_items_owned": 2,
			"items_by_category": {"card_front": 1, "board": 1},
			"items_by_rarity": {"common": 2},
			"total_equipped_time": {}
		}
	}
	save_data_to_file()

# === DEBUG ===

func debug_status() -> void:
	print("\n=== EQUIPMENT MANAGER STATUS ===")
	print("Owned items: %d" % save_data.owned_items.size())
	print("Equipped:")
	for category in save_data.equipped:
		var value = save_data.equipped[category]
		
		# Check if value has meaningful content based on its type
		match typeof(value):
			TYPE_STRING:
				if value != "":
					print("  %s: %s" % [category, value])
			TYPE_ARRAY:
				if value.size() > 0:
					print("  %s: %s" % [category, value])
			TYPE_BOOL:
				if value:
					print("  %s: %s" % [category, value])
			_:
				if value != null:
					print("  %s: %s" % [category, value])
	
	print("Stats:")
	print("  By category: %s" % save_data.stats.items_by_category)
	print("  By rarity: %s" % save_data.stats.items_by_rarity)
	print("================================\n")
