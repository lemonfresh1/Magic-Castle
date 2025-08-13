# ProceduralBoard.gd - Base class for procedurally generated board designs
# Location: res://Pyramids/scripts/items/boards/procedural/ProceduralBoard.gd
# Last Updated: Updated to use UnifiedItemData exclusively [Date]

class_name ProceduralBoard
extends BoardSkinBase

# Board dimensions for export
const BOARD_WIDTH: int = 384
const BOARD_HEIGHT: int = 252
const THUMBNAIL_WIDTH: int = 192
const THUMBNAIL_HEIGHT: int = 126

# Animation properties
@export var is_animated: bool = false
@export var animation_duration: float = 3.0
@export var animation_elements: Array[String] = []

# Design properties
@export var theme_name: String = ""
@export var item_id: String = ""
@export var item_rarity: UnifiedItemData.Rarity = UnifiedItemData.Rarity.COMMON

# Animation state
var animation_phase: float = 0.0
var is_animation_playing: bool = false

func _init():
	# Override in child classes
	pass

# Core drawing method - override in child classes
func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Default implementation
	canvas.draw_rect(Rect2(Vector2.ZERO, size), UIStyleManager.get_color("board_green"))

# Export board as PNG sprite with smart naming
func export_to_png(custom_output_path: String = "") -> bool:
	var output_path: String
	
	if custom_output_path != "":
		output_path = custom_output_path
	else:
		output_path = _generate_export_path()
	
	# Ensure directory exists
	var dir_path = output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.open("res://").make_dir_recursive(dir_path)
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var canvas = Control.new()
	canvas.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	canvas.draw.connect(_on_export_draw)
	
	viewport.add_child(canvas)
	Engine.get_main_loop().root.add_child(viewport)
	
	# Render one frame
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	
	# Get the image
	var image = viewport.get_texture().get_image()
	var success = image.save_png(output_path)
	
	# Cleanup
	viewport.queue_free()
	
	print("Exported board to: %s" % output_path)
	return success == OK

func _generate_export_path() -> String:
	# Export to assets/icons/boards/
	return "res://Pyramids/assets/icons/boards/%s.png" % item_id

func _on_export_draw():
	# Get the canvas control
	var canvas = Engine.get_main_loop().root.get_viewport().get_child(-1).get_child(0)
	draw_board_background(canvas, Vector2(BOARD_WIDTH, BOARD_HEIGHT))

# Animation system - for Node-based instances only
func setup_animation_on_node(node: Node) -> void:
	if not is_animated:
		return
		
	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_method(_update_animation_phase, 0.0, 1.0, animation_duration)

func _update_animation_phase(phase: float) -> void:
	animation_phase = phase

# Create UnifiedItemData for this board
func create_item_data() -> UnifiedItemData:
	var item = UnifiedItemData.new()
	item.id = item_id
	item.display_name = display_name
	item.description = "Procedurally generated " + theme_name + " board design"
	item.category = UnifiedItemData.Category.BOARD
	item.rarity = item_rarity
	item.source = UnifiedItemData.Source.SHOP
	item.base_price = _calculate_price_by_rarity(item_rarity)
	item.subcategory = theme_name.to_lower()
	item.set_name = theme_name + " Collection"
	item.is_animated = is_animated
	item.is_procedural = true
	item.procedural_script_path = get_script().resource_path
	item.background_type = "procedural"
	
	return item

func _calculate_price_by_rarity(rarity: UnifiedItemData.Rarity) -> int:
	match rarity:
		UnifiedItemData.Rarity.COMMON: return 50
		UnifiedItemData.Rarity.UNCOMMON: return 100
		UnifiedItemData.Rarity.RARE: return 250
		UnifiedItemData.Rarity.EPIC: return 500
		UnifiedItemData.Rarity.LEGENDARY: return 1000
		UnifiedItemData.Rarity.MYTHIC: return 2000
		_: return 0

# Get animation elements for Epic tier
func get_animation_elements() -> Array[String]:
	return animation_elements
