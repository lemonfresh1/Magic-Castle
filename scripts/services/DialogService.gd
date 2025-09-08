# DialogService.gd - Orchestrates popup display and business logic separation
# Location: res://Pyramids/scripts/services/DialogService.gd
# Last Updated: Added UnifiedItemData support for purchase popups with card display
#
# Purpose: Central service for managing all popup dialogs in the game
# Dependencies: PopupQueue (autoload), ItemManager (autoload), various popup scripts
# Use Cases: Purchase confirmations, equip dialogs, error messages, rewards, etc.
# Flow: 1) UI calls DialogService → 2) Create popup → 3) Add to tree → 4) Setup → 5) Queue display
# Notes: Must add popup to tree before setup for node references to work

extends Node

# Scene preloads
const POPUP_BASE_SCENE = preload("res://Pyramids/scenes/ui/popups/PopupBase.tscn")
const REWARD_CLAIM_POPUP_SCENE = preload("res://Pyramids/scenes/ui/popups/RewardClaimPopup.tscn")
const ITEM_EXPANDED_VIEW_SCENE = preload("res://Pyramids/scenes/ui/popups/ItemExpandedView.tscn")

# Script preloads
const EQUIP_POPUP_SCRIPT = preload("res://Pyramids/scripts/ui/popups/EquipPopup.gd")
const PURCHASE_POPUP_SCRIPT = preload("res://Pyramids/scripts/ui/popups/PurchasePopup.gd")
const SUCCESS_POPUP_SCRIPT = preload("res://Pyramids/scripts/ui/popups/SuccessPopup.gd")
const ERROR_POPUP_SCRIPT = preload("res://Pyramids/scripts/ui/popups/ErrorPopup.gd")
const KICK_POPUP_SCRIPT = preload("res://Pyramids/scripts/ui/popups/KickPopup.gd")
const LEAVE_POPUP_SCRIPT = preload("res://Pyramids/scripts/ui/popups/LeavePopup.gd")

# Global signals for popup events
signal popup_confirmed(popup_type: String, data: Dictionary)
signal popup_cancelled(popup_type: String, data: Dictionary)
signal popup_closed(popup_type: String, data: Dictionary)

var debug_enabled: bool = true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_debug_log("DialogService initialized")

# === Equip Dialogs ===
func show_equip(item_name: String, category: String, item_id: String = "") -> PopupBase:
	"""Show equip confirmation for an item"""
	_debug_log("show_equip called for: %s (id: %s)" % [item_name, item_id])
	
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(EQUIP_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	# Try to get the full item data to show the card visual
	var item_data = null
	if item_id != "" and ItemManager:
		item_data = ItemManager.get_item(item_id)
		_debug_log("Got item_data: %s" % (item_data.display_name if item_data else "null"))
	
	# Setup popup with item card if available, otherwise text-only
	if item_data:
		# Use the setup_with_item method to show the card visual
		popup.setup_with_item(item_data)
		
		# Override message for emojis
		if category == "emoji":
			popup.show_message("Add %s to your emoji collection?\n(Max 4 emojis)" % item_name)
	else:
		# Fallback to text-only setup
		var message = "Equip %s?" % item_name
		if category == "emoji":
			message = "Add %s to your emoji collection?\n(Max 4 emojis)" % item_name
		
		popup.setup("Equip Item", message, item_id, category)
	
	# Store data for signal emission
	var data = {
		"item_name": item_name,
		"item_id": item_id,
		"category": category,
		"type": "equip"
	}
	
	# Connect signals
	popup.confirmed.connect(func(): 
		_debug_log("Equip confirmed: %s" % item_name)
		popup_confirmed.emit("equip", data)
	)
	popup.cancelled.connect(func(): 
		_debug_log("Equip cancelled: %s" % item_name)
		popup_cancelled.emit("equip", data)
	)
	popup.closed.connect(func(): popup_closed.emit("equip", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

# === Purchase Dialogs ===
func show_purchase(item_name: String, price: int, currency: String = "coins", item_id: String = "", item_data: UnifiedItemData = null) -> PopupBase:
	"""Show purchase confirmation dialog - now accepts full item data for card display"""
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(PURCHASE_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	# Try to get the full item data if not provided but item_id exists
	if not item_data and item_id != "" and ItemManager:
		item_data = ItemManager.get_item(item_id)
		_debug_log("Got item_data from ItemManager for purchase: %s" % (item_data.display_name if item_data else "null"))
	
	# Use setup_with_item if we have the data, otherwise fall back to basic setup
	if item_data:
		_debug_log("Using setup_with_item for purchase popup with: %s" % item_data.display_name)
		popup.setup_with_item("Purchase", item_data, price, currency)
	else:
		_debug_log("Using basic setup for purchase popup (no item data)")
		var title = "Confirm Purchase"
		var message = "Purchase %s for %d %s?" % [item_name, price, currency]
		popup.setup(title, message, price, currency)
	
	var data = {
		"item_name": item_name,
		"item_id": item_id,
		"price": price,
		"currency": currency,
		"type": "purchase"
	}
	
	# Connect signals
	popup.confirmed.connect(func():
		_debug_log("Purchase confirmed: %s for %d %s" % [item_name, price, currency])
		popup_confirmed.emit("purchase", data)
		# REMOVED THE DIRECT PURCHASE CALL - ShopUI will handle this
	)
	popup.cancelled.connect(func():
		_debug_log("Purchase cancelled: %s" % item_name)
		popup_cancelled.emit("purchase", data)
	)
	popup.closed.connect(func(): popup_closed.emit("purchase", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

func show_battle_pass_purchase(pass_type: String, price: int) -> PopupBase:
	"""Show battle pass purchase confirmation"""
	var title = "Purchase %s Pass" % pass_type.capitalize()
	var message = "Unlock the %s Pass for %d Stars?" % [pass_type.capitalize(), price]
	
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(PURCHASE_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	popup.setup(title, message, price, "stars")
	
	var data = {
		"pass_type": pass_type,
		"price": price,
		"type": "battle_pass"
	}
	
	popup.confirmed.connect(func(): popup_confirmed.emit("battle_pass", data))
	popup.cancelled.connect(func(): popup_cancelled.emit("battle_pass", data))
	popup.closed.connect(func(): popup_closed.emit("battle_pass", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

func show_buy_levels(current_level: int, target_level: int, price_per_level: int) -> PopupBase:
	"""Show buy battle pass levels confirmation"""
	var levels_to_buy = target_level - current_level
	var total_price = levels_to_buy * price_per_level
	var title = "Buy Battle Pass Levels"
	var message = "Buy %d levels for %d Stars?" % [levels_to_buy, total_price]
	
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(PURCHASE_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	popup.setup(title, message, total_price, "stars")
	
	var data = {
		"current_level": current_level,
		"target_level": target_level,
		"levels": levels_to_buy,
		"price": total_price,
		"type": "buy_levels"
	}
	
	popup.confirmed.connect(func(): popup_confirmed.emit("buy_levels", data))
	popup.cancelled.connect(func(): popup_cancelled.emit("buy_levels", data))
	popup.closed.connect(func(): popup_closed.emit("buy_levels", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

# === Success Dialogs ===
func show_success(title: String = "Success!", message: String = "", button_text: String = "Great!") -> PopupBase:
	"""Show generic success message"""
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(SUCCESS_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	popup.setup(title, message, button_text)
	
	var data = {"type": "success", "title": title}
	popup.closed.connect(func(): popup_closed.emit("success", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

func show_purchase_success(item_name: String) -> PopupBase:
	"""Show purchase success message"""
	return show_success("Purchase Complete!", "You now own %s!" % item_name, "Awesome!")

# === Error Dialogs ===
func show_error(message: String, title: String = "Error") -> PopupBase:
	"""Show an error message"""
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(ERROR_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	popup.setup(title, message)
	
	var data = {"type": "error", "message": message}
	popup.closed.connect(func(): popup_closed.emit("error", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

func show_insufficient_funds(required: int, current: int, currency: String = "coins") -> PopupBase:
	"""Show insufficient funds error"""
	var message = "Not enough %s!\n\nRequired: %d\nYou have: %d" % [currency, required, current]
	return show_error(message, "Insufficient Funds")

func show_connection_error(error_type: String = "disconnect") -> PopupBase:
	"""Show connection error messages"""
	var title = "Connection Error"
	var message = ""
	
	match error_type:
		"disconnect":
			message = "You have been disconnected from the server."
		"reconnecting":
			message = "Attempting to reconnect..."
		"timeout":
			message = "Connection timed out. Please try again."
		_:
			message = "A connection error occurred."
	
	return show_error(message, title)

# === Reward Dialogs (using existing RewardClaimPopup scene) ===
# DO NOT TOUCH - These work differently and should not be modified
func show_reward(rewards: Dictionary, icon_texture: Texture2D = null) -> RewardClaimPopup:
	"""Show single reward using existing RewardClaimPopup"""
	# DO NOT MODIFY - This uses its own scene and works correctly
	var popup = REWARD_CLAIM_POPUP_SCENE.instantiate()
	popup.setup(rewards, icon_texture)
	
	var data = {"rewards": rewards}
	popup.confirmed.connect(func(): popup_confirmed.emit("reward", data))
	popup.closed.connect(func(): popup_closed.emit("reward", data))
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.visible = true
	
	return popup

func show_rewards_with_level_up(rewards: Dictionary, level_ups: Array) -> RewardClaimPopup:
	"""Show rewards with level-up information"""
	# DO NOT MODIFY - This uses its own scene and works correctly
	var popup = REWARD_CLAIM_POPUP_SCENE.instantiate()
	popup.setup_with_level_ups(rewards, level_ups)
	
	var data = {"rewards": rewards, "level_ups": level_ups}
	popup.confirmed.connect(func(): popup_confirmed.emit("reward_levelup", data))
	popup.closed.connect(func(): popup_closed.emit("reward_levelup", data))
	
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.visible = true
	
	return popup

func show_batch_rewards(rewards_array: Array) -> RewardClaimPopup:
	"""Show multiple rewards using existing RewardClaimPopup"""
	# DO NOT MODIFY - This uses its own scene and works correctly
	var popup = REWARD_CLAIM_POPUP_SCENE.instantiate()
	popup.setup_batch(rewards_array)
	
	var data = {"rewards": rewards_array}
	popup.confirmed.connect(func(): popup_confirmed.emit("batch_reward", data))
	popup.closed.connect(func(): popup_closed.emit("batch_reward", data))
	
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.visible = true
	
	return popup

func show_batch_rewards_with_level_up(rewards_array: Array, level_ups: Array) -> RewardClaimPopup:
	"""Show batch rewards with level-up information"""
	# DO NOT MODIFY - This uses its own scene and works correctly
	var popup = REWARD_CLAIM_POPUP_SCENE.instantiate()
	popup.setup_batch_with_level_ups(rewards_array, level_ups)
	
	var data = {"rewards": rewards_array, "level_ups": level_ups}
	popup.confirmed.connect(func(): popup_confirmed.emit("batch_reward_levelup", data))
	popup.closed.connect(func(): popup_closed.emit("batch_reward_levelup", data))
	
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.visible = true
	
	return popup

func show_starbox_claim(xp: int, stars: int, streak: int) -> RewardClaimPopup:
	"""Show starbox claim with streak info"""
	var rewards = {
		"xp": xp,
		"stars": stars
	}
	
	# DO NOT MODIFY - This uses its own scene and works correctly
	var popup = REWARD_CLAIM_POPUP_SCENE.instantiate()
	popup.setup(rewards)
	
	# TODO: Add streak display to popup
	if popup.message_label:
		popup.message_label.text = "Day %d Streak!\nYou received %d XP and %d Stars!" % [streak, xp, stars]
	
	var data = {"xp": xp, "stars": stars, "streak": streak}
	popup.confirmed.connect(func(): popup_confirmed.emit("starbox", data))
	popup.closed.connect(func(): popup_closed.emit("starbox", data))
	
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.visible = true
	
	return popup

# === Kick/Leave Dialogs ===
func show_kick_player(player_name: String) -> PopupBase:
	"""Show kick player confirmation"""
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(KICK_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	var title = "Kick Player"
	var message = "Are you sure you want to kick %s from the lobby?" % player_name
	
	popup.setup(title, message, player_name)
	
	var data = {"player_name": player_name, "type": "kick"}
	popup.confirmed.connect(func(): popup_confirmed.emit("kick", data))
	popup.cancelled.connect(func(): popup_cancelled.emit("kick", data))
	popup.closed.connect(func(): popup_closed.emit("kick", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

func show_leave_lobby() -> PopupBase:
	"""Show leave lobby confirmation"""
	# Create popup from scene and attach script
	var popup = POPUP_BASE_SCENE.instantiate()
	popup.set_script(LEAVE_POPUP_SCRIPT)
	
	# Add to tree FIRST (needed for node references to work)
	get_tree().root.add_child(popup)
	
	var title = "Leave Lobby"
	var message = "Are you sure you want to leave the lobby?"
	
	popup.setup(title, message)
	
	var data = {"type": "leave"}
	popup.confirmed.connect(func(): popup_confirmed.emit("leave", data))
	popup.cancelled.connect(func(): popup_cancelled.emit("leave", data))
	popup.closed.connect(func(): popup_closed.emit("leave", data))
	
	# Remove from root and queue through PopupQueue
	get_tree().root.remove_child(popup)
	
	# Queue through PopupQueue
	if PopupQueue:
		PopupQueue.show_popup(popup)
	else:
		push_error("PopupQueue not found!")
		get_tree().root.add_child(popup)
		popup.show_popup()
	
	return popup

# === Utility Functions ===
func _debug_log(message: String):
	if debug_enabled:
		print("[DialogService] %s" % message)
