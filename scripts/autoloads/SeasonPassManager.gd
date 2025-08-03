# SeasonPassManager.gd - Manages season pass progression and rewards
# Location: res://Magic-Castle/scripts/autoloads/SeasonPassManager.gd
# Last Updated: Created foundation for season pass system [Date]

extends Node

signal tier_unlocked(tier: int, rewards: Dictionary)
signal season_xp_gained(amount: int, source: String)
signal season_level_up(new_level: int)
signal season_ended(season_id: String)
signal season_started(season_id: String)

const SAVE_PATH = "user://season_pass_data.save"
const XP_PER_LEVEL = 1000
const MAX_TIER = 50

# Season tier structure
class SeasonTier extends Resource:
	@export var tier: int = 1
	@export var required_level: int = 1
	@export var free_rewards: Dictionary = {}  # "stars": 50, "cosmetic_id": "card_skin_1"
	@export var premium_rewards: Dictionary = {}
	@export var is_unlocked: bool = false
	@export var free_claimed: bool = false
	@export var premium_claimed: bool = false

# Season save data
var season_data = {
	"current_season_id": "season_1",
	"season_xp": 0,
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

func _ready():
	load_season_data()
	_initialize_season_tiers()
	
	# Connect to XP gains for season progress
	if XPManager:
		XPManager.xp_gained.connect(_on_xp_gained)

func _initialize_season_tiers():
	# Create 50 tiers with rewards
	for i in range(1, MAX_TIER + 1):
		var tier = SeasonTier.new()
		tier.tier = i
		tier.required_level = i
		
		# Free track rewards (every tier)
		if i % 5 == 0:  # Every 5 levels
			tier.free_rewards = {
				"stars": 100 * (i / 5),
				"xp": 500
			}
		else:
			tier.free_rewards = {
				"stars": 50,
				"xp": 250
			}
		
		# Premium track rewards
		tier.premium_rewards = {
			"stars": 100,
			"xp": 500
		}
		
		# Special milestone rewards
		if i % 10 == 0:  # Every 10 levels
			tier.premium_rewards["cosmetic_type"] = "special"
			tier.premium_rewards["cosmetic_id"] = "season_1_tier_%d" % i
		
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

func add_season_xp(amount: int, source: String = "gameplay"):
	season_data.season_xp += amount
	season_xp_gained.emit(amount, source)
	
	# Check for level ups
	while season_data.season_xp >= season_data.season_level * XP_PER_LEVEL:
		season_data.season_level += 1
		season_level_up.emit(season_data.season_level)
		
		# Unlock new tier
		if season_data.season_level <= MAX_TIER:
			var tier = current_season.tiers[season_data.season_level - 1]
			tier.is_unlocked = true
			tier_unlocked.emit(season_data.season_level, tier.free_rewards)
	
	save_season_data()

func claim_tier_rewards(tier_number: int, is_premium: bool = false) -> bool:
	if tier_number < 1 or tier_number > MAX_TIER:
		return false
		
	var tier = current_season.tiers[tier_number - 1]
	
	if not tier.is_unlocked:
		return false
	
	if is_premium and not season_data.has_premium_pass:
		return false
	
	var rewards = {}
	var tier_key = ""
	
	if is_premium and not tier.premium_claimed:
		rewards = tier.premium_rewards
		tier.premium_claimed = true
		tier_key = "tier_%d_premium" % tier_number
	elif not is_premium and not tier.free_claimed:
		rewards = tier.free_rewards
		tier.free_claimed = true
		tier_key = "tier_%d_free" % tier_number
	else:
		return false  # Already claimed
	
	# Grant rewards
	if rewards.has("stars"):
		StarManager.add_stars(rewards.stars, "season_pass")
	if rewards.has("xp"):
		XPManager.add_xp(rewards.xp)
	if rewards.has("cosmetic_id"):
		# Future: Grant cosmetic
		pass
	
	season_data.claimed_tiers.append(tier_key)
	save_season_data()
	return true

func purchase_premium_pass() -> bool:
	# Premium pass costs 1000 stars
	if StarManager.spend_stars(1000, "premium_pass_purchase"):
		season_data.has_premium_pass = true
		save_season_data()
		return true
	return false

func get_current_tier() -> int:
	return season_data.season_level

func get_tier_progress() -> Dictionary:
	var current_level_xp = (season_data.season_level - 1) * XP_PER_LEVEL
	var next_level_xp = season_data.season_level * XP_PER_LEVEL
	var progress_xp = season_data.season_xp - current_level_xp
	
	return {
		"current_xp": progress_xp,
		"required_xp": XP_PER_LEVEL,
		"percentage": float(progress_xp) / float(XP_PER_LEVEL)
	}

func get_season_tiers() -> Array:
	return current_season.tiers

func get_season_info() -> Dictionary:
	return {
		"id": current_season.id,
		"name": current_season.name,
		"theme": current_season.theme,
		"days_remaining": _calculate_days_remaining(),
		"current_tier": season_data.season_level,
		"has_premium": season_data.has_premium_pass
	}

func _calculate_days_remaining() -> int:
	# Simple calculation - would need proper date parsing
	return 30  # Placeholder

func _on_xp_gained(amount: int):
	# Convert 10% of regular XP to season XP
	var season_xp = int(amount * 0.1)
	if season_xp > 0:
		add_season_xp(season_xp, "xp_conversion")

func check_season_end():
	# Called daily to check if season should end
	# Would implement proper date checking
	pass

func start_new_season(season_config: Dictionary):
	# Archive old season data
	season_data.lifetime_seasons_completed += 1
	
	# Reset for new season
	season_data.current_season_id = season_config.id
	season_data.season_xp = 0
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
		"version": 1,
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
		"season_xp": 0,
		"season_level": 1,
		"has_premium_pass": false,
		"claimed_tiers": [],
		"season_end_date": "",
		"lifetime_seasons_completed": 0
	}
	save_season_data()
	_initialize_season_tiers()
