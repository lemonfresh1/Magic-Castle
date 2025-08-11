# ProceduralCardSkin.gd - Base class for procedurally generated card designs
# Path: res://Pyramids/scripts/items/card_fronts/procedural/ProceduralCardSkin.gd
# Last Updated: Created procedural card skin foundation [Date]

class_name ProceduralCardFront
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
@export var item_rarity: ItemData.Rarity = ItemData.Rarity.COMMON

# Animation state
var animation_phase: float = 0.0
var is_animation_playing: bool = false

func _init():
	# Override in child classes
	pass

# Core drawing method - override in child classes
func draw_card_back(canvas: CanvasItem, size: Vector2) -> void:
	# Default implementation - override this
	canvas.draw_rect(Rect2(Vector2.ZERO, size), UIStyleManager.get_card_color("pyramid_sand"))

# Export card as PNG sprite
func export_to_png(output_path: String) -> bool:
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
	
	return success == OK

func _on_export_draw():
	# Get the canvas control
	var canvas = Engine.get_main_loop().root.get_viewport().get_child(-1).get_child(0)
	draw_card_back(canvas, Vector2(CARD_WIDTH, CARD_HEIGHT))

# Animation system
func start_animation() -> void:
	if not is_animated:
		return
		
	is_animation_playing = true
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(_update_animation_phase, 0.0, 1.0, animation_duration)

func _update_animation_phase(phase: float) -> void:
	animation_phase = phase
	# Trigger redraw for animated cards
	queue_redraw()

# Create ItemData for this skin
func create_item_data() -> ItemData:
	var item = ItemData.new()
	item.id = item_id
	item.display_name = display_name
	item.description = "Procedurally generated " + theme_name + " card design"
	item.category = ItemData.Category.CARD_BACK
	item.rarity = item_rarity
	item.source = ItemData.Source.SHOP
	item.base_price = _calculate_price_by_rarity(item_rarity)
	item.subcategory = theme_name.to_lower()
	item.set_name = theme_name + " Collection"
	item.is_animated = is_animated
	
	return item

func _calculate_price_by_rarity(rarity: ItemData.Rarity) -> int:
	match rarity:
		ItemData.Rarity.COMMON: return 50
		ItemData.Rarity.UNCOMMON: return 100
		ItemData.Rarity.RARE: return 250
		ItemData.Rarity.EPIC: return 500
		ItemData.Rarity.LEGENDARY: return 1000
		_: return 0

# High contrast support
func supports_high_contrast() -> bool:
	return supports_high_contrast

# Get animation elements for Epic tier
func get_animation_elements() -> Array[String]:
	return animation_elements
