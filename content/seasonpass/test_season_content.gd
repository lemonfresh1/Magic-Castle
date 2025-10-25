# test_season_content.gd - Test script for Season Pass Q1 2025 content
# Run this in Godot to verify the content loads correctly

extends Node

func _ready():
	print("\n========================================")
	print("Testing Season Pass Q1 2025 Content")
	print("========================================\n")
	
	# Load the season content (simulate)
	var season = load("res://Pyramids/content/seasonpass/SeasonPassQ4_2025.gd")
	
	# Test metadata
	print("📋 SEASON METADATA:")
	print("  ID: %s" % season.SEASON_ID)
	print("  Name: %s" % season.SEASON_NAME)
	print("  Theme: %s" % season.SEASON_THEME)
	print("  Start: %s" % season.START_DATE)
	print("  End: %s" % season.END_DATE)
	print("  Total Weeks: %d" % season.WEEK_UNLOCK_DATES.size())
	print("")
	
	# Test missions structure
	print("🎯 MISSION STRUCTURE:")
	var total_missions = 0
	var total_sp = 0
	for week in season.MISSIONS:
		var week_missions = season.MISSIONS[week]
		print("  %s: %d missions" % [week, week_missions.size()])
		total_missions += week_missions.size()
		for mission in week_missions:
			total_sp += mission.reward_sp
	
	print("\n  📊 TOTALS:")
	print("    Total Missions: %d" % total_missions)
	print("    Total SP Available: %d" % total_sp)
	print("")
	
	# Test sample mission structure
	print("📝 SAMPLE MISSION (Week 1, Mission 1):")
	var sample = season.MISSIONS["week_1"][0]
	print("  ID: %s" % sample.id)
	print("  Name: %s" % sample.name)
	print("  Description: %s" % sample.desc)
	print("  Target: %d" % sample.target)
	print("  Track: %s" % sample.track)
	print("  Reward SP: %d" % sample.reward_sp)
	print("")
	
	# Test helper functions
	print("🔧 HELPER FUNCTION TESTS:")
	
	# Test with various dates
	var test_dates = [
		"2025-09-30",  # Before season
		"2025-10-01",  # Start day
		"2025-10-07",  # Week 1 active
		"2025-10-14",  # Mid-season (Week 7)
		"2025-10-21",  # Near end
		"2025-10-28"   # After season
	]
	
	for test_date in test_dates:
		var week_num = season.get_week_number(test_date)
		var unlocked = season.get_unlocked_weeks(test_date)
		var is_active = season.is_season_active(test_date)
		var days_left = season.get_days_remaining(test_date)
		
		print("  Date: %s" % test_date)
		print("    Current Week: %d" % week_num)
		print("    Unlocked Weeks: %s" % str(unlocked))
		print("    Season Active: %s" % is_active)
		print("    Days Remaining: %d" % days_left)
		print("")
	
	# Test mission variety
	print("📊 MISSION VARIETY BY TRACK TYPE:")
	var track_counts = {}
	for week in season.MISSIONS:
		for mission in season.MISSIONS[week]:
			var track = mission.track
			if not track_counts.has(track):
				track_counts[track] = 0
			track_counts[track] += 1
	
	for track in track_counts:
		print("  %s: %d missions" % [track, track_counts[track]])
	print("")
	
	# Test reward distribution
	print("💰 REWARD DISTRIBUTION:")
	var sp_by_week = {}
	for week in season.MISSIONS:
		var week_sp = 0
		for mission in season.MISSIONS[week]:
			week_sp += mission.reward_sp
		sp_by_week[week] = week_sp
	
	for week in sp_by_week:
		print("  %s: %d SP" % [week, sp_by_week[week]])
	print("")
	
	print("✅ All tests complete!")
	print("========================================\n")
