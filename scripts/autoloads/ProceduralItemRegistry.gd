# ProceduralItemRegistry.gd - Auto-discovers and registers all procedural items
# Location: res://Pyramids/scripts/autoloads/ProceduralItemRegistry.gd
# Last Updated: Created procedural item auto-discovery system [Date]

extends Node

# Registry of all discovered procedural items
var procedural_items: Dictionary = {}
var registered_count: int = 0

# Categories to scan
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

func _ready():
	print("ProceduralItemRegistry initializing...")

# Main discovery function
func discover_and_register_all() -> void:
	print("=== PROCEDURAL ITEM DISCOVERY ===")
	procedural_items.clear()
	registered_count = 0
	
	for category in CATEGORIES:
		var category_path = BASE_PATH + category + "/procedural/"
		_scan_category(category, category_path)
	
	print("=== DISCOVERY COMPLETE ===")
	print("Total procedural items found: %d" % registered_count)
	
	# Register with appropriate managers
	_register_with_managers()

func _scan_category(category: String, path: String) -> void:
	print("Scanning category: %s at %s" % [category, path])
	
	if not DirAccess.dir_exists_absolute(path):
		print("  - Directory not found, skipping")
		return
	
	# Scan all subdirectories (epic, rare, common, etc.)
	var dir = DirAccess.open(path)
	if not dir:
		print("  - Could not open directory")
		return
	
	_scan_directory_recursive(category, path, dir)

func _scan_directory_recursive(category: String, current_path: String, dir: DirAccess) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = current_path + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively scan subdirectories
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_scan_directory_recursive(category, full_path + "/", sub_dir)
		elif file_name.ends_with(".gd") and not file_name.begins_with("Procedural"):
			# Found a procedural item script
			_process_procedural_script(category, full_path)
		
		file_name = dir.get_next()

func _process_procedural_script(category: String, script_path: String) -> void:
	print("  - Found script: %s" % script_path)
	
	# Load the script
	var script = load(script_path)
	if not script:
		print("    ✗ Could not load script")
		return
	
	# Try to instantiate it
	var instance = script.new()
	if not instance:
		print("    ✗ Could not instantiate")
		return
	
	# Check if it's a valid procedural item
	if not _is_valid_procedural_item(instance, category):
		print("    ✗ Invalid procedural item")
		instance.queue_free() if instance.has_method("queue_free") else null
		return
	
	# Store in registry
	var item_id = instance.item_id if instance.has_method("get") and instance.item_id != "" else _generate_id_from_path(script_path)
	
	procedural_items[item_id] = {
		"instance": instance,
		"category": category,
		"script_path": script_path,
		"class_name": instance.get_script().get_global_name()
	}
	
	registered_count += 1
	print("    ✓ Registered: %s (id: %s)" % [instance.display_name, item_id])

func _is_valid_procedural_item(instance, category: String) -> bool:
	# Check if it's the right base class for the category
	match category:
		"card_fronts", "card_backs":
			return instance is ProceduralCardBack or instance.has_method("draw_card_back")
		"boards":
			return instance.has_method("draw_board_background")
		"frames":
			return instance.has_method("draw_frame")
		"avatars":
			return instance.has_method("draw_avatar")
		_:
			return instance.has_method("create_item_data")

func _generate_id_from_path(script_path: String) -> String:
	# Generate ID from file path: "epic/ClassicPyramidsGold.gd" -> "classic_pyramids_gold"
	var file_name = script_path.get_file().get_basename()
	return file_name.to_snake_case()

func _register_with_managers() -> void:
	print("Registering with managers...")
	
	for item_id in procedural_items:
		var item_data = procedural_items[item_id]
		var instance = item_data.instance
		var category = item_data.category
		
		# Create ItemData resource
		if instance.has_method("create_item_data"):
			var item_resource = instance.create_item_data()
			
			# Register with ItemManager
			if ItemManager and item_resource:
				ItemManager.all_items[item_id] = item_resource
				print("  ✓ Registered %s with ItemManager" % item_id)
		
		# Register card skins with CardSkinManager
		if category in ["card_fronts", "card_backs"] and CardSkinManager:
			if not CardSkinManager.available_skins.has(item_id):
				CardSkinManager.available_skins[item_id] = instance
				print("  ✓ Registered %s with CardSkinManager" % item_id)

# Export all procedural items as PNGs
# Export all procedural items as PNGs with organized structure
func export_all_to_png() -> void:
	print("=== EXPORTING ALL PROCEDURAL ITEMS ===")
	
	var exported_count = 0
	var failed_exports = []
	
	for item_id in procedural_items:
		var item_data = procedural_items[item_id]
		var instance = item_data.instance
		var category = item_data.category
		
		if instance.has_method("export_to_png"):
			print("Exporting: %s (%s)" % [instance.display_name, category])
			var success = await instance.export_to_png()  # Uses smart auto-path
			
			if success:
				exported_count += 1
				print("  ✓ Success")
			else:
				failed_exports.append(item_id)
				print("  ✗ Failed")
	
	print("=== EXPORT COMPLETE ===")
	print("Successfully exported: %d items" % exported_count)
	if failed_exports.size() > 0:
		print("Failed exports: %s" % failed_exports)

# Debug functions
func debug_print_registry() -> void:
	print("\n=== PROCEDURAL ITEM REGISTRY ===")
	print("Total items: %d" % procedural_items.size())
	
	for category in CATEGORIES:
		var category_items = procedural_items.values().filter(func(item): return item.category == category)
		if category_items.size() > 0:
			print("\n%s (%d items):" % [category.capitalize(), category_items.size()])
			for item in category_items:
				print("  - %s (%s)" % [item.instance.display_name, item.instance.item_id])
	print("================================\n")

# Get procedural item by ID
func get_procedural_item(item_id: String):
	return procedural_items.get(item_id, {}).get("instance", null)

# Get all items by category
func get_items_by_category(category: String) -> Array:
	var items = []
	for item_data in procedural_items.values():
		if item_data.category == category:
			items.append(item_data.instance)
	return items
