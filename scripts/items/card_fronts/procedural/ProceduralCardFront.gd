# ProceduralCardFront.gd - Base class for procedurally generated card front designs
# Location: res://Pyramids/scripts/items/card_fronts/procedural/ProceduralCardFront.gd
# Last Updated: Simplified to use only item_id [Date]

class_name ProceduralCardFront
extends CardSkinBase

# Card dimensions (actual render size)
const CARD_WIDTH: int = 180
const CARD_HEIGHT: int = 252

# Core properties - using item_id as single identifier
@export var item_id: String = ""
@export var theme_name: String = ""
@export var item_rarity: UnifiedItemData.Rarity = UnifiedItemData.Rarity.COMMON

# Animation properties
@export var is_animated: bool = false
@export var animation_duration: float = 2.5
@export var animation_elements: Array[String] = []
var animation_phase: float = 0.0

func _init():
	# Set skin_name to match item_id for parent compatibility
	pass

func _ready():
	# Sync skin_name with item_id when set
	if item_id != "":
		skin_name = item_id

# Core drawing method - override in child classes
func draw_card_front(canvas: CanvasItem, size: Vector2, rank: String, suit: int) -> void:
	# Default implementation - draw basic card
	canvas.draw_rect(Rect2(Vector2.ZERO, size), card_bg_color)
	
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

func _get_suit_symbol(suit: int) -> String:
	match suit:
		0: return "♠"  # Spades
		1: return "♥"  # Hearts
		2: return "♣"  # Clubs
		3: return "♦"  # Diamonds
		_: return "?"

# Export card as PNG sprite
func export_to_png(custom_output_path: String = "") -> bool:
	var output_path = custom_output_path if custom_output_path != "" else "res://Pyramids/assets/icons/card_fronts/%s.png" % item_id
	
	var dir_path = output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var canvas = Control.new()
	canvas.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	# Draw with Ace of Spades as example
	canvas.draw.connect(func(): draw_card_front(canvas, canvas.size, "A", 0))
	
	viewport.add_child(canvas)
	Engine.get_main_loop().root.add_child(viewport)
	
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	
	var image = viewport.get_texture().get_image()
	var success = image.save_png(output_path)
	
	viewport.queue_free()
	
	print("Exported card front to: %s" % output_path)
	return success == OK

# Create UnifiedItemData for this skin
func create_item_data() -> UnifiedItemData:
	var item = UnifiedItemData.new()
	
	# Use item_id as the single identifier
	item.id = item_id
	item.display_name = display_name if display_name != "" else theme_name + " Card Front"
	item.description = "Procedurally generated " + theme_name + " card front design"
	item.category = UnifiedItemData.Category.CARD_FRONT
	item.rarity = item_rarity
	item.source = UnifiedItemData.Source.SHOP
	item.base_price = _calculate_price_by_rarity(item_rarity)
	item.is_animated = is_animated
	item.is_procedural = true
	item.procedural_script_path = get_script().resource_path
	
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
