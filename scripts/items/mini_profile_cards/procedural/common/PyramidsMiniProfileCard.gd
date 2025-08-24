# PyramidsMiniProfileCard.gd - Clean desert-themed mini profile card
# Location: res://Pyramids/scripts/items/mini_profile_cards/procedural/PyramidsMiniProfileCard.gd
# Last Updated: Fixed property access [August 24, 2025]

extends ProceduralMiniProfileCard

func _init():
	# Identifiers
	self.item_id = "pyramids_mini_profile_card"
	self.display_name = "Pyramids"
	self.theme_name = "Pyramids"
	self.item_rarity = UnifiedItemData.Rarity.COMMON
	
	# Main Panel - Sandy/papyrus look
	self.main_bg_color = Color(0.96, 0.92, 0.84, 0.95)  # Light sand/papyrus color
	self.main_border_color = Color(0.76, 0.68, 0.50, 1.0)  # Darker sand border
	self.main_border_width = 2
	self.main_corner_radius = 6
	
	# Stats Panel - Keep subtle/transparent
	self.stats_bg_color = Color(0, 0, 0, 0.08)  # Very subtle dark overlay
	self.stats_border_color = Color(0.76, 0.68, 0.50, 0.3)  # Faint sand border
	self.stats_border_width = 1
	self.stats_corner_radius = 4
	
	# Bottom Section - Also subtle
	self.bot_bg_color = Color(0, 0, 0, 0.1)  # Slightly darker overlay
	self.bot_border_color = Color(0.76, 0.68, 0.50, 0.3)  # Faint sand border
	self.bot_border_width = 1
	self.bot_corner_radius = 4
	
	# Accent color - Egyptian gold
	self.accent_color = Color(0.85, 0.65, 0.13, 1.0)  # Gold accent
	
	# Pattern settings
	self.has_pattern = true
	self.pattern_type = "hieroglyphs"  # Custom pattern

# Override to add hieroglyph-style decorations
func draw_mini_profile_card(canvas: CanvasItem, size: Vector2) -> void:
	# Main background
	canvas.draw_rect(Rect2(Vector2.ZERO, size), self.main_bg_color)
	
	# Add subtle papyrus texture effect
	_draw_papyrus_texture(canvas, size)
	
	# Main border
	if self.main_border_width > 0:
		canvas.draw_rect(Rect2(Vector2.ZERO, size), self.main_border_color, false, self.main_border_width)
	
	# Stats panel area
	var stats_rect = Rect2(100, 35, 90, 65)
	canvas.draw_rect(stats_rect, self.stats_bg_color)
	if self.stats_border_width > 0:
		canvas.draw_rect(stats_rect, self.stats_border_color, false, self.stats_border_width)
	
	# Bottom section area
	var bot_rect = Rect2(10, 115, 180, 68)
	canvas.draw_rect(bot_rect, self.bot_bg_color)
	if self.bot_border_width > 0:
		canvas.draw_rect(bot_rect, self.bot_border_color, false, self.bot_border_width)
	
	# Add decorative elements
	_draw_corner_decorations(canvas, size)

func _draw_papyrus_texture(canvas: CanvasItem, size: Vector2) -> void:
	# Create subtle horizontal lines like papyrus fibers
	var fiber_color = Color(0.86, 0.82, 0.74, 0.3)  # Slightly darker than bg
	
	for y in range(0, int(size.y), 3):
		if randf() > 0.6:  # Random fibers
			var start_x = randf() * 20
			var end_x = size.x - randf() * 20
			canvas.draw_line(Vector2(start_x, y), Vector2(end_x, y), fiber_color, 1)

func _draw_corner_decorations(canvas: CanvasItem, size: Vector2) -> void:
	# Draw small pyramid symbols in corners
	var pyramid_color = self.accent_color
	pyramid_color.a = 0.4
	
	# Top-left pyramid
	var tl_points = PackedVector2Array([
		Vector2(5, 15),
		Vector2(10, 5),
		Vector2(15, 15)
	])
	canvas.draw_colored_polygon(tl_points, pyramid_color)
	
	# Top-right pyramid
	var tr_points = PackedVector2Array([
		Vector2(size.x - 15, 15),
		Vector2(size.x - 10, 5),
		Vector2(size.x - 5, 15)
	])
	canvas.draw_colored_polygon(tr_points, pyramid_color)
	
	# Bottom decorative line
	canvas.draw_line(
		Vector2(20, size.y - 5),
		Vector2(size.x - 20, size.y - 5),
		pyramid_color,
		1
	)
	
	# Small accent dots along the bottom line
	for x in range(30, int(size.x) - 20, 20):
		canvas.draw_circle(Vector2(x, size.y - 5), 2, pyramid_color)
