# ItemExpandedView.gd - Modal popup for detailed item/reward preview
# Location: res://Pyramids/scripts/ui/popups/ItemExpandedView.gd
# Last Updated: August 23, 2025 - Added header documentation, identified click issue
#
# Dependencies:
#   - UnifiedItemCard - Creates the actual item display
#   - UnifiedItemData - Item data structure
#
# Flow: User clicks small item → UnifiedItemCard emits signal → Creates this popup
#       → Shows large preview → User clicks X or backdrop → Popup closes
#
# Functionality:
#   • Creates modal popup with dark backdrop
#   • Displays items at full size (90x126 portrait, 192x126 landscape)
#   • Handles both item data and reward dictionaries
#   • Auto-sizes based on item type (board vs card)
#   • Closes on backdrop click or X button
#   • Hides price/name overlays for clean preview
#
# Signals Out:
#   - closed - When popup is dismissed

extends PanelContainer

signal closed

# Node references
@onready var close_button: Button = null
@onready var item_card: Control = null
@onready var title_label: Label = null
@onready var backdrop: Control = null

# Popup data
var item_data: UnifiedItemData = null
var reward_data: Dictionary = {}

func _ready():
	# Create a full-screen backdrop to capture clicks outside
	backdrop = Control.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.z_index = 998  # Just below the popup
	
	# Semi-transparent dark background for backdrop
	var backdrop_bg = ColorRect.new()
	backdrop_bg.color = Color(0, 0, 0, 0.5)  # 50% transparent black
	backdrop_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.add_child(backdrop_bg)
	
	# Add backdrop to root BEFORE adding self
	get_tree().root.add_child(backdrop)
	
	# Connect backdrop click
	backdrop_bg.gui_input.connect(_on_backdrop_clicked)
	
	# DON'T set size here - will be set by setup functions
	z_index = 999  # On top of backdrop
	
	# Create dark semi-transparent background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.98)
	style.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	
	# Create container for layout
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Create header with title and close button
	var header = HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(header)
	
	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Item"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	# Close button (X)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.flat = true
	close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color(0.6, 0.6, 0.6))
	header.add_child(close_button)
	
	# Connect close button
	close_button.pressed.connect(_on_close_pressed)
	
	# Add separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)
	
	# Container for the item card - size will be set dynamically
	var card_container = Control.new()
	card_container.name = "CardContainer"
	card_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_container.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(card_container)
	
	# Store reference
	item_card = card_container
	
	# Make it modal
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store backdrop reference for cleanup
	set_meta("backdrop", backdrop)

func setup_item(item: UnifiedItemData):
	"""Setup popup with UnifiedItemData - handles portrait/landscape"""
	item_data = item
	reward_data = {}
	
	# Update title
	if title_label:
		title_label.text = item.display_name
	
	# Determine if this is a landscape item (board)
	var is_landscape = item_data.category == UnifiedItemData.Category.BOARD
	
	# Set appropriate popup size based on item type
	# Add padding for border and header
	var padding = 20  # Total padding (borders + margins)
	var header_height = 44  # Header + separator height
	
	if is_landscape:
		# Landscape size for boards
		var card_size = Vector2(192, 126)
		custom_minimum_size = Vector2(card_size.x + padding, card_size.y + header_height + padding)
		size = custom_minimum_size
	else:
		# Portrait size for cards  
		var card_size = Vector2(90, 126)
		custom_minimum_size = Vector2(card_size.x + padding, card_size.y + header_height + padding)
		size = custom_minimum_size
	
	# Create the item card display
	_create_item_display()
	
	# Force layout update
	await get_tree().process_frame
	
	# Ensure we're properly sized
	if size != custom_minimum_size:
		size = custom_minimum_size

func setup_reward(reward: Dictionary):
	"""Setup popup with reward dictionary"""
	reward_data = reward
	item_data = null
	
	# Update title based on reward type
	if title_label:
		if reward_data.has("stars"):
			title_label.text = "%d Stars" % reward_data.stars
		elif reward_data.has("xp"):
			title_label.text = "%d XP" % reward_data.xp
		elif reward_data.has("cosmetic_type"):
			title_label.text = reward_data.cosmetic_type.capitalize()
		else:
			title_label.text = "Reward"
	
	# Create display
	_create_reward_display()

func _create_item_display():
	"""Create the item card preview with correct size"""
	if not item_card:
		return
	
	# Clear previous content
	for child in item_card.get_children():
		child.queue_free()
	
	# Wait for cleanup
	await get_tree().process_frame
	
	# Determine if landscape (board)
	var is_landscape = item_data and item_data.category == UnifiedItemData.Category.BOARD
	
	# Set the container size FIRST
	if is_landscape:
		item_card.custom_minimum_size = Vector2(192, 126)
		item_card.size = Vector2(192, 126)
	else:
		item_card.custom_minimum_size = Vector2(90, 126)
		item_card.size = Vector2(90, 126)
	
	# Create UnifiedItemCard
	var card = null
	var scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	
	if ResourceLoader.exists(scene_path):
		var card_scene = load(scene_path)
		card = card_scene.instantiate()
	else:
		card = _create_item_card_programmatically()
	
	if not card:
		push_error("[ItemExpandedView] Failed to create item card display")
		return
	
	# Add to container FIRST (important for initialization)
	item_card.add_child(card)
	
	# Wait for card to be in tree
	await get_tree().process_frame
	
	# Setup the card with INVENTORY preset always (not SHOP)
	if card.has_method("setup"):
		# Always use INVENTORY display mode for consistent sizing
		card.setup(item_data, UnifiedItemCard.DisplayMode.INVENTORY)
		
		# Override the size preset based on landscape/portrait
		if is_landscape:
			card.size_preset = UnifiedItemCard.SizePreset.SHOP  # This gives us 192x126
			card.layout_type = UnifiedItemCard.LayoutType.LANDSCAPE
		else:
			card.size_preset = UnifiedItemCard.SizePreset.INVENTORY  # This gives us 90x126
			card.layout_type = UnifiedItemCard.LayoutType.PORTRAIT
		
		# Apply the size preset
		if card.has_method("_apply_size_preset"):
			card._apply_size_preset()
		
		# Force the exact size we want
		card.custom_minimum_size = item_card.size
		card.size = item_card.size
		
		# Hide overlays for clean display
		if card.has_method("hide_overlays_for_popup"):
			card.hide_overlays_for_popup()
		else:
			# Manually hide overlays
			for node_path in ["OverlayContainer/NameLabel", "OverlayContainer/PriceLabel", "OverlayContainer/EquippedBadge"]:
				var node = card.get_node_or_null(node_path)
				if node:
					node.visible = false
	
	# Ensure card is positioned at origin of container
	card.position = Vector2.ZERO
	
	# Force redraw if procedural
	if item_data and item_data.is_procedural:
		var proc_canvas = card.get_node_or_null("ProceduralCanvas")
		if proc_canvas:
			var draw_canvas = proc_canvas.get_node_or_null("DrawCanvas")
			if draw_canvas:
				draw_canvas.queue_redraw()

func _create_reward_display():
	"""Create the reward card preview"""
	if not item_card:
		return
	
	# Clear previous content
	for child in item_card.get_children():
		child.queue_free()
	
	# Try to create UnifiedItemCard
	var card = null
	var scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	
	if ResourceLoader.exists(scene_path):
		var card_scene = load(scene_path)
		card = card_scene.instantiate()
	else:
		card = _create_item_card_programmatically()
	
	if not card:
		push_error("[ItemExpandedView] Failed to create reward card display")
		return
	
	# Set to inventory size
	card.custom_minimum_size = Vector2(90, 126)
	card.size = Vector2(90, 126)
	
	# Setup the card
	if card.has_method("setup_from_dict"):
		card.setup_from_dict(reward_data, UnifiedItemCard.SizePreset.INVENTORY)
		
		# Hide overlays for clean display
		if card.has_method("hide_overlays_for_popup"):
			card.hide_overlays_for_popup()
		else:
			# Manually hide overlays if method doesn't exist
			if card.get_node_or_null("OverlayContainer/NameLabel"):
				card.get_node("OverlayContainer/NameLabel").visible = false
			if card.get_node_or_null("OverlayContainer/PriceLabel"):
				card.get_node("OverlayContainer/PriceLabel").visible = false
			if card.get_node_or_null("OverlayContainer/EquippedBadge"):
				card.get_node("OverlayContainer/EquippedBadge").visible = false
	
	item_card.add_child(card)
	
	# Center the card in its container
	card.position = Vector2.ZERO

func _create_item_card_programmatically() -> PanelContainer:
	"""Create a UnifiedItemCard programmatically as fallback"""
	var card = PanelContainer.new()
	
	# Try to apply the UnifiedItemCard script
	var script_path = "res://Pyramids/scripts/ui/UnifiedItemCard.gd"
	if ResourceLoader.exists(script_path):
		var script = load(script_path)
		card.set_script(script)
		
		# Create required child nodes
		var bg_texture = TextureRect.new()
		bg_texture.name = "BackgroundTexture"
		card.add_child(bg_texture)
		
		var icon_texture = TextureRect.new()
		icon_texture.name = "IconTexture"
		card.add_child(icon_texture)
		
		var procedural_canvas = Control.new()
		procedural_canvas.name = "ProceduralCanvas"
		card.add_child(procedural_canvas)
		
		var overlay_container = Control.new()
		overlay_container.name = "OverlayContainer"
		card.add_child(overlay_container)
		
		var name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.visible = false  # Hide for popup
		overlay_container.add_child(name_label)
		
		var price_label = Label.new()
		price_label.name = "PriceLabel"
		price_label.visible = false  # Hide for popup
		overlay_container.add_child(price_label)
		
		var equipped_badge = TextureRect.new()
		equipped_badge.name = "EquippedBadge"
		equipped_badge.visible = false  # Hide for popup
		overlay_container.add_child(equipped_badge)
		
		var locked_overlay = Control.new()
		locked_overlay.name = "LockedOverlay"
		card.add_child(locked_overlay)
		
		# Call ready to initialize
		if card.has_method("_ready"):
			card._ready()
	else:
		# Ultra fallback - just create a simple panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
		style.border_color = Color(0.5, 0.5, 0.5, 1.0)
		style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", style)
		
		# Just show the texture/icon, no labels
		var texture = TextureRect.new()
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(texture)
	
	return card

func _on_backdrop_clicked(event: InputEvent):
	"""Handle clicks on the backdrop (outside popup)"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_close_popup()

func _on_close_pressed():
	"""Handle close button press"""
	_close_popup()

func _close_popup():
	"""Clean up and close the popup"""
	closed.emit()
	
	# Remove backdrop first
	if backdrop and is_instance_valid(backdrop):
		backdrop.queue_free()
	
	# Then remove self
	queue_free()

func _input(event: InputEvent):
	"""Handle input - close on click outside"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is outside popup bounds
			var popup_rect = Rect2(global_position, size)
			
			if not popup_rect.has_point(event.position):
				_close_popup()
				get_viewport().set_input_as_handled()
