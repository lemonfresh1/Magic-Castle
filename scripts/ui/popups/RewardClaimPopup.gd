# RewardClaimPopup.gd - Enhanced popup for rewards AND level-ups (Using ThemeConstants)
# Location: res://Pyramids/scripts/ui/popups/RewardClaimPopup.gd
# Last Updated: Replaced UIStyleManager with ThemeConstants

extends PanelContainer
class_name RewardClaimPopup

# Debug flag
const DEBUG: bool = true
var debug_enabled: bool = false
var global_debug: bool = true

# UI Constants
const SINGLE_ICON_SIZE: int = 80
const BATCH_ICON_SIZE: int = 60
const MAX_BATCH_COLUMNS: int = 6
const POPUP_MIN_WIDTH: int = 600
const POPUP_BATCH_HEIGHT: int = 300
const POPUP_SINGLE_HEIGHT: int = 200
const POPUP_WITH_LEVELUP_HEIGHT: int = 350

signal confirmed()
signal cancelled()

var reward_data: Dictionary = {}
var all_rewards: Array = []  # For batch claims
var is_batch_claim: bool = false
var level_up_data: Array = []  # NEW: Store level-up info

var title_label: Label
var level_up_container: VBoxContainer  # NEW: Container for level-up display
var rewards_container: CenterContainer
var message_label: Label
var accept_button: StyledButton  # Changed to StyledButton

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug and DEBUG:
		print("[REWARDCLAIMPOPUP] %s" % message)

func _ready():
	_create_popup_structure()
	
	# Apply custom panel style without shadow
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.border_color = Color("#E5E7EB")
	style.set_border_width_all(1)
	
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(400, 200)
	size = Vector2(400, 200)
	clip_contents = true

func _create_popup_structure():
	"""Create the popup UI structure programmatically"""
	var margin_container = MarginContainer.new()
	if ThemeConstants:
		margin_container.add_theme_constant_override("margin_left", ThemeConstants.spacing.space_4)
		margin_container.add_theme_constant_override("margin_right", ThemeConstants.spacing.space_4)
		margin_container.add_theme_constant_override("margin_top", ThemeConstants.spacing.space_4)
		margin_container.add_theme_constant_override("margin_bottom", ThemeConstants.spacing.space_4)
	else:
		# Fallback values
		margin_container.add_theme_constant_override("margin_left", 16)
		margin_container.add_theme_constant_override("margin_right", 16)
		margin_container.add_theme_constant_override("margin_top", 16)
		margin_container.add_theme_constant_override("margin_bottom", 16)
	add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	if ThemeConstants:
		vbox.add_theme_constant_override("separation", ThemeConstants.spacing.space_3)
	else:
		vbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(vbox)
	
	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ThemeConstants:
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_h3)
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	else:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color("#10b981"))
	vbox.add_child(title_label)
	
	# NEW: Level-up container (above rewards)
	level_up_container = VBoxContainer.new()
	level_up_container.name = "LevelUpContainer"
	level_up_container.visible = false  # Hidden by default
	if ThemeConstants:
		level_up_container.add_theme_constant_override("separation", ThemeConstants.spacing.space_2)
	else:
		level_up_container.add_theme_constant_override("separation", 8)
	vbox.add_child(level_up_container)
	
	# Rewards container
	rewards_container = CenterContainer.new()
	rewards_container.name = "RewardsContainer"
	rewards_container.custom_minimum_size = Vector2(300, 100)
	vbox.add_child(rewards_container)
	
	# Message label
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ThemeConstants:
		message_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
		message_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
	else:
		message_label.add_theme_font_size_override("font_size", 18)
		message_label.add_theme_color_override("font_color", Color("#374151"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.x = 350
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(message_label)
	
	# Button container
	var button_container = CenterContainer.new()
	vbox.add_child(button_container)
	
	accept_button = StyledButton.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Awesome!"
	accept_button.custom_minimum_size = Vector2(120, 36)
	button_container.add_child(accept_button)
	
	accept_button.set_button_style("primary", "medium")
	accept_button.pressed.connect(_on_accept_pressed)

func setup(rewards: Dictionary, icon_texture: Texture2D = null):
	"""Setup popup for single reward claim"""
	_debug_log("setup() called with rewards: %s" % str(rewards))
	
	is_batch_claim = false
	reward_data = rewards
	level_up_data.clear()
	
	# Set fixed size for single reward
	custom_minimum_size = Vector2(400, 250)
	size = Vector2(400, 250)
	
	if title_label:
		title_label.text = "Reward Claimed!"
	
	# Hide level-up container for simple rewards
	if level_up_container:
		level_up_container.visible = false
	
	if rewards_container:
		_clear_container(rewards_container)
		_create_single_reward_display(rewards_container, rewards, icon_texture)
	
	if message_label:
		var reward_name = _get_reward_name(rewards)
		message_label.text = "You received %s!" % reward_name
	
	_center_popup()

func setup_with_level_ups(rewards: Dictionary, level_ups: Array):
	"""NEW: Setup popup for single reward with level-ups"""
	_debug_log("setup_with_level_ups() - Rewards: %s, Level-ups: %d" % [str(rewards), level_ups.size()])
	
	is_batch_claim = false
	reward_data = rewards
	level_up_data = level_ups
	
	# Increase size for level-up display
	custom_minimum_size = Vector2(600, 280)
	size = Vector2(600, 280)
	
	# Update title to reflect level-up
	if title_label:
		if level_ups.size() > 0:
			title_label.text = "Level Up! 🎉"
		else:
			title_label.text = "Reward Claimed!"
	
	# Create level-up display
	if level_up_container and level_ups.size() > 0:
		_create_level_up_display(level_ups)
		level_up_container.visible = true
	
	# Create reward display
	if rewards_container:
		_clear_container(rewards_container)
		_create_single_reward_display(rewards_container, rewards, null)
	
	# Update message
	if message_label:
		var reward_name = _get_reward_name(rewards)
		message_label.text = "You received %s!" % reward_name
	
	_center_popup()

func setup_batch(rewards_array: Array):
	"""Setup popup for multiple reward claims"""
	_debug_log("setup_batch() called with %d rewards" % rewards_array.size())
	
	is_batch_claim = true
	all_rewards = rewards_array
	level_up_data.clear()
	
	# Set fixed size for batch
	custom_minimum_size = Vector2(450, 400)
	size = Vector2(450, 400)
	
	if title_label:
		title_label.text = "All Rewards Claimed!"
	
	# Hide level-up container for simple batch
	if level_up_container:
		level_up_container.visible = false
	
	if rewards_container:
		_clear_container(rewards_container)
		_create_batch_display()
	
	_center_popup()

func setup_batch_with_level_ups(rewards_array: Array, level_ups: Array):
	"""NEW: Setup popup for batch rewards with level-ups"""
	_debug_log("setup_batch_with_level_ups() - %d rewards, %d level-ups" % [rewards_array.size(), level_ups.size()])
	
	is_batch_claim = true
	all_rewards = rewards_array
	level_up_data = level_ups
	
	# Increase size to accommodate level-up display
	custom_minimum_size = Vector2(600, 420)
	size = Vector2(600, 420)
	
	# Update title
	if title_label:
		if level_ups.size() > 0:
			title_label.text = "Level Up & Rewards! 🎉"
		else:
			title_label.text = "All Rewards Claimed!"
	
	# Create level-up display
	if level_up_container and level_ups.size() > 0:
		_create_level_up_display(level_ups)
		level_up_container.visible = true
	
	# Create batch rewards display
	if rewards_container:
		_clear_container(rewards_container)
		_create_batch_display()
	
	_center_popup()

func _create_level_up_display(level_ups: Array):
	"""Create compact level-up display section"""
	_clear_container(level_up_container)
	
	# Create background panel for level-up section
	var level_panel = PanelContainer.new()
	var level_style = StyleBoxFlat.new()
	level_style.bg_color = Color("#FEF3C7")  # Light yellow background
	level_style.set_corner_radius_all(8)
	level_style.border_color = Color("#FCD34D")  # Golden border
	level_style.set_border_width_all(1)
	level_panel.add_theme_stylebox_override("panel", level_style)
	level_up_container.add_child(level_panel)
	
	# COMPACT: Use HBox for side-by-side display
	var level_hbox = HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 20)
	level_panel.add_child(level_hbox)
	
	# Add padding
	var level_margin = MarginContainer.new()
	level_margin.add_theme_constant_override("margin_left", 16)
	level_margin.add_theme_constant_override("margin_right", 16)
	level_margin.add_theme_constant_override("margin_top", 8)
	level_margin.add_theme_constant_override("margin_bottom", 8)
	level_hbox.add_child(level_margin)
	
	var level_content = VBoxContainer.new()
	level_content.add_theme_constant_override("separation", 2)  # Tight spacing
	level_margin.add_child(level_content)
	
	# Line 1: Level progression
	var level_label = Label.new()
	if level_ups.size() == 1:
		level_label.text = "Level %d → Level %d" % [level_ups[0].old_level, level_ups[0].new_level]
	else:
		level_label.text = "Level %d → Level %d" % [level_ups[0].old_level, level_ups[-1].new_level]
	
	if ThemeConstants:
		level_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_title)
	else:
		level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Color("#92400E"))  # Dark amber
	level_content.add_child(level_label)
	
	# Line 2: Combined star rewards
	var total_level_stars = 0
	for level_data in level_ups:
		if level_data.rewards.has("stars"):
			total_level_stars += level_data.rewards.stars
	
	if total_level_stars > 0:
		var star_label = Label.new()
		star_label.text = "Level rewards: Earned %d stars from level ups" % total_level_stars
		if ThemeConstants:
			star_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)
		else:
			star_label.add_theme_font_size_override("font_size", 18)
		star_label.add_theme_color_override("font_color", Color("#B45309"))  # Medium amber
		level_content.add_child(star_label)
	
	# Minimal separator
	var separator = HSeparator.new()
	separator.modulate = Color("#E5E7EB")
	separator.custom_minimum_size.y = 4  # Thin separator
	level_up_container.add_child(separator)

func _create_batch_display():
	"""Create the batch rewards display"""
	# Sort rewards
	all_rewards.sort_custom(_sort_rewards_by_type)
	
	# Create grid
	var grid = GridContainer.new()
	grid.columns = min(6, all_rewards.size())
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	rewards_container.add_child(grid)
	
	# Load UnifiedItemCard scene
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	var card_scene = null
	if ResourceLoader.exists(card_scene_path):
		card_scene = load(card_scene_path)
	
	# Track totals for summary
	var total_stars = 0
	var total_xp = 0
	var cosmetics_count = 0
	
	# Add level-up stars to totals
	for level_data in level_up_data:
		if level_data.rewards.has("stars"):
			total_stars += level_data.rewards.stars
	
	# Create cards for each reward
	for reward in all_rewards:
		# Count totals
		if reward.has("stars"):
			total_stars += reward.stars
		elif reward.has("xp"):
			total_xp += reward.xp
		elif reward.has("cosmetic_id"):
			cosmetics_count += 1
		
		if card_scene:
			var card = card_scene.instantiate()
			card.custom_minimum_size = Vector2(86, 86)
			card.size = Vector2(86, 86)
			
			grid.add_child(card)
			
			card.setup_from_dict(reward, card.SizePreset.PASS_REWARD)
			card.set_reward_state(true, false)
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color.WHITE
			style.set_corner_radius_all(12)
			style.border_color = Color("#E5E7EB")
			style.set_border_width_all(1)
			
			card.call_deferred("add_theme_stylebox_override", "panel", style)
			
			# Add tooltip
			if reward.has("stars"):
				card.tooltip_text = "%d Stars" % reward.stars
			elif reward.has("xp"):
				card.tooltip_text = "%d XP" % reward.xp
			elif reward.has("cosmetic_id"):
				card.tooltip_text = reward.get("cosmetic_id", "Cosmetic").replace("_", " ").capitalize()
	
	# Set summary message
	if message_label:
		var summary_parts = []
		if total_stars > 0:
			summary_parts.append("%d Stars" % total_stars)
		if total_xp > 0:
			summary_parts.append("%d XP" % total_xp)
		if cosmetics_count > 0:
			summary_parts.append("%d Cosmetic%s" % [cosmetics_count, "s" if cosmetics_count > 1 else ""])
		
		if summary_parts.size() > 0:
			message_label.text = "Total received: " + ", ".join(summary_parts)
		else:
			message_label.text = "All rewards have been claimed!"

# Keep all the existing helper methods unchanged...
func _clear_container(container: Node):
	"""Safely clear all children from a container"""
	for child in container.get_children():
		child.queue_free()

func _create_single_reward_display(container: CenterContainer, rewards: Dictionary, icon_texture: Texture2D = null):
	"""Create icon display for single reward"""
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if ResourceLoader.exists(card_scene_path):
		var card_scene = load(card_scene_path)
		var card = card_scene.instantiate()
		
		card.custom_minimum_size = Vector2(SINGLE_ICON_SIZE, SINGLE_ICON_SIZE)
		card.size = Vector2(SINGLE_ICON_SIZE, SINGLE_ICON_SIZE)
		
		container.add_child(card)
		
		card.setup_from_dict(rewards, card.SizePreset.PASS_REWARD)
		card.set_reward_state(true, false)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(12)
		style.border_color = Color("#E5E7EB")
		style.set_border_width_all(1)
		
		card.call_deferred("add_theme_stylebox_override", "panel", style)

func _get_reward_texture(reward: Dictionary, fallback: Texture2D = null) -> Texture2D:
	"""Get appropriate texture for reward type"""
	if reward.has("stars"):
		var texture = load("res://Pyramids/assets/ui/bp_star.png")
		if texture:
			return texture
	elif reward.has("xp"):
		var texture = load("res://Pyramids/assets/ui/bp_xp.png")
		if texture:
			return texture
	elif reward.has("cosmetic_type"):
		match reward.cosmetic_type:
			"board":
				var texture = load("res://Pyramids/assets/ui/bp_board.png")
				if texture:
					return texture
			"card_back", "card_front":
				var texture = load("res://Pyramids/assets/items/card_backs/default_back.png")
				if texture:
					return texture
		
		var texture = load("res://Pyramids/assets/ui/bp_gift.png")
		if texture:
			return texture
	
	if fallback:
		return fallback
	
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.7, 0.7, 0.7))
	return ImageTexture.create_from_image(image)

func _sort_rewards_by_type(a: Dictionary, b: Dictionary) -> bool:
	"""Sort rewards: Cosmetics first, then stars, then XP"""
	var get_priority = func(reward: Dictionary) -> int:
		if reward.has("cosmetic_id"): 
			return 0
		elif reward.has("stars"): 
			return 1
		elif reward.has("xp"): 
			return 2
		else: 
			return 3
	
	return get_priority.call(a) < get_priority.call(b)

func _get_reward_name(rewards: Dictionary) -> String:
	"""Get a readable name for the reward"""
	if rewards.has("stars"):
		return "%d Stars" % rewards.stars
	elif rewards.has("xp"):
		return "%d XP" % rewards.xp
	elif rewards.has("cosmetic_type") and rewards.has("cosmetic_id"):
		if ItemManager:
			var item = ItemManager.get_item(rewards.cosmetic_id)
			if item:
				return item.display_name
		
		match rewards.cosmetic_type:
			"emoji": 
				return "a new Emoji"
			"card_skin", "card_back", "card_front": 
				return "a new Card Skin"
			"board", "board_skin": 
				return "a new Board"
			"avatar": 
				return "a new Avatar"
			"frame": 
				return "a new Frame"
			_: 
				return "a new Cosmetic"
	else:
		return "a reward"

func _center_popup():
	"""Center the popup on screen and ensure visibility"""
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_size = viewport_rect.size
	
	var max_width = min(size.x, viewport_size.x - 40)
	var max_height = min(size.y, viewport_size.y - 40)
	size = Vector2(max_width, max_height)
	
	position = (viewport_size - size) / 2
	
	position.x = max(20, min(position.x, viewport_size.x - size.x - 20))
	position.y = max(20, min(position.y, viewport_size.y - size.y - 20))
	
	z_index = 999
	visible = true
	show()
	modulate = Color.WHITE
	
	_debug_log("Centered at %s, size: %s, viewport: %s" % [position, size, viewport_size])

func _on_accept_pressed():
	"""Handle accept button press"""
	_debug_log("Accept button pressed, closing popup")
	confirmed.emit()
	queue_free()
