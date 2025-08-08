# StatsUI.gd - Statistics interface displaying game stats
# Location: res://Magic-Castle/scripts/ui/stats/StatsUI.gd
# Last Updated: Integrated with UIStyleManager [Date]

extends PanelContainer

signal stats_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer

func _ready():
	if not is_node_ready():
		return
	
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "stats_ui")
	
	_setup_overall_tab()
	_add_coming_soon_message()

func _setup_overall_tab():
	var overall_tab = tab_container.get_node_or_null("Overall")
	if not overall_tab:
		return
	
	# Use UIStyleManager for scrollable content
	await UIStyleManager.setup_scrollable_content(overall_tab, _populate_stats_content)

func _populate_stats_content(vbox: VBoxContainer) -> void:
	"""Content for stats display"""
	if not StatsManager:
		return
	
	var total_stats = StatsManager.get_total_stats()
	var highscore = StatsManager.get_highscore()
	var longest_combo = StatsManager.get_longest_combo()
	
	# Overall Statistics
	_add_section_header(vbox, "Overall Statistics")
	_add_stat_row(vbox, "Games Played", str(total_stats.games_played))
	_add_stat_row(vbox, "Total Score", _format_number(total_stats.total_score))
	_add_stat_row(vbox, "Average Score", _format_number(int(StatsManager.get_average_score())))
	_add_stat_row(vbox, "Cards Clicked", _format_number(total_stats.cards_clicked))
	_add_stat_row(vbox, "Cards Drawn", _format_number(total_stats.cards_drawn))
	_add_stat_row(vbox, "Rounds Cleared", str(total_stats.rounds_cleared))
	_add_stat_row(vbox, "Clear Rate", "%.1f%%" % StatsManager.get_clear_rate())
	_add_stat_row(vbox, "Perfect Rounds", str(total_stats.perfect_rounds))
	_add_stat_row(vbox, "Invalid Clicks", str(total_stats.invalid_clicks))
	
	_add_separator(vbox)
	
	# Records
	_add_section_header(vbox, "Records")
	_add_stat_row(vbox, "Highscore", _format_number(highscore.score))
	if highscore.date:
		_add_stat_row(vbox, "Achieved", highscore.date)
	_add_stat_row(vbox, "Longest Combo", str(longest_combo.combo))
	if longest_combo.date:
		_add_stat_row(vbox, "Achieved", longest_combo.date)
	
	if total_stats.fastest_clear > 0:
		_add_stat_row(vbox, "Fastest Clear", "%.1f seconds" % total_stats.fastest_clear)
		_add_stat_row(vbox, "Most Cards Left", str(total_stats.most_cards_remaining))
	
	_add_separator(vbox)
	
	# Special Stats
	_add_section_header(vbox, "Special Stats")
	_add_stat_row(vbox, "Aces Played", str(total_stats.aces_played))
	_add_stat_row(vbox, "Kings Played", str(total_stats.kings_played))
	_add_stat_row(vbox, "Total Peaks Cleared", str(total_stats.total_peaks_cleared))
	_add_stat_row(vbox, "Suit Bonuses", str(total_stats.suit_bonuses))

func _add_coming_soon_message():
	# Add text about future mode tabs
	var overall_tab = tab_container.get_node_or_null("Overall")
	if overall_tab:
		# Find the VBox that was created by UIStyleManager
		var scroll = overall_tab.find_child("ScrollContainer", true, false)
		if scroll and scroll.get_child_count() > 0:
			var margin = scroll.get_child(0)
			if margin and margin.get_child_count() > 0:
				var vbox = margin.get_child(0)
				if vbox:
					_add_separator(vbox)
					
					var future_label = Label.new()
					future_label.text = "Mode-specific stats tabs coming soon!"
					future_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_small"))
					future_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_500"))
					vbox.add_child(future_label)

func _add_section_header(container: VBoxContainer, text: String):
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_title"))
	header.add_theme_color_override("font_color", UIStyleManager.get_color("primary"))  # Green accent for headers
	container.add_child(header)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = UIStyleManager.get_spacing("space_2")
	container.add_child(spacer)

func _add_stat_row(container: VBoxContainer, stat_name: String, value: String):
	var hbox = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.custom_minimum_size.x = 250
	name_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_small"))
	name_label.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_small"))
	value_label.add_theme_color_override("font_color", UIStyleManager.get_color("success"))  # Green for values
	
	hbox.add_child(name_label)
	hbox.add_child(value_label)
	container.add_child(hbox)

func _add_separator(container: VBoxContainer):
	var spacer = Control.new()
	spacer.custom_minimum_size.y = UIStyleManager.get_spacing("space_5")
	container.add_child(spacer)
	
	var sep = HSeparator.new()
	sep.modulate = UIStyleManager.get_color("gray_300")
	container.add_child(sep)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = UIStyleManager.get_spacing("space_5")
	container.add_child(spacer2)

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

func show_stats():
	visible = true
	# Re-populate stats when showing
	_setup_overall_tab()

func hide_stats():
	visible = false
	stats_closed.emit()
