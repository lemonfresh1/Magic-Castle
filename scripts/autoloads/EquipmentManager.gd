# EquipmentManager.gd - Single source of truth for ALL equipment management
# Location: res://Pyramids/scripts/autoloads/EquipmentManager.gd
# Last Updated: Removed legacy code, streamlined with ItemManager [Date]
#
# EquipmentManager handles:
# - Item ownership tracking
# - Equipment state management
# - Save/load of player's collection
# - Equipment history and favorites
# - Statistics tracking
#
# Flow: ItemManager (definitions) → EquipmentManager (ownership) → UIs
# Dependencies: ItemManager (for item data), UnifiedItemData (for item structure)

extends Node

# Signals for equipment changes
signal item_equipped(item_id: String, category: String)
signal item_unequipped(item_id: String, category: String)
signal equipment_changed(category: String)
signal ownership_changed(item_id: String, owned: bool)
signal item_granted(item_id: String, source: String)

# Save data
const SAVE_PATH = "user://equipment_data.save"
const SAVE_VERSION = 2  # Incremented for clean break from old data

var save_data = {
	"version": SAVE_VERSION,
	"owned_items": [],  # Array of all owned item IDs
	"equipped": {
		# Current categories
		"card_front": "card_classic",
		"card_back": "",
		"board": "classic_board",
		"mini_profile_card": "",
		"frame": "",
		"avatar": "",
		"emoji": [],  # Array for multiple emojis
		
		# Future categories - TODO: Implement these systems
		"mini_profile_card_showcased_items": [],  # Items shown on mini profile
		"mini_profile_card_showcased_stats": [],  # Stats shown on mini profile
		"mini_profile_card_showcased_achievements": [],  # Achievements shown
		
		"topbar": "",  # TODO: Implement topbar customization
		"combo_effect": "",  # TODO: Implement combo effects
		"menu_background": "",  # TODO: Can be same as board or separate
		"use_board_as_menu_bg": false  # TODO: Toggle for using board as menu bg
	},
	"favorites": {},  # category -> [item_ids] for quick swap
	"history": {},  # category -> [last 5 equipped items]
	"unlock_dates": {},  # item_id -> timestamp when unlocked
	"item_sources": {},  # item_id -> how it was obtained (string)
	"stats": {
		"total_items_owned": 0,
		"items_by_category": {},
		"items_by_rarity": {},
		"total_equipped_time": {},  # item_id -> seconds equipped
		"times_equipped": {}  # item_id -> count
	}
}

# Runtime cache
var items_by_category: Dictionary = {}  # category -> [item_ids]

func _ready():
	load_save_data()
	_ensure_defaults()
	_build_cache()
	_validate_equipped_items()

func _build_cache():
	"""Build runtime cache of items by category"""
	items_by_category.clear()
	
	# Initialize all categories including future ones
	var all_categories = ["card_front", "card_back", "board", "frame", "avatar", 
						  "emoji", "mini_profile_card", "topbar", "combo_effect", "menu_background"]
	
	for category in all_categories:
		items_by_category[category] = []
	
	# Sort owned items into categories
	for item_id in save_data.owned_items:
		if not ItemManager:
			continue
			
		var item = ItemManager.get_item(item_id)
		if item:
			var category_key = _get_category_key(item.category)
			if items_by_category.has(category_key):
				items_by_category[category_key].append(item_id)

func _validate_equipped_items():
	"""Ensure all equipped items are actually owned"""
	for category in save_data.equipped:
		var value = save_data.equipped[category]
		
		match typeof(value):
			TYPE_STRING:
				if value != "" and not is_item_owned(value):
					push_warning("EquipmentManager: Unequipping unowned item %s from %s" % [value, category])
					save_data.equipped[category] = ""
			TYPE_ARRAY:
				var valid_items = []
				for item_id in value:
					if is_item_owned(item_id):
						valid_items.append(item_id)
					else:
						push_warning("EquipmentManager: Removing unowned item %s from %s" % [item_id, category])
				save_data.equipped[category] = valid_items

# === CORE FUNCTIONS ===

func equip_item(item_id: String) -> bool:
	"""Equip an item - returns true if successful"""
	if not is_item_owned(item_id):
		push_error("EquipmentManager: Cannot equip unowned item: " + item_id)
		return false
	
	if not ItemManager:
		push_error("EquipmentManager: ItemManager not available")
		return false
	
	var item = ItemManager.get_item(item_id)
	if not item:
		push_error("EquipmentManager: Item not found: " + item_id)
		return false
	
	# Handle future categories
	if item.has_method("is_future_category") and item.is_future_category():
		push_warning("EquipmentManager: Future category - " + item.get_todo_message())
		# Still allow equipping for testing
	
	var old_equipped = ""
	var category = item.category
	var category_key = _get_category_key(category)
	
	# Handle different category types
	match category:
		UnifiedItemData.Category.EMOJI:
			# Max 4 emojis
			if not item_id in save_data.equipped.emoji:
				if save_data.equipped.emoji.size() < 4:
					save_data.equipped.emoji.append(item_id)
				else:
					# Replace oldest
					push_warning("EquipmentManager: Max 4 emojis, replacing oldest")
					var old_emoji = save_data.equipped.emoji[0]
					save_data.equipped.emoji.erase(old_emoji)
					save_data.equipped.emoji.append(item_id)
					item_unequipped.emit(old_emoji, "emoji")
		
		UnifiedItemData.Category.MINI_PROFILE_CARD:
			old_equipped = save_data.equipped.mini_profile_card
			save_data.equipped.mini_profile_card = item_id
			# TODO: Implement mini profile showcase UI
		
		UnifiedItemData.Category.COMBO_EFFECT:
			old_equipped = save_data.equipped.combo_effect
			save_data.equipped.combo_effect = item_id
			# TODO: Apply combo effect in CardManager
		
		UnifiedItemData.Category.TOPBAR:
			old_equipped = save_data.equipped.topbar
			save_data.equipped.topbar = item_id
			# TODO: Apply topbar skin to MobileTopBar
		
		UnifiedItemData.Category.MENU_BACKGROUND:
			old_equipped = save_data.equipped.menu_background
			save_data.equipped.menu_background = item_id
			# TODO: Apply background to MainMenu
		
		_:
			# Standard single-equip categories
			old_equipped = save_data.equipped.get(category_key, "")
			save_data.equipped[category_key] = item_id
	
	# Update history
	_add_to_history(category_key, item_id)
	
	# Track equipment stats
	if not save_data.stats.times_equipped.has(item_id):
		save_data.stats.times_equipped[item_id] = 0
	save_data.stats.times_equipped[item_id] += 1
	
	if not save_data.stats.total_equipped_time.has(item_id):
		save_data.stats.total_equipped_time[item_id] = 0
	
	# Save and emit signals
	save_data_to_file()
	
	if old_equipped != "" and old_equipped != item_id:
		item_unequipped.emit(old_equipped, category_key)
	
	item_equipped.emit(item_id, category_key)
	equipment_changed.emit(category_key)
	
	return true

func unequip_item(item_id: String) -> bool:
	"""Unequip an item - returns true if successful"""
	if not ItemManager:
		return false
		
	var item = ItemManager.get_item(item_id)
	if not item:
		return false
	
	var category = item.category
	var category_key = _get_category_key(category)
	
	match category:
		UnifiedItemData.Category.EMOJI:
			save_data.equipped.emoji.erase(item_id)
		UnifiedItemData.Category.MINI_PROFILE_CARD:
			if save_data.equipped.mini_profile_card == item_id:
				save_data.equipped.mini_profile_card = ""
				# Also clear showcased items
				save_data.equipped.mini_profile_card_showcased_items.clear()
				save_data.equipped.mini_profile_card_showcased_stats.clear()
				save_data.equipped.mini_profile_card_showcased_achievements.clear()
		_:
			if save_data.equipped.get(category_key, "") == item_id:
				save_data.equipped[category_key] = ""
	
	save_data_to_file()
	item_unequipped.emit(item_id, category_key)
	equipment_changed.emit(category_key)
	
	return true

func grant_item(item_id: String, source: String = "shop") -> bool:
	"""Grant an item to the player"""
	if is_item_owned(item_id):
		push_warning("EquipmentManager: Item already owned: " + item_id)
		return false
	
	if not ItemManager:
		push_error("EquipmentManager: ItemManager not available")
		return false
	
	var item = ItemManager.get_item(item_id)
	if not item:
		push_error("EquipmentManager: Item not found in ItemManager: " + item_id)
		return false
	
	# Add to owned items
	save_data.owned_items.append(item_id)
	save_data.unlock_dates[item_id] = Time.get_unix_time_from_system()
	save_data.item_sources[item_id] = source
	
	# Update stats
	save_data.stats.total_items_owned += 1
	
	var category_key = _get_category_key(item.category)
	
	# Update category stats
	if not save_data.stats.items_by_category.has(category_key):
		save_data.stats.items_by_category[category_key] = 0
	save_data.stats.items_by_category[category_key] += 1
	
	# Update rarity stats
	var rarity_key = item.get_rarity_name().to_lower()
	if not save_data.stats.items_by_rarity.has(rarity_key):
		save_data.stats.items_by_rarity[rarity_key] = 0
	save_data.stats.items_by_rarity[rarity_key] += 1
	
	# Update cache
	if items_by_category.has(category_key):
		items_by_category[category_key].append(item_id)
	
	# Auto-equip if first of category
	if should_auto_equip(item):
		equip_item(item_id)
	
	save_data_to_file()
	ownership_changed.emit(item_id, true)
	item_granted.emit(item_id, source)
	
	return true

func revoke_item(item_id: String) -> bool:
	"""Remove an item from player's collection (for testing/admin)"""
	if not is_item_owned(item_id):
		return false
	
	# Unequip if equipped
	if is_item_equipped(item_id):
		unequip_item(item_id)
	
	# Remove from owned items
	save_data.owned_items.erase(item_id)
	
	# Update stats
	save_data.stats.total_items_owned = max(0, save_data.stats.total_items_owned - 1)
	
	if ItemManager:
		var item = ItemManager.get_item(item_id)
		if item:
			var category_key = _get_category_key(item.category)
			if save_data.stats.items_by_category.has(category_key):
				save_data.stats.items_by_category[category_key] = max(0, save_data.stats.items_by_category[category_key] - 1)
			
			# Update cache
			if items_by_category.has(category_key):
				items_by_category[category_key].erase(item_id)
	
	# Remove from favorites and history
	for category in save_data.favorites:
		save_data.favorites[category].erase(item_id)
	for category in save_data.history:
		save_data.history[category].erase(item_id)
	
	save_data_to_file()
	ownership_changed.emit(item_id, false)
	
	return true

# === SHOWCASE/DISPLAY FUNCTIONS ===

signal showcase_items_changed()

func get_showcased_items() -> Array:
	"""Get showcased items - initially returns equipped for testing"""
	# For now, return equipped items if showcase is empty
	if save_data.equipped.mini_profile_card_showcased_items.is_empty():
		# Return first 3 equipped items as default
		var equipped = []
		if save_data.equipped.card_back != "":
			equipped.append(save_data.equipped.card_back)
		if save_data.equipped.card_front != "":
			equipped.append(save_data.equipped.card_front)
		if save_data.equipped.board != "":
			equipped.append(save_data.equipped.board)
		# Pad with empty strings to ensure 3 slots
		while equipped.size() < 3:
			equipped.append("")
		return equipped.slice(0, 3)
	
	return save_data.equipped.mini_profile_card_showcased_items.duplicate()

func update_showcased_item(slot_index: int, item_id: String) -> void:
	"""Update a specific showcase slot"""
	# Ensure array has 3 slots
	while save_data.equipped.mini_profile_card_showcased_items.size() < 3:
		save_data.equipped.mini_profile_card_showcased_items.append("")
	
	# Update the slot
	save_data.equipped.mini_profile_card_showcased_items[slot_index] = item_id
	
	save_data_to_file()
	showcase_items_changed.emit()

func clear_showcased_item(slot_index: int) -> void:
	"""Clear a showcase slot"""
	update_showcased_item(slot_index, "")

# === QUERY FUNCTIONS ===

func is_item_owned(item_id: String) -> bool:
	"""Check if player owns an item"""
	return item_id in save_data.owned_items

func is_item_equipped(item_id: String) -> bool:
	"""Check if an item is currently equipped"""
	if not ItemManager:
		return false
		
	var item = ItemManager.get_item(item_id)
	if not item:
		return false
	
	match item.category:
		UnifiedItemData.Category.EMOJI:
			return item_id in save_data.equipped.emoji
		_:
			var category_key = _get_category_key(item.category)
			return save_data.equipped.get(category_key, "") == item_id

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
	"""Get all owned item IDs, optionally filtered by category"""
	if category == "":
		return save_data.owned_items.duplicate()
	
	return items_by_category.get(category, []).duplicate()

func get_owned_count() -> int:
	"""Get total number of owned items"""
	return save_data.owned_items.size()

func get_owned_count_by_category(category: String) -> int:
	"""Get number of owned items in a category"""
	return items_by_category.get(category, []).size()

# === FAVORITES & HISTORY ===

func add_to_favorites(item_id: String) -> bool:
	"""Add an item to favorites for quick access"""
	if not is_item_owned(item_id):
		return false
	
	if not ItemManager:
		return false
		
	var item = ItemManager.get_item(item_id)
	if not item:
		return false
	
	var category_key = _get_category_key(item.category)
	
	if not save_data.favorites.has(category_key):
		save_data.favorites[category_key] = []
	
	if not item_id in save_data.favorites[category_key]:
		save_data.favorites[category_key].append(item_id)
		save_data_to_file()
	
	return true

func remove_from_favorites(item_id: String) -> bool:
	"""Remove an item from favorites"""
	for category in save_data.favorites:
		if item_id in save_data.favorites[category]:
			save_data.favorites[category].erase(item_id)
			save_data_to_file()
			return true
	return false

func get_favorites(category: String = "") -> Array:
	"""Get favorite items, optionally filtered by category"""
	if category != "":
		return save_data.favorites.get(category, []).duplicate()
	
	var all_favorites = []
	for cat in save_data.favorites:
		all_favorites.append_array(save_data.favorites[cat])
	return all_favorites

func get_history(category: String) -> Array:
	"""Get equipment history for a category"""
	return save_data.history.get(category, []).duplicate()

# === MINI PROFILE SPECIFIC ===

func set_mini_profile_card_showcase(items: Array, stats: Array, achievements: Array) -> void:
	"""Set what's displayed on the mini profile card"""
	if not save_data.equipped.mini_profile_card:
		push_warning("No mini profile equipped")
		return
	
	if ItemManager:
		var profile = ItemManager.get_item(save_data.equipped.mini_profile_card)
		if profile:
			# Validate limits (default to 3 if property doesn't exist)
			var max_slots = profile.get("showcase_slots") if profile.has("showcase_slots") else 3
			
			save_data.equipped.mini_profile_card_showcased_items = items.slice(0, min(items.size(), max_slots))
			save_data.equipped.mini_profile_card_showcased_stats = stats.slice(0, min(stats.size(), max_slots))
			save_data.equipped.mini_profile_card_showcased_achievements = achievements.slice(0, min(achievements.size(), max_slots))
			
			save_data_to_file()
			equipment_changed.emit("mini_profile_card_showcase")

# === MENU BACKGROUND SPECIFIC ===

func toggle_board_as_menu_background(enabled: bool) -> void:
	"""Toggle using the game board as menu background"""
	save_data.equipped.use_board_as_menu_bg = enabled
	save_data_to_file()
	equipment_changed.emit("menu_background")

func get_menu_background() -> String:
	"""Get the current menu background (board or dedicated background)"""
	if save_data.equipped.use_board_as_menu_bg:
		return save_data.equipped.board
	return save_data.equipped.menu_background if save_data.equipped.menu_background else save_data.equipped.board

# === HELPER FUNCTIONS ===

func should_auto_equip(item: UnifiedItemData) -> bool:
	"""Check if an item should auto-equip when granted"""
	if item.category == UnifiedItemData.Category.EMOJI:
		return save_data.equipped.emoji.size() < 8
	
	var category_key = _get_category_key(item.category)
	return save_data.equipped.get(category_key, "") == ""

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

func _ensure_defaults() -> void:
	"""Ensure default items are owned and equipped AND all keys exist"""
	# First, ensure the equipped dictionary has all required keys
	var required_equipped_keys = {
		"card_front": "",
		"card_back": "",
		"board": "",
		"frame": "",
		"avatar": "",
		"emoji": [],
		"mini_profile_card": "",
		"mini_profile_card_showcased_items": [],
		"mini_profile_card_showcased_stats": [],
		"mini_profile_card_showcased_achievements": [],
		"topbar": "",
		"combo_effect": "",
		"menu_background": "",
		"use_board_as_menu_bg": false
	}
	
	# Add any missing keys to equipped
	for key in required_equipped_keys:
		if not save_data.equipped.has(key):
			save_data.equipped[key] = required_equipped_keys[key]
	
	# Default items that should always be owned
	var defaults = {
		"card_front": "card_classic",
		"card_back": "classic_card_back",
		"board": "classic_board",
		"emoji": ["emoji_cool", "emoji_cry", "emoji_curse", "emoji_love"]
	}
	
	for category in defaults:
		if category == "emoji":
			# Handle emoji array differently
			for emoji_id in defaults[category]:
				# Ensure owned
				if not emoji_id in save_data.owned_items:
					save_data.owned_items.append(emoji_id)
					save_data.item_sources[emoji_id] = "default"
					save_data.stats.total_items_owned += 1
				
				# Auto-equip if not already equipped
				if not emoji_id in save_data.equipped.emoji:
					save_data.equipped.emoji.append(emoji_id)
		else:
			var item_id = defaults[category]
			
			# Ensure owned
			if not item_id in save_data.owned_items:
				save_data.owned_items.append(item_id)
				save_data.item_sources[item_id] = "default"
				save_data.stats.total_items_owned += 1
			
			# Ensure equipped if nothing else is
			if save_data.equipped.get(category, "") == "":
				save_data.equipped[category] = item_id

# === PERSISTENCE ===

func save_data_to_file() -> void:
	"""Save equipment data to disk"""
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_save_data() -> void:
	"""Load equipment data from disk"""
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var loaded_data = file.get_var()
		file.close()
		
		if loaded_data and loaded_data.has("version"):
			if loaded_data.version == SAVE_VERSION:
				save_data = loaded_data
			elif loaded_data.version < SAVE_VERSION:
				_migrate_save_data(loaded_data)

func _migrate_save_data(old_data: Dictionary) -> void:
	"""Handle save data migration from older versions"""
	print("EquipmentManager: Migrating save from version %d to %d" % [old_data.get("version", 0), SAVE_VERSION])
	
	# Start with fresh save structure
	var new_save = {
		"version": SAVE_VERSION,
		"owned_items": [],
		"equipped": {
			"card_front": "card_classic",
			"card_back": "",
			"board": "board_green",
			"frame": "",
			"avatar": "",
			"emoji": [],
			"mini_profile_card": "",
			"mini_profile_card_showcased_items": [],
			"mini_profile_card_showcased_stats": [],
			"mini_profile_card_showcased_achievements": [],
			"topbar": "",
			"combo_effect": "",
			"menu_background": "",
			"use_board_as_menu_bg": false
		},
		"favorites": {},
		"history": {},
		"unlock_dates": {},
		"item_sources": {},
		"stats": {
			"total_items_owned": 0,
			"items_by_category": {},
			"items_by_rarity": {},
			"total_equipped_time": {},
			"times_equipped": {}
		}
	}
	
	# Copy over existing data
	if old_data.has("owned_items"):
		new_save.owned_items = old_data.owned_items
	
	if old_data.has("equipped"):
		# Merge old equipped with new structure
		for key in old_data.equipped:
			if new_save.equipped.has(key):
				new_save.equipped[key] = old_data.equipped[key]
	
	if old_data.has("favorites"):
		new_save.favorites = old_data.favorites
	if old_data.has("history"):
		new_save.history = old_data.history
	if old_data.has("unlock_dates"):
		new_save.unlock_dates = old_data.unlock_dates
	if old_data.has("item_sources"):
		new_save.item_sources = old_data.item_sources
	if old_data.has("stats"):
		new_save.stats = old_data.stats
	
	save_data = new_save
	save_data_to_file()

func reset_all_equipment() -> void:
	"""Reset to default state (for testing or new game)"""
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
			"mini_profile_card": "",
			"mini_profile_card_showcased_items": [],
			"mini_profile_card_showcased_stats": [],
			"mini_profile_card_showcased_achievements": [],
			"topbar": "",
			"combo_effect": "",
			"menu_background": "",
			"use_board_as_menu_bg": false
		},
		"favorites": {},
		"history": {},
		"unlock_dates": {
			"card_classic": Time.get_unix_time_from_system(),
			"board_green": Time.get_unix_time_from_system()
		},
		"item_sources": {
			"card_classic": "default",
			"board_green": "default"
		},
		"stats": {
			"total_items_owned": 2,
			"items_by_category": {"card_front": 1, "board": 1},
			"items_by_rarity": {"common": 2},
			"total_equipped_time": {},
			"times_equipped": {}
		}
	}
	save_data_to_file()
	_build_cache()

# === CATEGORY CONVERSION ===

func _get_category_key(category) -> String:
	"""Convert enum category to string key for save data"""
	# Handle if already a string
	if typeof(category) == TYPE_STRING:
		return category
	
	# Handle enum (int) conversion
	if typeof(category) == TYPE_INT:
		match category:
			UnifiedItemData.Category.CARD_FRONT:
				return "card_front"
			UnifiedItemData.Category.CARD_BACK:
				return "card_back"
			UnifiedItemData.Category.BOARD:
				return "board"
			UnifiedItemData.Category.FRAME:
				return "frame"
			UnifiedItemData.Category.AVATAR:
				return "avatar"
			UnifiedItemData.Category.EMOJI:
				return "emoji"
			UnifiedItemData.Category.MINI_PROFILE_CARD:
				return "mini_profile_card"
			UnifiedItemData.Category.TOPBAR:
				return "topbar"
			UnifiedItemData.Category.COMBO_EFFECT:
				return "combo_effect"
			UnifiedItemData.Category.MENU_BACKGROUND:
				return "menu_background"
			_:
				return ""
	
	return ""

# === DEBUG ===

func debug_status() -> void:
	"""Print comprehensive equipment status"""
	print("\n=== EQUIPMENT MANAGER STATUS ===")
	print("Owned items: %d" % save_data.owned_items.size())
	print("\nEquipped items:")
	for category in save_data.equipped:
		var value = save_data.equipped[category]
		
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
	
	print("\nStatistics:")
	print("  Total owned: %d" % save_data.stats.total_items_owned)
	print("  By category: %s" % save_data.stats.items_by_category)
	print("  By rarity: %s" % save_data.stats.items_by_rarity)
	
	if save_data.favorites.size() > 0:
		print("\nFavorites:")
		for category in save_data.favorites:
			if save_data.favorites[category].size() > 0:
				print("  %s: %s" % [category, save_data.favorites[category]])
	
	print("================================\n")

func debug_grant_all_items() -> void:
	"""Grant all items for testing (debug only)"""
	if not ItemManager:
		push_error("ItemManager not available")
		return
	
	var granted = 0
	for item_id in ItemManager.all_items:
		if not is_item_owned(item_id):
			if grant_item(item_id, "debug"):
				granted += 1
	
	print("EquipmentManager: Granted %d items for debug" % granted)

func debug_grant_random_items(count: int = 5) -> void:
	"""Grant random items for testing"""
	if not ItemManager:
		push_error("ItemManager not available")
		return
	
	var available = []
	for item_id in ItemManager.all_items:
		if not is_item_owned(item_id):
			available.append(item_id)
	
	available.shuffle()
	
	var granted = 0
	for i in min(count, available.size()):
		if grant_item(available[i], "debug"):
			granted += 1
	
	print("EquipmentManager: Granted %d random items for debug" % granted)
