# ProceduralMiniProfileCard.gd - Visual themes for mini profile cards
# Location: res://Pyramids/scripts/items/mini_profile_cards/procedural/ProceduralMiniProfileCard.gd
# Last Updated: Simplified to panel styling only [August 24, 2025]

class_name ProceduralMiniProfileCard
extends Resource

# Core properties
@export var item_id: String = ""
@export var display_name: String = "Classic Profile"
@export var theme_name: String = ""
@export var item_rarity: UnifiedItemData.Rarity = UnifiedItemData.Rarity.COMMON

# Card dimensions (for PNG export)
const CARD_WIDTH: int = 200
const CARD_HEIGHT: int = 200

# Main Panel Style
@export var main_bg_color: Color = Color(0.15, 0.15, 0.15, 0.9)
@export var main_border_color: Color = Color(0.3, 0.3, 0.3, 1.0)
@export var main_border_width: int = 2
@export var main_corner_radius: int = 8

# Stats Panel Style  
@export var stats_bg_color: Color = Color(0.1, 0.1, 0.1, 0.2)
@export var stats_border_color: Color = Color(0.2, 0.2, 0.2, 0.3)
@export var stats_border_width: int = 1
@export var stats_corner_radius: int = 4

# Bottom Section Style
@export var bot_bg_color: Color = Color(0.1, 0.1, 0.1, 0.3)
@export var bot_border_color: Color = Color(0.3, 0.3, 0.3, 0.3)
@export var bot_border_width: int = 1
@export var bot_corner_radius: int = 4

# Visual Effects
@export var has_gradient: bool = false
@export var gradient_colors: Array[Color] = []
@export var has_pattern: bool = false
@export var pattern_type: String = "none"  # none, dots, grid, diagonal
@export var accent_color: Color = Color("#a487ff")

# Get style for main panel
func get_main_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = main_bg_color
	style.border_color = main_border_color
	style.set_border_width_all(main_border_width)
	style.set_corner_radius_all(main_corner_radius)
	return style

# Get style for stats panel
func get_stats_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = stats_bg_color
	style.border_color = stats_border_color
	style.set_border_width_all(stats_border_width)
	style.set_corner_radius_all(stats_corner_radius)
	style.set_content_margin_all(4)
	return style

# Get style for bottom section
func get_bot_section_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bot_bg_color
	style.border_color = bot_border_color
	style.set_border_width_all(bot_border_width)
	style.set_corner_radius_all(bot_corner_radius)
	return style

# Draw preview for PNG export
func draw_mini_profile_card(canvas: CanvasItem, size: Vector2) -> void:
	# Main background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), main_bg_color)
	
	# Main border
	if main_border_width > 0:
		canvas.draw_rect(Rect2(Vector2.ZERO, size), main_border_color, false, main_border_width)
	
	# Stats panel area (approximate position)
	var stats_rect = Rect2(100, 35, 90, 65)
	canvas.draw_rect(stats_rect, stats_bg_color)
	if stats_border_width > 0:
		canvas.draw_rect(stats_rect, stats_border_color, false, stats_border_width)
	
	# Bottom section area (approximate position)
	var bot_rect = Rect2(10, 115, 180, 68)
	canvas.draw_rect(bot_rect, bot_bg_color)
	if bot_border_width > 0:
		canvas.draw_rect(bot_rect, bot_border_color, false, bot_border_width)
	
	# Draw pattern overlay if enabled
	if has_pattern:
		_draw_pattern(canvas, size)

func _draw_pattern(canvas: CanvasItem, size: Vector2) -> void:
	match pattern_type:
		"dots":
			var dot_color = accent_color
			dot_color.a = 0.1
			for x in range(10, int(size.x), 15):
				for y in range(10, int(size.y), 15):
					canvas.draw_circle(Vector2(x, y), 2, dot_color)
		"grid":
			var line_color = accent_color
			line_color.a = 0.05
			for x in range(0, int(size.x), 20):
				canvas.draw_line(Vector2(x, 0), Vector2(x, size.y), line_color, 1)
			for y in range(0, int(size.y), 20):
				canvas.draw_line(Vector2(0, y), Vector2(size.x, y), line_color, 1)
		"diagonal":
			var line_color = accent_color  
			line_color.a = 0.05
			for i in range(-int(size.y), int(size.x), 20):
				canvas.draw_line(Vector2(i, 0), Vector2(i + size.y, size.y), line_color, 1)

# Export as PNG
func export_to_png(custom_output_path: String = "") -> bool:
	var output_path = custom_output_path if custom_output_path != "" else "res://Pyramids/assets/icons/mini_profile_cards/%s.png" % item_id
	
	var dir_path = output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var viewport = SubViewport.new()
	viewport.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var canvas = Control.new()
	canvas.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	canvas.draw.connect(func(): draw_mini_profile_card(canvas, canvas.size))
	
	viewport.add_child(canvas)
	Engine.get_main_loop().root.add_child(viewport)
	
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	
	var image = viewport.get_texture().get_image()
	var success = image.save_png(output_path)
	
	viewport.queue_free()
	
	print("Exported mini profile card to: %s" % output_path)
	return success == OK

# Create UnifiedItemData
func create_item_data() -> UnifiedItemData:
	var item = UnifiedItemData.new()
	
	item.id = item_id
	item.display_name = display_name if display_name != "" else theme_name + " Profile Card"
	item.description = "A stylish mini profile card with " + theme_name + " theme"
	item.category = UnifiedItemData.Category.MINI_PROFILE_CARD
	item.rarity = item_rarity
	
	item.is_procedural = true
	item.procedural_script_path = get_script().resource_path
	item.mini_profile_card_layout = "standard"
	
	return item
