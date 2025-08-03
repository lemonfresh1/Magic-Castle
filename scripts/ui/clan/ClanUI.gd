# ClanUI.gd - Clan interface placeholder
# Location: res://Magic-Castle/scripts/ui/clan/ClanUI.gd
# Last Updated: Created placeholder clan UI [Date]

extends PanelContainer

signal clan_closed

func _ready():
	_setup_coming_soon()

func _setup_coming_soon():
	var margin = $MarginContainer
	if not margin:
		return
		
	var label = Label.new()
	label.text = "Coming Soon!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.643, 0.529, 1, 1))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	margin.add_child(label)

func show_clan():
	visible = true

func hide_clan():
	visible = false
	clan_closed.emit()
