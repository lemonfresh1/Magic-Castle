# EquipDialog.gd - Simple dialog for equipping items from inventory
# Location: res://Magic-Castle/scripts/ui/dialogs/EquipDialog.gd
# Last Updated: Created equip dialog for inventory items [Date]

extends AcceptDialog

signal item_equipped(item_id: String)
signal item_unequipped(item_id: String)

var current_item: ShopManager.ShopItem
var is_currently_equipped: bool = false

func setup_for_item(item: ShopManager.ShopItem):
	current_item = item
	
	# Check if currently equipped
	var equipped = ShopManager.shop_data.equipped
	is_currently_equipped = false
	
	match item.category:
		"card_skins":
			is_currently_equipped = equipped.card_skin == item.id
		"board_skins":
			is_currently_equipped = equipped.board_skin == item.id
		"avatars":
			is_currently_equipped = equipped.avatar == item.id
		"frames":
			is_currently_equipped = equipped.frame == item.id
		"emojis":
			is_currently_equipped = item.id in equipped.selected_emojis
	
	# Set dialog text
	if is_currently_equipped:
		title = "Unequip Item"
		dialog_text = "Do you want to unequip %s?" % item.display_name
		ok_button_text = "Unequip"
	else:
		title = "Equip Item"
		dialog_text = "Do you want to equip %s?" % item.display_name
		ok_button_text = "Equip"
	
	# Add cancel button
	add_cancel_button("Cancel")

func _ready():
	# Connect to confirmed signal
	confirmed.connect(_on_confirmed)

func _on_confirmed():
	if is_currently_equipped:
		# Unequip logic
		match current_item.category:
			"emojis":
				# Remove from selected emojis
				var equipped_emojis = ShopManager.shop_data.equipped.selected_emojis
				equipped_emojis.erase(current_item.id)
				ShopManager.save_shop_data()
			_:
				# For other categories, we'd need to set to default
				# For now, just prevent unequipping
				pass
		
		item_unequipped.emit(current_item.id)
	else:
		# Equip the item
		if ShopManager.equip_item(current_item.id):
			item_equipped.emit(current_item.id)
