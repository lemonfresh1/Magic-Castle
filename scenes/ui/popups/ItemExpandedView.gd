# ItemExpandedView.gd - Modal popup for detailed item/reward preview (SCENE-BASED)
# Location: res://Pyramids/scripts/ui/popups/ItemExpandedView.gd
# Last Updated: Scene-based implementation with StyledPanel

extends Control

signal closed

# Scene nodes
@onready var popup_panel: StyledPanel = $StyledPanel

# Dynamically created nodes
var close_button: StyledButton = null
var item_card: Control = null
var title_label: Label = null

# Popup data
var item_data: UnifiedItemData = null
var reward_data: Dictionary = {}

func _ready():
	# Set full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 999
	
	# Create the content inside StyledPanel
	_create_popup_content()
	
	# Make it modal
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Add fade-in animation
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _create_popup_content():
	"""Create the UI elements inside the StyledPanel"""
	# Create margin container for padding
	var margin_container = MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	popup_panel.add_child(margin_container)
	
	# Create main vertical container
	var vbox = VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 8)
	margin_container.add_child(vbox)
	
	# Create header with title and close button
	var header = HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(header)
	
	# Title label with primary color
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Item"
	if ThemeConstants:
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_title)
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	else:
		title_label.add_theme_font_size_override("font_size", 18)
		title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	# Create StyledButton for close button
	close_button = StyledButton.new()
	close_button.name = "CloseButton"
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.button_style = "transparent"
	close_button.button_size = "small"
	
	# Override close button colors for dark popup background
	close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color(0.6, 0.6, 0.6))
	close_button.add_theme_font_size_override("font_size", 20)
	
	header.add_child(close_button)
	close_button.pressed.connect(_on_close_pressed)
	
	# Add separator with primary color
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	if ThemeConstants:
		var sep_style = StyleBoxLine.new()
		sep_style.color = ThemeConstants.colors.primary
		sep_style.thickness = 2
		sep.add_theme_stylebox_override("separator", sep_style)
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
	var padding = 32  # Padding inside panel
	var header_height = 56  # Header + separator height
	
	if is_landscape:
		# Landscape size for boards
		var card_size = Vector2(192, 126)
		popup_panel.custom_minimum_size = Vector2(card_size.x + padding, card_size.y + header_height + padding)
		popup_panel.size = popup_panel.custom_minimum_size
	else:
		# Portrait size for cards  
		var card_size = Vector2(90, 126)
		popup_panel.custom_minimum_size = Vector2(card_size.x + padding, card_size.y + header_height + padding)
		popup_panel.size = popup_panel.custom_minimum_size
	
	# Center the popup
	popup_panel.position = (get_viewport_rect().size - popup_panel.size) * 0.5
	
	# Create the item card display
	_create_item_display()
	
	# Force layout update
	await get_tree().process_frame

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
	
	# Set standard reward size
	var padding = 32
	var header_height = 56
	var card_size = Vector2(90, 126)
	popup_panel.custom_minimum_size = Vector2(card_size.x + padding, card_size.y + header_height + padding)
	popup_panel.size = popup_panel.custom_minimum_size
	
	# Center the popup
	popup_panel.position = (get_viewport_rect().size - popup_panel.size) * 0.5
	
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
	"""Clean up and close the popup with fade out"""
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		closed.emit()
		queue_free()  # This will clean up everything
	)

func _input(event: InputEvent):
	"""Handle input - close on click outside"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is outside popup bounds
			var popup_rect = Rect2(popup_panel.global_position, popup_panel.size)
			
			if not popup_rect.has_point(event.position):
				_close_popup()
				get_viewport().set_input_as_handled()
