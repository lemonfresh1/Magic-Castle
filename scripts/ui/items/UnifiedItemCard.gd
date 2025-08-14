# UnifiedItemCard.gd - Universal item card for ALL UI displays
# Location: res://Pyramids/scripts/ui/UnifiedItemCard.gd
# Last Updated: Fixed type handling for categories and rarities [Date]
#
# UnifiedItemCard handles:
# - Displaying any item type in any UI context
# - Procedural/animated item rendering
# - Ownership and equipped state badges
# - Lock state for level-restricted items
# - Responsive layout (portrait vs landscape)
#
# Flow: UnifiedItemData → UnifiedItemCard → UI Display
# Dependencies: UnifiedItemData (for item), EquipmentManager (for state), UIStyleManager (for styling)

class_name UnifiedItemCard
extends PanelContainer

# Signals
signal clicked(item: UnifiedItemData)
signal right_clicked(item: UnifiedItemData)

# Display modes
enum DisplayMode {
	INVENTORY,
	SHOP,
	PROFILE,
	SHOWCASE,
	SELECTION
}

# Layout modes based on item type
enum LayoutType {
	PORTRAIT,     # Cards, Emojis, Avatars, Frames
	LANDSCAPE     # Boards, Mini profiles
}

# Node references (from scene)
var background_texture: TextureRect
var icon_texture: TextureRect
var procedural_canvas: Control
var overlay_container: Control
var name_label: Label
var price_label: Label
var equipped_badge: TextureRect
var locked_overlay: Control

# Data
var item_data: UnifiedItemData
var display_mode: DisplayMode = DisplayMode.INVENTORY
var layout_type: LayoutType = LayoutType.PORTRAIT
var is_equipped: bool = false
var is_owned: bool = false
var is_locked: bool = false

func _ready():
	# Get references to scene nodes
	background_texture = $BackgroundTexture
	icon_texture = $IconTexture
	procedural_canvas = $ProceduralCanvas
	overlay_container = $OverlayContainer
	name_label = $OverlayContainer/NameLabel
	price_label = $OverlayContainer/PriceLabel
	equipped_badge = $OverlayContainer/EquippedBadge
	locked_overlay = $LockedOverlay
	
	# Make sure ProceduralCanvas fills the entire card
	if procedural_canvas:
		procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Setup input
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect to EquipmentManager
	if EquipmentManager:
		EquipmentManager.item_equipped.connect(_on_global_item_equipped)
		EquipmentManager.item_unequipped.connect(_on_global_item_unequipped)
		EquipmentManager.ownership_changed.connect(_on_global_ownership_changed)

func setup(item: UnifiedItemData, mode: DisplayMode = DisplayMode.INVENTORY):
	"""Configure the card with item data and display mode"""
	print("\n=== SETTING UP CARD: %s ===" % item.id)
	print("  Mode: %s" % mode)
	
	item_data = item
	display_mode = mode
	
	if not is_node_ready():
		await ready
	
	# Get references to existing scene nodes
	background_texture = $BackgroundTexture
	icon_texture = $IconTexture
	procedural_canvas = $ProceduralCanvas
	overlay_container = $OverlayContainer
	name_label = $OverlayContainer/NameLabel
	price_label = $OverlayContainer/PriceLabel
	equipped_badge = $OverlayContainer/EquippedBadge
	locked_overlay = $LockedOverlay
	
	# Determine layout type based on item category
	layout_type = _get_layout_type()
	print("  Layout: %s" % ("LANDSCAPE" if layout_type == LayoutType.LANDSCAPE else "PORTRAIT"))
	
	# Check ownership and equipped status
	is_owned = EquipmentManager.is_item_owned(item.id) if EquipmentManager else false
	is_equipped = EquipmentManager.is_item_equipped(item.id) if EquipmentManager else false
	is_locked = not is_owned and item.unlock_level > 0
	print("  Status - Owned: %s, Equipped: %s, Locked: %s" % [is_owned, is_equipped, is_locked])
	print("  Animated: %s, Procedural: %s" % [item.is_animated, item.is_procedural])
	
	if display_mode == DisplayMode.SHOP:
		var final_size = _get_card_size()
		custom_minimum_size = final_size
		size = final_size
		
		# Make sure procedural canvas doesn't expand
		if procedural_canvas:
			procedural_canvas.custom_minimum_size = final_size - Vector2(4, 4)
			procedural_canvas.size = final_size - Vector2(4, 4)
		
		print("  FORCED final size: (%s)" % final_size)
	
	# Setup the visual display
	_setup_card_size()
	_setup_panel_style()
	_setup_background()
	_setup_overlays()
	_update_equipped_badge()
	_update_lock_state()
	
	print("  Final size: %s" % size)
	print("=== SETUP COMPLETE ===\n")


func _get_layout_type() -> LayoutType:
	"""Determine layout type from item category"""
	match item_data.category:
		UnifiedItemData.Category.BOARD, UnifiedItemData.Category.MINI_PROFILE_CARD:
			return LayoutType.LANDSCAPE
		_:
			return LayoutType.PORTRAIT

func _setup_card_size():
	"""Set card size based on layout type - with proper clipping"""
	var base_size = Vector2()
	
	match layout_type:
		LayoutType.PORTRAIT:
			base_size = UIStyleManager.get_item_card_style("size_portrait")
		LayoutType.LANDSCAPE:
			base_size = UIStyleManager.get_item_card_style("size_landscape")
	
	print("  Setting size to: %s" % base_size)
	
	# Set sizes
	custom_minimum_size = base_size
	size = base_size
	
	# IMPORTANT: Enable clipping to prevent overflow
	clip_contents = true
	
	# BORDER FIX: Inset ProceduralCanvas by border width from UIStyleManager
	if procedural_canvas:
		# Get border width from UIStyleManager - fix the rarity check
		var rarity_str = item_data.get_rarity_name().to_lower()
		var border_width = UIStyleManager.get_item_card_style("card_border_width_epic") if rarity_str in ["epic", "legendary", "mythic"] else UIStyleManager.get_item_card_style("card_border_width_normal")
		
		procedural_canvas.clip_contents = true
		# Inset the canvas to not cover the border
		procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.set_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.offset_left = border_width
		procedural_canvas.offset_top = border_width
		procedural_canvas.offset_right = -border_width
		procedural_canvas.offset_bottom = -border_width
		
		print("  ProceduralCanvas inset by: %spx" % border_width)

func _setup_panel_style():
	"""Setup panel style with rarity-colored border"""
	var style = StyleBoxFlat.new()
	
	# Transparent background (let texture/procedural show through)
	style.bg_color = Color(0, 0, 0, 0)
	
	# Rarity border - use the item's helper method
	var rarity_color = item_data.get_rarity_color()
	style.border_color = rarity_color
	
	# Get border width from UIStyleManager
	var rarity_str = item_data.get_rarity_name().to_lower()
	var border_width = UIStyleManager.get_item_card_style("card_border_width_epic") if rarity_str in ["epic", "legendary", "mythic"] else UIStyleManager.get_item_card_style("card_border_width_normal")
	
	style.set_border_width_all(border_width)
	
	# No round corners (or use from UIStyleManager if you want)
	var corner_radius = UIStyleManager.get_item_card_style("corner_radius")
	style.set_corner_radius_all(0)  # Keep at 0 for sharp corners, or use corner_radius
	
	# IMPORTANT: Set content margin to prevent border from being cut off
	style.set_content_margin_all(0)
	
	add_theme_stylebox_override("panel", style)
	
	# Make sure the panel fills the entire card
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_background():
	"""Setup the background texture or procedural display"""
	
	# DEBUG: Let's see what's actually in the item
	print("DEBUG: Item %s - is_animated=%s, is_procedural=%s" % [
		item_data.id, 
		item_data.is_animated, 
		item_data.is_procedural
	])
	
	# Reset everything
	background_texture.visible = true
	background_texture.modulate = Color.WHITE
	icon_texture.visible = false
	procedural_canvas.visible = false
	
	# Check EITHER is_animated OR is_procedural (they might be using either)
	if item_data.is_animated or item_data.is_procedural:
		print("  → Item should be animated/procedural, setting up...")
		_setup_procedural_display()
		if procedural_canvas.visible:
			background_texture.visible = false
	else:
		print("  → Looking for static texture")
		var texture_loaded = _try_load_texture()
		if not texture_loaded:
			print("  → No texture, showing debug background")
	
	print("  Final state - BG visible: %s, Procedural visible: %s" % [
		background_texture.visible, 
		procedural_canvas.visible
	])

func _try_load_texture() -> bool:
	"""Load and display the item texture"""
	print("DEBUG: Trying to load texture for: ", item_data.id)
	
	# SKIP texture loading if animated!
	if item_data.is_animated:
		print("  - Item is animated, skipping texture load")
		return false
	
	var texture: Texture2D = null
	var paths_to_try = []
	
	# Add paths from item data
	if item_data.preview_texture_path != "":
		paths_to_try.append(item_data.preview_texture_path)
		print("  - Will check preview path: ", item_data.preview_texture_path)
	if item_data.texture_path != "":
		paths_to_try.append(item_data.texture_path)
		print("  - Will check texture path: ", item_data.texture_path)
	if item_data.icon_path != "":
		paths_to_try.append(item_data.icon_path)
		print("  - Will check icon path: ", item_data.icon_path)
	
	# Add fallback paths for common locations - use the item's helper method
	var category_folder = item_data.get_category_folder()
	var fallback_paths = [
		"res://Pyramids/assets/icons/%s/%s.png" % [category_folder, item_data.id],
		"res://Magic-Castle/assets/%s/%s.png" % [category_folder, item_data.id],
	]
	
	for fallback in fallback_paths:
		if not fallback in paths_to_try:
			paths_to_try.append(fallback)
			print("  - Adding fallback path: ", fallback)
	
	# Try each path
	for path in paths_to_try:
		print("  - Checking: ", path)
		if ResourceLoader.exists(path):
			print("    ✓ Path exists!")
			texture = load(path)
			if texture:
				print("    ✓ Texture loaded successfully!")
				# Display the texture
				background_texture.texture = texture
				background_texture.visible = true
				background_texture.modulate = Color.WHITE
				background_texture.self_modulate = Color.WHITE
				background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				background_texture.stretch_mode = TextureRect.STRETCH_SCALE
				return true
			else:
				print("    ✗ Failed to load texture")
		else:
			print("    ✗ Path does not exist")
	
	print("  ✗ No texture found for ", item_data.id)
	return false

func _display_texture(texture: Texture2D):
	"""Display texture based on item category"""
	# For emojis, avatars, frames - show as icon
	if item_data.category in [UnifiedItemData.Category.EMOJI, UnifiedItemData.Category.AVATAR, UnifiedItemData.Category.FRAME]:
		icon_texture.texture = texture
		icon_texture.visible = true
		# Position at top center, 60% of card height
		var icon_size = size * 0.6
		icon_texture.size = icon_size
		icon_texture.position = Vector2((size.x - icon_size.x) / 2, 10)
	else:
		# For cards and boards - fill entire background
		background_texture.texture = texture
		background_texture.visible = true

func _setup_overlays():
	"""Setup text overlays using existing scene nodes"""
	
	# Clear any existing background from previous setup
	for child in overlay_container.get_children():
		if child.name == "LabelBackground":
			child.queue_free()
	
	# Get positioning from UIStyleManager
	var slot_1_top = UIStyleManager.get_item_card_style("label_slot_1_top")
	var slot_1_bottom = UIStyleManager.get_item_card_style("label_slot_1_bottom")
	var slot_2_top = UIStyleManager.get_item_card_style("label_slot_2_top")
	var slot_2_bottom = UIStyleManager.get_item_card_style("label_slot_2_bottom")
	var font_size_name = UIStyleManager.get_item_card_style("font_size_name")
	var font_size_price = UIStyleManager.get_item_card_style("font_size_price")
	
	# Setup Name Label - ALWAYS at slot 1
	name_label.text = item_data.display_name
	name_label.visible = true
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.anchor_top = slot_1_top
	name_label.anchor_bottom = slot_1_bottom
	name_label.anchor_left = 0
	name_label.anchor_right = 1
	
	# INSET FROM BORDERS - 4px each side to prevent overlap
	name_label.offset_left = 4
	name_label.offset_right = -4
	name_label.offset_top = 0
	name_label.offset_bottom = 0
	
	# Configure name label appearance - STRONG OUTLINE for visibility
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_font_size_override("font_size", font_size_name)
	
	# Setup Price Label - ALWAYS at slot 2, visible only in shop
	if display_mode == DisplayMode.SHOP and not is_owned:
		price_label.visible = true
		# Get price from ShopManager if available, otherwise use base price
		var price = 0
		if ShopManager and ShopManager.has_method("get_item_price"):
			price = ShopManager.get_item_price(item_data.id)
		else:
			price = item_data.get_price_with_rarity_multiplier()
		price_label.text = str(price) + " ⭐"
	else:
		price_label.visible = false
	
	price_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	price_label.anchor_top = slot_2_top
	price_label.anchor_bottom = slot_2_bottom
	price_label.anchor_left = 0
	price_label.anchor_right = 1
	
	# INSET FROM BORDERS - 4px each side
	price_label.offset_left = 4
	price_label.offset_right = -4
	price_label.offset_top = 0
	price_label.offset_bottom = 0
	
	# Configure price label appearance - STRONG OUTLINE for visibility
	price_label.add_theme_color_override("font_color", Color("#FFD700"))  # Gold
	price_label.add_theme_color_override("font_outline_color", Color.BLACK)
	price_label.add_theme_constant_override("outline_size", 1)
	price_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	price_label.add_theme_constant_override("shadow_offset_x", 1)
	price_label.add_theme_constant_override("shadow_offset_y", 1)
	price_label.add_theme_font_size_override("font_size", font_size_price)

func _update_equipped_badge():
	"""Update equipped badge visual state"""
	var badge_size = UIStyleManager.get_item_card_style("equipped_badge_size")
	var badge_margin = UIStyleManager.get_item_card_style("equipped_badge_margin")
	
	equipped_badge.set_position(Vector2(badge_margin, badge_margin))
	equipped_badge.set_size(Vector2(badge_size, badge_size))
	
	# Clear previous icon drawer if exists
	for child in equipped_badge.get_children():
		if child.name == "IconDrawer":
			child.queue_free()
	
	if display_mode == DisplayMode.SHOP and not is_owned:
		equipped_badge.visible = true
		_draw_badge_icon(equipped_badge, "shop")
		equipped_badge.modulate = Color.WHITE
	elif is_equipped:
		equipped_badge.visible = true
		_draw_badge_icon(equipped_badge, "equipped")
		equipped_badge.modulate = Color.WHITE
	elif is_owned:
		equipped_badge.visible = true
		_draw_badge_icon(equipped_badge, "owned")
		equipped_badge.modulate = Color.WHITE
	else:
		equipped_badge.visible = false

func _update_lock_state():
	"""Update lock overlay using chain animation"""
	if is_locked:
		locked_overlay.visible = true
		_setup_chain_lock()
	else:
		locked_overlay.visible = false
		# Clear any existing chains
		for child in locked_overlay.get_children():
			child.queue_free()

func _setup_procedural_display():
	"""Setup procedural animation - with proper size constraints"""
	print("  Setting up procedural display...")
	
	if not item_data.is_animated and not item_data.is_procedural:
		print("    ✗ Item is not animated/procedural, skipping setup")
		return
	
	# Show procedural canvas, hide background
	procedural_canvas.visible = true
	background_texture.visible = false
	
	# Clear any previous children
	for child in procedural_canvas.get_children():
		child.queue_free()
	
	# Get the procedural instance
	var instance = null
	
	# First try to get from ItemManager's cache
	if ItemManager and ItemManager.has_method("get_procedural_instance"):
		instance = ItemManager.get_procedural_instance(item_data.id)
		if instance:
			print("    ✓ Got cached instance from ItemManager")
	
	# If not cached, try ProceduralItemRegistry directly
	if not instance and ProceduralItemRegistry:
		instance = ProceduralItemRegistry.get_procedural_item(item_data.id)
		if instance:
			print("    ✓ Got instance from ProceduralItemRegistry")
	
	# If still no instance, load the script directly
	if not instance and item_data.procedural_script_path != "":
		if ResourceLoader.exists(item_data.procedural_script_path):
			var script = load(item_data.procedural_script_path)
			instance = script.new()
			print("    ✓ Created new instance from script")
		else:
			print("    ✗ Script path doesn't exist: %s" % item_data.procedural_script_path)
	
	if not instance:
		print("    ✗ Could not get procedural instance!")
		procedural_canvas.visible = false
		return
	
	# Create a Control to draw on
	var draw_canvas = Control.new()
	draw_canvas.name = "DrawCanvas"
	draw_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_canvas.clip_contents = true
	
	procedural_canvas.add_child(draw_canvas)
	
	# Setup the draw callback based on item type
	draw_canvas.draw.connect(func():
		var canvas_size = draw_canvas.size
		if instance.has_method("draw_card_back"):
			instance.draw_card_back(draw_canvas, canvas_size)
		elif instance.has_method("draw_board_background"):
			instance.draw_board_background(draw_canvas, canvas_size)
		elif instance.has_method("draw_card_front"):
			# For card fronts, draw with example rank/suit
			instance.draw_card_front(draw_canvas, canvas_size, "A", 0)
		elif instance.has_method("draw_item"):
			instance.draw_item(draw_canvas, canvas_size)
	)
	
	# Setup animation if needed
	if instance.get("is_animated") and instance.is_animated:
		print("    Setting up animation...")
		var tween = create_tween()
		tween.set_loops()
		
		var duration = instance.get("animation_duration") if instance.get("animation_duration") else 2.0
		
		tween.tween_method(
			func(phase: float): 
				instance.animation_phase = phase
				draw_canvas.queue_redraw(),
			0.0, 
			1.0, 
			duration
		)
		print("    ✓ Animation tween created with duration: %s" % duration)
	
	draw_canvas.queue_redraw()
	print("    ✓ Procedural display setup complete")
	
func _on_gui_input(event: InputEvent):
	"""Handle input - only process clicks if not locked"""
	if event is InputEventMouseButton and event.pressed:
		print("UnifiedItemCard: Click detected on %s" % item_data.id)  # Debug
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Don't process if locked
			if is_locked:
				print("  Item is locked")
				return
			
			# Emit click for all cases (except locked)
			print("  Emitting clicked signal")
			clicked.emit(item_data)

# Equipment change handlers
func _on_global_item_equipped(item_id: String, category: String):
	if item_data and item_data.id == item_id:
		is_equipped = true
		_update_equipped_badge()

func _on_global_item_unequipped(item_id: String, category: String):
	if item_data and item_data.id == item_id:
		is_equipped = false
		_update_equipped_badge()

func _on_global_ownership_changed(item_id: String, owned: bool):
	if item_data and item_data.id == item_id:
		is_owned = owned
		is_locked = not owned and item_data.unlock_level > 0
		_update_equipped_badge()
		_update_lock_state()

func _draw_badge_icon(badge_node: TextureRect, badge_type: String):
	"""Draw procedural badge icons"""
	var badge_size = UIStyleManager.get_item_card_style("equipped_badge_size")
	
	# Clear previous icon drawer if exists
	for child in badge_node.get_children():
		if child.name == "IconDrawer":
			child.queue_free()
	
	# Create a custom draw control
	var icon_drawer = Control.new()
	icon_drawer.name = "IconDrawer"
	icon_drawer.size = Vector2(badge_size, badge_size)
	icon_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	badge_node.add_child(icon_drawer)
	
	icon_drawer.draw.connect(func():
		var size = icon_drawer.size
		var center = size / 2
		
		match badge_type:
			"equipped":  # Box with checkmark
				# Draw box
				var box_size = size * 0.7
				var box_rect = Rect2((size - box_size) / 2, box_size)
				icon_drawer.draw_rect(box_rect, Color.WHITE, false, 2.0)
				
				# Draw checkmark
				var check_points = PackedVector2Array([
					Vector2(size.x * 0.25, size.y * 0.5),
					Vector2(size.x * 0.4, size.y * 0.65),
					Vector2(size.x * 0.75, size.y * 0.3)
				])
				icon_drawer.draw_polyline(check_points, Color.GREEN, 2.0)
				
			"owned":  # Empty box
				# Draw box with white color and thicker line
				var box_size = size * 0.7
				var box_rect = Rect2((size - box_size) / 2, box_size)
				icon_drawer.draw_rect(box_rect, Color.WHITE, false, 2.0)
				# Add a slight fill to make it more visible
				var inner_rect = Rect2(box_rect.position + Vector2(2, 2), box_rect.size - Vector2(4, 4))
				icon_drawer.draw_rect(inner_rect, Color(1, 1, 1, 0.1), true)
				
			"shop":  # Price tag shape
				# Draw tag body (rectangle)
				var tag_width = size.x * 0.7
				var tag_height = size.y * 0.5
				var tag_rect = Rect2(size.x * 0.15, size.y * 0.25, tag_width, tag_height)
				icon_drawer.draw_rect(tag_rect, Color("#FFD700"), true)
				
				# Draw triangle cutout on right
				var triangle_points = PackedVector2Array([
					Vector2(tag_rect.position.x + tag_width, tag_rect.position.y),
					Vector2(size.x * 0.95, center.y),
					Vector2(tag_rect.position.x + tag_width, tag_rect.position.y + tag_height)
				])
				icon_drawer.draw_colored_polygon(triangle_points, Color("#FFD700"))
				
				# Draw hole for string
				icon_drawer.draw_circle(Vector2(size.x * 0.88, center.y), 2, Color.BLACK)
	)
	
	icon_drawer.queue_redraw()

func _setup_chain_lock():
	"""Create animated chain lock overlay"""
	# Clear any existing children
	for child in locked_overlay.get_children():
		child.queue_free()
	
	# Create dark overlay background
	var dark_overlay = ColorRect.new()
	dark_overlay.name = "DarkOverlay"
	dark_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark_overlay.color = Color(0, 0, 0, 0.6)  # Dark semi-transparent
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_overlay.add_child(dark_overlay)
	
	# Create chain drawer
	var chain_drawer = Control.new()
	chain_drawer.name = "ChainDrawer"
	chain_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chain_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_overlay.add_child(chain_drawer)
	
	# Draw the chains
	chain_drawer.draw.connect(func():
		_draw_chains(chain_drawer)
	)
	
	# Animate chains sliding in
	_animate_chains_entrance(locked_overlay)
	
	chain_drawer.queue_redraw()

func _draw_chains(drawer: Control):
	"""Draw the X pattern of chains"""
	var card_size = drawer.size
	
	# Chain properties
	var link_width = 8.0
	var link_height = 12.0
	var link_spacing = 2.0
	
	# Colors
	var chain_color = Color(0.7, 0.7, 0.7, 1.0)  # Silver/gray
	var chain_shadow = Color(0.2, 0.2, 0.2, 0.8)  # Dark shadow
	var chain_highlight = Color(0.9, 0.9, 0.9, 1.0)  # Light highlight
	
	# Draw two diagonal chains (X pattern)
	# Chain 1: Top-left to bottom-right
	_draw_chain_line(drawer, Vector2(0, 0), Vector2(card_size.x, card_size.y), 
					link_width, link_height, link_spacing, 
					chain_color, chain_shadow, chain_highlight)
	
	# Chain 2: Top-right to bottom-left  
	_draw_chain_line(drawer, Vector2(card_size.x, 0), Vector2(0, card_size.y),
					link_width, link_height, link_spacing,
					chain_color, chain_shadow, chain_highlight)
	
	# Draw padlock at center intersection
	_draw_padlock(drawer, card_size / 2, 20)

func _draw_chain_line(drawer: Control, start: Vector2, end: Vector2, 
					link_width: float, link_height: float, spacing: float,
					color: Color, shadow_color: Color, highlight_color: Color):
	"""Draw a single chain line made of oval links"""
	var direction = (end - start).normalized()
	var angle = direction.angle()
	var total_length = start.distance_to(end)
	var link_total = link_height + spacing
	var num_links = int(total_length / link_total)
	
	for i in range(num_links):
		var link_pos = start + direction * (i * link_total)
		
		# Draw link shadow (offset slightly)
		_draw_chain_link(drawer, link_pos + Vector2(1, 1), link_width, link_height, 
						angle, shadow_color, true)
		
		# Draw main link
		_draw_chain_link(drawer, link_pos, link_width, link_height, 
						angle, color, false)
		
		# Draw highlight on top edge
		_draw_chain_link_highlight(drawer, link_pos, link_width, link_height,
								angle, highlight_color)

func _draw_chain_link(drawer: Control, pos: Vector2, width: float, height: float, 
					angle: float, color: Color, is_shadow: bool):
	"""Draw a single oval chain link"""
	var points = 16  # Number of points for oval
	var oval_points = PackedVector2Array()
	
	for i in range(points + 1):
		var theta = (i / float(points)) * TAU
		var x = cos(theta) * width / 2
		var y = sin(theta) * height / 2
		
		# Rotate point by chain angle
		var rotated = Vector2(x, y).rotated(angle)
		oval_points.append(pos + rotated)
	
	# Draw oval outline (thick for chain effect)
	if not is_shadow:
		drawer.draw_polyline(oval_points, color, 2.0, true)
	else:
		drawer.draw_polyline(oval_points, color, 2.5, true)

func _draw_chain_link_highlight(drawer: Control, pos: Vector2, width: float, height: float,
							angle: float, color: Color):
	"""Draw highlight on chain link for 3D effect"""
	var points = 8  # Fewer points for highlight arc
	var highlight_points = PackedVector2Array()
	
	# Only draw top half of oval for highlight
	for i in range(points):
		var theta = (i / float(points - 1)) * PI - PI/2  # Top half only
		var x = cos(theta) * width / 2.5  # Slightly smaller
		var y = sin(theta) * height / 2.5
		
		var rotated = Vector2(x, y).rotated(angle)
		highlight_points.append(pos + rotated)
	
	drawer.draw_polyline(highlight_points, color, 1.0, true)

func _draw_padlock(drawer: Control, pos: Vector2, size: float):
	"""Draw a padlock at the chain intersection"""
	# Padlock body
	var body_rect = Rect2(pos.x - size/2, pos.y - size/3, size, size * 0.8)
	drawer.draw_rect(body_rect, Color(0.5, 0.5, 0.5, 1.0), true)
	drawer.draw_rect(body_rect, Color(0.3, 0.3, 0.3, 1.0), false, 2.0)
	
	# Padlock shackle (the loop part)
	var shackle_points = PackedVector2Array()
	var shackle_radius = size * 0.35
	
	# Create shackle arc
	for i in range(11):
		var angle = PI + (i / 10.0) * PI  # Semi-circle from PI to 2*PI
		var point = pos + Vector2(cos(angle), sin(angle)) * shackle_radius
		point.y -= size * 0.2  # Move up to connect with body
		shackle_points.append(point)
	
	drawer.draw_polyline(shackle_points, Color(0.4, 0.4, 0.4, 1.0), 3.0)
	
	# Keyhole
	drawer.draw_circle(pos + Vector2(0, size * 0.1), 3, Color(0.2, 0.2, 0.2, 1.0))

func _animate_chains_entrance(container: Control):
	"""Animate chains sliding in from corners"""
	# Start with chains offset
	container.modulate.a = 0.0
	container.scale = Vector2(1.2, 1.2)
	
	# Animate in
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	tween.tween_property(container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Add subtle pulse animation after entrance
	tween.chain().set_loops()
	tween.tween_property(container, "modulate:a", 0.9, 1.0)
	tween.tween_property(container, "modulate:a", 1.0, 1.0)

func _get_card_size() -> Vector2:
	"""Get the appropriate size based on item category and display mode"""
	var is_landscape = item_data and item_data.category == UnifiedItemData.Category.BOARD
	
	match display_mode:
		DisplayMode.SHOP:
			return Vector2(192, 126) if is_landscape else Vector2(90, 126)
		DisplayMode.INVENTORY:
			return Vector2(192, 126) if is_landscape else Vector2(90, 126)
		DisplayMode.SHOWCASE:
			return Vector2(120, 80) if is_landscape else Vector2(60, 80)
		_:
			return Vector2(90, 126)
