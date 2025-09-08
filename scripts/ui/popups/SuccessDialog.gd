extends ColorRect

@onready var item_card_container = $StyledPanel/MarginContainer/VBoxContainer/ItemCardContainer
@onready var confirm_button = $StyledPanel/MarginContainer/VBoxContainer/ConfirmButton

func setup(item: UnifiedItemData):
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	# Add the item card
	var card = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn").instantiate()
	card.setup(item, UnifiedItemCard.DisplayMode.INVENTORY)
	item_card_container.add_child(card)

func _ready():
	# Debug check
	if not item_card_container:
		push_error("SuccessDialog: ItemCardContainer not found!")
		print("Available children: ", $StyledPanel/MarginContainer/VBoxContainer.get_children())
	
	confirm_button.pressed.connect(func():
		queue_free()
	)
