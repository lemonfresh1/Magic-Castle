# test_unified_missions.gd - Test script for UnifiedMissionManager
# Location: res://Pyramids/test_scenes/test_unified_missions.gd
# Run this in Godot to verify the mission system works correctly

extends Node

func _ready():
	print("\n" + "=")
	print("TESTING UNIFIED MISSION MANAGER")
	print("=" + "\n")
	
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	
	# Run all tests
	test_daily_rotation()
	await get_tree().create_timer(0.2).timeout
	
	test_weekly_missions()
	await get_tree().create_timer(0.2).timeout
	
	test_season_pass_loading()
	await get_tree().create_timer(0.2).timeout
	
	test_holiday_loading()
	await get_tree().create_timer(0.2).timeout
	
	test_mission_progress()
	await get_tree().create_timer(0.2).timeout
	
	test_combo_cascading()
	await get_tree().create_timer(0.2).timeout
	
	test_weekly_stats()
	await get_tree().create_timer(0.2).timeout
	
	print("\n" + "=")
	print("✅ ALL TESTS COMPLETE!")
	print("=" + "\n")

# ============================================================================
# TEST 1: DAILY ROTATION
# ============================================================================

func test_daily_rotation():
	print("🔄 TEST 1: DAILY MISSION ROTATION")
	print("-" )
	
	# Test that same date returns same missions
	var date1 = "2025-01-15"
	var missions1 = UnifiedMissionManager.get_daily_missions_for_date(date1)
	var missions2 = UnifiedMissionManager.get_daily_missions_for_date(date1)
	
	print("  Testing deterministic rotation...")
	if missions1.size() == 5:
		print("  ✅ Returns 5 missions")
	else:
		print("  ❌ Expected 5 missions, got %d" % missions1.size())
	
	# Check that missions are identical
	var identical = true
	for i in range(missions1.size()):
		if missions1[i].id != missions2[i].id:
			identical = false
			break
	
	if identical:
		print("  ✅ Same date returns same missions (deterministic)")
	else:
		print("  ❌ Same date returned different missions!")
	
	# Test that different dates return different missions
	var date2 = "2025-01-16"
	var missions3 = UnifiedMissionManager.get_daily_missions_for_date(date2)
	
	var different = false
	for i in range(missions1.size()):
		if missions1[i].id != missions3[i].id:
			different = true
			break
	
	if different:
		print("  ✅ Different dates return different missions")
	else:
		print("  ⚠️  Different dates returned same missions (unlikely but possible)")
	
	# Show today's missions
	var today = Time.get_date_string_from_system()
	var today_missions = UnifiedMissionManager.get_daily_missions_for_date(today)
	
	print("\n  📋 Today's Daily Missions (%s):" % today)
	for mission in today_missions:
		print("    • %s - %s (target: %d)" % [mission.name, mission.desc, mission.target])
	
	print("")

# ============================================================================
# TEST 2: WEEKLY MISSIONS
# ============================================================================

func test_weekly_missions():
	print("📅 TEST 2: WEEKLY MISSIONS")
	print("-")
	
	var weekly = UnifiedMissionManager.get_missions_for_system("standard", "weekly")
	
	print("  Testing weekly mission system...")
	if weekly.size() == 10:
		print("  ✅ Returns 10 weekly missions")
	else:
		print("  ❌ Expected 10 missions, got %d" % weekly.size())
	
	# Check weekly tracks
	var has_weekly_tracks = true
	for mission in weekly:
		if not mission.id.begins_with("weekly_"):
			has_weekly_tracks = false
			break
	
	if has_weekly_tracks:
		print("  ✅ All missions have 'weekly_' prefix")
	else:
		print("  ❌ Some missions missing 'weekly_' prefix")
	
	# Show weekly missions
	print("\n  📋 Weekly Missions:")
	for mission in weekly:
		print("    • %s - %s (target: %d, reward: %d XP)" % [
			mission.display_name,
			mission.description,
			mission.target_value,
			mission.rewards.get("xp", 0)
		])
	
	print("")

# ============================================================================
# TEST 3: SEASON PASS LOADING
# ============================================================================

func test_season_pass_loading():
	print("🎯 TEST 3: SEASON PASS CONTENT LOADING")
	print("-" )
	
	# Try to load Q4 2025 season
	var season = UnifiedMissionManager.load_season_content("Q4_2025")
	
	if season.size() > 0:
		print("  ✅ Season content loaded successfully")
		print("  📊 Season Details:")
		print("    ID: %s" % season.id)
		print("    Name: %s" % season.name)
		print("    Theme: %s" % season.theme)
		print("    Start: %s" % season.start_date)
		print("    End: %s" % season.end_date)
		
		# Count total missions
		var total_missions = 0
		var total_sp = 0
		for week in range(1, 13):
			var week_key = "week_%d" % week
			if season.missions.has(week_key):
				total_missions += season.missions[week_key].size()
				for mission in season.missions[week_key]:
					total_sp += mission.reward_sp
		
		print("    Total Missions: %d" % total_missions)
		print("    Total SP: %d" % total_sp)
		
		# Test week calculation
		var current_week = UnifiedMissionManager.get_current_week_for_season(season)
		print("    Current Week: %d/12" % current_week)
		
		if current_week > 0:
			print("  ✅ Week calculation working")
			
			# Get missions for current week
			var week_missions = UnifiedMissionManager.get_missions_for_system("season_pass", "all", current_week)
			print("\n  📋 Week %d Missions (%d available):" % [current_week, week_missions.size()])
			for i in range(min(3, week_missions.size())):
				var m = week_missions[i]
				print("    • %s - %s (target: %d, reward: %d SP)" % [
					m.display_name,
					m.description,
					m.target_value,
					m.rewards.sp
				])
			if week_missions.size() > 3:
				print("    ... and %d more" % (week_missions.size() - 3))
		else:
			print("  ⚠️  Season hasn't started yet or current week is 0")
	else:
		print("  ❌ Failed to load season content")
	
	print("")

# ============================================================================
# TEST 4: HOLIDAY EVENT LOADING
# ============================================================================

func test_holiday_loading():
	print("❄️  TEST 4: HOLIDAY EVENT CONTENT LOADING")
	print("-" )
	
	# Try to load Winter Wonderland
	var event = UnifiedMissionManager.load_holiday_content("WinterWonderland2025")
	
	if event.size() > 0:
		print("  ✅ Holiday content loaded successfully")
		print("  🎄 Event Details:")
		print("    ID: %s" % event.id)
		print("    Name: %s" % event.name)
		print("    Theme: %s" % event.theme)
		print("    Start: %s" % event.start_date)
		print("    End: %s" % event.end_date)
		print("    Duration: %d days" % event.duration_days)
		print("    Currency: %s %s" % [event.currency_icon, event.currency_name])
		
		# Count missions and HP
		var total_hp = 0
		var difficulty_counts = {"easy": 0, "medium": 0, "hard": 0, "extreme": 0}
		
		for mission in event.missions:
			total_hp += mission.reward_hp
			var diff = mission.get("difficulty", "medium")
			if difficulty_counts.has(diff):
				difficulty_counts[diff] += 1
		
		print("    Total Missions: %d" % event.missions.size())
		print("    Total HP: %d" % total_hp)
		print("    Difficulty Breakdown:")
		for diff in ["easy", "medium", "hard", "extreme"]:
			print("      %s: %d" % [diff.capitalize(), difficulty_counts[diff]])
		
		# Get all holiday missions
		var holiday_missions = UnifiedMissionManager.get_missions_for_system("holiday")
		print("\n  📋 Holiday Missions (%d loaded):" % holiday_missions.size())
		
		# Show sample from each difficulty
		for diff in ["easy", "hard"]:
			var sample = null
			for m in holiday_missions:
				if m.difficulty == diff:
					sample = m
					break
			
			if sample:
				print("    [%s] %s - %s (target: %d, reward: %d HP)" % [
					diff.to_upper(),
					sample.display_name,
					sample.description,
					sample.target_value,
					sample.rewards.hp
				])
	else:
		print("  ❌ Failed to load holiday content")
	
	print("")

# ============================================================================
# TEST 5: MISSION PROGRESS
# ============================================================================

func test_mission_progress():
	print("📈 TEST 5: MISSION PROGRESS TRACKING")
	print("-" )
	
	# Clear any existing progress
	UnifiedMissionManager.debug_reset_all()
	
	print("  Testing progress tracking...")
	
	# Simulate playing a game
	UnifiedMissionManager.update_progress("games_played", 1)
	
	# Get missions and check progress
	var missions = UnifiedMissionManager.get_missions_for_system("standard", "daily")
	
	var progressed = false
	for mission in missions:
		if mission.current_value > 0:
			progressed = true
			print("  ✅ Progress tracked: %s (%d/%d)" % [
				mission.display_name,
				mission.current_value,
				mission.target_value
			])
			break
	
	if not progressed:
		print("  ⚠️  No progress detected (might not have games_played mission today)")
	
	# Test completion
	print("\n  Testing mission completion...")
	
	# Find a simple mission to complete
	var test_mission = null
	for mission in missions:
		if mission.target_value == 1 and not mission.is_completed:
			test_mission = mission
			break
	
	if test_mission:
		# Complete it
		UnifiedMissionManager.debug_complete_mission(test_mission.id, "standard")
		
		# Check if completed
		var updated_missions = UnifiedMissionManager.get_missions_for_system("standard", "daily")
		for mission in updated_missions:
			if mission.id == test_mission.id:
				if mission.is_completed:
					print("  ✅ Mission completion working")
				else:
					print("  ❌ Mission not marked as completed")
				break
	else:
		print("  ⚠️  No suitable test mission found")
	
	print("")

# ============================================================================
# TEST 6: COMBO CASCADING
# ============================================================================

func test_combo_cascading():
	print("⚡ TEST 6: COMBO CASCADING")
	print("-" )
	
	# Clear progress
	UnifiedMissionManager.debug_reset_all()
	
	print("  Testing combo cascade logic...")
	print("  Simulating combo of 15...")
	
	# Simulate a combo of 15
	UnifiedMissionManager.update_progress("combo_3", 1)
	UnifiedMissionManager.update_progress("combo_5", 1)
	UnifiedMissionManager.update_progress("combo_8", 1)
	UnifiedMissionManager.update_progress("combo_10", 1)
	UnifiedMissionManager.update_progress("combo_12", 1)
	UnifiedMissionManager.update_progress("combo_15", 1)
	
	# Check which combo missions got updated
	var missions = UnifiedMissionManager.get_missions_for_system("standard", "daily")
	
	var combo_missions = []
	for mission in missions:
		if "combo" in mission.id.to_lower() and mission.current_value > 0:
			combo_missions.append(mission)
	
	if combo_missions.size() > 0:
		print("  ✅ Combo missions updated:")
		for mission in combo_missions:
			print("    • %s: %d/%d" % [
				mission.display_name,
				mission.current_value,
				mission.target_value
			])
	else:
		print("  ⚠️  No combo missions in today's rotation")
	
	print("")

# ============================================================================
# TEST 7: WEEKLY STATS
# ============================================================================

func test_weekly_stats():
	print("=" .repeat(60))
	print("TEST 7: WEEKLY STAT TRACKING")
	print("-".repeat(60))
	
	if not StatsManager:
		print("  FAIL: StatsManager not found")
		print("")
		return
	
	print("  Testing weekly stats integration...")
	
	# Check if weekly_stats exists
	if "weekly_stats" in StatsManager:
		print("  PASS: StatsManager has weekly_stats")
		
		# Show current weekly stats
		print("\n  Current Weekly Stats:")
		for stat in StatsManager.weekly_stats:
			if stat != "last_weekly_reset":
				var value = StatsManager.weekly_stats[stat]
				print("    %s: %d" % [stat, value])
		
		# Check if reset tracking works
		var reset_key = StatsManager.weekly_stats.get("last_weekly_reset", "")
		if reset_key != "":
			print("\n  PASS: Weekly reset tracking active")
			print("    Last reset: %s" % reset_key)
		else:
			print("\n  WARNING: Weekly reset not yet initialized")
	else:
		print("  FAIL: StatsManager missing weekly_stats")
	
	print("")

# ============================================================================
# HELPER: Print Test Section
# ============================================================================

func print_section(title: String):
	print("\n" + "=")
	print(title)
	print("=" + "\n")
