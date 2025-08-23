# RewardClaimPopup.gd - Enhanced popup for single and batch reward claims
# Location: res://Pyramids/scripts/ui/popups/RewardClaimPopup.gd
# Last Updated: Added batch claim support [Date]

extends PanelContainer
class_name RewardClaimPopup

signal confirmed()
signal cancelled()

var reward_data: Dictionary = {}
var all_rewards: Array = []  # For batch claims
var is_batch_claim: bool = false

func _ready():
	_create_popup_structure()
	UIStyleManager.apply_panel_style(self, "reward_popup")
	custom_minimum_size = Vector2(UIStyleManager.get_dimension("modal_min_width"), 200)

func _create_popup_structure():
	"""Create the popup UI structure programmatically"""
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", UIStyleManager.get_spacing("space_4"))
	margin_container.add_theme_constant_override("margin_right", UIStyleManager.get_spacing("space_4"))
	margin_container.add_theme_constant_override("margin_top", UIStyleManager.get_spacing("space_4"))
	margin_container.add_theme_constant_override("margin_bottom", UIStyleManager.get_spacing("space_4"))
	add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_3"))
	margin_container.add_child(vbox)
	
	# Title label
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_h3"))
	title_label.add_theme_color_override("font_color", UIStyleManager.get_color("primary"))
	vbox.add_child(title_label)
	
	# Rewards container (for grid or single icon)
	var rewards_container = CenterContainer.new()
	rewards_container.name = "RewardsContainer"
	rewards_container.custom_minimum_size = Vector2(300, 100)
	vbox.add_child(rewards_container)
	
	# Message label
	var message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	message_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(message_label)
	
	# Button container
	var button_container = CenterContainer.new()
	vbox.add_child(button_container)
	
	var accept_button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Awesome!"
	accept_button.custom_minimum_size = Vector2(120, 36)
	button_container.add_child(accept_button)
	
	UIStyleManager.apply_button_style(accept_button, "primary", "medium")
	accept_button.pressed.connect(_on_accept_pressed)

func setup(rewards: Dictionary, icon_texture: Texture2D = null):
	"""Setup for single reward claim"""
	is_batch_claim = false
	reward_data = rewards
	
	var title_label = find_child("TitleLabel") as Label
	var rewards_container = find_child("RewardsContainer") as CenterContainer
	var message_label = find_child("MessageLabel") as Label
	
	if title_label:
		title_label.text = "Reward Claimed!"
	
	# Clear container safely
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()
		
		# Create single reward display
		if rewards.size() > 0:
			# Try using UnifiedItemCard for consistency
			var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
			if ResourceLoader.exists(card_scene_path):
				var card = load(card_scene_path).instantiate()
				card.setup_from_dict(rewards, UnifiedItemCard.SizePreset.PASS_REWARD)
				card.custom_minimum_size = Vector2(80, 80)
				card.size = Vector2(80, 80)
				rewards_container.add_child(card)
			else:
				# Fallback to simple icon
				var icon = TextureRect.new()
				icon.custom_minimum_size = Vector2(80, 80)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				if icon_texture:
					icon.texture = icon_texture
				rewards_container.add_child(icon)
	
	if message_label:
		var reward_name = _get_reward_name(rewards)
		message_label.text = "You received %s!" % reward_name
	
	_center_popup()

func setup_batch(rewards_array: Array):
	"""Setup for multiple reward claims"""
	is_batch_claim = true
	all_rewards = rewards_array
	
	var title_label = find_child("TitleLabel") as Label
	var rewards_container = find_child("RewardsContainer") as CenterContainer
	var message_label = find_child("MessageLabel") as Label
	
	if title_label:
		title_label.text = "All Rewards Claimed!"
	
	# Clear container safely
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()
		
		await get_tree().process_frame  # Wait for cleanup
		
		# Sort rewards by type
		all_rewards.sort_custom(_sort_rewards_by_type)
		
		# Create grid for rewards
		var grid = GridContainer.new()
		grid.columns = min(5, all_rewards.size())  # Max 5 columns
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		rewards_container.add_child(grid)
		
		# Track totals
		var total_stars = 0
		var total_xp = 0
		var cosmetics_count = 0
		
		# Load UnifiedItemCard scene once
		var card_scene = null
		var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
		if ResourceLoader.exists(card_scene_path):
			card_scene = load(card_scene_path)
		
		for reward in all_rewards:
			# Count totals
			if reward.has("stars"):
				total_stars += reward.stars
			elif reward.has("xp"):
				total_xp += reward.xp
			elif reward.has("cosmetic_id"):
				cosmetics_count += 1
			
			# Create mini display
			if card_scene:
				var card = card_scene.instantiate()
				card.setup_from_dict(reward, UnifiedItemCard.SizePreset.PASS_REWARD)
				card.custom_minimum_size = Vector2(60, 60)
				card.size = Vector2(60, 60)
				grid.add_child(card)
			else:
				# Fallback to simple colored rect
				var placeholder = ColorRect.new()
				placeholder.custom_minimum_size = Vector2(60, 60)
				placeholder.color = Color(0.8, 0.8, 0.8, 1.0)
				grid.add_child(placeholder)
		
		# Build summary message
		if message_label:
			var summary_parts = []
			if total_stars > 0:
				summary_parts.append("%d Stars" % total_stars)
			if total_xp > 0:
				summary_parts.append("%d XP" % total_xp)
			if cosmetics_count > 0:
				summary_parts.append("%d Cosmetic%s" % [cosmetics_count, "s" if cosmetics_count > 1 else ""])
			
			if summary_parts.size() > 0:
				message_label.text = "You received: " + ", ".join(summary_parts)
			else:
				message_label.text = "All rewards have been claimed!"
	
	# Adjust popup size for batch
	custom_minimum_size = Vector2(400, 300)

func _sort_rewards_by_type(a: Dictionary, b: Dictionary) -> bool:
	"""Sort: Cosmetics first, then stars, then XP"""
	var get_type = func(reward: Dictionary) -> int:
		if reward.has("cosmetic_id"): return 0
		elif reward.has("stars"): return 1
		elif reward.has("xp"): return 2
		else: return 3
	
	return get_type.call(a) < get_type.call(b)

func _get_reward_name(rewards: Dictionary) -> String:
	"""Get a readable name for the reward"""
	if rewards.has("stars"):
		return "%d Stars" % rewards.stars
	elif rewards.has("xp"):
		return "%d XP" % rewards.xp
	elif rewards.has("cosmetic_type") and rewards.has("cosmetic_id"):
		# Try to get actual item name from ItemManager
		if ItemManager:
			var item = ItemManager.get_item(rewards.cosmetic_id)
			if item:
				return item.display_name
		
		# Fallback to type
		match rewards.cosmetic_type:
			"emoji": return "a new Emoji"
			"card_skin", "card_back", "card_front": return "a new Card Skin"
			"board", "board_skin": return "a new Board"
			"avatar": return "a new Avatar"
			"frame": return "a new Frame"
			_: return "a new Cosmetic"
	else:
		return "a reward"

func _center_popup():
	"""Center the popup on screen"""
	await get_tree().process_frame
	
	# Get the viewport size for centering
	var viewport_size = get_viewport().size
	
	# Convert Vector2i to Vector2 for math operations
	var viewport_size_v2 = Vector2(viewport_size.x, viewport_size.y)
	
	# Set position to center
	position = (viewport_size_v2 - size) / 2
	
	# Ensure it stays on screen
	position.x = max(20, min(position.x, viewport_size_v2.x - size.x - 20))
	position.y = max(20, min(position.y, viewport_size_v2.y - size.y - 20))
	
	# Make sure it's on top
	z_index = 999
	
	# FIX: MAKE THE POPUP VISIBLE!
	visible = true
	show()  # Explicitly show the popup

func _on_accept_pressed():
	confirmed.emit()
	queue_free()
