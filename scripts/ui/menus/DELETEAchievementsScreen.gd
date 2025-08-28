# AchievementsScreen.gd - Displays achievements and stats
# res://Pyramids/scripts/ui/menus/AchievementsScreen.gd 
extends Control

@onready var tab_container = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var achievement_list = $Panel/MarginContainer/VBoxContainer/TabContainer/Achievements/ScrollContainer/AchievementList
@onready var stats_container = $Panel/MarginContainer/VBoxContainer/TabContainer/Stats/ScrollContainer/StatsContainer
@onready var back_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var title_label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/Title
@onready var star_display: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/StarDisplay


var achievement_item_scene = preload("res://Pyramids/scenes/ui/menus/AchievementItem.tscn")

signal back_pressed

func _ready():
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)

	_update_star_display()
	_populate_achievements()
	_populate_stats()

func _populate_achievements():
	print("Populating achievements...")
	
	# Clear existing
	for child in achievement_list.get_children():
		child.queue_free()
	
	# Create grid container for 3 columns layout
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	achievement_list.add_child(grid)
	
	print("Grid created, adding achievements...")
	
	# Add all 18 achievements
	var achievement_ids = [
		# Starter tier
		"first_game", "board_clear", "play_10", "combo_5", "speed_clear",
		# Skill tier
		"combo_10", "all_peaks", "score_10k", "perfect_round", 
		"ace_hunter", "king_slayer", "suit_master",
		# Grind tier
		"peak_crusher", "card_collector", "tap_master", 
		"veteran", "perfect_week",
		# Legendary tier
		"million_club"
	]
	
	for id in achievement_ids:
		print("Creating achievement: ", id)
		var item = achievement_item_scene.instantiate()
		if item:
			grid.add_child(item)
			item.setup(id)
		else:
			print("Failed to instantiate achievement item!")

func _populate_stats():
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()
	
	var total_stats = StatsManager.get_total_stats()
	var highscore = StatsManager.get_highscore()
	var longest_combo = StatsManager.get_longest_combo()
	
	# Overall Statistics
	_add_section_header("Overall Statistics")
	_add_stat_row("Games Played", str(total_stats.games_played))
	_add_stat_row("Total Score", _format_number(total_stats.total_score))
	_add_stat_row("Average Score", _format_number(int(StatsManager.get_average_score())))
	_add_stat_row("Cards Clicked", _format_number(total_stats.cards_clicked))
	_add_stat_row("Cards Drawn", _format_number(total_stats.cards_drawn))
	_add_stat_row("Rounds Cleared", str(total_stats.rounds_cleared))
	_add_stat_row("Clear Rate", "%.1f%%" % StatsManager.get_clear_rate())
	_add_stat_row("Perfect Rounds", str(total_stats.perfect_rounds))
	_add_stat_row("Invalid Clicks", str(total_stats.invalid_clicks))
	
	_add_separator()
	
	# Records
	_add_section_header("Records")
	_add_stat_row("Highscore", _format_number(highscore.score))
	if highscore.date:
		_add_stat_row("Achieved", highscore.date)
	_add_stat_row("Longest Combo", str(longest_combo.combo))
	if longest_combo.date:
		_add_stat_row("Achieved", longest_combo.date)
	
	if total_stats.fastest_clear > 0:
		_add_stat_row("Fastest Clear", "%.1f seconds" % total_stats.fastest_clear)
		_add_stat_row("Most Cards Left", str(total_stats.most_cards_remaining))
	
	_add_separator()
	
	# Tri-Peaks Mode
	_add_section_header("Tri-Peaks Mode")
	var tri_peaks = StatsManager.get_mode_stats("tri_peaks")
	_add_stat_row("Games", str(tri_peaks.games_played))
	_add_stat_row("Clear Rate", "%.1f%%" % StatsManager.get_clear_rate("tri_peaks"))
	_add_stat_row("Perfect Rounds", str(tri_peaks.perfect_rounds))
	
	_add_separator()
	
	# Rush Mode
	_add_section_header("Rush Mode") 
	var rush = StatsManager.get_mode_stats("rush")
	_add_stat_row("Games", str(rush.games_played))
	_add_stat_row("Clear Rate", "%.1f%%" % StatsManager.get_clear_rate("rush"))
	_add_stat_row("Perfect Rounds", str(rush.perfect_rounds))
	
	_add_separator()
	
	# Chill Mode
	_add_section_header("Chill Mode")
	var chill = StatsManager.get_mode_stats("chill")
	_add_stat_row("Games", str(chill.games_played))
	_add_stat_row("Clear Rate", "%.1f%%" % StatsManager.get_clear_rate("chill"))
	_add_stat_row("Perfect Rounds", str(chill.perfect_rounds))
	
	_add_separator()
	
	# Test Mode
	_add_section_header("Test Mode")
	var test = StatsManager.get_mode_stats("test")
	_add_stat_row("Games", str(test.games_played))
	_add_stat_row("Clear Rate", "%.1f%%" % StatsManager.get_clear_rate("test"))
	_add_stat_row("Perfect Rounds", str(test.perfect_rounds))

func _add_section_header(text: String):
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	stats_container.add_child(header)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	stats_container.add_child(spacer)

func _add_stat_row(stat_name: String, value: String):
	var hbox = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.custom_minimum_size.x = 250
	name_label.add_theme_font_size_override("font_size", 16)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))  # Green
	value_label.add_theme_font_size_override("font_size", 16)
	
	hbox.add_child(name_label)
	hbox.add_child(value_label)
	stats_container.add_child(hbox)

func _add_separator():
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	stats_container.add_child(spacer)
	
	var sep = HSeparator.new()
	stats_container.add_child(sep)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 20
	stats_container.add_child(spacer2)

func _format_number(num: int) -> String:
	# Add commas to large numbers
	var s = str(num)
	var result = ""
	var i = s.length() - 1
	var count = 0
	
	while i >= 0:
		if count == 3:
			result = "," + result
			count = 0
		result = s[i] + result
		count += 1
		i -= 1
	
	return result

func _on_tab_changed(tab: int):
	match tab:
		0:  # Achievements
			title_label.text = "Achievements"
			_update_star_display()  # Add this
		1:  # Stats
			title_label.text = "Statistics"
			_update_star_display()  # Add this

func _on_back_pressed():
	back_pressed.emit()
	get_tree().change_scene_to_file("res://Pyramids/scenes/ui/menus/MainMenu.tscn")

func _update_star_display():
	# Create star display if it doesn't exist
	if not star_display:
		star_display = Label.new()
		star_display.name = "StarDisplay"
		
		# Find the HBoxContainer that has the title and back button
		var hbox = $Panel/MarginContainer/VBoxContainer/HBoxContainer
		if hbox:
			# Add spacer to push star display to the right
			var spacer = Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(spacer)
			
			# Add the star display
			hbox.add_child(star_display)
	
	# Update the star count from StarManager
	if star_display:
		var total_stars = StarManager.get_balance()
		star_display.text = "⭐ %d" % total_stars
		star_display.add_theme_font_size_override("font_size", 20)
		star_display.add_theme_color_override("font_color", Color.YELLOW)
