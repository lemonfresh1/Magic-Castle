# AndroidDebugHelper.gd - Comprehensive Android debugging helper
# Location: res://Pyramids/scripts/autoloads/AndroidDebugHelper.gd
# Add as autoload: Project Settings → Autoload → Add this script

extends Node

signal debug_info_collected(info: Dictionary)

var debug_info: Dictionary = {}

func _ready():
	print("=== ANDROID DEBUG HELPER STARTED ===")
	collect_system_info()
	check_common_issues()
	
	# Print debug info every 5 seconds if in debug mode
	if OS.is_debug_build():
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.timeout.connect(print_performance_stats)
		add_child(timer)
		timer.start()

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
