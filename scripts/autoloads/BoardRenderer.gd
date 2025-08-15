
# BoardRenderer.gd - Autoload for managing board visual rendering
# Path: res://Pyramids/scripts/autoloads/BoardRenderer.gd
# Last Updated: Initial creation - handles all board visual rendering
#
# BoardRenderer handles:
# - Board background rendering (color, texture, procedural, animated, scene)
# - Equipment integration for board skins
# - Animation lifecycle management
# - Resource caching for performance
# - Background type detection and routing
# - Fallback rendering for missing assets
#
# Flow: Equipment/Settings → BoardRenderer → Background creation → Parent node display
# Dependencies: EquipmentManager (equipped board), ItemManager (board definitions), UIStyleManager (fallbacks)

extends Node

# === RENDERING TYPES ===
enum BackgroundType {
	COLOR,           # Simple color background
	TEXTURE,         # Static texture
	PROCEDURAL,      # Procedurally drawn
	ANIMATED,        # Animated procedural
	SCENE            # Full scene-based background
}

# === STATE ===
var current_background_type: BackgroundType = BackgroundType.COLOR
var current_background_id: String = "board_green"
var background_node: Node = null
var parent_node: Control = null
var active_animations: Array[Tween] = []

# === CACHE ===
var cached_procedural_instances: Dictionary = {}
var cached_textures: Dictionary = {}
var cached_scenes: Dictionary = {}

# === SIGNALS ===
signal background_changed(new_id: String)
signal animation_started(background_id: String)
signal animation_stopped(background_id: String)

func _ready() -> void:
	print("BoardRenderer initialized")
	
	# Connect to signals
	SignalBus.board_skin_changed.connect(_on_board_skin_changed)
	
	# Preload common backgrounds
	_preload_common_backgrounds()

func _preload_common_backgrounds() -> void:
	"""Preload commonly used backgrounds for faster switching"""
	# Preload default textures if they exist
	var common_boards = ["board_green", "board_blue", "board_sunset"]
	for board_id in common_boards:
		if ItemManager:
			var item = ItemManager.get_item(board_id)
			if item and item.texture_path:
				_cache_texture(board_id, item.texture_path)

# === PUBLIC API ===

func set_parent(parent: Control) -> void:
	"""Set the parent node where backgrounds will be rendered"""
	parent_node = parent
	print("BoardRenderer parent set to: %s" % parent.name)

func apply_background(background_id: String = "") -> void:
	"""Apply a background by ID or use equipped"""
	# Clear existing background
	_clear_current_background()
	
	# Determine what background to use
	if background_id == "":
		background_id = _get_equipped_background()
	
	current_background_id = background_id
	
	# Get item data
	var item = _get_background_item(background_id)
	if not item:
		_apply_fallback_background()
		return
	
	# Determine type and apply
	var bg_type = _determine_background_type(item)
	current_background_type = bg_type
	
	match bg_type:
		BackgroundType.SCENE:
			_apply_scene_background(item)
		BackgroundType.ANIMATED:
			_apply_animated_background(item)
		BackgroundType.PROCEDURAL:
			_apply_procedural_background(item)
		BackgroundType.TEXTURE:
			_apply_texture_background(item)
		BackgroundType.COLOR:
			_apply_color_background(item)
	
	# Emit signal
	background_changed.emit(current_background_id)

func clear_background() -> void:
	"""Remove current background"""
	_clear_current_background()

func pause_animations() -> void:
	"""Pause all active background animations"""
	for tween in active_animations:
		if tween and tween.is_valid():
			tween.pause()

func resume_animations() -> void:
	"""Resume all paused background animations"""
	for tween in active_animations:
		if tween and tween.is_valid():
			tween.play()

func get_current_background() -> String:
	"""Get the ID of the current background"""
	return current_background_id

func get_background_type() -> BackgroundType:
	"""Get the type of the current background"""
	return current_background_type

# === BACKGROUND DETERMINATION ===

func _get_equipped_background() -> String:
	"""Get the currently equipped background ID"""
	if EquipmentManager:
		var equipped = EquipmentManager.get_equipped_items()
		return equipped.get("board", "board_green")
	return "board_green"

func _get_background_item(background_id: String) -> UnifiedItemData:
	"""Get item data for a background ID"""
	if ItemManager:
		return ItemManager.get_item(background_id)
	return null

func _determine_background_type(item: UnifiedItemData) -> BackgroundType:
	"""Determine the type of background from item data"""
	# Priority order: Scene > Animated > Procedural > Texture > Color
	
	if item.background_scene_path and item.background_scene_path != "":
		if ResourceLoader.exists(item.background_scene_path):
			return BackgroundType.SCENE
	
	if item.is_procedural and item.is_animated:
		return BackgroundType.ANIMATED
	
	if item.is_procedural:
		return BackgroundType.PROCEDURAL
	
	if item.texture_path and item.texture_path != "":
		if ResourceLoader.exists(item.texture_path):
			return BackgroundType.TEXTURE
	
	return BackgroundType.COLOR

# === BACKGROUND APPLICATION ===

func _apply_scene_background(item: UnifiedItemData) -> void:
	"""Apply a scene-based background"""
	if not parent_node:
		push_error("BoardRenderer: No parent node set")
		return
	
	# Check cache first
	var scene: PackedScene
	if cached_scenes.has(item.id):
		scene = cached_scenes[item.id]
	else:
		scene = load(item.background_scene_path)
		cached_scenes[item.id] = scene
	
	if scene:
		background_node = scene.instantiate()
		_finalize_background_node()
		print("Applied scene background: %s" % item.id)

func _apply_animated_background(item: UnifiedItemData) -> void:
	"""Apply an animated procedural background"""
	if not parent_node or not ItemManager:
		push_error("BoardRenderer: Missing parent or ItemManager")
		return
	
	# Get or create procedural instance
	var instance = _get_or_create_procedural_instance(item.id)
	if not instance or not instance.has_method("draw_board_background"):
		_apply_fallback_background()
		return
	
	# Create canvas for drawing
	var canvas = Control.new()
	canvas.name = "AnimatedBackground"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Store instance reference
	canvas.set_meta("board_instance", instance)
	canvas.set_meta("item_id", item.id)
	
	# Setup animation
	var duration = instance.get("animation_duration") if instance.get("animation_duration") else 6.0
	var tween = parent_node.create_tween()
	tween.set_loops()
	
	tween.tween_method(
		func(phase: float):
			if instance:
				instance.animation_phase = phase
				canvas.queue_redraw(),
		0.0,
		1.0,
		duration
	)
	
	active_animations.append(tween)
	
	# Connect draw callback
	canvas.draw.connect(func():
		if instance and instance.has_method("draw_board_background"):
			instance.draw_board_background(canvas, canvas.size)
	)
	
	background_node = canvas
	_finalize_background_node()
	canvas.queue_redraw()
	
	animation_started.emit(item.id)
	print("Applied animated background: %s" % item.id)

func _apply_procedural_background(item: UnifiedItemData) -> void:
	"""Apply a static procedural background"""
	if not parent_node or not ItemManager:
		push_error("BoardRenderer: Missing parent or ItemManager")
		return
	
	# Get or create procedural instance
	var instance = _get_or_create_procedural_instance(item.id)
	if not instance or not instance.has_method("draw_board_background"):
		_apply_fallback_background()
		return
	
	# Create canvas for drawing
	var canvas = Control.new()
	canvas.name = "ProceduralBackground"
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Store instance reference
	canvas.set_meta("board_instance", instance)
	
	# Connect draw callback
	canvas.draw.connect(func():
		if instance and instance.has_method("draw_board_background"):
			instance.draw_board_background(canvas, canvas.size)
	)
	
	background_node = canvas
	_finalize_background_node()
	canvas.queue_redraw()
	
	print("Applied procedural background: %s" % item.id)

func _apply_texture_background(item: UnifiedItemData) -> void:
	"""Apply a texture-based background"""
	if not parent_node:
		push_error("BoardRenderer: No parent node set")
		return
	
	# Get or load texture
	var texture: Texture2D
	if cached_textures.has(item.id):
		texture = cached_textures[item.id]
	else:
		texture = load(item.texture_path)
		cached_textures[item.id] = texture
	
	if texture:
		var rect = TextureRect.new()
		rect.name = "TextureBackground"
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		background_node = rect
		_finalize_background_node()
		print("Applied texture background: %s" % item.id)
	else:
		_apply_fallback_background()

func _apply_color_background(item: UnifiedItemData) -> void:
	"""Apply a simple color background"""
	if not parent_node:
		push_error("BoardRenderer: No parent node set")
		return
	
	var rect = ColorRect.new()
	rect.name = "ColorBackground"
	
	# Get color from item or use default
	var bg_color = item.colors.get("primary", Color(0.15, 0.4, 0.15))
	rect.color = bg_color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	background_node = rect
	_finalize_background_node()
	print("Applied color background: %s with color %s" % [item.id, bg_color])

func _apply_fallback_background() -> void:
	"""Apply a fallback background when the requested one fails"""
	print("Applying fallback background")
	
	if not parent_node:
		return
	
	# Try legacy system
	var bg_color: Color
	match SettingsSystem.current_board_skin:
		"green":
			bg_color = Color(0.15, 0.4, 0.15)
		"blue":
			bg_color = Color(0.15, 0.25, 0.5)
		"sunset":
			bg_color = Color(0.6, 0.3, 0.15)
		_:
			bg_color = Color(0.2, 0.2, 0.2)
	
	var rect = ColorRect.new()
	rect.name = "FallbackBackground"
	rect.color = bg_color
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	background_node = rect
	_finalize_background_node()

func _finalize_background_node() -> void:
	"""Add the background node to parent and configure it"""
	if not background_node or not parent_node:
		return
	
	background_node.name = "BackgroundNode"
	parent_node.add_child(background_node)
	parent_node.move_child(background_node, 0)
	
	if background_node is Control:
		background_node.z_index = -10
		background_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if background_node.has_method("set_anchors_and_offsets_preset"):
			background_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# === CLEANUP ===

func _clear_current_background() -> void:
	"""Remove the current background and clean up"""
	# Stop animations
	for tween in active_animations:
		if tween and tween.is_valid():
			tween.kill()
	active_animations.clear()
	
	# Remove background node
	if background_node and is_instance_valid(background_node):
		background_node.queue_free()
	background_node = null
	
	# Emit stopped signal if was animated
	if current_background_type == BackgroundType.ANIMATED:
		animation_stopped.emit(current_background_id)

# === PROCEDURAL MANAGEMENT ===

func _get_or_create_procedural_instance(item_id: String):
	"""Get or create a procedural instance for an item"""
	if cached_procedural_instances.has(item_id):
		return cached_procedural_instances[item_id]
	
	if ItemManager:
		var instance = ItemManager.get_procedural_instance(item_id)
		if instance:
			cached_procedural_instances[item_id] = instance
			return instance
	
	return null

func _cache_texture(item_id: String, texture_path: String) -> void:
	"""Cache a texture for faster loading"""
	if ResourceLoader.exists(texture_path):
		cached_textures[item_id] = load(texture_path)

# === SIGNAL HANDLERS ===

func _on_board_skin_changed(skin_name: String) -> void:
	"""Handle board skin change from settings"""
	apply_background(skin_name)

# === UTILITY ===

func get_available_backgrounds() -> Array[String]:
	"""Get list of available background IDs"""
	var backgrounds: Array[String] = []
	
	if ItemManager:
		var all_items = ItemManager.get_all_items()
		for item in all_items:
			if item.category == "board":
				backgrounds.append(item.id)
	
	# Add legacy backgrounds if not in items
	var legacy = ["board_green", "board_blue", "board_sunset"]
	for bg in legacy:
		if not backgrounds.has(bg):
			backgrounds.append(bg)
	
	return backgrounds

func is_animated() -> bool:
	"""Check if current background is animated"""
	return current_background_type == BackgroundType.ANIMATED

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"current_id": current_background_id,
		"type": BackgroundType.keys()[current_background_type],
		"has_parent": parent_node != null,
		"has_background": background_node != null,
		"active_animations": active_animations.size(),
		"cached_procedurals": cached_procedural_instances.size(),
		"cached_textures": cached_textures.size(),
		"cached_scenes": cached_scenes.size()
	}

func print_debug() -> void:
	"""Print debug information"""
	print("=== BOARD RENDERER DEBUG ===")
	var info = get_debug_info()
	for key in info:
		print("%s: %s" % [key, info[key]])
	print("============================")
