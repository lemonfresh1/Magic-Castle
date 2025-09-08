extends ColorRect

@onready var item_card_container = $StyledPanel/MarginContainer/VBoxContainer/ItemCardContainer
@onready var price_label = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton/HBoxContainer/Label
@onready var confirm_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/CancelButton

signal confirmed

func setup(item: UnifiedItemData, price: int):
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	# Add the item card
	var card = preload("res://Pyramids/scenes/ui/items/UnifiedItemCard.tscn").instantiate()
	card.setup(item, UnifiedItemCard.DisplayMode.SHOP)
	item_card_container.add_child(card)
	
	# Set price in the label
	price_label.text = str(price)

func _ready():
	# Debug: Check if nodes are found
	if not item_card_container:
		push_error("PurchaseDialog: ItemCardContainer not found!")
		print("Available children: ", $StyledPanel/MarginContainer/VBoxContainer.get_children())
	
	confirm_button.pressed.connect(func(): 
		confirmed.emit()
		queue_free()
	)
	cancel_button.pressed.connect(func():
		queue_free()
	)
