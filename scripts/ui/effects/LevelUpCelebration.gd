# LevelUpCelebration.gd - Simplified level up notification with confetti
# Path: res://Magic-Castle/scripts/ui/effects/LevelUpCelebration.gd
# Shows minimal celebration overlay when player levels up
extends Control

@onready var panel: Panel = $CenterContainer/Panel
@onready var level_up_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/LevelUpLabel
@onready var rewards_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/RewardsLabel
@onready var confetti_particles: CPUParticles2D = $ConfettiParticles

var auto_hide_timer: Timer

func _ready() -> void:
	# Start hidden
	visible = false
	
	# Set high z-index to appear above everything
	z_index = 1001
	set_as_top_level(true)
	
	# Create auto-hide timer
	auto_hide_timer = Timer.new()
	auto_hide_timer.wait_time = 2.5
	auto_hide_timer.one_shot = true
	auto_hide_timer.timeout.connect(_hide_celebration)
	add_child(auto_hide_timer)
	
	# Make clickable to dismiss early
	gui_input.connect(_on_gui_input)
	
	# Setup confetti
	_setup_confetti()

func _setup_confetti() -> void:
	if not confetti_particles:
		return
	
	# Particle properties
	confetti_particles.amount = 200
	confetti_particles.lifetime = 6.0
	confetti_particles.preprocess = 0.0
	confetti_particles.speed_scale = 1.0
	confetti_particles.emitting = false
	
	# Set texture to a square for confetti pieces
	var image = Image.create(15, 15, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	confetti_particles.texture = texture
	
	# Movement
	confetti_particles.direction = Vector2(0, 1)
	confetti_particles.initial_velocity_min = 50.0
	confetti_particles.initial_velocity_max = 200.0
	confetti_particles.angular_velocity_min = -360.0
	confetti_particles.angular_velocity_max = 360.0
	confetti_particles.gravity = Vector2(0, 300)
	
	# Visual properties
	confetti_particles.scale_amount_min = 0.8
	confetti_particles.scale_amount_max = 1.2
	
	# Create gradient for multiple colors
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0, 0))      # Red
	gradient.add_point(0.2, Color(1, 0.5, 0))    # Orange  
	gradient.add_point(0.4, Color(1, 1, 0))      # Yellow
	gradient.add_point(0.6, Color(0, 1, 0))      # Green
	gradient.add_point(0.8, Color(0, 0.5, 1))    # Blue
	gradient.add_point(1.0, Color(1, 0, 1))      # Purple
	
	confetti_particles.color_ramp = gradient

func show_level_up(old_level: int, new_level: int, rewards: Dictionary) -> void:
	# Position confetti at top center of screen
	var viewport_size = get_viewport().size
	confetti_particles.position = Vector2(viewport_size.x / 2, -50)
	confetti_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti_particles.emission_rect_extents = Vector2(viewport_size.x / 2, 10)
	
	# Update labels
	level_up_label.text = "LEVEL UP! 🎉"
	
	# Show star reward if any
	if rewards.has("stars") and rewards.stars > 0:
		rewards_label.text = "+%d ⭐" % rewards.stars
		rewards_label.visible = true
	else:
		rewards_label.visible = false
	
	# Show and animate
	visible = true
	_animate_entrance()
	_start_confetti()
	
	# Start auto-hide timer
	auto_hide_timer.start()

func _animate_entrance() -> void:
	# Reset panel state
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	
	# Create entrance animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Fade in and scale up panel
	tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.3)

func _start_confetti() -> void:
	if confetti_particles:
		confetti_particles.emitting = true
		confetti_particles.restart()
		
		# Add a second burst slightly delayed for more impact
		await get_tree().create_timer(0.2).timeout
		var second_burst = confetti_particles.duplicate()
		add_child(second_burst)
		second_burst.amount = 100
		second_burst.emitting = true
		second_burst.lifetime = 5.0
		
		# Clean up second burst
		await get_tree().create_timer(6.0).timeout
		if is_instance_valid(second_burst):
			second_burst.queue_free()

func _hide_celebration() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		visible = false
		modulate.a = 1.0
		confetti_particles.emitting = false
	)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		auto_hide_timer.stop()
		_hide_celebration()
