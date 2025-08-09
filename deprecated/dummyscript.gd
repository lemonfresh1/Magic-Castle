extends Node

@onready var panel: Panel = $Panel
@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var main_menu: Button = $Panel/MarginContainer/HBoxContainer/LeftSection/MainMenu
@onready var timer_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/LeftSection/TimerContainer/TimerBar
@onready var timer_label: Label = $Panel/MarginContainer/HBoxContainer/LeftSection/TimerContainer/TimerLabel
@onready var draw_pile: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/DrawPile
@onready var draw_pile_sprite: TextureRect = $Panel/MarginContainer/HBoxContainer/CenterSection/DrawPile/DrawPileSprite
@onready var draw_pile_label: Label = $Panel/MarginContainer/HBoxContainer/CenterSection/DrawPile/DrawPileLabel
@onready var card_slot_1: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot1
@onready var card_slot_2: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot2
@onready var background: TextureRect = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot2/Background
@onready var combo_countdown_1: Label = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot2/ComboCountdown1
@onready var card_slot_3: Control = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot3
@onready var background2: TextureRect = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot3/Background
@onready var combo_countdown_2: Label = $Panel/MarginContainer/HBoxContainer/CenterSection/CardSlot3/ComboCountdown2
@onready var combo_bar: ProgressBar = $Panel/MarginContainer/HBoxContainer/RightSection/ComboContainer/ComboBar
@onready var combo_label: Label = $Panel/MarginContainer/HBoxContainer/RightSection/ComboContainer/ComboLabel
@onready var pause_button: Button = $Panel/MarginContainer/HBoxContainer/RightSection/PauseButton
