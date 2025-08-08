# PassLayout.gd - Controls the season/event pass horizontal scrolling layout
# Location: res://Magic-Castle/scripts/ui/components/PassLayout.gd
# Last Updated: Fixed claim all crash and buy premium button behavior [Date]

extends PanelContainer
class_name PassLayout

signal tier_clicked(tier_number: int)
signal reward_claimed(tier_number: int, is_premium: bool)
signal pass_refreshed()

# Scene references
@export var tier_column_scene: PackedScene = preload("res://Magic-Castle/scenes/ui/components/TierColumn.tscn")

# Node references - Updated to match actual scene structure
@onready var progress_bar: ProgressBar = $VBoxContainer/HeaderContainer/ProgressBar
@onready var progress_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/ProgressLabel
@onready var timer_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/TimerLabel
@onready var pass_level_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/PassLevelLabel
@onready var level_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/Control/LevelLabel
@onready var free_pass_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/Control2/FreePassLabel
@onready var battle_pass_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/Control3/BattlePassLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ContentContainer/ScrollContainer
@onready var margin_container: MarginContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer
@onready var tiers_container: HBoxContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer/TiersContainer
@onready var buy_premium_button: Button = $VBoxContainer/ButtonContainer/BuyPremiumButton
@onready var buy_levels_button: Button = $VBoxContainer/ButtonContainer/BuyLevelsButton
@onready var claim_all_button: Button = $VBoxContainer/ButtonContainer/ClaimAllButton

# Configuration
@export var pass_type: String = "season"  # "season" or "event"
@export var theme_type: String = "battle_pass"  # "battle_pass" or "holiday"
@export var auto_scroll_to_current: bool = true
@export var scroll_speed: float = 500.0  # Pixels per second for smooth scrolling

# State
var tier_columns: Array = []
var current_tier: int = 1
var is_premium: bool = false
var countdown_timer: Timer
var is_setting_up: bool = false  # Prevent concurrent setups
var has_been_setup: bool = false  # Track if initial setup is done

func _ready():
	print("[PassLayout] _ready() called - Instance ID: ", get_instance_id())
	print("[PassLayout] Pass type: ", pass_type, " Theme type: ", theme_type)
	print("[PassLayout] Current tier container children: ", tiers_container.get_child_count())
	
	# Debug label creation
	print("[PassLayout] Creating labels - free_pass_label: ", free_pass_label, " battle_pass_label: ", battle_pass_label)
	
	# Ensure we expand to fill parent
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(580, 280)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Configure scroll container for horizontal scrolling only
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Setup countdown timer
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(_update_timer)
	add_child(countdown_timer)
	countdown_timer.start()
	
	# Setup labels and styling
	_setup_labels()
	_apply_styling()
	
	# Rotate the vertical labels
	print("[PassLayout] Rotating labels to -90 degrees")
	free_pass_label.rotation_degrees = -90
	battle_pass_label.rotation_degrees = -90
	
	# Connect button signals
	buy_premium_button.pressed.connect(_on_buy_premium_pressed)
	buy_levels_button.pressed.connect(_on_buy_levels_pressed)
	claim_all_button.pressed.connect(_on_claim_all_pressed)
	
	# Connect to manager signals based on pass type
	if pass_type == "season" and SeasonPassManager:
		print("[PassLayout] Connecting to SeasonPassManager signals")
		if not SeasonPassManager.tier_unlocked.is_connected(_on_tier_unlocked):
			SeasonPassManager.tier_unlocked.connect(_on_tier_unlocked)
		if not SeasonPassManager.season_level_up.is_connected(_on_level_up):
			SeasonPassManager.season_level_up.connect(_on_level_up)
		if not SeasonPassManager.season_progress_updated.is_connected(_on_season_progress_updated):
			SeasonPassManager.season_progress_updated.connect(_on_season_progress_updated)
	elif pass_type == "holiday" and HolidayEventManager:
		print("[PassLayout] Connecting to HolidayEventManager signals")
		if not HolidayEventManager.tier_unlocked.is_connected(_on_tier_unlocked):
			HolidayEventManager.tier_unlocked.connect(_on_tier_unlocked)
		if not HolidayEventManager.holiday_level_up.is_connected(_on_level_up):
			HolidayEventManager.holiday_level_up.connect(_on_level_up)
		if not HolidayEventManager.holiday_progress_updated.is_connected(_on_holiday_progress_updated):
			HolidayEventManager.holiday_progress_updated.connect(_on_holiday_progress_updated)
	else:
		push_warning("[PassLayout] No manager available for pass type: " + pass_type)
	
	# Update initial labels
	_update_labels()
	
	# DON'T automatically call setup_pass - let parent control this
	print("[PassLayout] _ready() complete - waiting for parent to call setup_pass()")

func _apply_styling():
	"""Apply styling to all components using UIStyleManager"""
	# Style the main panel (transparent background)
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	transparent_style.set_border_width_all(0)
	add_theme_stylebox_override("panel", transparent_style)
	
	# FIX: Ensure VBoxContainer is also transparent
	if has_node("VBoxContainer"):
		var vbox = $VBoxContainer
		vbox.self_modulate = Color(1, 1, 1, 0)  # Fully transparent
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow clicks to pass through
		
		# Remove any potential panel styles
		var empty_style = StyleBoxEmpty.new()
		vbox.add_theme_stylebox_override("panel", empty_style)
		vbox.add_theme_stylebox_override("normal", empty_style)
	
	# Style progress bar
	UIStyleManager.apply_progress_bar_style(progress_bar, theme_type)
	
	# Style buttons
	UIStyleManager.apply_button_style(buy_premium_button, "primary", "medium")
	UIStyleManager.apply_button_style(buy_levels_button, "secondary", "medium")
	UIStyleManager.apply_button_style(claim_all_button, "secondary", "medium")
	
	# Style labels
	progress_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	progress_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	
	timer_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_small"))
	timer_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_600"))
	
	level_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_small"))
	level_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))

func setup_pass():
	"""Initialize the pass with current data"""
	print("\n[PassLayout] setup_pass() called - Instance: ", get_instance_id())
	print("[PassLayout] Pass type: ", pass_type, " Theme type: ", theme_type)
	
	# Prevent concurrent setups
	if is_setting_up:
		print("[PassLayout] Setup already in progress, skipping...")
		return
	
	# Don't setup if not in tree
	if not is_inside_tree():
		print("[PassLayout] Not in tree yet, deferring setup")
		call_deferred("setup_pass")
		return
	
	is_setting_up = true
	
	print("[PassLayout] Starting cleanup...")
	
	# Clear existing columns
	_cleanup_tier_columns()
	
	# Wait for cleanup to complete
	await get_tree().process_frame
	
	# Get data based on pass type
	var tiers_data = []
	var max_tiers = 0
	
	if pass_type == "season":
		tiers_data = SeasonPassManager.get_season_tiers()
		current_tier = SeasonPassManager.get_current_tier()
		is_premium = SeasonPassManager.season_data.has_premium_pass
		max_tiers = SeasonPassManager.MAX_TIER
	elif pass_type == "holiday":
		# FIXED: Use HolidayEventManager for holiday passes
		tiers_data = HolidayEventManager.get_holiday_tiers()
		current_tier = HolidayEventManager.get_current_tier()
		is_premium = HolidayEventManager.holiday_data.has_premium_pass
		max_tiers = HolidayEventManager.MAX_TIER
	else:
		push_warning("Unknown pass type: " + pass_type)
		is_setting_up = false
		return
	
	print("[PassLayout] Creating ", min(tiers_data.size(), max_tiers), " tier columns for ", pass_type, " pass...")
	
	# Create tier columns
	for i in range(min(tiers_data.size(), max_tiers)):
		var tier_data = {}
		if pass_type == "season":
			tier_data = SeasonPassManager.get_tier_data(i + 1)
		else:
			tier_data = HolidayEventManager.get_tier_data(i + 1)
		
		var column = _create_tier_column(tier_data)
		tier_columns.append(column)
	
	print("[PassLayout] Created ", tier_columns.size(), " tier columns")
	
	# Update UI
	_update_progress_display()
	_update_labels()
	_update_button_states()
	
	# Scroll to current tier
	if auto_scroll_to_current:
		call_deferred("_scroll_to_tier", current_tier)
	
	is_setting_up = false
	has_been_setup = true
	pass_refreshed.emit()

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
	# Suppress debug output for individual tier creation
	var column = tier_column_scene.instantiate()
	tiers_container.add_child(column)
	
	# Setup the column
	column.setup(tier_data, theme_type)
	
	# Connect click handling
	column.gui_input.connect(_on_tier_column_input.bind(column))
	
	# Connect reward claim signal
	column.reward_claim_requested.connect(_on_tier_reward_claim_requested)
	
	return column

func _on_tier_column_input(event: InputEvent, column: TierColumn):
	"""Handle clicks on tier columns"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tier_clicked.emit(column.tier_number)
		
		# Check if can claim rewards
		if column.is_unlocked:
			if not column.free_claimed:
				if _try_claim_reward(column.tier_number, false):
					column.claim_reward(true)
					reward_claimed.emit(column.tier_number, false)
			
			if is_premium and not column.premium_claimed:
				if _try_claim_reward(column.tier_number, true):
					column.claim_reward(false)
					reward_claimed.emit(column.tier_number, true)

func _try_claim_reward(tier_number: int, is_premium_reward: bool) -> bool:
	"""Try to claim a tier reward"""
	if pass_type == "season":
		return SeasonPassManager.claim_tier_rewards(tier_number, is_premium_reward)
	elif pass_type == "holiday":
		# FIXED: Use HolidayEventManager
		return HolidayEventManager.claim_tier_rewards(tier_number, is_premium_reward)
	else:
		return false

func _on_tier_reward_claim_requested(tier_number: int, is_free: bool):
	"""Handle reward claim request from tier column popup"""
	if is_free:
		if _try_claim_reward(tier_number, false):
			# Find and update the column
			if tier_number <= tier_columns.size():
				var column = tier_columns[tier_number - 1]
				if is_instance_valid(column):
					column.claim_reward(true)
			reward_claimed.emit(tier_number, false)
	else:
		if _try_claim_reward(tier_number, true):
			# Find and update the column
			if tier_number <= tier_columns.size():
				var column = tier_columns[tier_number - 1]
				if is_instance_valid(column):
					column.claim_reward(false)
			reward_claimed.emit(tier_number, true)

func _setup_labels():
	"""Setup label text based on pass type"""
	print("[PassLayout] _setup_labels() called")
	
	if pass_type == "season":
		level_label.text = "Lv."
		# Free and Battle Pass labels are rotated -90 degrees, so keep them short
		free_pass_label.text = "Free"
		battle_pass_label.text = "Premium"
	else:
		level_label.text = "Tier"
		free_pass_label.text = "Free"
		battle_pass_label.text = "Premium"
	
	print("[PassLayout] Labels set - Level: '%s', Free: '%s', Premium: '%s'" % [level_label.text, free_pass_label.text, battle_pass_label.text])

func _update_labels():
	"""Update dynamic labels"""
	# Update progress based on pass type
	if pass_type == "season":
		var progress = SeasonPassManager.get_tier_progress()
		progress_label.text = "%d/%d SP" % [progress.current_sp, progress.required_sp]
		
		# Update pass level label
		pass_level_label.text = "Level %d" % SeasonPassManager.get_current_tier()
		
	elif pass_type == "holiday":
		# FIXED: Use HolidayEventManager and show HP
		var progress = HolidayEventManager.get_tier_progress()
		progress_label.text = "%d/%d HP" % [progress.current_hp, progress.required_hp]
		
		# Update pass level label
		pass_level_label.text = "Tier %d" % HolidayEventManager.get_current_tier()
	
	# Style the pass level label using UIStyleManager
	pass_level_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	pass_level_label.add_theme_color_override("font_color", UIStyleManager.get_color("white"))
	
	# Add shadow using UIStyleManager's shadow config
	pass_level_label.add_theme_color_override("font_shadow_color", UIStyleManager.shadows.color_medium)
	pass_level_label.add_theme_constant_override("shadow_offset_x", UIStyleManager.shadows.offset_small.x)
	pass_level_label.add_theme_constant_override("shadow_offset_y", UIStyleManager.shadows.offset_small.y)
	
	# Ensure proper alignment
	pass_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _update_timer():
	"""Update countdown timer display"""
	var time_left = ""
	
	if pass_type == "season":
		var days = SeasonPassManager._calculate_days_remaining()
		if days > 1:
			time_left = "%d days left" % days
		elif days == 1:
			time_left = "1 day left"
		else:
			time_left = "Ends today!"
	elif pass_type == "holiday":
		# FIXED: Use HolidayEventManager
		var days = HolidayEventManager._calculate_days_remaining()
		if days > 1:
			time_left = "%d days left" % days
		elif days == 1:
			time_left = "1 day left"
		else:
			time_left = "Ends today!"
	
	timer_label.text = time_left

func _update_progress_display():
	"""Update the progress display for current tier"""
	if pass_type == "season":
		var progress = SeasonPassManager.get_tier_progress()
		if progress.required_sp > 0:
			progress_bar.value = (float(progress.current_sp) / float(progress.required_sp)) * 100.0
		else:
			progress_bar.value = 0
	elif pass_type == "holiday":
		# FIXED: Use HolidayEventManager
		var progress = HolidayEventManager.get_tier_progress()
		if progress.required_hp > 0:
			progress_bar.value = (float(progress.current_hp) / float(progress.required_hp)) * 100.0
		else:
			progress_bar.value = 0

func _update_button_states():
	"""Update button visibility and text based on state"""
	# Buy premium button - show price if not owned
	if is_premium:
		buy_premium_button.visible = false
		buy_levels_button.visible = true
		buy_levels_button.text = "Buy 5 Tiers - 500 Stars"
	else:
		buy_premium_button.visible = true
		buy_premium_button.text = "Buy Premium Pass - 1000 Stars"
		buy_levels_button.visible = false
	
	# Claim all button - check if there are unclaimed rewards
	var has_unclaimed = false
	for column in tier_columns:
		if is_instance_valid(column) and column.is_unlocked and not column.free_claimed:
			has_unclaimed = true
			break
		if is_instance_valid(column) and is_premium and column.is_unlocked and not column.premium_claimed:
			has_unclaimed = true
			break
	
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
			column.setup(SeasonPassManager.get_tier_data(tier), theme_type)

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
	
	if auto_scroll_to_current:
		_scroll_to_tier(current_tier)

func _on_season_progress_updated():
	"""Handle any season progress update"""
	refresh()

func _on_buy_premium_pressed():
	"""Handle buy premium button press"""
	if StarManager.get_balance() < 1000:
		print("[PassLayout] Not enough stars for premium pass (need 1000, have %d)" % StarManager.get_balance())
		return
	
	var success = false
	if pass_type == "season":
		success = SeasonPassManager.purchase_premium_pass()
	elif pass_type == "holiday":
		success = HolidayEventManager.purchase_premium_pass()
	
	if success:
		set_premium_status(true)
		_update_button_states()
		print("[PassLayout] Premium pass purchased successfully!")

func _on_buy_levels_pressed():
	"""Handle buy levels button press"""
	if StarManager.get_balance() < 500:
		print("[PassLayout] Not enough stars for 5 tiers (need 500, have %d)" % StarManager.get_balance())
		return
	
	var success = false
	if pass_type == "season":
		success = SeasonPassManager.purchase_tier_skips(5)
	elif pass_type == "holiday":
		success = HolidayEventManager.purchase_tier_skips(5)
	
	if success:
		print("[PassLayout] Purchased 5 tier skips!")
		refresh()

func _on_claim_all_pressed():
	"""Handle claim all button press"""
	var claimed_any = false
	
	# FIXED: Add bounds checking to prevent crash
	var max_tiers = min(tier_columns.size(), SeasonPassManager.MAX_TIER)
	for i in range(max_tiers):
		if i >= tier_columns.size():
			break
			
		var column = tier_columns[i]
		if not is_instance_valid(column):
			continue
			
		if column.is_unlocked:
			# Claim free rewards
			if not column.free_claimed:
				if _try_claim_reward(i + 1, false):
					column.claim_reward(true)
					reward_claimed.emit(i + 1, false)
					claimed_any = true
			
			# Claim premium rewards if available
			if is_premium and not column.premium_claimed:
				if _try_claim_reward(i + 1, true):
					column.claim_reward(false)
					reward_claimed.emit(i + 1, true)
					claimed_any = true
	
	if claimed_any:
		_update_button_states()
		print("[PassLayout] All available rewards claimed!")

func refresh():
	"""Refresh the entire pass display"""
	print("\n[PassLayout] refresh() called - Stack trace:")
	print_stack()
	
	# Don't call refresh if we're already setting up
	if is_setting_up:
		print("[PassLayout] Already setting up, skipping refresh")
		return
	
	# Don't refresh if not in tree yet
	if not is_inside_tree():
		print("[PassLayout] Not in tree yet, skipping refresh")
		return
	
	# Only refresh if we've been setup at least once
	if has_been_setup:
		setup_pass()
	else:
		print("[PassLayout] Not yet setup, skipping refresh")

func set_premium_status(has_premium: bool):
	"""Update premium pass status"""
	is_premium = has_premium
	
	# Update all columns
	for i in range(tier_columns.size()):
		if is_instance_valid(tier_columns[i]):
			var tier_data = SeasonPassManager.get_tier_data(i + 1)
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

func _on_holiday_progress_updated():
	"""Handle any holiday progress update"""
	refresh()
