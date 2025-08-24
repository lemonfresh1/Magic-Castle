# RewardClaimPopup.gd - Popup display for single and batch reward claims
# Location: res://Pyramids/scripts/ui/popups/RewardClaimPopup.gd
# Last Updated: August 23, 2025 - Fixed visibility issues, added proper centering for batch
#
# Dependencies:
#   - UIStyleManager - Provides consistent styling
#   - ItemManager (optional) - Gets display names for cosmetics
#   - UnifiedItemCard (optional) - Can display reward items (currently disabled for stability)
#
# Flow: PassLayout claims rewards → Creates this popup → Shows rewards → User clicks Awesome → Closes
#
# Functionality:
#   • Displays single reward claims with icon and description
#   • Displays batch reward claims with grid of icons and summary
#   • Auto-centers on screen and ensures visibility
#   • Sorts rewards by type (cosmetics → stars → XP)
#   • Provides readable summaries of claimed rewards
#   • Handles both dictionary (single) and array (batch) reward data
#
# Signals Out:
#   - confirmed - When user clicks the accept button
#   - cancelled - When popup is closed without confirmation (unused currently)

extends PanelContainer
class_name RewardClaimPopup

# Debug flag
const DEBUG: bool = true

# UI Constants
const SINGLE_ICON_SIZE: int = 80
const BATCH_ICON_SIZE: int = 60
const MAX_BATCH_COLUMNS: int = 5
const POPUP_MIN_WIDTH: int = 400
const POPUP_BATCH_HEIGHT: int = 300
const POPUP_SINGLE_HEIGHT: int = 200

signal confirmed()
signal cancelled()

var reward_data: Dictionary = {}
var all_rewards: Array = []  # For batch claims
var is_batch_claim: bool = false

var title_label: Label
var rewards_container: CenterContainer
var message_label: Label
var accept_button: Button

func _ready():
	_create_popup_structure()
	
	# REMOVE SHADOW: Apply custom panel style without shadow
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE  # White background
	style.set_corner_radius_all(12)  # Rounded corners
	style.border_color = Color("#E5E7EB")  # Light grey border
	style.set_border_width_all(1)
	
	# NO shadow properties set
	add_theme_stylebox_override("panel", style)
	
	# Set both minimum AND custom size to prevent infinite expansion
	custom_minimum_size = Vector2(400, 200)
	size = Vector2(400, 200)  # Set actual size
	clip_contents = true  # Prevent overflow

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
	
	# STORE REFERENCES AS WE CREATE THEM
	
	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_h3"))
	title_label.add_theme_color_override("font_color", UIStyleManager.get_color("primary"))
	vbox.add_child(title_label)
	
	# Rewards container
	rewards_container = CenterContainer.new()
	rewards_container.name = "RewardsContainer"
	rewards_container.custom_minimum_size = Vector2(300, 100)
	vbox.add_child(rewards_container)
	
	# Message label
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	message_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# FIX: Set proper width constraints to prevent 1px width bug
	message_label.custom_minimum_size.x = 350  # Ensure minimum width
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expand to fill container
	vbox.add_child(message_label)
	
	# Button container
	var button_container = CenterContainer.new()
	vbox.add_child(button_container)
	
	accept_button = Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = "Awesome!"
	accept_button.custom_minimum_size = Vector2(120, 36)
	button_container.add_child(accept_button)
	
	UIStyleManager.apply_button_style(accept_button, "primary", "medium")
	accept_button.pressed.connect(_on_accept_pressed)

func setup(rewards: Dictionary, icon_texture: Texture2D = null):
	"""Setup popup for single reward claim"""
	if DEBUG:
		print("[RewardPopup] setup() called with rewards: %s" % str(rewards))
	
	is_batch_claim = false
	reward_data = rewards
	
	# Set fixed size for single reward
	custom_minimum_size = Vector2(400, 250)
	size = Vector2(400, 250)
	
	if title_label:
		title_label.text = "Reward Claimed!"
	
	if rewards_container:
		_clear_container(rewards_container)
		_create_single_reward_display(rewards_container, rewards, icon_texture)
	
	if message_label:
		var reward_name = _get_reward_name(rewards)
		message_label.text = "You received %s!" % reward_name
	
	_center_popup()

func setup_batch(rewards_array: Array):
	"""Setup popup for multiple reward claims"""
	if DEBUG:
		print("[RewardPopup] setup_batch() called with %d rewards" % rewards_array.size())
	
	is_batch_claim = true
	all_rewards = rewards_array
	
	# Set fixed size for batch
	custom_minimum_size = Vector2(450, 400)
	size = Vector2(450, 400)
	
	if title_label:
		title_label.text = "All Rewards Claimed!"
	
	if rewards_container:
		_clear_container(rewards_container)
		
		# Sort rewards
		all_rewards.sort_custom(_sort_rewards_by_type)
		
		# Create grid
		var grid = GridContainer.new()
		grid.columns = min(4, all_rewards.size())
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
				
				# Add to grid first
				grid.add_child(card)
				
				# Setup the card
				card.setup_from_dict(reward, card.SizePreset.PASS_REWARD)
				card.set_reward_state(true, false)
				
				# Override the panel style to remove colored borders
				var style = StyleBoxFlat.new()
				style.bg_color = Color.WHITE
				style.set_corner_radius_all(12)  # Rounded corners
				style.border_color = Color("#E5E7EB")  # Light grey border
				style.set_border_width_all(1)
				
				# Apply the override
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
				message_label.text = "You received: " + ", ".join(summary_parts)
			else:
				message_label.text = "All rewards have been claimed!"
	
	_center_popup()

func _apply_tier_column_style(card: UnifiedItemCard):
	"""Apply the same styling as TierColumn uses for reward cards"""
	var style = StyleBoxFlat.new()
	
	# White background for claimable items (matching TierColumn)
	style.bg_color = Color.WHITE
	
	# Rounded corners (matching pass theme - 12px)
	style.set_corner_radius_all(12)
	
	# IMPORTANT: Light grey border instead of colored borders
	# This matches TierColumn's claimable state exactly
	style.border_color = Color("#E5E7EB")  # Light grey
	style.set_border_width_all(1)  # Thin border
	
	# Force override any previous styling
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color.WHITE  # Full brightness
	
	# Also ensure the card doesn't re-apply its own borders
	# by setting its internal border cache if it exists
	if card.has_method("_get_border_width"):
		card._cached_border_width = 1

func _clear_container(container: Node):
	"""Safely clear all children from a container"""
	for child in container.get_children():
		child.queue_free()

func _create_single_reward_display(container: CenterContainer, rewards: Dictionary, icon_texture: Texture2D = null):
	"""Create icon display for single reward"""
	
	# Load UnifiedItemCard scene for ALL reward types
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	if ResourceLoader.exists(card_scene_path):
		var card_scene = load(card_scene_path)
		var card = card_scene.instantiate()
		
		# Use consistent size
		card.custom_minimum_size = Vector2(SINGLE_ICON_SIZE, SINGLE_ICON_SIZE)
		card.size = Vector2(SINGLE_ICON_SIZE, SINGLE_ICON_SIZE)
		
		# Add to container first
		container.add_child(card)
		
		# Setup the card with reward data
		card.setup_from_dict(rewards, card.SizePreset.PASS_REWARD)
		
		# Set as claimable for animation
		card.set_reward_state(true, false)  # unlocked, not claimed
		
		# Override the panel style to match batch claim (rounded corners, light border)
		var style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(12)  # Rounded corners
		style.border_color = Color("#E5E7EB")  # Light grey border
		style.set_border_width_all(1)
		
		# Apply the override using call_deferred to ensure it happens after setup
		card.call_deferred("add_theme_stylebox_override", "panel", style)

func _create_rewards_grid(container: CenterContainer) -> GridContainer:
	"""Create and configure grid for batch rewards"""
	var grid = GridContainer.new()
	grid.columns = min(MAX_BATCH_COLUMNS, all_rewards.size())
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	container.add_child(grid)
	return grid

func _populate_batch_rewards(grid: GridContainer) -> Dictionary:
	"""Populate grid with reward icons and return totals"""
	var totals = {"stars": 0, "xp": 0, "cosmetics": 0}
	
	for reward in all_rewards:
		# Count totals
		if reward.has("stars"):
			totals.stars += reward.stars
		elif reward.has("xp"):
			totals.xp += reward.xp
		elif reward.has("cosmetic_id"):
			totals.cosmetics += 1
		
		# Create icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(BATCH_ICON_SIZE, BATCH_ICON_SIZE)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.texture = _get_reward_texture(reward, null)
		
		# Add tooltip for clarity
		if reward.has("stars"):
			icon.tooltip_text = "%d Stars" % reward.stars
		elif reward.has("xp"):
			icon.tooltip_text = "%d XP" % reward.xp
		elif reward.has("cosmetic_id"):
			icon.tooltip_text = reward.get("cosmetic_id", "Cosmetic")
		
		grid.add_child(icon)
	
	return totals

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
		# Try specific cosmetic icons
		match reward.cosmetic_type:
			"board":
				var texture = load("res://Pyramids/assets/ui/bp_board.png")
				if texture:
					return texture
			"card_back", "card_front":
				var texture = load("res://Pyramids/assets/items/card_backs/default_back.png")
				if texture:
					return texture
		
		# Fallback to gift icon for any cosmetic
		var texture = load("res://Pyramids/assets/ui/bp_gift.png")
		if texture:
			return texture
	
	# Use provided fallback or create placeholder
	if fallback:
		return fallback
	
	# Last resort: create a simple colored texture
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(0.7, 0.7, 0.7))
	return ImageTexture.create_from_image(image)

func _create_summary_message(totals: Dictionary) -> String:
	"""Create summary message from totals"""
	var summary_parts = []
	
	if totals.stars > 0:
		summary_parts.append("%d Stars" % totals.stars)
	if totals.xp > 0:
		summary_parts.append("%d XP" % totals.xp)
	if totals.cosmetics > 0:
		summary_parts.append("%d Cosmetic%s" % [totals.cosmetics, "s" if totals.cosmetics > 1 else ""])
	
	if summary_parts.size() > 0:
		return "You received: " + ", ".join(summary_parts)
	else:
		return "All rewards have been claimed!"

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
		# Try to get actual item name from ItemManager
		if ItemManager:
			var item = ItemManager.get_item(rewards.cosmetic_id)
			if item:
				return item.display_name
		
		# Fallback to formatted type name
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
	# Get the correct visible viewport
	var viewport_rect = get_viewport().get_visible_rect()
	var viewport_size = viewport_rect.size
	
	# Ensure size is constrained
	var max_width = min(size.x, viewport_size.x - 40)
	var max_height = min(size.y, viewport_size.y - 40)
	size = Vector2(max_width, max_height)
	
	# Center position
	position = (viewport_size - size) / 2
	
	# Ensure on screen
	position.x = max(20, min(position.x, viewport_size.x - size.x - 20))
	position.y = max(20, min(position.y, viewport_size.y - size.y - 20))
	
	# Force visibility
	z_index = 999
	visible = true
	show()
	modulate = Color.WHITE
	
	if DEBUG:
		print("[RewardPopup] Centered at %s, size: %s, viewport: %s" % [position, size, viewport_size])

func _on_accept_pressed():
	"""Handle accept button press"""
	if DEBUG:
		print("[RewardPopup] Accept button pressed, closing popup")
	confirmed.emit()
	queue_free()
