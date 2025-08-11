# ReferralUI.gd - Referral interface placeholder
# Location: res://Pyramids/scripts/ui/referral/ReferralUI.gd
# Last Updated: Integrated with UIStyleManager [Date]

extends PanelContainer

signal referral_closed

func _ready():
	# Apply panel styling
	UIStyleManager.apply_panel_style(self, "referral_ui")
	
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

func show_referral():
	visible = true

func hide_referral():
	visible = false
	referral_closed.emit()
