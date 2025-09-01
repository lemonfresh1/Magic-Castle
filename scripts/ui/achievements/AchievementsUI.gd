# AchievementUI.gd - Main achievement display UI
# Location: res://Pyramids/scripts/ui/achievements/AchievementUI.gd
# Last Updated: Fixed sorting, styling, and auto-selection [2025-08-28]

extends PanelContainer

# Node references matching your scene structure
@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox_container: VBoxContainer = $MarginContainer/VBoxContainer
@onready var filter_button: OptionButton = $MarginContainer/VBoxContainer/HBoxContainer/FilterButton
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer
@onready var achievements_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/AchievementsContainer

# Filter options
enum FilterType {
	PROGRESS_HIGH_LOW,
	PROGRESS_LOW_HIGH,
	TIER_HIGH_LOW,
	TIER_LOW_HIGH,
}

var current_filter: FilterType = FilterType.PROGRESS_HIGH_LOW
var achievement_cards: Array[UnifiedAchievementCard] = []
var pending_level_ups: Array = []
var claim_in_progress: bool = false

var debug_enabled: bool = false
var global_debug: bool = true

func _ready():
	# Apply panel styling
	if UIStyleManager:
		UIStyleManager.apply_panel_style(self, "achievements_ui")
	
	# Setup filter button
	_setup_filter_button()
	
	# Setup scroll container sizing
	if scroll_container:
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(600, 345)
	
	# Ensure the achievements container expands
	if achievements_container:
		achievements_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		achievements_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		achievements_container.add_theme_constant_override("separation", 10)
	
	# Load achievements with default claimable-first sorting
	load_achievements()
	
	# Connect to achievement signals
	if AchievementManager:
		AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
		AchievementManager.achievement_claimed.connect(_on_achievement_claimed)

	if XPManager:
		XPManager.level_up_occurred.connect(_on_level_up_occurred)

func _debug_log(message: String) -> void:
	if debug_enabled and global_debug:
		print("[ACHIEVEMENTUI] %s" % message)

func _setup_filter_button():
	"""Setup the filter dropdown"""
	if not filter_button:
		return
		
	filter_button.clear()
	filter_button.add_item("Progress: High to Low")  # 0
	filter_button.add_item("Progress: Low to High")  # 1
	filter_button.add_item("Tier: High to Low")  # 2
	filter_button.add_item("Tier: Low to High")  # 3
	
	filter_button.selected = 0  # Default to Progress High to Low
	filter_button.item_selected.connect(_on_filter_changed)

func load_achievements():
	"""Load all achievements with proper sorting"""
	# Clear existing cards
	_clear_achievement_list()
	achievement_cards.clear()
	
	# Get all base achievements
	var base_achievements = AchievementManager.get_all_base_achievements()
	
	# Create cards for each achievement
	for base_id in base_achievements:
		var card = _create_achievement_card(base_id)
		if card:
			achievement_cards.append(card)
			achievements_container.add_child(card)
	
	# Add invisible separator at the end
	var bottom_separator = Control.new()
	bottom_separator.custom_minimum_size = Vector2(0, 2)
	bottom_separator.modulate.a = 0
	achievements_container.add_child(bottom_separator)
	
	# Apply default Progress High to Low sorting with claimable on top
	current_filter = FilterType.PROGRESS_HIGH_LOW
	filter_button.selected = 0
	_apply_sorting()
	
	# Auto-select appropriate tier for each card
	for card in achievement_cards:
		_auto_select_tier_for_card(card)

func _create_achievement_card(base_id: String) -> UnifiedAchievementCard:
	"""Create a single achievement card"""
	var card_scene = preload("res://Pyramids/scenes/ui/achievements/UnifiedAchievementCard.tscn")
	if not card_scene:
		push_error("Failed to load UnifiedAchievementCard scene")
		return null
		
	var card = card_scene.instantiate() as UnifiedAchievementCard
	card.setup(base_id, UnifiedAchievementCard.DisplayMode.FULL)
	
	# Connect signals
	card.claim_requested.connect(_on_claim_requested)
	card.tier_selected.connect(_on_tier_selected)
	
	return card

func _auto_select_tier_for_card(card: UnifiedAchievementCard):
	"""Auto-select the appropriate tier for a card"""
	var unlocked_tier = card.unlocked_tier
	var claimed_tier = card.claimed_tier
	
	# Priority: highest claimable tier, otherwise current progress tier
	if unlocked_tier > claimed_tier:
		# Select the highest claimable tier (highest unclaimed)
		card.select_tier(unlocked_tier)
	elif unlocked_tier > 0:
		# Select the current progress tier (next tier to unlock)
		card.select_tier(min(unlocked_tier + 1, 5))
	else:
		# No progress yet, select tier 1
		card.select_tier(1)

func _apply_sorting():
	"""Apply current filter/sort to achievement cards - claimable always on top"""
	# Sort by the selected method (claimable priority is built into each sort function)
	match current_filter:
		FilterType.PROGRESS_HIGH_LOW:
			achievement_cards.sort_custom(_sort_progress_high)
		FilterType.PROGRESS_LOW_HIGH:
			achievement_cards.sort_custom(_sort_progress_low)
		FilterType.TIER_HIGH_LOW:
			achievement_cards.sort_custom(_sort_tier_high)
		FilterType.TIER_LOW_HIGH:
			achievement_cards.sort_custom(_sort_tier_low)
	
	# Re-order children in container, preserving separators
	var index = 1  # Start at 1 to skip top separator
	for card in achievement_cards:
		achievements_container.move_child(card, index)
		index += 1

func _sort_progress_high(a: UnifiedAchievementCard, b: UnifiedAchievementCard) -> bool:
	"""Sort by highest progress first, claimed last"""
	# Claimable always go first
	var a_claimable = a.get_claimable_count() > 0
	var b_claimable = b.get_claimable_count() > 0
	if a_claimable != b_claimable:
		return a_claimable
	
	# Fully claimed always go to bottom
	if a.claimed_tier == 5 and b.claimed_tier != 5:
		return false
	if b.claimed_tier == 5 and a.claimed_tier != 5:
		return true
	
	# Both not fully claimed: sort by progress
	if a.claimed_tier < 5 and b.claimed_tier < 5:
		var a_progress = a.get_progress_for_sorting()
		var b_progress = b.get_progress_for_sorting()
		if abs(a_progress - b_progress) > 0.01:
			return a_progress > b_progress
	
	# Secondary: tier
	return a.get_tier_for_sorting() > b.get_tier_for_sorting()

func _sort_progress_low(a: UnifiedAchievementCard, b: UnifiedAchievementCard) -> bool:
	"""Sort by lowest progress first, claimed last"""
	# Claimable always go first
	var a_claimable = a.get_claimable_count() > 0
	var b_claimable = b.get_claimable_count() > 0
	if a_claimable != b_claimable:
		return a_claimable
	
	# Fully claimed always go to bottom
	if a.claimed_tier == 5 and b.claimed_tier != 5:
		return false
	if b.claimed_tier == 5 and a.claimed_tier != 5:
		return true
	
	# Both not fully claimed: sort by progress
	if a.claimed_tier < 5 and b.claimed_tier < 5:
		var a_progress = a.get_progress_for_sorting()
		var b_progress = b.get_progress_for_sorting()
		if abs(a_progress - b_progress) > 0.01:
			return a_progress < b_progress
	
	# Secondary: tier
	return a.get_tier_for_sorting() < b.get_tier_for_sorting()

func _sort_tier_high(a: UnifiedAchievementCard, b: UnifiedAchievementCard) -> bool:
	"""Sort by highest tier first"""
	# Claimable always go first
	var a_claimable = a.get_claimable_count() > 0
	var b_claimable = b.get_claimable_count() > 0
	if a_claimable != b_claimable:
		return a_claimable
	
	var a_tier = a.get_tier_for_sorting()
	var b_tier = b.get_tier_for_sorting()
	if a_tier != b_tier:
		return a_tier > b_tier
	
	# Secondary: progress
	return a.get_progress_for_sorting() > b.get_progress_for_sorting()

func _sort_tier_low(a: UnifiedAchievementCard, b: UnifiedAchievementCard) -> bool:
	"""Sort by lowest tier first"""
	# Claimable always go first
	var a_claimable = a.get_claimable_count() > 0
	var b_claimable = b.get_claimable_count() > 0
	if a_claimable != b_claimable:
		return a_claimable
	
	var a_tier = a.get_tier_for_sorting()
	var b_tier = b.get_tier_for_sorting()
	if a_tier != b_tier:
		return a_tier < b_tier
	
	# Secondary: progress (excluding claimed)
	if a.claimed_tier < 5 and b.claimed_tier < 5:
		return a.get_progress_for_sorting() > b.get_progress_for_sorting()
	
	return a.claimed_tier < b.claimed_tier

func _on_filter_changed(index: int):
	"""Handle filter option change"""
	match index:
		0: current_filter = FilterType.PROGRESS_HIGH_LOW
		1: current_filter = FilterType.PROGRESS_LOW_HIGH
		2: current_filter = FilterType.TIER_HIGH_LOW
		3: current_filter = FilterType.TIER_LOW_HIGH
	
	_apply_sorting()

func _on_achievement_unlocked(base_id: String, tier: int):
	"""Handle achievement unlock from AchievementManager"""
	# Find and update the card
	for card in achievement_cards:
		if card.achievement_base_id == base_id:
			# Refresh the card
			card.unlocked_tier = AchievementManager.get_unlocked_tier(base_id)
			card.setup(base_id, UnifiedAchievementCard.DisplayMode.FULL)
			
			# Auto-select appropriate tier
			_auto_select_tier_for_card(card)
			break
	
	# Re-apply sorting with claimable on top
	_apply_sorting()

func _on_achievement_claimed(base_id: String, tier: int):
	"""Handle achievement claim from AchievementManager"""
	# Find and update the card
	for card in achievement_cards:
		if card.achievement_base_id == base_id:
			# Update claimed status
			card.claimed_tier = AchievementManager.get_claimed_tier(base_id)
			card.has_claimable = card.claimed_tier < card.unlocked_tier
			
			# Auto-select next tier after claiming
			_auto_select_next_tier_after_claim(card)
			break
	
	# Don't auto-resort to prevent jumping, but update if needed
	if current_filter == FilterType.PROGRESS_HIGH_LOW:
		_apply_sorting()

func _auto_select_next_tier_after_claim(card: UnifiedAchievementCard):
	"""After claiming, auto-select the next appropriate tier"""
	var unlocked_tier = card.unlocked_tier
	var claimed_tier = card.claimed_tier
	
	if unlocked_tier > claimed_tier:
		# Still have claimable tiers, select highest unclaimed
		card.select_tier(unlocked_tier)
	elif unlocked_tier < 5:
		# Select the next tier to work towards
		card.select_tier(unlocked_tier + 1)
	else:
		# All tiers complete, keep on tier 5
		card.select_tier(5)

func _on_level_up_occurred(old_level: int, new_level: int, rewards: Dictionary):
	"""Track ALL level-ups while achievements screen is open"""
	_debug_log("📈 LEVEL UP SIGNAL RECEIVED: %d → %d" % [old_level, new_level])
	
	if visible:
		pending_level_ups.append({
			"old_level": old_level,
			"new_level": new_level,
			"rewards": rewards
		})
		_debug_log("   ✅ Level-up tracked (achievements screen visible)")
		# DON'T show immediately - wait for claim to finish

func _on_claim_requested(base_id: String, tier: int):
	"""Handle claim request from a card - FIXED"""
	_debug_log("========== CLAIM START ==========")
	_debug_log("Claiming %s tier %d" % [base_id, tier])
	
	# DON'T clear if we already have level-ups tracked!
	if pending_level_ups.size() > 0:
		_debug_log("Already have %d level-ups tracked, keeping them" % pending_level_ups.size())
	else:
		pending_level_ups.clear()
	
	claim_in_progress = true
	
	# Update the card display
	for card in achievement_cards:
		if card.achievement_base_id == base_id:
			card.claimed_tier = AchievementManager.get_claimed_tier(base_id)
			card.has_claimable = card.claimed_tier < card.unlocked_tier
			card.setup(base_id, UnifiedAchievementCard.DisplayMode.FULL)
			_auto_select_next_tier_after_claim(card)
			break
	
	_debug_log("Pending level-ups to show: %d" % pending_level_ups.size())
	
	# Show notifications if any
	if pending_level_ups.size() > 0:
		_debug_log("🎉 Showing notification...")
		_show_pending_notifications()
	
	claim_in_progress = false
	_debug_log("========== CLAIM END ==========")

func _on_tier_selected(base_id: String, tier: int):
	"""Handle tier selection from a card"""
	# Could be used for analytics or other features
	pass

func _clear_achievement_list():
	"""Clear all achievement cards from container"""
	if not achievements_container:
		return
		
	for child in achievements_container.get_children():
		child.queue_free()

func refresh():
	"""Refresh the entire achievement display"""
	load_achievements()

func reset_to_default_sorting():
	"""Reset to default claimable-first sorting when returning to screen"""
	current_filter = FilterType.PROGRESS_HIGH_LOW
	filter_button.selected = 0
	_apply_sorting()
	
	# Re-select appropriate tiers
	for card in achievement_cards:
		_auto_select_tier_for_card(card)

# Public API for other systems
func get_claimable_count() -> int:
	"""Get total number of claimable achievement tiers"""
	var count = 0
	for card in achievement_cards:
		count += card.get_claimable_count()
	return count

func claim_all():
	"""Claim all available achievement tiers"""
	for card in achievement_cards:
		var claimable = card.get_claimable_count()
		for i in range(claimable):
			var tier_to_claim = card.claimed_tier + 1
			AchievementManager.claim_achievement_tier(card.achievement_base_id, tier_to_claim)
	
	# Refresh after claiming all
	refresh()

func highlight_new_achievements():
	"""Scroll to and highlight new achievements"""
	for card in achievement_cards:
		if card.new_badge and card.new_badge.visible:
			# Scroll to this card
			await get_tree().process_frame
			var card_position = card.position.y
			scroll_container.scroll_vertical = int(card_position)
			break

# Called when screen becomes visible again
func on_screen_entered():
	"""Called when returning to achievements screen"""
	reset_to_default_sorting()

func _show_pending_notifications():
	"""Show level-up notification if any occurred during achievement claims"""
	if pending_level_ups.size() > 0:
		_debug_log("Showing %d pending level-ups from achievement claims" % pending_level_ups.size())
		
		# Use UnifiedRewardNotification for achievement level-ups
		var notification_path = "res://Pyramids/scenes/ui/dialogs/UnifiedRewardNotification.tscn"
		if ResourceLoader.exists(notification_path):
			var notification = load(notification_path).instantiate()
			get_tree().root.add_child(notification)
			
			# Show level-ups with achievement context
			var context_data = {
				"trigger_source": "achievement",
				"total_stars_earned": 0,
				"total_xp_earned": 0
			}
			
			# Calculate total stars from level-ups
			for level_data in pending_level_ups:
				if level_data.rewards.has("stars"):
					context_data.total_stars_earned += level_data.rewards.stars
			
			# Show the notification
			notification.show_level_ups_with_context(pending_level_ups, context_data)
		else:
			push_error("[AchievementUI] UnifiedRewardNotification scene not found!")
		
		pending_level_ups.clear()
