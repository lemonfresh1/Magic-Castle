# SeasonPassUI.gd - Season pass interface with tiers and missions (FIXED)
# Location: res://Pyramids/scripts/ui/season_pass/SeasonPassUI.gd
# Last Updated: Fixed initialization order to prevent double creation [Date]

extends PanelContainer

signal season_pass_ui_closed

const StyledButton = preload("res://Pyramids/scripts/ui/components/StyledButton.gd")

@onready var tab_container: TabContainer = $MarginContainer/TabContainer
@onready var mission_card_scene = preload("res://Pyramids/scenes/ui/missions/MissionCard.tscn")
@onready var pass_layout_scene = preload("res://Pyramids/scenes/ui/components/PassLayout.tscn")

var filter_mode: String = "all"  # all, completed, open
var pass_layout: PassLayout
var is_initializing: bool = false
var has_been_initialized: bool = false  # Track if we've already initialized
var mission_cards = {}  # {mission_id: card_instance}
var pending_level_ups: Array = []
var claim_in_progress: bool = false


func _ready():
	print("\n[SeasonPassUI] _ready() called - Instance: ", get_instance_id())
	print("[SeasonPassUI] Stack trace:")
	print_stack()
	print("[SeasonPassUI] Parent: ", get_parent(), " Parent's parent: ", get_parent().get_parent() if get_parent() else "none")
	
	# Check if we've already initialized
	if has_been_initialized:
		print("[SeasonPassUI] WARNING: Already initialized! Skipping duplicate _ready() call")
		return
	
	if is_initializing:
		print("[SeasonPassUI] WARNING: Already initializing! Skipping duplicate _ready() call")
		return
	
	# Set flags
	is_initializing = true
	has_been_initialized = true
	
	# Wait for next frame to ensure nodes are ready
	await get_tree().process_frame
	
	custom_minimum_size = Vector2(600, 414)  # Match other UIs
	
	if not tab_container:
		push_error("SeasonPassUI: TabContainer not found!")
		is_initializing = false
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "season_pass_ui")
	
	# Setup all tabs FIRST and wait for completion
	await _initialize_all_tabs()
	
	# NOW connect all signals after tabs are ready
	_connect_all_signals()
	
	# Mark initialization complete
	is_initializing = false
	
	# Finally, populate the current tab
	_populate_current_tab()
	
	if XPManager:
		XPManager.level_up_occurred.connect(_on_level_up_occurred)


func _initialize_all_tabs():
	"""Initialize all tabs and wait for their completion"""
	print("[SeasonPassUI] Starting controlled tab initialization")
	
	# Setup Overview tab
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		print("[SeasonPassUI] Setting up Overview tab")
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)
		await get_tree().process_frame
	
	# Setup Battle Pass tab
	var battle_pass_tab = tab_container.get_node_or_null("Battle Pass")
	if battle_pass_tab:
		print("[SeasonPassUI] Setting up Battle Pass tab")
		await _setup_battle_pass_tab(battle_pass_tab)
		await get_tree().process_frame
	
	# Setup Daily Missions tab
	var daily_missions_tab = tab_container.get_node_or_null("Daily Missions")
	if daily_missions_tab:
		print("[SeasonPassUI] Setting up Daily Missions tab")
		_setup_missions_tab(daily_missions_tab, "daily")
		await get_tree().process_frame
	
	# Setup Weekly Missions tab
	var weekly_missions_tab = tab_container.get_node_or_null("Weekly Missions")
	if weekly_missions_tab:
		print("[SeasonPassUI] Setting up Weekly Missions tab")
		_setup_missions_tab(weekly_missions_tab, "weekly")
		await get_tree().process_frame
	
	print("[SeasonPassUI] All tabs initialized successfully")

func _connect_all_signals():
	"""Connect all signals after tabs are initialized"""
	print("[SeasonPassUI] Connecting signals")
	
	# Connect tab changed signal
	if not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Connect to mission updates
	if UnifiedMissionManager:
		if not UnifiedMissionManager.mission_completed.is_connected(_on_mission_completed):
			UnifiedMissionManager.mission_completed.connect(_on_mission_completed)
		if not UnifiedMissionManager.missions_reset.is_connected(_on_missions_reset):
			UnifiedMissionManager.missions_reset.connect(_on_missions_reset)
	
	# Connect to SeasonPassManager for SP updates
	if SeasonPassManager:
		if not SeasonPassManager.season_points_gained.is_connected(_on_season_points_gained):
			SeasonPassManager.season_points_gained.connect(_on_season_points_gained)
		if not SeasonPassManager.season_progress_updated.is_connected(_on_season_progress_updated):
			SeasonPassManager.season_progress_updated.connect(_on_season_progress_updated)
	
	print("[SeasonPassUI] All signals connected")

func _setup_battle_pass_tab(battle_pass_tab: Control):
	"""Setup the Battle Pass tab with PassLayout directly, no wrapper panel"""
	print("[SeasonPassUI] _setup_battle_pass_tab called")
	
	# Debug current state
	print("[SeasonPassUI] Battle Pass tab children before setup: ", battle_pass_tab.get_child_count())
	for i in range(battle_pass_tab.get_child_count()):
		var child = battle_pass_tab.get_child(i)
		print("  - Child %d: %s (Type: %s, Instance: %s)" % [i, child.name, child.get_class(), child.get_instance_id()])
	
	# Check if PassLayout already exists and is tracked
	if pass_layout and is_instance_valid(pass_layout):
		print("[SeasonPassUI] PassLayout already exists and is valid, using existing")
		return
	
	# Check if PassLayout exists in the scene
	var existing_pass_layout = null
	for child in battle_pass_tab.get_children():
		if child is PassLayout:
			existing_pass_layout = child
			print("[SeasonPassUI] Found existing PassLayout in scene: ", child.get_instance_id())
			break
	
	if existing_pass_layout:
		print("[SeasonPassUI] Using existing PassLayout from scene")
		pass_layout = existing_pass_layout
		
		# Configure the existing PassLayout
		pass_layout.pass_type = "season"
		pass_layout.theme_type = "battle_pass"
		pass_layout.auto_scroll_to_current = true
		
		# Ensure proper anchoring
		pass_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pass_layout.offset_top = 10
		
		# Connect signals if not already connected
		_connect_pass_layout_signals()
		
		# Setup the pass content only if not already setup
		if not pass_layout.has_been_setup:
			await get_tree().process_frame
			pass_layout.setup_pass()
		
		return
	
	# Create new PassLayout only if none exists
	print("[SeasonPassUI] Creating new PassLayout")
	
	# Clear any non-PassLayout children
	for child in battle_pass_tab.get_children():
		if not child is PassLayout:
			print("[SeasonPassUI] Removing child: ", child.name)
			child.queue_free()
	
	# Wait for cleanup
	await get_tree().process_frame
	
	# Create PassLayout
	pass_layout = pass_layout_scene.instantiate()
	battle_pass_tab.add_child(pass_layout)
	print("[SeasonPassUI] Created new PassLayout: ", pass_layout.get_instance_id())
	
	# Configure PassLayout
	pass_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pass_layout.offset_top = 10
	pass_layout.pass_type = "season"
	pass_layout.theme_type = "battle_pass"
	
	# Connect signals
	_connect_pass_layout_signals()
	
	# Wait for PassLayout to be ready
	await get_tree().process_frame
	
	# Setup the pass
	pass_layout.setup_pass()
	
	print("[SeasonPassUI] Battle Pass tab setup complete")

func _connect_pass_layout_signals():
	"""Connect PassLayout signals"""
	if not pass_layout.tier_clicked.is_connected(_on_tier_clicked):
		pass_layout.tier_clicked.connect(_on_tier_clicked)
		print("[SeasonPassUI] Connected tier_clicked signal")
	
	if not pass_layout.reward_claimed.is_connected(_on_reward_claimed):
		pass_layout.reward_claimed.connect(_on_reward_claimed)
		print("[SeasonPassUI] Connected reward_claimed signal")

func _on_season_points_gained(amount: int, source: String):
	"""Handle when season points are gained"""
	print("[SeasonPassUI] SP gained: %d from %s" % [amount, source])
	# Refresh overview if it's the current tab
	if tab_container.current_tab == 0:
		_refresh_overview()
	# Update pass layout if visible
	if tab_container.current_tab == 1 and pass_layout:
		pass_layout.refresh()

func _on_season_progress_updated():
	"""Handle general progress updates"""
	# Refresh current tab
	_populate_current_tab()

func _on_tab_changed(tab_idx: int):
	"""Handle tab changes"""
	# Ignore tab changes during initialization
	if is_initializing:
		print("[SeasonPassUI] Ignoring tab change during initialization")
		return
	
	print("[SeasonPassUI] Tab changed to: ", tab_container.get_tab_title(tab_idx))
	_populate_current_tab()

func _populate_current_tab():
	"""Populate content for the currently active tab"""
	if is_initializing:
		print("[SeasonPassUI] Skipping populate during initialization")
		return
	
	var current_tab_idx = tab_container.current_tab
	var current_tab_name = tab_container.get_tab_title(current_tab_idx)
	var current_tab = tab_container.get_child(current_tab_idx)
	
	print("[SeasonPassUI] Populating tab: ", current_tab_name)
	
	match current_tab_name:
		"Overview":
			_refresh_overview()
		"Battle Pass":
			# Don't recreate PassLayout when switching tabs
			if pass_layout and is_instance_valid(pass_layout) and not pass_layout.is_setting_up:
				pass_layout.refresh()
		"Daily Missions", "Weekly Missions":
			var scroll = current_tab.find_child("ScrollContainer", true, false)
			if scroll:
				var has_content = false
				for child in scroll.get_children():
					if child.name == "MarginContainer":
						has_content = true
						break
				
				if not has_content:
					# First time - create content
					print("No content found, setting up scrollable content")
					await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)
				else:
					# FIXED: Don't recreate, just update existing cards
					print("Content exists, updating mission cards")
					_update_mission_visibility()

func _setup_missions_tab(tab: Control, mission_type: String):
	"""Setup a missions tab with filter button"""
	var filter_button = tab.find_child("FilterButton", true, false)
	if filter_button:
		if filter_button.get_item_count() == 0:
			filter_button.add_item("All")
			filter_button.add_item("Open")
			filter_button.add_item("Completed")
			filter_button.selected = 0
		
		if not filter_button.item_selected.is_connected(_on_filter_changed):
			filter_button.item_selected.connect(_on_filter_changed)
		
		# Apply filter styling with season orange theme color
		UIStyleManager.style_filter_button(filter_button, Color("#FFB75A"))

func _populate_overview_content(vbox: VBoxContainer) -> void:
	"""Content for Overview tab"""
	var season_info = SeasonPassManager.get_season_info()
	var tier_progress = SeasonPassManager.get_tier_progress()
	
	var header = Label.new()
	header.text = season_info.name
	header.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_h2"))
	header.add_theme_color_override("font_color", Color("#FFB75A"))  # Keep season orange theme
	vbox.add_child(header)
	
	# Season stats
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_2"))
	vbox.add_child(stats_container)
	
	var current_tier_label = Label.new()
	current_tier_label.text = "Current Tier: %d / %d" % [season_info.current_tier, SeasonPassManager.MAX_TIER]
	current_tier_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_large"))
	current_tier_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	stats_container.add_child(current_tier_label)
	
	# Show actual SP values
	var sp_label = Label.new()
	sp_label.text = "Total SP: %d" % season_info.total_sp
	sp_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	sp_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_600"))
	stats_container.add_child(sp_label)
	
	var progress_label = Label.new()
	progress_label.text = "Progress: %d / %d SP (%.1f%%)" % [tier_progress.current_sp, tier_progress.required_sp, tier_progress.percentage * 100]
	progress_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	progress_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_600"))
	stats_container.add_child(progress_label)
	
	var premium_status = Label.new()
	premium_status.text = "Battle Pass: %s" % ("ACTIVE" if season_info.has_premium else "FREE")
	premium_status.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body"))
	# Keep conditional coloring for premium status
	if season_info.has_premium:
		premium_status.add_theme_color_override("font_color", Color("#FFD700"))  # Gold for active
	else:
		premium_status.add_theme_color_override("font_color", UIStyleManager.get_color("gray_400"))
	stats_container.add_child(premium_status)
	
	# Add separator
	var separator = HSeparator.new()
	separator.modulate = UIStyleManager.get_color("gray_300")
	vbox.add_child(separator)
	
	# Purchase premium button if not owned
	if not season_info.has_premium:
		var purchase_button = StyledButton.new()
		purchase_button.text = "Unlock Battle Pass - 1000 Stars"
		purchase_button.custom_minimum_size = Vector2(300, 60)
		purchase_button.button_style = "primary"  # Set via property
		purchase_button.button_size = "large"    # Set via property
		purchase_button.pressed.connect(_on_purchase_premium)
		vbox.add_child(purchase_button)

func _populate_missions_content(vbox: VBoxContainer) -> void:
	"""Initial population of missions - only called once per tab"""
	print("=== Initial mission population ===")
	
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 8)
	
	# Clear mission cards tracking
	mission_cards.clear()
	
	# Determine which tab we're in
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	
	# Get all missions for this type
	var missions = UnifiedMissionManager.get_missions_for_system("season_pass", mission_type)
	
	# Sort missions: claimable first, then uncompleted, then claimed
	missions.sort_custom(func(a, b):
		var a_claimable = a.is_completed and not a.is_claimed
		var b_claimable = b.is_completed and not b.is_claimed
		if a_claimable != b_claimable:
			return a_claimable
		if a.is_claimed != b.is_claimed:
			return b.is_claimed
		return false
	)
	
	# Create mission cards
	for mission in missions:
		var card = mission_card_scene.instantiate()
		vbox.add_child(card)
		card.setup(mission, "season")
		
		# Store reference to card
		mission_cards[mission.id] = card
		
		# Connect claim signal
		if card.has_signal("mission_claimed"):
			card.mission_claimed.connect(func(mission_id): 
				claim_in_progress = true
				pending_level_ups.clear()
				UnifiedMissionManager.claim_mission(mission_id, "season_pass") # "season_pass" or "holiday"
				_update_mission_visibility()
				call_deferred("_show_pending_notifications")
				claim_in_progress = false
			)
	
	# Apply initial filter
	_apply_mission_filter()

func _on_tier_clicked(tier_number: int):
	"""Handle tier click from PassLayout"""
	print("Tier %d clicked" % tier_number)

func _on_reward_claimed(tier_number: int, is_premium: bool):
	"""Handle reward claimed from PassLayout"""
	print("Reward claimed - Tier: %d, Premium: %s" % [tier_number, is_premium])
	
	# Refresh overview if visible
	if tab_container.current_tab == 0:
		_refresh_overview()

func _on_purchase_premium():
	"""Handle premium pass purchase"""
	if SeasonPassManager.purchase_premium_pass():
		print("Premium pass purchased!")
		# Update pass layout
		if pass_layout:
			pass_layout.set_premium_status(true)
		# Refresh overview
		_refresh_overview()
	else:
		print("Failed to purchase premium pass - not enough stars")

func _refresh_overview():
	"""Refresh the overview tab content"""
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)

func _on_filter_changed(index: int):
	"""Handle filter change without recreating content"""
	print("Filter changed to index: ", index)
	match index:
		0:
			filter_mode = "all"
		1:
			filter_mode = "open"
		2:
			filter_mode = "completed"
	
	print("New filter mode: ", filter_mode)
	_apply_mission_filter()  # Just apply filter, don't recreate

func _apply_mission_filter():
	"""Show/hide mission cards based on current filter"""
	print("Applying filter: ", filter_mode)
	
	var visible_count = 0
	
	# Get current missions data
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	var missions = UnifiedMissionManager.get_missions_for_system("season_pass", mission_type)
	
	# Update visibility for each card
	for mission in missions:
		if not mission_cards.has(mission.id):
			continue
			
		var card = mission_cards[mission.id]
		if not is_instance_valid(card):
			continue
		
		# Determine if card should be visible
		var should_show = false
		match filter_mode:
			"completed":
				should_show = mission.is_completed
			"open":
				should_show = not mission.is_completed
			_:  # "all"
				should_show = true
		
		card.visible = should_show
		if should_show:
			visible_count += 1
	
	# If no visible missions, show a message
	var current_tab = tab_container.get_child(tab_container.current_tab)
	var scroll = current_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			# Remove any existing empty message
			for child in vbox.get_children():
				if child.name == "EmptyMessage":
					child.queue_free()
			
			# Add empty message if needed
			if visible_count == 0:
				var empty_label = Label.new()
				empty_label.name = "EmptyMessage"
				empty_label.text = "No missions to display"
				empty_label.add_theme_font_size_override("font_size", 16)
				empty_label.add_theme_color_override("font_color", Color("#CCCCCC"))
				empty_label.modulate = Color(0.7, 0.7, 0.7)
				vbox.add_child(empty_label)

func _update_mission_visibility():
	"""Update mission cards when data changes (completion, claims, etc)"""
	print("[SeasonPassUI] === UPDATE VISIBILITY STARTED")
	
	# Get fresh mission data
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	var mission_type = "daily" if current_tab_name == "Daily Missions" else "weekly"
	var missions = UnifiedMissionManager.get_missions_for_system("season_pass", mission_type)
	
	print("[SeasonPassUI] Got %d missions for %s" % [missions.size(), mission_type])
	
	# Create a list to track cards that need repositioning
	var cards_to_reorder = []
	
	# Update each card with fresh data
	for mission in missions:
		if mission_cards.has(mission.id) and is_instance_valid(mission_cards[mission.id]):
			var card = mission_cards[mission.id]
			card.setup(mission, "season")  # Refresh the card data
			cards_to_reorder.append({"card": card, "mission": mission})
	
	# Re-sort and reposition cards without recreating them
	cards_to_reorder.sort_custom(func(a, b):
		var a_claimable = a.mission.is_completed and not a.mission.is_claimed
		var b_claimable = b.mission.is_completed and not b.mission.is_claimed
		if a_claimable != b_claimable:
			return a_claimable
		if a.mission.is_claimed != b.mission.is_claimed:
			return b.mission.is_claimed
		return false
	)
	
	# Get the parent vbox
	var current_tab = tab_container.get_child(tab_container.current_tab)
	var scroll = current_tab.find_child("ScrollContainer", true, false)
	if scroll:
		var vbox = scroll.find_child("ContentVBox", true, false)
		if vbox:
			# Reorder children in VBox
			for i in range(cards_to_reorder.size()):
				var card_data = cards_to_reorder[i]
				vbox.move_child(card_data.card, i)
	
	# Reapply filter
	_apply_mission_filter()

func _refresh_missions():
	"""Refresh missions when filter changes"""
	print("Refreshing missions with filter: ", filter_mode)
	
	var current_tab_idx = tab_container.current_tab
	var current_tab_name = tab_container.get_tab_title(current_tab_idx)
	
	# Only refresh if we're on a missions tab
	if current_tab_name in ["Daily Missions", "Weekly Missions"]:
		# If cards already exist, just update visibility
		if mission_cards.size() > 0:
			_update_mission_visibility()
		else:
			# Initial setup
			var current_tab = tab_container.get_child(current_tab_idx)
			await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)

# Update mission completed handler
func _on_mission_completed(mission_id: String, system: String):
	"""Handle mission completion from UnifiedMissionManager"""
	if system == "season_pass":
		# Just update visibility/data, don't recreate
		var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
		if ("daily" in mission_id and current_tab_name == "Daily Missions") or \
		   ("weekly" in mission_id and current_tab_name == "Weekly Missions"):
			_update_mission_visibility()
		
		# Update pass layout to show new tier progress
		if pass_layout:
			pass_layout.refresh()

# Update mission reset handler
func _on_missions_reset(reset_type: String):
	"""Handle mission reset from UnifiedMissionManager"""
	var current_tab_name = tab_container.get_tab_title(tab_container.current_tab)
	if (reset_type == "daily" and current_tab_name == "Daily Missions") or \
	   (reset_type == "weekly" and current_tab_name == "Weekly Missions"):
		# On reset, we need to recreate cards
		mission_cards.clear()
		var current_tab = tab_container.get_child(tab_container.current_tab)
		await UIStyleManager.setup_scrollable_content(current_tab, _populate_missions_content)

func show_season_pass_ui():
	visible = true
	# Only populate if not initializing
	if not is_initializing:
		_populate_current_tab()
	
	# Refresh specific content based on current tab
	var current_tab_idx = tab_container.current_tab
	match current_tab_idx:
		0:  # Overview
			_refresh_overview()
		1:  # Battle Pass
			if pass_layout and not pass_layout.is_setting_up:
				pass_layout.refresh()

func hide_season_pass_ui():
	visible = false
	season_pass_ui_closed.emit()

func show_season_pass():
	"""Alias for compatibility"""
	show_season_pass_ui()

func _on_level_up_occurred(old_level: int, new_level: int, rewards: Dictionary):
	"""Track level-ups during mission claims"""
	if claim_in_progress:
		pending_level_ups.append({
			"old_level": old_level,
			"new_level": new_level,
			"rewards": rewards
		})

func _show_pending_notifications():
	"""Show level-up notification if any occurred"""
	if pending_level_ups.size() > 0:
		var notification_path = "res://Pyramids/scenes/ui/dialogs/UnifiedRewardNotification.tscn"
		if ResourceLoader.exists(notification_path):
			var notification = load(notification_path).instantiate()
			get_tree().root.add_child(notification)
			notification.show_level_ups(pending_level_ups)
		pending_level_ups.clear()
