# PassLayout.gd - Controls the season/event pass horizontal scrolling layout
# Location: res://Magic-Castle/scripts/ui/components/PassLayout.gd
# Last Updated: Created pass layout controller with tier management [Date]

extends PanelContainer
class_name PassLayout

signal tier_clicked(tier_number: int)
signal reward_claimed(tier_number: int, is_premium: bool)
signal pass_refreshed()

# Scene references
@export var tier_column_scene: PackedScene = preload("res://Magic-Castle/scenes/ui/components/TierColumn.tscn")

# Node references
@onready var timer_label: Label = $VBoxContainer/HeaderContainer/TimerLabel
@onready var tier_info_container: Container = $VBoxContainer/TierInfoContainer
@onready var tier_label: Label = $VBoxContainer/TierInfoContainer/TierLabel
@onready var progress_label: Label = $VBoxContainer/TierInfoContainer/PanelContainer/HBoxContainer/ProgressLabel
@onready var progress_icon: TextureRect = $VBoxContainer/TierInfoContainer/PanelContainer/HBoxContainer/TextureRect
@onready var level_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/LevelLabel
@onready var free_pass_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/FreePassLabel
@onready var battle_pass_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/BattlePassLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ContentContainer/ScrollContainer
@onready var tiers_container: HBoxContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer/TiersContainer

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

func _ready():
	# Set size constraints - use full height available
	custom_minimum_size = Vector2(580, 280)  # Nearly full height of 300 minus margins
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Make sure our internal scroll is horizontal only
	if has_node("VBoxContainer/ContentContainer/ScrollContainer"):
		var internal_scroll = get_node("VBoxContainer/ContentContainer/ScrollContainer")
		internal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		internal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Setup countdown timer
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0
	countdown_timer.timeout.connect(_update_timer)
	add_child(countdown_timer)
	countdown_timer.start()
	
	# Setup labels based on pass type
	_setup_labels()
	
	# Apply styling
	UIStyleManager.apply_panel_style(self, "pass_layout")
	
	# Connect to manager signals
	if pass_type == "season" and SeasonPassManager:
		SeasonPassManager.tier_unlocked.connect(_on_tier_unlocked)
		SeasonPassManager.season_level_up.connect(_on_level_up)
	
	# Initialize pass display
	call_deferred("setup_pass")


func setup_pass():
	"""Initialize the pass with current data"""
	# Clear existing columns
	for column in tier_columns:
		column.queue_free()
	tier_columns.clear()
	
	# Get data based on pass type
	var tiers_data = []
	if pass_type == "season":
		tiers_data = SeasonPassManager.get_season_tiers()
		current_tier = SeasonPassManager.get_current_tier()
		is_premium = SeasonPassManager.season_data.has_premium_pass
	else:
		# Event pass data would come from EventManager
		push_warning("Event pass not yet implemented")
		return
	
	# Create tier columns
	for i in range(min(tiers_data.size(), SeasonPassManager.MAX_TIER)):
		var tier_data = SeasonPassManager.get_tier_data(i + 1)
		var column = _create_tier_column(tier_data)
		tier_columns.append(column)
	
	# Update UI
	_update_progress_display()
	_update_labels()
	
	# Scroll to current tier
	if auto_scroll_to_current:
		call_deferred("_scroll_to_tier", current_tier)
	
	pass_refreshed.emit()

func _create_tier_column(tier_data: Dictionary) -> TierColumn:
	"""Create and setup a tier column"""
	var column = tier_column_scene.instantiate()
	tiers_container.add_child(column)
	
	# Setup the column
	column.setup(tier_data, theme_type)
	
	# Connect click handling
	column.gui_input.connect(_on_tier_column_input.bind(column))
	
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
	else:
		# Event pass claim logic
		return false

func _setup_labels():
	"""Setup label text based on pass type"""
	if pass_type == "season":
		level_label.text = "LEVEL"
		free_pass_label.text = "FREE PASS"
		battle_pass_label.text = "BATTLE PASS"
	else:
		level_label.text = "TIER"
		free_pass_label.text = "FREE TRACK"
		battle_pass_label.text = "PREMIUM TRACK"

func _update_labels():
	"""Update dynamic labels"""
	# Update tier label
	if tier_label:
		tier_label.text = "Tier %d" % current_tier
	else:
		push_warning("PassLayout: tier_label is null")
	
	# Update progress based on pass type
	if pass_type == "season":
		var progress = SeasonPassManager.get_tier_progress()
		if progress_label:
			progress_label.text = "%d/%d SP" % [progress.current_sp, progress.required_sp]
		else:
			push_warning("PassLayout: progress_label is null")
		
		# Update progress icon (placeholder logic)
		if progress_icon:
			var icon_path = "res://Magic-Castle/assets/placeholder/food/28_cookies.png"
			if progress.current_sp >= 8:
				icon_path = "res://Magic-Castle/assets/placeholder/food/22_cheesecake.png"
			elif progress.current_sp >= 5:
				icon_path = "res://Magic-Castle/assets/placeholder/food/05_apple_pie.png"
			progress_icon.texture = load(icon_path)
		else:
			push_warning("PassLayout: progress_icon is null")

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
	else:
		# Event timer logic
		time_left = "Event timer"
	
	timer_label.text = time_left

func _update_progress_display():
	"""Update the progress display for current tier"""
	if pass_type == "season":
		var progress = SeasonPassManager.get_tier_progress()
		# Could add a progress bar here
		pass

func _scroll_to_tier(tier_number: int):
	"""Scroll to show a specific tier"""
	if tier_number < 1 or tier_number > tier_columns.size():
		return
	
	var column = tier_columns[tier_number - 1]
	if not column:
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
		column.is_unlocked = true
		column.setup(SeasonPassManager.get_tier_data(tier), theme_type)

func _on_level_up(new_level: int):
	"""Handle level up"""
	current_tier = new_level
	_update_labels()
	
	# Update current tier visual
	for i in range(tier_columns.size()):
		var column = tier_columns[i]
		column.set_current(i + 1 == current_tier)
	
	if auto_scroll_to_current:
		_scroll_to_tier(current_tier)

func refresh():
	"""Refresh the entire pass display"""
	setup_pass()

func set_premium_status(has_premium: bool):
	"""Update premium pass status"""
	is_premium = has_premium
	
	# Update all columns
	for i in range(tier_columns.size()):
		var tier_data = SeasonPassManager.get_tier_data(i + 1)
		tier_data.has_premium_pass = has_premium
		tier_columns[i].setup(tier_data, theme_type)

func get_visible_tiers() -> Array:
	"""Get list of currently visible tier numbers"""
	var visible = []
	var scroll_left = scroll_container.scroll_horizontal
	var scroll_right = scroll_left + scroll_container.size.x
	
	for i in range(tier_columns.size()):
		var column = tier_columns[i]
		var column_left = column.position.x
		var column_right = column_left + column.size.x
		
		if column_right >= scroll_left and column_left <= scroll_right:
			visible.append(i + 1)
	
	return visible
