# ProceduralItemRegistry.gd - Auto-discovers and registers all procedural items
# Location: res://Pyramids/scripts/autoloads/ProceduralItemRegistry.gd
# Last Updated: Cleaned up debug output, preserved all functionality [Date]
#
# ProceduralItemRegistry handles:
# - Auto-discovery of procedural item scripts
# - Registration with ItemManager
# - PNG export functionality
# - .tres file generation
#
# Flow: Procedural scripts → ProceduralItemRegistry → ItemManager
# Dependencies: ItemManager (for registration), UnifiedItemData (resource type)

extends Node

# === CONSTANTS ===
const CATEGORIES = [
	"card_fronts",
	"card_backs", 
	"boards",
	"frames",
	"avatars",
	"emojis",
	"mini_profile_boards"
]

const BASE_PATH = "res://Pyramids/scripts/items/"

# === PROPERTIES ===
var procedural_items: Dictionary = {}
var registered_count: int = 0

# === LIFECYCLE ===

func _ready():
	discover_and_register_all()

# === DISCOVERY & REGISTRATION ===

func discover_and_register_all() -> void:
	procedural_items.clear()
	registered_count = 0
	
	for category in CATEGORIES:
		var category_path = BASE_PATH + category + "/procedural/"
		_scan_category(category, category_path)
	
	_register_with_managers()

func _scan_category(category: String, path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	
	var dir = DirAccess.open(path)
	if not dir:
		return
	
	_scan_directory_recursive(category, path, dir)

func _scan_directory_recursive(category: String, current_path: String, dir: DirAccess) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = current_path + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_scan_directory_recursive(category, full_path + "/", sub_dir)
		elif file_name.ends_with(".gd") and not file_name.begins_with("Procedural"):
			_process_procedural_script(category, full_path)
		
		file_name = dir.get_next()

func _process_procedural_script(category: String, script_path: String) -> void:
	var script = load(script_path)
	if not script:
		return
	
	var instance = script.new()
	if not instance:
		return
	
	if not _is_valid_procedural_item(instance, category):
		if instance.has_method("queue_free"):
			instance.queue_free()
		return
	
	var item_id = instance.item_id if instance.has_method("get") and instance.item_id != "" else _generate_id_from_path(script_path)
	
	procedural_items[item_id] = {
		"instance": instance,
		"category": category,
		"script_path": script_path,
		"class_name": instance.get_script().get_global_name()
	}
	
	registered_count += 1

func _register_with_managers() -> void:
	for item_id in procedural_items:
		var item_data = procedural_items[item_id]
		var instance = item_data.instance
		var category = item_data.category
		
		var item_resource: UnifiedItemData
		
		if instance.has_method("create_item_data"):
			item_resource = instance.create_item_data()
		else:
			item_resource = UnifiedItemData.new()
			item_resource.id = instance.get("item_id") if instance.get("item_id") else item_id
			item_resource.display_name = instance.get("display_name") if instance.get("display_name") else ""
			item_resource.description = instance.get("description") if instance.get("description") else ""
			item_resource.category = _category_string_to_enum(category)
			item_resource.rarity = instance.get("item_rarity") if instance.get("item_rarity") else UnifiedItemData.Rarity.COMMON
			item_resource.is_procedural = true
			item_resource.is_animated = instance.get("is_animated") if instance.get("is_animated") else false
			item_resource.procedural_script_path = item_data.script_path
		
		if ItemManager and item_resource:
			ItemManager.register_item(item_resource)

# === PUBLIC INTERFACE ===

func get_procedural_item(item_id: String):
	"""Get procedural item instance by ID"""
	return procedural_items.get(item_id, {}).get("instance", null)

func get_items_by_category(category: String) -> Array:
	"""Get all items in a category"""
	var items = []
	for item_data in procedural_items.values():
		if item_data.category == category:
			items.append(item_data.instance)
	return items

# === EXPORT FUNCTIONS (KEEP ALL) ===

func export_all_to_png() -> void:
	"""Export all procedural items as PNG files"""
	var exported_count = 0
	var failed_exports = []
	
	for item_id in procedural_items:
		var item_data = procedural_items[item_id]
		var instance = item_data.instance
		
		if instance.has_method("export_to_png"):
			var success = await instance.export_to_png()
			
			if success:
				exported_count += 1
			else:
				failed_exports.append(item_id)
	
	print("Exported %d/%d procedural items to PNG" % [exported_count, procedural_items.size()])
	if failed_exports.size() > 0:
		push_warning("Failed exports: %s" % failed_exports)

func generate_tres_files_for_all() -> void:
	"""Generate .tres files for all procedural items"""
	var generated_count = 0
	var failed = []
	
	for item_id in procedural_items:
		var item_data = procedural_items[item_id]
		var instance = item_data.instance
		
		if instance.has_method("create_item_data"):
			var unified_data = instance.create_item_data()
			
			var category_folder = _get_category_folder_name(item_data.category)
			var icon_path = "res://Pyramids/assets/icons/%s/%s.png" % [category_folder, item_id]
			
			unified_data.icon_path = icon_path
			unified_data.texture_path = icon_path
			unified_data.preview_texture_path = icon_path
			unified_data.procedural_script_path = item_data.script_path
			
			var save_path = "res://Pyramids/resources/items/%s/%s.tres" % [category_folder, item_id]
			
			var dir_path = save_path.get_base_dir()
			if not DirAccess.dir_exists_absolute(dir_path):
				DirAccess.make_dir_recursive_absolute(dir_path)
			
			var result = ResourceSaver.save(unified_data, save_path)
			
			if result == OK:
				generated_count += 1
			else:
				failed.append(item_id)
	
	print("Generated %d/%d .tres files" % [generated_count, procedural_items.size()])
	if failed.size() > 0:
		push_warning("Failed generations: %s" % failed)

# === PRIVATE HELPERS ===

func _is_valid_procedural_item(instance, category: String) -> bool:
	match category:
		"card_fronts":
			return instance is ProceduralCardFront or instance.has_method("draw_card_front")
		"card_backs":
			return instance is ProceduralCardBack or instance.has_method("draw_card_back")
		"boards":
			return instance is ProceduralBoard or instance.has_method("draw_board_background")
		"frames":
			return instance.has_method("draw_frame")
		"avatars":
			return instance.has_method("draw_avatar")
		_:
			return instance.has_method("create_item_data")

func _generate_id_from_path(script_path: String) -> String:
	var file_name = script_path.get_file().get_basename()
	return file_name.to_snake_case()

func _get_category_folder_name(category: String) -> String:
	match category:
		"card_fronts": return "card_fronts"
		"card_backs": return "card_backs"
		"boards": return "boards"
		"frames": return "frames"
		"avatars": return "avatars"
		"emojis": return "emojis"
		_: return category

func _category_string_to_enum(category: String) -> UnifiedItemData.Category:
	match category:
		"card_fronts": return UnifiedItemData.Category.CARD_FRONT
		"card_backs": return UnifiedItemData.Category.CARD_BACK
		"boards": return UnifiedItemData.Category.BOARD
		"frames": return UnifiedItemData.Category.FRAME
		"avatars": return UnifiedItemData.Category.AVATAR
		"emojis": return UnifiedItemData.Category.EMOJI
		_: return UnifiedItemData.Category.CARD_FRONT

# === DEBUG (KEEP BUT SIMPLIFIED) ===

func debug_print_registry() -> void:
	"""Print registry contents for debugging"""
	print("\n=== PROCEDURAL ITEM REGISTRY ===")
	print("Total items: %d" % procedural_items.size())
	
	for category in CATEGORIES:
		var category_items = procedural_items.values().filter(func(item): return item.category == category)
		if category_items.size() > 0:
			print("%s: %d items" % [category, category_items.size()])
	print("================================\n")
