# SeasonPassManager.gd - Manages season pass progression and rewards
# Location: res://Pyramids/scripts/autoloads/SeasonPassManager.gd
# Last Updated: Removed mission logic, focused on tier progression [Date]

extends Node

signal tier_unlocked(tier: int, rewards: Dictionary)
signal season_points_gained(amount: int, source: String)
signal season_level_up(new_level: int)
signal season_ended(season_id: String)
signal season_started(season_id: String)
signal season_progress_updated()  # NEW: For UI refresh

const SAVE_PATH = "user://season_pass_data.save"
const SP_PER_LEVEL = 10  # Season Points per level
const MAX_TIER = 50

# Tiers that have rewards
const FREE_REWARD_TIERS = [1, 3, 5, 8, 10, 15, 20, 25, 30, 35, 40, 50]
const PREMIUM_REWARD_TIERS = [1, 2, 3, 4, 5, 7, 9, 10, 12, 15, 18, 20, 25, 30, 35, 40, 45, 50]

# Season tier structure
class SeasonTier extends Resource:
	@export var tier: int = 1
	@export var required_sp: int = 0  # Total SP needed to reach this tier
	@export var free_rewards: Dictionary = {}
	@export var premium_rewards: Dictionary = {}
	@export var is_unlocked: bool = false
	@export var free_claimed: bool = false
	@export var premium_claimed: bool = false

# Season save data
var season_data = {
	"current_season_id": "season_1",
	"season_points": 0,  # Current SP
	"season_level": 1,
	"has_premium_pass": false,
	"claimed_tiers": [],
	"season_end_date": "",
	"lifetime_seasons_completed": 0
}

# Current season configuration
var current_season = {
	"id": "season_1",
	"name": "Castle Foundations",
	"theme": "medieval",
	"start_date": "2024-01-01",
	"end_date": "2024-03-31",
	"tiers": []
}

# Define specific rewards for each tier
var season_rewards = {
	"free": {
		1: {"stars": 50},
		3: {"stars": 100},
		4: {"xp": 250},
		5: {"cosmetic_type": "card_back", "cosmetic_id": "neon_night_back"},
		8: {"xp": 500},  # ADD XP reward here
		10: {"cosmetic_type": "card_front", "cosmetic_id": "neon_night_front"},
		15: {"stars": 200},
		20: {"cosmetic_type": "board", "cosmetic_id": "neon_night_board"},
		25: {"xp": 1000},  # ADD XP reward here
		30: {"cosmetic_type": "frame", "cosmetic_id": "season_frame_1"},
		35: {"stars": 400},
		40: {"cosmetic_type": "board_skin", "cosmetic_id": "season_board_1"},
		50: {"cosmetic_type": "card_skin", "cosmetic_id": "season_legendary_1", "stars": 1000}
	},
	"premium": {
		1: {"stars": 100},
		2: {"cosmetic_type": "board", "cosmetic_id": "glyphwave_board"},
		3: {"stars": 150},
		4: {"cosmetic_type": "card_back", "cosmetic_id": "glyphwave_card_back"},
		5: {"cosmetic_type": "card_front", "cosmetic_id": "glyphwave_card_front"},
		7: {"xp": 750},  # ADD XP reward here
		9: {"stars": 250},
		10: {"cosmetic_type": "frame", "cosmetic_id": "premium_frame_1", "stars": 100},
		12: {"xp": 1500},
		15: {"stars": 300, "cosmetic_type": "emoji", "cosmetic_id": "premium_emoji_3"},
		18: {"cosmetic_type": "card_skin", "cosmetic_id": "premium_card_2"},
		20: {"cosmetic_type": "avatar", "cosmetic_id": "premium_avatar_2", "stars": 200},
		25: {"cosmetic_type": "frame", "cosmetic_id": "premium_frame_2", "stars": 400},
		30: {"cosmetic_type": "board_skin", "cosmetic_id": "premium_board_2", "stars": 500},
		35: {"cosmetic_type": "card_skin", "cosmetic_id": "premium_card_3"},
		40: {"cosmetic_type": "avatar", "cosmetic_id": "premium_avatar_3", "stars": 600},
		45: {"cosmetic_type": "frame", "cosmetic_id": "premium_frame_3"},
		50: {"cosmetic_type": "card_skin", "cosmetic_id": "premium_legendary_1", "stars": 1500}
	}
}

func _ready():
	load_season_data()
	_initialize_season_tiers()

func _initialize_season_tiers():
	# Create 50 tiers with rewards
	for i in range(1, MAX_TIER + 1):
		var tier = SeasonTier.new()
		tier.tier = i
		tier.required_sp = (i - 1) * SP_PER_LEVEL
		
		# Set free track rewards
		if i in FREE_REWARD_TIERS:
			tier.free_rewards = season_rewards.free.get(i, {"stars": 50})
		
		# Set premium track rewards
		if i in PREMIUM_REWARD_TIERS:
			tier.premium_rewards = season_rewards.premium.get(i, {"stars": 100})
		
		# Check if already unlocked
		if i <= season_data.season_level:
			tier.is_unlocked = true
		
		# Check if already claimed
		var tier_key = "tier_%d_free" % i
		if tier_key in season_data.claimed_tiers:
			tier.free_claimed = true
		
		tier_key = "tier_%d_premium" % i
		if tier_key in season_data.claimed_tiers:
			tier.premium_claimed = true
		
		current_season.tiers.append(tier)

func add_season_points(amount: int, source: String = "gameplay"):
	print("[SeasonPassManager] Adding %d SP from %s" % [amount, source])
	season_data.season_points += amount
	season_points_gained.emit(amount, source)
	
	# Check for level ups
	var leveled_up = false
	while season_data.season_points >= season_data.season_level * SP_PER_LEVEL:
		season_data.season_level += 1
		leveled_up = true
		season_level_up.emit(season_data.season_level)
		
		# Unlock new tier
		if season_data.season_level <= MAX_TIER:
			var tier = current_season.tiers[season_data.season_level - 1]
			tier.is_unlocked = true
			tier_unlocked.emit(season_data.season_level, tier.free_rewards)
	
	save_season_data()
	
	# Emit progress update for UI refresh
	season_progress_updated.emit()

func claim_tier_rewards(tier_number: int, is_premium: bool = false) -> bool:
	print("[SeasonPassManager] claim_tier_rewards called - tier: %d, premium: %s" % [tier_number, is_premium])
	
	if tier_number < 1 or tier_number > MAX_TIER:
		print("[SeasonPassManager] Invalid tier number")
		return false
		
	var tier = current_season.tiers[tier_number - 1]
	print("[SeasonPassManager] Tier data - unlocked: %s, free_claimed: %s, premium_claimed: %s" % [tier.is_unlocked, tier.free_claimed, tier.premium_claimed])
	
	if not tier.is_unlocked:
		print("[SeasonPassManager] Tier not unlocked")
		return false
	
	if is_premium and not season_data.has_premium_pass:
		print("[SeasonPassManager] No premium pass")
		return false
	
	var rewards = {}
	var tier_key = ""
	
	if is_premium and not tier.premium_claimed:
		rewards = tier.premium_rewards
		print("[SeasonPassManager] Premium rewards to grant: ", rewards)
		tier.premium_claimed = true
		tier_key = "tier_%d_premium" % tier_number
	elif not is_premium and not tier.free_claimed:
		rewards = tier.free_rewards
		print("[SeasonPassManager] Free rewards to grant: ", rewards)
		tier.free_claimed = true
		tier_key = "tier_%d_free" % tier_number
	else:
		print("[SeasonPassManager] Already claimed")
		return false  # Already claimed
	
	# Grant rewards
	print("[SeasonPassManager] About to grant rewards: ", rewards)
	_grant_rewards(rewards)
	
	season_data.claimed_tiers.append(tier_key)
	save_season_data()
	season_progress_updated.emit()
	return true

func _grant_rewards(rewards: Dictionary):
	"""Grant rewards through proper managers"""
	print("[SeasonPassManager] _grant_rewards called with: ", rewards)
	
	# Grant stars
	if rewards.has("stars"):
		print("[SeasonPassManager] Granting %d stars" % rewards.stars)
		if StarManager:
			var old_state = StarManager.rewards_enabled
			StarManager.rewards_enabled = true
			StarManager.add_stars(rewards.stars, "season_pass_tier")
			StarManager.rewards_enabled = old_state
			print("[SeasonPassManager] Stars added successfully")
	
	# Grant XP
	if rewards.has("xp"):
		print("[SeasonPassManager] Granting %d XP" % rewards.xp)
		if XPManager:
			var old_state = XPManager.rewards_enabled
			XPManager.rewards_enabled = true
			XPManager.add_xp(rewards.xp, "season_pass_tier")
			XPManager.rewards_enabled = old_state
			print("[SeasonPassManager] XP added successfully")
	
	# Grant cosmetics - FIX THE CALL
	if rewards.has("cosmetic_id") and rewards.has("cosmetic_type"):
		print("[SeasonPassManager] Granting cosmetic: %s (%s)" % [
			rewards.cosmetic_id,
			rewards.cosmetic_type
		])
		
		# Use EquipmentManager to grant the item
		if EquipmentManager:
			var success = EquipmentManager.grant_item(
				rewards.cosmetic_id, 
				"season_pass"  # source as string, not enum
			)
			if success:
				print("[SeasonPassManager] Cosmetic granted successfully")
			else:
				push_error("[SeasonPassManager] Failed to grant cosmetic: " + rewards.cosmetic_id)
		else:
			push_error("[SeasonPassManager] EquipmentManager not found!")
	
	print("[SeasonPassManager] _grant_rewards completed")

func purchase_premium_pass() -> bool:
	# Premium pass costs 1000 stars
	if StarManager.spend_stars(1000, "premium_pass_purchase"):
		season_data.has_premium_pass = true
		save_season_data()
		season_progress_updated.emit()
		return true
	return false

func purchase_tier_skips(num_tiers: int) -> bool:
	# Each tier skip costs 100 stars
	var cost = num_tiers * 100
	if StarManager.spend_stars(cost, "tier_skip_purchase"):
		add_season_points(num_tiers * SP_PER_LEVEL, "tier_skip")
		return true
	return false

func get_current_tier() -> int:
	return season_data.season_level

func get_tier_progress() -> Dictionary:
	var current_sp = season_data.season_points
	var current_tier_sp = (season_data.season_level - 1) * SP_PER_LEVEL
	var next_tier_sp = season_data.season_level * SP_PER_LEVEL
	var progress_sp = current_sp - current_tier_sp
	
	return {
		"current_tier": season_data.season_level,
		"current_sp": progress_sp,
		"required_sp": SP_PER_LEVEL,
		"percentage": float(progress_sp) / float(SP_PER_LEVEL),
		"total_sp": current_sp,
		"total_required": MAX_TIER * SP_PER_LEVEL
	}

func get_season_tiers() -> Array:
	return current_season.tiers
	
func get_tier_data(tier_number: int) -> Dictionary:
	"""Get complete tier data for UI display"""
	if tier_number < 1 or tier_number > MAX_TIER:
		return {}
		
	var tier = current_season.tiers[tier_number - 1]
	
	return {
		"tier": tier.tier,
		"is_current": tier.tier == season_data.season_level,
		"is_unlocked": tier.is_unlocked,
		"has_premium_pass": season_data.has_premium_pass,
		"free_claimed": tier.free_claimed,
		"premium_claimed": tier.premium_claimed,
		"free_rewards": tier.free_rewards,
		"premium_rewards": tier.premium_rewards
	}

func get_season_info() -> Dictionary:
	return {
		"id": current_season.id,
		"name": current_season.name,
		"theme": current_season.theme,
		"days_remaining": _calculate_days_remaining(),
		"current_tier": season_data.season_level,
		"total_sp": season_data.season_points,
		"has_premium": season_data.has_premium_pass
	}

func _calculate_days_remaining() -> int:
	# Simple calculation - would need proper date parsing
	return 90  # 90 days for full season

func check_season_end():
	# Called daily to check if season should end
	# Would implement proper date checking
	pass

func start_new_season(season_config: Dictionary):
	# Archive old season data
	season_data.lifetime_seasons_completed += 1
	
	# Reset for new season
	season_data.current_season_id = season_config.id
	season_data.season_points = 0
	season_data.season_level = 1
	season_data.has_premium_pass = false
	season_data.claimed_tiers.clear()
	season_data.season_end_date = season_config.end_date
	
	current_season = season_config
	_initialize_season_tiers()
	
	save_season_data()
	season_started.emit(season_config.id)

func save_season_data():
	var save_dict = {
		"version": 2,
		"data": season_data
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_dict)
		file.close()

func load_season_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var save_dict = file.get_var()
			file.close()
			
			if save_dict and save_dict.has("data"):
				season_data = save_dict.data

func reset_season_data():
	season_data = {
		"current_season_id": "season_1",
		"season_points": 0,
		"season_level": 1,
		"has_premium_pass": false,
		"claimed_tiers": [],
		"season_end_date": "",
		"lifetime_seasons_completed": 0
	}
	save_season_data()
	_initialize_season_tiers()

# Debug functions
func debug_add_points(amount: int):
	"""Debug function to add season points"""
	add_season_points(amount, "debug")

func debug_unlock_all_tiers():
	"""Debug function to unlock all tiers"""
	add_season_points(MAX_TIER * SP_PER_LEVEL, "debug_unlock_all")
