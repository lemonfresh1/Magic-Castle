# ScrollableContainer.gd - Self-contained scrollable content component
# Replaces: UIStyleManager.setup_scrollable_content()
extends ScrollContainer
class_name ScrollableContainer

# Configuration exports
@export var content_margins: Vector2i = Vector2i(10, 10)  # x=horizontal, y=vertical
@export var content_separation: int = 10
@export var show_horizontal_scrollbar: bool = false
@export var show_vertical_scrollbar: bool = true
@export var auto_setup: bool = true  # Create structure automatically

# The VBox where content should be added
var content_container: VBoxContainer

# Internal structure
var _margin_container: MarginContainer

func _ready():
	if auto_setup:
		setup_container()

func setup_container():
	"""Create the internal structure - can be called manually if auto_setup is false"""
	
	# Configure scroll modes
	if show_horizontal_scrollbar:
		horizontal_scroll_mode = ScrollMode.SCROLL_MODE_AUTO
	else:
		horizontal_scroll_mode = ScrollMode.SCROLL_MODE_DISABLED
	
	if show_vertical_scrollbar:
		vertical_scroll_mode = ScrollMode.SCROLL_MODE_AUTO
	else:
		vertical_scroll_mode = ScrollMode.SCROLL_MODE_DISABLED
	
	# Clear any existing children (for reinit)
	for child in get_children():
		child.queue_free()
	
	# Create margin container
	_margin_container = MarginContainer.new()
	_margin_container.name = "MarginContainer"
	_apply_margins()
	_margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_margin_container)
	
	# Create content container (VBox)
	content_container = VBoxContainer.new()
	content_container.name = "ContentVBox"
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", content_separation)
	_margin_container.add_child(content_container)
	
	# Ensure we expand properly
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _apply_margins():
	"""Apply margin configuration"""
	if not _margin_container:
		return
	
	_margin_container.add_theme_constant_override("margin_left", content_margins.x)
	_margin_container.add_theme_constant_override("margin_right", content_margins.x)
	_margin_container.add_theme_constant_override("margin_top", content_margins.y)
	_margin_container.add_theme_constant_override("margin_bottom", content_margins.y)

func set_content_margins(margins: Vector2i):
	"""Update margins at runtime"""
	content_margins = margins
	_apply_margins()

func set_content_separation(separation: int):
	"""Update content separation at runtime"""
	content_separation = separation
	if content_container:
		content_container.add_theme_constant_override("separation", content_separation)

func clear_content():
	"""Clear all content from the container"""
	if not content_container:
		return
	
	for child in content_container.get_children():
		child.queue_free()

func add_content(node: Node):
	"""Add a node to the content container"""
	if not content_container:
		push_error("ScrollableContainer: content_container not initialized. Call setup_container() first.")
		return
	
	content_container.add_child(node)

func get_content_children() -> Array:
	"""Get all children in the content container"""
	if not content_container:
		return []
	return content_container.get_children()

# Convenience method for compatibility with old code
func get_content_vbox() -> VBoxContainer:
	"""Get the VBox container - for compatibility with old setup_scrollable_content()"""
	return content_container
