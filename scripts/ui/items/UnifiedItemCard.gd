# UnifiedItemCard.gd - Universal item card for ALL UI displays
# Location: res://Pyramids/scripts/ui/UnifiedItemCard.gd
# Last Updated: Removed AnimationPlayer, cleaned debug output, Tween-only animations

class_name UnifiedItemCard
extends PanelContainer

# === SIGNALS ===
signal clicked(item: UnifiedItemData)
signal right_clicked(item: UnifiedItemData)
signal expanded_view_requested()

# === ENUMS ===
enum DisplayMode {
	INVENTORY,
	SHOP,
	PROFILE,
	SHOWCASE,
	SELECTION
}

enum LayoutType {
	PORTRAIT,     # Cards, Emojis, Avatars, Frames
	LANDSCAPE     # Boards, Mini profiles
}

enum SizePreset {
	MINI_DISPLAY,    # 44x44 in 50x50 (MiniProfileCard display items)
	PASS_REWARD,     # 80x80 in 86x86 (Battle pass rewards)
	INVENTORY,       # 90x126 (existing)
	SHOP,           # 192x126 (existing)
	SHOWCASE        # 60x80 (existing)
}

# === NODE REFERENCES ===
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var icon_texture: TextureRect = $IconTexture
@onready var procedural_canvas: Control = $ProceduralCanvas
@onready var overlay_container: Control = $OverlayContainer
@onready var name_label: Label = $OverlayContainer/NameLabel
@onready var price_label: Label = $OverlayContainer/PriceLabel
@onready var equipped_badge: TextureRect = $OverlayContainer/EquippedBadge
@onready var locked_overlay: Control = $LockedOverlay
@onready var shadow_layer: Control = null  # Created dynamically

# === PROPERTIES ===
var item_data: UnifiedItemData = null  # Can be null for raw rewards
var reward_data: Dictionary = {}  # For raw reward dictionaries
var display_mode: DisplayMode = DisplayMode.INVENTORY
var layout_type: LayoutType = LayoutType.PORTRAIT
var size_preset: SizePreset = SizePreset.INVENTORY
var is_equipped: bool = false
var is_owned: bool = false
var is_locked: bool = false
var is_claimable: bool = false  # For animation control
var is_claimed: bool = false    # For dimming

# Animation properties
var animation_enabled: bool = false  # State-based animation
var animation_timer: float = 0.0
var animation_interval: float = 5.0  # Time between animations

# Popup for expanded view
var expanded_popup_scene = preload("res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn") if ResourceLoader.exists("res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn") else null

# === LIFECYCLE ===

func _ready():
	# Enable processing for animations
	set_process(true)
	
	# Create shadow layer
	_create_shadow_layer()
	
	# Configure procedural canvas
	if procedural_canvas:
		procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Ensure it has no background color
		if procedural_canvas is ColorRect:
			procedural_canvas.color = Color(0, 0, 0, 0)
	
	# Hide background texture if this is a small preset (might be set before ready)
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		if background_texture:
			background_texture.visible = false
			background_texture.self_modulate = Color(1, 1, 1, 0)
	
	# Setup input
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect to EquipmentManager
	if EquipmentManager:
		EquipmentManager.item_equipped.connect(_on_global_item_equipped)
		EquipmentManager.item_unequipped.connect(_on_global_item_unequipped)
		EquipmentManager.ownership_changed.connect(_on_global_ownership_changed)

func _process(delta):
	"""Handle animation timing"""
	if not animation_enabled:
		return
	
	if is_locked or is_claimed:
		return
	
	# For rewards, start animation immediately if not already running
	if reward_data.size() > 0 and is_claimable:
		if not has_meta("float_tween") or not get_meta("float_tween"):
			_play_animation()
	else:
		# Original timing logic for non-rewards (if any)
		animation_timer += delta
		if animation_timer >= animation_interval:
			animation_timer = 0.0
			_play_animation()

# === PUBLIC INTERFACE ===

func setup(item: UnifiedItemData, mode: DisplayMode = DisplayMode.INVENTORY):
	"""Configure the card with item data and display mode"""
	item_data = item
	reward_data = {}  # Clear reward data
	display_mode = mode
	
	# Store the preset if it was already set (for size_before_setup case)
	var preset_override = size_preset
	
	# Apply size based on display mode (default behavior)
	if display_mode == DisplayMode.SHOP:
		size_preset = SizePreset.SHOP
	elif display_mode == DisplayMode.INVENTORY:
		size_preset = SizePreset.INVENTORY
	elif display_mode == DisplayMode.SHOWCASE:
		size_preset = SizePreset.SHOWCASE
	elif display_mode == DisplayMode.PROFILE:
		size_preset = SizePreset.SHOWCASE  
	elif display_mode == DisplayMode.SELECTION:
		size_preset = SizePreset.INVENTORY
	
	# If preset was set before setup, restore it
	if preset_override != SizePreset.INVENTORY:  # INVENTORY is the default
		size_preset = preset_override
	
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
	
	# Check ownership and equipped status
	is_owned = EquipmentManager.is_item_owned(item.id) if EquipmentManager else false
	is_equipped = EquipmentManager.is_item_equipped(item.id) if EquipmentManager else false
	is_locked = not is_owned and item.unlock_level > 0
	
	# Apply the size preset BEFORE setting up display
	_apply_size_preset()
	
	# Setup the visual display
	_setup_panel_style()
	_setup_background()  # This calls _setup_procedural_display if needed
	_setup_overlays()
	_update_equipped_badge()
	_update_lock_state()
	_update_animation_state()
	
	# Regular items should NOT animate (only rewards animate)
	animation_enabled = false
	set_process(false)

func setup_from_dict(reward_dict: Dictionary, preset: SizePreset):
	"""Configure the card with raw reward dictionary (for battle pass)"""
	reward_data = reward_dict
	item_data = null  # Clear item data
	size_preset = preset
	
	if not is_node_ready():
		await ready
	
	# Re-get references
	background_texture = $BackgroundTexture
	icon_texture = $IconTexture
	procedural_canvas = $ProceduralCanvas
	overlay_container = $OverlayContainer
	name_label = $OverlayContainer/NameLabel
	price_label = $OverlayContainer/PriceLabel
	equipped_badge = $OverlayContainer/EquippedBadge
	locked_overlay = $LockedOverlay
	
	# Apply size preset
	_apply_size_preset()
	
	# Setup panel style (no rarity for rewards)
	_setup_reward_panel_style()
	
	# Setup reward display
	_setup_reward_display()
	
	# No equipped badge for rewards
	if equipped_badge:
		equipped_badge.visible = false
	
	# Update animation based on state
	_update_animation_state()

func set_reward_state(unlocked: bool, claimed: bool):
	"""Set the state for reward items (controls animation and appearance)"""
	is_locked = not unlocked
	is_claimed = claimed
	is_claimable = unlocked and not claimed
	
	# Only animate if claimable
	animation_enabled = is_claimable
	
	# Ensure processing is enabled for animations
	if animation_enabled:
		set_process(true)
	else:
		set_process(false)  # Stop processing if not animating
	
	# Update visual state
	_update_lock_state()
	
	# Dim if claimed
	if is_claimed:
		modulate.a = 0.5
		if shadow_layer:
			shadow_layer.visible = false
	else:
		modulate.a = 1.0
		if shadow_layer and is_claimable:
			shadow_layer.visible = true

func setup_with_preset(item: UnifiedItemData, preset: SizePreset):
	"""Configure with UnifiedItemData and size preset"""
	size_preset = preset
	setup(item, DisplayMode.SHOWCASE)

# === CORE FUNCTIONALITY ===

func _get_layout_type() -> LayoutType:
	"""Determine layout type from item category"""
	if not item_data:
		# For rewards, determine from size preset
		if size_preset == SizePreset.PASS_REWARD:
			return LayoutType.PORTRAIT
		return LayoutType.PORTRAIT
	
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
	
	# Set sizes
	custom_minimum_size = base_size
	size = base_size
	
	# Enable clipping to prevent overflow
	clip_contents = true
	
	# Inset ProceduralCanvas by border width
	if procedural_canvas:
		var rarity_str = item_data.get_rarity_name().to_lower() if item_data else "common"
		var border_width = UIStyleManager.get_item_card_style("card_border_width_epic") if rarity_str in ["epic", "legendary", "mythic"] else UIStyleManager.get_item_card_style("card_border_width_normal")
		
		procedural_canvas.clip_contents = true
		procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.set_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.offset_left = border_width
		procedural_canvas.offset_top = border_width
		procedural_canvas.offset_right = -border_width
		procedural_canvas.offset_bottom = -border_width

func _apply_size_preset():
	"""Apply size based on preset"""
	var target_size = Vector2()
	
	match size_preset:
		SizePreset.MINI_DISPLAY:
			target_size = Vector2(50, 50)
		SizePreset.PASS_REWARD:
			target_size = Vector2(86, 86)
		SizePreset.INVENTORY:
			target_size = Vector2(90, 126)
		SizePreset.SHOP:
			target_size = Vector2(192, 126) if layout_type == LayoutType.LANDSCAPE else Vector2(90, 126)
		SizePreset.SHOWCASE:
			target_size = Vector2(60, 80)
	
	custom_minimum_size = target_size
	size = target_size
	clip_contents = true
	
	# Update procedural canvas size if it exists
	if procedural_canvas:
		procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Check for scale container (mini/pass/showcase displays)
		var scale_container = procedural_canvas.get_node_or_null("ScaleContainer")
		if scale_container:
			# Handle scaled procedural displays
			var draw_canvas = scale_container.get_node_or_null("DrawCanvas")
			if draw_canvas:
				# Get border width for padding
				var border_width = _get_border_width()
				var padding = border_width + 2
				
				# Determine target area with padding
				var padded_target = target_size - Vector2(padding * 2, padding * 2)
				
				# Further reduce for small presets
				match size_preset:
					SizePreset.MINI_DISPLAY:
						padded_target = Vector2(40, 40)
					SizePreset.PASS_REWARD:
						padded_target = Vector2(78, 78)
					SizePreset.SHOWCASE:
						padded_target = Vector2(52, 72)
				
				# Recalculate scale
				var full_size = draw_canvas.size
				var scale_x = padded_target.x / full_size.x
				var scale_y = padded_target.y / full_size.y
				var uniform_scale = min(scale_x, scale_y)
				
				draw_canvas.scale = Vector2(uniform_scale, uniform_scale)
				
				# Re-center
				var scaled_size = full_size * uniform_scale
				var offset = (target_size - scaled_size) / 2
				draw_canvas.position = offset
				
				# Update shadow if it exists
				var shadow_layer_node = procedural_canvas.get_node_or_null("ShadowLayer")
				if shadow_layer_node:
					shadow_layer_node.queue_redraw()
				
				draw_canvas.queue_redraw()
		else:
			# Check for padding container (full-size procedural)
			var padding_container = procedural_canvas.get_node_or_null("PaddingContainer")
			if padding_container:
				# This is for full-size displays - just ensure it's properly sized
				padding_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				var border_width = _get_border_width()
				padding_container.offset_left = border_width
				padding_container.offset_top = border_width
				padding_container.offset_right = -border_width
				padding_container.offset_bottom = -border_width
				
				# Check if DrawCanvas needs redraw
				var draw_canvas = padding_container.get_node_or_null("DrawCanvas")
				if draw_canvas:
					draw_canvas.queue_redraw()
	
	# Update shadow position based on size
	if shadow_layer:
		_update_shadow_position()

func _setup_panel_style():
	"""Setup panel style with rarity-colored border"""
	var style = StyleBoxFlat.new()
	
	# FULLY TRANSPARENT background for small presets
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		style.bg_color = Color(0, 0, 0, 0)  # Fully transparent
		# Also ensure the panel itself is transparent
		self.self_modulate = Color(1, 1, 1, 1)  # Keep normal modulation
		self.modulate = Color(1, 1, 1, 1)  # Keep normal modulation
	else:
		style.bg_color = Color(0, 0, 0, 0)  # Already transparent
	
	# Rarity border
	if item_data:
		var rarity_color = item_data.get_rarity_color()
		style.border_color = rarity_color
		
		# Border width
		var rarity_str = item_data.get_rarity_name().to_lower()
		var border_width = UIStyleManager.get_item_card_style("card_border_width_epic") if rarity_str in ["epic", "legendary", "mythic"] else UIStyleManager.get_item_card_style("card_border_width_normal")
		
		style.set_border_width_all(border_width)
	else:
		# Default border for rewards
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)
		style.set_border_width_all(1)
	
	style.set_corner_radius_all(0)
	style.set_content_margin_all(0)
	
	add_theme_stylebox_override("panel", style)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_reward_panel_style():
	"""Setup panel style for rewards - matches item style with colored border"""
	var style = StyleBoxFlat.new()
	
	# Transparent background like items
	style.bg_color = Color(0, 0, 0, 0)
	
	# Determine border color based on reward value/type
	var border_color = Color(0.3, 0.3, 0.3, 0.5)  # Default gray
	var border_width = 2
	
	# Color based on reward type/value
	if reward_data.has("stars"):
		var stars = reward_data.stars
		if stars >= 1000:
			border_color = Color("#FFD700")  # Legendary gold
			border_width = 3
		elif stars >= 500:
			border_color = Color("#9B59B6")  # Epic purple
			border_width = 3
		elif stars >= 250:
			border_color = Color("#3498DB")  # Rare blue
		else:
			border_color = Color("#2ECC71")  # Common green
	elif reward_data.has("xp"):
		border_color = Color("#2ECC71")  # Green for XP
	elif reward_data.has("cosmetic_type"):
		border_color = Color("#9B59B6")  # Purple for cosmetics
		border_width = 3
	
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)  # Square corners like items
	style.set_content_margin_all(0)
	
	add_theme_stylebox_override("panel", style)

func _setup_background():
	"""Setup the background texture or procedural display"""
	if not item_data:
		return  # Skip for rewards
	
	# For small presets, hide ALL backgrounds
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		background_texture.visible = false
		background_texture.self_modulate = Color(1, 1, 1, 0)  # Make invisible
		icon_texture.visible = false
		procedural_canvas.visible = false
		
		# Then setup procedural if needed
		if item_data.is_animated or item_data.is_procedural:
			_setup_scaled_procedural_display()
			if procedural_canvas.visible:
				background_texture.visible = false  # Ensure it stays hidden
		return
	
	# Normal setup for full-size cards
	background_texture.visible = true
	background_texture.modulate = Color.WHITE
	icon_texture.visible = false
	procedural_canvas.visible = false
	
	# Check for animated/procedural
	if item_data.is_animated or item_data.is_procedural:
		_setup_procedural_display()
		if procedural_canvas.visible:
			background_texture.visible = false
	else:
		var texture_loaded = _try_load_texture()
		if not texture_loaded:
			pass  # Show default background

func _try_load_texture() -> bool:
	"""Load and display the item texture"""
	if not item_data:
		return false
	
	# Skip texture loading if animated
	if item_data.is_animated:
		return false
	
	var texture: Texture2D = null
	var paths_to_try = []
	
	# Add paths from item data
	if item_data.preview_texture_path != "":
		paths_to_try.append(item_data.preview_texture_path)
	if item_data.texture_path != "":
		paths_to_try.append(item_data.texture_path)
	if item_data.icon_path != "":
		paths_to_try.append(item_data.icon_path)
	
	# Add fallback paths
	var category_folder = item_data.get_category_folder()
	var fallback_paths = [
		"res://Pyramids/assets/icons/%s/%s.png" % [category_folder, item_data.id],
		"res://Magic-Castle/assets/%s/%s.png" % [category_folder, item_data.id],
	]
	
	for fallback in fallback_paths:
		if not fallback in paths_to_try:
			paths_to_try.append(fallback)
	
	# Try each path
	for path in paths_to_try:
		if ResourceLoader.exists(path):
			texture = load(path)
			if texture:
				background_texture.texture = texture
				background_texture.visible = true
				background_texture.modulate = Color.WHITE
				background_texture.self_modulate = Color.WHITE
				background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				background_texture.stretch_mode = TextureRect.STRETCH_SCALE
				return true
	
	return false

func _setup_overlays():
	"""Setup text overlays using existing scene nodes"""
	if not item_data:
		return  # Skip for rewards
	
	# For small presets - hide EVERYTHING (text and badges)
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD, SizePreset.SHOWCASE]:
		name_label.visible = false
		price_label.visible = false
		equipped_badge.visible = false  # Also hide badge for small cards
		return
	
	# Below here is only for INVENTORY and SHOP presets (full size cards)
	
	# Get positioning from UIStyleManager
	var slot_1_top = UIStyleManager.get_item_card_style("label_slot_1_top")
	var slot_1_bottom = UIStyleManager.get_item_card_style("label_slot_1_bottom")
	var slot_2_top = UIStyleManager.get_item_card_style("label_slot_2_top")
	var slot_2_bottom = UIStyleManager.get_item_card_style("label_slot_2_bottom")
	var font_size_name = UIStyleManager.get_item_card_style("font_size_name")
	var font_size_price = UIStyleManager.get_item_card_style("font_size_price")
	
	# Setup Name Label
	name_label.text = item_data.display_name
	name_label.visible = true
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.anchor_top = slot_1_top
	name_label.anchor_bottom = slot_1_bottom
	name_label.anchor_left = 0
	name_label.anchor_right = 1
	
	# Inset from borders
	name_label.offset_left = 4
	name_label.offset_right = -4
	name_label.offset_top = 0
	name_label.offset_bottom = 0
	
	# Configure appearance
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_font_size_override("font_size", font_size_name)
	
	# Setup Price Label
	if display_mode == DisplayMode.SHOP and not is_owned:
		price_label.visible = true
		var price = 0
		if ShopManager and ShopManager.has_method("get_item_price"):
			price = ShopManager.get_item_price(item_data.id)
		else:
			price = item_data.get_price_with_rarity_multiplier()
		
		# Make sure price is valid
		if price <= 0:
			price = item_data.base_price if item_data.base_price > 0 else 100
		
		price_label.text = str(price) + " ⭐"
	else:
		price_label.visible = false
	
	price_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	price_label.anchor_top = slot_2_top
	price_label.anchor_bottom = slot_2_bottom
	price_label.anchor_left = 0
	price_label.anchor_right = 1
	
	# Inset from borders
	price_label.offset_left = 4
	price_label.offset_right = -4
	price_label.offset_top = 0
	price_label.offset_bottom = 0
	
	# Configure appearance
	price_label.add_theme_color_override("font_color", Color("#FFD700"))
	price_label.add_theme_color_override("font_outline_color", Color.BLACK)
	price_label.add_theme_constant_override("outline_size", 1)
	price_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	price_label.add_theme_constant_override("shadow_offset_x", 1)
	price_label.add_theme_constant_override("shadow_offset_y", 1)
	price_label.add_theme_font_size_override("font_size", font_size_price)

func _update_equipped_badge():
	"""Update equipped badge visual state"""
	if reward_data.size() > 0:
		equipped_badge.visible = false  # No badge for rewards
		return
		
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD, SizePreset.SHOWCASE]:
		equipped_badge.visible = false
		return
	
	var badge_size = UIStyleManager.get_item_card_style("equipped_badge_size")
	var badge_margin = UIStyleManager.get_item_card_style("equipped_badge_margin")
	
	equipped_badge.set_position(Vector2(badge_margin, badge_margin))
	equipped_badge.set_size(Vector2(badge_size, badge_size))
	
	# Clear previous icon drawer
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
	if not locked_overlay:
		# For reward cards, locked_overlay might not exist in scene
		# Create it dynamically if needed
		if is_locked and not has_node("LockedOverlay"):
			locked_overlay = Control.new()
			locked_overlay.name = "LockedOverlay"
			locked_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			locked_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(locked_overlay)
		elif not is_locked:
			return  # Nothing to do if not locked and no overlay
		else:
			locked_overlay = get_node_or_null("LockedOverlay")
			if not locked_overlay:
				return
	
	if is_locked:
		locked_overlay.visible = true
		_setup_chain_lock()
	else:
		locked_overlay.visible = false
		for child in locked_overlay.get_children():
			child.queue_free()

# CRITICAL FIX for _setup_procedural_display in UnifiedItemCard.gd
# This ensures DrawCanvas is ALWAYS created for procedural items

func _setup_procedural_display():
	"""Setup procedural animation - WITH BORDER PADDING"""
	if not item_data:
		return
	
	if not item_data.is_animated and not item_data.is_procedural:
		return
	
	print("[PROCEDURAL] Setting up for: %s" % item_data.id)
	
	# Show procedural canvas, hide background
	procedural_canvas.visible = true
	background_texture.visible = false
	
	# Clear any previous children SYNCHRONOUSLY
	for child in procedural_canvas.get_children():
		procedural_canvas.remove_child(child)
		child.queue_free()
	
	# Get the procedural instance
	var instance = null
	
	# Try loading the script directly FIRST (most reliable)
	if item_data.procedural_script_path != "":
		print("[PROCEDURAL] Loading script: %s" % item_data.procedural_script_path)
		if ResourceLoader.exists(item_data.procedural_script_path):
			var script = load(item_data.procedural_script_path)
			if script:
				instance = script.new()
				print("[PROCEDURAL] Instance created from script")
	
	# Fallback to other methods if direct load failed
	if not instance and ItemManager and ItemManager.has_method("get_procedural_instance"):
		instance = ItemManager.get_procedural_instance(item_data.id)
		if instance:
			print("[PROCEDURAL] Got instance from ItemManager")
	
	if not instance and ProceduralItemRegistry:
		instance = ProceduralItemRegistry.get_procedural_item(item_data.id)
		if instance:
			print("[PROCEDURAL] Got instance from Registry")
	
	if not instance:
		print("[ERROR] Failed to create procedural instance for: %s" % item_data.id)
		procedural_canvas.visible = false
		background_texture.visible = true
		return
	
	# CREATE CONTAINER for border padding (for full-size items)
	var padding_container = Control.new()
	padding_container.name = "PaddingContainer"
	padding_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padding_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Apply padding based on border width
	var border_width = _get_border_width()
	padding_container.set_offsets_preset(Control.PRESET_FULL_RECT)
	padding_container.offset_left = border_width
	padding_container.offset_top = border_width
	padding_container.offset_right = -border_width
	padding_container.offset_bottom = -border_width
	
	procedural_canvas.add_child(padding_container)
	
	# CREATE DRAWCANVAS inside padding container
	var draw_canvas = Control.new()
	draw_canvas.name = "DrawCanvas"
	draw_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_canvas.clip_contents = true
	
	# Add to padding container instead of directly to procedural_canvas
	padding_container.add_child(draw_canvas)
	
	await get_tree().process_frame  # Let it enter tree first
	draw_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	print("[PROCEDURAL] DrawCanvas created with size: %s (with %spx border padding)" % [draw_canvas.size, border_width])
	
	# Setup the draw callback with proper method selection
	draw_canvas.draw.connect(func():
		var canvas_size = draw_canvas.size
		if canvas_size.x <= 0 or canvas_size.y <= 0:
			canvas_size = padding_container.size  # Fallback to container size
			if canvas_size.x <= 0 or canvas_size.y <= 0:
				return  # Can't draw with invalid size
		
		# Call the appropriate draw method based on category
		match item_data.category:
			UnifiedItemData.Category.CARD_BACK:
				if instance.has_method("draw_card_back"):
					instance.draw_card_back(draw_canvas, canvas_size)
			UnifiedItemData.Category.CARD_FRONT:
				if instance.has_method("draw_card_front"):
					instance.draw_card_front(draw_canvas, canvas_size, "A", 0)
			UnifiedItemData.Category.BOARD:
				if instance.has_method("draw_board_background"):
					instance.draw_board_background(draw_canvas, canvas_size)
			_:
				if instance.has_method("draw_item"):
					instance.draw_item(draw_canvas, canvas_size)
	)
	
	# Setup animation if needed
	if instance.get("is_animated") and instance.is_animated:
		var tween = create_tween()
		tween.set_loops()
		
		var duration = 2.0
		if "animation_duration" in instance:
			duration = instance.animation_duration
		
		tween.tween_method(
			func(phase: float): 
				instance.animation_phase = phase
				draw_canvas.queue_redraw(),
			0.0, 
			1.0, 
			duration
		)
	
	# Force initial draw
	draw_canvas.queue_redraw()
	
	print("[PROCEDURAL] Setup complete. ProceduralCanvas children: %d" % procedural_canvas.get_child_count())

func _setup_scaled_procedural_display():
	"""Setup procedural display with scaling for small sizes - WITH VISIBLE SHADOWS"""
	if not item_data or not item_data.is_procedural:
		return
	
	print("[SCALED] Setting up scaled display for: %s at size %s" % [item_data.id, size])
	
	# Determine if we need scaling (for small presets)
	var needs_scaling = size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD, SizePreset.SHOWCASE]
	
	if not needs_scaling:
		# Use normal procedural display for full-size cards
		_setup_procedural_display()
		return
	
	# ENSURE ALL BACKGROUNDS ARE HIDDEN
	if background_texture:
		background_texture.visible = false
		background_texture.texture = null  # Clear any default texture
		background_texture.self_modulate = Color(1, 1, 1, 0)
	
	# Clear and setup procedural canvas
	procedural_canvas.visible = true
	procedural_canvas.self_modulate = Color(1, 1, 1, 1)  # No transparency on the canvas itself
	
	# Clear the procedural canvas background color if it has one
	if procedural_canvas.has_method("set_default_color"):
		procedural_canvas.set_default_color(Color(0, 0, 0, 0))
	
	for child in procedural_canvas.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get the procedural instance
	var instance = null
	
	if item_data.procedural_script_path != "":
		if ResourceLoader.exists(item_data.procedural_script_path):
			var script = load(item_data.procedural_script_path)
			if script:
				instance = script.new()
	
	if not instance:
		print("[SCALED] Failed to create procedural instance")
		procedural_canvas.visible = false
		background_texture.visible = true
		return
	
	# DETERMINE FULL SIZE based on item type
	var full_size = Vector2()
	var is_landscape = item_data.category == UnifiedItemData.Category.BOARD
	
	if is_landscape:
		full_size = Vector2(192, 126)  # Full landscape size
	else:
		full_size = Vector2(90, 126)  # Full portrait size
	
	# GET BORDER WIDTH to account for
	var border_width = _get_border_width()
	var padding = border_width + 2  # Border plus 2px extra for shadow space
	
	# CALCULATE TARGET SIZE with padding
	var container_size = procedural_canvas.size
	var target_size = container_size - Vector2(padding * 2, padding * 2)
	
	# Further reduce for small presets to ensure good spacing
	match size_preset:
		SizePreset.MINI_DISPLAY:
			target_size = Vector2(40, 40)
		SizePreset.PASS_REWARD:
			target_size = Vector2(78, 78)
		SizePreset.SHOWCASE:
			target_size = Vector2(52, 72)
	
	# Calculate scale
	var scale_x = target_size.x / full_size.x
	var scale_y = target_size.y / full_size.y
	var uniform_scale = min(scale_x, scale_y)
	var scale_factor = Vector2(uniform_scale, uniform_scale)
	var scaled_size = full_size * uniform_scale
	var card_offset = (container_size - scaled_size) / 2
	
	print("[SCALED] Container: %s, Target: %s, Scale: %s, Border: %spx" % 
		[container_size, target_size, scale_factor, border_width])
	
	# CREATE SHADOW DIRECTLY ON PROCEDURAL CANVAS (for mini display and pass reward)
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		var shadow_node = ColorRect.new()  # Use ColorRect for simple shadow
		shadow_node.name = "ShadowNode"
		shadow_node.color = Color(0, 0, 0, 0.3)  # 30% black
		shadow_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Position shadow with offset
		var shadow_offset = Vector2(2, 2)
		shadow_node.position = card_offset + shadow_offset
		shadow_node.size = scaled_size
		
		procedural_canvas.add_child(shadow_node)
		
		print("[SCALED] Shadow added at position: %s, size: %s" % [shadow_node.position, shadow_node.size])
	
	# CREATE SCALING CONTAINER (for the actual card)
	var scale_container = Control.new()
	scale_container.name = "ScaleContainer"
	scale_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scale_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	procedural_canvas.add_child(scale_container)
	
	# CREATE FULL-SIZE DRAW CANVAS
	var draw_canvas = Control.new()
	draw_canvas.name = "DrawCanvas"
	draw_canvas.custom_minimum_size = full_size
	draw_canvas.size = full_size
	draw_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_canvas.clip_contents = true
	scale_container.add_child(draw_canvas)
	
	print("[SCALED] DrawCanvas created at full size: %s (landscape: %s)" % [full_size, is_landscape])
	
	# APPLY SCALE AND CENTER
	draw_canvas.scale = scale_factor
	draw_canvas.position = card_offset
	
	print("[SCALED] Final size: %s, Position: %s" % [scaled_size, card_offset])
	
	# SETUP FLOAT ANIMATION (only for mini display and pass reward)
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		# Store base position for animation
		var base_pos = draw_canvas.position
		
		# Horizontal sway + rotation animation
		var float_tween = create_tween()
		float_tween.set_loops()
		float_tween.set_trans(Tween.TRANS_SINE)
		
		# Sway right with clockwise rotation
		float_tween.tween_property(draw_canvas, "position:x", base_pos.x + 1.5, 1.2)
		float_tween.parallel().tween_property(draw_canvas, "rotation", deg_to_rad(2), 1.2)
		
		# Sway left with counter-clockwise rotation
		float_tween.tween_property(draw_canvas, "position:x", base_pos.x - 1.5, 1.2)
		float_tween.parallel().tween_property(draw_canvas, "rotation", deg_to_rad(-2), 1.2)
		
		# Return to center
		float_tween.tween_property(draw_canvas, "position:x", base_pos.x, 1.2)
		float_tween.parallel().tween_property(draw_canvas, "rotation", 0, 1.2)
		
		# Vertical bob animation (separate for different timing)
		var bob_tween = create_tween()
		bob_tween.set_loops()
		bob_tween.set_trans(Tween.TRANS_SINE)
		
		bob_tween.tween_property(draw_canvas, "position:y", base_pos.y - 1, 1.8)
		bob_tween.tween_property(draw_canvas, "position:y", base_pos.y + 1, 1.8)
		bob_tween.tween_property(draw_canvas, "position:y", base_pos.y, 1.8)
	
	# SETUP DRAW CALLBACK (draw at FULL size)
	draw_canvas.draw.connect(func():
		var canvas_size = full_size  # Always use full size for drawing
		
		match item_data.category:
			UnifiedItemData.Category.CARD_BACK:
				if instance.has_method("draw_card_back"):
					instance.draw_card_back(draw_canvas, canvas_size)
			UnifiedItemData.Category.CARD_FRONT:
				if instance.has_method("draw_card_front"):
					instance.draw_card_front(draw_canvas, canvas_size, "A", 0)
			UnifiedItemData.Category.BOARD:
				if instance.has_method("draw_board_background"):
					instance.draw_board_background(draw_canvas, canvas_size)
			_:
				if instance.has_method("draw_item"):
					instance.draw_item(draw_canvas, canvas_size)
	)
	
	# SETUP PROCEDURAL ANIMATION if needed
	if instance.get("is_animated") and instance.is_animated:
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
	
	# Force initial draw
	draw_canvas.queue_redraw()
	
	print("[SCALED] Setup complete for %s" % item_data.id)

func _draw_card_shadow(shadow_node: Control, card_size: Vector2, card_offset: Vector2):
	"""Draw a drop shadow for the card"""
	# Shadow offset (2px right, 2px down)
	var shadow_offset = Vector2(2, 2)
	var shadow_pos = card_offset + shadow_offset
	
	# Draw multiple layers for blur effect
	var shadow_layers = [
		{"offset": Vector2(0, 0), "alpha": 0.3, "size_reduction": 0},
		{"offset": Vector2(1, 1), "alpha": 0.2, "size_reduction": 2},
		{"offset": Vector2(2, 2), "alpha": 0.1, "size_reduction": 4},
	]
	
	for layer in shadow_layers:
		var rect = Rect2(
			shadow_pos + layer.offset,
			card_size - Vector2(layer.size_reduction, layer.size_reduction)
		)
		var color = Color(0, 0, 0, layer.alpha)
		
		# Draw rounded rect for softer shadow
		if rect.size.x > 0 and rect.size.y > 0:
			shadow_node.draw_rect(rect, color)

func _setup_float_animation(container: Control):
	"""Setup subtle floating animation for small display cards"""
	# Create looping animation
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)  # Smooth sine wave motion
	
	# Horizontal sway (subtle left-right)
	var sway_amount = 1.5  # pixels
	var rotation_amount = deg_to_rad(2)  # 2 degrees
	
	# Create animation sequence
	# Move right and rotate slightly clockwise
	tween.tween_property(container, "position:x", sway_amount, 1.2)
	tween.parallel().tween_property(container, "rotation", rotation_amount, 1.2)
	
	# Move left and rotate counter-clockwise  
	tween.tween_property(container, "position:x", -sway_amount, 1.2)
	tween.parallel().tween_property(container, "rotation", -rotation_amount, 1.2)
	
	# Return to center
	tween.tween_property(container, "position:x", 0, 1.2)
	tween.parallel().tween_property(container, "rotation", 0, 1.2)
	
	# Add subtle vertical bob
	var tween2 = create_tween()
	tween2.set_loops()
	tween2.set_trans(Tween.TRANS_SINE)
	
	var bob_amount = 1.0  # pixels
	tween2.tween_property(container, "position:y", -bob_amount, 1.8)
	tween2.tween_property(container, "position:y", bob_amount, 1.8)
	tween2.tween_property(container, "position:y", 0, 1.8)

func _get_border_width() -> int:
	"""Get the border width based on item rarity"""
	if not item_data:
		return 2  # Default border
	
	var rarity_str = item_data.get_rarity_name().to_lower()
	if rarity_str in ["epic", "legendary", "mythic"]:
		# Check if UIStyleManager has the border width setting
		if UIStyleManager and UIStyleManager.has_method("get_item_card_style"):
			var epic_border = UIStyleManager.get_item_card_style("card_border_width_epic")
			if epic_border:
				return epic_border
		return 3  # Default epic border
	else:
		if UIStyleManager and UIStyleManager.has_method("get_item_card_style"):
			var normal_border = UIStyleManager.get_item_card_style("card_border_width_normal")
			if normal_border:
				return normal_border
		return 2  # Default normal border

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

# === REWARD DISPLAY ===

func _setup_reward_display():
	"""Setup display for raw reward dictionary"""
	# Hide background texture for rewards
	if background_texture:
		background_texture.visible = false
	
	# Hide procedural canvas for rewards
	if procedural_canvas:
		procedural_canvas.visible = false
	
	# Create icon based on reward type
	if reward_data.has("stars"):
		_setup_currency_display("stars", reward_data.stars)
	elif reward_data.has("xp"):
		_setup_currency_display("xp", reward_data.xp)
	elif reward_data.has("cosmetic_type") and reward_data.has("cosmetic_id"):
		_setup_cosmetic_reward_display(reward_data.cosmetic_type, reward_data.cosmetic_id)
	else:
		# Generic reward
		_setup_generic_reward_display()

func _setup_currency_display(currency_type: String, amount: int):
	"""Display currency rewards (stars, XP)"""
	# Show icon
	if icon_texture:
		icon_texture.visible = true
		icon_texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_texture.size = Vector2(40, 40) if size_preset == SizePreset.PASS_REWARD else Vector2(24, 24)
		icon_texture.position = size / 2 - icon_texture.size / 2
		
		# Try to load placeholder food icons for now
		var food_path = ""
		match currency_type:
			"stars":
				food_path = "res://Pyramids/assets/placeholder/food/59_jelly.png"  # Golden jelly for stars
			"xp":
				food_path = "res://Pyramids/assets/placeholder/food/57_icecream.png"  # Ice cream for XP
		
		if ResourceLoader.exists(food_path):
			icon_texture.texture = load(food_path)
		
		# Use name label to show amount
		if name_label:
			name_label.visible = true
			name_label.text = str(amount)
			name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			name_label.anchor_top = 0.7
			name_label.add_theme_color_override("font_color", Color("#FFD700") if currency_type == "stars" else Color("#00FF00"))
			name_label.add_theme_font_size_override("font_size", 16)
	
	# HIDE price label for rewards
	if price_label:
		price_label.visible = false

func _setup_cosmetic_reward_display(cosmetic_type: String, cosmetic_id: String):
	"""Display cosmetic rewards"""
	if icon_texture:
		icon_texture.visible = true
		icon_texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_texture.size = Vector2(40, 40) if size_preset == SizePreset.PASS_REWARD else Vector2(24, 24)
		icon_texture.position = size / 2 - icon_texture.size / 2
		
		# Use placeholder food for cosmetics
		var food_items = ["34_donut.png", "75_pudding.png", "77_potatochips.png", "83_popcorn.png", "87_ramen.png"]
		var food_path = "res://Pyramids/assets/placeholder/food/" + food_items[randi() % food_items.size()]
		
		if ResourceLoader.exists(food_path):
			icon_texture.texture = load(food_path)
	
	# Show "NEW!" label
	if name_label:
		name_label.visible = true
		name_label.text = "NEW!"
		name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.anchor_top = 0.7
		name_label.add_theme_color_override("font_color", Color("#FFB75A"))
		name_label.add_theme_font_size_override("font_size", 14)
	
	# HIDE price label for rewards
	if price_label:
		price_label.visible = false

func _setup_generic_reward_display():
	"""Display generic rewards"""
	if icon_texture:
		icon_texture.visible = true
		icon_texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_texture.size = Vector2(40, 40) if size_preset == SizePreset.PASS_REWARD else Vector2(24, 24)
		icon_texture.position = size / 2 - icon_texture.size / 2
		
		# Use sandwich as generic fallback
		var food_path = "res://Pyramids/assets/placeholder/food/92_sandwich.png"
		if ResourceLoader.exists(food_path):
			icon_texture.texture = load(food_path)
	
	# HIDE price label for rewards
	if price_label:
		price_label.visible = false

# === SHADOW SYSTEM ===

func _create_shadow_layer():
	"""Create shadow layer for floating effect"""
	shadow_layer = Control.new()
	shadow_layer.name = "ShadowLayer"
	shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add as first child (behind everything)
	add_child(shadow_layer)
	move_child(shadow_layer, 0)
	
	# Create shadow drawable
	shadow_layer.draw.connect(_draw_shadow)
	shadow_layer.modulate.a = 0
	
	# Initially hidden
	shadow_layer.visible = false

func _draw_shadow():
	"""Draw the shadow effect"""
	var shadow_rect = Rect2(Vector2(3, 3), size - Vector2(6, 6))
	
	# Draw blurred shadow (simplified - multiple overlapping rects)
	for i in range(3):
		var offset = i * 1.0
		var alpha = 0.3 - (i * 0.1)
		var rect = Rect2(
			shadow_rect.position + Vector2(offset, offset),
			shadow_rect.size - Vector2(offset * 2, offset * 2)
		)
		shadow_layer.draw_rect(rect, Color(0, 0, 0, alpha))

func _update_shadow_position():
	"""Update shadow position for floating animation"""
	if shadow_layer:
		shadow_layer.queue_redraw()

# === ANIMATION SYSTEM (TWEEN ONLY) ===

func _play_animation():
	"""Play subtle float animation for claimable rewards - matches procedural items"""
	# Only animate if we don't already have a float animation running
	if has_meta("float_tween") and get_meta("float_tween"):
		return
	
	# Store base position
	var base_pos = position
	
	# Create subtle horizontal sway with slight rotation
	var float_tween = create_tween()
	float_tween.set_loops()  # Continuous loop
	float_tween.set_trans(Tween.TRANS_SINE)
	
	# Sway right with clockwise rotation
	float_tween.tween_property(self, "position:x", base_pos.x + 1.5, 1.2)
	float_tween.parallel().tween_property(self, "rotation", deg_to_rad(1), 1.2)
	
	# Sway left with counter-clockwise rotation  
	float_tween.tween_property(self, "position:x", base_pos.x - 1.5, 1.2)
	float_tween.parallel().tween_property(self, "rotation", deg_to_rad(-1), 1.2)
	
	# Return to center
	float_tween.tween_property(self, "position:x", base_pos.x, 1.2)
	float_tween.parallel().tween_property(self, "rotation", 0, 1.2)
	
	# Vertical bob animation (separate for different timing)
	var bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.set_trans(Tween.TRANS_SINE)
	
	bob_tween.tween_property(self, "position:y", base_pos.y - 1, 1.8)
	bob_tween.tween_property(self, "position:y", base_pos.y + 1, 1.8)
	bob_tween.tween_property(self, "position:y", base_pos.y, 1.8)
	
	# Store reference to stop if needed
	set_meta("float_tween", float_tween)
	set_meta("bob_tween", bob_tween)

func _update_animation_state():
	"""Update whether animations should be enabled"""
	if reward_data.size() > 0:
		# For rewards, animation is controlled by set_reward_state()
		return
	
	# For items, animate if not locked and not equipped
	animation_enabled = not is_locked and not is_equipped and display_mode != DisplayMode.INVENTORY
	
	# Show shadow for animated items
	if shadow_layer:
		shadow_layer.visible = animation_enabled

# === EXPANDED VIEW ===

func _show_expanded_view():
	"""Show expanded popup view of the item with smart positioning"""
	# First try to load the scene file
	var popup = null
	var scene_path = "res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn"
	
	if ResourceLoader.exists(scene_path):
		var expanded_popup_scene = load(scene_path)
		popup = expanded_popup_scene.instantiate()
	else:
		# Fallback: Create programmatically
		var script_path = "res://Pyramids/scripts/ui/popups/ItemExpandedView.gd"
		if ResourceLoader.exists(script_path):
			var script = load(script_path)
			popup = PanelContainer.new()
			popup.set_script(script)
			popup._ready()
		else:
			popup = _create_simple_popup()
	
	if not popup:
		push_error("[UnifiedItemCard] Could not create expanded view popup")
		return
	
	# Add to scene tree FIRST (needed for proper sizing)
	get_tree().root.add_child(popup)
	
	# Setup popup with item or reward data
	if item_data:
		if popup.has_method("setup_item"):
			popup.setup_item(item_data)
	elif reward_data.size() > 0:
		if popup.has_method("setup_reward"):
			popup.setup_reward(reward_data)
	
	# Wait for popup to be properly sized
	await get_tree().process_frame
	
	# SMART POSITIONING
	var screen_size = get_viewport().size
	var popup_size = popup.size
	var card_global_rect = Rect2(global_position, size)
	var margin = 20  # Distance from screen edge
	var spacing = 10  # Distance from clicked card
	
	var popup_pos = Vector2()
	
	# Horizontal positioning
	# Try to position to the RIGHT of the card
	var right_pos = card_global_rect.position.x + card_global_rect.size.x + spacing
	var left_pos = card_global_rect.position.x - popup_size.x - spacing
	var center_pos = card_global_rect.position.x + (card_global_rect.size.x - popup_size.x) / 2
	
	# Check which positions would fit on screen
	var can_fit_right = (right_pos + popup_size.x + margin) <= screen_size.x
	var can_fit_left = left_pos >= margin
	var can_fit_center = center_pos >= margin and (center_pos + popup_size.x + margin) <= screen_size.x
	
	# Prefer right, then left, then center
	if can_fit_right:
		popup_pos.x = right_pos
	elif can_fit_left:
		popup_pos.x = left_pos
	elif can_fit_center:
		popup_pos.x = center_pos
	else:
		# Last resort: clamp to screen bounds
		popup_pos.x = clamp(center_pos, margin, screen_size.x - popup_size.x - margin)
	
	# Vertical positioning
	# Try to center vertically with the card
	var center_y = card_global_rect.position.y + (card_global_rect.size.y - popup_size.y) / 2
	
	# Ensure it fits on screen vertically
	popup_pos.y = clamp(center_y, margin, screen_size.y - popup_size.y - margin)
	
	# Apply position
	popup.position = popup_pos
	
	# Make sure it's on top
	popup.z_index = 999
	
	# Connect close signal
	if popup.has_signal("closed"):
		popup.closed.connect(func(): popup.queue_free())
	
	expanded_view_requested.emit()

func _create_simple_popup() -> PanelContainer:
	"""Create a simple fallback popup if ItemExpandedView can't be loaded"""
	var popup = PanelContainer.new()
	popup.custom_minimum_size = Vector2(300, 400)
	popup.size = Vector2(300, 400)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", style)
	
	# Content
	var vbox = VBoxContainer.new()
	popup.add_child(vbox)
	
	# Title
	var title = Label.new()
	if item_data:
		title.text = item_data.display_name
	elif reward_data.has("stars"):
		title.text = "%d Stars" % reward_data.stars
	elif reward_data.has("xp"):
		title.text = "%d XP" % reward_data.xp
	else:
		title.text = "Item Preview"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_btn)
	
	# Make modal
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return popup

# === PRIVATE HELPERS ===

func _draw_badge_icon(badge_node: TextureRect, badge_type: String):
	"""Draw procedural badge icons"""
	var badge_size = UIStyleManager.get_item_card_style("equipped_badge_size")
	
	# Clear previous icon drawer
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
				var box_size = size * 0.7
				var box_rect = Rect2((size - box_size) / 2, box_size)
				icon_drawer.draw_rect(box_rect, Color.WHITE, false, 2.0)
				
				var check_points = PackedVector2Array([
					Vector2(size.x * 0.25, size.y * 0.5),
					Vector2(size.x * 0.4, size.y * 0.65),
					Vector2(size.x * 0.75, size.y * 0.3)
				])
				icon_drawer.draw_polyline(check_points, Color.GREEN, 2.0)
				
			"owned":  # Empty box
				var box_size = size * 0.7
				var box_rect = Rect2((size - box_size) / 2, box_size)
				icon_drawer.draw_rect(box_rect, Color.WHITE, false, 2.0)
				var inner_rect = Rect2(box_rect.position + Vector2(2, 2), box_rect.size - Vector2(4, 4))
				icon_drawer.draw_rect(inner_rect, Color(1, 1, 1, 0.1), true)
				
			"shop":  # Price tag shape
				var tag_width = size.x * 0.7
				var tag_height = size.y * 0.5
				var tag_rect = Rect2(size.x * 0.15, size.y * 0.25, tag_width, tag_height)
				icon_drawer.draw_rect(tag_rect, Color("#FFD700"), true)
				
				var triangle_points = PackedVector2Array([
					Vector2(tag_rect.position.x + tag_width, tag_rect.position.y),
					Vector2(size.x * 0.95, center.y),
					Vector2(tag_rect.position.x + tag_width, tag_rect.position.y + tag_height)
				])
				icon_drawer.draw_colored_polygon(triangle_points, Color("#FFD700"))
				
				icon_drawer.draw_circle(Vector2(size.x * 0.88, center.y), 2, Color.BLACK)
	)
	
	icon_drawer.queue_redraw()

func _setup_chain_lock():
	"""Create animated chain lock overlay"""
	for child in locked_overlay.get_children():
		child.queue_free()
	
	# Create dark overlay background
	var dark_overlay = ColorRect.new()
	dark_overlay.name = "DarkOverlay"
	dark_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark_overlay.color = Color(0, 0, 0, 0.6)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_overlay.add_child(dark_overlay)
	
	# Create chain drawer
	var chain_drawer = Control.new()
	chain_drawer.name = "ChainDrawer"
	chain_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chain_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_overlay.add_child(chain_drawer)
	
	chain_drawer.draw.connect(func():
		_draw_chains(chain_drawer)
	)
	
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
	var chain_color = Color(0.7, 0.7, 0.7, 1.0)
	var chain_shadow = Color(0.2, 0.2, 0.2, 0.8)
	var chain_highlight = Color(0.9, 0.9, 0.9, 1.0)
	
	# Draw two diagonal chains
	_draw_chain_line(drawer, Vector2(0, 0), Vector2(card_size.x, card_size.y), 
					link_width, link_height, link_spacing, 
					chain_color, chain_shadow, chain_highlight)
	
	_draw_chain_line(drawer, Vector2(card_size.x, 0), Vector2(0, card_size.y),
					link_width, link_height, link_spacing,
					chain_color, chain_shadow, chain_highlight)
	
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
		
		_draw_chain_link(drawer, link_pos + Vector2(1, 1), link_width, link_height, 
						angle, shadow_color, true)
		
		_draw_chain_link(drawer, link_pos, link_width, link_height, 
						angle, color, false)
		
		_draw_chain_link_highlight(drawer, link_pos, link_width, link_height,
								angle, highlight_color)

func _draw_chain_link(drawer: Control, pos: Vector2, width: float, height: float, 
					angle: float, color: Color, is_shadow: bool):
	"""Draw a single oval chain link"""
	var points = 16
	var oval_points = PackedVector2Array()
	
	for i in range(points + 1):
		var theta = (i / float(points)) * TAU
		var x = cos(theta) * width / 2
		var y = sin(theta) * height / 2
		
		var rotated = Vector2(x, y).rotated(angle)
		oval_points.append(pos + rotated)
	
	if not is_shadow:
		drawer.draw_polyline(oval_points, color, 2.0, true)
	else:
		drawer.draw_polyline(oval_points, color, 2.5, true)

func _draw_chain_link_highlight(drawer: Control, pos: Vector2, width: float, height: float,
							angle: float, color: Color):
	"""Draw highlight on chain link for 3D effect"""
	var points = 8
	var highlight_points = PackedVector2Array()
	
	for i in range(points):
		var theta = (i / float(points - 1)) * PI - PI/2
		var x = cos(theta) * width / 2.5
		var y = sin(theta) * height / 2.5
		
		var rotated = Vector2(x, y).rotated(angle)
		highlight_points.append(pos + rotated)
	
	drawer.draw_polyline(highlight_points, color, 1.0, true)

func _draw_padlock(drawer: Control, pos: Vector2, size: float):
	"""Draw a padlock at the chain intersection"""
	var body_rect = Rect2(pos.x - size/2, pos.y - size/3, size, size * 0.8)
	drawer.draw_rect(body_rect, Color(0.5, 0.5, 0.5, 1.0), true)
	drawer.draw_rect(body_rect, Color(0.3, 0.3, 0.3, 1.0), false, 2.0)
	
	var shackle_points = PackedVector2Array()
	var shackle_radius = size * 0.35
	
	for i in range(11):
		var angle = PI + (i / 10.0) * PI
		var point = pos + Vector2(cos(angle), sin(angle)) * shackle_radius
		point.y -= size * 0.2
		shackle_points.append(point)
	
	drawer.draw_polyline(shackle_points, Color(0.4, 0.4, 0.4, 1.0), 3.0)
	drawer.draw_circle(pos + Vector2(0, size * 0.1), 3, Color(0.2, 0.2, 0.2, 1.0))

func _animate_chains_entrance(container: Control):
	"""Animate chains sliding in from corners"""
	container.modulate.a = 0.0
	container.scale = Vector2(1.2, 1.2)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	tween.tween_property(container, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	tween.chain().set_loops()
	tween.tween_property(container, "modulate:a", 0.9, 1.0)
	tween.tween_property(container, "modulate:a", 1.0, 1.0)

# === SIGNAL HANDLERS ===

func _on_gui_input(event: InputEvent):
	"""Handle input - show expanded view ONLY for specific contexts"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_locked:
				return
			
			# ONLY show expanded view for mini displays and pass rewards
			# Skip for shop, inventory, and profile screens
			var should_show_expanded = false
			
			# Check by size preset (most reliable)
			if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
				should_show_expanded = true
			
			# Also check by display mode to be sure
			if display_mode in [DisplayMode.SHOP, DisplayMode.INVENTORY, DisplayMode.PROFILE]:
				should_show_expanded = false
			
			# Show expanded view if appropriate
			if should_show_expanded:
				_show_expanded_view()
			
			# Always emit clicked signal for other systems to handle
			if item_data:
				clicked.emit(item_data)

func _on_global_item_equipped(item_id: String, category: String):
	if item_data and item_data.id == item_id:
		is_equipped = true
		_update_equipped_badge()
		_update_animation_state()

func _on_global_item_unequipped(item_id: String, category: String):
	if item_data and item_data.id == item_id:
		is_equipped = false
		_update_equipped_badge()
		_update_animation_state()

func _on_global_ownership_changed(item_id: String, owned: bool):
	if item_data and item_data.id == item_id:
		is_owned = owned
		is_locked = not owned and item_data.unlock_level > 0
		_update_equipped_badge()
		_update_lock_state()
		_update_animation_state()

func hide_overlays_for_popup():
	"""Hide all overlays when card is displayed in a popup"""
	# Hide name label (shown in popup header instead)
	if name_label:
		name_label.visible = false
	
	# Hide price label (not needed in popup)
	if price_label:
		price_label.visible = false
	
	# Hide equipped/owned badge (not needed in popup)
	if equipped_badge:
		equipped_badge.visible = false

func debug_print_canvas_info():
	"""Print debug info about canvas setup"""
	if not procedural_canvas or not procedural_canvas.visible:
		print("[DEBUG] No visible procedural canvas")
		return
	
	print("[DEBUG] Card: %s, Size: %s, Preset: %s" % [
		item_data.id if item_data else "none",
		size,
		SizePreset.keys()[size_preset]
	])
	
	var scale_container = procedural_canvas.get_node_or_null("ScaleContainer")
	if scale_container:
		var draw_canvas = scale_container.get_node_or_null("DrawCanvas")
		if draw_canvas:
			print("[DEBUG]   Scaled rendering:")
			print("[DEBUG]   - DrawCanvas size: %s" % draw_canvas.size)
			print("[DEBUG]   - DrawCanvas scale: %s" % draw_canvas.scale)
			print("[DEBUG]   - DrawCanvas position: %s" % draw_canvas.position)
			print("[DEBUG]   - Effective size: %s" % (draw_canvas.size * draw_canvas.scale.x))
	else:
		print("[DEBUG]   Normal rendering (no scaling)")
