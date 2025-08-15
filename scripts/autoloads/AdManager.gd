# AdManager.gd - Simple ad management system
# Path: res://Pyramids/scripts/autoloads/AdManager.gd
# Last Updated: Simplified implementation for future monetization
#
# AdManager handles:
# - Interstitial ads every 5 rounds (max 10/day)
# - Daily skip system (2 free + farmable via rewarded ads)
# - Season pass integration for ad-free experience
# - Skip inventory management (max 11 skips)
# - Daily reset logic for fair monetization
#
# Flow: GameState (rounds) → AdManager → UI dialogs → Player choice
# Dependencies: GameState (for round tracking), Season pass system (future)

extends Node

# === SIGNALS ===
signal ad_completed
signal ad_failed
signal ad_skipped
signal skip_count_changed(skips_remaining: int)

# === CONSTANTS ===
const ROUNDS_BETWEEN_ADS = 5
const MAX_ADS_PER_DAY = 10
const FREE_SKIPS_PER_DAY = 2
const SKIPS_PER_WATCHED_AD = 3
const MAX_SKIP_INVENTORY = 11

# === STATE ===
var is_ad_free: bool = false
var has_season_pass: bool = false
var ads_shown_today: int = 0
var skips_remaining: int = 2
var last_reset_date: String = ""
var rounds_since_last_ad: int = 0

# === SAVE PATH ===
const SAVE_PATH = "user://ad_data.save"

func _ready() -> void:
	print("AdManager initialized")
	load_ad_data()
	_check_daily_reset()
	
	# Connect to game signals
	if GameState:
		GameState.round_completed.connect(_on_round_completed)

# === DAILY RESET ===
func _check_daily_reset() -> void:
	var today = Time.get_date_string_from_system()
	if last_reset_date != today:
		ads_shown_today = 0
		skips_remaining = FREE_SKIPS_PER_DAY
		last_reset_date = today
		save_ad_data()
		skip_count_changed.emit(skips_remaining)
		print("AdManager: Daily reset - %d skips available" % skips_remaining)

# === AD TRIGGERS ===
func _on_round_completed(_round_number: int) -> void:
	rounds_since_last_ad += 1
	
	# Check if we should show an ad
	if should_show_ad():
		show_interstitial()

func should_show_ad() -> bool:
	"""Determine if an ad should be shown"""
	if is_ad_free or has_season_pass:
		return false
	
	if ads_shown_today >= MAX_ADS_PER_DAY:
		return false
	
	if rounds_since_last_ad < ROUNDS_BETWEEN_ADS:
		return false
	
	return true

# === AD DISPLAY ===
func show_interstitial() -> void:
	"""Show an interstitial ad or skip option"""
	if is_ad_free or has_season_pass:
		ad_skipped.emit()
		return
	
	_check_daily_reset()
	
	if skips_remaining > 0:
		_show_skip_dialog()
	else:
		_play_ad()

func _show_skip_dialog() -> void:
	"""Show dialog with skip option"""
	# In real implementation, this would show a UI dialog
	# For now, we'll simulate it
	print("AdManager: Skip available (%d remaining)" % skips_remaining)
	
	# Create a simple confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Skip this ad? (%d skips remaining)" % skips_remaining
	dialog.add_cancel_button("Watch Ad")
	dialog.title = "Advertisement"
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		use_skip()
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		_play_ad()
		dialog.queue_free()
	)

func _play_ad() -> void:
	"""Play an ad (placeholder for actual ad SDK)"""
	print("AdManager: Playing ad...")
	
	# In real implementation, this would call the ad SDK
	# For now, simulate with a timer
	await get_tree().create_timer(3.0).timeout
	
	ads_shown_today += 1
	rounds_since_last_ad = 0
	save_ad_data()
	ad_completed.emit()
	print("AdManager: Ad completed (%d/%d today)" % [ads_shown_today, MAX_ADS_PER_DAY])

# === SKIP MANAGEMENT ===
func use_skip() -> bool:
	"""Use an ad skip if available"""
	if skips_remaining > 0:
		skips_remaining -= 1
		rounds_since_last_ad = 0
		save_ad_data()
		skip_count_changed.emit(skips_remaining)
		ad_skipped.emit()
		print("AdManager: Skip used (%d remaining)" % skips_remaining)
		return true
	return false

func watch_ad_for_skips() -> void:
	"""Watch a rewarded ad to earn skips"""
	print("AdManager: Playing rewarded ad for skips...")
	
	# Simulate rewarded ad
	await get_tree().create_timer(5.0).timeout
	
	# Grant skips
	var previous_skips = skips_remaining
	skips_remaining = min(skips_remaining + SKIPS_PER_WATCHED_AD, MAX_SKIP_INVENTORY)
	var granted = skips_remaining - previous_skips
	
	save_ad_data()
	skip_count_changed.emit(skips_remaining)
	ad_completed.emit()
	
	print("AdManager: Rewarded ad completed, +%d skips (total: %d)" % [granted, skips_remaining])

func get_skip_count() -> int:
	"""Get current number of skips available"""
	_check_daily_reset()
	return skips_remaining

# === PURCHASES ===
func purchase_ad_free() -> void:
	"""Handle ad-free purchase"""
	is_ad_free = true
	save_ad_data()
	print("AdManager: Ad-free purchased - ads permanently disabled")

func activate_season_pass() -> void:
	"""Activate season pass (disables ads)"""
	has_season_pass = true
	save_ad_data()
	print("AdManager: Season pass activated - ads disabled")

func deactivate_season_pass() -> void:
	"""Deactivate season pass (for expired passes)"""
	has_season_pass = false
	save_ad_data()
	print("AdManager: Season pass expired - ads re-enabled")

# === PERSISTENCE ===
func save_ad_data() -> void:
	var data = {
		"is_ad_free": is_ad_free,
		"has_season_pass": has_season_pass,
		"ads_shown_today": ads_shown_today,
		"skips_remaining": skips_remaining,
		"last_reset_date": last_reset_date,
		"rounds_since_last_ad": rounds_since_last_ad
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_ad_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		
		if data:
			is_ad_free = data.get("is_ad_free", false)
			has_season_pass = data.get("has_season_pass", false)
			ads_shown_today = data.get("ads_shown_today", 0)
			skips_remaining = data.get("skips_remaining", FREE_SKIPS_PER_DAY)
			last_reset_date = data.get("last_reset_date", "")
			rounds_since_last_ad = data.get("rounds_since_last_ad", 0)

# === DEBUG ===
func debug_status() -> void:
	"""Print current ad system status"""
	print("\n=== AD MANAGER STATUS ===")
	print("Ad-free: %s" % is_ad_free)
	print("Season Pass: %s" % has_season_pass)
	print("Ads today: %d/%d" % [ads_shown_today, MAX_ADS_PER_DAY])
	print("Skips: %d/%d" % [skips_remaining, MAX_SKIP_INVENTORY])
	print("Rounds since ad: %d/%d" % [rounds_since_last_ad, ROUNDS_BETWEEN_ADS])
	print("=========================\n")

func debug_grant_skips(amount: int = 5) -> void:
	"""Grant skips for testing"""
	skips_remaining = min(skips_remaining + amount, MAX_SKIP_INVENTORY)
	save_ad_data()
	skip_count_changed.emit(skips_remaining)
	print("AdManager: Granted %d skips (total: %d)" % [amount, skips_remaining])

func debug_reset_daily() -> void:
	"""Force daily reset for testing"""
	last_reset_date = ""
	_check_daily_reset()
