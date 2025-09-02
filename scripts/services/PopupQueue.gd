# PopupQueue.gd - Manages popup display queue, prevents overlaps
# Location: res://Pyramids/scripts/services/PopupQueue.gd
# Add to autoload!

extends Node

var current_popup: PopupBase = null
var popup_queue: Array[PopupBase] = []

func _ready():
	print("PopupQueue initialized")

func show_popup(popup: PopupBase):
	"""Queue a popup for display"""
	if current_popup == null:
		_display_popup(popup)
	else:
		popup_queue.append(popup)
		print("PopupQueue: Queued popup, %d waiting" % popup_queue.size())

func popup_closed(popup: PopupBase):
	"""Called when a popup closes"""
	if popup == current_popup:
		current_popup = null
		_show_next_popup()

func _display_popup(popup: PopupBase):
	"""Actually display a popup"""
	current_popup = popup
	get_tree().root.add_child(popup)
	popup.display()

func _show_next_popup():
	"""Show the next popup in queue"""
	if popup_queue.size() > 0:
		var next_popup = popup_queue.pop_front()
		if is_instance_valid(next_popup):
			_display_popup(next_popup)

func clear_queue():
	"""Clear all waiting popups"""
	popup_queue.clear()
	
func has_popup_active() -> bool:
	"""Check if any popup is currently showing"""
	return current_popup != null
