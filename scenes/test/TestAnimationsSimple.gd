# TestAnimationsSimple.gd - Direct test with manual animation triggers
# Location: res://Pyramids/scripts/tests/TestAnimationsSimple.gd

extends Control

var test_cards: Array = []
var manual_timer: float = 0.0

func _ready():
	print("\n=== SIMPLE ANIMATION TEST ===")
	print("This test manually triggers animations to verify they work")
	print("Press SPACE to manually trigger animations")
	print("===============================\n")
	
	# Enable processing
	set_process(true)
	
	# Set window size
	get_window().size = Vector2(1000, 700)
	
	# Create main container with scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 680)
	scroll.position = Vector2(10, 10)
	scroll.size = Vector2(980, 680)
	add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(main_vbox)
	
	# Load card scene
	var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
	
	# === Test 1: Basic Reward Cards ===
	var title1 = Label.new()
	title1.text = "TEST 1: Basic Reward States"
	title1.add_theme_font_size_override("font_size", 18)
	title1.add_theme_color_override("font_color", Color.YELLOW)
	main_vbox.add_child(title1)
	
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 20)
	main_vbox.add_child(row1)
	
	# Create 3 star rewards with different states
	for i in range(3):
		var card = card_scene.instantiate()
		card.setup_from_dict({"stars": 100 + i * 50}, UnifiedItemCard.SizePreset.PASS_REWARD)
		
		var label_text = ""
		var label_color = Color.WHITE
		
		match i:
			0:
				# Claimable - should animate
				card.set_reward_state(true, false)
				label_text = "CLAIMABLE\n(Should animate)"
				label_color = Color.GREEN
				test_cards.append(card)  # Track for manual animation
			1:
				# Locked
				card.set_reward_state(false, false)
				label_text = "LOCKED\n(Static + chains)"
				label_color = Color.RED
			2:
				# Claimed
				card.set_reward_state(true, true)
				label_text = "CLAIMED\n(Dimmed 50%)"
				label_color = Color.GRAY
		
		var vbox = VBoxContainer.new()
		row1.add_child(vbox)
		vbox.add_child(card)
		
		var label = Label.new()
		label.text = label_text
		label.add_theme_color_override("font_color", label_color)
		label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(label)
	
	# === Test 2: Different Reward Types ===
	var title2 = Label.new()
	title2.text = "TEST 2: Different Reward Types (All Claimable)"
	title2.add_theme_font_size_override("font_size", 18)
	title2.add_theme_color_override("font_color", Color.YELLOW)
	main_vbox.add_child(title2)
	
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 20)
	main_vbox.add_child(row2)
	
	var rewards = [
		{"stars": 250},
		{"xp": 500},
		{"cosmetic_type": "emoji", "cosmetic_id": "fire"}
	]
	
	for reward in rewards:
		var card = card_scene.instantiate()
		card.setup_from_dict(reward, UnifiedItemCard.SizePreset.PASS_REWARD)
		card.set_reward_state(true, false)  # All claimable
		test_cards.append(card)  # Track for manual animation
		
		var vbox = VBoxContainer.new()
		row2.add_child(vbox)
		vbox.add_child(card)
		
		var label = Label.new()
		if reward.has("stars"):
			label.text = "%d Stars" % reward.stars
		elif reward.has("xp"):
			label.text = "%d XP" % reward.xp
		else:
			label.text = "Cosmetic"
		label.add_theme_color_override("font_color", Color.GREEN)
		vbox.add_child(label)
	
	# === Test 3: Manual Animation Test ===
	var title3 = Label.new()
	title3.text = "TEST 3: Manual Animation Trigger"
	title3.add_theme_font_size_override("font_size", 18)
	title3.add_theme_color_override("font_color", Color.YELLOW)
	main_vbox.add_child(title3)
	
	var big_card = card_scene.instantiate()
	big_card.setup_from_dict({"stars": 1000}, UnifiedItemCard.SizePreset.PASS_REWARD)
	big_card.set_reward_state(true, false)
	big_card.scale = Vector2(1.5, 1.5)  # Make it bigger to see animation better
	test_cards.append(big_card)
	main_vbox.add_child(big_card)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = """
	CONTROLS:
	• SPACE = Manually trigger animations on all claimable cards
	• A = Auto-trigger animations every 2 seconds (toggle)
	• R = Reload test
	• T = Test if cards are processing
	
	WHAT TO LOOK FOR:
	• Green cards should animate when triggered
	• Red cards should never move
	• Gray cards should be 50% transparent
	• Check console for debug output
	"""
	instructions.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(instructions)
	
	# Timer display
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "Manual timer: 0.0s"
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", Color.CYAN)
	main_vbox.add_child(timer_label)

var auto_animate: bool = false
var auto_timer: float = 0.0

func _process(delta):
	manual_timer += delta
	
	# Update timer display
	var timer_label = get_node_or_null("TimerLabel")
	if timer_label:
		timer_label.text = "Manual timer: %.1fs | Auto: %s" % [manual_timer, "ON" if auto_animate else "OFF"]
	
	# Auto animation if enabled
	if auto_animate:
		auto_timer += delta
		if auto_timer >= 2.0:
			auto_timer = 0.0
			_trigger_animations()

func _trigger_animations():
	print("\n[MANUAL] Triggering animations on %d tracked cards..." % test_cards.size())
	
	for card in test_cards:
		if not is_instance_valid(card):
			continue
		
		# Try multiple ways to trigger animation
		
		# Method 1: Call _play_animation if it exists
		if card.has_method("_play_animation"):
			card._play_animation()
			print("  - Called _play_animation on card")
		
		# Method 2: Try to animate via tween
		var tween = card.create_tween()
		tween.set_loops(1)
		tween.tween_property(card, "scale", Vector2(1.1, 1.1), 0.3)
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.3)
		
		# Method 3: Try rotation animation
		var tween2 = card.create_tween()
		tween2.set_loops(1)
		tween2.tween_property(card, "rotation", deg_to_rad(5), 0.2)
		tween2.tween_property(card, "rotation", deg_to_rad(-5), 0.4)
		tween2.tween_property(card, "rotation", 0, 0.2)
	
	print("  Animations triggered!")

func _test_processing():
	print("\n[TEST] Checking card processing...")
	for card in test_cards:
		if not is_instance_valid(card):
			continue
		
		print("  Card: %s" % card)
		print("    - is_processing: %s" % card.is_processing())
		print("    - animation_enabled: %s" % (card.get("animation_enabled") if card.has_method("get") else "N/A"))
		print("    - animation_timer: %s" % (card.get("animation_timer") if card.has_method("get") else "N/A"))
		print("    - is_claimable: %s" % (card.get("is_claimable") if card.has_method("get") else "N/A"))

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				print("SPACE pressed - triggering animations")
				_trigger_animations()
			KEY_A:
				auto_animate = !auto_animate
				auto_timer = 0.0
				print("Auto-animate: %s" % ("ON" if auto_animate else "OFF"))
			KEY_R:
				get_tree().reload_current_scene()
			KEY_T:
				_test_processing()
