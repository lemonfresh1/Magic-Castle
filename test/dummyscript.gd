extends Node

@onready var progress_bar: ProgressBar = $VBoxContainer/HeaderContainer/ProgressBar
@onready var progress_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/ProgressLabel
@onready var timer_label: Label = $VBoxContainer/HeaderContainer/ProgressBar/TimerLabel
@onready var level_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/Control/LevelLabel
@onready var free_pass_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/Control2/FreePassLabel
@onready var battle_pass_label: Label = $VBoxContainer/ContentContainer/FixedLabelsContainer/Control3/BattlePassLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ContentContainer/ScrollContainer
@onready var margin_container: MarginContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer
@onready var tiers_container: HBoxContainer = $VBoxContainer/ContentContainer/ScrollContainer/MarginContainer/TiersContainer
@onready var buy_premium_button: Button = $VBoxContainer/ButtonContainer/BuyPremiumButton
@onready var buy_levels_button: Button = $VBoxContainer/ButtonContainer/BuyLevelsButton
@onready var claim_all_button: Button = $VBoxContainer/ButtonContainer/ClaimAllButton
