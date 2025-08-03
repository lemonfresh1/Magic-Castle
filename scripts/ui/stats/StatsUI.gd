# StatsUI.gd - Statistics interface displaying game stats
# Location: res://Magic-Castle/scripts/ui/stats/StatsUI.gd
# Last Updated: Created stats UI with overall tab and future mode tabs [Date]

extends PanelContainer

signal stats_closed

@onready var tab_container: TabContainer = $MarginContainer/TabContainer

func _ready():
	if not is_node_ready():
		return
		
	_setup_overall_tab()
	_add_coming_soon_message()

func _setup_overall_tab():
	var overall_tab = tab_container.get_node_or_null("Overall")
	if not overall_tab:
		return
	
	var scroll = overall_tab.find_child("ScrollContainer", true, false)
	if not scroll:
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 10)
		overall_tab.add_child(margin)
		
		var vbox = VBoxContainer.new()
		margin.add_child(vbox)
		
		scroll = ScrollContainer.new()
		vbox.add_child(scroll)
	
	# Apply scroll container settings
	_setup_scroll_container(scroll)
	
	# Create stats container
	var stats_container = scroll.get_child(0) if scroll.get_child_count() > 0 else null
	if not stats_container:
		stats_container = VBoxContainer.new()
		stats_container.name = "StatsContainer"
		stats_container.add_theme_constant_override("separation", 10)
		scroll.add_child(stats_container)
	
	_populate_stats(stats_container)

func _populate_stats(container: VBoxContainer):
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	
	if not StatsManager:
		return
	
	var total_stats = StatsManager.get_total_stats()
	var highscore = StatsManager.get_highscore()
	var longest_combo = StatsManager.get_longest_combo()
	
	# Overall Statistics
	_add_section_header(container, "Overall Statistics")
	_add_stat_row(container, "Games Played", str(total_stats.games_played))
	_add_stat_row(container, "Total Score", _format_number(total_stats.total_score))
	_add_stat_row(container, "Average Score", _format_number(int(StatsManager.get_average_score())))
	_add_stat_row(container, "Cards Clicked", _format_number(total_stats.cards_clicked))
	_add_stat_row(container, "Cards Drawn", _format_number(total_stats.cards_drawn))
	_add_stat_row(container, "Rounds Cleared", str(total_stats.rounds_cleared))
	_add_stat_row(container, "Clear Rate", "%.1f%%" % StatsManager.get_clear_rate())
	_add_stat_row(container, "Perfect Rounds", str(total_stats.perfect_rounds))
	_add_stat_row(container, "Invalid Clicks", str(total_stats.invalid_clicks))
	
	_add_separator(container)
	
	# Records
	_add_section_header(container, "Records")
	_add_stat_row(container, "Highscore", _format_number(highscore.score))
	if highscore.date:
		_add_stat_row(container, "Achieved", highscore.date)
	_add_stat_row(container, "Longest Combo", str(longest_combo.combo))
	if longest_combo.date:
		_add_stat_row(container, "Achieved", longest_combo.date)
	
	if total_stats.fastest_clear > 0:
		_add_stat_row(container, "Fastest Clear", "%.1f seconds" % total_stats.fastest_clear)
		_add_stat_row(container, "Most Cards Left", str(total_stats.most_cards_remaining))
	
	_add_separator(container)
	
	# Special Stats
	_add_section_header(container, "Special Stats")
	_add_stat_row(container, "Aces Played", str(total_stats.aces_played))
	_add_stat_row(container, "Kings Played", str(total_stats.kings_played))
	_add_stat_row(container, "Total Peaks Cleared", str(total_stats.total_peaks_cleared))
	_add_stat_row(container, "Suit Bonuses", str(total_stats.suit_bonuses))

func _add_coming_soon_message():
	# Add text about future mode tabs
	var overall_tab = tab_container.get_node_or_null("Overall")
	if overall_tab:
		var container = overall_tab.find_child("StatsContainer", true, false)
		if container:
			_add_separator(container)
			
			var future_label = Label.new()
			future_label.text = "Mode-specific stats tabs coming soon!"
			future_label.add_theme_font_size_override("font_size", 16)
			future_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			container.add_child(future_label)

func _add_section_header(container: VBoxContainer, text: String):
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	container.add_child(header)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	container.add_child(spacer)

func _add_stat_row(container: VBoxContainer, stat_name: String, value: String):
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
	container.add_child(hbox)

func _add_separator(container: VBoxContainer):
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	container.add_child(spacer)
	
	var sep = HSeparator.new()
	container.add_child(sep)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 20
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
	_populate_stats(tab_container.get_node("Overall").find_child("StatsContainer", true, false))

func hide_stats():
	visible = false
	stats_closed.emit()

func _setup_scroll_container(scroll_container: ScrollContainer):
	if not scroll_container:
		return
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(600, 300)
	scroll_container.self_modulate.a = 0  # Make transparent
