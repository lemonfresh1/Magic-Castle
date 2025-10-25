# test_holiday_content.gd - Test script for Holiday Event content
# Run this in Godot to verify the holiday event loads correctly

extends Node

func _ready():
	print("\n========================================")
	print("Testing Winter Wonderland 2025 Event")
	print("========================================\n")
	
	# Load the holiday event content
	var event = load("res://Pyramids/content/holiday_events/WinterWonderland2025.gd")
	
	# Test metadata
	print("🎄 EVENT METADATA:")
	print("  ID: %s" % event.EVENT_ID)
	print("  Name: %s" % event.EVENT_NAME)
	print("  Theme: %s" % event.EVENT_THEME)
	print("  Start: %s" % event.START_DATE)
	print("  End: %s" % event.END_DATE)
	print("  Duration: %d days" % event.DURATION_DAYS)
	print("  Currency: %s %s" % [event.CURRENCY_ICON, event.CURRENCY_NAME])
	print("  Color: %s" % event.EVENT_COLOR)
	print("")
	
	# Test missions structure
	print("🎯 MISSION STRUCTURE:")
	print("  Total Missions: %d" % event.MISSIONS.size())
	
	var total_hp = 0
	for mission in event.MISSIONS:
		total_hp += mission.reward_hp
	
	print("  Total HP Available: %d" % total_hp)
	print("")
	
	# Test difficulty breakdown
	print("📊 MISSIONS BY DIFFICULTY:")
	var diff_counts = event.get_mission_count_by_difficulty()
	for difficulty in ["easy", "medium", "hard", "extreme"]:
		var count = diff_counts.get(difficulty, 0)
		var missions = event.get_missions_by_difficulty(difficulty)
		var hp = 0
		for m in missions:
			hp += m.reward_hp
		print("  %s: %d missions (%d HP)" % [difficulty.capitalize(), count, hp])
	print("")
	
	# Test sample missions
	print("📝 SAMPLE MISSIONS:")
	print("  EASY: %s - %s (%d HP)" % [
		event.MISSIONS[0].name,
		event.MISSIONS[0].desc,
		event.MISSIONS[0].reward_hp
	])
	print("  EXTREME: %s - %s (%d HP)" % [
		event.MISSIONS[-1].name,
		event.MISSIONS[-1].desc,
		event.MISSIONS[-1].reward_hp
	])
	print("")
	
	# Test helper functions
	print("🔧 HELPER FUNCTION TESTS:")
	
	var test_dates = [
		"2025-12-19",  # Before event
		"2025-12-20",  # Start day
		"2025-12-23",  # Mid-event
		"2025-12-27",  # Last day
		"2025-12-28"   # After event
	]
	
	for test_date in test_dates:
		var is_active = event.is_event_active(test_date)
		var days_left = event.get_days_remaining(test_date)
		var hours_left = event.get_hours_remaining(test_date)
		var progress = event.get_event_progress_percentage(test_date)
		
		print("  Date: %s" % test_date)
		print("    Event Active: %s" % is_active)
		print("    Days Remaining: %d" % days_left)
		print("    Hours Remaining: %d" % hours_left)
		print("    Progress: %.1f%%" % (progress * 100))
		print("")
	
	# Test mission variety
	print("📊 MISSION VARIETY BY TRACK TYPE:")
	var track_counts = {}
	for mission in event.MISSIONS:
		var track = mission.track
		if not track_counts.has(track):
			track_counts[track] = 0
		track_counts[track] += 1
	
	for track in track_counts:
		print("  %s: %d missions" % [track, track_counts[track]])
	print("")
	
	# Verify total HP
	print("💰 REWARD VERIFICATION:")
	var calculated_hp = event.get_total_hp_available()
	print("  Calculated Total: %d HP" % calculated_hp)
	print("  Actual Total: %d HP" % total_hp)
	if calculated_hp == total_hp:
		print("  ✅ HP totals match!")
	else:
		print("  ❌ HP totals don't match!")
	print("")
	
	# Test mission structure completeness
	print("🔍 MISSION DATA VALIDATION:")
	var valid = true
	for i in range(event.MISSIONS.size()):
		var mission = event.MISSIONS[i]
		if not mission.has("id"):
			print("  ❌ Mission %d missing 'id'" % i)
			valid = false
		if not mission.has("name"):
			print("  ❌ Mission %d missing 'name'" % i)
			valid = false
		if not mission.has("desc"):
			print("  ❌ Mission %d missing 'desc'" % i)
			valid = false
		if not mission.has("target"):
			print("  ❌ Mission %d missing 'target'" % i)
			valid = false
		if not mission.has("track"):
			print("  ❌ Mission %d missing 'track'" % i)
			valid = false
		if not mission.has("reward_hp"):
			print("  ❌ Mission %d missing 'reward_hp'" % i)
			valid = false
		if not mission.has("difficulty"):
			print("  ❌ Mission %d missing 'difficulty'" % i)
			valid = false
	
	if valid:
		print("  ✅ All missions have complete data!")
	print("")
	
	print("✅ All tests complete!")
	print("========================================\n")
