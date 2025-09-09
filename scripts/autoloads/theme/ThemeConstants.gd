# ThemeConstants.gd - Pure theme data constants
# Location: res://Pyramids/scripts/autoloads/theme/ThemeConstants.gd
# Last Updated: Extracted from UIStyleManager [Date]
# 
# This file contains ONLY data dictionaries - no functions or logic
# All visual constants for the game are defined here

extends Node

# Design system colors - from your design doc
var colors = {
	# Primary Colors
	"primary": Color("#10b981"),
	"primary_dark": Color("#059669"),
	"primary_light": Color("#d1fae5"),
	"primary_focus": Color(0.063, 0.725, 0.506, 0.1),
	
	# Play Button Mode Colors
	"play_solo": Color("#10b981"),        # Green (same as primary)
	"play_solo_dark": Color("#059669"),   # Dark green (same as primary_dark)
	"play_multiplayer": Color("#E53935"),  # Red
	"play_multiplayer_dark": Color("#C62828"), # Dark red
	"play_tournament": Color("#FFB300"),   # Gold
	"play_tournament_dark": Color("#F57C00"), # Dark gold

	"gray_900": Color("#111827"),  # Primary text
	"gray_700": Color("#374151"),  # Secondary text
	"gray_600": Color("#4b5563"),  # Tertiary text
	"gray_500": Color("#6b7280"),  # Muted text
	"gray_400": Color("#9ca3af"),  # Disabled text
	"gray_300": Color("#d1d5db"),  # Borders - disabled
	"gray_200": Color("#e5e7eb"),  # Borders - inactive
	"gray_100": Color("#f3f4f6"),  # Borders - active
	"gray_50": Color("#f9fafb"),   # Hover backgrounds
	"white": Color.WHITE,
	"base_bg": Color("#fafafa"),   # Page background
	
	# Semantic Colors
	"error": Color("#ef4444"),
	"error_light": Color("#fee2e2"),
	"warning": Color("#f59e0b"),
	"warning_light": Color("#fef3c7"),
	"warning_muted": Color("#FFBD00"), 
	"success": Color("#10b981"),
	"info": Color("#3b82f6"),
	"info_light": Color("#dbeafe"),
	
	# Special Colors
	"premium": Color("#8b5cf6"),
	"premium_dark": Color("#7c3aed"),
	"premium_light": Color("#ede9fe")
}

# Typography specifications
var typography = {
	# Font sizes
	"size_display": 48,    # Play button only
	"size_h1": 40,
	"size_h2": 36,
	"size_h3": 32,
	"size_title": 24,
	"size_body_large": 20,
	"size_body": 18,
	"size_body_small": 16,
	"size_caption": 14,
	"size_micro": 12,
	
	# Font weights (if using dynamic fonts)
	"weight_regular": 400,
	"weight_medium": 500,
	"weight_bold": 700
}

# Spacing system - base unit of 4px
var spacing = {
	"unit": 4,
	"space_1": 4,      # 4px
	"space_2": 8,      # 8px
	"space_3": 12,     # 12px
	"space_4": 16,     # 16px
	"space_5": 20,     # 20px
	"space_6": 24,     # 24px
	"space_8": 32,     # 32px
	"space_10": 40,    # 40px
	"space_12": 48,    # 48px
	"space_16": 64,    # 64px
	"space_20": 80,    # 80px
	
	# Component specific
	"card_padding": 20,
	"button_padding_h": 24,
	"button_padding_v": 8,
	"modal_padding": 32,
	"section_spacing": 48
}

# Component dimensions
var dimensions = {
	# Buttons
	"play_button_size": Vector2(560, 100),
	"menu_button_size": Vector2(560, 80),
	"action_button_height": 50,
	"medium_button_height": 30,
	"small_button_height": 20,
	
	# Cards and panels
	"reward_card_size": Vector2(180, 170),
	"tier_column_width": 120,
	"tier_column_height": 187,
	"mission_card_height": 80,
	
	# Progress bars
	"progress_bar_height": 50,
	"small_progress_height": 30,
	
	# Modals
	"modal_min_width": 400,
	"modal_max_width": 600,
	
	# Corner radius
	"corner_radius_small": 8,
	"corner_radius_medium": 12,
	"corner_radius_large": 16,
	"corner_radius_xl": 25,
	"corner_radius_round": 50  # For pills/play button
}

# Border specifications
var borders = {
	"width_thin": 1,
	"width_medium": 2,
	"width_thick": 3,
	"width_focus": 2
}

# Shadow specifications
var shadows = {
	# Shadow sizes
	"size_small": 2,
	"size_medium": 4,
	"size_large": 8,
	"size_xl": 20,
	
	# Shadow colors
	"color_default": Color(0, 0, 0, 0.08),
	"color_medium": Color(0, 0, 0, 0.15),
	"color_large": Color(0, 0, 0, 0.25),
	"color_primary": Color(0.063, 0.725, 0.506, 0.3),  # Primary with transparency
	
	# Shadow offsets
	"offset_small": Vector2(0, 1),
	"offset_medium": Vector2(0, 2),
	"offset_large": Vector2(0, 4)
}

var opacity = {
	"full": 1.0,
	"claimed": 0.6,      # Dimmed claimed rewards
	"locked": 0.4,       # Locked rewards
	"backdrop": 0.5,
	"lock_strong": 0.8,  # Lock overlay - not reached
	"lock_medium": 0.6,  # Lock overlay - no premium
	"lock_weak": 0.5,    # Lock overlay - default
	"lock_faint": 0.3,   # Lock overlay - claimed
}

# Animation durations
var animations = {
	"duration_instant": 0.0,
	"duration_fast": 0.1,      # Clicks
	"duration_normal": 0.15,   # Hovers
	"duration_medium": 0.2,    # Modals
	"duration_slow": 0.3,      # Page transitions
	"duration_slower": 0.4     # Complex animations
}

# Battle pass style configuration
var battle_pass_style = {
	# Tier column colors
	"tier_bg": Color.WHITE,
	"tier_bg_locked": Color("#F3F4F6"),
	"tier_bg_current": Color("#10b981"),
	"tier_border": Color("#E5E7EB"),
	"tier_border_current": Color("#10b981"),
	"tier_shadow": Color(0, 0, 0, 0.08),
	
	# Progress bar
	"progress_bg": Color("#E5E7EB"),
	"progress_fill": Color("#10b981"),
	"progress_text": Color("#374151"),
	
	# Dimensions
	"tier_corner_radius": 12,
	"tier_border_width": 1,
	"tier_shadow_size": 4,
	"tier_width": 120,
	"tier_height": 187,
	
	# Typography
	"tier_number_size": 20,
	"reward_amount_size": 16,
	"progress_text_size": 18
}

# Holiday theme overrides
var holiday_style = {
	"tier_bg": Color.WHITE,
	"tier_bg_locked": Color("#FEF3C7"),  # Warm holiday tint
	"tier_bg_current": Color("#DC2626"),  # Holiday red
	"tier_border": Color("#FCD34D"),      # Golden border
	"tier_border_current": Color("#DC2626"),
	"progress_fill": Color("#DC2626"),
	# Rest inherits from battle_pass_style
}

# Panel styling configuration (existing)
var panel_style_config = {
	"bg_color": Color(1.0, 1.0, 1.0, 1.0),
	"border_color": Color(1.0, 1.0, 1.0, 1.0),
	"border_width": 1,
	"corner_radius": 12,
	"shadow_size": 5,
	"shadow_offset_y": 3,
	"shadow_color": Color(0.445, 0.445, 0.445, 0.6)
}

# Scroll container configuration (existing)
var scroll_config = {
	"width": 600,
	"height": 300,
	"margin_left": 5,
	"margin_right": 5,
	"margin_top": 2,
	"margin_bottom": 9,
	"content_separation": 10
}

# Filter button styling configuration (existing)
var filter_style_config = {
	"normal_color": Color(0.565, 0.525, 1.0),
	"hover_color": Color(0.565, 0.525, 1.0),  # Same as normal for mobile
	"pressed_color": Color(0.644, 0.529, 1.0),
	"corner_radius": 12,
	"content_margin_h": 20,  # Left and right
	"content_margin_v": -1   # Top and bottom
}

var game_style = {
	# Proportional sizes (as percentages)
	"top_bar_height_percent": 0.24,  # 15% of screen
	"board_area_height_percent": 0.76,  # 85% of screen
	"draw_zone_width_percent": 0.08,  # 8% of screen width
	
	# Draw zones - MORE VISIBLE COLORS
	"draw_zone_bg_color": Color(0.1, 0.2, 0.3, 0.1),  # Dark blue-gray with 50% alpha
	"draw_zone_border_color": Color(0.2, 0.4, 0.6, 0.2),  # Matching border
	"draw_zone_text_color": Color(0.9, 0.95, 1.0, 1.0),  # Keep bright white
	"draw_zone_pulse_alpha_min": 0.5,  # Higher minimum
	"draw_zone_pulse_alpha_max": 1.0,  # Full opacity at peak
	"draw_zone_pulse_duration": 1.5,  # Faster pulse
	
	# Top bar - MORE VISIBLE
	"top_bar_bg_color": Color(0.15, 0.15, 0.15, 0.95),  # Darker, more opaque
	"top_bar_border_color": Color(0.4, 0.4, 0.4, 0.5),  # More visible border
	
	# Progress bars
	"timer_bar_bg": Color(0.2, 0.8, 0.2, 0.3),
	"timer_bar_fill": Color(0.2, 0.8, 0.2),
	"combo_bar_bg": Color(0.9, 0.9, 0.2, 0.3),
	"combo_bar_fill": Color(0.9, 0.9, 0.2),
	
	# Cards (keeping some fixed for gameplay consistency)
	"card_width_mobile": 50,
	"card_height_mobile": 70,
	"card_overlap_y": 25,
	"card_spacing_min": 3,
	
	# Animations
	"draw_zone_click_scale": 0.95,
	"draw_zone_click_duration": 0.1
}

var card_colors = {
	"pyramid_gold": Color("#FFD700"),          # Classic gold
	"pyramid_gold_dark": Color("#B8860B"),     # Darker gold
	"pyramid_gold_light": Color("#FFF8DC"),    # Light gold
	"pyramid_sand": Color("#F4E4BC"),          # Sand color
	"pyramid_stone": Color("#8B7355"),         # Stone brown
	"pyramid_copper": Color("#B87333"),        # Copper bronze
	"pyramid_turquoise": Color("#40E0D0"),     # Nile turquoise
	"pyramid_lapis": Color("#26619C"),         # Lapis blue
	"pyramid_emerald": Color("#50C878"),       # Emerald green
	"pyramid_ruby": Color("#E0115F"),          # Ruby red
	"pyramid_obsidian": Color("#2F2F2F"),      # Obsidian black
	"pyramid_papyrus": Color("#FDF5E6"),       # Papyrus cream
	"neon_cyan": Color("#00FFFF"),             # Neon cyan
	"neon_magenta": Color("#FF00FF"),          # Neon magenta
	"neon_green": Color("#00FF80"),            # Neon green
	"neon_orange": Color("#FF8000")            # Neon orange
}

var item_card_style = {
	# === CORE SIZES BY LAYOUT ===
	"size_portrait": Vector2(90, 126),
	"size_landscape": Vector2(191, 126),  # 2x portrait width + separator
	"size_reduction": 0.5,  # 50% of original export size
	
	# === CONTEXT-SPECIFIC SIZES ===
	"size_showcase": Vector2(50, 50),
	"size_profile": Vector2(80, 100),
	"size_inventory": Vector2(120, 160),
	"size_shop": Vector2(120, 160),
	"size_game": Vector2(180, 252),  # Full size cards in game
	
	# === GRID CONFIGURATION ===
	"grid_separator": 12,  # Space between cards in grid
	"grid_spacing": 12,
	"grid_slots_card": 1,  # How many columns a card takes
	"grid_slots_board": 2,  # How many columns a board takes
	
	# === LABEL POSITIONING (as percentages of card height) ===
	"label_slot_1_top": 0.55,
	"label_slot_1_bottom": 0.85,
	"label_slot_2_top": 0.85,
	"label_slot_2_bottom": 1.0,
	
	# === FONT SIZES ===
	"font_size_name": 14,
	"font_size_price": 16,
	"font_size_lock": 16,
	"name_size_showcase": 14,
	"name_size_profile": 16,
	"name_size_default": 18,
	
	# === SPACING & PADDING ===
	"card_padding": 8,
	"equipped_badge_margin": 4,
	
	# === VISUAL PROPERTIES ===
	"label_bg_alpha": 0.5,
	"corner_radius": 0,  # No rounded corners
	"shadow_size": 4,
	"shadow_alpha": 0.3,
	
	# === EQUIPPED INDICATOR ===
	"equipped_badge_size": 24,
	"equipped_badge_color": Color("#10b981"),
	
	# === LOCK OVERLAY ===
	"lock_overlay_opacity": 0.8,
	"lock_text_color": Color.WHITE,
	
	# === BORDERS ===
	"card_border_width_normal": 2,
	"card_border_width_epic": 3,
	"border_use_rounded": false  # Explicitly no rounded corners
}

var mode_colors = {
	"test": {
		"primary": Color(0.3, 0.8, 0.3),  # Green
		"dark": Color(0.2, 0.6, 0.2)
	},
	"classic": {
		"primary": Color(0.2, 0.5, 0.8),  # Blue
		"dark": Color(0.15, 0.4, 0.65)
	},
	"timed_rush": {
		"primary": Color(0.9, 0.3, 0.3),  # Red
		"dark": Color(0.7, 0.2, 0.2)
	},
	"zen": {
		"primary": Color(0.5, 0.7, 0.9),  # Light blue
		"dark": Color(0.4, 0.6, 0.8)
	},
	"daily_challenge": {
		"primary": Color(0.9, 0.7, 0.2),  # Gold/Yellow
		"dark": Color(0.7, 0.5, 0.1)
	},
	"puzzle_master": {
		"primary": Color(0.7, 0.4, 0.9),  # Purple
		"dark": Color(0.6, 0.3, 0.8)
	}
}

var popup_sizes = {
	"small": Vector2(350, 250),
	"medium": Vector2(400, 300),
	"large": Vector2(500, 400),
	"purchase": Vector2(450, 350)
}

func _ready():
	print("ThemeConstants loaded with %d color definitions" % colors.size())
