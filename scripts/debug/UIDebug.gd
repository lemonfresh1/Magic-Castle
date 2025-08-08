# UIDebug.gd - Debug utility for inspecting UI nodes
# Location: res://Magic-Castle/scripts/debug/UIDebug.gd
# Last Updated: Fixed string operations for Godot 4 [Date]

class_name UIDebug
extends RefCounted

static func inspect_scene(root_node: Node, report_name: String = "Scene") -> void:
	"""Call this from any scene's _ready() to get a full debug report"""
	print("\n" + _repeat_string("=", 80))
	print("UI DEBUG REPORT: %s - %s" % [report_name, Time.get_time_string_from_system()])
	print(_repeat_string("=", 80))
	
	# Full node tree with details
	print("\n[FULL NODE TREE]")
	_recursive_debug_node(root_node, 0)
	
	# Summary of suspicious nodes
	print("\n" + _repeat_string("=", 40))
	print("[SUSPICIOUS NODES SUMMARY]")
	print(_repeat_string("=", 40))
	_find_visible_overlays(root_node)
	
	# Quick stats
	var stats = _collect_stats(root_node)
	print("\n" + _repeat_string("=", 40))
	print("[SCENE STATISTICS]")
	print(_repeat_string("=", 40))
	print("Total nodes: %d" % stats.total_nodes)
	print("Control nodes: %d" % stats.control_nodes)
	print("Visible controls: %d" % stats.visible_controls)
	print("Panels/PanelContainers: %d" % stats.panel_nodes)
	print("Nodes with high z-index (>10): %d" % stats.high_z_nodes)
	
	print("\n" + _repeat_string("=", 80) + "\n")

static func _repeat_string(text: String, count: int) -> String:
	"""Helper to repeat a string n times"""
	var result = ""
	for i in range(count):
		result += text
	return result

static func _get_indent(level: int) -> String:
	"""Get indentation string for given level"""
	var indent = ""
	for i in range(level):
		indent += "  "
	return indent

static func _recursive_debug_node(node: Node, indent: int) -> void:
	var indent_str = _get_indent(indent)
	var node_info = "%s[%s] %s" % [indent_str, node.get_class(), node.name]
	
	# For Control nodes, add detailed information
	if node is Control:
		var control = node as Control
		
		# Basic visibility and position
		node_info += "\n%s  📍 Pos: %s | Size: %s | Visible: %s | Alpha: %.2f" % [
			indent_str,
			control.global_position if control.is_inside_tree() else control.position,
			control.size,
			control.visible,
			control.modulate.a * control.self_modulate.a
		]
		
		# Z-index and mouse filter
		node_info += "\n%s  🔢 Z: %d | Mouse: %s" % [
			indent_str,
			control.z_index,
			_get_mouse_filter_name(control.mouse_filter)
		]
		
		# Colors and styles
		if node is PanelContainer or node is Panel:
			var panel_style = node.get_theme_stylebox("panel") if node.has_theme_stylebox("panel") else null
			if panel_style and panel_style is StyleBoxFlat:
				var style = panel_style as StyleBoxFlat
				node_info += "\n%s  🎨 BG: %s (a:%.2f) | Border: %s (w:%d)" % [
					indent_str,
					_color_to_string(style.bg_color),
					style.bg_color.a,
					_color_to_string(style.border_color),
					style.get_border_width(SIDE_TOP)
				]
		
		if node is ColorRect:
			node_info += "\n%s  🎨 Color: %s (a:%.2f)" % [
				indent_str,
				_color_to_string(node.color),
				node.color.a
			]
		
		# Modulation
		if control.modulate != Color.WHITE or control.self_modulate != Color.WHITE:
			node_info += "\n%s  🎨 Modulate: %s | Self: %s" % [
				indent_str,
				_color_to_string(control.modulate),
				_color_to_string(control.self_modulate)
			]
		
		# Container specific info
		if node is VBoxContainer or node is HBoxContainer:
			var container = node
			if container.has_theme_stylebox("panel"):
				var panel_style = container.get_theme_stylebox("panel")
				if panel_style:
					node_info += "\n%s  ⚠️ CONTAINER HAS PANEL STYLE!" % indent_str
		
		# Check for any theme overrides
		var overrides = _get_theme_overrides(node)
		if overrides.size() > 0:
			node_info += "\n%s  🎨 Theme Overrides: %s" % [indent_str, overrides]
	
	print(node_info)
	
	# Recurse through children
	for child in node.get_children():
		_recursive_debug_node(child, indent + 1)

static func _find_visible_overlays(node: Node) -> void:
	"""Find nodes that could be causing overlay issues"""
	var suspicious_nodes = []
	_collect_suspicious_nodes(node, suspicious_nodes)
	
	if suspicious_nodes.size() > 0:
		print("⚠️ Found %d potentially problematic nodes:" % suspicious_nodes.size())
		for info in suspicious_nodes:
			print("  • [%s] %s" % [info.class, info.name])
			print("    Path: %s" % info.path)
			print("    Reason: %s" % info.reason)
			print("    Position: %s, Size: %s" % [info.position, info.size])
	else:
		print("✅ No obviously suspicious nodes found")

static func _collect_suspicious_nodes(node: Node, suspicious_list: Array) -> void:
	if node is Control:
		var control = node as Control
		var is_suspicious = false
		var reason = ""
		
		# Check for gray panels
		if node is Panel or node is PanelContainer:
			var panel_style = node.get_theme_stylebox("panel") if node.has_theme_stylebox("panel") else null
			if panel_style and panel_style is StyleBoxFlat:
				var style = panel_style as StyleBoxFlat
				if _is_grayish(style.bg_color) and style.bg_color.a > 0.5 and control.visible:
					is_suspicious = true
					reason = "Gray panel with alpha %.2f, color: %s" % [style.bg_color.a, _color_to_string(style.bg_color)]
		
		# Check for gray ColorRects
		if node is ColorRect:
			if _is_grayish(node.color) and node.color.a > 0.5 and control.visible:
				is_suspicious = true
				reason = "Gray ColorRect with alpha %.2f, color: %s" % [node.color.a, _color_to_string(node.color)]
		
		# Check for VBoxContainer/HBoxContainer with styles (unusual)
		if (node is VBoxContainer or node is HBoxContainer) and node.has_theme_stylebox("panel"):
			is_suspicious = true
			reason = "Container with panel style (unusual!)"
		
		# Check for high z-index overlays
		if control.z_index > 10 and control.visible and control.modulate.a > 0:
			is_suspicious = true
			if reason != "":
				reason += " + "
			reason += "High z-index: %d" % control.z_index
		
		# Check for large semi-transparent overlays
		if control.size.x > 400 and control.size.y > 200 and control.visible:
			if control.self_modulate.a > 0.3 and control.self_modulate.a < 1.0:
				if not is_suspicious:
					is_suspicious = true
					reason = "Large semi-transparent overlay (%.2f alpha)" % control.self_modulate.a
		
		if is_suspicious:
			suspicious_list.append({
				"path": node.get_path(),
				"name": node.name,
				"class": node.get_class(),
				"reason": reason,
				"position": control.global_position if control.is_inside_tree() else control.position,
				"size": control.size
			})
	
	# Recurse
	for child in node.get_children():
		_collect_suspicious_nodes(child, suspicious_list)

static func _collect_stats(node: Node) -> Dictionary:
	"""Collect statistics about the scene"""
	var stats = {
		"total_nodes": 0,
		"control_nodes": 0,
		"visible_controls": 0,
		"panel_nodes": 0,
		"high_z_nodes": 0
	}
	_count_nodes(node, stats)
	return stats

static func _count_nodes(node: Node, stats: Dictionary) -> void:
	stats.total_nodes += 1
	
	if node is Control:
		stats.control_nodes += 1
		var control = node as Control
		if control.visible:
			stats.visible_controls += 1
		if control.z_index > 10:
			stats.high_z_nodes += 1
	
	if node is Panel or node is PanelContainer:
		stats.panel_nodes += 1
	
	for child in node.get_children():
		_count_nodes(child, stats)

static func _is_grayish(color: Color) -> bool:
	"""Check if a color is grayish"""
	var r = color.r
	var g = color.g
	var b = color.b
	
	# Check if RGB values are similar (gray)
	var max_diff = max(abs(r - g), max(abs(g - b), abs(r - b)))
	if max_diff < 0.15:  # Close enough to be gray
		# Check if it's in the gray range (not too dark, not too light)
		var avg = (r + g + b) / 3.0
		return avg > 0.3 and avg < 0.8
	return false

static func _color_to_string(color: Color) -> String:
	"""Convert color to readable string"""
	if color == Color.WHITE:
		return "WHITE"
	elif color == Color.BLACK:
		return "BLACK"
	elif color == Color.TRANSPARENT:
		return "TRANSPARENT"
	elif _is_grayish(color):
		return "GRAY(%.2f,%.2f,%.2f)" % [color.r, color.g, color.b]
	else:
		return "#%02X%02X%02X" % [int(color.r * 255), int(color.g * 255), int(color.b * 255)]

static func _get_mouse_filter_name(filter: int) -> String:
	"""Get readable name for mouse filter"""
	match filter:
		Control.MOUSE_FILTER_STOP:
			return "STOP"
		Control.MOUSE_FILTER_PASS:
			return "PASS"
		Control.MOUSE_FILTER_IGNORE:
			return "IGNORE"
		_:
			return "UNKNOWN"

static func _get_theme_overrides(node: Control) -> Array:
	"""Get list of theme overrides on a node"""
	var overrides = []
	
	# Check for common overrides
	var override_types = ["stylebox", "font", "font_size", "color", "constant", "icon"]
	for type in override_types:
		var method_name = "get_theme_%s_override_list" % type
		if node.has_method(method_name):
			var override_list = node.call(method_name)
			if override_list and override_list.size() > 0:
				for override_name in override_list:
					overrides.append("%s:%s" % [type, override_name])
	
	return overrides

# Quick helper functions for common debugging needs
static func find_gray_panels(root: Node) -> Array:
	"""Quick function to find all gray panels in scene"""
	var gray_panels = []
	_find_gray_panels_recursive(root, gray_panels)
	return gray_panels

static func _find_gray_panels_recursive(node: Node, list: Array) -> void:
	if node is Panel or node is PanelContainer:
		var panel_style = node.get_theme_stylebox("panel") if node.has_theme_stylebox("panel") else null
		if panel_style and panel_style is StyleBoxFlat:
			var style = panel_style as StyleBoxFlat
			if _is_grayish(style.bg_color) and style.bg_color.a > 0.1:
				list.append({
					"node": node,
					"path": node.get_path(),
					"color": style.bg_color,
					"visible": node.visible if node is Control else true
				})
	
	for child in node.get_children():
		_find_gray_panels_recursive(child, list)
