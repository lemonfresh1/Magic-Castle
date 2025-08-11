# EquipDialog.gd - Dialog for equipping items using CustomDialog
# Location: res://Pyramids/scripts/ui/dialogs/EquipDialog.gd
# Last Updated: Converted to use CustomDialog [Date]

extends CustomDialog

signal item_equipped(item_id: String)

var current_item: ShopManager.ShopItem

func setup_for_item(item: ShopManager.ShopItem):
	current_item = item
	
	# Only show for equipping (not unequipping as requested)
	var item_type = _get_item_type_display(item.category)
	
	# Try to get icon - same logic as InventoryItemCard
	var icon: Texture2D = null
	var icon_loaded = false
	
	# First try preview_texture_path (actual icon from ItemData)
	if item.preview_texture_path != "" and ResourceLoader.exists(item.preview_texture_path):
		icon = load(item.preview_texture_path)
		icon_loaded = true
	
	# Fallback to placeholder icon if no actual icon
	if not icon_loaded and item.placeholder_icon != "":
		var placeholder_path = "res://Pyramids/assets/placeholder/food/" + item.placeholder_icon
		if ResourceLoader.exists(placeholder_path):
			icon = load(placeholder_path)
	
	# Setup the dialog with body text only, empty title
	setup("", "Equip: %s (%s)" % [item.display_name, item_type], icon, "Equip", false)
	
	# Hide the title label completely
	if title_label:
		title_label.visible = false
	
	# Override confirm behavior
	if confirmed.is_connected(_on_confirm):
		confirmed.disconnect(_on_confirm)
	confirmed.connect(_on_equip_confirmed)

func _get_item_type_display(category: String) -> String:
	match category:
		"card_skins": return "Card Skin"
		"board_skins": return "Board Skin"
		"avatars": return "Avatar"
		"frames": return "Frame"
		"emojis": return "Emoji"
		_: return category.capitalize()

func _on_equip_confirmed():
	var success = false
	
	# Try ItemManager first
	if ItemManager and ItemManager.get_item(current_item.id):
		success = ItemManager.equip_item(current_item.id)
		if success:
			# Update ShopManager for compatibility
			var key = _get_shop_equipped_key()
			if key != "":
				ShopManager.shop_data.equipped[key] = current_item.id
				ShopManager.save_shop_data()
	else:
		# Fallback to ShopManager
		success = ShopManager.equip_item(current_item.id)
	
	if success:
		item_equipped.emit(current_item.id)
		
		# Update InventoryUI if it exists
		var inventory_ui = get_tree().get_nodes_in_group("inventory_ui")
		if inventory_ui.size() > 0:
			inventory_ui[0]._refresh_all_cards()

func _get_shop_equipped_key() -> String:
	match current_item.category:
		"card_skins": return "card_skin"
		"board_skins": return "board_skin"
		"avatars": return "avatar"
		"frames": return "frame"
		_: return ""
