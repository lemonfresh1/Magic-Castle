# StarManager.gd - Autoload for star currency management
# Path: res://Magic-Castle/scripts/autoloads/StarManager.gd
# Manages star currency earning, spending, and tracking
extends Node

signal stars_changed(new_total: int, change: int)
signal stars_spent(amount: int, item: String)

const SAVE_PATH = "user://stars.save"

# Star balance
var total_stars: int = 0
var lifetime_earned: int = 0
var lifetime_spent: int = 0
var rewards_enabled: bool = true


# Transaction history (last 50)
var transaction_history: Array = []
const MAX_HISTORY = 50

func _ready():
	print("StarManager initializing...")
	load_stars()
	
	# Connect to achievement unlocks for star rewards
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	
	print("StarManager ready - Balance: %d stars" % total_stars)

# === EARNING STARS ===
func add_stars(amount: int, source: String = "") -> void:
	# Allow certain sources to bypass rewards_enabled check
	var bypass_sources = ["season_pass", "holiday_pass", "achievement", "debug", "level_up", "shop_refund"]
	var should_bypass = false
	
	for bypass_source in bypass_sources:
		if bypass_source in source:
			should_bypass = true
			break
	
	if not should_bypass and not rewards_enabled and source != "post_game_total":
		print("[StarManager] Blocked %d stars from %s (rewards disabled)" % [amount, source])
		return
		
	if amount <= 0:
		return
	
	total_stars += amount
	lifetime_earned += amount
	
	# Record transaction
	_add_transaction({
		"type": "earn",
		"amount": amount,
		"source": source,
		"timestamp": Time.get_unix_time_from_system(),
		"balance": total_stars
	})
	
	save_stars()
	stars_changed.emit(total_stars, amount)
	
	print("[StarManager] Earned %d stars from %s. New balance: %d" % [amount, source, total_stars])
	print("[StarManager] Signal emitted with %d connected listeners" % stars_changed.get_connections().size())

# === SPENDING STARS ===
func spend_stars(amount: int, item: String) -> bool:
	if amount <= 0 or amount > total_stars:
		return false
	
	total_stars -= amount
	lifetime_spent += amount
	
	# Record transaction
	_add_transaction({
		"type": "spend",
		"amount": amount,
		"item": item,
		"timestamp": Time.get_unix_time_from_system(),
		"balance": total_stars
	})
	
	save_stars()
	stars_changed.emit(total_stars, -amount)
	stars_spent.emit(amount, item)
	
	print("Spent %d stars on %s. New balance: %d" % [amount, item, total_stars])
	return true

# === BALANCE QUERIES ===
func get_balance() -> int:
	return total_stars

func can_afford(amount: int) -> bool:
	return total_stars >= amount

func get_lifetime_earned() -> int:
	return lifetime_earned

func get_lifetime_spent() -> int:
	return lifetime_spent

# === ACHIEVEMENT INTEGRATION ===
func _on_achievement_unlocked(achievement_id: String):
	var achievement = AchievementManager.achievements.get(achievement_id, {})
	var star_reward = achievement.get("stars", 0)
	
	if star_reward > 0:
		add_stars(star_reward, "achievement_%s" % achievement_id)

# === TRANSACTION HISTORY ===
func _add_transaction(transaction: Dictionary):
	transaction_history.push_front(transaction)
	
	# Keep only last MAX_HISTORY transactions
	if transaction_history.size() > MAX_HISTORY:
		transaction_history.resize(MAX_HISTORY)

func get_transaction_history() -> Array:
	return transaction_history

func get_recent_transactions(count: int = 10) -> Array:
	return transaction_history.slice(0, min(count, transaction_history.size()))

# === PERSISTENCE ===
func save_stars():
	var save_data = {
		"version": 1,
		"total_stars": total_stars,
		"lifetime_earned": lifetime_earned,
		"lifetime_spent": lifetime_spent,
		"history": transaction_history
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_stars():
	if not FileAccess.file_exists(SAVE_PATH):
		# Check if player has achievements to calculate initial stars
		_calculate_initial_stars()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		if save_data and save_data.has("total_stars"):
			total_stars = save_data.get("total_stars", 0)
			lifetime_earned = save_data.get("lifetime_earned", total_stars)
			lifetime_spent = save_data.get("lifetime_spent", 0)
			transaction_history = save_data.get("history", [])

func _calculate_initial_stars():
	# If this is first load, calculate stars from achievements
	var earned_from_achievements = AchievementManager.get_total_stars_earned()
	if earned_from_achievements > 0:
		total_stars = earned_from_achievements
		lifetime_earned = earned_from_achievements
		
		# Add initial transaction
		_add_transaction({
			"type": "earn",
			"amount": earned_from_achievements,
			"source": "achievement_backfill",
			"timestamp": Time.get_unix_time_from_system(),
			"balance": total_stars
		})
		
		save_stars()
		print("Calculated %d initial stars from achievements" % earned_from_achievements)

# === DEBUG ===
func add_debug_stars(amount: int):
	add_stars(amount, "debug_panel")

func reset_stars():
	print("Resetting all star data...")
	total_stars = 0
	lifetime_earned = 0
	lifetime_spent = 0
	transaction_history.clear()
	
	# Recalculate from achievements
	_calculate_initial_stars()

func print_star_summary():
	print("\n=== STAR SUMMARY ===")
	print("Current Balance: %d" % total_stars)
	print("Lifetime Earned: %d" % lifetime_earned)
	print("Lifetime Spent: %d" % lifetime_spent)
	print("Recent Transactions:")
	
	for i in range(min(5, transaction_history.size())):
		var trans = transaction_history[i]
		var type_symbol = "+" if trans.type == "earn" else "-"
		print("  %s%d - %s" % [type_symbol, trans.amount, trans.get("source", trans.get("item", "unknown"))])
	
	print("====================\n")
