# EquipPopup.gd - Equipment confirmation popup
# Location: res://Pyramids/scripts/ui/popups/EquipPopup.gd
# Last Updated: Scene-based implementation

extends PopupBase
class_name EquipPopup

var item_id: String = ""
var item_category: String = ""

func setup(title: String, message: String, item_id_val: String, category: String):
	"""Setup equip popup"""
	self.item_id = item_id_val
	self.item_category = category
	
	# Basic setup
	setup_basic(title if title != "" else "Equip Item", message, false)
	
	# Single button for equip
	set_confirm_button_text("Equip")
	hide_cancel_button()

func setup_with_item(item: UnifiedItemData):
	"""Setup with UnifiedItemData object"""
	self.item_id = item.id
	self.item_category = item.get_category_name()
	
	set_title("Equip %s?" % item.display_name)
	
	# Add item card to asset container
	if ItemManager:
		var card_scene = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn")
		var card = card_scene.instantiate()
		card.custom_minimum_size = Vector2(80, 80)
		card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
		add_to_asset_container(card)
	
	set_confirm_button_text("Equip")
	hide_cancel_button()
