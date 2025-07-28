# shipped.gd - Project Roadmap & Progress Tracker
# CMD+SHIFT+X to run in output
# Path: res://Magic-Castle/shipped.gd
# Run this script to see project status: Click "Run" in script editor
@tool
extends EditorScript

# Status: "done" ✅, "working" 🔄, "open" ⬜
var roadmap = {
	"phase_1_game_modes": {
		"status": "working",
		"name": "Additional Game Modes",
		"tasks": {
			"1_1_game_mode_manager": {
				"status": "working",  # Changed from "open"
				"name": "Create GameModeManager Autoload",
				"subtasks": {
					"base_class": {"status": "done", "name": "Create GameModeBase class"},  # Already existed
					"manager_autoload": {"status": "done", "name": "Create GameModeManager autoload"},  # Already existed
					"mode_registration": {"status": "working", "name": "Implement mode registration system"}
				}
			},
			"1_2_game_modes": {
				"status": "working",  # Changed from "open"
				"name": "Implement Game Modes",
				"subtasks": {
					"tri_peaks": {"status": "done", "name": "Refactor existing to TriPeaksMode"},  # Already existed
					"rush_mode": {"status": "done", "name": "Create RushMode (5 rounds, 1.5x score)"},  # Just created
					"chill_mode": {"status": "done", "name": "Create ChillMode (no timer, 720s combo)"}  # Just created
				}
			},
			"1_3_ui_updates": {
				"status": "open",
				"name": "Update UI for Modes",
				"subtasks": {
					"mode_select": {"status": "open", "name": "Mode selection in main menu"},
					"timer_adapt": {"status": "open", "name": "Hide timer in chill mode"},
					"score_display": {"status": "open", "name": "Show mode multiplier in score"}
				}
			}
		}
	},
	"phase_2_achievements": {
		"status": "open",
		"name": "Achievements System",
		"tasks": {
			"2_1_achievement_manager": {
				"status": "open",
				"name": "Create AchievementManager",
				"subtasks": {
					"manager_autoload": {"status": "open", "name": "Create AchievementManager autoload"},
					"definitions": {"status": "open", "name": "Define achievement resources"},
					"tracking": {"status": "open", "name": "Implement progress tracking"},
					"persistence": {"status": "open", "name": "Save/load achievement data"}
				}
			},
			"2_2_achievement_ui": {
				"status": "open",
				"name": "Achievement UI Components",
				"subtasks": {
					"notification": {"status": "open", "name": "Unlock notification popup"},
					"panel": {"status": "open", "name": "Achievement gallery panel"},
					"progress_bars": {"status": "open", "name": "Progress indicators"}
				}
			},
			"2_3_integration": {
				"status": "open",
				"name": "Achievement Integration",
				"subtasks": {
					"game_hooks": {"status": "open", "name": "Hook into game events"},
					"mode_specific": {"status": "open", "name": "Mode-specific achievements"},
					"testing": {"status": "open", "name": "Test all achievement triggers"}
				}
			}
		}
	},
	"phase_3_statistics": {
		"status": "open",
		"name": "Statistics Database",
		"tasks": {
			"3_1_database": {
				"status": "open",
				"name": "Create DatabaseManager",
				"subtasks": {
					"manager": {"status": "open", "name": "DatabaseManager autoload"},
					"schema": {"status": "open", "name": "Define database schema"},
					"queries": {"status": "open", "name": "Implement CRUD operations"}
				}
			},
			"3_2_stats_display": {
				"status": "open",
				"name": "Statistics Display",
				"subtasks": {
					"main_widget": {"status": "open", "name": "Main menu stats widget"},
					"stats_screen": {"status": "open", "name": "Detailed statistics screen"},
					"post_game": {"status": "open", "name": "Post-game comparisons"}
				}
			}
		}
	},
	"phase_4_multiplayer": {
		"status": "open",
		"name": "Multiplayer System",
		"tasks": {
			"4_1_infrastructure": {"status": "open", "name": "Network infrastructure setup"},
			"4_2_game_modes": {"status": "open", "name": "Multiplayer game modes"},
			"4_3_matchmaking": {"status": "open", "name": "Matchmaking system"}
		}
	},
	"phase_5_monetization": {
		"status": "open",
		"name": "Monetization Framework",
		"tasks": {
			"5_1_battle_pass": {"status": "open", "name": "Battle pass system"},
			"5_2_ads": {"status": "open", "name": "Ad integration"},
			"5_3_premium": {"status": "open", "name": "Premium features"}
		}
	}
}

func _run():
	print("==============\n")
	print("🏰 MAGIC CASTLE SOLITAIRE - ROADMAP STATUS 🏰")
	print("==============\n")
	
	var total_tasks = 0
	var completed_tasks = 0
	
	for phase_key in roadmap:
		var phase = roadmap[phase_key]
		print(_get_status_icon(phase.status) + " " + phase.name.to_upper())
		
		for task_key in phase.tasks:
			var task = phase.tasks[task_key]
			print("  " + _get_status_icon(task.status) + " " + task.name)
			
			if task.has("subtasks"):
				for subtask_key in task.subtasks:
					var subtask = task.subtasks[subtask_key]
					total_tasks += 1
					if subtask.status == "done":
						completed_tasks += 1
					print("    " + _get_status_icon(subtask.status) + " " + subtask.name)
			else:
				total_tasks += 1
				if task.status == "done":
					completed_tasks += 1
		print("")
	
	var progress = float(completed_tasks) / float(total_tasks) * 100.0
	print("==============\n")
	print("📊 Overall Progress: %d/%d tasks (%.1f%%)" % [completed_tasks, total_tasks, progress])
	print("==============\n")

func _get_status_icon(status: String) -> String:
	match status:
		"done": return "✅"
		"working": return "🔄"
		"open": return "⬜"
		_: return "❓"

# Quick status check function
func get_current_task() -> String:
	for phase_key in roadmap:
		var phase = roadmap[phase_key]
		if phase.status == "working":
			for task_key in phase.tasks:
				var task = phase.tasks[task_key]
				if task.status == "working":
					return phase.name + " > " + task.name
	return "No task currently in progress"
