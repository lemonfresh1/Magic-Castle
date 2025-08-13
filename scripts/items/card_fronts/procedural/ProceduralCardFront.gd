# ProceduralCardFront.gd - Base class for procedurally generated card front designs
# Path: res://Pyramids/scripts/items/card_fronts/procedural/ProceduralCardFront.gd
# Last Updated: Fixed export and animation methods [Date]

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
@export var item_rarity: UnifiedItemData.Rarity = UnifiedItemData.Rarity.COMMON

# Animation state (will be used by Node-based instances)
var animation_phase: float = 0.0
var is_animation_playing: bool = false

func _init():
	# Override in child classes
	pass

# Core drawing method - override in child classes
func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	# Default implementation - draw basic card
	canvas.draw_rect(Rect2(Vector2.ZERO, size), UIStyleManager.get_color("white"))
	
	# Draw rank and suit
	_draw_rank_and_suit(canvas, size, rank, suit)

func _draw_rank_and_suit(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	var suit_symbol = _get_suit_symbol(suit)
	var color = get_suit_color(suit)
	
	# Top-left rank
	var rank_pos = rank_position_offset
	_draw_text(canvas, rank, rank_pos, rank_font_size, color)
	
	# Suit below rank
	var suit_pos = suit_position_offset
	_draw_text(canvas, suit_symbol, suit_pos, suit_font_size, color)
	
	# Bottom-right rank (rotated)
	var rank_mirror_pos = Vector2(size.x - rank_position_offset.x - 20, size.y - rank_position_offset.y - 30)
	_draw_text_rotated(canvas, rank, rank_mirror_pos, rank_font_size, color, PI)
	
	# Bottom-right suit (rotated)
	var suit_mirror_pos = Vector2(size.x - suit_position_offset.x - 20, size.y - suit_position_offset.y - 30)
	_draw_text_rotated(canvas, suit_symbol, suit_mirror_pos, suit_font_size, color, PI)

func _draw_text(canvas: CanvasItem, text: String, pos: Vector2, size: int, color: Color) -> void:
	var font = ThemeDB.fallback_font
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_text_rotated(canvas: CanvasItem, text: String, pos: Vector2, size: int, color: Color, rotation: float) -> void:
	var font = ThemeDB.fallback_font
	canvas.draw_set_transform(pos, rotation, Vector2.ONE)
	canvas.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# Export card as PNG sprite with smart naming and folder structure
func export_to_png(custom_output_path: String = "") -> bool:
	var output_path: String
	
	if custom_output_path != "":
		output_path = custom_output_path
	else:
		# Export to assets/icons/ for shop/inventory display
		output_path = "res://Pyramids/assets/icons/card_fronts/%s.png" % item_id
	
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
	
	print("Exported card front to: %s" % output_path)
	return success == OK
func _on_export_draw():
	# Get the canvas control
	var canvas = Engine.get_main_loop().root.get_viewport().get_child(-1).get_child(0)
	# Draw with Ace of Spades as example
	draw_card_front(canvas, Vector2(CARD_WIDTH, CARD_HEIGHT), "A", CardData.Suit.SPADES)

# Animation system - for Node-based instances only
func setup_animation_on_node(node: Node) -> void:
	if not is_animated:
		return
		
	# Create tween on the NODE, not on this Resource
	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_method(_update_animation_phase, 0.0, 1.0, animation_duration)

func _update_animation_phase(phase: float) -> void:
	animation_phase = phase
	# DON'T queue_redraw here - the Card node will handle redrawing

# Create UnifiedItemData for this skin
func create_item_data() -> UnifiedItemData:
	var item = UnifiedItemData.new()
	item.id = item_id
	item.display_name = display_name
	item.description = "Procedurally generated " + theme_name + " card front design"
	item.category = UnifiedItemData.Category.CARD_FRONT  # Fixed: was CARD_BACK
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
