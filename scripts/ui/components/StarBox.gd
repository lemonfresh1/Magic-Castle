# StarBox.gd - Star display component that auto-updates
# Location: res://Magic-Castle/scripts/ui/components/StarBox.gd
# Last Updated: Fixed signal reconnection issue [Date]

extends PanelContainer

@onready var star_display: Label = $MarginContainer/HeaderContainer/StarDisplay
var is_connected: bool = false

func _ready() -> void:
	# Initial display
	update_star_display()
	
	# Connect to StarManager for auto-updates
	_ensure_signal_connection()
	
	# Also update when becoming visible
	visibility_changed.connect(_on_visibility_changed)

func _ensure_signal_connection():
	"""Ensure we're connected to StarManager signals"""
	if not StarManager:
		print("[StarBox] StarManager not found!")
		return
	
	# Disconnect if already connected (prevents duplicates)
	if is_connected and StarManager.stars_changed.is_connected(_on_stars_changed):
		StarManager.stars_changed.disconnect(_on_stars_changed)
		is_connected = false
	
	# Connect fresh
	if not StarManager.stars_changed.is_connected(_on_stars_changed):
		StarManager.stars_changed.connect(_on_stars_changed)
		is_connected = true
		print("[StarBox] Connected to StarManager.stars_changed")

func _on_visibility_changed():
	"""When becoming visible, ensure connection and update display"""
	if visible:
		_ensure_signal_connection()
		update_star_display()

func update_star_display():
	"""Update the star display with current balance"""
	if not star_display:
		return
		
	var total_stars = StarManager.get_balance()
	star_display.text = "%d" % total_stars
	print("[StarBox] Updated display to %d stars" % total_stars)

func _on_stars_changed(new_total: int, change: int):
	"""Called when stars change in StarManager"""
	print("[StarBox] Stars changed signal received: %d (change: %d)" % [new_total, change])
	update_star_display()
	
	# Optional: Add a brief animation for the change
	if change != 0:
		_animate_star_change(change)

func _animate_star_change(change: int):
	"""Brief animation when stars change"""
	if not star_display:
		return
		
	# Create a tween for a subtle pulse effect
	var tween = create_tween()
	
	# Color change based on gain/loss
	var target_color = Color("#4ADE80") if change > 0 else Color("#F87171")
	
	# Pulse the color
	tween.tween_property(star_display, "modulate", target_color, 0.2)
	tween.tween_property(star_display, "modulate", Color.WHITE, 0.3)
	
	# Small scale pulse
	tween.set_parallel(true)
	tween.tween_property(star_display, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(star_display, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.15)

func _enter_tree():
	"""Re-establish connection when entering tree"""
	if is_inside_tree():
		call_deferred("_ensure_signal_connection")
		call_deferred("update_star_display")

func _exit_tree():
	"""Clean up signal connections"""
	if StarManager and is_connected and StarManager.stars_changed.is_connected(_on_stars_changed):
		StarManager.stars_changed.disconnect(_on_stars_changed)
		is_connected = false
