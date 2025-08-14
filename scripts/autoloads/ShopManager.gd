# ShopManager.gd - Manages shop inventory, purchases, and pricing
# Location: res://Pyramids/scripts/autoloads/ShopManager.gd
# Last Updated: Simplified to MVP - static shop with star purchases only [Date]
#
# ShopManager handles:
# - Providing shop items from ItemManager
# - Processing purchases with StarManager
# - Price calculations with rarity multipliers
#
# This is a THIN LAYER that delegates to:
# - ItemManager for item definitions
# - EquipmentManager for ownership checks
# - StarManager for currency transactions
#
# Flow: ItemManager → ShopManager → ShopUI → UnifiedItemCard
# Dependencies: ItemManager (items), EquipmentManager (ownership), StarManager (currency)

extends Node

# Signals
signal item_purchased(item_id: String, price: int)
signal insufficient_funds(needed: int, current: int)
signal purchase_failed(item_id: String, reason: String)
signal shop_refreshed()

func _ready():
	print("ShopManager initializing...")
	print("ShopManager ready")

# === PUBLIC API ===

func get_all_shop_items() -> Array:
	"""Get all purchasable items as display dictionaries"""
	if not ItemManager:
		push_error("ShopManager: ItemManager not available")
		return []
	
	var result = []
	var all_items = ItemManager.get_all_items()
	
	for item_id in all_items:
		var item = all_items[item_id]
		if item and item is UnifiedItemData and _is_purchasable(item):
			result.append(_create_display_dict(item))
	
	print("ShopManager: Found %d purchasable items (excluding owned)" % result.size())
	return result

func get_items_by_category(category: String) -> Array:
	"""Get purchasable items in a category as display dictionaries"""
	if not ItemManager:
		push_error("ShopManager: ItemManager not available")
		return []
	
	var result = []
	var items = ItemManager.get_items_by_category(category)
	
	for item in items:
		if item and item is UnifiedItemData and _is_purchasable(item):
			result.append(_create_display_dict(item))
	
	print("ShopManager: Found %d purchasable items in category %s" % [result.size(), category])
	return result

func get_featured_items() -> Array:
	"""Get featured items for highlights tab - shows high rarity items"""
	var result = []
	
	if ItemManager:
		var all_items = ItemManager.get_all_items()
		for item_id in all_items:
			var item = all_items[item_id]
			if item and item is UnifiedItemData and _is_purchasable(item):
				# Show epic and legendary items in highlights
				if item.rarity >= UnifiedItemData.Rarity.EPIC:
					result.append(_create_display_dict(item))
	
	return result

func purchase_item(item_id: String) -> bool:
	"""Process a purchase"""
	print("ShopManager: Processing purchase for %s" % item_id)
	
	# Validate managers
	if not ItemManager or not EquipmentManager or not StarManager:
		push_error("ShopManager: Required managers not available")
		purchase_failed.emit(item_id, "System error")
		return false
	
	# Get item
	var item = ItemManager.get_item(item_id)
	if not item:
		push_error("ShopManager: Item not found: %s" % item_id)
		purchase_failed.emit(item_id, "Item not found")
		return false
	
	# Check if already owned
	if EquipmentManager.is_item_owned(item_id):
		push_warning("ShopManager: Item already owned: %s" % item_id)
		purchase_failed.emit(item_id, "Already owned")
		return false
	
	# Check if purchasable
	if not item.is_purchasable:
		push_warning("ShopManager: Item not purchasable: %s" % item_id)
		purchase_failed.emit(item_id, "Not for sale")
		return false
	
	# Calculate price
	var price = get_item_price(item_id)
	var current_balance = StarManager.get_balance()
	
	print("  Price: %d, Balance: %d" % [price, current_balance])
	
	# Check funds
	if current_balance < price:
		insufficient_funds.emit(price, current_balance)
		purchase_failed.emit(item_id, "Insufficient funds")
		return false
	
	# Process payment
	if not StarManager.spend_stars(price, "shop_purchase_%s" % item_id):
		purchase_failed.emit(item_id, "Payment failed")
		return false
	
	# Grant item
	if not EquipmentManager.grant_item(item_id, "shop"):
		# Refund if grant failed
		StarManager.add_stars(price, "refund_%s" % item_id)
		purchase_failed.emit(item_id, "Grant failed")
		return false
	
	# Success!
	item_purchased.emit(item_id, price)
	print("ShopManager: Purchase successful - %s for %d stars" % [item_id, price])
	return true

func get_item_price(item_id: String) -> int:
	"""Get the price of an item"""
	var item = ItemManager.get_item(item_id) if ItemManager else null
	if not item:
		return -1
	
	# Use base price or calculate from rarity
	var price = item.base_price
	if price <= 0:
		# Default prices by rarity
		match item.rarity:
			UnifiedItemData.Rarity.COMMON: price = 50
			UnifiedItemData.Rarity.UNCOMMON: price = 100
			UnifiedItemData.Rarity.RARE: price = 250
			UnifiedItemData.Rarity.EPIC: price = 500
			UnifiedItemData.Rarity.LEGENDARY: price = 1000
			UnifiedItemData.Rarity.MYTHIC: price = 2000
			_: price = 100
	
	return max(1, price)  # Minimum 1 star

func can_afford_item(item_id: String) -> bool:
	"""Check if player can afford an item"""
	var price = get_item_price(item_id)
	if price < 0:
		return false
	
	return StarManager.get_balance() >= price if StarManager else false

func is_item_on_sale(item_id: String) -> bool:
	"""Check if an item is on sale"""
	# TODO: Implement sales system
	return false

# === PRIVATE HELPERS ===

func _is_purchasable(item: UnifiedItemData) -> bool:
	"""Check if an item should appear in the shop"""
	# Must be purchasable
	if not item.is_purchasable:
		return false
	
	# Must not be owned
	if EquipmentManager and EquipmentManager.is_item_owned(item.id):
		return false
	
	# Must not be a default item (free starters)
	if item.source == UnifiedItemData.Source.DEFAULT:
		return false
	
	return true

func _create_display_dict(item: UnifiedItemData) -> Dictionary:
	"""Create a display dictionary for ShopUI"""
	return {
		"id": item.id,
		"item_data": item,  # The actual UnifiedItemData Resource
		"display_name": item.display_name,
		"description": item.description,
		"category": item.get_category_name(),
		"rarity": item.rarity,
		"rarity_name": item.get_rarity_name(),
		"price": get_item_price(item.id),
		"icon_path": item.icon_path,
		"preview_path": item.preview_texture_path,
		"unlock_level": item.unlock_level,
		"on_sale": false,  # Always false for MVP
		"is_new": item.is_new,
		"can_afford": can_afford_item(item.id),
		"is_animated": item.is_animated,
		"is_procedural": item.is_procedural
	}

# === FUTURE FEATURES (TODO) ===

func refresh_daily_sales():
	# TODO: Implement daily sales rotation
	pass

func add_featured_item(item_id: String):
	# TODO: Add item to featured/highlights
	pass

func set_item_discount(item_id: String, discount_percent: float):
	# TODO: Apply discount to specific item
	pass

func process_gem_purchase(item_id: String) -> bool:
	# TODO: Handle premium currency purchases
	return false

func process_event_token_purchase(item_id: String, event_id: String) -> bool:
	# TODO: Handle event currency purchases
	return false

# === DEBUG ===

func debug_add_stars(amount: int):
	"""Add stars for testing"""
	if StarManager:
		StarManager.add_stars(amount, "debug")
		print("ShopManager: Added %d stars (balance: %d)" % [amount, StarManager.get_balance()])

func debug_clear_ownership():
	"""Clear all ownership for testing"""
	if EquipmentManager:
		EquipmentManager.reset_all_equipment()
		print("ShopManager: Cleared all ownership")

func debug_grant_item(item_id: String):
	"""Grant an item for testing"""
	if EquipmentManager:
		EquipmentManager.grant_item(item_id, "debug")
		print("ShopManager: Granted item %s" % item_id)

func debug_status():
	"""Print shop status"""
	print("\n=== SHOP MANAGER STATUS ===")
	var all_items = get_all_shop_items()
	print("Total purchasable items: %d" % all_items.size())
	
	# Count by category
	var category_counts = {}
	for item_dict in all_items:
		var category = item_dict.category
		if not category_counts.has(category):
			category_counts[category] = 0
		category_counts[category] += 1
	
	print("By category:")
	for category in category_counts:
		print("  %s: %d items" % [category, category_counts[category]])
	
	print("Star balance: %d" % (StarManager.get_balance() if StarManager else 0))
	print("===========================\n")
