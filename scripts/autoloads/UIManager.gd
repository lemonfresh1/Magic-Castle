# UIManager.gd - Manages all UI panels and ensures only one is open at a time
# Location: res://Pyramids/scripts/autoloads/UIManager.gd
# Last Updated: Added debug system, replaced print statements

extends Node

# Debug configuration
var debug_enabled: bool = false
var global_debug: bool = true

signal ui_panel_opened(panel_name: String)
signal ui_panel_closed(panel_name: String)

# Currently active UI panel
var current_panel: Control = null
var current_panel_name: String = ""
var current_button: BaseButton = null

# Dictionary to track which button opened which panel
var button_panel_map = {}

func open_panel(panel: Control, panel_name: String, opening_button: BaseButton = null):
	debug_log("Request to open panel: %s" % panel_name)
	debug_log("  - Current panel: %s" % current_panel_name)
	debug_log("  - Opening button: %s" % (opening_button.name if opening_button else "none"))
	debug_log("  - Current button: %s" % (current_button.name if current_button else "none"))
	debug_log("  - Button pressed state: %s" % (opening_button.button_pressed if opening_button else "N/A"))
	
	# If clicking the same button that opened current panel, close it
	if opening_button and current_panel == panel and current_button == opening_button:
		debug_log("  - Same button clicked, closing panel")
		close_current_panel()
		return
	
	# Close current panel if different
	if current_panel and current_panel != panel:
		debug_log("  - Different panel requested, closing current")
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
		debug_log("  - Set button pressed: %s" % opening_button.name)
	
	# Call show method if it exists
	if panel.has_method("show_" + panel_name):
		panel.call("show_" + panel_name)
	
	ui_panel_opened.emit(panel_name)
	debug_log("Opened panel: %s" % panel_name)

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
					debug_log("  - Untoggling button: %s" % btn.name)
					btn.button_pressed = false

func close_current_panel():
	if current_panel:
		debug_log("Closing panel: %s" % current_panel_name)
		
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

func debug_log(message: String) -> void:
	"""Debug logging with component prefix"""
	if debug_enabled and global_debug:
		print("[UIMANAGER] %s" % message)
