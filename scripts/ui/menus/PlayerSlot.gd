# PlayerSlot.gd
extends PanelContainer

signal player_clicked(slot_index: int)
signal invite_clicked(slot_index: int)

@export var slot_index: int = 0
var is_occupied: bool = false
var player_data: Dictionary = {}

func set_empty():
	# Show dashed border and + icon
	is_occupied = false
	# Update visual to show invite state
	
func set_player(data: Dictionary):
	# Show player name, avatar, ready status
	is_occupied = true
	player_data = data
	# Update visual with player info
