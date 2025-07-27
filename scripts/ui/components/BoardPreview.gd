# BoardPreview.gd
extends Panel

var current_skin: String = "green"

func _ready() -> void:
	custom_minimum_size = Vector2(200, 80)
	_update_display()

func set_skin(skin_name: String) -> void:
	current_skin = skin_name
	_update_display()

func _update_display() -> void:
	# Check if we have a sprite for this skin
	var sprite_path = "res://Magic-Castle/assets/backgrounds/%s-bg.png" % current_skin
	
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
			"green":
				style.bg_color = Color(0.15, 0.4, 0.15)
				style.border_color = Color(0.1, 0.3, 0.1)
			"blue":
				style.bg_color = Color(0.15, 0.25, 0.5)
				style.border_color = Color(0.1, 0.2, 0.4)
			"sunset":
				style.bg_color = Color(0.6, 0.3, 0.15)
				style.border_color = Color(0.5, 0.25, 0.1)
			_:
				style.bg_color = Color(0.2, 0.2, 0.2)
		
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		add_theme_stylebox_override("panel", style)
