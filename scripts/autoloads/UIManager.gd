# UIManager.gd - Manages all UI panels and ensures only one is open at a time
# Location: res://Pyramids/scripts/autoloads/UIManager.gd
# Last Updated: Added button toggle state management [Date]

extends Node

signal ui_panel_opened(panel_name: String)
signal ui_panel_closed(panel_name: String)

# Currently active UI panel
var current_panel: Control = null
var current_panel_name: String = ""
var current_button: BaseButton = null

# Dictionary to track which button opened which panel
var button_panel_map = {}

func open_panel(panel: Control, panel_name: String, opening_button: BaseButton = null):
	print("UIManager: Request to open panel: ", panel_name)
	print("  - Current panel: ", current_panel_name)
	print("  - Opening button: ", opening_button.name if opening_button else "none")
	print("  - Current button: ", current_button.name if current_button else "none")
	print("  - Button pressed state: ", opening_button.button_pressed if opening_button else "N/A")
	
	# If clicking the same button that opened current panel, close it
	if opening_button and current_panel == panel and current_button == opening_button:
		print("  - Same button clicked, closing panel")
		close_current_panel()
		return
	
	# Close current panel if different
	if current_panel and current_panel != panel:
		print("  - Different panel requested, closing current")
		close_current_panel()
	
	# Open new panel
	panel.visible = true
	current_panel = panel
	current_panel_name = panel_name
	
	# Update button states
	if opening_button:
		# Untoggle ALL toggle buttons in ProfileCard first
		_untoggle_all_profile_buttons(opening_button)
		
		# Set new button as pressed
		opening_button.button_pressed = true
		current_button = opening_button
		button_panel_map[opening_button] = panel_name
		print("  - Set button pressed: ", opening_button.name)
	
	# Call show method if it exists
	if panel.has_method("show_" + panel_name):
		panel.call("show_" + panel_name)
	
	ui_panel_opened.emit(panel_name)
	print("UIManager: Opened panel: ", panel_name)

func _untoggle_all_profile_buttons(except_button: BaseButton = null):
	# Get the ProfileCard node if it exists
	var main_menu = get_tree().get_nodes_in_group("main_menu")[0] if get_tree().has_group("main_menu") else null
	if not main_menu:
		main_menu = get_node_or_null("/root/Main") # Or whatever your main scene root is
	
	if main_menu and main_menu.has_node("ProfileCard"):
		var profile_card = main_menu.get_node("ProfileCard")
		
		# List of all toggle buttons in ProfileCard
		var button_names = ["ProfileButton", "InventoryButton", "InboxButton", 
							"AchievementsButton", "StatsButton", "ClanButton", 
							"FollowersButton", "ReferralButton"]
		
		for btn_name in button_names:
			var btn = profile_card.get_node_or_null("MarginContainer/HeaderContainer/ButtonContainer/HBoxContainer/" + btn_name)
			if btn and btn != except_button and btn is BaseButton and btn.toggle_mode:
				if btn.button_pressed:
					print("  - Untoggling button: ", btn.name)
					btn.button_pressed = false

func close_current_panel():
	if current_panel:
		print("UIManager: Closing panel: ", current_panel_name)
		
		current_panel.visible = false
		
		# Call hide method if it exists
		if current_panel.has_method("hide_" + current_panel_name):
			current_panel.call("hide_" + current_panel_name)
		
		ui_panel_closed.emit(current_panel_name)
		
		# Untoggle the current button
		if current_button and current_button.button_pressed:
			current_button.button_pressed = false
		
		# Clear button associations for this panel
		var buttons_to_clear = []
		for button in button_panel_map:
			if button_panel_map[button] == current_panel_name:
				buttons_to_clear.append(button)
		
		for button in buttons_to_clear:
			button_panel_map.erase(button)
		
		current_panel = null
		current_panel_name = ""
		current_button = null

func close_panel(panel_name: String):
	if current_panel_name == panel_name:
		close_current_panel()

func is_panel_open(panel_name: String) -> bool:
	return current_panel_name == panel_name

func get_current_panel_name() -> String:
	return current_panel_name
