# StatsUI.gd - Statistics interface displaying game stats
# Location: res://Pyramids/scripts/ui/stats/StatsUI.gd
# Last Updated: Refactored to show solo/multi stats side-by-side [Date]

extends PanelContainer

signal stats_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "stats_ui")
	
	# Setup each mode tab with the grid layout
	_setup_mode_tab(tab_container.get_node("Test"), "test")
	_setup_mode_tab(tab_container.get_node("Rush"), "timed_rush")
	_setup_mode_tab(tab_container.get_node("Classic"), "classic")

func _setup_mode_tab(tab: Control, mode_id: String):
	"""Setup a mode tab with 3-column grid showing solo/multi stats"""
	
	# Find the ScrollContainer (it should be nested in the structure)
	var scroll_container = _find_scroll_container(tab)
	if not scroll_container:
		push_error("ScrollContainer not found in tab: " + tab.name)
		return
	
	# Clear any existing content
	for child in scroll_container.get_children():
		child.queue_free()
	
	# Create the grid container
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	scroll_container.add_child(grid)
	
	# Add headers
	_add_grid_header(grid, "Stat")
	_add_grid_header(grid, "Solo")
	_add_grid_header(grid, "Multi")
	
	# Add separator row
	_add_grid_separator(grid)
	
	# Get stats for both game types
	var solo_stats = StatsManager.get_mode_stats_typed(mode_id, "solo") if StatsManager else {}
	var multi_stats = StatsManager.get_mode_stats_typed(mode_id, "multi") if StatsManager else {}
	
	# Get highscores
	var solo_highscore = StatsManager.get_mode_highscore_typed(mode_id, "solo") if StatsManager else 0
	var multi_highscore = StatsManager.get_mode_highscore_typed(mode_id, "multi") if StatsManager else 0
	
	# Get multiplayer-specific stats
	var mp_stats = StatsManager.get_multiplayer_stats(mode_id) if StatsManager else {}
	
	# Add stat rows - Common stats
	_add_stat_row(grid, "Games Played", 
		str(solo_stats.get("games_played", 0)),
		str(multi_stats.get("games_played", 0)))
	
	_add_stat_row(grid, "Highscore",
		_format_number(solo_highscore),
		_format_number(multi_highscore))
	
	_add_stat_row(grid, "Total Score",
		_format_number(solo_stats.get("total_score", 0)),
		_format_number(multi_stats.get("total_score", 0)))
	
	# Calculate averages
	var solo_avg = 0
	if solo_stats.get("games_played", 0) > 0:
		solo_avg = solo_stats.get("total_score", 0) / solo_stats.get("games_played", 1)
	var multi_avg = 0
	if multi_stats.get("games_played", 0) > 0:
		multi_avg = multi_stats.get("total_score", 0) / multi_stats.get("games_played", 1)
	
	_add_stat_row(grid, "Average Score",
		_format_number(solo_avg),
		_format_number(multi_avg))
	
	_add_stat_row(grid, "Total Rounds",
		str(solo_stats.get("total_rounds", 0)),
		str(multi_stats.get("total_rounds", 0)))
	
	_add_stat_row(grid, "Perfect Rounds",
		str(solo_stats.get("perfect_rounds", 0)),
		str(multi_stats.get("perfect_rounds", 0)))
	
	_add_stat_row(grid, "Cards Clicked",
		_format_number(solo_stats.get("cards_clicked", 0)),
		_format_number(multi_stats.get("cards_clicked", 0)))
	
	_add_stat_row(grid, "Cards Drawn",
		_format_number(solo_stats.get("cards_drawn", 0)),
		_format_number(multi_stats.get("cards_drawn", 0)))
	
	_add_stat_row(grid, "Invalid Clicks",
		str(solo_stats.get("invalid_clicks", 0)),
		str(multi_stats.get("invalid_clicks", 0)))
	
	# Peak clears
	var solo_peaks = solo_stats.get("peak_clears", {})
	var multi_peaks = multi_stats.get("peak_clears", {})
	_add_stat_row(grid, "1-Peak Clears",
		str(solo_peaks.get("1", 0)),
		str(multi_peaks.get("1", 0)))
	
	_add_stat_row(grid, "2-Peak Clears",
		str(solo_peaks.get("2", 0)),
		str(multi_peaks.get("2", 0)))
	
	_add_stat_row(grid, "3-Peak Clears",
		str(solo_peaks.get("3", 0)),
		str(multi_peaks.get("3", 0)))
	
	_add_stat_row(grid, "Total Peaks",
		str(solo_stats.get("total_peaks_cleared", 0)),
		str(multi_stats.get("total_peaks_cleared", 0)))
	
	# Fastest clear
	var solo_fastest = solo_stats.get("fastest_clear", -1)
	var multi_fastest = multi_stats.get("fastest_clear", -1)
	_add_stat_row(grid, "Fastest Clear",
		"%.1fs" % solo_fastest if solo_fastest > 0 else "-",
		"%.1fs" % multi_fastest if multi_fastest > 0 else "-")
	
	_add_stat_row(grid, "Most Cards Left",
		str(solo_stats.get("most_cards_remaining", 0)),
		str(multi_stats.get("most_cards_remaining", 0)))
	
	_add_stat_row(grid, "Suit Bonuses",
		str(solo_stats.get("suit_bonuses", 0)),
		str(multi_stats.get("suit_bonuses", 0)))
	
	# Add separator before multiplayer-only stats
	_add_grid_separator(grid)
	
	# Multiplayer-only stats
	_add_stat_row(grid, "MMR",
		"-",
		str(mp_stats.get("mmr", 1000)))
	
	_add_stat_row(grid, "First Place",
		"-",
		str(mp_stats.get("first_place", 0)))
	
	_add_stat_row(grid, "Average Rank",
		"-",
		"%.2f" % mp_stats.get("average_rank", 0.0) if mp_stats.get("games", 0) > 0 else "-")
	
	# Calculate win rate
	var win_rate = 0.0
	if mp_stats.get("games", 0) > 0:
		win_rate = float(mp_stats.get("first_place", 0)) / float(mp_stats.get("games", 0)) * 100.0
	
	_add_stat_row(grid, "Win Rate",
		"-",
		"%.1f%%" % win_rate if mp_stats.get("games", 0) > 0 else "-")
	
	_add_stat_row(grid, "Current Win Streak",
		"-",
		str(mp_stats.get("current_win_streak", 0)))
	
	_add_stat_row(grid, "Best Win Streak",
		"-",
		str(mp_stats.get("best_win_streak", 0)))

func _find_scroll_container(node: Control) -> ScrollContainer:
	"""Recursively find the ScrollContainer in the node tree"""
	if node is ScrollContainer:
		return node
	
	for child in node.get_children():
		var result = _find_scroll_container(child)
		if result:
			return result
	
	return null

func _add_grid_header(grid: GridContainer, text: String):
	"""Add a header cell to the grid"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
	grid.add_child(label)

func _add_grid_separator(grid: GridContainer):
	"""Add a separator row to the grid"""
	for i in range(3):
		var sep = HSeparator.new()
		sep.add_theme_color_override("color", ThemeConstants.colors.gray_300)
		grid.add_child(sep)

func _add_stat_row(grid: GridContainer, stat_name: String, solo_value: String, multi_value: String):
	"""Add a stat row with 3 columns"""
	
	# Stat name
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
	grid.add_child(name_label)
	
	# Solo value
	var solo_label = Label.new()
	solo_label.text = solo_value
	solo_label.add_theme_font_size_override("font_size", 16)
	solo_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
	grid.add_child(solo_label)
	
	# Multi value
	var multi_label = Label.new()
	multi_label.text = multi_value
	multi_label.add_theme_font_size_override("font_size", 16)
	multi_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_900)
	grid.add_child(multi_label)

func _format_number(num: int) -> String:
	"""Add commas to large numbers"""
	if num == 0:
		return "0"
	
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

func show_stats():
	visible = true

func hide_stats():
	visible = false
	stats_closed.emit()
