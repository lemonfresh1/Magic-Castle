# ProceduralCardBack.gd - Base class for procedurally generated card back designs
# Location: res://Pyramids/scripts/items/card_backs/procedural/ProceduralCardBack.gd
# Last Updated: Updated to use UnifiedItemData exclusively [Date]

class_name ProceduralCardBack
extends CardSkinBase

# Card dimensions (actual render size)
const CARD_WIDTH: int = 180
const CARD_HEIGHT: int = 252
const RENDER_WIDTH: int = 90  
const RENDER_HEIGHT: int = 126

# Animation properties
@export var is_animated: bool = false
@export var animation_duration: float = 2.5
@export var animation_elements: Array[String] = []

# Design properties
@export var theme_name: String = ""
@export var item_id: String = ""
@export var item_rarity: UnifiedItemData.Rarity = UnifiedItemData.Rarity.COMMON

# Animation state (will be used by Node-based instances)
var animation_phase: float = 0.0
var is_animation_playing: bool = false

func _init():
	# Override in child classes
	pass

# Core drawing method - override in child classes
func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Default implementation - override this
	canvas.draw_rect(Rect2(Vector2.ZERO, size), UIStyleManager.get_card_color("pyramid_sand"))

# Export card as PNG sprite with smart naming and folder structure
func export_to_png(custom_output_path: String = "") -> bool:
	var output_path: String
	
	if custom_output_path != "":
		# Use custom path if provided
		output_path = custom_output_path
	else:
		# Smart auto-naming and folder structure
		output_path = _generate_export_path()
	
	# Ensure directory exists
	var dir_path = output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.open("res://").make_dir_recursive(dir_path)
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var canvas = Control.new()
	canvas.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
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
	
	print("Exported card back to: %s" % output_path)
	return success == OK

func _generate_export_path() -> String:
	# Export to assets/icons/card_backs/
	return "res://Pyramids/assets/icons/card_backs/%s.png" % item_id

func _on_export_draw():
	# Get the canvas control
	var canvas = Engine.get_main_loop().root.get_viewport().get_child(-1).get_child(0)
	draw_card_back(canvas, Vector2(CARD_WIDTH, CARD_HEIGHT))

# Animation system - for Node-based instances only
func setup_animation_on_node(node: Node) -> void:
	if not is_animated:
		return
		
	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_method(_update_animation_phase, 0.0, 1.0, animation_duration)

func _update_animation_phase(phase: float) -> void:
	animation_phase = phase

# Create UnifiedItemData for this skin
func create_item_data() -> UnifiedItemData:
	var item = UnifiedItemData.new()
	item.id = item_id
	item.display_name = display_name
	item.description = "Procedurally generated " + theme_name + " card back design"
	item.category = UnifiedItemData.Category.CARD_BACK
	item.rarity = item_rarity
	item.source = UnifiedItemData.Source.SHOP
	item.base_price = _calculate_price_by_rarity(item_rarity)
	item.subcategory = theme_name.to_lower()
	item.set_name = theme_name + " Collection"
	item.is_animated = is_animated
	item.is_procedural = true
	item.procedural_script_path = get_script().resource_path
	
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
