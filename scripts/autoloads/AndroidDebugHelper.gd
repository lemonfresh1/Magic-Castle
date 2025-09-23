# AndroidDebugHelper.gd - Comprehensive Android debugging helper
# Location: res://Pyramids/scripts/autoloads/AndroidDebugHelper.gd
# Add as autoload: Project Settings → Autoload → Add this script

extends Node

signal debug_info_collected(info: Dictionary)

var debug_info: Dictionary = {}
# Master debug switch
const DEBUG_ENABLED = false  # Toggle this

func _ready():
	if not DEBUG_ENABLED:
		return  # Skip all debug initialization

	print("=== ANDROID DEBUG HELPER STARTED ===")
	collect_system_info()
	check_common_issues()
	
	# Debug specific issues
	await get_tree().process_frame
	#debug_item_manager()
	#debug_procedural_items()
	#debug_emoji_loading()  # Add emoji debug
	debug_game_mode_manager()
	
	# Hook into scene changes
	get_tree().node_added.connect(_on_node_added)
	
	# Print debug info every 5 seconds if in debug mode
	if OS.is_debug_build():
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.timeout.connect(print_performance_stats)
		add_child(timer)
		timer.start()

func _on_node_added(node: Node):
	"""Hook into specific scenes for debugging"""
	if node.name == "SinglePlayerModeSelect":
		print("\n=== SINGLEPLAYER MODE SELECT LOADING ===")
		debug_scene_change("SinglePlayerModeSelect")
		# Add specific debugging for this scene
		call_deferred("_debug_single_player_scene", node)

func collect_system_info():
	"""Collect system information for debugging"""
	debug_info["os_name"] = OS.get_name()
	debug_info["os_version"] = OS.get_version()
	debug_info["processor_count"] = OS.get_processor_count()
	debug_info["executable_path"] = OS.get_executable_path()
	debug_info["user_data_dir"] = OS.get_user_data_dir()
	debug_info["granted_permissions"] = OS.get_granted_permissions()
	
	print("=== SYSTEM INFO ===")
	for key in debug_info:
		print("%s: %s" % [key, debug_info[key]])
	print("==================")

func check_common_issues():
	"""Check for common Android issues"""
	var issues = []
	
	# Check 1: res:// write attempts (YOUR ISSUE!)
	if not _check_writable_paths():
		issues.append("Attempting to write to res:// - use user:// instead")
	
	# Check 2: Case sensitivity
	if not _check_case_sensitivity():
		issues.append("Potential case sensitivity issues in file paths")
	
	# Check 3: Missing resources
	var missing = _check_missing_resources()
	if missing.size() > 0:
		issues.append("Missing resources: " + str(missing))
	
	# Check 4: Memory usage
	var memory_mb = OS.get_static_memory_usage() / 1048576.0
	if memory_mb > 512:
		issues.append("High memory usage: %.2f MB" % memory_mb)
	
	if issues.size() > 0:
		print("=== ISSUES DETECTED ===")
		for issue in issues:
			push_warning(issue)
			print("⚠️ " + issue)
		print("======================")
	else:
		print("✅ No common issues detected")

func _check_writable_paths() -> bool:
	"""Test if code is trying to write to res://"""
	var test_path = "res://test_write.txt"
	var file = FileAccess.open(test_path, FileAccess.WRITE)
	if file:
		file.close()
		DirAccess.remove_absolute(test_path)
		push_warning("res:// is writable - this will fail on Android!")
		return false
	return true

func _check_case_sensitivity() -> bool:
	"""Check for potential case sensitivity issues"""
	# This is where you'd check your resource paths
	# For now, just return true
	return true

func _check_missing_resources() -> Array:
	"""Check for missing critical resources"""
	var missing = []
	var critical_paths = [
		"res://Pyramids/assets/ui/menu/play.png",
		"res://Pyramids/scenes/ui/components/ButtonLayout.tscn",
		# Add your critical resources here
	]
	
	for path in critical_paths:
		if not ResourceLoader.exists(path):
			missing.append(path)
	
	return missing

func print_performance_stats():
	"""Print performance statistics"""
	var stats = {
		"FPS": Engine.get_frames_per_second(),
		"Memory (MB)": "%.2f" % (OS.get_static_memory_usage() / 1048576.0),
		"Process Time": "%.2f ms" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000),
		"Physics Time": "%.2f ms" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000),
		"Object Count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"Node Count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	}
	
	print("=== PERFORMANCE ===")
	for key in stats:
		print("%s: %s" % [key, stats[key]])

func safe_load_resource(path: String, fallback = null):
	"""Safely load a resource with fallback"""
	if not path.begins_with("res://"):
		push_error("Invalid resource path: " + path)
		return fallback
	
	if not ResourceLoader.exists(path):
		push_warning("Resource not found: " + path)
		return fallback
	
	var resource = load(path)
	if not resource:
		push_error("Failed to load resource: " + path)
		return fallback
	
	return resource

func safe_file_write(content: String, filename: String) -> bool:
	"""Safely write file to user:// directory"""
	var path = "user://" + filename
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Cannot write to: " + path)
		return false
	
	file.store_string(content)
	file.close()
	print("Successfully wrote to: " + path)
	return true

func log_crash_info(error_msg: String):
	"""Log crash information for debugging"""
	var crash_info = {
		"timestamp": Time.get_datetime_string_from_system(),
		"error": error_msg,
		"scene": get_tree().current_scene.name if get_tree().current_scene else "Unknown",
		"memory_mb": OS.get_static_memory_usage() / 1048576.0,
		"fps": Engine.get_frames_per_second()
	}
	
	var json = JSON.new()
	json.stringify(crash_info)
	safe_file_write(json.stringify(crash_info), "crash_log.json")
	
	print("=== CRASH INFO SAVED ===")
	print(crash_info)

func debug_item_manager():
	"""Debug ItemManager and inventory issues"""
	print("\n=== ITEMMANAGER DEBUG ===")
	
	if not ItemManager:
		print("❌ ItemManager is NULL!")
		return
	
	print("✓ ItemManager exists")
	print("  Total items: %d" % ItemManager.all_items.size())
	print("  Procedural instances: %d" % ItemManager.procedural_instances.size())
	
	# Count by category
	var categories = ["card_fronts", "card_backs", "boards", "frames", "avatars", "emojis"]
	for category in categories:
		var items = ItemManager.get_items_by_category(category)
		print("  %s: %d items" % [category, items.size()])
		
		# Show first 2 items in each category
		var count = 0
		for item in items:
			if count < 2:
				print("    - %s (procedural: %s)" % [item.id, item.is_procedural])
				count += 1
	
	# Check for common items
	var test_items = ["card_classic", "board_green"]
	for item_id in test_items:
		var item = ItemManager.get_item(item_id)
		if item:
			print("  ✓ Found: %s" % item_id)
		else:
			print("  ❌ Missing: %s" % item_id)

func debug_emoji_loading():
	print("\n=== EMOJI LOADING DEBUG ===")
	
	# Check PNG directory - show ALL files
	var png_path = "res://Pyramids/assets/icons/emojis/"
	print("Checking PNG path: %s" % png_path)
	if DirAccess.dir_exists_absolute(png_path):
		var dir = DirAccess.open(png_path)
		dir.list_dir_begin()
		var file = dir.get_next()
		var all_files = []
		while file != "":
			all_files.append(file)
			print("  Found file: %s" % file)  # Show EVERY file
			file = dir.get_next()
		print("  Total files in directory: %d" % all_files.size())
		if all_files.size() == 0:
			print("  ❌ Directory exists but is EMPTY!")
	
	# Check TRES directory - show ALL files
	var tres_path = "res://Pyramids/resources/items/emojis/"
	print("\nChecking TRES path: %s" % tres_path)
	if DirAccess.dir_exists_absolute(tres_path):
		var dir = DirAccess.open(tres_path)
		dir.list_dir_begin()
		var file = dir.get_next()
		var all_files = []
		while file != "":
			all_files.append(file)
			print("  Found file: %s" % file)  # Show EVERY file
			file = dir.get_next()
		print("  Total files in directory: %d" % all_files.size())
		if all_files.size() == 0:
			print("  ❌ Directory exists but is EMPTY!")

func debug_procedural_items():
	"""Debug why procedural items might not be loading"""
	print("\n=== PROCEDURAL ITEMS DEBUG ===")
	
	var paths_to_check = [
		"res://Pyramids/scripts/items/card_fronts/procedural/",
		"res://Pyramids/scripts/items/card_backs/procedural/",
		"res://Pyramids/scripts/items/boards/procedural/"
	]
	
	for path in paths_to_check:
		print("\nChecking: %s" % path)
		
		if not DirAccess.dir_exists_absolute(path):
			print("  ❌ Directory doesn't exist on device!")
			continue
		
		var dir = DirAccess.open(path)
		if not dir:
			print("  ❌ Cannot open directory!")
			continue
		
		print("  ✓ Directory accessible")
		
		# Count scripts
		dir.list_dir_begin()
		var script_count = 0
		var loaded_count = 0
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".gd"):
				script_count += 1
				var full_path = path + file_name
				
				# Try to load
				if ResourceLoader.exists(full_path):
					var script = load(full_path)
					if script:
						loaded_count += 1
						print("    ✓ %s" % file_name)
					else:
						print("    ❌ Failed to load: %s" % file_name)
				else:
					print("    ❌ Not in resources: %s" % file_name)
			
			file_name = dir.get_next()
		
		print("  Scripts: %d found, %d loaded" % [script_count, loaded_count])
	
	# Check if ProceduralItemRegistry exists
	if has_node("/root/ProceduralItemRegistry"):
		print("\n✓ ProceduralItemRegistry exists as autoload")
		var registry = get_node("/root/ProceduralItemRegistry")
		if "procedural_items" in registry:
			print("  Registered items: %d" % registry.procedural_items.size())
	else:
		print("\n❌ ProceduralItemRegistry not found in autoloads!")

func debug_game_mode_manager():
	"""Debug GameModeManager for SinglePlayerModeSelect crash"""
	print("\n=== GAMEMODE MANAGER DEBUG ===")
	
	if not has_node("/root/GameModeManager"):
		print("❌ GameModeManager not in autoloads!")
		return
	
	var gmm = get_node("/root/GameModeManager")
	print("✓ GameModeManager exists")
	
	if not "available_modes" in gmm:
		print("  ❌ No 'available_modes' property!")
		return
	
	var modes = gmm.available_modes
	print("  Available modes: %d" % modes.size())
	
	for mode_id in modes:
		var config = modes[mode_id]
		print("    - %s: %s" % [mode_id, config.get("display_name", "???")])

func debug_scene_change(to_scene: String):
	"""Call this before changing scenes to debug crashes"""
	print("\n=== SCENE CHANGE DEBUG ===")
	print("Changing to: %s" % to_scene)
	print("Current scene: %s" % get_tree().current_scene.name)
	print("Memory before: %.2f MB" % (OS.get_static_memory_usage() / 1048576.0))
	
	# Check critical autoloads
	var autoloads = ["GameModeManager", "ItemManager", "UIStyleManager", "StatsManager"]
	for autoload in autoloads:
		if has_node("/root/" + autoload):
			print("  ✓ %s" % autoload)
		else:
			print("  ❌ %s missing!" % autoload)

func _debug_single_player_scene(scene_node: Node):
	"""Debug SinglePlayerModeSelect specifically"""
	print("Debugging SinglePlayerModeSelect scene...")
	
	# Check for required child nodes
	var required_nodes = ["TopSection", "BottomSection", "TopSection/BackButton", "BottomSection/CardContainer"]
	for node_path in required_nodes:
		if scene_node.has_node(node_path):
			print("  ✓ Found: %s" % node_path)
		else:
			print("  ❌ Missing: %s" % node_path)
	
	# Check if HighscoresPanel scene exists
	if ResourceLoader.exists("res://Pyramids/scenes/ui/components/HighscoresPanel.tscn"):
		print("  ✓ HighscoresPanel.tscn exists")
	else:
		print("  ❌ HighscoresPanel.tscn not found!")
	
	# Monitor finalize function
	if scene_node.has_method("_finalize_carousel_setup"):
		print("  ✓ Has _finalize_carousel_setup method")
		
		# Try to detect when it's called
		await get_tree().process_frame
		await get_tree().process_frame  # Give it 2 frames
		print("  Carousel should be finalized by now")
