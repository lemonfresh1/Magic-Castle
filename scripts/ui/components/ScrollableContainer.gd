# ScrollableContainer.gd - Self-styling scroll container with auto-structure
# Location: res://Pyramids/scripts/ui/components/ScrollableContainer.gd  
# Last Updated: Added option to hide scrollbars

extends ScrollContainer
class_name ScrollableContainer

# Configuration overrides (optional)
@export var custom_width: int = -1  # -1 means use default from ThemeConstants
@export var custom_height: int = -1
@export var custom_margin_left: int = -1
@export var custom_margin_right: int = -1
@export var custom_margin_top: int = -1
@export var custom_margin_bottom: int = -1
@export var custom_separation: int = -1
@export var auto_hide_scrollbars: bool = true
@export var hide_scrollbars: bool = true  # NEW: completely hide scrollbars

# Internal node references
var margin_container: MarginContainer
var content_container: VBoxContainer

# Runtime config cache
var _config_applied: bool = false

func _ready():
	_setup_structure()
	_apply_config()
	
	# Re-apply on export changes in editor
	if Engine.is_editor_hint():
		set_notify_transform(true)

func _notification(what: int):
	# Re-apply config when export vars change in editor
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_apply_config()

func _setup_structure():
	"""Create the internal MarginContainer → VBoxContainer structure"""
	# Clear any existing children (in case this replaces an existing ScrollContainer)
	for child in get_children():
		if child is MarginContainer and child.name == "MarginContainer":
			margin_container = child
			# Look for existing VBoxContainer
			for grandchild in child.get_children():
				if grandchild is VBoxContainer and grandchild.name == "ContentVBox":
					content_container = grandchild
					return  # Structure already exists
	
	# Create MarginContainer if not found
	if not margin_container:
		margin_container = MarginContainer.new()
		margin_container.name = "MarginContainer"
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(margin_container)
	
	# Create VBoxContainer if not found
	if not content_container:
		content_container = VBoxContainer.new()
		content_container.name = "ContentVBox"
		content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.add_child(content_container)

func _apply_config():
	"""Apply configuration from ThemeConstants"""
	# Skip if already applied and not in editor
	if _config_applied and not Engine.is_editor_hint():
		return
	
	var theme_constants = ThemeConstants
	if not theme_constants:
		push_error("ScrollableContainer: ThemeConstants not found in autoloads")
		return
	
	var config = theme_constants.scroll_config
	if not config:
		push_error("ScrollableContainer: scroll_config not found in ThemeConstants")
		return
	
	# Get configuration values (use custom if set, otherwise use theme defaults)
	var width = custom_width if custom_width > 0 else config.get("width", 600)
	var height = custom_height if custom_height > 0 else config.get("height", 300)
	var margin_left = custom_margin_left if custom_margin_left >= 0 else config.get("margin_left", 5)
	var margin_right = custom_margin_right if custom_margin_right >= 0 else config.get("margin_right", 5)
	var margin_top = custom_margin_top if custom_margin_top >= 0 else config.get("margin_top", 2)
	var margin_bottom = custom_margin_bottom if custom_margin_bottom >= 0 else config.get("margin_bottom", 9)
	var separation = custom_separation if custom_separation >= 0 else config.get("content_separation", 10)
	
	# Apply to ScrollContainer
	custom_minimum_size = Vector2(width, height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Configure scroll modes
	if hide_scrollbars:
		# Completely hide scrollbars but keep scrolling functionality
		horizontal_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_NEVER
		vertical_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_NEVER
	elif auto_hide_scrollbars:
		horizontal_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_AUTO
		vertical_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_AUTO
	else:
		horizontal_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_ALWAYS
		vertical_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_ALWAYS
	
	# Style the scrollbars (even if hidden, in case they're shown later)
	_style_scrollbars(theme_constants)
	
	# Apply margins to MarginContainer
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", margin_left)
		margin_container.add_theme_constant_override("margin_right", margin_right)
		margin_container.add_theme_constant_override("margin_top", margin_top)
		margin_container.add_theme_constant_override("margin_bottom", margin_bottom)
	
	# Apply separation to VBoxContainer
	if content_container:
		content_container.add_theme_constant_override("separation", separation)
	
	_config_applied = true

func _style_scrollbars(theme_constants):
	"""Apply styling to scrollbars"""
	# Create scrollbar styles
	var scrollbar_style = StyleBoxFlat.new()
	scrollbar_style.bg_color = theme_constants.colors.gray_100
	scrollbar_style.set_corner_radius_all(4)
	
	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = theme_constants.colors.gray_400
	grabber_style.set_corner_radius_all(4)
	
	var grabber_hover = StyleBoxFlat.new()
	grabber_hover.bg_color = theme_constants.colors.gray_500
	grabber_hover.set_corner_radius_all(4)
	
	var grabber_pressed = StyleBoxFlat.new()
	grabber_pressed.bg_color = theme_constants.colors.gray_600
	grabber_pressed.set_corner_radius_all(4)
	
	# Apply to vertical scrollbar
	add_theme_stylebox_override("scroll", scrollbar_style)
	add_theme_stylebox_override("grabber", grabber_style)
	add_theme_stylebox_override("grabber_highlight", grabber_hover)
	add_theme_stylebox_override("grabber_pressed", grabber_pressed)

# === PUBLIC API ===

func get_content_container() -> VBoxContainer:
	"""Get the VBoxContainer where content should be added"""
	if not content_container:
		_setup_structure()
	return content_container

func clear_content():
	"""Clear all content from the container"""
	if content_container:
		for child in content_container.get_children():
			child.queue_free()

func add_content(node: Node):
	"""Convenience method to add content to the container"""
	if not content_container:
		_setup_structure()
	content_container.add_child(node)

func set_content_separation(separation: int):
	"""Update the separation between content items"""
	custom_separation = separation
	if content_container:
		content_container.add_theme_constant_override("separation", separation)

func set_margins(left: int = -1, right: int = -1, top: int = -1, bottom: int = -1):
	"""Update margins at runtime"""
	if left >= 0:
		custom_margin_left = left
	if right >= 0:
		custom_margin_right = right
	if top >= 0:
		custom_margin_top = top
	if bottom >= 0:
		custom_margin_bottom = bottom
	_apply_config()

func refresh_config():
	"""Force refresh configuration from ThemeConstants"""
	_config_applied = false
	_apply_config()

func set_scrollbar_visibility(visible: bool):
	"""Control scrollbar visibility at runtime"""
	hide_scrollbars = not visible
	_apply_config()

# === COMPATIBILITY HELPERS ===

func get_margin_container() -> MarginContainer:
	"""Get the margin container for compatibility with existing code"""
	if not margin_container:
		_setup_structure()
	return margin_container

func get_vbox_container() -> VBoxContainer:
	"""Alias for get_content_container() for compatibility"""
	return get_content_container()
