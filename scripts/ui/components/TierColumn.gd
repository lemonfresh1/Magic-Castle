# TierColumn.gd - Individual tier column for season/event passes
# Location: res://Magic-Castle/scripts/ui/components/TierColumn.gd
# Last Updated: Created tier column component with battle pass styling [Date]

extends VBoxContainer
class_name TierColumn

# Column sizing variables
@export var column_width: int = 120
@export var column_height: int = 187

# Node references
@onready var tier_header: PanelContainer = $TierHeader
@onready var tier_number_label: Label = $TierHeader/TierNumber
@onready var free_reward: PanelContainer = $FreeReward
@onready var free_icon: TextureRect = $FreeReward/RewardIcon
@onready var free_amount: Label = $FreeReward/AmountLabel
@onready var free_lock: TextureRect = $FreeReward/LockOverlay
@onready var premium_reward: PanelContainer = $PremiumReward
@onready var premium_icon: TextureRect = $PremiumReward/RewardIcon
@onready var premium_amount: Label = $PremiumReward/AmountLabel
@onready var premium_lock: TextureRect = $PremiumReward/LockOverlay

# Tier data
var tier_number: int = 1
var is_current: bool = false
var is_unlocked: bool = false
var has_premium_pass: bool = false
var free_claimed: bool = false
var premium_claimed: bool = false

# Color schemes
const BATTLE_PASS_COLORS = {
	"header_bg": Color("1a1a3e"),  # Dark blue
	"header_text": Color("ffffff"),
	"free_bg_locked": Color("2a2a5e"),  # Darker blue
	"free_bg_unlocked": Color("3a3a7e"),  # Medium blue
	"free_bg_current": Color("4169e1"),  # Bright blue
	"premium_bg_locked": Color("3a2a5e"),  # Purple-ish dark
	"premium_bg_unlocked": Color("5a3a8e"),  # Purple
	"premium_bg_current": Color("ff8c00"),  # Orange/Gold
	"text_locked": Color("888888"),
	"text_unlocked": Color("ffffff"),
	"border_color": Color("4169e1"),  # Blue border
	"current_border": Color("ffaa00")  # Gold border for current
}

const HOLIDAY_COLORS = {
	"header_bg": Color("1e3a1e"),  # Dark green
	"header_text": Color("ffffff"),
	"free_bg_locked": Color("2e4a2e"),  # Darker green
	"free_bg_unlocked": Color("3e5a3e"),  # Medium green
	"free_bg_current": Color("228b22"),  # Forest green
	"premium_bg_locked": Color("4a2e2e"),  # Dark red
	"premium_bg_unlocked": Color("8b2222"),  # Crimson
	"premium_bg_current": Color("dc143c"),  # Bright red
	"text_locked": Color("888888"),
	"text_unlocked": Color("ffffff"),
	"border_color": Color("228b22"),  # Green border
	"current_border": Color("ffd700")  # Gold border
}

var current_theme: String = "battle_pass"

func _ready():
	custom_minimum_size = Vector2(column_width, column_height)
	_apply_theme()

func setup(tier_data: Dictionary, theme: String = "battle_pass"):
	current_theme = theme
	tier_number = tier_data.get("tier", 1)
	is_current = tier_data.get("is_current", false)
	is_unlocked = tier_data.get("is_unlocked", false)
	has_premium_pass = tier_data.get("has_premium_pass", false)
	free_claimed = tier_data.get("free_claimed", false)
	premium_claimed = tier_data.get("premium_claimed", false)
	
	# Set tier number
	tier_number_label.text = str(tier_number)
	
	# Set rewards
	var free_rewards = tier_data.get("free_rewards", {})
	var premium_rewards = tier_data.get("premium_rewards", {})
	
	_setup_reward_panel(free_reward, free_icon, free_amount, free_lock, free_rewards, true)
	_setup_reward_panel(premium_reward, premium_icon, premium_amount, premium_lock, premium_rewards, false)
	
	_apply_theme()

func _setup_reward_panel(panel: PanelContainer, icon: TextureRect, amount_label: Label, lock: TextureRect, rewards: Dictionary, is_free: bool):
	# Hide all elements first
	icon.visible = false
	amount_label.visible = false
	lock.visible = true  # Show lock by default
	
	# Determine if this reward is accessible
	var is_accessible = is_unlocked and (is_free or has_premium_pass)
	var is_claimed = free_claimed if is_free else premium_claimed
	
	# Hide lock if accessible and not claimed
	lock.visible = not is_accessible or is_claimed
	
	# Show reward if we have one
	if rewards.size() > 0:
		# Handle different reward structures
		if rewards.has("stars"):
			# Stars reward
			icon.visible = true
			var icon_path = _get_reward_icon_path("stars", rewards.stars)
			if icon_path:
				icon.texture = load(icon_path)
			
			if rewards.stars > 1:
				amount_label.visible = true
				amount_label.text = str(rewards.stars)
		
		elif rewards.has("cosmetic_type") and rewards.has("cosmetic_id"):
			# Cosmetic reward
			icon.visible = true
			var icon_path = _get_reward_icon_path(rewards.cosmetic_type, 1)
			if icon_path:
				icon.texture = load(icon_path)
			
			# Show cosmetic name as amount label
			amount_label.visible = true
			amount_label.text = "NEW!"
			amount_label.add_theme_color_override("font_color", Color("#FFD700"))
		
		elif rewards.has("xp"):
			# XP reward
			icon.visible = true
			var icon_path = _get_reward_icon_path("xp", rewards.xp)
			if icon_path:
				icon.texture = load(icon_path)
			
			if rewards.xp > 1:
				amount_label.visible = true
				amount_label.text = str(rewards.xp)
		
		else:
			# Generic reward - show first key/value pair
			var reward_type = rewards.keys()[0]
			var reward_amount = rewards[reward_type]
			
			icon.visible = true
			var icon_path = _get_reward_icon_path(reward_type, reward_amount if reward_amount is int else 1)
			if icon_path:
				icon.texture = load(icon_path)
			
			if reward_amount is int and reward_amount > 1:
				amount_label.visible = true
				amount_label.text = str(reward_amount)

func _apply_theme():
	var colors = BATTLE_PASS_COLORS if current_theme == "battle_pass" else HOLIDAY_COLORS
	
	# Style tier header
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = colors.header_bg
	header_style.set_corner_radius_all(6)
	tier_header.add_theme_stylebox_override("panel", header_style)
	tier_number_label.add_theme_color_override("font_color", colors.header_text)
	tier_number_label.add_theme_font_size_override("font_size", 20)
	
	# Style free reward panel
	_style_reward_panel(
		free_reward, 
		colors.free_bg_locked if not is_unlocked else (colors.free_bg_current if is_current else colors.free_bg_unlocked),
		is_current
	)
	
	# Style premium reward panel
	_style_reward_panel(
		premium_reward,
		colors.premium_bg_locked if not (is_unlocked and has_premium_pass) else (colors.premium_bg_current if is_current else colors.premium_bg_unlocked),
		is_current
	)
	
	# Style amount labels
	var text_color = colors.text_locked if not is_unlocked else colors.text_unlocked
	free_amount.add_theme_color_override("font_color", text_color)
	free_amount.add_theme_font_size_override("font_size", 16)
	free_amount.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	free_amount.add_theme_constant_override("shadow_offset_x", 1)
	free_amount.add_theme_constant_override("shadow_offset_y", 1)
	
	premium_amount.add_theme_color_override("font_color", text_color)
	premium_amount.add_theme_font_size_override("font_size", 16)
	premium_amount.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	premium_amount.add_theme_constant_override("shadow_offset_x", 1)
	premium_amount.add_theme_constant_override("shadow_offset_y", 1)

func _style_reward_panel(panel: PanelContainer, bg_color: Color, is_current_tier: bool):
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	
	# Add border for current tier
	if is_current_tier:
		var colors = BATTLE_PASS_COLORS if current_theme == "battle_pass" else HOLIDAY_COLORS
		style.border_color = colors.current_border
		style.set_border_width_all(3)
	else:
		style.set_border_width_all(1)
		style.border_color = bg_color.darkened(0.2)
	
	panel.add_theme_stylebox_override("panel", style)

func set_current(current: bool):
	is_current = current
	_apply_theme()

func claim_reward(is_free: bool):
	"""Called when a reward is claimed"""
	if is_free:
		free_claimed = true
		free_lock.visible = true
	else:
		premium_claimed = true
		premium_lock.visible = true
	
	# Could add claim animation here
	_apply_theme()

func _get_reward_icon_path(reward_type: String, amount: int = 1) -> String:
	"""Get placeholder icon path based on reward type"""
	var base_path = "res://Magic-Castle/assets/placeholder/food/"
	
	# Map reward types to food icons for now
	match reward_type:
		"stars":
			# Use different foods based on star amount
			if amount >= 1000:
				return base_path + "59_jelly.png"  # Golden jelly for big rewards
			elif amount >= 500:
				return base_path + "30_chocolatecake.png"
			elif amount >= 300:
				return base_path + "22_cheesecake.png"
			elif amount >= 200:
				return base_path + "15_burger.png"
			elif amount >= 100:
				return base_path + "05_apple_pie.png"
			else:
				return base_path + "28_cookies.png"
		
		"xp":
			return base_path + "57_icecream.png"
		
		"emoji":
			# Use fun foods for emojis
			var emoji_foods = ["34_donut.png", "75_pudding.png", "77_potatochips.png", "83_popcorn.png"]
			return base_path + emoji_foods[randi() % emoji_foods.size()]
		
		"card_skin":
			# Use premium looking foods
			var card_foods = ["54_hotdog.png", "81_pizza.png", "99_taco.png", "95_steak.png"]
			return base_path + card_foods[randi() % card_foods.size()]
		
		"board_skin":
			# Use elaborate dishes
			return base_path + "87_ramen.png"
		
		"avatar":
			# Use character-like foods
			var avatar_foods = ["11_bun.png", "20_bagel.png", "36_dumplings.png", "69_meatball.png"]
			return base_path + avatar_foods[randi() % avatar_foods.size()]
		
		"frame":
			# Use decorative foods
			var frame_foods = ["101_waffle.png", "79_pancakes.png", "90_strawberrycake.png"]
			return base_path + frame_foods[randi() % frame_foods.size()]
		
		"holiday_points":
			# Use festive foods
			return base_path + "23_cheesecake_dish.png"
		
		_:
			# Default fallback
			return base_path + "92_sandwich.png"
