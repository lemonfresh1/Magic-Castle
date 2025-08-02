extends PanelContainer

@onready var option_button: OptionButton = $MarginContainer/TabContainer/TabName1/MarginContainer/VBoxContainer/HBoxContainer/OptionButton

func _ready():
	style_option_button(option_button)

func style_option_button(button: OptionButton):
	var popup = button.get_popup()
	
	# Popup background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#a487ff")
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_top = 5
	panel_style.border_color = Color.TRANSPARENT
	popup.add_theme_stylebox_override("panel", panel_style)
	
	# Hover style
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color("#b497ff")
	hover_style.corner_radius_top_left = 8
	hover_style.corner_radius_top_right = 8
	hover_style.corner_radius_bottom_left = 8
	hover_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("hover", hover_style)
