# HolidayEventManager.gd - Manages holiday pass progression and rewards
# Location: res://Pyramids/scripts/autoloads/HolidayPassManager.gd
# Last Updated: Created to match SeasonPassManager structure [Date]

extends Node

signal tier_unlocked(tier: int, rewards: Dictionary)
signal holiday_points_gained(amount: int, source: String)
signal holiday_level_up(new_level: int)
signal holiday_event_started(event_id: String)
signal holiday_event_ended(event_id: String)
signal holiday_progress_updated()  # For UI refresh
signal tier_claimed(tier_num: int)
signal holiday_pass_updated()

const SAVE_PATH = "user://holiday_pass_data.save"
const HP_PER_LEVEL = 10  # Holiday Points per level
const MAX_TIER = 30  # Shorter than season pass
const PREMIUM_PASS_COST: int = 1000
const TIER_SKIP_COST_PER_5: int = 500
const TIER_SKIP_BUNDLE_SIZE: int = 5

# Tiers that have rewards
const FREE_REWARD_TIERS = [1, 3, 5, 8, 10, 15, 20, 25, 30]
const PREMIUM_REWARD_TIERS = [1, 2, 3, 5, 7, 10, 12, 15, 18, 20, 22, 25, 27, 30]

# Holiday tier structure
class HolidayTier extends Resource:
	@export var tier: int = 1
	@export var required_hp: int = 0  # Total HP needed to reach this tier
	@export var free_rewards: Dictionary = {}
	@export var premium_rewards: Dictionary = {}
	@export var is_unlocked: bool = false
	@export var free_claimed: bool = false
	@export var premium_claimed: bool = false

# Holiday save data
var holiday_data = {
	"current_event_id": "winter_2024",
	"holiday_points": 0,  # Current HP
	"holiday_level": 1,
	"has_premium_pass": false,
	"claimed_tiers": [],
	"event_end_date": "",
	"lifetime_events_participated": 0
}

# Current holiday event configuration
var current_event = {
	"id": "winter_2024",
	"name": "Winter Wonderland",
	"theme": "winter",
	"start_date": "2025-07-31",
	"end_date": "2025-10-31",
	"currency_name": "Snowflakes",
	"currency_icon": "❄️",
	"tiers": []
}

# Define specific rewards for each tier (holiday themed)
var holiday_rewards = {
	"free": {
		1: {"stars": 25},
		3: {"stars": 50},
		5: {"cosmetic_type": "emoji", "cosmetic_id": "holiday_emoji_1"},
		8: {"stars": 75},
		10: {"cosmetic_type": "card_skin", "cosmetic_id": "holiday_card_1"},
		15: {"stars": 100},
		20: {"cosmetic_type": "avatar", "cosmetic_id": "holiday_avatar_1"},
		25: {"stars": 150},
		30: {"cosmetic_type": "card_skin", "cosmetic_id": "holiday_legendary_1", "stars": 500}
	},
	"premium": {
		1: {"stars": 50},
		2: {"cosmetic_type": "emoji", "cosmetic_id": "premium_holiday_emoji_1"},
		3: {"stars": 75},
		5: {"cosmetic_type": "card_skin", "cosmetic_id": "premium_holiday_card_1"},
		7: {"cosmetic_type": "avatar", "cosmetic_id": "premium_holiday_avatar_1"},
		10: {"stars": 100, "cosmetic_type": "frame", "cosmetic_id": "premium_holiday_frame_1"},
		12: {"cosmetic_type": "board_skin", "cosmetic_id": "premium_holiday_board_1"},
		15: {"stars": 150, "cosmetic_type": "emoji", "cosmetic_id": "premium_holiday_emoji_2"},
		18: {"cosmetic_type": "card_skin", "cosmetic_id": "premium_holiday_card_2"},
		20: {"stars": 200},
		22: {"cosmetic_type": "avatar", "cosmetic_id": "premium_holiday_avatar_2"},
		25: {"cosmetic_type": "frame", "cosmetic_id": "premium_holiday_frame_2", "stars": 250},
		27: {"cosmetic_type": "board_skin", "cosmetic_id": "premium_holiday_board_2"},
		30: {"cosmetic_type": "card_skin", "cosmetic_id": "premium_holiday_legendary_1", "stars": 750}
	}
}

func _ready():
	load_holiday_data()
	_initialize_holiday_tiers()
	
	# Check if event is active
	_check_active_event()

func _check_active_event():
	# Check if event is active (simplified - would need proper date checking)
	if holiday_data.current_event_id != current_event.id:
		start_holiday_event(current_event)

func start_holiday_event(event_config: Dictionary):
	current_event = event_config
	holiday_data.current_event_id = event_config.id
	holiday_data.lifetime_events_participated += 1
	
	# Reset progress for new event
	holiday_data.holiday_points = 0
	holiday_data.holiday_level = 1
	holiday_data.has_premium_pass = false
	holiday_data.claimed_tiers.clear()
	
	_initialize_holiday_tiers()
	save_holiday_data()
	holiday_event_started.emit(event_config.id)

func _initialize_holiday_tiers():
	current_event.tiers.clear()
	
	# Create 30 tiers with rewards
	for i in range(1, MAX_TIER + 1):
		var tier = HolidayTier.new()
		tier.tier = i
		tier.required_hp = (i - 1) * HP_PER_LEVEL
		
		# Set free track rewards
		if i in FREE_REWARD_TIERS:
			tier.free_rewards = holiday_rewards.free.get(i, {"stars": 25})
		
		# Set premium track rewards
		if i in PREMIUM_REWARD_TIERS:
			tier.premium_rewards = holiday_rewards.premium.get(i, {"stars": 50})
		
		# Check if already unlocked
		if i <= holiday_data.holiday_level:
			tier.is_unlocked = true
		
		# Check if already claimed
		var tier_key = "tier_%d_free" % i
		if tier_key in holiday_data.claimed_tiers:
			tier.free_claimed = true
		
		tier_key = "tier_%d_premium" % i
		if tier_key in holiday_data.claimed_tiers:
			tier.premium_claimed = true
		
		current_event.tiers.append(tier)

func add_holiday_points(amount: int, source: String = "gameplay"):
	print("[HolidayPassManager] Adding %d HP from %s" % [amount, source])
	holiday_data.holiday_points += amount
	holiday_points_gained.emit(amount, source)
	
	# Check for level ups
	var leveled_up = false
	while holiday_data.holiday_points >= holiday_data.holiday_level * HP_PER_LEVEL:
		holiday_data.holiday_level += 1
		leveled_up = true
		holiday_level_up.emit(holiday_data.holiday_level)
		
		# Unlock new tier
		if holiday_data.holiday_level <= MAX_TIER:
			var tier = current_event.tiers[holiday_data.holiday_level - 1]
			tier.is_unlocked = true
			tier_unlocked.emit(holiday_data.holiday_level, tier.free_rewards)
	
	save_holiday_data()
	
	# Emit progress update for UI refresh
	holiday_progress_updated.emit()

# Alias for compatibility with old HolidayEventManager
func add_holiday_currency(amount: int):
	add_holiday_points(amount, "legacy_currency")

func claim_tier_rewards(tier_num: int, claim_free: bool = true, claim_premium: bool = true) -> bool:
	"""Claim rewards with separate control for free/premium - matching SeasonPassManager"""
	if tier_num < 1 or tier_num > MAX_TIER:
		return false
		
	var tier = current_event.tiers[tier_num - 1]
	if not tier:
		return false
	
	var claimed_something = false
	
	# Claim free if requested and available
	if claim_free and not tier.free_claimed and tier.is_unlocked:
		_grant_rewards(tier.free_rewards)
		tier.free_claimed = true
		holiday_data.claimed_tiers.append("tier_%d_free" % tier_num)
		claimed_something = true
	
	# Claim premium if requested and available
	if claim_premium and holiday_data.has_premium_pass and not tier.premium_claimed and tier.is_unlocked:
		_grant_rewards(tier.premium_rewards)
		tier.premium_claimed = true
		holiday_data.claimed_tiers.append("tier_%d_premium" % tier_num)
		claimed_something = true
	
	if claimed_something:
		save_holiday_data()
		tier_claimed.emit(tier_num)
		holiday_pass_updated.emit()
		holiday_progress_updated.emit()  # Keep this extra signal for holiday
	
	return claimed_something

func _grant_rewards(rewards: Dictionary):
	"""Grant rewards through proper managers"""
	print("[HolidayEventManager] _grant_rewards called with: ", rewards)
	
	# Get managers
	var star_manager = get_node("/root/StarManager")
	var item_manager = get_node("/root/ItemManager")
	
	print("[HolidayEventManager] Manager checks - Star: %s, Item: %s" % [
		star_manager != null,
		item_manager != null
	])
	
	# Grant stars
	if rewards.has("stars"):
		print("[HolidayEventManager] Attempting to grant %d stars" % rewards.stars)
		if star_manager:
			print("[HolidayEventManager] Calling star_manager.add_stars()")
			# Temporarily enable rewards to ensure stars are granted
			var old_state = StarManager.rewards_enabled
			StarManager.rewards_enabled = true
			star_manager.add_stars(rewards.stars, "holiday_pass_tier")
			StarManager.rewards_enabled = old_state
			print("[HolidayEventManager] Stars added successfully")
		else:
			push_error("[HolidayEventManager] StarManager not found!")
	
	# Grant XP
	if rewards.has("xp"):
		print("[HolidayEventManager] Attempting to grant %d XP" % rewards.xp)
		if XPManager:
			var old_state = XPManager.rewards_enabled
			XPManager.rewards_enabled = true
			XPManager.add_xp(rewards.xp, "holiday_pass_tier")
			XPManager.rewards_enabled = old_state
			print("[HolidayEventManager] XP added successfully")
	
	# Grant cosmetics
	if rewards.has("cosmetic_id") and rewards.has("cosmetic_type"):
		print("[HolidayEventManager] Attempting to grant cosmetic: %s (%s)" % [
			rewards.cosmetic_id,
			rewards.cosmetic_type
		])
		if item_manager:
			var success = item_manager.grant_item(rewards.cosmetic_id, UnifiedItemData.Source.HOLIDAY_EVENT)
			if success:
				print("[HolidayEventManager] Cosmetic granted successfully")
			else:
				print("[HolidayEventManager] Failed to grant cosmetic")
		else:
			push_error("[HolidayEventManager] ItemManager not found!")
	
	print("[HolidayEventManager] _grant_rewards completed")

func purchase_premium_pass() -> bool:
	# Holiday pass costs 1000 stars (same as season pass)
	if StarManager.spend_stars(1000, "holiday_pass_purchase"):
		holiday_data.has_premium_pass = true
		save_holiday_data()
		holiday_progress_updated.emit()
		return true
	return false

func purchase_tier_skips(num_tiers: int) -> bool:
	# Each tier skip costs 100 stars
	var cost = num_tiers * 100
	if StarManager.spend_stars(cost, "holiday_tier_skip"):
		add_holiday_points(num_tiers * HP_PER_LEVEL, "tier_skip")
		return true
	return false

func get_current_tier() -> int:
	return holiday_data.holiday_level

func get_tier_progress() -> Dictionary:
	var current_hp = holiday_data.holiday_points
	var current_tier_hp = (holiday_data.holiday_level - 1) * HP_PER_LEVEL
	var next_tier_hp = holiday_data.holiday_level * HP_PER_LEVEL
	var progress_hp = current_hp - current_tier_hp
	
	return {
		"current_tier": holiday_data.holiday_level,
		"current_hp": progress_hp,
		"required_hp": HP_PER_LEVEL,
		"percentage": float(progress_hp) / float(HP_PER_LEVEL),
		"total_hp": current_hp,
		"total_required": MAX_TIER * HP_PER_LEVEL
	}

# Compatibility method for UI that expects SP naming
func get_season_info() -> Dictionary:
	return get_event_info()

func get_event_info() -> Dictionary:
	return {
		"id": current_event.id,
		"name": current_event.name,
		"theme": current_event.theme,
		"currency_name": current_event.currency_name,
		"currency_icon": current_event.currency_icon,
		"days_remaining": _calculate_days_remaining(),
		"current_tier": holiday_data.holiday_level,
		"total_hp": holiday_data.holiday_points,
		"has_premium": holiday_data.has_premium_pass
	}

func get_holiday_tiers() -> Array:
	return current_event.tiers

func get_tier_data(tier_number: int) -> Dictionary:
	"""Get complete tier data for UI display"""
	if tier_number < 1 or tier_number > MAX_TIER:
		return {}
		
	var tier = current_event.tiers[tier_number - 1]
	
	return {
		"tier": tier.tier,
		"is_current": tier.tier == holiday_data.holiday_level,
		"is_unlocked": tier.is_unlocked,
		"has_premium_pass": holiday_data.has_premium_pass,
		"free_claimed": tier.free_claimed,
		"premium_claimed": tier.premium_claimed,
		"free_rewards": tier.free_rewards,
		"premium_rewards": tier.premium_rewards
	}

func get_seconds_remaining() -> int:
	"""Get seconds until season ends"""
	# Parse end date
	var end_parts = current_event.end_date.split("-")
	var end_dict = {
		"year": int(end_parts[0]),
		"month": int(end_parts[1]), 
		"day": int(end_parts[2]),
		"hour": 23,
		"minute": 59,
		"second": 59
	}
	
	var current_unix = Time.get_unix_time_from_system()
	var end_unix = Time.get_unix_time_from_datetime_dict(end_dict)
	
	return max(0, int(end_unix - current_unix))

func _calculate_days_remaining() -> int:
	"""Calculate days remaining until season end"""
	var seconds = get_seconds_remaining()
	return int(seconds / 86400)

func save_holiday_data():
	var save_dict = {
		"version": 1,
		"data": holiday_data
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_dict)
		file.close()

func load_holiday_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var save_dict = file.get_var()
			file.close()
			
			if save_dict and save_dict.has("data"):
				holiday_data = save_dict.data

func reset_holiday_data():
	holiday_data = {
		"current_event_id": "winter_2024",
		"holiday_points": 0,
		"holiday_level": 1,
		"has_premium_pass": false,
		"claimed_tiers": [],
		"event_end_date": "",
		"lifetime_events_participated": 0
	}
	save_holiday_data()
	_initialize_holiday_tiers()

# Debug functions
func debug_add_points(amount: int):
	"""Debug function to add holiday points"""
	add_holiday_points(amount, "debug")

func debug_unlock_all_tiers():
	"""Debug function to unlock all tiers"""
	add_holiday_points(MAX_TIER * HP_PER_LEVEL, "debug_unlock_all")
