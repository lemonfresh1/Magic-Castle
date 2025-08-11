# shipped.gd - Project Roadmap & Progress Tracker
# CMD+SHIFT+X to run in output
# Path: res://Pyramids/shipped.gd
# Run this script to see project status: Click "Run" in script editor
@tool
extends EditorScript

# Status: "done" ✅, "working" 🔄, "open" ⬜
var roadmap = {
	"phase_0_mobile_ui": {
		"status": "done",
		"name": "Mobile UI Implementation",
		"tasks": {
			"0_1_mobile_layout": {
				"status": "done",
				"name": "Mobile Layout System",
				"subtasks": {
					"screen_adaptation": {"status": "done", "name": "2400x1080 landscape layout"},
					"card_scaling": {"status": "done", "name": "Mobile card size constants"},
					"pyramid_layout": {"status": "done", "name": "Compressed pyramid for mobile"}
				}
			},
			"0_2_mobile_topbar": {
				"status": "done",
				"name": "Mobile Top Bar UI",
				"subtasks": {
					"scene_structure": {"status": "done", "name": "HBox layout with spacers"},
					"timer_display": {"status": "done", "name": "Green timer bar with label"},
					"draw_pile": {"status": "done", "name": "Draw pile with correct count"},
					"card_slots": {"status": "done", "name": "Centered card slots with unlock UI"},
					"combo_bar": {"status": "done", "name": "Yellow combo bar (right-to-left)"},
					"pause_system": {"status": "done", "name": "Pause/Resume functionality"}
				}
			},
			"0_3_mobile_fixes": {
				"status": "done",
				"name": "Mobile Bug Fixes",
				"subtasks": {
					"end_score_bug": {"status": "done", "name": "Fixed final score calculation"},
					"slot_visibility": {"status": "done", "name": "Fixed card slot backgrounds"},
					"draw_limit_display": {"status": "done", "name": "Show mode-specific draw limits"}
				}
			}
		}
	},
	"phase_1_game_modes": {
		"status": "done",
		"name": "Additional Game Modes",
		"tasks": {
			"1_1_game_mode_manager": {
				"status": "done",
				"name": "Create GameModeManager Autoload",
				"subtasks": {
					"base_class": {"status": "done", "name": "Create GameModeBase class"},
					"manager_autoload": {"status": "done", "name": "Create GameModeManager autoload"},
					"mode_registration": {"status": "done", "name": "Implement mode registration system"}
				}
			},
			"1_2_game_modes": {
				"status": "done",
				"name": "Implement Game Modes",
				"subtasks": {
					"tri_peaks": {"status": "done", "name": "Refactor existing to TriPeaksMode"},
					"rush_mode": {"status": "done", "name": "Create RushMode (5 rounds, 1.5x score)"},
					"chill_mode": {"status": "done", "name": "Create ChillMode (no timer, 720s combo)"},
					"test_mode": {"status": "done", "name": "Create TestMode (2 rounds for testing)"}
				}
			},
			"1_3_ui_updates": {
				"status": "done",
				"name": "Update UI for Modes",
				"subtasks": {
					"mode_select": {"status": "done", "name": "Mode selection in settings"},
					"timer_adapt": {"status": "done", "name": "Hide timer in chill mode"},
					"score_display": {"status": "done", "name": "Show mode in score screen"}
				}
			}
		}
	},
	"phase_2_statistics": {
		"status": "done",
		"name": "Statistics System",
		"tasks": {
			"2_1_stats_manager": {
				"status": "done",
				"name": "Create StatsManager",
				"subtasks": {
					"manager_autoload": {"status": "done", "name": "Create StatsManager autoload"},
					"save_load": {"status": "done", "name": "Implement save/load system"},
					"tracking": {"status": "done", "name": "Track all game statistics"},
					"integration": {"status": "done", "name": "Hook into game systems"}
				}
			},
			"2_2_stats_display": {
				"status": "done",
				"name": "Statistics Display",
				"subtasks": {
					"stats_screen": {"status": "done", "name": "Stats tab in achievements screen"},
					"formatting": {"status": "done", "name": "Number formatting and percentages"},
					"mode_stats": {"status": "done", "name": "Per-mode statistics"}
				}
			}
		}
	},
	"phase_3_achievements": {
		"status": "working",
		"name": "Achievements System",
		"tasks": {
			"3_1_achievement_manager": {
				"status": "done",
				"name": "Create AchievementManager",
				"subtasks": {
					"manager_autoload": {"status": "done", "name": "Create AchievementManager autoload"},
					"definitions": {"status": "done", "name": "Define 9 achievements"},
					"tracking": {"status": "done", "name": "Implement progress tracking"},
					"persistence": {"status": "done", "name": "Save/load achievement data"}
				}
			},
			"3_2_achievement_ui": {
				"status": "working",
				"name": "Achievement UI Components",
				"subtasks": {
					"achievement_screen": {"status": "done", "name": "3x3 grid display"},
					"achievement_items": {"status": "done", "name": "Individual achievement cards"},
					"progress_bars": {"status": "done", "name": "Progress indicators"},
					"notification": {"status": "done", "name": "Unlock notification popup"}
				}
			},
			"3_3_integration": {
				"status": "working",
				"name": "Achievement Integration",
				"subtasks": {
					"game_hooks": {"status": "done", "name": "Hook into game events"},
					"unlock_detection": {"status": "done", "name": "Fix timing issues"},
					"testing": {"status": "open", "name": "Test all achievement triggers"}
				}
			}
		}
	},
	"phase_4_meta_progression": {
		"status": "open",
		"name": "Meta Progression System",
		"tasks": {
			"4_1_star_currency": {
				"status": "open",
				"name": "Star Currency System",
				"subtasks": {
					"currency_manager": {"status": "open", "name": "Create currency manager"},
					"star_rewards": {"status": "open", "name": "Implement star rewards"},
					"display": {"status": "open", "name": "Show stars in UI"}
				}
			},
			"4_2_unlockables": {
				"status": "open",
				"name": "Unlockable Content",
				"subtasks": {
					"shop_system": {"status": "open", "name": "Create shop interface"},
					"board_skins": {"status": "open", "name": "Unlockable backgrounds"},
					"card_backs": {"status": "open", "name": "Custom card designs"}
				}
			},
			"4_3_daily_missions": {
				"status": "open",
				"name": "Daily Missions",
				"subtasks": {
					"mission_system": {"status": "open", "name": "Mission generation"},
					"progress_tracking": {"status": "open", "name": "Track mission progress"},
					"rewards": {"status": "open", "name": "Mission rewards"}
				}
			}
		}
	},
	"phase_5_multiplayer": {
		"status": "open",
		"name": "Multiplayer System",
		"tasks": {
			"5_1_infrastructure": {
				"status": "open",
				"name": "Network Infrastructure",
				"subtasks": {
					"websocket_server": {"status": "open", "name": "WebSocket server setup"},
					"client_connection": {"status": "open", "name": "Client connection handling"},
					"state_sync": {"status": "open", "name": "Game state synchronization"}
				}
			},
			"5_2_game_modes": {
				"status": "open",
				"name": "Multiplayer Game Modes",
				"subtasks": {
					"vs_mode": {"status": "open", "name": "1v1 versus mode"},
					"race_mode": {"status": "open", "name": "Race to clear board"},
					"coop_mode": {"status": "open", "name": "Cooperative mode"}
				}
			},
			"5_3_matchmaking": {
				"status": "open",
				"name": "Matchmaking System",
				"subtasks": {
					"lobby_system": {"status": "open", "name": "Game lobby creation"},
					"quick_match": {"status": "open", "name": "Quick match algorithm"},
					"ranking": {"status": "open", "name": "Player ranking system"}
				}
			}
		}
	},
	"phase_6_polish": {
		"status": "open",
		"name": "Polish & Enhancement",
		"tasks": {
			"6_1_animations": {
				"status": "open",
				"name": "Enhanced Animations",
				"subtasks": {
					"card_animations": {"status": "open", "name": "Smooth card movements"},
					"combo_effects": {"status": "open", "name": "Combo visual effects"},
					"victory_animation": {"status": "open", "name": "Board clear celebration"}
				}
			},
			"6_2_audio": {
				"status": "open",
				"name": "Audio System",
				"subtasks": {
					"sound_effects": {"status": "open", "name": "Card flip, combo sounds"},
					"music_system": {"status": "open", "name": "Background music tracks"},
					"audio_settings": {"status": "open", "name": "Volume controls"}
				}
			},
			"6_3_quality_of_life": {
				"status": "open",
				"name": "Quality of Life",
				"subtasks": {
					"tutorial": {"status": "open", "name": "Interactive tutorial"},
					"confirmation_dialogs": {"status": "open", "name": "Exit confirmations"},
					"undo_system": {"status": "open", "name": "Undo last move"}
				}
			}
		}
	}
}

func _run():
	print("\n==============")
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
	print("==============")
	print("📊 Overall Progress: %d/%d tasks (%.1f%%)" % [completed_tasks, total_tasks, progress])
	print("==============\n")
	
	# Show what's currently being worked on
	print("🔄 CURRENTLY WORKING ON:")
	var working_count = 0
	for phase_key in roadmap:
		var phase = roadmap[phase_key]
		if phase.status == "working":
			print("  - " + phase.name)
			for task_key in phase.tasks:
				var task = phase.tasks[task_key]
				if task.status == "working":
					print("    └─ " + task.name)
			working_count += 1
	
	if working_count == 0:
		print("  Nothing in active development")
	
	print("\n==============\n")

func _get_status_icon(status: String) -> String:
	match status:
		"done": return "✅"
		"working": return "🔄"
		"open": return "⬜"
		_: return "❓"
