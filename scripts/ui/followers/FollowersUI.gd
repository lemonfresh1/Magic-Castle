# FollowersUI.gd - Followers interface placeholder
# Location: res://Magic-Castle/scripts/ui/followers/FollowersUI.gd
# Last Updated: Integrated with UIStyleManager [Date]

extends PanelContainer

signal followers_closed

func _ready():
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "followers_ui")
	
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

func show_followers():
	visible = true

func hide_followers():
	visible = false
	followers_closed.emit()
