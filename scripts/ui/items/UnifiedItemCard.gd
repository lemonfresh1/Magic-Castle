# UnifiedItemCard.gd - Universal item display component for all UI contexts
# Location: res://Pyramids/scripts/ui/UnifiedItemCard.gd
# Last Updated: August 23, 2025 - Cleanup: Added comprehensive header, wrapped debug prints, removed dead code
#
# Dependencies:
#   - ItemManager (autoload) - Retrieves item data and procedural instances
#   - EquipmentManager (autoload) - Tracks ownership and equipped states
#   - UIStyleManager (autoload) - Provides consistent styling values
#   - ProceduralItemRegistry (optional) - Fallback for procedural items
#   - ShopManager (optional) - Gets item prices for shop display
#   - UnifiedItemData (class) - Data structure for item properties
#
# Flow: Parent UI creates card → Calls setup() with item/reward → Card determines display type
#       → Loads textures or creates procedural display → Sets up overlays (name, price, badges)
#       → Handles user clicks → Shows expanded view or emits signals → Parent handles action
#
# Functionality:
#   • Displays items in 5 different modes (Inventory, Shop, Profile, Showcase, Selection)
#   • Supports 5 size presets (Mini 44x44, Pass 80x80, Inventory 90x126, Shop 192x126, Showcase 60x80)
#   • Renders both static textures and animated procedural items
#   • Shows item rarity through colored borders (common/rare/epic/legendary)
#   • Displays contextual overlays (name, price, equipped badge, lock icon)
#   • Handles battle pass rewards (stars, XP, cosmetics) with special formatting
#   • Animates claimable rewards with floating/bobbing effects
#   • Creates smart expanded view popups on click for small displays
#   • Manages ownership and equipped states via global signals
#   • Supports both portrait (cards, avatars) and landscape (boards) layouts
#
# Signals Out:
#   - clicked(item) - When card is clicked (for parent to handle)
#   - right_clicked(item) - Right click on card (unused currently)
#   - expanded_view_requested() - When popup is shown
# Signals In (from autoloads):
#   - item_equipped from EquipmentManager - Updates equipped badge
#   - item_unequipped from EquipmentManager - Removes equipped badge
#   - ownership_changed from EquipmentManager - Updates lock state
# 
# TODO: REFACTOR - This file is too large (1,664 lines)
# See roadmap: res://docs/CodebaseImprovementRoadmap.md
# Priority: HIGH - Used by ShopUI, InventoryUI, ProfileUI, MiniProfileCard
# Split into:
#   - ItemCardDisplay.gd (~400 lines)
#   - ItemCardState.gd (~300 lines)  
#   - ItemCardAnimator.gd (~300 lines)

class_name UnifiedItemCard
extends PanelContainer

# === CONSTANTS ===
const DEBUG = false  # Toggle for debug prints

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
	LANDSCAPE,     # Boards, Mini profiles
	ICON # Used for frames and emojis
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
@onready var lock_icon: TextureRect = $OverlayContainer/LockIcon
@onready var check_icon: TextureRect = $OverlayContainer/CheckIcon

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
var _cached_border_width: int = -1  # -1 means not cached

# Animation properties
var animation_enabled: bool = false  # State-based animation
var animation_timer: float = 0.0
var animation_interval: float = 5.0  # Time between animations

# Popup for expanded view
var expanded_popup_scene = preload("res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn") if ResourceLoader.exists("res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn") else null

# === LIFECYCLE METHODS ===

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
	
	# Initialize lock icon visibility
	if lock_icon:
		lock_icon.visible = false
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Initialize check icon visibility
	if check_icon:
		check_icon.visible = false
		check_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
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

# === PUBLIC API METHODS ===

func setup(item: UnifiedItemData, mode: DisplayMode = DisplayMode.INVENTORY):
	"""Configure the card with item data and display mode"""
	item_data = item
	reward_data = {}  # Clear reward data
	display_mode = mode
	_cached_border_width = -1

	
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
	display_mode = DisplayMode.SHOWCASE  # ← ADD THIS LINE!
	_cached_border_width = -1
	
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
	# Check if this is an empty reward slot (no actual rewards)
	var is_empty_slot = _is_empty_reward()
	
	is_locked = not unlocked
	is_claimed = claimed
	is_claimable = unlocked and not claimed
	
	# Only animate if claimable and not empty
	animation_enabled = is_claimable and not is_empty_slot
	
	# Ensure processing is enabled for animations
	if animation_enabled:
		set_process(true)
	else:
		set_process(false)
	
	# Update visual state - pass empty flag
	_update_lock_state_for_rewards(is_empty_slot)
	
	# UPDATE: Show checkmark for claimed items
	if check_icon:
		check_icon.visible = is_claimed and not is_empty_slot
		if check_icon.visible:
			# Position and size the checkmark
			check_icon.custom_minimum_size = Vector2(24, 24)
			check_icon.size = Vector2(24, 24)
			check_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			check_icon.position = Vector2(-26, 2)
			check_icon.modulate = Color("#10B981")  # Green checkmark
	
	# Dim if claimed (but preserve icon colors)
	if is_claimed:
		modulate.a = 0.5
		if shadow_layer:
			shadow_layer.visible = false
	else:
		modulate.a = 1.0
		if shadow_layer and is_claimable and size_preset != SizePreset.PASS_REWARD:
			shadow_layer.visible = true
	
	# PRESERVE ICON COLORS - reset icon modulation after state changes
	if icon_texture:
		icon_texture.modulate = Color.WHITE
		icon_texture.self_modulate = Color.WHITE

func setup_with_preset(item: UnifiedItemData, preset: SizePreset):
	"""Configure with UnifiedItemData and size preset"""
	size_preset = preset
	setup(item, DisplayMode.SHOWCASE)

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

# === CORE SETUP METHODS ===

func _apply_size_preset():
	"""Apply size based on preset"""
	var target_size = Vector2()
	
	match size_preset:
		SizePreset.MINI_DISPLAY:
			target_size = Vector2(50, 50)  # Keep this custom for mini
		SizePreset.PASS_REWARD:
			target_size = Vector2(86, 86)  # Keep this custom for pass
		SizePreset.INVENTORY:
			# Use UIStyleManager values
			if layout_type == LayoutType.LANDSCAPE:
				target_size = UIStyleManager.get_item_card_style("size_landscape")
			else:
				target_size = UIStyleManager.get_item_card_style("size_portrait")
		SizePreset.SHOP:
			# Same as inventory
			if layout_type == LayoutType.LANDSCAPE:
				target_size = UIStyleManager.get_item_card_style("size_landscape")
			else:
				target_size = UIStyleManager.get_item_card_style("size_portrait")
		SizePreset.SHOWCASE:
			target_size = UIStyleManager.get_item_card_style("size_showcase")
			# But we need to handle landscape showcase differently
			if layout_type == LayoutType.LANDSCAPE:
				# Calculate proportional landscape showcase (roughly 2x width)
				var showcase = UIStyleManager.get_item_card_style("size_showcase")
				target_size = Vector2(showcase.x * 2, showcase.y)
	
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
				# NOTE: Redundant calculation here - could use _get_border_width() but kept for performance
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
	
	# For ICON layout, use special centered display
	if layout_type == LayoutType.ICON:
		_setup_icon_display()
		return
	
	# For small presets, hide ALL backgrounds
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		background_texture.visible = false
		background_texture.self_modulate = Color(1, 1, 1, 0)  # Make invisible
		icon_texture.visible = false
		procedural_canvas.visible = false
		
		# Then setup procedural if needed
		if item_data.is_animated or item_data.is_procedural:
			_setup_procedural_display()
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

func _setup_overlays():
	"""Setup text overlays using existing scene nodes"""
	if not item_data:
		return  # Skip for rewards
	
	# For small presets - hide EVERYTHING (text and badges)
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD, SizePreset.SHOWCASE]:
		name_label.visible = false
		price_label.visible = false
		equipped_badge.visible = false
		return
	
	# DELETE THE ENTIRE SPECIAL ICON HANDLING BLOCK (lines that had "if layout_type == LayoutType.ICON:")
	# Just add this simple check for ICON items to hide the name
	if layout_type == LayoutType.ICON:
		name_label.visible = false
	else:
		# Normal name label setup for non-ICON items
		name_label.visible = true
		name_label.text = item_data.display_name
	
	# Below here continues as normal for all items (including ICON)
	
	# Get positioning from UIStyleManager
	var slot_1_top = UIStyleManager.get_item_card_style("label_slot_1_top")
	var slot_1_bottom = UIStyleManager.get_item_card_style("label_slot_1_bottom")
	var slot_2_top = UIStyleManager.get_item_card_style("label_slot_2_top")
	var slot_2_bottom = UIStyleManager.get_item_card_style("label_slot_2_bottom")
	var font_size_name = UIStyleManager.get_item_card_style("font_size_name")
	var font_size_price = UIStyleManager.get_item_card_style("font_size_price")
	
	# Only setup name label position if it's visible
	if name_label.visible:
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
	
	# Setup Price Label (same for all including ICON)
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
	
	# Continue with price label positioning (unchanged)
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

func _setup_card_size():
	"""Set card size based on layout type - with proper clipping"""
	var base_size = Vector2()
	
	match layout_type:
		LayoutType.PORTRAIT:
			base_size = UIStyleManager.get_item_card_style("size_portrait")
		LayoutType.LANDSCAPE:
			base_size = UIStyleManager.get_item_card_style("size_landscape")
		LayoutType.ICON:
			base_size = UIStyleManager.get_item_card_style("size_portrait")
	
	# Set sizes
	custom_minimum_size = base_size
	size = base_size
	
	# Enable clipping to prevent overflow
	clip_contents = true
	
	# Inset ProceduralCanvas by border width
	if procedural_canvas:
		# NOTE: Redundant border calculation - could use _get_border_width()
		var rarity_str = item_data.get_rarity_name().to_lower() if item_data else "common"
		var border_width = UIStyleManager.get_item_card_style("card_border_width_epic") if rarity_str in ["epic", "legendary", "mythic"] else UIStyleManager.get_item_card_style("card_border_width_normal")
		
		procedural_canvas.clip_contents = true
		procedural_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.set_offsets_preset(Control.PRESET_FULL_RECT)
		procedural_canvas.offset_left = border_width
		procedural_canvas.offset_top = border_width
		procedural_canvas.offset_right = -border_width
		procedural_canvas.offset_bottom = -border_width

# === PROCEDURAL DISPLAY METHODS ===

func _setup_procedural_display():
	"""Setup procedural animation - smart method handles both full and scaled displays"""
	if not item_data:
		return
	
	if not item_data.is_animated and not item_data.is_procedural:
		return
	
	# Determine if we need scaling based on size preset
	var needs_scaling = size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD, SizePreset.SHOWCASE]
	
	if DEBUG:
		print("[PROCEDURAL] Setting up for: %s (scaled: %s)" % [item_data.id, needs_scaling])
	
	# Show procedural canvas, hide background
	procedural_canvas.visible = true
	background_texture.visible = false
	
	# For small presets, ensure background stays hidden
	if needs_scaling:
		if background_texture:
			background_texture.visible = false
			background_texture.texture = null
			background_texture.self_modulate = Color(1, 1, 1, 0)
	
	# Clear any previous children
	for child in procedural_canvas.get_children():
		procedural_canvas.remove_child(child)
		child.queue_free()
	
	await get_tree().process_frame
	
	# Get the procedural instance
	var instance = null
	
	# Try loading the script directly (most reliable)
	if item_data.procedural_script_path != "":
		if DEBUG:
			print("[PROCEDURAL] Loading script: %s" % item_data.procedural_script_path)
		if ResourceLoader.exists(item_data.procedural_script_path):
			var script = load(item_data.procedural_script_path)
			if script:
				instance = script.new()
				if DEBUG:
					print("[PROCEDURAL] Instance created from script")
	
	# Fallback to other methods if direct load failed
	if not instance and ItemManager and ItemManager.has_method("get_procedural_instance"):
		instance = ItemManager.get_procedural_instance(item_data.id)
		if instance and DEBUG:
			print("[PROCEDURAL] Got instance from ItemManager")
	
	if not instance and ProceduralItemRegistry:
		instance = ProceduralItemRegistry.get_procedural_item(item_data.id)
		if instance and DEBUG:
			print("[PROCEDURAL] Got instance from Registry")
	
	if not instance:
		push_error("[UnifiedItemCard] Failed to create procedural instance for: %s" % item_data.id)
		procedural_canvas.visible = false
		background_texture.visible = true
		return
	
	# Branch based on whether we need scaling
	if needs_scaling:
		_setup_scaled_procedural(instance)
	else:
		_setup_full_size_procedural(instance)

func _setup_full_size_procedural(instance):
	"""Setup procedural display at full size with border padding"""
	# Create container for border padding
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
	
	# Create DrawCanvas inside padding container
	var draw_canvas = Control.new()
	draw_canvas.name = "DrawCanvas"
	draw_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	draw_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_canvas.clip_contents = true
	
	padding_container.add_child(draw_canvas)
	
	await get_tree().process_frame
	draw_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if DEBUG:
		print("[PROCEDURAL] DrawCanvas created with size: %s (with %spx border padding)" % [draw_canvas.size, border_width])
	
	# Setup the draw callback
	_setup_draw_callback(draw_canvas, instance, draw_canvas.size)
	
	# Setup animation if needed
	_setup_procedural_animation(draw_canvas, instance)
	
	# Force initial draw
	draw_canvas.queue_redraw()
	
	if DEBUG:
		print("[PROCEDURAL] Full-size setup complete")

func _setup_scaled_procedural(instance):
	"""Setup procedural display with scaling for small sizes"""
	# Determine full size based on item type
	var full_size = Vector2()
	var is_landscape = item_data.category == UnifiedItemData.Category.BOARD
	
	if is_landscape:
		full_size = Vector2(192, 126)  # Full landscape size
	else:
		full_size = Vector2(90, 126)  # Full portrait size
	
	# Get border width and calculate target size
	var border_width = _get_border_width()
	var padding = border_width + 2  # Border plus extra for shadow
	var container_size = procedural_canvas.size
	var target_size = container_size - Vector2(padding * 2, padding * 2)
	
	# Further reduce for small presets
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
	
	if DEBUG:
		print("[PROCEDURAL] Scaled: Container: %s, Target: %s, Scale: %s" % 
			[container_size, target_size, scale_factor])
	
	# Create shadow for mini display and pass reward
	# NOTE: Redundant shadow creation - could be unified with _create_shadow_layer()
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		var shadow_node = ColorRect.new()
		shadow_node.name = "ShadowNode"
		shadow_node.color = Color(0, 0, 0, 0.3)  # 30% black
		shadow_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var shadow_offset = Vector2(2, 2)
		shadow_node.position = card_offset + shadow_offset
		shadow_node.size = scaled_size
		
		procedural_canvas.add_child(shadow_node)
		if DEBUG:
			print("[PROCEDURAL] Shadow added")
	
	# Create scaling container
	var scale_container = Control.new()
	scale_container.name = "ScaleContainer"
	scale_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scale_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	procedural_canvas.add_child(scale_container)
	
	# Create full-size draw canvas
	var draw_canvas = Control.new()
	draw_canvas.name = "DrawCanvas"
	draw_canvas.custom_minimum_size = full_size
	draw_canvas.size = full_size
	draw_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_canvas.clip_contents = true
	scale_container.add_child(draw_canvas)
	
	# Apply scale and position
	draw_canvas.scale = scale_factor
	draw_canvas.position = card_offset
	
	if DEBUG:
		print("[PROCEDURAL] DrawCanvas at full size: %s, scaled to: %s" % [full_size, scaled_size])
	
	# Setup float animation for mini/pass
	if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
		_setup_float_animation(draw_canvas, card_offset)
	
	# Setup the draw callback (always draw at full size)
	_setup_draw_callback(draw_canvas, instance, full_size)
	
	# Setup procedural animation if needed
	_setup_procedural_animation(draw_canvas, instance)
	
	# Force initial draw
	draw_canvas.queue_redraw()
	
	if DEBUG:
		print("[PROCEDURAL] Scaled setup complete")

func _setup_draw_callback(draw_canvas: Control, instance, canvas_size: Vector2):
	"""Setup the draw callback for procedural items"""
	draw_canvas.draw.connect(func():
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

func _setup_procedural_animation(draw_canvas: Control, instance):
	"""Setup animation for animated procedural items"""
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

# === REWARD DISPLAY METHODS ===

func _setup_reward_display():
	"""Setup display for raw reward dictionary"""
	# RESET any modulation first
	# NOTE: Redundant modulation reset - happens multiple times
	self.modulate = Color.WHITE  # Reset card modulation
	
	# Hide background texture for rewards
	if background_texture:
		background_texture.visible = false
	
	# Hide procedural canvas for rewards
	if procedural_canvas:
		procedural_canvas.visible = false
	
	# Check if empty first
	if _is_empty_reward():
		# Empty slot - just show empty bordered container
		_setup_empty_slot_display()
		return
	
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

func _setup_icon_display():
	"""Setup centered icon display for emojis, frames, etc."""
	# Hide background for icon items
	background_texture.visible = false
	procedural_canvas.visible = false
	
	# Load the texture
	var texture_path = item_data.texture_path
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return
	
	# Use icon_texture for display
	icon_texture.visible = true
	icon_texture.texture = load(texture_path)
	
	# ENSURE NO COLOR MODULATION
	icon_texture.modulate = Color.WHITE
	icon_texture.self_modulate = Color.WHITE
	
	# Use the expand mode that works for sizing
	icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Instead of position, use anchors and margins to center it
	icon_texture.set_anchors_preset(Control.PRESET_CENTER)
	
	# Set the size
	var icon_size = Vector2(64, 64)
	icon_texture.size = icon_size
	
	# Use margins to offset from center (negative half of size)
	icon_texture.set_offsets_preset(Control.PRESET_CENTER)
	icon_texture.offset_left = -32  # Half of 64
	icon_texture.offset_top = 32   # Half of 64
	icon_texture.offset_right = 32
	icon_texture.offset_bottom = 32
	
	if DEBUG:
		print("[ICON] Using anchor centering: size=%s" % icon_texture.size)

func _setup_empty_slot_display():
	"""Display for empty reward slots - just a semi-transparent placeholder"""
	# Hide icon
	if icon_texture:
		icon_texture.visible = false
	
	# Hide labels
	if name_label:
		name_label.visible = false
	if price_label:
		price_label.visible = false
	
	# Make the whole card semi-transparent to indicate emptiness
	modulate.a = 0.6

func _setup_currency_display(currency_type: String, amount: int):
	"""Display currency rewards (stars, XP) with proper sprites"""
	# Show icon
	# NOTE: Redundant icon setup - similar code in _setup_generic_reward_display()
	if icon_texture:
		icon_texture.visible = true
		icon_texture.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		
		# Size based on preset - slightly smaller to fit well
		var icon_size = Vector2(50, 50) if size_preset == SizePreset.PASS_REWARD else Vector2(40, 40)
		icon_texture.size = icon_size
		icon_texture.position = (size / 2) - (icon_texture.size / 2)
		icon_texture.position.y -= 8  # Move icon up a bit to make room for text
		
		# Load proper sprites for stars and XP
		var sprite_path = ""
		match currency_type:
			"stars":
				sprite_path = "res://Pyramids/assets/ui/bp_star.png"
			"xp":
				sprite_path = "res://Pyramids/assets/ui/bp_xp.png"
			_:
				# Fallback to food icons for other types
				sprite_path = "res://Pyramids/assets/placeholder/food/92_sandwich.png"
		
		if ResourceLoader.exists(sprite_path):
			icon_texture.texture = load(sprite_path)
			icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# ENSURE NO TINTING - Force white modulation to show original colors
			# NOTE: Redundant modulation resets
			icon_texture.modulate = Color.WHITE
			icon_texture.self_modulate = Color.WHITE
		else:
			push_warning("[UnifiedItemCard] Currency sprite not found: " + sprite_path)
		
		# Use NameLabel to show amount below icon
		if name_label:
			name_label.visible = true
			name_label.text = str(amount)
			
			# Position at bottom of card
			name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			name_label.anchor_top = 0.65  # Start from 65% down
			name_label.anchor_bottom = 0.95  # End at 95% down
			name_label.offset_left = 0
			name_label.offset_right = 0
			
			# Style the text
			match currency_type:
				"stars":
					name_label.add_theme_color_override("font_color", Color("#FFD700"))  # Gold
				"xp":
					name_label.add_theme_color_override("font_color", Color("#00E5FF"))  # Cyan
				_:
					name_label.add_theme_color_override("font_color", Color.WHITE)
			
			name_label.add_theme_font_size_override("font_size", 20)
			name_label.add_theme_color_override("font_outline_color", Color.BLACK)
			name_label.add_theme_constant_override("outline_size", 2)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			
			# Ensure label isn't tinted either
			name_label.modulate = Color.WHITE
			name_label.self_modulate = Color.WHITE
	
	# Hide price label for rewards
	if price_label:
		price_label.visible = false

func _setup_cosmetic_reward_display(cosmetic_type: String, cosmetic_id: String):
	"""Display cosmetic rewards"""
	var item = ItemManager.get_item(cosmetic_id) if ItemManager else null
	
	if item:
		item_data = item
		size_preset = SizePreset.PASS_REWARD
		_setup_background()  # Handles procedural display
		
		# NO TEXT LABELS for cosmetics - keep it clean
		if name_label:
			name_label.visible = false
	else:
		push_warning("[UnifiedItemCard] Cosmetic not found in ItemManager: %s" % cosmetic_id)
		# Since we have all items, this shouldn't happen
		# Just show nothing rather than placeholder
		if icon_texture:
			icon_texture.visible = false
	
	if price_label:
		price_label.visible = false

func _setup_generic_reward_display():
	"""Display generic rewards"""
	# NOTE: Redundant icon setup - similar to _setup_currency_display()
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

# === VISUAL UPDATE METHODS ===

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
	"""Update lock display using simple lock icon"""
	# Remove old locked overlay if it exists (cleanup)
	if locked_overlay and is_instance_valid(locked_overlay):
		locked_overlay.queue_free()
		locked_overlay = null
	
	# Use the simple lock icon
	if lock_icon:
		lock_icon.visible = is_locked
		
		# Position based on size preset
		match size_preset:
			SizePreset.PASS_REWARD:
				# For 86x86 cards, make it 20x20 in top-right
				lock_icon.custom_minimum_size = Vector2(20, 20)
				lock_icon.size = Vector2(20, 20)
				lock_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				lock_icon.position = Vector2(-22, 2)  # Slight padding from edge
			SizePreset.MINI_DISPLAY:
				# For 50x50 cards, make it 12x12
				lock_icon.custom_minimum_size = Vector2(12, 12)
				lock_icon.size = Vector2(12, 12)
				lock_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				lock_icon.position = Vector2(-14, 1)
			_:
				# Default size for other presets
				lock_icon.custom_minimum_size = Vector2(24, 24)
				lock_icon.size = Vector2(24, 24)
				lock_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				lock_icon.position = Vector2(-26, 2)

func _update_lock_state_for_rewards(is_empty_slot: bool):
	"""Update lock display for rewards - use simple icon"""
	# Remove old locked overlay if it exists
	if locked_overlay and is_instance_valid(locked_overlay):
		locked_overlay.queue_free()
		locked_overlay = null
	
	# Show lock icon ONLY if locked AND has content
	if lock_icon:
		lock_icon.visible = is_locked and not is_empty_slot
		
		# Size for pass rewards
		lock_icon.custom_minimum_size = Vector2(20, 20)
		lock_icon.size = Vector2(20, 20)
		lock_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lock_icon.position = Vector2(-22, 2)

func _update_shadow_position():
	"""Update shadow position for floating animation"""
	if shadow_layer:
		shadow_layer.queue_redraw()

func _update_animation_state():
	"""Update whether animations should be enabled"""
	if reward_data.size() > 0:
		# For rewards, animation is controlled by set_reward_state()
		return
	
	# For items, animate if not locked and not equipped
	animation_enabled = not is_locked and not is_equipped and display_mode != DisplayMode.INVENTORY
	
	# Show shadow for animated items (but NOT pass rewards)
	if shadow_layer and size_preset != SizePreset.PASS_REWARD:
		shadow_layer.visible = animation_enabled

# === ANIMATION METHODS ===

func _play_animation():
	"""Play subtle float animation - for rewards, animate icon only"""
	# For rewards, animate the icon inside, not the whole card
	# NOTE: Similar animation logic in _setup_float_animation() - could be unified
	if reward_data.size() > 0 and icon_texture and icon_texture.visible:
		# Only animate icon if we don't already have animation
		if icon_texture.has_meta("float_tween") and icon_texture.get_meta("float_tween"):
			return
		
		# Store base position of icon
		var base_pos = icon_texture.position
		
		# Create subtle horizontal sway with slight rotation for icon
		var float_tween = create_tween()
		float_tween.set_loops()
		float_tween.set_trans(Tween.TRANS_SINE)
		
		# Sway right with clockwise rotation
		float_tween.tween_property(icon_texture, "position:x", base_pos.x + 1.5, 1.2)
		float_tween.parallel().tween_property(icon_texture, "rotation", deg_to_rad(1), 1.2)
		
		# Sway left with counter-clockwise rotation  
		float_tween.tween_property(icon_texture, "position:x", base_pos.x - 1.5, 1.2)
		float_tween.parallel().tween_property(icon_texture, "rotation", deg_to_rad(-1), 1.2)
		
		# Return to center
		float_tween.tween_property(icon_texture, "position:x", base_pos.x, 1.2)
		float_tween.parallel().tween_property(icon_texture, "rotation", 0, 1.2)
		
		# Vertical bob animation
		var bob_tween = create_tween()
		bob_tween.set_loops()
		bob_tween.set_trans(Tween.TRANS_SINE)
		
		bob_tween.tween_property(icon_texture, "position:y", base_pos.y - 1, 1.8)
		bob_tween.tween_property(icon_texture, "position:y", base_pos.y + 1, 1.8)
		bob_tween.tween_property(icon_texture, "position:y", base_pos.y, 1.8)
		
		# Store reference
		icon_texture.set_meta("float_tween", float_tween)
		icon_texture.set_meta("bob_tween", bob_tween)
	else:
		# For regular items, keep existing animation (if any needed)
		pass

func _setup_float_animation(draw_canvas: Control, base_pos: Vector2):
	"""Setup subtle floating animation for small display cards"""
	# Horizontal sway + rotation animation
	# NOTE: Similar to _play_animation() - could be parameterized and unified
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

# === SHADOW SYSTEM METHODS ===

func _create_shadow_layer():
	"""Create shadow layer for floating effect"""
	# NO SHADOWS for pass rewards
	if size_preset == SizePreset.PASS_REWARD:
		return  # Skip shadow creation entirely
	
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

# === EXPANDED VIEW METHODS ===

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

# === HELPER METHODS ===

func _get_layout_type() -> LayoutType:
	"""Determine layout type from item category"""
	if not item_data:
		# For rewards, determine from size preset
		if size_preset == SizePreset.PASS_REWARD:
			return LayoutType.PORTRAIT
		return LayoutType.PORTRAIT
	
	# Determine layout based on category
	match item_data.category:
		UnifiedItemData.Category.BOARD, UnifiedItemData.Category.MINI_PROFILE_CARD:
			return LayoutType.LANDSCAPE
		UnifiedItemData.Category.EMOJI, UnifiedItemData.Category.FRAME:
			return LayoutType.ICON
		_:
			return LayoutType.PORTRAIT

func _get_border_width() -> int:
	"""Get the border width based on item rarity - CACHED"""
	# Return cached value if available
	if _cached_border_width >= 0:
		return _cached_border_width
	
	# Calculate border width
	var border_width = 2  # Default
	
	if not item_data:
		_cached_border_width = 2
		return _cached_border_width
	
	var rarity_str = item_data.get_rarity_name().to_lower()
	if rarity_str in ["epic", "legendary", "mythic"]:
		if UIStyleManager and UIStyleManager.has_method("get_item_card_style"):
			var epic_border = UIStyleManager.get_item_card_style("card_border_width_epic")
			if epic_border:
				border_width = epic_border
			else:
				border_width = 3  # Default epic
		else:
			border_width = 3
	else:
		if UIStyleManager and UIStyleManager.has_method("get_item_card_style"):
			var normal_border = UIStyleManager.get_item_card_style("card_border_width_normal")
			if normal_border:
				border_width = normal_border
			else:
				border_width = 2  # Default normal
		else:
			border_width = 2
	
	# Cache the result
	_cached_border_width = border_width
	return _cached_border_width

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

func _is_empty_reward() -> bool:
	"""Check if reward_data is empty or has no meaningful content"""
	if reward_data.is_empty():
		return true
	
	# Check if it has any actual reward content
	var has_content = (
		reward_data.has("stars") or 
		reward_data.has("xp") or 
		reward_data.has("cosmetic_id") or
		reward_data.has("cosmetic_type")
	)
	
	return not has_content

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

# === SIGNAL HANDLERS ===

func _on_gui_input(event: InputEvent):
	"""Handle input - show expanded view for locked/claimed items only"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var should_show_expanded = false
			
			# For rewards - only show expanded view if locked OR claimed
			# NOT for claimable items (unlocked but not claimed)
			if reward_data.size() > 0:
				# Only allow preview for locked or already claimed items
				if is_locked or is_claimed:
					should_show_expanded = true
				# Block for claimable items (is_claimable = true means unlocked but not claimed)
				elif is_claimable:
					should_show_expanded = false
			else:
				# For regular items (non-rewards)
				if size_preset in [SizePreset.MINI_DISPLAY, SizePreset.PASS_REWARD]:
					should_show_expanded = true
				
				# Skip for full-size item displays
				if item_data and display_mode in [DisplayMode.SHOP, DisplayMode.INVENTORY, DisplayMode.PROFILE]:
					should_show_expanded = false
			
			# Show expanded view if appropriate
			if should_show_expanded:
				_show_expanded_view()
			
			# Emit clicked signal for claimable items (for claiming)
			if reward_data.size() > 0 and is_claimable:
				# This allows clicking to claim
				# but doesn't show expanded view
				pass
			elif item_data and not is_locked:
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
