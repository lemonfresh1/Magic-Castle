extends PanelContainer

@onready var star_display: Label = $MarginContainer/HeaderContainer/StarDisplay

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_star_display()

func _update_star_display():
	var total_stars = StarManager.get_balance()
	star_display.text = "%d" % total_stars
