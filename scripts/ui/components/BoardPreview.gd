# BoardPreview.gd
# Path: res://Pyramids/scripts/ui/components/BoardPreview.gd
extends Panel

var current_skin: String = "green"

func _ready() -> void:
	custom_minimum_size = Vector2(200, 80)
	update_display()

func set_skin(skin_name: String) -> void:
	current_skin = skin_name
	update_display()

func update_display() -> void:
	# Check if this is an ItemManager board
	if current_skin.begins_with("board_"):
		var item = ItemManager.get_item(current_skin)
		if item and item is ItemData:
			_apply_item_preview(item)
			return
	
	# Legacy board handling - your existing code
	_apply_legacy_preview()

func _apply_item_preview(item: ItemData) -> void:
	var style: StyleBox
	
	# Handle different background types
	match item.background_type:
		"scene":
			# For animated scenes, show a preview image or themed color
			if item.preview_texture_path and ResourceLoader.exists(item.preview_texture_path):
				# Use preview texture if available
				var texture = load(item.preview_texture_path)
				var tex_style = StyleBoxTexture.new()
				tex_style.texture = texture
				style = tex_style
			else:
				# Create a themed preview for pyramid board
				var flat_style = StyleBoxFlat.new()
				flat_style.bg_color = Color(0.8, 0.6, 0.4)  # Sandy color
				flat_style.border_color = Color(0.6, 0.4, 0.2)
				flat_style.set_border_width_all(2)
				flat_style.set_corner_radius_all(8)
				
				# Add gradient effect for depth
				flat_style.shadow_color = Color(0.5, 0.3, 0.1, 0.3)
				flat_style.shadow_size = 3
				style = flat_style
		
		"sprite":
			# Static sprite background
			if item.texture_path and ResourceLoader.exists(item.texture_path):
				var texture = load(item.texture_path)
				var tex_style = StyleBoxTexture.new()
				tex_style.texture = texture
				style = tex_style
			else:
				# Fallback to color
				style = _create_color_style_from_item(item)
		
		_:  # "color" or default
			style = _create_color_style_from_item(item)
	
	if style:
		add_theme_stylebox_override("panel", style)

func _create_color_style_from_item(item: ItemData) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	
	# Use colors from item data
	var primary_color = item.colors.get("primary", Color(0.5, 0.5, 0.5))
	var border_color = item.colors.get("border", primary_color.darkened(0.3))
	
	style.bg_color = primary_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	
	return style

func _apply_legacy_preview() -> void:
	# First check for sprite (your existing code)
	var sprite_path = "res://Pyramids/assets/backgrounds/%s_bg.png" % current_skin
	
	if ResourceLoader.exists(sprite_path):
		# Use sprite background
		var texture = load(sprite_path)
		var style = StyleBoxTexture.new()
		style.texture = texture
		add_theme_stylebox_override("panel", style)
	else:
		# Fall back to color
		var style = StyleBoxFlat.new()
		
		match current_skin:
			"green", "classic":
				style.bg_color = Color(0.15, 0.4, 0.15)
				style.border_color = Color(0.1, 0.3, 0.1)
			"blue":
				style.bg_color = Color(0.15, 0.25, 0.5)
				style.border_color = Color(0.1, 0.2, 0.4)
			"sunset":
				style.bg_color = Color(0.6, 0.3, 0.15)
				style.border_color = Color(0.5, 0.25, 0.1)
			"board_pyramids":
				# Fallback if ItemManager isn't available
				style.bg_color = Color(0.8, 0.6, 0.4)
				style.border_color = Color(0.6, 0.4, 0.2)
			_:
				style.bg_color = Color(0.2, 0.2, 0.2)
				style.border_color = Color(0.15, 0.15, 0.15)
		
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		add_theme_stylebox_override("panel", style)
