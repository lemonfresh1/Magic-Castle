# PassLayout.gd - Manages the Battle Pass UI layout and tier display
# Location: res://Pyramids/scripts/ui/components/PassLayout.gd
# Last Updated: August 23, 2025 - Fixed duplicate claim handler bug, added constants, cleaned debug
#
# Dependencies:
#   - SeasonPassManager/HolidayEventManager (autoload) - Provides pass data and handles claims
#   - TierColumn - Individual tier display component
#   - UIStyleManager - Provides styling
#   - StarManager - Handles currency
#
# Flow: Parent creates this → setup_pass() → Creates TierColumns → User clicks cards
#       → TierColumn handles individual claims → Manager updates → We refresh UI
#
# Functionality:
#   • Creates and manages the horizontal scrolling tier layout
#   • Handles "Claim All" button for batch reward collection
#   • Shows reward popups when items are claimed
#   • Updates progress bar and labels
#   • Manages premium pass purchase
#   • Handles tier skip purchases
#
# Signals In:
#   - tier_unlocked, level_up, progress_updated from Managers
# Signals Out:
#   - tier_clicked, reward_claimed, pass_refreshed to parent

extends PanelContainer
class_name PassLayout

# Debug flag - set to true for testing
const DEBUG: bool = true

# UI Constants
const ICON_SIZE: int = 64
const LABEL_CONTAINER_WIDTH: int = 70
const TIER_HEADER_HEIGHT: int = 50
const REWARD_CARD_HEIGHT: int = 86
const ELEMENT_SPACING: int = 4
const MARGIN_RIGHT: int = 10
const MARGIN_BOTTOM: int = 10

# Click zones for tier column
const HEADER_ZONE_END: int = 50
const FREE_ZONE_END: int = 140
const PREMIUM_ZONE_START: int = 140

signal tier_clicked(tier_number: int)
signal reward_claimed(tier_number: int, is_premium: bool)
signal pass_refreshed()

# Scene references
@export var tier_column_scene: PackedScene = preload("res://Pyramids/scenes/ui/components/TierColumn.tscn")

# Node references - Updated to match actual scene structure
@onready var progress_bar: ProgressBar = $VBoxContainer/HeaderContainer/ProgressBar
@onready var progress_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/ProgressLabel
@onready var timer_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/TimerLabel
@onready var pass_level_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/PassLevelLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ContentContainer/ScrollContainer
@onready var margin_container: MarginContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer
@onready var tiers_container: HBoxContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer/TiersContainer
@onready var buy_premium_button: Button = $VBoxContainer/ButtonContainer/BuyPremiumButton
@onready var buy_levels_button: Button = $VBoxContainer/ButtonContainer/BuyLevelsButton
@onready var claim_all_button: Button = $VBoxContainer/ButtonContainer/ClaimAllButton
@onready var scroll_level_button: Button = $VBoxContainer/ButtonContainer/ScrollLevelButton
@onready var fixed_labels_container: VBoxContainer = $VBoxContainer/ContentContainer/FixedLabelsContainer
@export var auto_scroll_to_current: bool = false  # Disabled by default

# Configuration
@export var pass_type: String = "season"  # "season" or "event"
@export var theme_type: String = "battle_pass"  # "battle_pass" or "holiday"
@export var scroll_speed: float = 500.0  # Pixels per second for smooth scrolling

# State
var tier_columns: Array = []
var current_tier: int = 1
var is_premium: bool = false
var countdown_timer: Timer
var is_setting_up: bool = false  # Prevent concurrent setups
var has_been_setup: bool = false  # Track if initial setup is done
var has_scrolled_to_current: bool = false  # Track if we've done initial scroll
var suppress_scroll: bool = false
var is_batch_claiming: bool = false

func _ready():
	if DEBUG:
		print("[PassLayout] _ready() called - Instance ID: ", get_instance_id())
		print("[PassLayout] Pass type: ", pass_type, " Theme type: ", theme_type)
		print("[PassLayout] Current tier container children: ", tiers_container.get_child_count())
	
	# Ensure we expand to fill parent
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(580, 280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Configure scroll container for horizontal scrolling only
	scroll_container.horizontal_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_NEVER
	scroll_container.vertical_scroll_mode = ScrollContainer.ScrollMode.SCROLL_MODE_SHOW_NEVER
	
	# FIX LEFT MARGIN - Remove the whitespace
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 0)
		margin_container.add_theme_constant_override("margin_right", MARGIN_RIGHT)
		margin_container.add_theme_constant_override("margin_top", 0)
		margin_container.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)
	
	# Setup countdown timer
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(_update_timer)
	add_child(countdown_timer)
	countdown_timer.start()
	
	# Setup labels and styling
	_setup_labels()
	_apply_styling()
	
	# Connect button signals
	buy_premium_button.pressed.connect(_on_buy_premium_pressed)
	buy_levels_button.pressed.connect(_on_buy_levels_pressed)
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	scroll_level_button.pressed.connect(_on_scroll_level_pressed)
	
	# Connect to manager signals based on pass type
	_connect_manager_signals()
	
	# Update initial labels
	_update_labels()
	
	if DEBUG:
		print("[PassLayout] _ready() complete - waiting for parent to call setup_pass()")

func _connect_manager_signals():
	"""Connect to the appropriate manager signals based on pass type"""
	var manager = _get_current_manager()
	
	if pass_type == "season" and SeasonPassManager:
		if DEBUG:
			print("[PassLayout] Connecting to SeasonPassManager signals")
		if not SeasonPassManager.tier_unlocked.is_connected(_on_tier_unlocked):
			SeasonPassManager.tier_unlocked.connect(_on_tier_unlocked)
		if not SeasonPassManager.season_level_up.is_connected(_on_level_up):
			SeasonPassManager.season_level_up.connect(_on_level_up)
		if not SeasonPassManager.season_progress_updated.is_connected(_on_progress_updated):
			SeasonPassManager.season_progress_updated.connect(_on_progress_updated)
	elif pass_type == "holiday" and HolidayEventManager:
		if DEBUG:
			print("[PassLayout] Connecting to HolidayEventManager signals")
		if not HolidayEventManager.tier_unlocked.is_connected(_on_tier_unlocked):
			HolidayEventManager.tier_unlocked.connect(_on_tier_unlocked)
		if not HolidayEventManager.holiday_level_up.is_connected(_on_level_up):
			HolidayEventManager.holiday_level_up.connect(_on_level_up)
		if not HolidayEventManager.holiday_progress_updated.is_connected(_on_progress_updated):
			HolidayEventManager.holiday_progress_updated.connect(_on_progress_updated)
	else:
		push_warning("[PassLayout] No manager available for pass type: " + pass_type)

func _get_current_manager():
	"""Get the correct manager based on pass type"""
	if pass_type == "season":
		return SeasonPassManager
	else:
		return HolidayEventManager

func _apply_styling():
	"""Apply styling to all components using UIStyleManager"""
	# Get consistent font size for all UI elements
	var standard_font_size = UIStyleManager.get_font_size("size_body")
	
	# Style the main panel (transparent background)
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	transparent_style.set_border_width_all(0)
	add_theme_stylebox_override("panel", transparent_style)
	
	# FIX: Ensure VBoxContainer is also transparent
	if has_node("VBoxContainer"):
		var vbox = $VBoxContainer
		vbox.self_modulate = Color(1, 1, 1, 0)  # Fully transparent
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var empty_style = StyleBoxEmpty.new()
		vbox.add_theme_stylebox_override("panel", empty_style)
		vbox.add_theme_stylebox_override("normal", empty_style)
	
	# Style progress bar
	UIStyleManager.apply_progress_bar_style(progress_bar, theme_type)
	# Grey font with white outline for readability
	progress_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	progress_label.add_theme_color_override("font_outline_color", Color.WHITE)
	progress_label.add_theme_constant_override("outline_size", 1)

	timer_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	timer_label.add_theme_color_override("font_outline_color", Color.WHITE)
	timer_label.add_theme_constant_override("outline_size", 1)
	timer_label.position.x = -150  # Move left

	pass_level_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	pass_level_label.add_theme_color_override("font_outline_color", Color.WHITE)
	pass_level_label.add_theme_constant_override("outline_size", 1)
	pass_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pass_level_label.position.x = 5
	
	# Style buttons with consistent size
	UIStyleManager.apply_button_style(buy_premium_button, "primary", "medium")
	UIStyleManager.apply_button_style(buy_levels_button, "secondary", "medium")
	UIStyleManager.apply_button_style(claim_all_button, "secondary", "medium")
	UIStyleManager.apply_button_style(scroll_level_button, "secondary", "medium")
	
	# Ensure button font sizes are consistent
	var button_font_size = standard_font_size
	buy_premium_button.add_theme_font_size_override("font_size", button_font_size)
	buy_levels_button.add_theme_font_size_override("font_size", button_font_size)
	claim_all_button.add_theme_font_size_override("font_size", button_font_size)
	scroll_level_button.add_theme_font_size_override("font_size", button_font_size)

func setup_pass():
	"""Initialize the pass with current data"""
	if DEBUG:
		print("\n[PassLayout] ============================================")
		print("[PassLayout] setup_pass() called - Instance: ", get_instance_id())
		print("[PassLayout] Pass type: ", pass_type, " Theme type: ", theme_type)
		print("[PassLayout] Call Stack:")
		var stack = get_stack()
		for i in range(min(5, stack.size())):  # Show last 5 calls
			var frame = stack[i]
			print("  -> %s:%d in %s()" % [frame.source, frame.line, frame.function])
		print("[PassLayout] ============================================")
	
	# Prevent concurrent setups
	if is_setting_up:
		if DEBUG:
			print("[PassLayout] Setup already in progress, skipping...")
		return
	
	# Don't setup if not in tree
	if not is_inside_tree():
		if DEBUG:
			print("[PassLayout] Not in tree yet, deferring setup")
		call_deferred("setup_pass")
		return
	
	is_setting_up = true
	
	if DEBUG:
		print("[PassLayout] Starting cleanup...")
	
	# Clear existing columns
	_cleanup_tier_columns()
	
	# Wait for cleanup to complete
	await get_tree().process_frame
	
	# Get data based on pass type
	var manager = _get_current_manager()
	var tiers_data = []
	var max_tiers = 0
	
	if pass_type == "season":
		tiers_data = SeasonPassManager.get_season_tiers()
		current_tier = SeasonPassManager.get_current_tier()
		is_premium = SeasonPassManager.season_data.has_premium_pass
		max_tiers = SeasonPassManager.MAX_TIER
	elif pass_type == "holiday":
		tiers_data = HolidayEventManager.get_holiday_tiers()
		current_tier = HolidayEventManager.get_current_tier()
		is_premium = HolidayEventManager.holiday_data.has_premium_pass
		max_tiers = HolidayEventManager.MAX_TIER
	else:
		push_warning("Unknown pass type: " + pass_type)
		is_setting_up = false
		return
	
	if DEBUG:
		print("[PassLayout] Creating ", min(tiers_data.size(), max_tiers), " tier columns for ", pass_type, " pass...")
	
	# Create tier columns
	for i in range(min(tiers_data.size(), max_tiers)):
		var tier_data = manager.get_tier_data(i + 1) if pass_type == "season" else manager.get_tier_data(i + 1)
		var column = _create_tier_column(tier_data)
		tier_columns.append(column)
	
	if DEBUG:
		print("[PassLayout] Created ", tier_columns.size(), " tier columns")
	
	# Update UI
	_update_progress_display()
	_update_labels()
	_update_button_states()
	
	is_setting_up = false
	has_been_setup = true
	pass_refreshed.emit()
	
	# Only scroll if not suppressed AND auto_scroll is true
	if auto_scroll_to_current and not has_scrolled_to_current and not suppress_scroll:
		call_deferred("_scroll_to_tier", current_tier)
		has_scrolled_to_current = true

func _cleanup_tier_columns():
	"""Properly cleanup existing tier columns"""
	# Clear array references first
	for column in tier_columns:
		if is_instance_valid(column) and column.get_parent() == tiers_container:
			tiers_container.remove_child(column)
			column.queue_free()
	tier_columns.clear()
	
	# Also clean any orphaned children
	for child in tiers_container.get_children():
		tiers_container.remove_child(child)
		child.queue_free()

func _create_tier_column(tier_data: Dictionary) -> TierColumn:
	"""Create and setup a tier column"""
	var column = tier_column_scene.instantiate()
	tiers_container.add_child(column)
	
	# Setup the column
	column.setup(tier_data, theme_type)
	
	# Connect click handling for tier selection only (not claiming)
	column.gui_input.connect(_on_tier_column_input.bind(column))
	
	# Connect reward claim signal for popup notification
	column.reward_claim_requested.connect(_on_tier_reward_claim_requested)
	
	return column

func _on_tier_column_input(event: InputEvent, column: TierColumn):
	"""Handle clicks on tier columns"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tier_clicked.emit(column.tier_number)
		
		# Get the click position relative to the column
		var local_pos = column.get_local_mouse_position()
		
		if DEBUG:
			print("[PassLayout] Click at Y position: %d in tier %d" % [local_pos.y, column.tier_number])
		
		# Determine which card was clicked based on Y position
		if local_pos.y < HEADER_ZONE_END:
			# Clicked on header, do nothing
			return
		elif local_pos.y < FREE_ZONE_END:
			# Clicked on FREE card
			if column.is_unlocked and not column.free_claimed and column.free_reward_data.size() > 0:
				if DEBUG:
					print("[PassLayout] Claiming FREE reward for tier %d" % column.tier_number)
				var manager = _get_current_manager()
				if manager.claim_tier_rewards(column.tier_number, true, false):
					column.claim_reward(true)
					reward_claimed.emit(column.tier_number, false)
					print("[PassLayout] Successfully claimed FREE tier %d" % column.tier_number)
					# FIXED: Show popup for free reward
					_show_claim_popup([column.free_reward_data], column.tier_number, true)
		else:
			# Clicked on PREMIUM card
			if column.is_unlocked and is_premium and not column.premium_claimed and column.premium_reward_data.size() > 0:
				if DEBUG:
					print("[PassLayout] Claiming PREMIUM reward for tier %d" % column.tier_number)
				var manager = _get_current_manager()
				if manager.claim_tier_rewards(column.tier_number, false, true):
					column.claim_reward(false)
					reward_claimed.emit(column.tier_number, true)
					print("[PassLayout] Successfully claimed PREMIUM tier %d" % column.tier_number)
					# FIXED: Show popup for premium reward
					_show_claim_popup([column.premium_reward_data], column.tier_number, false)

func _try_claim_reward(tier_number: int, is_premium_reward: bool) -> bool:
	"""Try to claim a tier reward through the appropriate manager"""
	if DEBUG:
		print("[PassLayout] _try_claim_reward: tier %d, premium: %s, pass_type: %s" % 
			[tier_number, is_premium_reward, pass_type])
	
	var manager = _get_current_manager()
	# Use the new claim signature with separate free/premium flags
	var result = manager.claim_tier_rewards(tier_number, not is_premium_reward, is_premium_reward)
	
	if DEBUG:
		print("[PassLayout] _try_claim_reward result: %s" % result)
	return result

func _on_tier_reward_claim_requested(tier_number: int, is_free: bool):
	"""Handle reward claim request from tier column popup confirmation"""
	# This is called after the popup is confirmed
	# The actual claiming happens in TierColumn's click handlers
	reward_claimed.emit(tier_number, not is_free)

func _setup_labels():
	"""Setup icon indicators for level and tracks"""
	if DEBUG:
		print("[PassLayout] Setting up icon indicators")
	
	# Clear any existing children
	for child in fixed_labels_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Container setup
	fixed_labels_container.custom_minimum_size = Vector2(LABEL_CONTAINER_WIDTH, 0)
	fixed_labels_container.add_theme_constant_override("separation", ELEMENT_SPACING)
	
	# Create three containers for the icons
	var level_container = Control.new()
	level_container.name = "LevelIconContainer"
	level_container.custom_minimum_size = Vector2(LABEL_CONTAINER_WIDTH, TIER_HEADER_HEIGHT)
	
	var free_container = Control.new()
	free_container.name = "FreeIconContainer"
	free_container.custom_minimum_size = Vector2(LABEL_CONTAINER_WIDTH, REWARD_CARD_HEIGHT)
	
	var premium_container = Control.new()
	premium_container.name = "PremiumIconContainer"
	premium_container.custom_minimum_size = Vector2(LABEL_CONTAINER_WIDTH, REWARD_CARD_HEIGHT)
	
	# Add containers to fixed labels
	fixed_labels_container.add_child(level_container)
	fixed_labels_container.add_child(free_container)
	fixed_labels_container.add_child(premium_container)
	
	# Create level icon
	var level_icon = TextureRect.new()
	level_icon.name = "LevelIcon"
	level_icon.texture = load("res://Pyramids/assets/ui/bp_lvl.png")
	level_icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	level_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	level_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	level_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	
	level_container.add_child(level_icon)
	level_icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	level_icon.set_position(Vector2(0, 3))
	
	# Create gift icon
	var gift_icon = TextureRect.new()
	gift_icon.name = "GiftIcon"
	gift_icon.texture = load("res://Pyramids/assets/ui/bp_gift.png")
	gift_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	gift_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gift_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	gift_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	
	free_container.add_child(gift_icon)
	gift_icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	gift_icon.set_position(Vector2(0, 33))
	
	# Create crown icon
	var crown_icon = TextureRect.new()
	crown_icon.name = "CrownIcon"
	crown_icon.texture = load("res://Pyramids/assets/ui/bp_crown.png")
	crown_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	crown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	crown_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	crown_icon.modulate = Color("#FFD700")
	
	premium_container.add_child(crown_icon)
	crown_icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	crown_icon.set_position(Vector2(0, 33))
	
	if DEBUG:
		print("[PassLayout] Icon indicators created")

func _update_labels():
	"""Update dynamic labels"""
	var manager = _get_current_manager()
	
	# Update progress based on pass type
	if pass_type == "season":
		var progress = SeasonPassManager.get_tier_progress()
		progress_label.text = "%d/%d SP" % [progress.current_sp, progress.required_sp]
		pass_level_label.text = "Level %d" % SeasonPassManager.get_current_tier()
		scroll_level_button.text = "Scroll to Level %d" % current_tier
	elif pass_type == "holiday":
		var progress = HolidayEventManager.get_tier_progress()
		progress_label.text = "%d/%d HP" % [progress.current_hp, progress.required_hp]
		pass_level_label.text = "Tier %d" % HolidayEventManager.get_current_tier()
		scroll_level_button.text = "Scroll to Tier %d" % current_tier

func _update_timer():
	"""Update countdown timer display"""
	var manager = _get_current_manager()
	
	if manager.has_method("get_seconds_remaining"):
		var total_seconds = manager.get_seconds_remaining()
		
		# Calculate components
		var days = int(total_seconds / 86400)
		var hours = int(total_seconds / 3600) % 24
		var minutes = int(total_seconds / 60) % 60
		var seconds = int(total_seconds) % 60
		
		# Format as "XX days, HH:MM:SS left"
		if days > 0:
			timer_label.text = "%d days, %02d:%02d:%02d left" % [days, hours, minutes, seconds]
		else:
			timer_label.text = "%02d:%02d:%02d left" % [hours, minutes, seconds]
	else:
		timer_label.text = "90 days left"  # Fallback

func _update_progress_display():
	"""Update the progress display for current tier"""
	var manager = _get_current_manager()
	
	if pass_type == "season":
		var progress = SeasonPassManager.get_tier_progress()
		if progress.required_sp > 0:
			progress_bar.value = (float(progress.current_sp) / float(progress.required_sp)) * 100.0
		else:
			progress_bar.value = 0
	elif pass_type == "holiday":
		var progress = HolidayEventManager.get_tier_progress()
		if progress.required_hp > 0:
			progress_bar.value = (float(progress.current_hp) / float(progress.required_hp)) * 100.0
		else:
			progress_bar.value = 0

func _update_button_states():
	"""Update button visibility and text based on state"""
	var manager = _get_current_manager()
	
	# Buy premium/levels buttons
	if is_premium:
		buy_premium_button.visible = false
		buy_levels_button.visible = true
		buy_levels_button.text = "Buy %d Tiers - %d Stars" % [manager.TIER_SKIP_BUNDLE_SIZE, manager.TIER_SKIP_COST_PER_5]
	else:
		buy_premium_button.visible = true
		buy_premium_button.text = "Buy Premium Pass - %d Stars" % manager.PREMIUM_PASS_COST
		buy_levels_button.visible = false
	
	# Scroll button - always visible
	scroll_level_button.visible = true
	
	# Claim all button - check if there are unclaimed rewards
	var has_unclaimed = false
	for column in tier_columns:
		if is_instance_valid(column) and column.is_unlocked:
			if not column.free_claimed:
				has_unclaimed = true
				break
			if is_premium and not column.premium_claimed:
				has_unclaimed = true
				break
	
	claim_all_button.visible = has_unclaimed
	claim_all_button.disabled = not has_unclaimed

func _scroll_to_tier(tier_number: int):
	"""Scroll to show a specific tier"""
	if tier_number < 1 or tier_number > tier_columns.size():
		return
	
	var column = tier_columns[tier_number - 1]
	if not column or not is_instance_valid(column):
		return
	
	# Calculate scroll position to center the tier
	var column_x = column.global_position.x - tiers_container.global_position.x
	var scroll_width = scroll_container.size.x
	var target_scroll = column_x - (scroll_width / 2) + (column.size.x / 2)
	
	# Animate scroll
	var tween = create_tween()
	tween.tween_property(scroll_container, "scroll_horizontal", int(target_scroll), 0.5)

func _on_tier_unlocked(tier: int, rewards: Dictionary):
	"""Handle tier unlock from manager"""
	if tier > 0 and tier <= tier_columns.size():
		var column = tier_columns[tier - 1]
		if is_instance_valid(column):
			column.is_unlocked = true
			var manager = _get_current_manager()
			column.setup(manager.get_tier_data(tier), theme_type)

func _on_level_up(new_level: int):
	"""Handle level up"""
	current_tier = new_level
	_update_labels()
	_update_progress_display()
	
	# Update current tier visual
	for i in range(tier_columns.size()):
		var column = tier_columns[i]
		if is_instance_valid(column):
			column.set_current(i + 1 == current_tier)

func _on_progress_updated():
	"""Handle any progress update from managers"""
	refresh()

func _on_buy_premium_pressed():
	"""Handle buy premium button press"""
	var manager = _get_current_manager()
	
	if StarManager.get_balance() < manager.PREMIUM_PASS_COST:
		print("[PassLayout] Not enough stars for premium pass (need %d, have %d)" % 
			[manager.PREMIUM_PASS_COST, StarManager.get_balance()])
		return
	
	var success = manager.purchase_premium_pass()
	
	if success:
		set_premium_status(true)
		_update_button_states()
		print("[PassLayout] Premium pass purchased successfully!")

func _on_buy_levels_pressed():
	"""Handle buy levels button press"""
	var manager = _get_current_manager()
	
	if StarManager.get_balance() < manager.TIER_SKIP_COST_PER_5:
		print("[PassLayout] Not enough stars for %d tiers (need %d, have %d)" % 
			[manager.TIER_SKIP_BUNDLE_SIZE, manager.TIER_SKIP_COST_PER_5, StarManager.get_balance()])
		return
	
	var success = manager.purchase_tier_skips(manager.TIER_SKIP_BUNDLE_SIZE)
	
	if success:
		print("[PassLayout] Purchased %d tier skips!" % manager.TIER_SKIP_BUNDLE_SIZE)
		refresh()

func _on_claim_all_pressed():
	"""Handle claim all button press"""
	is_batch_claiming = true
	
	print("[DEBUG] Claim All button pressed")
	var claimed_any = false
	var all_claimed_rewards = []  # Collect all rewards for popup
	
	# Determine which manager to use
	var manager = _get_current_manager()
	var max_tiers = manager.MAX_TIER
	max_tiers = min(tier_columns.size(), max_tiers)
	
	print("[DEBUG] Checking %d tiers for claimable rewards" % max_tiers)
	print("[DEBUG] Premium pass status: %s" % is_premium)
	
	for i in range(max_tiers):
		if i >= tier_columns.size():
			break
		
		var column = tier_columns[i]
		if not is_instance_valid(column):
			continue
		
		var tier_num = i + 1
		print("[DEBUG] Checking tier %d - unlocked: %s, free_claimed: %s, premium_claimed: %s" % 
			[tier_num, column.is_unlocked, column.free_claimed, column.premium_claimed])
		
		if column.is_unlocked:
			# Claim free rewards
			if not column.free_claimed and column.free_reward_data.size() > 0:
				print("[DEBUG] Attempting to claim free rewards for tier %d" % tier_num)
				print("[DEBUG] Free reward data: %s" % str(column.free_reward_data))
				
				if _try_claim_reward(tier_num, false):
					column.claim_reward(true)
					reward_claimed.emit(tier_num, false)
					all_claimed_rewards.append(column.free_reward_data.duplicate())
					claimed_any = true
					print("[DEBUG] Successfully claimed free tier %d" % tier_num)
				else:
					print("[DEBUG] Failed to claim free tier %d" % tier_num)
			
			# Claim premium rewards if available
			if is_premium and not column.premium_claimed and column.premium_reward_data.size() > 0:
				print("[DEBUG] Attempting to claim premium rewards for tier %d" % tier_num)
				print("[DEBUG] Premium reward data: %s" % str(column.premium_reward_data))
				
				if _try_claim_reward(tier_num, true):
					column.claim_reward(false)
					reward_claimed.emit(tier_num, true)
					all_claimed_rewards.append(column.premium_reward_data.duplicate())
					claimed_any = true
					print("[DEBUG] Successfully claimed premium tier %d" % tier_num)
				else:
					print("[DEBUG] Failed to claim premium tier %d" % tier_num)
	
	is_batch_claiming = false
	refresh()  # Single refresh at the end
	
	print("[DEBUG] Total rewards claimed: %d" % all_claimed_rewards.size())
	print("[DEBUG] All claimed rewards: %s" % str(all_claimed_rewards))
	
	if claimed_any:
		_update_button_states()
		print("[PassLayout] All available rewards claimed!")
		
		# Show batch popup if we have rewards
		if all_claimed_rewards.size() > 0:
			print("[DEBUG] Showing batch claim popup with %d rewards" % all_claimed_rewards.size())
			_show_batch_claim_popup(all_claimed_rewards)
		else:
			print("[DEBUG] No rewards to show in popup (array empty)")
	else:
		print("[DEBUG] No rewards were claimed")

func _show_claim_popup(rewards: Array, tier_num: int = -1, is_free: bool = true):
	"""Show popup for claimed rewards (single or batch)"""
	if rewards.size() == 0:
		return
	
	print("[DEBUG POPUP] === Creating Popup ===")
	print("[DEBUG POPUP] Rewards to show: %s" % str(rewards))
	print("[DEBUG POPUP] Is batch: %s" % (rewards.size() > 1 or tier_num < 0))
	
	var popup_scene_path = "res://Pyramids/scenes/ui/popups/RewardClaimPopup.tscn"
	
	if not ResourceLoader.exists(popup_scene_path):
		push_error("[PassLayout] RewardClaimPopup scene not found!")
		return
		
	var popup_scene = load(popup_scene_path)
	if not popup_scene:
		push_error("[PassLayout] Failed to load RewardClaimPopup scene!")
		return
		
	var popup = popup_scene.instantiate()
	
	# Create CanvasLayer for guaranteed top rendering
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "RewardPopupLayer"
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(popup)
	
	# Get the actual visible window size
	var visible_rect = get_viewport().get_visible_rect()
	var window_size = visible_rect.size
	var popup_size = Vector2(400, 300)
	
	# Center in the actual visible window
	popup.position = (window_size - popup_size) / 2
	popup.size = popup_size
	
	# Set these BEFORE setup
	popup.visible = true
	popup.modulate = Color.WHITE
	popup.z_index = 999
	
	print("[DEBUG POPUP] Popup node: %s" % popup)
	print("[DEBUG POPUP] Popup position: %s" % popup.position)
	print("[DEBUG POPUP] Popup size: %s" % popup.size)
	
	# Setup content based on single or batch
	if rewards.size() == 1 and tier_num > 0:
		# Single reward
		var reward_data = rewards[0]
		print("[DEBUG POPUP] Setting up single reward: %s" % str(reward_data))
		
		if popup.has_method("setup"):
			popup.setup(reward_data, null)
			print("[DEBUG POPUP] Called setup()")
	else:
		# Multiple rewards - batch
		print("[DEBUG POPUP] Setting up batch with %d rewards" % rewards.size())
		if popup.has_method("setup_batch"):
			popup.setup_batch(rewards)
			print("[DEBUG POPUP] Called setup_batch()")
	
	# Force to front
	popup.show()
	popup.move_to_front()
	
	# REMOVED: Timer that auto-closes popup
	# The popup will now stay open until user clicks "Awesome!"
	
	# Connect to close popup when button is pressed
	if popup.has_signal("confirmed"):
		popup.confirmed.connect(func():
			print("[DEBUG POPUP] User clicked Awesome!")
			if is_instance_valid(popup):
				popup.queue_free()
			if is_instance_valid(canvas_layer):
				canvas_layer.queue_free()
		)
	
	print("[DEBUG POPUP] === Popup Setup Complete ===")

func _debug_node_tree(node: Node, depth: int):
	"""Recursively print node tree for debugging"""
	var indent = "  ".repeat(depth)
	var info = "%s%s" % [indent, node.name]
	
	if node is Control:
		info += " (visible: %s, size: %s)" % [node.visible, node.size]
	
	# Check for specific UI elements
	if node is Label:
		info += " - Text: '%s'" % node.text
	elif node is Button:
		info += " - Button: '%s'" % node.text
	elif node is TextureRect:
		info += " - Texture: %s" % (node.texture != null)
		
	print("[DEBUG POPUP] %s" % info)
	
	# Only go 3 levels deep to avoid spam
	if depth < 3:
		for child in node.get_children():
			_debug_node_tree(child, depth + 1)

func _show_batch_claim_popup(rewards: Array):
	"""Show popup for batch claimed rewards"""
	_show_claim_popup(rewards, -1, false)  # -1 tier means batch

func _on_scroll_level_pressed():
	"""Handle scroll to current level button"""
	_scroll_to_tier(current_tier)

func refresh():
	"""Refresh the entire pass display"""
	if is_batch_claiming:
		return
		
	# Don't scroll during refresh
	suppress_scroll = true
	
	if is_setting_up:
		return
	
	if not is_inside_tree():
		return
	
	if has_been_setup:
		setup_pass()
	
	suppress_scroll = false

func set_premium_status(has_premium: bool):
	"""Update premium pass status"""
	is_premium = has_premium
	
	# Update all columns
	var manager = _get_current_manager()
	for i in range(tier_columns.size()):
		if is_instance_valid(tier_columns[i]):
			var tier_data = manager.get_tier_data(i + 1)
			tier_data.has_premium_pass = has_premium
			tier_columns[i].setup(tier_data, theme_type)
	
	_update_button_states()

func get_visible_tiers() -> Array:
	"""Get list of currently visible tier numbers"""
	var visible = []
	var scroll_left = scroll_container.scroll_horizontal
	var scroll_right = scroll_left + scroll_container.size.x
	
	for i in range(tier_columns.size()):
		var column = tier_columns[i]
		if is_instance_valid(column):
			var column_left = column.position.x
			var column_right = column_left + column.size.x
			
			if column_right >= scroll_left and column_left <= scroll_right:
				visible.append(i + 1)
	
	return visible
