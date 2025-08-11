# ShopItemCard.gd - Individual shop item display component with rarity borders and pricing
# Location: res://Pyramids/scripts/ui/shop/ShopItemCard.gd
# Last Updated: Updated to use icons from ItemData [Date]

extends PanelContainer

signal item_clicked(item_data: ShopManager.ShopItem)
signal preview_requested(item_data: ShopManager.ShopItem)

@onready var icon_texture: TextureRect = $MarginContainer/VBoxContainer/IconContainer/IconTexture
@onready var lock_overlay: Control = $MarginContainer/VBoxContainer/IconContainer/LockOverlay
@onready var lock_icon: TextureRect = $MarginContainer/VBoxContainer/IconContainer/LockOverlay/LockIcon
@onready var lock_label: Label = $MarginContainer/VBoxContainer/IconContainer/LockOverlay/LockLabel
@onready var owned_overlay: Control = $MarginContainer/VBoxContainer/IconContainer/OwnedOverlay
@onready var checkmark: TextureRect = $MarginContainer/VBoxContainer/IconContainer/OwnedOverlay/Checkmark
@onready var new_badge: PanelContainer = $MarginContainer/VBoxContainer/IconContainer/NewBadge
@onready var sale_badge: PanelContainer = $MarginContainer/VBoxContainer/IconContainer/SaleBadge
@onready var sale_label: Label = $MarginContainer/VBoxContainer/IconContainer/SaleBadge/Label
@onready var item_name: Label = $MarginContainer/VBoxContainer/ItemName
@onready var price_container: HBoxContainer = $MarginContainer/VBoxContainer/PriceContainer
@onready var original_price: Label = $MarginContainer/VBoxContainer/PriceContainer/OriginalPrice
@onready var current_price: Label = $MarginContainer/VBoxContainer/PriceContainer/CurrentPrice
@onready var star_icon: TextureRect = $MarginContainer/VBoxContainer/PriceContainer/StarIcon

var item_data: ShopManager.ShopItem
var is_owned: bool = false
var is_locked: bool = false
var is_on_sale: bool = false
var is_new: bool = false

func setup(item: ShopManager.ShopItem):
	item_data = item
	
	# If nodes aren't ready yet, wait for ready
	if not is_node_ready():
		await ready
	
	# Load icon - prefer preview_texture_path (from ItemData.icon_path) over placeholder
	if icon_texture:
		var icon_loaded = false
		
		# First try preview_texture_path (actual icon from ItemData)
		if item.preview_texture_path != "" and ResourceLoader.exists(item.preview_texture_path):
			icon_texture.texture = load(item.preview_texture_path)
			icon_loaded = true
		
		# Fallback to placeholder icon if no actual icon
		if not icon_loaded and item.placeholder_icon != "":
			var placeholder_path = "res://Pyramids/assets/placeholder/food/" + item.placeholder_icon
			if ResourceLoader.exists(placeholder_path):
				icon_texture.texture = load(placeholder_path)
	
	# Set item name (truncate if too long)
	var display_name = item.display_name
	if display_name.length() > 10:
		display_name = display_name.substr(0, 9) + "..."
	
	if item_name:
		item_name.text = display_name
		item_name.add_theme_font_size_override("font_size", 12)
		item_name.autowrap_mode = TextServer.AUTOWRAP_OFF  # Prevent wrapping
	
	# Check states
	is_owned = ShopManager.is_item_owned(item.id)
	is_on_sale = ShopManager.is_item_on_sale(item.id)
	is_new = ShopManager.is_item_new(item.id)
	is_locked = item.unlock_level > 0  # Future: and XPManager.get_current_level() < item.unlock_level
	
	# Update visual state
	_update_visual_state()
	
	# Apply rarity styling
	_apply_rarity_style(item.rarity)

func _update_visual_state():
	# Reset all overlays - check for null first
	if lock_overlay:
		lock_overlay.visible = false
	if owned_overlay:
		owned_overlay.visible = false
	if new_badge:
		new_badge.visible = false
	if sale_badge:
		sale_badge.visible = false
	if original_price:
		original_price.visible = false
	
	# Handle different states
	if is_owned:
		owned_overlay.visible = true
		modulate = Color(1, 1, 1, 0.6)  # Semi-transparent
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif is_locked:
		# Use the SaleBadge for locked state
		sale_badge.visible = true
		sale_label.text = "LOCKED"
		lock_label.text = "Lvl " + str(item_data.unlock_level)
		modulate = Color(0.7, 0.7, 0.7, 1)
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		modulate = Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		if is_new:
			new_badge.visible = true
		
		if is_on_sale:
			sale_badge.visible = true
			sale_label.text = "33% OFF"
			# Hide original price for now
			original_price.visible = false
	
	# Set price
	var price = ShopManager.get_item_price(item_data.id)
	if price == -1:  # Mythic items
		current_price.text = "Not for Sale"
		star_icon.visible = false
	else:
		current_price.text = str(price)
		star_icon.visible = true
		
		# Set font size - make it slightly bigger
		current_price.add_theme_font_size_override("font_size", 14)  # Increase by 2px from default
		
		# Color price based on affordability
		if ShopManager.can_afford_item(item_data.id):
			current_price.add_theme_color_override("font_color", Color(0.137, 0.137, 0.137))
		else:
			current_price.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))  # Red for unaffordable

func _apply_rarity_style(rarity: ShopManager.Rarity):
	# Create border style based on rarity
	var border_style = StyleBoxFlat.new()
	var color = ShopManager.get_rarity_color(rarity)
	
	# Keep existing background from scene - no bg_color override
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = color
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border_style.corner_radius_top_left = 12
	border_style.corner_radius_top_right = 12
	border_style.corner_radius_bottom_left = 12
	border_style.corner_radius_bottom_right = 12	
	border_style.shadow_color = Color(0.445, 0.445, 0.445, 0.6)
	border_style.shadow_size = 2
	border_style.shadow_offset = Vector2.ZERO
	
	# Apply glow for higher rarities
	if rarity >= ShopManager.Rarity.EPIC:
		border_style.shadow_color = color
		border_style.shadow_size = 5
		border_style.shadow_offset = Vector2.ZERO
		
	if rarity == ShopManager.Rarity.MYTHIC:
		# Future: Add animation/particles
		pass
	
	add_theme_stylebox_override("panel", border_style)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_owned and not is_locked:
			item_clicked.emit(item_data)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Right click for preview
		preview_requested.emit(item_data)

func _on_mouse_entered():
	if not is_owned and not is_locked:
		# Add hover effect
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited():
	if not is_owned and not is_locked:
		# Remove hover effect
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func refresh_for_shop():
	# Force refresh the visual state for shop display
	if price_container:
		price_container.visible = true
	
	# Re-check all states
	is_owned = ShopManager.is_item_owned(item_data.id)
	is_on_sale = ShopManager.is_item_on_sale(item_data.id)
	is_new = ShopManager.is_item_new(item_data.id)
	is_locked = item_data.unlock_level > 0  # Future: and XPManager.get_current_level() < item_data.unlock_level
	
	# Update the display
	_update_visual_state()

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Set consistent size for all cards
	custom_minimum_size = Vector2(120, 150)
	size = Vector2(120, 150)  # Force size
	
	# Ensure proper size flags for grid layout
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
