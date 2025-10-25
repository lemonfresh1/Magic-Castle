# Mission System Implementation - Complete Game Plan
**Magic Castle Solitaire - Season Pass & Mission Overhaul**
**Last Updated:** October 25, 2025

----

## 📊 PROJECT STATUS OVERVIEW

### ✅ PHASE 1A: Content Structure (COMPLETED)
- [x] Created `SeasonPassQ4_2025.gd` (120 missions, 12 weeks, 955 SP)
- [x] Created `WinterWonderland2025.gd` (34 missions, 244 HP)
- [x] Created `UnifiedMissionManager.gd` (daily rotation, weekly tracking, content loading)
- [x] Added `StatsManager.weekly_stats` (tracks cumulative weekly progress)
- [x] Mission pools defined: 36 daily (pick 5/day), 10 weekly (fixed)
- [x] Combo cascading implemented
- [x] Test suite created and validated

**Test Results:**
✅ Daily rotation working (deterministic)
✅ Weekly missions working (all 10)
✅ Holiday content loads (34 missions)
❌ Season content loads (path fixed, needs manager update)
✅ Weekly stats tracking exists

---

## 🎯 REMAINING WORK

### ⏳ PHASE 1B: Manager Integration
### ⏳ PHASE 2: UI Updates
### ⏳ PHASE 3: Testing & Debug Tools
### ⏳ PHASE 4: Online Sync

---

# PHASE 1B: MANAGER INTEGRATION

## Chunk 1.4A: Update SeasonPassManager

**Goal:** Load season content from `.gd` files instead of using hardcoded missions

**File:** `res://Pyramids/scripts/autoloads/SeasonPassManager.gd`

### Changes Required:

#### 1. Add Content Loading on Startup
```gdscript
# Add to _ready()
func _ready():
	load_season_data()
	_initialize_season_tiers()
	
	# NEW: Load season content
	load_active_season_content()
	
	# Connect signals (existing code)
	# ...

func load_active_season_content():
	"""Load the currently active season from content files"""
	# Determine which season is active based on current date
	var today = Time.get_date_string_from_system()
	var season_id = _get_active_season_id(today)
	
	if season_id != "":
		var content = UnifiedMissionManager.load_season_content(season_id)
		if content.size() > 0:
			current_season_content = content
			print("[SeasonPassManager] Loaded season: %s" % content.name)
		else:
			push_error("Failed to load season content: %s" % season_id)
	else:
		print("[SeasonPassManager] No active season")

func _get_active_season_id(date_string: String) -> String:
	"""Determine which season is active based on date
	
	Q1: Jan 1 - Mar 31 → "Q1_2025"
	Q2: Apr 1 - Jun 30 → "Q2_2025"
	Q3: Jul 1 - Sep 30 → "Q3_2025"
	Q4: Oct 1 - Dec 31 → "Q4_2025"
	"""
	var parts = date_string.split("-")
	var year = int(parts[0])
	var month = int(parts[1])
	
	var quarter = ""
	if month >= 1 and month <= 3:
		quarter = "Q1"
	elif month >= 4 and month <= 6:
		quarter = "Q2"
	elif month >= 7 and month <= 9:
		quarter = "Q3"
	else:
		quarter = "Q4"
	
	return "%s_%d" % [quarter, year]
```

#### 2. Add Current Week Calculation
```gdscript
func get_current_week() -> int:
	"""Get current week number (1-12) for active season"""
	if current_season_content.size() == 0:
		return 0
	
	return UnifiedMissionManager.get_current_week_for_season(current_season_content)

func get_unlocked_weeks() -> Array:
	"""Get array of unlocked week numbers [1, 2, 3, ...]"""
	var current_week = get_current_week()
	var unlocked = []
	for i in range(1, current_week + 1):
		unlocked.append(i)
	return unlocked
```

#### 3. Add Auto-Claim at Season End
```gdscript
func check_season_expiry():
	"""Auto-claim unclaimed rewards when season ends"""
	if current_season_content.size() == 0:
		return
	
	var today = Time.get_date_string_from_system()
	var end_date = current_season_content.end_date
	
	if today > end_date:
		print("[SeasonPassManager] Season expired, auto-claiming rewards")
		_auto_claim_all_unclaimed()

func _auto_claim_all_unclaimed():
	"""Claim all completed but unclaimed missions/tiers"""
	# Auto-claim all completed missions
	var missions = UnifiedMissionManager.get_missions_for_system("season_pass")
	for mission in missions:
		if mission.is_completed and not mission.is_claimed:
			UnifiedMissionManager.claim_mission(mission.id, "season_pass")
	
	# Auto-claim all unlocked tier rewards
	for tier in current_season.tiers:
		if tier.is_unlocked:
			if not tier.free_claimed:
				claim_tier_rewards(tier.tier, true, false)
			if season_data.has_premium_pass and not tier.premium_claimed:
				claim_tier_rewards(tier.tier, false, true)
```

#### 4. Add Variables
```gdscript
# Add at top of script
var current_season_content: Dictionary = {}
```

### Testing Checklist:
- [ ] Season content loads on startup
- [ ] Current week calculation correct
- [ ] Missions from content file accessible
- [ ] Week unlock dates working
- [ ] Auto-claim triggers when season expires

---

## Chunk 1.4B: Update HolidayEventManager

**Goal:** Load holiday content from `.gd` files instead of using hardcoded events

**File:** `res://Pyramids/scripts/autoloads/HolidayEventManager.gd`

### Changes Required:

#### 1. Add Content Loading
```gdscript
# Add to _ready()
func _ready():
	load_holiday_data()
	_initialize_holiday_tiers()
	
	# NEW: Load holiday content if event is active
	load_active_event_content()
	
	# Connect signals (existing code)
	# ...

func load_active_event_content():
	"""Load currently active holiday event from content files"""
	var today = Time.get_date_string_from_system()
	var event_id = _get_active_event_id(today)
	
	if event_id != "":
		var content = UnifiedMissionManager.load_holiday_content(event_id)
		if content.size() > 0:
			current_event_content = content
			
			# Update current_event with loaded data
			current_event.id = content.id
			current_event.name = content.name
			current_event.theme = content.theme
			current_event.start_date = content.start_date
			current_event.end_date = content.end_date
			current_event.currency_name = content.currency_name
			current_event.currency_icon = content.currency_icon
			
			print("[HolidayEventManager] Loaded event: %s" % content.name)
		else:
			push_error("Failed to load event content: %s" % event_id)
	else:
		print("[HolidayEventManager] No active holiday event")

func _get_active_event_id(date_string: String) -> String:
	"""Determine which event is active based on date
	
	Check known event files and their date ranges.
	For now, hardcode known events. Later could be made dynamic.
	"""
	var known_events = {
		"WinterWonderland2025": {"start": "2025-12-20", "end": "2025-12-27"},
		# Add more events as they're created
	}
	
	for event_id in known_events:
		var event = known_events[event_id]
		if date_string >= event.start and date_string <= event.end:
			return event_id
	
	return ""
```

#### 2. Add Variables
```gdscript
# Add at top of script
var current_event_content: Dictionary = {}
```

#### 3. Add Event Registration System (Optional - Better Approach)
```gdscript
# Better: Let events register themselves
const REGISTERED_EVENTS = [
	"WinterWonderland2025",
	# Future events added here
]

func _get_active_event_id(date_string: String) -> String:
	"""Check each registered event file to see if it's active"""
	for event_id in REGISTERED_EVENTS:
		var content_path = "res://Pyramids/content/holiday_events/%s.gd" % event_id
		if FileAccess.file_exists(content_path):
			var script = load(content_path)
			var temp = script.new()
			
			# Check if event is active
			if temp.is_event_active(date_string):
				return event_id
	
	return ""
```

### Testing Checklist:
- [ ] Holiday content loads when event is active
- [ ] Event metadata (name, dates, currency) correct
- [ ] All missions available day 1
- [ ] No weekly progression (flat list)

---

# PHASE 2: UI UPDATES

## Chunk 2.1: SeasonPassUI Week Filters

**Goal:** Add week-based navigation (Week 1-12, All) instead of Daily/Weekly tabs

**File:** `res://Pyramids/scripts/ui/seasonpass/SeasonPassUI.gd`

### Changes Required:

#### 1. Add Week Filter Dropdown
```gdscript
# Add to class variables
var current_week_filter: int = -1  # -1 = All, 1-12 = specific week
```

#### 2. Modify Missions Tab Setup
```gdscript
func _setup_missions_tab(tab: Control, mission_type: String):
	"""Setup missions tab - now uses week filter instead of daily/weekly"""
	# Create week filter buttons at top
	var week_filter_container = HBoxContainer.new()
	week_filter_container.name = "WeekFilterContainer"
	
	# Add "All" button
	var all_btn = Button.new()
	all_btn.text = "All"
	all_btn.pressed.connect(_on_week_filter_selected.bind(-1))
	week_filter_container.add_child(all_btn)
	
	# Add Week 1-12 buttons
	var unlocked_weeks = SeasonPassManager.get_unlocked_weeks()
	for week in range(1, 13):
		var btn = Button.new()
		btn.text = "Week %d" % week
		btn.disabled = not (week in unlocked_weeks)
		btn.pressed.connect(_on_week_filter_selected.bind(week))
		week_filter_container.add_child(btn)
	
	# Add to tab
	tab.add_child(week_filter_container)
	
	# Add scrollable mission content below
	await UIStyleManager.setup_scrollable_content(tab, _populate_missions_content)

func _on_week_filter_selected(week: int):
	"""Handle week filter selection"""
	current_week_filter = week
	_refresh_missions()
```

#### 3. Update Mission Retrieval
```gdscript
func _populate_missions_content(parent: Control):
	"""Populate missions based on current week filter"""
	# Get missions with week filter
	var missions = UnifiedMissionManager.get_missions_for_system(
		"season_pass", 
		"all", 
		current_week_filter
	)
	
	# Rest of existing mission display code...
```

### Testing Checklist:
- [ ] Week filter buttons appear (Week 1-12, All)
- [ ] Locked weeks are disabled/grayed
- [ ] Clicking week shows only that week's missions
- [ ] "All" shows all unlocked weeks
- [ ] Completed missions stay at bottom

---

## Chunk 2.2: HolidayUI Simplification

**Goal:** Remove Daily/Weekly tabs, show single flat mission list

**File:** `res://Pyramids/scripts/ui/holiday/HolidayUI.gd`

### Changes Required:

#### 1. Remove Tab System
```gdscript
func _initialize_all_tabs():
	"""Simplified - no more daily/weekly tabs for holiday"""
	# Setup Overview tab (keep as-is)
	var overview_tab = tab_container.get_node_or_null("Overview")
	if overview_tab:
		await UIStyleManager.setup_scrollable_content(overview_tab, _populate_overview_content)
		await get_tree().process_frame
	
	# Setup Holiday Pass tab (keep as-is)
	var holiday_pass_tab = tab_container.get_node_or_null("Holiday Pass")
	if holiday_pass_tab:
		await _setup_holiday_pass_tab(holiday_pass_tab)
		await get_tree().process_frame
	
	# Setup single Missions tab (NEW - replaces Daily/Weekly)
	var missions_tab = tab_container.get_node_or_null("Missions")
	if missions_tab:
		_setup_missions_tab(missions_tab)
		await get_tree().process_frame
```

#### 2. Simplify Mission Tab
```gdscript
func _setup_missions_tab(tab: Control):
	"""Setup single missions tab - all missions visible"""
	# Add filter buttons (All/Open/Completed)
	var filter_container = HBoxContainer.new()
	filter_container.name = "FilterContainer"
	
	var filters = ["All", "Open", "Completed"]
	for filter in filters:
		var btn = Button.new()
		btn.text = filter
		btn.pressed.connect(_on_mission_filter_selected.bind(filter))
		filter_container.add_child(btn)
	
	tab.add_child(filter_container)
	
	# Add scrollable mission list
	await UIStyleManager.setup_scrollable_content(tab, _populate_missions_content)

func _populate_missions_content(parent: Control):
	"""Show all holiday missions (flat list, no weekly separation)"""
	var missions = UnifiedMissionManager.get_missions_for_system("holiday")
	
	# Apply current filter
	missions = _apply_filter(missions, current_filter)
	
	# Sort by difficulty
	missions.sort_custom(_sort_by_difficulty)
	
	# Display missions...
```

### Testing Checklist:
- [ ] Only 3 tabs: Overview, Holiday Pass, Missions
- [ ] Missions tab shows all missions at once
- [ ] Filter (All/Open/Completed) works
- [ ] Missions sorted by difficulty
- [ ] No daily/weekly separation

---

## Chunk 2.3: MissionCard Week Display

**Goal:** Add week badges to season pass mission cards

**File:** `res://Pyramids/scripts/ui/components/MissionCard.gd`

### Changes Required:

#### 1. Add Week Badge
```gdscript
func setup(mission_data: Dictionary):
	"""Setup mission card with optional week badge"""
	# Existing setup code...
	
	# Add week badge for season pass missions
	if mission_data.has("week"):
		_add_week_badge(mission_data.week)

func _add_week_badge(week_number: int):
	"""Add week indicator badge to card"""
	var badge = Label.new()
	badge.name = "WeekBadge"
	badge.text = "Week %d" % week_number
	badge.add_theme_font_size_override("font_size", 12)
	
	# Style as badge
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.8, 0.8)
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("normal", style)
	
	# Add to top-right of card
	add_child(badge)
	badge.position = Vector2(size.x - badge.size.x - 10, 10)
```

### Testing Checklist:
- [ ] Season pass missions show "Week X" badge
- [ ] Standard missions don't show badge
- [ ] Holiday missions don't show badge
- [ ] Badge positioned correctly
- [ ] Badge styled nicely

---

# PHASE 3: TESTING & DEBUG TOOLS

## Chunk 3.1: Debug Date Override

**Goal:** Add date override to test week unlocking and event timing

**File:** `res://Pyramids/scripts/ui/debug/DebugPanel.gd`

### Changes Required:

#### 1. Add Date Override Section
```gdscript
# Add to class variables
var debug_date_override: String = ""  # Empty = use real date

# Add to UI setup
func _create_mission_testing_section():
	"""Create mission/date testing controls"""
	var section = VBoxContainer.new()
	
	# Date Override
	var date_label = Label.new()
	date_label.text = "Override Date (YYYY-MM-DD):"
	section.add_child(date_label)
	
	var date_input = LineEdit.new()
	date_input.placeholder_text = "2025-12-23"
	date_input.text_changed.connect(_on_date_override_changed)
	section.add_child(date_input)
	
	var current_date_label = Label.new()
	current_date_label.name = "CurrentDateLabel"
	current_date_label.text = "Current: %s" % Time.get_date_string_from_system()
	section.add_child(current_date_label)
	
	var apply_date_btn = Button.new()
	apply_date_btn.text = "Apply Date Override"
	apply_date_btn.pressed.connect(_apply_date_override)
	section.add_child(apply_date_btn)
	
	var clear_date_btn = Button.new()
	clear_date_btn.text = "Clear Override (Use Real Date)"
	clear_date_btn.pressed.connect(_clear_date_override)
	section.add_child(clear_date_btn)
	
	return section

func _on_date_override_changed(new_text: String):
	debug_date_override = new_text

func _apply_date_override():
	if debug_date_override == "":
		print("[Debug] No date entered")
		return
	
	# Validate format
	var regex = RegEx.new()
	regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
	if not regex.search(debug_date_override):
		print("[Debug] Invalid date format. Use YYYY-MM-DD")
		return
	
	# Override Time class (monkey patch)
	DebugTimeOverride.set_override_date(debug_date_override)
	
	# Reload content based on new date
	SeasonPassManager.load_active_season_content()
	HolidayEventManager.load_active_event_content()
	
	print("[Debug] Date override applied: %s" % debug_date_override)
	print("[Debug] Current week: %d" % SeasonPassManager.get_current_week())

func _clear_date_override():
	debug_date_override = ""
	DebugTimeOverride.clear_override()
	
	SeasonPassManager.load_active_season_content()
	HolidayEventManager.load_active_event_content()
	
	print("[Debug] Date override cleared")
```

#### 2. Create DebugTimeOverride Helper
**New File:** `res://Pyramids/scripts/debug/DebugTimeOverride.gd`

```gdscript
# DebugTimeOverride.gd - Allows overriding Time.get_date_string_from_system()
extends Node

var override_active: bool = false
var override_date: String = ""

func set_override_date(date: String):
	override_active = true
	override_date = date
	print("[DebugTimeOverride] Date override: %s" % date)

func clear_override():
	override_active = false
	override_date = ""
	print("[DebugTimeOverride] Override cleared")

func get_current_date() -> String:
	if override_active:
		return override_date
	else:
		return Time.get_date_string_from_system()
```

#### 3. Update All Date Calls
Replace `Time.get_date_string_from_system()` with `DebugTimeOverride.get_current_date()` in:
- UnifiedMissionManager
- SeasonPassManager
- HolidayEventManager
- StatsManager (for weekly resets)

### Testing Checklist:
- [ ] Date override field accepts YYYY-MM-DD
- [ ] Applying override reloads season/holiday content
- [ ] Week calculation uses override date
- [ ] Mission rotation uses override date
- [ ] Clearing override returns to real date

---

## Chunk 3.2: Debug Mission Completion

**Goal:** Add tools to instantly complete specific missions by entering exact progress

**File:** `res://Pyramids/scripts/ui/debug/DebugPanel.gd`

### Changes Required:

#### 1. Add Mission Completion Section
```gdscript
func _create_mission_completion_section():
	"""Create mission testing controls"""
	var section = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Mission Testing:"
	section.add_child(label)
	
	# Mission ID input
	var mission_id_label = Label.new()
	mission_id_label.text = "Mission ID:"
	section.add_child(mission_id_label)
	
	var mission_id_input = LineEdit.new()
	mission_id_input.name = "MissionIDInput"
	mission_id_input.placeholder_text = "daily_play_3"
	section.add_child(mission_id_input)
	
	# System type dropdown
	var system_label = Label.new()
	system_label.text = "System:"
	section.add_child(system_label)
	
	var system_dropdown = OptionButton.new()
	system_dropdown.name = "SystemDropdown"
	system_dropdown.add_item("standard")
	system_dropdown.add_item("season_pass")
	system_dropdown.add_item("holiday")
	section.add_child(system_dropdown)
	
	# Progress input
	var progress_label = Label.new()
	progress_label.text = "Set Progress To:"
	section.add_child(progress_label)
	
	var progress_input = SpinBox.new()
	progress_input.name = "ProgressInput"
	progress_input.min_value = 0
	progress_input.max_value = 10000
	progress_input.step = 1
	section.add_child(progress_input)
	
	# Buttons
	var complete_btn = Button.new()
	complete_btn.text = "Complete Mission"
	complete_btn.pressed.connect(_debug_complete_mission)
	section.add_child(complete_btn)
	
	var set_progress_btn = Button.new()
	set_progress_btn.text = "Set Exact Progress"
	set_progress_btn.pressed.connect(_debug_set_mission_progress)
	section.add_child(set_progress_btn)
	
	# Quick actions
	var quick_label = Label.new()
	quick_label.text = "Quick Actions:"
	section.add_child(quick_label)
	
	var complete_all_daily_btn = Button.new()
	complete_all_daily_btn.text = "Complete All Today's Daily"
	complete_all_daily_btn.pressed.connect(_debug_complete_all_daily)
	section.add_child(complete_all_daily_btn)
	
	var complete_all_weekly_btn = Button.new()
	complete_all_weekly_btn.text = "Complete All Weekly"
	complete_all_weekly_btn.pressed.connect(_debug_complete_all_weekly)
	section.add_child(complete_all_weekly_btn)
	
	return section

func _debug_complete_mission():
	var mission_id = get_node("MissionIDInput").text
	var system_idx = get_node("SystemDropdown").selected
	var systems = ["standard", "season_pass", "holiday"]
	var system = systems[system_idx]
	
	if mission_id.is_empty():
		print("[Debug] Enter mission ID")
		return
	
	UnifiedMissionManager.debug_complete_mission(mission_id, system)
	print("[Debug] Completed: %s (%s)" % [mission_id, system])

func _debug_set_mission_progress():
	var mission_id = get_node("MissionIDInput").text
	var system_idx = get_node("SystemDropdown").selected
	var systems = ["standard", "season_pass", "holiday"]
	var system = systems[system_idx]
	var progress = int(get_node("ProgressInput").value)
	
	if mission_id.is_empty():
		print("[Debug] Enter mission ID")
		return
	
	# Set exact progress
	if not UnifiedMissionManager.mission_progress.has(system):
		UnifiedMissionManager.mission_progress[system] = {}
	
	if not UnifiedMissionManager.mission_progress[system].has(mission_id):
		UnifiedMissionManager.mission_progress[system][mission_id] = {
			"current": 0,
			"completed": false,
			"claimed": false
		}
	
	UnifiedMissionManager.mission_progress[system][mission_id].current = progress
	UnifiedMissionManager.save_missions()
	
	print("[Debug] Set %s progress to %d" % [mission_id, progress])

func _debug_complete_all_daily():
	var today = DebugTimeOverride.get_current_date()
	var daily_missions = UnifiedMissionManager.get_daily_missions_for_date(today)
	
	for mission in daily_missions:
		UnifiedMissionManager.debug_complete_mission(mission.id, "standard")
	
	print("[Debug] Completed all daily missions (%d)" % daily_missions.size())

func _debug_complete_all_weekly():
	for mission in UnifiedMissionManager.WEEKLY_MISSION_POOL:
		UnifiedMissionManager.debug_complete_mission(mission.id, "standard")
	
	print("[Debug] Completed all weekly missions (10)")
```

### Testing Checklist:
- [ ] Can complete specific mission by ID
- [ ] Can set exact progress value
- [ ] Can complete all daily missions at once
- [ ] Can complete all weekly missions at once
- [ ] Works for all systems (standard, season_pass, holiday)

---

## Chunk 3.3: Integration Testing

**Goal:** Manual testing with debug tools to ensure everything works

### Test Cases:

#### Test 1: Daily Rotation
1. Note today's daily missions
2. Override date to tomorrow
3. Verify different 5 missions appear
4. Override date back
5. Verify original 5 missions return

#### Test 2: Season Pass Week Unlocking
1. Override date to season start (Oct 1, 2025)
2. Verify only Week 1 unlocked
3. Override date to Oct 7, 2025 (Monday)
4. Verify Week 2 unlocked
5. Continue through all 12 weeks

#### Test 3: Holiday Event Timing
1. Override date to Dec 19, 2025 (before event)
2. Verify no holiday event active
3. Override date to Dec 20, 2025 (start)
4. Verify Winter Wonderland loads
5. Verify all 34 missions available
6. Override date to Dec 28, 2025 (after event)
7. Verify event no longer active

#### Test 4: Mission Completion
1. Use debug tool to complete a daily mission
2. Verify it shows as completed in UI
3. Claim the reward
4. Verify XP granted
5. Set exact progress (e.g., 5/10)
6. Verify progress bar updates

#### Test 5: Week Filters
1. Go to Season Pass → Missions
2. Verify week filter buttons
3. Click "Week 1" - see only Week 1 missions
4. Click "Week 2" - see only Week 2 missions (if unlocked)
5. Click "All" - see all unlocked weeks
6. Verify locked weeks are grayed out

#### Test 6: Combo Cascading
1. Use debug to simulate combo 15
2. Verify missions complete: combo_3, combo_5, combo_8, combo_10, combo_12, combo_15
3. Test with combo 20
4. Verify it also completes combo_20

---

# PHASE 4: ONLINE SYNC

## Overview

Sync mission progress and pass progress to Supabase for cross-device support.

### Supabase Tables

**Table 1: pyramids_mission_progress**
- Stores individual mission progress
- Uses `reset_key` to handle resets (daily/weekly/season/event)
- Unique constraint on (profile_id, mission_id, system_type, reset_key)

**Table 2: pyramids_pass_progress**
- Stores season pass / holiday pass progression
- Tracks points, level, premium status, claimed tiers
- Unique constraint on (profile_id, pass_id)

**Table 3: pyramids_profiles**
- Main profile table (already exists)
- All other tables reference this via profile_id

**Table 4: pyramids_stats**
- Already exists, tracks overall stats
- Could add weekly_stats JSONB column if needed (optional)

---

## Chunk 4.1: ProfileManager Mission Sync Methods

**Goal:** Add methods to sync mission progress to Supabase

**File:** `res://Pyramids/scripts/autoloads/ProfileManager.gd`

### Methods to Add:

```gdscript
func sync_mission_progress(mission_data: Dictionary):
	"""Sync single mission progress to Supabase
	
	mission_data format:
	{
		"mission_id": "daily_play_3",
		"system_type": "standard",
		"current_progress": 2,
		"is_completed": false,
		"is_claimed": false,
		"mission_type": "daily",
		"reset_key": "2025-10-25"
	}
	"""
	if not is_authenticated():
		return
	
	var data = {
		"profile_id": profile_id,
		"mission_id": mission_data.mission_id,
		"system_type": mission_data.system_type,
		"current_progress": mission_data.current_progress,
		"is_completed": mission_data.is_completed,
		"is_claimed": mission_data.is_claimed,
		"mission_type": mission_data.mission_type,
		"reset_key": mission_data.reset_key
	}
	
	if mission_data.is_completed and not mission_data.has("completed_at"):
		data["completed_at"] = Time.get_datetime_string_from_system()
	
	if mission_data.is_claimed and not mission_data.has("claimed_at"):
		data["claimed_at"] = Time.get_datetime_string_from_system()
	
	# Upsert (insert or update)
	SyncManager.queue_mission_update(data)

func load_mission_progress_from_db() -> Dictionary:
	"""Load all mission progress from Supabase"""
	if not is_authenticated():
		return {}
	
	var query = SupabaseManager.from_table("pyramids_mission_progress") \
		.select("*") \
		.eq("profile_id", profile_id)
	
	var result = await query.execute()
	
	if result.error:
		push_error("Failed to load mission progress: " + str(result.error))
		return {}
	
	# Convert to format UnifiedMissionManager expects
	var progress = {}
	for row in result.data:
		var system = row.system_type
		if not progress.has(system):
			progress[system] = {}
		
		progress[system][row.mission_id] = {
			"current": row.current_progress,
			"completed": row.is_completed,
			"claimed": row.is_claimed
		}
	
	return progress
```

---

## Chunk 4.2: ProfileManager Pass Sync Methods

**Goal:** Add methods to sync pass progress to Supabase

**File:** `res://Pyramids/scripts/autoloads/ProfileManager.gd`

### Methods to Add:

```gdscript
func sync_pass_progress(pass_data: Dictionary):
	"""Sync pass progress to Supabase
	
	pass_data format:
	{
		"pass_type": "season" or "holiday",
		"pass_id": "q4_2025" or "winter_2025",
		"points": 150,
		"level": 15,
		"owns_premium": true,
		"claimed_free_tiers": [1, 2, 3, ...],
		"claimed_premium_tiers": [1, 2, ...]
	}
	"""
	if not is_authenticated():
		return
	
	var data = {
		"profile_id": profile_id,
		"pass_type": pass_data.pass_type,
		"pass_id": pass_data.pass_id,
		"points": pass_data.points,
		"level": pass_data.level,
		"owns_premium": pass_data.owns_premium,
		"claimed_free_tiers": pass_data.claimed_free_tiers,
		"claimed_premium_tiers": pass_data.claimed_premium_tiers
	}
	
	if pass_data.owns_premium and not pass_data.has("purchased_at"):
		data["purchased_at"] = Time.get_datetime_string_from_system()
	
	# Upsert
	SyncManager.queue_pass_update(data)

func load_pass_progress_from_db() -> Dictionary:
	"""Load pass progress from Supabase"""
	if not is_authenticated():
		return {}
	
	var query = SupabaseManager.from_table("pyramids_pass_progress") \
		.select("*") \
		.eq("profile_id", profile_id)
	
	var result = await query.execute()
	
	if result.error:
		push_error("Failed to load pass progress: " + str(result.error))
		return {}
	
	var progress = {}
	for row in result.data:
		progress[row.pass_id] = {
			"pass_type": row.pass_type,
			"points": row.points,
			"level": row.level,
			"owns_premium": row.owns_premium,
			"claimed_free_tiers": row.claimed_free_tiers,
			"claimed_premium_tiers": row.claimed_premium_tiers
		}
	
	return progress
```

---

## Chunk 4.3: SyncManager Queue Methods

**Goal:** Add queue methods for batching sync requests

**File:** `res://Pyramids/scripts/autoloads/SyncManager.gd`

### Methods to Add:

```gdscript
var mission_update_queue = []
var pass_update_queue = []

func queue_mission_update(mission_data: Dictionary):
	"""Queue a mission update for batch sync"""
	mission_update_queue.append(mission_data)
	
	# Sync immediately if queue is large
	if mission_update_queue.size() >= 10:
		flush_mission_queue()

func queue_pass_update(pass_data: Dictionary):
	"""Queue a pass update for batch sync"""
	pass_update_queue.append(pass_data)
	flush_pass_queue()  # Pass updates are important, sync immediately

func flush_mission_queue():
	"""Send all queued mission updates to Supabase"""
	if mission_update_queue.is_empty():
		return
	
	if not NetworkManager.is_online():
		return  # Will retry later
	
	for mission in mission_update_queue:
		await _sync_single_mission(mission)
	
	mission_update_queue.clear()

func flush_pass_queue():
	"""Send all queued pass updates to Supabase"""
	if pass_update_queue.is_empty():
		return
	
	if not NetworkManager.is_online():
		return
	
	for pass in pass_update_queue:
		await _sync_single_pass(pass)
	
	pass_update_queue.clear()

func _sync_single_mission(data: Dictionary):
	"""Upsert a single mission to database"""
	var query = SupabaseManager.from_table("pyramids_mission_progress") \
		.upsert(data, ["profile_id", "mission_id", "system_type", "reset_key"])
	
	var result = await query.execute()
	
	if result.error:
		push_error("Mission sync failed: " + str(result.error))

func _sync_single_pass(data: Dictionary):
	"""Upsert a single pass to database"""
	var query = SupabaseManager.from_table("pyramids_pass_progress") \
		.upsert(data, ["profile_id", "pass_id"])
	
	var result = await query.execute()
	
	if result.error:
		push_error("Pass sync failed: " + str(result.error))
```

---

## Chunk 4.4: Wire Up Sync Calls

**Goal:** Call sync methods after mission/pass updates

### UnifiedMissionManager Changes:

```gdscript
# In update_progress(), after missions_completed check:
func update_progress(track_type: String, value: int = 1):
	# ... existing code ...
	
	if missions_completed.size() > 0:
		save_missions()
		
		# NEW: Sync completed missions
		for completed in missions_completed:
			_queue_mission_sync(completed.mission_id, completed.system)
	
	return missions_completed

func _queue_mission_sync(mission_id: String, system: String):
	"""Queue mission for sync to Supabase"""
	if not mission_progress.has(system) or not mission_progress[system].has(mission_id):
		return
	
	var progress = mission_progress[system][mission_id]
	
	# Determine reset_key based on system and mission type
	var reset_key = _get_reset_key(mission_id, system)
	
	var mission_data = {
		"mission_id": mission_id,
		"system_type": system,
		"current_progress": progress.current,
		"is_completed": progress.completed,
		"is_claimed": progress.claimed,
		"mission_type": _get_mission_type(mission_id),
		"reset_key": reset_key
	}
	
	ProfileManager.sync_mission_progress(mission_data)

func _get_reset_key(mission_id: String, system: String) -> String:
	"""Get appropriate reset key for mission"""
	if system == "season_pass":
		return loaded_season_content.get("id", "unknown")
	elif system == "holiday":
		return loaded_holiday_content.get("id", "unknown")
	else:
		# Standard missions
		if mission_id.begins_with("daily_"):
			return DebugTimeOverride.get_current_date()
		else:
			# Weekly - use week string
			var days_since_epoch = Time.get_unix_time_from_system() / 86400
			var week_number = int(days_since_epoch / 7)
			return "week_%d" % week_number

func _get_mission_type(mission_id: String) -> String:
	"""Get mission type from ID"""
	if mission_id.begins_with("daily_"):
		return "daily"
	elif mission_id.begins_with("weekly_"):
		return "weekly"
	else:
		return "season" if loaded_season_content.size() > 0 else "holiday"
```

### SeasonPassManager Changes:

```gdscript
# After add_season_points()
func add_season_points(amount: int, source: String = "gameplay"):
	# ... existing code ...
	
	# NEW: Sync after level up
	if leveled_up:
		_queue_pass_sync()

func _queue_pass_sync():
	"""Queue pass progress for sync"""
	var pass_data = {
		"pass_type": "season",
		"pass_id": current_season_content.get("id", "unknown"),
		"points": season_data.season_points,
		"level": season_data.season_level,
		"owns_premium": season_data.has_premium_pass,
		"claimed_free_tiers": season_data.claimed_tiers.filter(func(t): return t <= MAX_TIER),
		"claimed_premium_tiers": season_data.claimed_tiers.filter(func(t): return season_data.has_premium_pass)
	}
	
	ProfileManager.sync_pass_progress(pass_data)
```

### HolidayEventManager Changes:

```gdscript
# After add_holiday_points()
func add_holiday_points(amount: int, source: String = "gameplay"):
	# ... existing code ...
	
	# NEW: Sync after level up
	if leveled_up:
		_queue_pass_sync()

func _queue_pass_sync():
	"""Queue pass progress for sync"""
	var pass_data = {
		"pass_type": "holiday",
		"pass_id": current_event_content.get("id", "unknown"),
		"points": holiday_data.holiday_points,
		"level": holiday_data.holiday_level,
		"owns_premium": holiday_data.has_premium_pass,
		"claimed_free_tiers": holiday_data.claimed_tiers.filter(func(t): return t <= MAX_TIER),
		"claimed_premium_tiers": holiday_data.claimed_tiers.filter(func(t): return holiday_data.has_premium_pass)
	}
	
	ProfileManager.sync_pass_progress(pass_data)
```

---

## Chunk 4.5: Load from DB on Login

**Goal:** Populate local data from Supabase on login

### ProfileManager Changes:

```gdscript
func _on_user_authenticated(user_data: Dictionary):
	# ... existing code ...
	
	# NEW: Load mission and pass progress
	await _load_remote_progress()

func _load_remote_progress():
	"""Load mission and pass progress from database"""
	print("[ProfileManager] Loading remote progress...")
	
	# Load missions
	var mission_progress = await load_mission_progress_from_db()
	if mission_progress.size() > 0:
		UnifiedMissionManager.mission_progress = mission_progress
		UnifiedMissionManager.save_missions()
		print("[ProfileManager] Loaded %d mission systems from DB" % mission_progress.size())
	
	# Load passes
	var pass_progress = await load_pass_progress_from_db()
	
	# Apply to SeasonPassManager
	var season_id = SeasonPassManager.current_season_content.get("id", "")
	if pass_progress.has(season_id):
		var season = pass_progress[season_id]
		SeasonPassManager.season_data.season_points = season.points
		SeasonPassManager.season_data.season_level = season.level
		SeasonPassManager.season_data.has_premium_pass = season.owns_premium
		SeasonPassManager.season_data.claimed_tiers = season.claimed_free_tiers
		SeasonPassManager.save_season_data()
		print("[ProfileManager] Loaded season pass progress")
	
	# Apply to HolidayEventManager
	var event_id = HolidayEventManager.current_event_content.get("id", "")
	if pass_progress.has(event_id):
		var event = pass_progress[event_id]
		HolidayEventManager.holiday_data.holiday_points = event.points
		HolidayEventManager.holiday_data.holiday_level = event.level
		HolidayEventManager.holiday_data.has_premium_pass = event.owns_premium
		HolidayEventManager.holiday_data.claimed_tiers = event.claimed_free_tiers
		HolidayEventManager.save_holiday_data()
		print("[ProfileManager] Loaded holiday pass progress")
```

---

# SCRIPTS & DEPENDENCIES

## Core Scripts Modified:

### Phase 1B:
- [x] `SeasonPassManager.gd` - Load season content, week calculation
- [x] `HolidayEventManager.gd` - Load holiday content

### Phase 2:
- [x] `SeasonPassUI.gd` - Week filter UI
- [x] `HolidayUI.gd` - Simplified single missions tab
- [x] `MissionCard.gd` - Week badges

### Phase 3:
- [x] `DebugPanel.gd` - Date override, mission completion tools
- [x] `DebugTimeOverride.gd` (NEW) - Date override system
- [x] `UnifiedMissionManager.gd` - Use DebugTimeOverride
- [x] `SeasonPassManager.gd` - Use DebugTimeOverride
- [x] `HolidayEventManager.gd` - Use DebugTimeOverride
- [x] `StatsManager.gd` - Use DebugTimeOverride for weekly resets

### Phase 4:
- [x] `ProfileManager.gd` - Mission/pass sync methods
- [x] `SyncManager.gd` - Queue methods
- [x] `UnifiedMissionManager.gd` - Wire up sync calls
- [x] `SeasonPassManager.gd` - Wire up sync calls
- [x] `HolidayEventManager.gd` - Wire up sync calls
- [x] `SupabaseManager.gd` - Table queries (already exists, just use it)
- [x] `NetworkManager.gd` - Online check (already exists)

## Dependencies:

**Autoloads (Already Exist):**
- SignalBus
- UnifiedMissionManager
- StatsManager
- SeasonPassManager
- HolidayEventManager
- ProfileManager
- SyncManager
- SupabaseManager
- NetworkManager
- XPManager
- StarManager

**UI Components:**
- MissionCard.tscn/gd
- SeasonPassUI.tscn/gd
- HolidayUI.tscn/gd
- MissionUI.tscn/gd (for standard missions)
- DebugPanel.tscn/gd

**Content Files:**
- SeasonPassQ4_2025.gd
- WinterWonderland2025.gd
- (Future seasons/events added here)

---

# TESTING CHECKLIST

## Phase 1B Testing:
- [ ] Season content loads on startup
- [ ] Holiday content loads when event active
- [ ] Week calculation correct
- [ ] Auto-claim works at season end

## Phase 2 Testing:
- [ ] Season Pass UI shows week filters (1-12, All)
- [ ] Locked weeks are disabled
- [ ] Week filter shows correct missions
- [ ] Holiday UI shows single missions tab
- [ ] Holiday missions all visible day 1
- [ ] Mission cards show week badges (season only)

## Phase 3 Testing:
- [ ] Date override changes current date
- [ ] Mission rotation uses override date
- [ ] Week unlocking uses override date
- [ ] Event timing uses override date
- [ ] Can complete missions via debug panel
- [ ] Can set exact progress
- [ ] Quick complete all daily/weekly works

## Phase 4 Testing:
- [ ] Mission completion syncs to DB
- [ ] Mission claim syncs to DB
- [ ] Pass level up syncs to DB
- [ ] Pass tier claim syncs to DB
- [ ] Login loads progress from DB
- [ ] Cross-device sync works (test on 2 devices)
- [ ] Offline mode queues updates
- [ ] Queue flushes when online

---

# SUPABASE TABLES REFERENCE

## pyramids_profiles
```sql
- id (uuid, PK)
- user_id (uuid, FK to auth.users)
- username (text)
- created_at, updated_at (timestamp)
```

## pyramids_mission_progress
```sql
- id (uuid, PK)
- profile_id (uuid, FK)
- mission_id (text)
- system_type (text) - "standard", "season_pass", "holiday"
- current_progress (int)
- is_completed (bool)
- is_claimed (bool)
- completed_at, claimed_at (timestamp nullable)
- mission_type (text) - "daily", "weekly", "season", "holiday"
- reset_key (text) - "2025-10-25", "week_124", "q4_2025", "winter_2025"
- created_at, updated_at (timestamp)
- UNIQUE(profile_id, mission_id, system_type, reset_key)
```

## pyramids_pass_progress
```sql
- id (uuid, PK)
- profile_id (uuid, FK)
- pass_type (text) - "season" or "holiday"
- pass_id (text) - "q4_2025", "winter_2025"
- points (int) - SP or HP
- level (int) - current tier
- owns_premium (bool)
- purchased_at (timestamp nullable)
- claimed_free_tiers (int[])
- claimed_premium_tiers (int[])
- started_at, last_updated (timestamp)
- UNIQUE(profile_id, pass_id)
```

## pyramids_stats
```sql
- id (uuid, PK)
- profile_id (uuid, FK)
- mode_stats (jsonb)
- total_games, total_score, highest_combo, etc.
- login_streak, last_login_date, daily_logins
- created_at, updated_at (timestamp)
- UNIQUE(profile_id)

Optional: Add weekly_stats jsonb column for weekly stat tracking
```

---

# ESTIMATED TIME

- **Phase 1B:** 1-2 hours
- **Phase 2:** 2-3 hours
- **Phase 3:** 2-3 hours
- **Phase 4:** 3-4 hours

**Total:** 8-12 hours of focused work

---

# NOTES

- All date handling now goes through `DebugTimeOverride.get_current_date()`
- This allows testing future dates without changing system time
- Content files (SeasonPassQ4_2025.gd, etc.) are loaded at runtime
- Adding new seasons/events is as simple as creating new .gd files
- Sync is batched to avoid spamming Supabase
- Offline mode queues updates for later sync
- Cross-device sync uses Supabase as source of truth

---

**Ready to start Phase 1B?** 🚀
