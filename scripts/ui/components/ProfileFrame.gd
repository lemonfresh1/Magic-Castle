# ProfileFrame.gd - Reusable frame component for player profiles
# Location: res://Pyramids/scripts/ui/components/ProfileFrame.gd
# Last Updated: Initial implementation with prestige colors and animations

extends PanelContainer

signal frame_clicked()
signal animation_finished(animation_name: String)

# === DEBUG FLAGS ===
var debug_enabled: bool = true
var global_debug: bool = true

# Frame customization
@export var frame_size: int = 80  # Default size for frame
@export var show_level: bool = true
@export var enable_animations: bool = true
@export var custom_frame_id: String = ""  # For future custom frames

# Node references
@onready var frame_border: NinePatchRect = $FrameBorder
@onready var level_container: PanelContainer = $PanelContainer
@onready var level_label: Label = $PanelContainer/LevelLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particle_container: Node2D = $ParticleContainer

# Current state
var current_level: int = 1
var current_prestige: int = 0
var is_animating: bool = false

# Prestige tier colors (matching XPManager)
const PRESTIGE_COLORS = {
	"none": Color.WHITE,
	"bronze": Color(0.8, 0.5, 0.3),
	"silver": Color(0.75, 0.75, 0.75),
	"gold": Color(1.0, 0.84, 0),
	"diamond": Color(0.7, 0.9, 1.0)
}

# Border glow intensities based on prestige
const GLOW_INTENSITY = {
	"none": 0.0,
	"bronze": 0.3,
	"silver": 0.5,
	"gold": 0.7,
	"diamond": 0.9
}

func debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[ProfileFrame] %s" % message)

func _ready() -> void:
	# Set initial size (ensure square for circle)
	custom_minimum_size = Vector2(frame_size, frame_size)
	size = Vector2(frame_size, frame_size)
	
	# DON'T clip contents to allow effects to extend beyond bounds
	clip_contents = false
	
	# Setup frame border style
	_setup_frame_style()
	
	# Connect to click detection
	gui_input.connect(_on_gui_input)
	
	# Setup level container positioning
	if level_container:
		level_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		level_container.size = Vector2(frame_size * 0.5, frame_size * 0.5)
		level_container.position = Vector2(-frame_size * 0.25, -frame_size * 0.25)
		level_container.clip_contents = true
	
	# Setup animations if available
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
		
		# TODO: Create fire animation for diamond prestige
		# - Add GPUParticles2D for fire effect
		# - Trigger on prestige 16-20
		print("TODO: Implement fire animation for diamond prestige frames")
		
		# TODO: Create lightning animation for gold prestige
		# - Add animated lightning bolts around frame
		# - Trigger on prestige 11-15
		print("TODO: Implement lightning animation for gold prestige frames")
		
		# TODO: Create water ripple effect for silver prestige
		# - Add shader-based water effect
		# - Trigger on prestige 6-10
		print("TODO: Implement water ripple animation for silver prestige frames")

func set_player_level(level: int, prestige: int = 0) -> void:
	debug_log("set_player_level() called:")
	debug_log("  Received level: %s (type: %s)" % [level, typeof(level)])
	debug_log("  Received prestige: %s (type: %s)" % [prestige, typeof(prestige)])
	
	current_level = level
	current_prestige = prestige
	
	debug_log("  current_level set to: %d" % current_level)
	debug_log("  current_prestige set to: %d" % current_prestige)
	
	# Update level display
	if level_label and show_level:
		debug_log("  Setting level_label.text to: '%s'" % str(level))
		level_label.text = str(level)
		level_label.visible = true
		debug_log("  level_label.text is now: '%s'" % level_label.text)
		debug_log("  level_label visible: %s" % level_label.visible)
	elif level_label:
		debug_log("  show_level is FALSE, hiding label")
		level_label.visible = false
	else:
		debug_log("  ERROR: level_label is NULL!")
	
	# Update frame appearance
	_update_frame_appearance()
	
	# Trigger special effects based on prestige
	if enable_animations:
		_trigger_prestige_animation()

func set_custom_frame(frame_id: String) -> void:
	custom_frame_id = frame_id
	
	# TODO: Load custom frame texture/style
	# - Load from ItemManager
	# - Apply custom border texture
	# - Override default prestige colors if needed
	print("TODO: Load custom frame with ID: " + frame_id)
	
	_update_frame_appearance()

func _setup_frame_style() -> void:
	# Create circular frame style
	var style = StyleBoxFlat.new()
	
	# Make it a perfect circle by setting corner radius to half the size
	var radius = frame_size / 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	
	# Border width
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	
	# Colors
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)  # Dark background
	style.border_color = Color.WHITE  # Will be updated based on prestige
	
	# Anti-aliasing for smooth circle
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	
	add_theme_stylebox_override("panel", style)

func _update_frame_appearance() -> void:
	var prestige_tier = _get_prestige_tier()
	var frame_color = PRESTIGE_COLORS[prestige_tier]
	var glow_intensity = GLOW_INTENSITY[prestige_tier]
	
	# Update frame border color while maintaining circle shape
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		style.border_color = frame_color
		
		# Ensure it stays circular when size changes
		var radius = frame_size / 2
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		
		# Add shadow/glow effect for higher prestige
		if glow_intensity > 0:
			style.shadow_color = frame_color
			style.shadow_color.a = glow_intensity * 0.6
			style.shadow_size = int(8 * glow_intensity)
			style.shadow_offset = Vector2.ZERO  # Centered glow
	
	# Update level label color
	if level_label:
		level_label.modulate = frame_color
		
		# Make label bigger for prestige levels
		if current_prestige > 0:
			level_label.add_theme_font_size_override("font_size", int(frame_size * 0.35))
		else:
			level_label.add_theme_font_size_override("font_size", int(frame_size * 0.3))
	
	# Update level container background (also circular)
	if level_container:
		var level_style = StyleBoxFlat.new()
		level_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
		
		# Make the level container also circular
		var level_radius = (frame_size * 0.4) / 2  # Slightly smaller than frame
		level_style.corner_radius_top_left = level_radius
		level_style.corner_radius_top_right = level_radius
		level_style.corner_radius_bottom_left = level_radius
		level_style.corner_radius_bottom_right = level_radius
		
		# Add subtle border to level container
		level_style.border_width_left = 1
		level_style.border_width_right = 1
		level_style.border_width_top = 1
		level_style.border_width_bottom = 1
		level_style.border_color = frame_color
		level_style.border_color.a = 0.3
		
		level_container.add_theme_stylebox_override("panel", level_style)

func _get_prestige_tier() -> String:
	if current_prestige == 0:
		return "none"
	elif current_prestige <= 5:
		return "bronze"
	elif current_prestige <= 10:
		return "silver"
	elif current_prestige <= 15:
		return "gold"
	else:
		return "diamond"

func _trigger_prestige_animation() -> void:
	if not animation_player or is_animating:
		return
	
	var prestige_tier = _get_prestige_tier()
	
	# Play pulse animation for any prestige
	if current_prestige > 0 and animation_player.has_animation("pulse"):
		play_animation("pulse")
	
	# TODO: Trigger tier-specific animations
	match prestige_tier:
		"bronze":
			# Simple pulse is enough for bronze
			pass
		"silver":
			# Will add water ripple effect
			print("TODO: Trigger silver water ripple animation")
		"gold":
			# Will add lightning effect
			print("TODO: Trigger gold lightning animation")
		"diamond":
			# Will add fire effect
			print("TODO: Trigger diamond fire animation")

func play_animation(anim_name: String) -> void:
	if not animation_player or not animation_player.has_animation(anim_name):
		return
	
	is_animating = true
	animation_player.play(anim_name)

func stop_animation() -> void:
	if animation_player and animation_player.is_playing():
		animation_player.stop()
		is_animating = false

func _on_animation_finished(anim_name: String) -> void:
	is_animating = false
	animation_finished.emit(anim_name)
	
	# Loop certain animations
	if anim_name == "pulse" and current_prestige > 0:
		# Keep pulsing for prestige frames
		await get_tree().create_timer(2.0).timeout
		if enable_animations:
			play_animation("pulse")

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			frame_clicked.emit()

func set_frame_size(size: int) -> void:
	frame_size = size
	custom_minimum_size = Vector2(size, size)
	self.size = Vector2(size, size)
	
	# Update style to maintain circle
	var style = get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var radius = size / 2
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
	
	# Scale level label font accordingly
	if level_label:
		var font_size = int(size * 0.3)  # 30% of frame size
		level_label.add_theme_font_size_override("font_size", font_size)
	
	# Update level container size and position
	if level_container:
		level_container.size = Vector2(size * 0.5, size * 0.5)
		level_container.position = Vector2(-size * 0.25, -size * 0.25)

# Debug function to test different prestige levels
func debug_set_prestige(prestige: int) -> void:
	set_player_level(50, prestige)
	print("ProfileFrame: Set to prestige %d (%s tier)" % [prestige, _get_prestige_tier()])

# TODO: Responsive sizing
# - Dynamically adjust frame_size based on parent container
# - Scale border width proportionally
# - Adjust font sizes based on frame size
# - Test on different screen resolutions
func _on_resized() -> void:
	print("TODO: Implement responsive sizing for ProfileFrame")
