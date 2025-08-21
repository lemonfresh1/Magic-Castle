# TestRewardAnimations.gd - Simple test focusing on reward animations
# Location: res://Pyramids/scripts/tests/TestRewardAnimations.gd
# Shows the 3 states clearly: Claimable (animated), Locked (static), Claimed (dimmed)

extends Control

var animation_check_timer: float = 0.0
var test_cards: Array = []  # FIXED: Added missing variable

func _ready():
	await get_tree().process_frame
	
	# Set window size for better visibility
	get_window().size = Vector2(800, 600)
	
	print("\n=== REWARD ANIMATION TEST ===")
	print("Watch the CLAIMABLE cards - they should pulse/sway every 5 seconds")
	print("LOCKED cards should be static with chains")
	print("CLAIMED cards should be dimmed (50% opacity)")
	
	# Enable processing for timer updates
	set_process(true)
	
	# Load card scene
	var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
	
	# Create scroll container for all content
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size = Vector2(780, 580)
	scroll.position = Vector2(10, 10)
	add_child(scroll)
	
	# Main container inside scroll
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 30)
	scroll.add_child(container)
	
	# === ROW 1: Star Rewards ===
	var stars_row = HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", 20)
	container.add_child(stars_row)
	
	_add_label(stars_row, "STAR REWARDS:")
	
	# Claimable stars - SHOULD ANIMATE
	var stars_claimable = card_scene.instantiate()
	stars_claimable.setup_from_dict({"stars": 100}, UnifiedItemCard.SizePreset.PASS_REWARD)
	stars_claimable.set_reward_state(true, false)  # Unlocked, not claimed
	stars_claimable.add_to_group("unified_item_cards")  # Add to group for tracking
	stars_claimable.set_process(true)  # Ensure processing is enabled
	test_cards.append(stars_claimable)  # FIXED: Now properly tracks the card
	stars_row.add_child(stars_claimable)
	_add_state_label(stars_claimable, "✨ ANIMATING", Color.GREEN)
	
	# Force animation to be enabled (debug)
	if stars_claimable.has_method("set"):
		stars_claimable.set("animation_enabled", true)
		print("Forced animation on stars_claimable: ", stars_claimable.get("animation_enabled"))
	
	# Locked stars - SHOULD BE STATIC
	var stars_locked = card_scene.instantiate()
	stars_locked.setup_from_dict({"stars": 100}, UnifiedItemCard.SizePreset.PASS_REWARD)
	stars_locked.set_reward_state(false, false)  # Locked
	stars_row.add_child(stars_locked)
	_add_state_label(stars_locked, "🔒 STATIC", Color.RED)
	
	# Claimed stars - SHOULD BE DIMMED
	var stars_claimed = card_scene.instantiate()
	stars_claimed.setup_from_dict({"stars": 100}, UnifiedItemCard.SizePreset.PASS_REWARD)
	stars_claimed.set_reward_state(true, true)  # Claimed
	stars_row.add_child(stars_claimed)
	_add_state_label(stars_claimed, "✓ DIMMED", Color.GRAY)
	
	# === ROW 2: XP Rewards ===
	var xp_row = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 20)
	container.add_child(xp_row)
	
	_add_label(xp_row, "XP REWARDS:")
	
	# Claimable XP
	var xp_claimable = card_scene.instantiate()
	xp_claimable.setup_from_dict({"xp": 500}, UnifiedItemCard.SizePreset.PASS_REWARD)
	xp_claimable.set_reward_state(true, false)
	xp_claimable.add_to_group("unified_item_cards")
	test_cards.append(xp_claimable)  # FIXED: Now properly tracks
	xp_row.add_child(xp_claimable)
	_add_state_label(xp_claimable, "✨ ANIMATING", Color.GREEN)
	
	# Locked XP
	var xp_locked = card_scene.instantiate()
	xp_locked.setup_from_dict({"xp": 500}, UnifiedItemCard.SizePreset.PASS_REWARD)
	xp_locked.set_reward_state(false, false)
	xp_row.add_child(xp_locked)
	_add_state_label(xp_locked, "🔒 STATIC", Color.RED)
	
	# Claimed XP
	var xp_claimed = card_scene.instantiate()
	xp_claimed.setup_from_dict({"xp": 500}, UnifiedItemCard.SizePreset.PASS_REWARD)
	xp_claimed.set_reward_state(true, true)
	xp_row.add_child(xp_claimed)
	_add_state_label(xp_claimed, "✓ DIMMED", Color.GRAY)
	
	# === ROW 3: Cosmetic Rewards ===
	var cosmetic_row = HBoxContainer.new()
	cosmetic_row.add_theme_constant_override("separation", 20)
	container.add_child(cosmetic_row)
	
	_add_label(cosmetic_row, "COSMETICS:")
	
	# Claimable cosmetic
	var cosmetic_claimable = card_scene.instantiate()
	cosmetic_claimable.setup_from_dict({
		"cosmetic_type": "emoji",
		"cosmetic_id": "fire"
	}, UnifiedItemCard.SizePreset.PASS_REWARD)
	cosmetic_claimable.set_reward_state(true, false)
	cosmetic_claimable.add_to_group("unified_item_cards")
	test_cards.append(cosmetic_claimable)  # FIXED: Now properly tracks
	cosmetic_row.add_child(cosmetic_claimable)
	_add_state_label(cosmetic_claimable, "✨ ANIMATING", Color.GREEN)
	
	# Locked cosmetic
	var cosmetic_locked = card_scene.instantiate()
	cosmetic_locked.setup_from_dict({
		"cosmetic_type": "card_skin",
		"cosmetic_id": "golden"
	}, UnifiedItemCard.SizePreset.PASS_REWARD)
	cosmetic_locked.set_reward_state(false, false)
	cosmetic_row.add_child(cosmetic_locked)
	_add_state_label(cosmetic_locked, "🔒 STATIC", Color.RED)
	
	# Claimed cosmetic
	var cosmetic_claimed = card_scene.instantiate()
	cosmetic_claimed.setup_from_dict({
		"cosmetic_type": "board",
		"cosmetic_id": "space"
	}, UnifiedItemCard.SizePreset.PASS_REWARD)
	cosmetic_claimed.set_reward_state(true, true)
	cosmetic_row.add_child(cosmetic_claimed)
	_add_state_label(cosmetic_claimed, "✓ DIMMED", Color.GRAY)
	
	# === Animation Timer Display ===
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "Next animation in: 5.0s"
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.add_theme_color_override("font_color", Color.CYAN)
	container.add_child(timer_label)
	
	# Instructions
	var info = Label.new()
	info.text = """
	EXPECTED BEHAVIOR:
	• GREEN cards should pulse/sway every 5 seconds
	• RED cards should never move (static with lock chains)
	• GRAY cards should be dimmed to 50% opacity
	• Click any card to test expanded view popup
	
	KEYBOARD CONTROLS:
	• R = Reload test
	• T = Trigger animations manually (force animation)
	• S = Status check (see console for animation states)
	• D = Debug print all card states
	"""
	info.add_theme_font_size_override("font_size", 12)
	container.add_child(info)
	
	print("Created %d test cards for animation tracking" % test_cards.size())

func _add_label(parent: Node, text: String):
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(120, 30)
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)

func _add_state_label(card: Node, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.position = Vector2(0, -25)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	card.add_child(label)

func _process(delta):
	# Update animation check timer
	animation_check_timer += delta
	
	# Check animations every second
	if animation_check_timer >= 1.0:
		animation_check_timer = 0.0
		
		# Debug: Check if any cards are animating
		var animated_count = 0
		for card in test_cards:
			if is_instance_valid(card) and card.has_method("get") and card.get("animation_enabled"):
				animated_count += 1
		
		if animated_count == 0:
			print("WARNING: No cards have animation enabled!")
		else:
			# Print status every 5 seconds
			if int(Time.get_ticks_msec() / 1000) % 5 == 0:
				print("Tracking %d animated cards" % animated_count)
	
	# Update animation timer display
	var timer_label = get_node_or_null("TimerLabel")
	if timer_label and test_cards.size() > 0:
		# Find any animated card to check timer
		for card in test_cards:
			if is_instance_valid(card) and card.has_method("get") and card.get("animation_enabled"):
				var time_until_next = card.animation_interval - card.animation_timer
				timer_label.text = "Next animation in: %.1fs" % time_until_next
				break

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_T:
				# Manually trigger animations on all claimable cards
				print("\nManually triggering animations on %d tracked cards..." % test_cards.size())
				for card in test_cards:
					if is_instance_valid(card):
						if card.animation_enabled:
							card._play_animation()
							print("  - Triggered animation on card")
						else:
							print("  - Card has animation disabled")
			KEY_S:
				# Status check
				print("\n=== ANIMATION STATUS CHECK ===")
				var i = 0
				for card in test_cards:
					if is_instance_valid(card):
						i += 1
						print("Card %d:" % i)
						print("  - animation_enabled: %s" % card.animation_enabled)
						print("  - animation_timer: %.1f" % card.animation_timer)
						print("  - is_claimable: %s" % card.is_claimable)
						print("  - is_processing: %s" % card.is_processing())
				print("================================\n")
			KEY_D:
				# Debug all properties
				print("\n=== DETAILED DEBUG ===")
				for card in test_cards:
					if is_instance_valid(card):
						print("Card: %s" % card)
						print("  Properties:")
						for prop in ["animation_enabled", "animation_timer", "animation_interval", 
									"is_locked", "is_claimed", "is_claimable"]:
							if card.has_method("get"):
								print("    %s: %s" % [prop, card.get(prop)])
				print("======================\n")
