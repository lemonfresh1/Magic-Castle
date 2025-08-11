# OrganicBackground.gd - Noise-based organic morphing with vibrant colors
# Location: res://Pyramids/scripts/ui/backgrounds/OrganicBackground.gd
# Last Updated: More vibrant color variations

extends ColorRect

@export var base_color: Color = Color(0.2, 0.5, 0.3)
@export var morph_speed: float = 1.5
@export var shape_scale: float = 3.0  # Size of the shapes
@export var color_range: float = 0.4  # INCREASED - How much color varies

var time: float = 0.0

const SHADER_CODE = """
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.2, 0.5, 0.3, 1.0);
uniform float time = 0.0;
uniform float shape_scale = 3.0;
uniform float color_range = 0.4;

// Simple pseudo-random
float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Smooth noise
float noise(vec2 st) {
	vec2 i = floor(st);
	vec2 f = fract(st);
	
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));
	
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal noise for more organic look
float fbm(vec2 st) {
	float value = 0.0;
	float amplitude = 0.5;
	
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(st);
		st *= 2.0;
		amplitude *= 0.5;
	}
	
	return value;
}

void fragment() {
	vec2 uv = UV;
	
	// Create slowly morphing noise
	float n1 = fbm(uv * shape_scale + vec2(time * 0.05, time * 0.03));
	float n2 = fbm(uv * shape_scale * 0.8 + vec2(-time * 0.04, time * 0.06));
	float n3 = fbm(uv * shape_scale * 1.2 + vec2(time * 0.03, -time * 0.05));
	
	// Combine noises for complex patterns
	float combined = (n1 + n2 + n3) / 3.0;
	
	// Create stepped regions for more defined shapes
	float stepped = floor(combined * 5.0) / 5.0;
	
	// Smooth between stepped and continuous
	float pattern = mix(combined, stepped, 0.3);
	
	// Color based on pattern
	vec4 color = base_color;
	
	// Much stronger color variations
	vec3 dark_variant = base_color.rgb * 0.4;  // Very dark green
	vec3 light_variant = base_color.rgb * 1.6; // Bright green
	vec3 blue_variant = vec3(base_color.r * 0.7, base_color.g * 0.9, base_color.b * 1.4); // Blue-green
	vec3 yellow_variant = vec3(base_color.r * 1.2, base_color.g * 1.3, base_color.b * 0.8); // Yellow-green
	
	// Mix colors based on pattern value
	if (pattern < 0.25) {
		color.rgb = mix(dark_variant, base_color.rgb, pattern * 4.0);
	} else if (pattern < 0.5) {
		color.rgb = mix(base_color.rgb, blue_variant, (pattern - 0.25) * 4.0);
	} else if (pattern < 0.75) {
		color.rgb = mix(blue_variant, yellow_variant, (pattern - 0.5) * 4.0);
	} else {
		color.rgb = mix(yellow_variant, light_variant, (pattern - 0.75) * 4.0);
	}
	
	// Add some color contrast at edges
	float edge = abs(fract(pattern * 8.0) - 0.5) * 2.0;
	if (edge > 0.8) {
		color.rgb *= 1.3; // Highlight edges
	}
	
	// Slow global color shift
	float pulse = sin(time * 0.1) * 0.1;
	color.rgb += pulse;
	
	// Ensure we don't blow out the colors
	color.rgb = clamp(color.rgb, vec3(0.0), vec3(1.0));
	
	COLOR = color;
}
"""

func _ready():
	size = Vector2(1200, 540)
	
	var shader = Shader.new()
	shader.code = SHADER_CODE
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("base_color", base_color)
	shader_material.set_shader_parameter("shape_scale", shape_scale)
	shader_material.set_shader_parameter("color_range", color_range)
	
	material = shader_material

func _process(delta):
	time += delta * morph_speed
	
	if material:
		material.set_shader_parameter("time", time)
