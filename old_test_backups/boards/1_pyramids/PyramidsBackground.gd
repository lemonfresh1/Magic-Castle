# PyramidsBackground.gd
# "res://Pyramids/scenes/items/boards/1_pyramids/PyramidsBackground.gd"
# "res://Pyramids/scenes/items/boards/1_pyramids/PyramidsBackground.tscn"

extends Control

@onready var sky: ColorRect = $Sky
@onready var cloud_container: Control = $CloudContainer
@onready var desert_back: ColorRect = $DesertBack
@onready var desert_front: ColorRect = $DesertFront

# Colors
const SKY_TOP = Color(0.5, 0.7, 0.9)
const SKY_BOTTOM = Color(0.9, 0.8, 0.6)
const DESERT_BACK = Color(0.8, 0.6, 0.4)
const DESERT_FRONT = Color(0.7, 0.5, 0.3)

# Cloud settings - higher number = faster speed
const CLOUD_SPEEDS = [15.0, 25.0, 35.0, 45.0]  # Different speeds for parallax effect

# Store cloud data
var clouds: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_sky()
	_setup_desert_layers()
	_setup_pyramids()
	_setup_clouds()

func _setup_sky() -> void:
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform vec4 top_color : source_color = vec4(0.5, 0.7, 0.9, 1.0);
	uniform vec4 bottom_color : source_color = vec4(0.9, 0.8, 0.6, 1.0);
	
	void fragment() {
		float gradient = UV.y;
		COLOR = mix(top_color, bottom_color, gradient);
	}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top_color", SKY_TOP)
	material.set_shader_parameter("bottom_color", SKY_BOTTOM)
	sky.material = material

func _setup_desert_layers() -> void:
	# Back desert layer - simple gradient matching pyramid style
	if desert_back:
		var back_shader = Shader.new()
		back_shader.code = """
		shader_type canvas_item;
		
		uniform vec4 top_color : source_color = vec4(0.8, 0.6, 0.4, 1.0);
		uniform vec4 bottom_color : source_color = vec4(0.7, 0.5, 0.3, 1.0);
		
		void fragment() {
			// Simple gradient
			float gradient = UV.y;
			COLOR = mix(top_color, bottom_color, gradient);
		}
		"""
		
		var back_material = ShaderMaterial.new()
		back_material.shader = back_shader
		back_material.set_shader_parameter("top_color", Color(0.75, 0.55, 0.35))  # Light sand
		back_material.set_shader_parameter("bottom_color", Color(0.65, 0.45, 0.25))  # Darker sand
		desert_back.material = back_material
	
	# Front desert layer - same style, just slightly darker
	if desert_front:
		var front_shader = Shader.new()
		front_shader.code = """
		shader_type canvas_item;
		
		uniform vec4 top_color : source_color = vec4(0.7, 0.5, 0.3, 1.0);
		uniform vec4 bottom_color : source_color = vec4(0.6, 0.4, 0.2, 1.0);
		
		void fragment() {
			// Simple gradient matching the back layer
			float gradient = UV.y;
			COLOR = mix(top_color, bottom_color, gradient);
		}
		"""
		
		var front_material = ShaderMaterial.new()
		front_material.shader = front_shader
		front_material.set_shader_parameter("top_color", Color(0.65, 0.45, 0.25))  # Medium sand
		front_material.set_shader_parameter("bottom_color", Color(0.55, 0.35, 0.15))  # Dark sand
		desert_front.material = front_material

func _add_gradient_to_desert(rect: ColorRect, top_color: Color, bottom_color: Color) -> void:
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	uniform vec4 top_color : source_color;
	uniform vec4 bottom_color : source_color;
	
	void fragment() {
		float gradient = UV.y;
		COLOR = mix(top_color, bottom_color, gradient);
	}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("top_color", top_color)
	material.set_shader_parameter("bottom_color", bottom_color)
	rect.material = material

func _setup_clouds() -> void:
	cloud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Get all cloud sprites
	var cloud_sprites = [
		$CloudContainer/Cloud1,
		$CloudContainer/Cloud2,
		$CloudContainer/Cloud3,
		$CloudContainer/Cloud4
	]
	
	var viewport_width = get_viewport_rect().size.x
	
	for i in range(cloud_sprites.size()):
		if cloud_sprites[i]:
			var sprite = cloud_sprites[i] as Sprite2D
			
			# Load texture if not already loaded
			if not sprite.texture:
				var texture_path = "res://Pyramids/scenes/items/backgrounds/1_pyramids/clouds_%d.png" % (i + 1)
				if ResourceLoader.exists(texture_path):
					sprite.texture = load(texture_path)
			
			# Scale down if needed
			sprite.scale = Vector2(0.4, 0.4)
			
			# Get actual sprite width after scaling
			var sprite_width = sprite.texture.get_width() * sprite.scale.x
			
			# Calculate how many copies we need to fill the screen + 1 extra
			var copies_needed = int(viewport_width / sprite_width) + 2
			
			# Set Y position for this cloud layer
			var y_position = 80 + (i * 50)
			
			# Set transparency (further = more transparent)
			var alpha = 0.7 - (i * 0.1)
			
			# Position first sprite at start
			sprite.position.x = 0
			sprite.position.y = y_position
			sprite.modulate.a = alpha
			
			# Store first cloud
			clouds.append({
				"sprite": sprite,
				"speed": CLOUD_SPEEDS[i],
				"width": sprite_width,
				"y_pos": y_position
			})
			
			# Create additional sprites to form a continuous chain
			for j in range(1, copies_needed):
				var duplicate = sprite.duplicate()
				duplicate.position.x = j * sprite_width  # Position exactly at the end of previous
				duplicate.position.y = y_position
				duplicate.modulate.a = alpha
				cloud_container.add_child(duplicate)
				
				clouds.append({
					"sprite": duplicate,
					"speed": CLOUD_SPEEDS[i],
					"width": sprite_width,
					"y_pos": y_position
				})

func _setup_pyramids() -> void:
	# PYRAMID 1 (Left)
	var pyramid_left = $PyramidLayer/PyramidLeft
	if pyramid_left:
		# Use your exact coordinates
		var left_points = PackedVector2Array([
			Vector2(215.0, 500.0),   # Point 0
			Vector2(397.0, 247.0),   # Point 1 (peak)
			Vector2(552.0, 500.0)    # Point 2
		])
		pyramid_left.polygon = left_points
		pyramid_left.color = Color(0.65, 0.55, 0.35)  # Light sandy color (background)
		pyramid_left.z_index = -1
		_add_pyramid_shadow(pyramid_left)
	
	# PYRAMID 2 (Center)
	var pyramid_center = $PyramidLayer/PyramidCenter
	if pyramid_center:
		# Use your exact coordinates
		var center_points = PackedVector2Array([
			Vector2(598.0, 160.0),   # Point 0 (peak)
			Vector2(852.0, 500.0),   # Point 1
			Vector2(357.0, 500.0)    # Point 2
		])
		pyramid_center.polygon = center_points
		pyramid_center.color = Color(0.6, 0.5, 0.3)  # Main pyramid color
		pyramid_center.z_index = 0  # In front
		_add_pyramid_shadow(pyramid_center)
	
	# PYRAMID 3 (Right)
	var pyramid_right = $PyramidLayer/PyramidRight
	if pyramid_right:
		# Use your exact coordinates
		var right_points = PackedVector2Array([
			Vector2(999.0, 500.0),   # Point 0
			Vector2(810.0, 247.0),   # Point 1 (peak)
			Vector2(648.0, 500.0)    # Point 2
		])
		pyramid_right.polygon = right_points
		pyramid_right.color = Color(0.55, 0.45, 0.30)  # Darker sandy (background)
		pyramid_right.z_index = -1
		_add_pyramid_shadow(pyramid_right)

func _add_pyramid_shadow(pyramid: Polygon2D) -> void:
	# Remove existing shadow if any
	for child in pyramid.get_children():
		if child.name == "Shadow":
			child.queue_free()
	
	# Create shadow polygon (darker face for 3D effect)
	var shadow = Polygon2D.new()
	shadow.name = "Shadow"
	
	# Get the original polygon points
	var points = pyramid.polygon
	if points.size() >= 3:
		# Find the peak (point with lowest Y value)
		var peak_idx = 0
		var min_y = points[0].y
		for i in range(points.size()):
			if points[i].y < min_y:
				min_y = points[i].y
				peak_idx = i
		
		# Find rightmost base point
		var right_idx = 0
		var max_x = points[0].x
		for i in range(points.size()):
			if points[i].x > max_x and points[i].y > min_y:  # Base point
				max_x = points[i].x
				right_idx = i
		
		# Create shadow as right face
		var shadow_points = PackedVector2Array([
			points[peak_idx],                              # Peak
			points[right_idx],                              # Bottom right
			Vector2(points[peak_idx].x + 30, points[right_idx].y)  # Inward point
		])
		shadow.polygon = shadow_points
		shadow.color = pyramid.color.darkened(0.35)  # Darker shade
		pyramid.add_child(shadow)

func _process(delta: float) -> void:
	var viewport_width = get_viewport_rect().size.x
	
	# Group clouds by their speed (to move same-speed clouds together)
	var cloud_groups = {}
	for cloud_data in clouds:
		var speed = cloud_data["speed"]
		if not cloud_groups.has(speed):
			cloud_groups[speed] = []
		cloud_groups[speed].append(cloud_data)
	
	# Move each group
	for speed in cloud_groups:
		var group = cloud_groups[speed]
		
		# Move all clouds in this group
		for cloud_data in group:
			var sprite = cloud_data["sprite"]
			sprite.position.x -= speed * delta
		
		# Check if we need to wrap any clouds
		for cloud_data in group:
			var sprite = cloud_data["sprite"]
			var sprite_width = cloud_data["width"]
			
			# If cloud has moved completely off the left side
			if sprite.position.x < -sprite_width:
				# Find the rightmost cloud in this group
				var rightmost_x = -INF
				for other_cloud in group:
					var other_x = other_cloud["sprite"].position.x
					if other_x > rightmost_x:
						rightmost_x = other_x
				
				# Position this cloud at the end of the rightmost cloud
				sprite.position.x = rightmost_x + sprite_width
