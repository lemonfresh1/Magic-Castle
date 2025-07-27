# AdManager.gd - Autoload for ad management
extends Node

signal ad_completed
signal ad_failed
signal ad_skipped

var is_ad_free: bool = false

func _ready() -> void:
	# Check if player purchased ad-free
	is_ad_free = _load_ad_free_status()

func show_interstitial() -> void:
	if is_ad_free:
		ad_skipped.emit()
		return
	
	if SettingsSystem.get_ad_skips() > 0:
		# Show skip button
		_show_skip_option()
	else:
		# Show ad directly
		_play_ad()

func show_rewarded_ad() -> void:
	# Always show rewarded ads, even for ad-free players
	_play_rewarded_ad()

func _show_skip_option() -> void:
	# Create skip dialog
	var dialog = preload("res://Magic-Castle/scenes/ui/components/AdSkipDialog.tscn").instantiate()
	get_tree().root.add_child(dialog)
	
	dialog.skip_pressed.connect(func():
		SettingsSystem.use_ad_skip()
		ad_skipped.emit()
		dialog.queue_free()
	)
	
	dialog.watch_pressed.connect(func():
		dialog.queue_free()
		_play_ad()
	)

func _play_ad() -> void:
	# Placeholder for actual ad integration
	print("Playing ad...")
	await get_tree().create_timer(3.0).timeout
	ad_completed.emit()

func _play_rewarded_ad() -> void:
	# Placeholder for rewarded ad
	print("Playing rewarded ad...")
	await get_tree().create_timer(5.0).timeout
	
	if randf() > 0.1:  # 90% success rate
		SettingsSystem.watch_ad_for_skip()
		ad_completed.emit()
	else:
		ad_failed.emit()

func purchase_ad_free() -> void:
	# Handle in-app purchase
	is_ad_free = true
	_save_ad_free_status(true)

func _load_ad_free_status() -> bool:
	var config = ConfigFile.new()
	if config.load("user://purchases.cfg") == OK:
		return config.get_value("purchases", "ad_free", false)
	return false

func _save_ad_free_status(status: bool) -> void:
	var config = ConfigFile.new()
	config.set_value("purchases", "ad_free", status)
	config.save("user://purchases.cfg")
