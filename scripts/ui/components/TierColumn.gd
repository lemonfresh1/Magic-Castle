# TierColumn.gd - Individual tier column display with reward cards
# Location: res://Pyramids/scripts/ui/components/TierColumn.gd
# Last Updated: Added debug system, replaced print statements
#
# Dependencies:
#   - UnifiedItemCard - Displays individual rewards
#   - SeasonPassManager/HolidayEventManager - Handles claiming logic
#   - UIStyleManager - Provides styling
#   - RewardClaimPopup (scene) - Shows claim confirmation
#
# Flow: PassLayout creates columns → Setup with tier data → Creates UnifiedItemCards
#       → User clicks card → Calls manager claim → Shows popup → Updates visual state
#
# Functionality:
#   • Displays one tier column with free and premium rewards
#   • Creates and manages UnifiedItemCard instances for each reward
#   • Handles click events for claiming rewards
#   • Shows reward popup after successful claim
#   • Shows current tier with special styling
#   • Applies locked/claimed/claimable states to cards
#   • Centers cards properly in column
#
# Signals Out:
#   - reward_claim_requested(tier_number, is_free) - When user wants to claim

extends VBoxContainer
class_name TierColumn

# Debug configuration
var debug_enabled: bool = false
var global_debug: bool = true

# Global counter for debugging
static var total_instances: int = 0
static var active_instances: int = 0

signal reward_claim_requested(tier_number: int, is_free: bool)

# Instance ID for debugging
var instance_id: int = 0
var current_tier_level: int = 1  # Track the actual current tier
var tier_glow_effect: Control = null  # For the glow effect

# Column sizing constants
const COLUMN_WIDTH: int = 95  # Width of each tier column
const COLUMN_HEIGHT: int = 240  # Height for 86x86 cards + header + spacing
const CARD_SIZE: int = 86  # Size of reward cards
const ELEMENT_SPACING: int = 4  # Spacing between elements

# Node references (only header remains from scene)
@onready var tier_header: PanelContainer = $TierHeader
@onready var tier_number_label: Label = $TierHeader/TierNumber

# UnifiedItemCard instances (created programmatically)
var free_reward_card: UnifiedItemCard = null
var premium_reward_card: UnifiedItemCard = null

# Tier data
var tier_number: int = 1
var is_current: bool = false
var is_unlocked: bool = false
var has_premium_pass: bool = false
var free_claimed: bool = false
var premium_claimed: bool = false

var current_theme: String = "battle_pass"

# Reward data storage
var free_reward_data: Dictionary = {}
var premium_reward_data: Dictionary = {}
var popup_scene = preload("res://Pyramids/scenes/ui/popups/RewardClaimPopup.tscn")

func _ready():
	# Track instance creation (always keep for debugging)
	total_instances += 1
	active_instances += 1
	instance_id = total_instances
	
	custom_minimum_size = Vector2(COLUMN_WIDTH, COLUMN_HEIGHT)
	
	# CENTER ALIGNMENT FIX
	alignment = BoxContainer.ALIGNMENT_CENTER
	
	# REDUCE SPACING between elements
	add_theme_constant_override("separation", ELEMENT_SPACING)
	
	# ENSURE NO MARGINS
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 0)
	
	# Remove old nodes if they exist (cleanup from scene)
	if has_node("FreeReward"):
		$FreeReward.queue_free()
	if has_node("PremiumReward"):
		$PremiumReward.queue_free()
	
	# Wait for cleanup
	await get_tree().process_frame
	
	# Apply theme to header
	_style_tier_header()

func _exit_tree():
	"""Track when instances are destroyed"""
	active_instances -= 1

func _create_reward_cards() -> void:
	"""Create UnifiedItemCard instances for rewards"""
	
	var card_scene_path = "res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn"
	
	if not ResourceLoader.exists(card_scene_path):
		push_error("[TierColumn] UnifiedItemCard scene not found at: " + card_scene_path)
		return
	
	var card_scene = load(card_scene_path)
	
	# Create free reward card if it doesn't exist
	if not free_reward_card:
		free_reward_card = card_scene.instantiate()
		free_reward_card.name = "FreeRewardCard"
		free_reward_card.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
		free_reward_card.size = Vector2(CARD_SIZE, CARD_SIZE)
		
		# CENTER THE CARD - THIS IS KEY
		free_reward_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		add_child(free_reward_card)
		
		# Wait for card to be ready
		if not free_reward_card.is_node_ready():
			await free_reward_card.ready
		
		# Connect click signal
		if free_reward_card.has_signal("clicked"):
			free_reward_card.clicked.connect(_on_free_card_clicked)
	
	# Create premium reward card if it doesn't exist
	if not premium_reward_card:
		premium_reward_card = card_scene.instantiate()
		premium_reward_card.name = "PremiumRewardCard"
		premium_reward_card.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
		premium_reward_card.size = Vector2(CARD_SIZE, CARD_SIZE)
		
		# CENTER THE CARD - THIS IS KEY
		premium_reward_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		add_child(premium_reward_card)
		
		# Wait for card to be ready
		if not premium_reward_card.is_node_ready():
			await premium_reward_card.ready
		
		# Connect click signal
		if premium_reward_card.has_signal("clicked"):
			premium_reward_card.clicked.connect(_on_premium_card_clicked)

func setup(tier_data: Dictionary, theme: String = "battle_pass"):
	current_theme = theme
	tier_number = tier_data.get("tier", 1)
	is_current = tier_data.get("is_current", false)
	is_unlocked = tier_data.get("is_unlocked", false)
	has_premium_pass = tier_data.get("has_premium_pass", false)
	free_claimed = tier_data.get("free_claimed", false)
	premium_claimed = tier_data.get("premium_claimed", false)
	
	# Get current tier level from correct manager based on theme
	var manager = _get_current_manager()
	current_tier_level = manager.get_current_tier()
	
	# Debug output for tracking (wrapped)
	if tier_number <= 5:
		debug_log("Tier %d - unlocked: %s, premium: %s, free_claimed: %s, premium_claimed: %s" % 
			[tier_number, is_unlocked, has_premium_pass, free_claimed, premium_claimed])
	
	# Set tier number
	if tier_number_label:
		tier_number_label.text = str(tier_number)
	
	# Store rewards data
	free_reward_data = tier_data.get("free_rewards", {})
	premium_reward_data = tier_data.get("premium_rewards", {})
	
	# Create cards only when first needed
	if not free_reward_card or not premium_reward_card:
		await _create_reward_cards()
	
	# FIX: Ensure cards are centered even if they already exist
	if free_reward_card:
		free_reward_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_setup_unified_card(free_reward_card, free_reward_data, true)
	else:
		push_error("[TierColumn] Free reward card is null!")
	
	if premium_reward_card:
		premium_reward_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_setup_unified_card(premium_reward_card, premium_reward_data, false)
	else:
		push_error("[TierColumn] Premium reward card is null!")
	
	# Apply theme styling with tier state
	_style_tier_header()

func _setup_unified_card(card: UnifiedItemCard, rewards: Dictionary, is_free: bool):
	"""Setup a UnifiedItemCard with reward data"""
	
	# Always show the card
	card.visible = true
	card.modulate = Color.WHITE
	
	# FIX: ALWAYS ensure the card is centered AND positioned correctly
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(CARD_SIZE, CARD_SIZE)
	card.size = Vector2(CARD_SIZE, CARD_SIZE)
	
	# FIX: Set the correct position based on whether it's free or premium
	# This matches the fresh creation positioning
	if is_free:
		card.position = Vector2(4, 77)  # FREE card position
	else:
		card.position = Vector2(4, 167)  # PREMIUM card position
	
	# Convert reward data to proper format for UnifiedItemCard
	var formatted_rewards = _format_reward_data(rewards)
	
	if formatted_rewards.size() > 0:
		# Has rewards - set up normally
		
		# Setup card with reward dictionary and PASS_REWARD preset
		card.setup_from_dict(formatted_rewards, UnifiedItemCard.SizePreset.PASS_REWARD)
		
		# Determine reward state
		var is_claimed = free_claimed if is_free else premium_claimed
		var is_accessible = is_unlocked and (is_free or has_premium_pass)
		
		# Set reward state (controls lock overlay and animations)
		card.set_reward_state(is_accessible, is_claimed)
		
		# Apply pass reward styling
		_apply_pass_reward_style(card, is_accessible, is_claimed)
	else:
		# Empty slot - just show as empty placeholder, NO LOCK
		
		# Setup as empty card with no rewards
		card.setup_from_dict({}, UnifiedItemCard.SizePreset.PASS_REWARD)
		
		# DON'T set as locked - just empty
		card.set_reward_state(false, false)
		
		# Apply empty slot styling
		_apply_empty_slot_style(card)

func _apply_pass_reward_style(card: UnifiedItemCard, is_accessible: bool, is_claimed: bool):
	"""Apply custom styling for pass rewards"""
	var style = StyleBoxFlat.new()
	
	# Get the theme config
	var config = UIStyleManager.battle_pass_style if current_theme == "battle_pass" else UIStyleManager.holiday_style
	
	# Background color based on state
	if is_claimed:
		style.bg_color = Color(0.95, 0.95, 0.95, 1.0)  # Light grey for claimed
		card.modulate = Color(1, 1, 1, 0.6)  # Dim claimed items
	elif is_accessible:
		style.bg_color = Color.WHITE  # White for claimable
		card.modulate = Color.WHITE  # Full brightness
	else:
		# Locked - slightly grey background
		style.bg_color = Color(0.95, 0.95, 0.95, 1.0)  
		card.modulate = Color(1, 1, 1, 0.5)  # Dim locked items
	
	# Rounded corners
	style.set_corner_radius_all(config.get("tier_corner_radius", 12))
	
	# Border based on state
	if is_accessible and not is_claimed:
		# Claimable - green/primary border
		style.border_color = UIStyleManager.get_color("primary") if current_theme == "battle_pass" else Color("#DC2626")
		style.set_border_width_all(2)
	else:
		# Normal border for locked/claimed
		style.border_color = Color("#E5E7EB")
		style.set_border_width_all(1)
	
	card.add_theme_stylebox_override("panel", style)

func _apply_empty_slot_style(card: UnifiedItemCard):
	"""Apply styling for empty slots - visible but subtle"""
	var style = StyleBoxFlat.new()
	
	# Get the theme config
	var config = UIStyleManager.battle_pass_style if current_theme == "battle_pass" else UIStyleManager.holiday_style
	
	# Light grey background - VISIBLE but subtle
	style.bg_color = Color(0.97, 0.97, 0.97, 1.0)  # Light grey, fully opaque
	
	# Rounded corners like other slots
	style.set_corner_radius_all(config.get("tier_corner_radius", 12))
	
	# Subtle border to define the shape
	style.border_color = Color("#F0F0F0")  # Very light grey border
	style.set_border_width_all(1)
	
	card.add_theme_stylebox_override("panel", style)
	
	# Fully opaque to show it exists
	card.modulate = Color(1, 1, 1, 1)

func _format_reward_data(rewards: Dictionary) -> Dictionary:
	"""Format reward data for UnifiedItemCard consumption"""
	var formatted = {}
	
	# Handle different reward structures
	if rewards.has("stars"):
		formatted["stars"] = rewards.stars
		# TODO: [Feature] Update UnifiedItemCard to use bp_star.png sprite
	elif rewards.has("xp"):
		formatted["xp"] = rewards.xp
		# TODO: [Feature] Update UnifiedItemCard to use bp_xp.png sprite
	elif rewards.has("cosmetic_type") and rewards.has("cosmetic_id"):
		formatted["cosmetic_type"] = rewards.cosmetic_type
		formatted["cosmetic_id"] = rewards.cosmetic_id
		# TODO: [Feature] Replace with real cosmetic item sprites
	else:
		# Pass through any other reward types
		formatted = rewards
	
	return formatted

func _style_tier_header():
	"""Style the tier header with state-based colors"""
	var style = StyleBoxFlat.new()
	
	# Transparent background
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(0)
	
	# CRITICAL: Remove ALL content margins to fix centering
	style.set_content_margin_all(0)
	
	# Apply to header
	tier_header.add_theme_stylebox_override("panel", style)
	
	# Get theme color
	var theme_color = Color("#10B981") if current_theme == "battle_pass" else Color("#DC2626")
	
	# Determine tier number color based on state
	var number_color: Color
	if tier_number == current_tier_level:
		# Current tier - full color
		number_color = theme_color
	elif tier_number < current_tier_level:
		# Completed tier - lighter version
		number_color = theme_color.lightened(0.5)
	else:
		# Future tier - grey
		number_color = Color("#9CA3AF")
	
	# Apply color
	tier_number_label.add_theme_color_override("font_color", number_color)
	
	# SAME FONT SIZE FOR ALL - no more size differences
	tier_number_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_large"))
	
	# Ensure label is truly centered
	tier_number_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tier_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Force zero offsets
	tier_number_label.offset_left = 0
	tier_number_label.offset_right = 0
	tier_number_label.offset_top = 0
	tier_number_label.offset_bottom = 0
	
	# Add subtle shadow ONLY for current tier (visual emphasis without size change)
	if tier_number == current_tier_level:
		tier_number_label.add_theme_color_override("font_shadow_color", theme_color.darkened(0.3))
		tier_number_label.add_theme_constant_override("shadow_offset_x", 0)
		tier_number_label.add_theme_constant_override("shadow_offset_y", 1)
	else:
		tier_number_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

func set_current(current: bool):
	is_current = current
	# Could add visual indication for current tier if needed

func claim_reward(is_free: bool):
	"""Called when a reward is claimed - updates visual state"""
	if is_free:
		free_claimed = true
		if free_reward_card:
			free_reward_card.set_reward_state(is_unlocked, true)
	else:
		premium_claimed = true
		if premium_reward_card:
			premium_reward_card.set_reward_state(is_unlocked and has_premium_pass, true)

# === HELPER FUNCTIONS ===

func _get_current_manager():
	"""Get the correct manager based on current theme"""
	if current_theme == "battle_pass":
		return SeasonPassManager
	else:
		return HolidayEventManager

# === CLICK HANDLERS ===

func _on_free_card_clicked():
	"""Handle click on FREE reward card only"""
	if not is_unlocked or free_claimed:
		return
	
	# FIXED: Get correct manager based on theme
	var manager = _get_current_manager()
	
	# Claim ONLY free reward
	var success = manager.claim_tier_rewards(tier_number, true, false)
	if success:
		debug_log("Successfully claimed FREE reward for tier %d" % tier_number)
		# FIXED: Show popup after successful claim
		_show_claim_popup(free_reward_data, true)
		# Update visual state
		claim_reward(true)

func _on_premium_card_clicked():
	"""Handle click on PREMIUM reward card only"""
	if not is_unlocked or premium_claimed:
		return
	
	# FIXED: Get correct manager based on theme
	var manager = _get_current_manager()
	
	if not manager.has_premium_pass():
		# TODO: [Feature] Show purchase prompt for premium pass
		return
	
	# Claim ONLY premium reward
	var success = manager.claim_tier_rewards(tier_number, false, true)
	if success:
		debug_log("Successfully claimed PREMIUM reward for tier %d" % tier_number)
		# FIXED: Show popup after successful claim
		_show_claim_popup(premium_reward_data, false)
		# Update visual state
		claim_reward(false)

func _show_claim_popup(rewards: Dictionary, is_free: bool):
	"""Show the reward claim confirmation popup"""
	var popup = popup_scene.instantiate()
	
	# Add popup to the same parent as the SeasonPassUI
	var season_pass_ui = get_tree().get_nodes_in_group("season_pass_ui")[0] if get_tree().has_group("season_pass_ui") else null
	if season_pass_ui:
		season_pass_ui.add_child(popup)
	else:
		# Fallback: add to the PassLayout's parent
		var pass_layout = get_parent().get_parent().get_parent().get_parent()
		pass_layout.get_parent().add_child(popup)
	
	# Get icon texture from the card
	var icon_texture = null
	# TODO: [Feature] Get actual texture from UnifiedItemCard if needed
	
	popup.setup(rewards, icon_texture)
	popup.confirmed.connect(_on_popup_confirmed.bind(is_free))

func _on_popup_confirmed(is_free: bool):
	"""Handle popup confirmation"""
	# This should trigger the manager to grant ALL rewards in the dict
	reward_claim_requested.emit(tier_number, is_free)

func _add_current_tier_glow():
	"""Add a properly centered glow effect for current tier"""
	# Remove old glow if exists
	if tier_glow_effect:
		tier_glow_effect.queue_free()
	
	# Create glow container
	tier_glow_effect = Control.new()
	tier_glow_effect.name = "TierGlow"
	tier_glow_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add as first child (behind everything)
	add_child(tier_glow_effect)
	move_child(tier_glow_effect, 0)
	
	# Make it exactly the same size as the column
	tier_glow_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# NO OFFSETS - this was the issue
	tier_glow_effect.offset_left = 0
	tier_glow_effect.offset_right = 0
	tier_glow_effect.offset_top = 0
	tier_glow_effect.offset_bottom = 0
	
	# Create the glow effect with draw
	tier_glow_effect.draw.connect(_draw_tier_glow)
	
	# Animate the glow
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(tier_glow_effect, "modulate:a", 0.3, 1.0)
	tween.tween_property(tier_glow_effect, "modulate:a", 0.6, 1.0)

func _draw_tier_glow():
	"""Draw centered glow effect"""
	var theme_color = Color("#10B981") if current_theme == "battle_pass" else Color("#DC2626")
	
	# Draw centered rectangle
	var rect = Rect2(Vector2.ZERO, size)
	
	# Single subtle background
	var glow_color = theme_color
	glow_color.a = 0.08  # Very subtle
	tier_glow_effect.draw_rect(rect, glow_color, true)
	
	# Clean border
	var border_color = theme_color
	border_color.a = 0.2
	tier_glow_effect.draw_rect(rect, border_color, false, 2.0)

func debug_log(message: String) -> void:
	"""Debug logging with component prefix"""
	if debug_enabled and global_debug:
		print("[TIERCOLUMN] %s" % message)
