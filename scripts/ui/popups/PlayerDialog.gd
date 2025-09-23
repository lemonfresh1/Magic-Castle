# PlayerDialog.gd - Player profile dialog
# Location: res://Pyramids/scripts/ui/popups/PlayerDialog.gd
# Last Updated: Initial implementation with placeholder actions

extends ColorRect

@onready var title_label = $StyledPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var mini_profile_container = $StyledPanel/MarginContainer/VBoxContainer/MiniProfileContainer
@onready var add_friend_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/AddFriendButton
@onready var send_message_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/SendMessageButton
@onready var leave_button = $StyledPanel/MarginContainer/VBoxContainer/HBoxContainer/LeaveButton

signal confirmed
signal add_friend_pressed(player_name: String)
signal send_message_pressed(player_name: String)

var player_name: String = ""
var player_data: Dictionary = {}

func setup(score_data: Dictionary = {}):
	# Wait for ready if needed
	if not is_node_ready():
		await ready
	
	player_data = score_data
	player_name = score_data.get("player_name", "Player")
	
	# Set title with player name
	if title_label:
		title_label.text = player_name
	
	# MiniProfileContainer is left alone as requested
	# TODO: Add mini profile card when implemented

func _ready():
	# Enable input on the backdrop
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_backdrop_input)
	
	# Update button text if needed
	if add_friend_button:
		add_friend_button.text = "Add"
		add_friend_button.pressed.connect(_on_add_friend_pressed)
	
	if send_message_button:
		send_message_button.text = "Message"
		send_message_button.pressed.connect(_on_send_message_pressed)
	
	if leave_button:
		leave_button.text = "Leave"
		leave_button.pressed.connect(func():
			queue_free()
		)

func _on_add_friend_pressed():
	"""Handle add friend button - placeholder for now"""
	print("[PlayerDialog] Add friend pressed for: %s" % player_name)
	# TODO: Implement add friend functionality
	add_friend_pressed.emit(player_name)
	# Don't close - would show success/failure feedback

func _on_send_message_pressed():
	"""Handle send message button - placeholder for now"""
	print("[PlayerDialog] Send message pressed to: %s" % player_name)
	# TODO: Implement messaging functionality
	send_message_pressed.emit(player_name)
	# Don't close - would open message composer

func _on_backdrop_input(event: InputEvent):
	"""Handle clicks on backdrop to close"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click was on backdrop (not on panel)
		var panel = $StyledPanel
		if panel:
			var panel_rect = panel.get_global_rect()
			if not panel_rect.has_point(event.global_position):
				queue_free()
