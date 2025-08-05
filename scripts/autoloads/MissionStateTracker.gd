# MissionStateTracker.gd - Tracks mission state at game start for comparison
# Location: res://Magic-Castle/scripts/autoloads/MissionStateTracker.gd
# Last Updated: Cleaned debug output while maintaining functionality [Date]

extends Node

# Store mission states at game start
var game_start_states = {}  # {system: {mission_id: {current_value, is_completed, is_claimed}}}
var is_tracking = false

func _ready():
	# Connect to game signals
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.game_over.connect(_on_game_over)

func _on_round_started(round_number: int):
	# Only capture state at the very start of round 1
	if round_number == 1 and not is_tracking:
		capture_mission_states()
		is_tracking = true

func _on_game_over(final_score: int):
	# Reset tracking for next game
	is_tracking = false
	# Don't clear states yet - PostGameSummary needs them!

func capture_mission_states():
	"""Capture the current state of all missions at game start"""
	game_start_states.clear()
	
	# Capture state for all systems
	for system in ["standard", "season_pass", "holiday"]:
		game_start_states[system] = {}
		
		var missions = UnifiedMissionManager.get_missions_for_system(system)
		for mission in missions:
			game_start_states[system][mission.id] = {
				"current_value": mission.current_value,
				"is_completed": mission.is_completed,
				"is_claimed": mission.is_claimed
			}

func get_mission_start_state(system: String, mission_id: String) -> Dictionary:
	"""Get the state of a mission at game start"""
	if game_start_states.has(system) and game_start_states[system].has(mission_id):
		return game_start_states[system][mission_id]
	
	# Return default if not found
	return {
		"current_value": 0,
		"is_completed": false,
		"is_claimed": false
	}

func did_mission_progress(system: String, mission_id: String, current_state: Dictionary) -> bool:
	"""Check if a mission made any progress since game start"""
	var start_state = get_mission_start_state(system, mission_id)
	
	# Mission progressed if:
	# 1. Current value increased
	# 2. Completed state changed from false to true
	# 3. Was not claimed at start (we never show already claimed missions)
	
	if start_state.is_claimed:
		return false  # Never show missions that were already claimed
	
	return (current_state.current_value > start_state.current_value or 
			(current_state.is_completed and not start_state.is_completed))

func was_already_claimable(system: String, mission_id: String) -> bool:
	"""Check if a mission was already claimable (completed but not claimed) at game start"""
	var start_state = get_mission_start_state(system, mission_id)
	return start_state.is_completed and not start_state.is_claimed

func clear_states():
	"""Clear stored states - call this when returning to menu"""
	game_start_states.clear()
	is_tracking = false
