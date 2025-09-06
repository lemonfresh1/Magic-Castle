# PopupBase.gd - Simplified with standard button styling
# Location: res://Pyramids/scripts/ui/popups/PopupBase.gd  
# Last Updated: Simplified button styling approach

extends Control
class_name PopupBase

signal closed
signal confirmed
signal cancelled

# Scene nodes - populated from the scene tree
@onready var backdrop: ColorRect = $Backdrop
@onready var panel: StyledPanel = $StyledPanel
@onready var title_label: Label = $StyledPanel/MarginContainer/Content/Title
@onready var asset_container: CenterContainer = $StyledPanel/MarginContainer/Content/AssetContainer
@onready var message_label: Label = $StyledPanel/MarginContainer/Content/Message
@onready var button_container: HBoxContainer = $StyledPanel/MarginContainer/Content/ButtonContainer
@onready var cancel_button: StyledButton = $StyledPanel/MarginContainer/Content/ButtonContainer/CancelButton
@onready var confirm_button: StyledButton = $StyledPanel/MarginContainer/Content/ButtonContainer/ConfirmButton

@export var close_on_backdrop_click: bool = true
@export var close_on_esc: bool = true

func _ready():
	visible = false
	set_process_unhandled_input(true)
	
	# Use call_deferred to ensure @onready vars are initialized
	call_deferred("_setup_connections")
	call_deferred("_apply_text_styles")

func _setup_connections():
	# Connect backdrop click
	if close_on_backdrop_click and backdrop:
		backdrop.gui_input.connect(_on_backdrop_input)
	
	# Connect default buttons
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func _apply_text_styles():
	"""Apply proper text colors from ThemeConstants"""
	# Title styling - use primary color for emphasis
	if title_label and ThemeConstants:
		title_label.add_theme_color_override("font_color", ThemeConstants.colors.primary)
		title_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_title)
	
	# Message styling - use secondary text color
	if message_label and ThemeConstants:
		message_label.add_theme_color_override("font_color", ThemeConstants.colors.gray_700)
		message_label.add_theme_font_size_override("font_size", ThemeConstants.typography.size_body)

func setup_basic(title: String, message: String = "", show_cancel: bool = false):
	"""Basic setup for simple popups"""
	set_title(title)
	
	if message != "":
		show_message(message)
	
	if show_cancel:
		show_cancel_button()
	else:
		hide_cancel_button()

func set_title(text: String):
	if title_label:
		title_label.text = text

func show_message(text: String):
	if message_label:
		message_label.text = text
		message_label.visible = true

func hide_message():
	if message_label:
		message_label.visible = false

func show_cancel_button(text: String = "Cancel"):
	if cancel_button:
		cancel_button.text = text
		cancel_button.visible = true

func hide_cancel_button():
	if cancel_button:
		cancel_button.visible = false

func set_confirm_button_text(text: String):
	if confirm_button:
		confirm_button.text = text

func show_asset_container():
	if asset_container:
		asset_container.visible = true

func hide_asset_container():
	if asset_container:
		asset_container.visible = false

func add_to_asset_container(node: Node):
	"""Add a node (like UnifiedItemCard) to the asset container"""
	if asset_container:
		# Clear existing children
		for child in asset_container.get_children():
			child.queue_free()
		asset_container.add_child(node)
		asset_container.visible = true

func display():
	visible = true
	
	# Fade in animation
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _on_backdrop_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		close()

func _on_confirm_pressed():
	confirmed.emit()
	close()

func _on_cancel_pressed():
	cancelled.emit()
	close()

func _unhandled_input(event: InputEvent):
	if close_on_esc and event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		close()
		get_viewport().set_input_as_handled()

func show_popup():
	"""Queue this popup to show"""
	if PopupQueue:
		PopupQueue.show_popup(self)
	else:
		display()

func close():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		closed.emit()
		if PopupQueue:
			PopupQueue.popup_closed(self)
		queue_free()
	)
	
