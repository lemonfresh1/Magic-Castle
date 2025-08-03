# HolidayEventManager.gd - Manages holiday events and special missions
# Location: res://Magic-Castle/scripts/autoloads/HolidayEventManager.gd
# Last Updated: Created holiday event system [Date]

extends Node

signal holiday_mission_completed(mission_id: String, rewards: Dictionary)
signal holiday_mission_progress_updated(mission_id: String, current: int, target: int)
signal holiday_event_started(event_id: String)
signal holiday_event_ended(event_id: String)
signal holiday_currency_earned(amount: int)

const SAVE_PATH = "user://holiday_event_data.save"

# Holiday mission structure (same as MissionManager.Mission)
class HolidayMission extends Resource:
	@export var id: String = ""
	@export var display_name: String = ""
	@export var description: String = ""
	@export var target_value: int = 1
	@export var current_value: int = 0
	@export var rewards: Dictionary = {}  # "holiday_points": 100, "xp": 50, etc.
	@export var icon_path: String = ""
	@export var expires_at: String = ""
	@export var is_completed: bool = false
	@export var is_claimed: bool = false

# Active event data
var current_event = {
	"id": "winter_2024",
	"name": "Winter Wonderland",
	"theme": "winter",
	"start_date": "2024-12-01",
	"end_date": "2024-12-31",
	"currency_name": "Snowflakes",
	"currency_icon": "❄️"
}

# Active missions
var holiday_missions: Array[HolidayMission] = []

# Save data
var holiday_data = {
	"current_event_id": "",
	"holiday_currency": 0,
	"completed_missions": [],
	"claimed_missions": [],
	"mission_progress": {},
	"lifetime_events_participated": 0
}

# Mission templates
var holiday_mission_templates = {
	"holiday_collect_50": {
		"name": "Snowflake Collector",
		"desc": "Collect 50 snowflakes from games",
		"target": 50,
		"rewards": {"holiday_points": 100, "xp": 200},
		"track": "items_collected"
	},
	"holiday_win_10": {
		"name": "Holiday Victor",
		"desc": "Win 10 games during the event",
		"target": 10,
		"rewards": {"holiday_points": 150, "xp": 300},
		"track": "games_won"
	},
	"holiday_perfect_3": {
		"name": "Perfect Holiday",
		"desc": "Get 3 perfect clears",
		"target": 3,
		"rewards": {"holiday_points": 200, "xp": 400},
		"track": "perfect_clears"
	},
	"holiday_play_20": {
		"name": "Festive Player",
		"desc": "Play 20 games during the event",
		"target": 20,
		"rewards": {"holiday_points": 75, "xp": 150},
		"track": "games_played"
	},
	"holiday_score_50k": {
		"name": "Holiday High Scorer",
		"desc": "Score 50,000 points total",
		"target": 50000,
		"rewards": {"holiday_points": 125, "xp": 250},
		"track": "score_earned"
	}
}

func _ready():
	load_holiday_data()
	_check_active_event()
	
	# Defer signal connections to ensure SignalBus is ready
	call_deferred("_connect_signals")

func _connect_signals():
	# Connect to game signals
	if SignalBus:
		if not SignalBus.game_won.is_connected(_on_game_won):
			SignalBus.game_won.connect(_on_game_won)
		if not SignalBus.game_lost.is_connected(_on_game_lost):
			SignalBus.game_lost.connect(_on_game_lost)
		if not SignalBus.score_changed.is_connected(_on_score_changed):
			SignalBus.score_changed.connect(_on_score_changed)
		if not SignalBus.perfect_clear_achieved.is_connected(_on_perfect_clear):
			SignalBus.perfect_clear_achieved.connect(_on_perfect_clear)
	else:
		push_error("HolidayEventManager: SignalBus not found!")

func _check_active_event():
	# Check if event is active (simplified - would need proper date checking)
	if holiday_data.current_event_id != current_event.id:
		start_holiday_event(current_event)
	else:
		# Still initialize missions if they're empty
		if holiday_missions.is_empty():
			_initialize_holiday_missions()

func start_holiday_event(event_config: Dictionary):
	current_event = event_config
	holiday_data.current_event_id = event_config.id
	holiday_data.lifetime_events_participated += 1
	
	# Initialize missions
	_initialize_holiday_missions()
	
	save_holiday_data()
	holiday_event_started.emit(event_config.id)

func _initialize_holiday_missions():
	holiday_missions.clear()
	
	# Add all holiday missions
	for template_id in holiday_mission_templates:
		var template = holiday_mission_templates[template_id]
		var mission = _create_mission_from_template(template_id, template)
		holiday_missions.append(mission)
	
	print("HolidayEventManager: Initialized %d holiday missions" % holiday_missions.size())

func _create_mission_from_template(id: String, template: Dictionary) -> HolidayMission:
	var mission = HolidayMission.new()
	mission.id = id
	mission.display_name = template.name
	mission.description = template.desc
	mission.target_value = template.target
	mission.rewards = template.rewards
	
	# Check if already completed/claimed
	mission.is_completed = id in holiday_data.completed_missions
	mission.is_claimed = id in holiday_data.claimed_missions
	
	# Load progress
	if holiday_data.mission_progress.has(id):
		mission.current_value = holiday_data.mission_progress[id]
	
	return mission

func update_mission_progress(track_type: String, value: int):
	for mission in holiday_missions:
		if mission.is_completed:
			continue
			
		var template_key = mission.id
		if holiday_mission_templates.has(template_key):
			var template = holiday_mission_templates[template_key]
			if template.get("track", "") == track_type:
				mission.current_value += value
				holiday_data.mission_progress[mission.id] = mission.current_value
				
				# Check completion
				if mission.current_value >= mission.target_value:
					mission.is_completed = true
					holiday_data.completed_missions.append(mission.id)
					
					# Auto-grant rewards (no claiming needed)
					_grant_mission_rewards(mission)
					holiday_mission_completed.emit(mission.id, mission.rewards)
				
				holiday_mission_progress_updated.emit(mission.id, mission.current_value, mission.target_value)
	
	save_holiday_data()

func _grant_mission_rewards(mission: HolidayMission):
	if mission.rewards.has("holiday_points"):
		add_holiday_currency(mission.rewards.holiday_points)
	if mission.rewards.has("xp"):
		XPManager.add_xp(mission.rewards.xp)
	
	mission.is_claimed = true
	holiday_data.claimed_missions.append(mission.id)

func add_holiday_currency(amount: int):
	holiday_data.holiday_currency += amount
	holiday_currency_earned.emit(amount)
	save_holiday_data()

func spend_holiday_currency(amount: int) -> bool:
	if holiday_data.holiday_currency >= amount:
		holiday_data.holiday_currency -= amount
		save_holiday_data()
		return true
	return false

func get_holiday_currency() -> int:
	return holiday_data.holiday_currency

func get_active_missions() -> Array[HolidayMission]:
	return holiday_missions

func get_event_info() -> Dictionary:
	return {
		"id": current_event.id,
		"name": current_event.name,
		"theme": current_event.theme,
		"currency_name": current_event.currency_name,
		"currency_icon": current_event.currency_icon,
		"currency_amount": holiday_data.holiday_currency,
		"days_remaining": _calculate_days_remaining()
	}

func _calculate_days_remaining() -> int:
	# Simplified - would need proper date parsing
	return 15

# Signal handlers
func _on_game_won(final_score: int, time_elapsed: float):
	update_mission_progress("games_won", 1)
	update_mission_progress("games_played", 1)
	# Award some holiday currency for winning
	add_holiday_currency(10)

func _on_game_lost(final_score: int, reason: String):
	update_mission_progress("games_played", 1)

func _on_perfect_clear():
	update_mission_progress("perfect_clears", 1)
	# Bonus currency for perfect clear
	add_holiday_currency(5)

func _on_score_changed(points: int, reason: String):
	if points > 0:
		update_mission_progress("score_earned", points)

# Save/Load
func save_holiday_data():
	var save_dict = {
		"version": 1,
		"data": holiday_data
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_dict)
		file.close()

func load_holiday_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var save_dict = file.get_var()
			file.close()
			
			if save_dict and save_dict.has("data"):
				holiday_data = save_dict.data

func debug_force_init_missions():
	"""Force initialize missions for testing"""
	print("HolidayEventManager: Force initializing missions")
	_initialize_holiday_missions()
	return holiday_missions.size()

func reset_holiday_data():
	holiday_data = {
		"current_event_id": "",
		"holiday_currency": 0,
		"completed_missions": [],
		"claimed_missions": [],
		"mission_progress": {},
		"lifetime_events_participated": 0
	}
	save_holiday_data()
	_check_active_event()
