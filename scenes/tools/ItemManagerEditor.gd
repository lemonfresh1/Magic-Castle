#ItemManagerEditor.gd
extends Control

# Scene references
@onready var title_label: Label = $VBoxContainer/HeaderContainer/TitleLabel
@onready var refresh_button: Button = $VBoxContainer/HeaderContainer/ButtonContainer/RefreshButton
@onready var export_all_button: Button = $VBoxContainer/HeaderContainer/ButtonContainer/ExportAllButton
@onready var save_all_button: Button = $VBoxContainer/HeaderContainer/ButtonContainer/SaveAllButton
@onready var reload_button: Button = $VBoxContainer/HeaderContainer/ButtonContainer/ReloadButton  # NEW
@onready var exit_button: Button = $VBoxContainer/HeaderContainer/ButtonContainer/ExitButton  # NEW
@onready var category_tabs: TabContainer = $VBoxContainer/MainContent/LeftPanel/CategoryTabs
@onready var item_details: PanelContainer = $VBoxContainer/MainContent/RightPanel/ItemDetails
@onready var property_editor: ScrollContainer = $VBoxContainer/MainContent/RightPanel/PropertyEditor
@onready var preview_container: Control = $VBoxContainer/MainContent/RightPanel/PreviewContainer

# Data
var all_items: Dictionary = {}
var selected_item: UnifiedItemData
var category_lists: Dictionary = {}

func _ready():
	print("=== ITEM MANAGER EDITOR STARTING ===")
	
	# Setup UI
	title_label.text = "Item Manager Editor"
	refresh_button.pressed.connect(refresh_all)
	export_all_button.pressed.connect(export_all)
	save_all_button.pressed.connect(save_all)
	reload_button.pressed.connect(_reload_item_manager)  # NEW
	exit_button.pressed.connect(_exit_editor)  # NEW
	
	# Set button texts
	reload_button.text = "Reload ItemManager"
	exit_button.text = "Exit"

	# Add new button
	var generate_button = Button.new()
	generate_button.text = "Generate All .tres"
	generate_button.pressed.connect(_generate_all_tres)
	$VBoxContainer/HeaderContainer/ButtonContainer.add_child(generate_button)

	# Initialize
	refresh_all()

func _reload_item_manager():
	"""Force ItemManager to reload all items from disk"""
	print("=== RELOADING ITEM MANAGER ===")
	
	if has_node("/root/ItemManager"):
		var item_manager = get_node("/root/ItemManager")
		
		# Clear current items
		item_manager.all_items.clear()
		print("Cleared ItemManager items")
		
		# Force reload from disk - scan .tres files manually
		var base_path = "res://Pyramids/resources/items/"
		var categories = ["card_fronts", "card_backs", "boards", "mini_profile_cards", "frames", "avatars", "emojis"]
		
		for category in categories:
			var path = base_path + category + "/"
			if DirAccess.dir_exists_absolute(path):
				var dir = DirAccess.open(path)
				if dir:
					dir.list_dir_begin()
					var file_name = dir.get_next()
					
					while file_name != "":
						if file_name.ends_with(".tres"):
							var full_path = path + file_name
							# Force reload from disk (bypass cache)
							var item = load(full_path) as UnifiedItemData
							if item and item.id != "":
								item_manager.all_items[item.id] = item
								print("  Loaded from disk: %s (price: %d)" % [item.display_name, item.base_price])
						file_name = dir.get_next()
		
		print("ItemManager reloaded with %d items" % item_manager.all_items.size())
		
		# DON'T re-register procedural items - they would overwrite .tres data
		
		# Refresh our editor view
		refresh_all()
	else:
		print("ItemManager not found!")

func _exit_editor():
	"""Close the entire application"""
	print("Closing application...")
	
	# This closes the entire game/application
	get_tree().quit()

func _load_all_items():
	var procedural_items = []
	var tres_items = []
	
	# FIRST: Load from ItemManager (includes .tres files) - HIGHER PRIORITY
	if has_node("/root/ItemManager"):
		var item_manager = get_node("/root/ItemManager")
		for item_id in item_manager.all_items:
			all_items[item_id] = item_manager.all_items[item_id]
			tres_items.append(item_id)
	
	# SECOND: Load from ProceduralItemRegistry - only if NOT already loaded from .tres
	if has_node("/root/ProceduralItemRegistry"):
		var registry = get_node("/root/ProceduralItemRegistry")
		registry.discover_and_register_all()
		
		for item_id in registry.procedural_items:
			# ONLY add procedural if we don't have a .tres version
			if not all_items.has(item_id):
				var procedural_data = registry.procedural_items[item_id]
				if procedural_data.instance.has_method("create_item_data"):
					var item_data = procedural_data.instance.create_item_data()
					all_items[item_id] = item_data
					procedural_items.append(item_id)
			else:
				print("  Skipping procedural %s - using .tres version" % item_id)
	
	print("Loaded %d items total" % all_items.size())
	print("  - From .tres files (%d): %s" % [tres_items.size(), str(tres_items)])
	print("  - Procedural only (%d): %s" % [procedural_items.size(), str(procedural_items)])

func refresh_all():
	print("Refreshing all items...")
	
	# Clear everything
	all_items.clear()
	category_lists.clear()
	
	# Setup tabs with ItemLists
	for i in range(category_tabs.get_tab_count()):
		var tab = category_tabs.get_tab_control(i)
		var category_name = category_tabs.get_tab_title(i)
		
		# Clear tab
		for child in tab.get_children():
			child.queue_free()
		
		# Create new ItemList
		var item_list = ItemList.new()
		item_list.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_list.select_mode = ItemList.SELECT_SINGLE
		item_list.allow_reselect = true  # IMPORTANT: Allow clicking same item again
		
		# Simple styling from UIStyleManager
		item_list.add_theme_font_size_override("font_size", UIStyleManager.get_font_size("size_body_small"))
		item_list.add_theme_color_override("font_color", UIStyleManager.get_color("gray_700"))
		
		# REMOVE white background - use transparent
		var bg = StyleBoxEmpty.new()
		item_list.add_theme_stylebox_override("panel", bg)
		
		# Fix selected styling - make it visible with bold text
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = UIStyleManager.get_color("primary_light")  # Light green background
		selected_style.bg_color.a = 0.3  # Semi-transparent
		item_list.add_theme_stylebox_override("selected", selected_style)
		item_list.add_theme_stylebox_override("selected_focus", selected_style)
		
		# Make selected text dark and visible
		item_list.add_theme_color_override("font_selected_color", UIStyleManager.get_color("gray_900"))
		
		# Connect selection
		item_list.item_selected.connect(_on_item_selected.bind(category_name))
		
		tab.add_child(item_list)
		category_lists[category_name] = item_list
	
	# Load all items
	_load_all_items()
	
	# Populate lists
	_populate_lists()

func _populate_lists():
	# Clear all lists first
	for list in category_lists.values():
		list.clear()
	
	# Add items to appropriate lists
	for item_id in all_items:
		var item = all_items[item_id]
		var category_name = _get_category_name(item.category)
		
		if category_lists.has(category_name):
			var list = category_lists[category_name]
			var index = list.add_item(item.display_name)
			list.set_item_metadata(index, item_id)
			
			# Color by rarity
			list.set_item_custom_fg_color(index, item.get_rarity_color())

func _get_category_name(category: UnifiedItemData.Category) -> String:
	match category:
		UnifiedItemData.Category.CARD_BACK: return "Card Backs"
		UnifiedItemData.Category.CARD_FRONT: return "Card Fronts"
		UnifiedItemData.Category.BOARD: return "Boards"
		UnifiedItemData.Category.MINI_PROFILE_CARD: return "Mini Profile Cards"
		UnifiedItemData.Category.FRAME: return "Frames"
		UnifiedItemData.Category.AVATAR: return "Avatars"
		_: return "Unknown"

func _on_item_selected(index: int, category_name: String):
	var list = category_lists[category_name]
	var item_id = list.get_item_metadata(index)
	
	# Check if it's actually a different item or just re-selecting
	var previous_item = selected_item
	selected_item = all_items[item_id]
	
	print("Selected: %s (was: %s)" % [
		selected_item.display_name, 
		previous_item.display_name if previous_item else "none"
	])
	
	# Update all lists to show selection
	for cat_name in category_lists:
		var cat_list = category_lists[cat_name]
		for i in range(cat_list.get_item_count()):
			var original_text = cat_list.get_item_text(i).replace(" (SELECTED)", "")
			if cat_name == category_name and i == index:
				# Mark as selected
				cat_list.set_item_text(i, original_text + " (SELECTED)")
				# Make it bold (using color as workaround)
				cat_list.set_item_custom_fg_color(i, UIStyleManager.get_color("primary_dark"))
			else:
				# Reset others
				cat_list.set_item_text(i, original_text)
				# Reset color based on rarity
				var other_item_id = cat_list.get_item_metadata(i)
				if all_items.has(other_item_id):
					cat_list.set_item_custom_fg_color(i, all_items[other_item_id].get_rarity_color())
	
	# ALWAYS update details and preview, even if same item
	_show_item_details()
	_show_preview()
	_show_property_editor()  # ADD THIS

func _show_item_details():
	# Clear details
	for child in item_details.get_children():
		child.queue_free()
	
	if not selected_item:
		return
	
	# Simple details display
	var label = Label.new()
	label.text = "Name: %s\nType: %s\nRarity: %s" % [
		selected_item.display_name,
		selected_item.get_category_name(),
		selected_item.get_rarity_name()
	]
	item_details.add_child(label)

func _show_preview():
	# Clear preview
	for child in preview_container.get_children():
		child.queue_free()
	
	if not selected_item:
		return
	
	# Build the expected PNG path based on item properties
	var png_path = _get_item_png_path(selected_item)
	
	if ResourceLoader.exists(png_path):
		var texture = load(png_path)
		var texture_rect = TextureRect.new()
		texture_rect.texture = texture
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		
		# Force maximum size with a container
		var size_container = Control.new()
		size_container.custom_minimum_size = Vector2(64, 90)  # Force smaller size
		size_container.size = Vector2(64, 90)
		size_container.set_anchors_preset(Control.PRESET_CENTER)
		
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		size_container.add_child(texture_rect)
		preview_container.add_child(size_container)
		
		print("Showing preview from: %s" % png_path)
	else:
		# Show placeholder
		var label = Label.new()
		label.text = "Preview not available\n(Export PNG first)"
		label.set_anchors_preset(Control.PRESET_CENTER)
		preview_container.add_child(label)

func _get_item_png_path(item: UnifiedItemData) -> String:
	var category_folder = ""
	match item.category:
		UnifiedItemData.Category.CARD_BACK: category_folder = "card_backs"
		UnifiedItemData.Category.CARD_FRONT: category_folder = "card_fronts"
		UnifiedItemData.Category.BOARD: category_folder = "boards"
		UnifiedItemData.Category.MINI_PROFILE_CARD: category_folder = "mini_profile_cards"  # NEW
		UnifiedItemData.Category.FRAME: category_folder = "frames"
		UnifiedItemData.Category.AVATAR: category_folder = "avatars"
		_: category_folder = "misc"
	
	var rarity_folder = item.get_rarity_name().to_lower()
	
	return "res://Pyramids/assets/icons/%s/%s.png" % [category_folder, item.id]

	
func export_all():
	print("Export all not implemented yet")

func save_all():
	print("Save all not implemented yet")

func _show_property_editor():
	# Clear property editor
	for child in property_editor.get_children():
		child.queue_free()
	
	if not selected_item:
		return
	
	# Create a VBox for all properties
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_2"))
	property_editor.add_child(vbox)
	
	# Add property fields
	_add_property_field(vbox, "ID", "id", false)  # ID shouldn't be editable
	_add_property_field(vbox, "Display Name", "display_name")
	_add_property_field(vbox, "Description", "description", true, true)  # Multiline
	_add_property_field(vbox, "Base Price", "base_price", true, false, "number")
	_add_property_field(vbox, "Theme Name", "subcategory")
	_add_property_field(vbox, "Set Name", "set_name")
	_add_property_field(vbox, "Sort Order", "sort_order", true, false, "number")
	
	# Add dropdowns for enums
	_add_enum_field(vbox, "Rarity", "rarity", UnifiedItemData.Rarity)
	_add_enum_field(vbox, "Source", "source", UnifiedItemData.Source)
	
	# Add checkboxes
	_add_checkbox_field(vbox, "Is Animated", "is_animated")
	_add_checkbox_field(vbox, "Is Purchasable", "is_purchasable")
	_add_checkbox_field(vbox, "Is Limited", "is_limited")
	_add_checkbox_field(vbox, "Is New", "is_new")
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Add action buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_2"))
	vbox.add_child(button_container)
	
	# Save button
	var save_button = Button.new()
	save_button.text = "Save Item"
	save_button.pressed.connect(_save_current_item)
	UIStyleManager.apply_button_style(save_button, "primary", "medium")
	button_container.add_child(save_button)
	
	# Export PNG button
	var export_button = Button.new()
	export_button.text = "Export PNG"
	export_button.pressed.connect(_export_current_item_png)
	UIStyleManager.apply_button_style(export_button, "secondary", "medium")
	button_container.add_child(export_button)

func _add_property_field(parent: Node, label_text: String, property: String, editable: bool = true, multiline: bool = false, type: String = "text"):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_2"))
	parent.add_child(hbox)
	
	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 120
	UIStyleManager.apply_label_style(label, "body_small")
	hbox.add_child(label)
	
	# Input field
	var input: Control
	if multiline:
		input = TextEdit.new()
		input.custom_minimum_size.y = 60
		input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	else:
		input = LineEdit.new()
	
	if selected_item.get(property) != null:
		input.text = str(selected_item.get(property))
	
	input.editable = editable
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Store reference for saving
	input.set_meta("property_name", property)
	input.set_meta("property_type", type)
	
	hbox.add_child(input)

func _add_enum_field(parent: Node, label_text: String, property: String, enum_type):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_2"))
	parent.add_child(hbox)
	
	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 120
	UIStyleManager.apply_label_style(label, "body_small")
	hbox.add_child(label)
	
	# Dropdown
	var dropdown = OptionButton.new()
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add enum options
	var current_value = selected_item.get(property)
	for i in range(enum_type.size()):
		var option_name = enum_type.keys()[i]
		dropdown.add_item(option_name)
		if i == current_value:
			dropdown.selected = i
	
	# Store reference for saving
	dropdown.set_meta("property_name", property)
	dropdown.set_meta("property_type", "enum")
	
	hbox.add_child(dropdown)

func _add_checkbox_field(parent: Node, label_text: String, property: String):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", UIStyleManager.get_spacing("space_2"))
	parent.add_child(hbox)
	
	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 120
	UIStyleManager.apply_label_style(label, "body_small")
	hbox.add_child(label)
	
	# Checkbox
	var checkbox = CheckBox.new()
	checkbox.button_pressed = selected_item.get(property) == true
	
	# Store reference for saving
	checkbox.set_meta("property_name", property)
	checkbox.set_meta("property_type", "bool")
	
	hbox.add_child(checkbox)

func _save_current_item():
	if not selected_item:
		print("No item selected to save")
		return
	
	# Update item properties from UI
	var vbox = property_editor.get_child(0)
	for child in vbox.get_children():
		if child is HBoxContainer:
			for control in child.get_children():
				if control.has_meta("property_name"):
					var prop_name = control.get_meta("property_name")
					var prop_type = control.get_meta("property_type")
					
					if control is LineEdit or control is TextEdit:
						var value = control.text
						if prop_type == "number":
							value = int(value) if value.is_valid_int() else 0
						selected_item.set(prop_name, value)
					elif control is OptionButton:
						selected_item.set(prop_name, control.selected)
					elif control is CheckBox:
						selected_item.set(prop_name, control.button_pressed)
	
	# Save to file
	var save_path = _get_item_save_path(selected_item)
	var result = ResourceSaver.save(selected_item, save_path)
	
	if result == OK:
		print("✓ Saved: %s to %s" % [selected_item.display_name, save_path])
	else:
		print("✗ Failed to save: %s" % selected_item.display_name)

func _get_item_save_path(item: UnifiedItemData) -> String:
	var category_folder = ""
	match item.category:
		UnifiedItemData.Category.CARD_BACK: category_folder = "card_backs"
		UnifiedItemData.Category.CARD_FRONT: category_folder = "card_fronts"
		UnifiedItemData.Category.BOARD: category_folder = "boards"
		UnifiedItemData.Category.MINI_PROFILE_CARD: category_folder = "mini_profile_cards"  # NEW
		UnifiedItemData.Category.FRAME: category_folder = "frames"
		UnifiedItemData.Category.AVATAR: category_folder = "avatars"
		_: category_folder = "misc"
	
	return "res://Pyramids/resources/items/%s/%s.tres" % [category_folder, item.id]

func _export_current_item_png():
	if not selected_item:
		print("No item selected to export")
		return
	
	# Check if it's a procedural item
	if ProceduralItemRegistry.procedural_items.has(selected_item.id):
		var procedural_data = ProceduralItemRegistry.procedural_items[selected_item.id]
		var instance = procedural_data.instance
		
		if instance.has_method("export_to_png"):
			print("Exporting %s to PNG..." % selected_item.display_name)
			await instance.export_to_png()
			print("✓ Export complete")
			
			# Refresh preview to show the new PNG
			_show_preview()
	else:
		print("Item %s is not procedural, cannot export PNG" % selected_item.display_name)

func _generate_all_tres():
	print("Generating .tres files for all procedural items...")
	ProceduralItemRegistry.generate_tres_files_for_all()
	
	# Reload to show the new items
	_reload_item_manager()
	refresh_all()
