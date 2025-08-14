# ProceduralBoard.gd - Base class for procedurally generated board designs
# Location: res://Pyramids/scripts/items/boards/procedural/ProceduralBoard.gd
# Last Updated: Simplified to use only item_id [Date]

class_name ProceduralBoard
extends BoardSkinBase

# Board dimensions for export
const BOARD_WIDTH: int = 384
const BOARD_HEIGHT: int = 252

# Core properties - using item_id as single identifier
@export var item_id: String = ""
@export var theme_name: String = ""
@export var item_rarity: UnifiedItemData.Rarity = UnifiedItemData.Rarity.COMMON

# Animation properties
@export var is_animated: bool = false
@export var animation_duration: float = 3.0
@export var animation_elements: Array[String] = []
var animation_phase: float = 0.0

func _init():
	pass

func _ready():
	# Sync skin_name with item_id when set
	if item_id != "":
		skin_name = item_id

# Core drawing method - override in child classes
func draw_board_background(canvas: CanvasItem, size: Vector2) -> void:
	# Default implementation
	canvas.draw_rect(Rect2(Vector2.ZERO, size), board_bg_color)

# Export board as PNG sprite
func export_to_png(custom_output_path: String = "") -> bool:
	var output_path = custom_output_path if custom_output_path != "" else "res://Pyramids/assets/icons/boards/%s.png" % item_id
	
	var dir_path = output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var canvas = Control.new()
	canvas.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	canvas.draw.connect(func(): draw_board_background(canvas, canvas.size))
	
	viewport.add_child(canvas)
	Engine.get_main_loop().root.add_child(viewport)
	
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	
	var image = viewport.get_texture().get_image()
	var success = image.save_png(output_path)
	
	viewport.queue_free()
	
	print("Exported board to: %s" % output_path)
	return success == OK

# Create UnifiedItemData for this board
func create_item_data() -> UnifiedItemData:
	var item = UnifiedItemData.new()
	
	# Use item_id as the single identifier
	item.id = item_id
	item.display_name = display_name if display_name != "" else theme_name + " Board"
	item.description = "Procedurally generated " + theme_name + " board design"
	item.category = UnifiedItemData.Category.BOARD
	item.rarity = item_rarity
	item.source = UnifiedItemData.Source.SHOP
	item.base_price = _calculate_price_by_rarity(item_rarity)
	item.is_animated = is_animated
	item.is_procedural = true
	item.procedural_script_path = get_script().resource_path
	item.background_type = "procedural"
	
	# Sync skin_name for compatibility
	skin_name = item_id
	
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
