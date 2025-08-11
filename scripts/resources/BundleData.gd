# BundleData.gd - Resource class for bundle definitions
# Location: res://Pyramids/scripts/resources/BundleData.gd
# Last Updated: Created as resource for bundle system [Date]

class_name BundleData
extends Resource

@export_group("Basic Info")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var theme: String = ""  # Bundle theme

@export_group("Contents")
@export var item_ids: Array[String] = []
@export var bonus_stars: int = 0  # Bonus stars with bundle
@export var bonus_xp: int = 0  # Bonus XP with bundle

@export_group("Pricing")
@export var discount_percent: float = 20.0  # Default 20% off
@export var override_price: int = 0  # If set, use this instead of calculated
@export var currency_type: String = "stars"

@export_group("Availability")
@export var is_limited: bool = false
@export var available_from: String = ""  # Start date
@export var available_until: String = ""  # End date
@export var max_purchases: int = 1  # How many times can be bought

@export_group("Display")
@export var icon_path: String = ""
@export var banner_path: String = ""  # For featured bundles
@export var sort_order: int = 0
@export var is_featured: bool = false

func calculate_price(items_dict: Dictionary) -> int:
	if override_price > 0:
		return override_price
	
	var total_price = 0
	for item_id in item_ids:
		var item = items_dict.get(item_id) as ItemData
		if item:
			total_price += item.base_price
	
	return int(total_price * (1.0 - discount_percent / 100.0))

func calculate_savings(items_dict: Dictionary) -> int:
	var total_price = 0
	for item_id in item_ids:
		var item = items_dict.get(item_id) as ItemData
		if item:
			total_price += item.base_price
	
	var bundle_price = calculate_price(items_dict)
	return total_price - bundle_price
