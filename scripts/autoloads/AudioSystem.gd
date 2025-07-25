# AudioSystem.gd - Autoload for game audio management
extends Node

# === AUDIO PLAYERS ===
var sfx_players: Array[AudioStreamPlayer] = []
var current_player_index: int = 0
const MAX_CONCURRENT_SOUNDS: int = 8

# === SOUND EFFECTS DATABASE ===
var sound_effects: Dictionary = {}

# === SOUND GROUPS ===
var sound_groups: Dictionary = {
	"card_draw": ["CardDraw1", "CardDraw2", "CardDraw3"],
	"error": ["Error1", "Error2", "Error3"],
	"peak_clear": ["PeakClear1", "PeakClear2"]
}

func _ready() -> void:
	print("AudioSystem initializing...")
	_create_audio_players()
	_load_sound_effects()
	_connect_signals()
	print("AudioSystem initialized with %d sounds" % sound_effects.size())

func _create_audio_players() -> void:
	# Create multiple AudioStreamPlayer nodes for concurrent sounds
	for i in range(MAX_CONCURRENT_SOUNDS):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		sfx_players.append(player)

func _load_sound_effects() -> void:
	# Load all sound effects from the soundeffects folder
	var sound_files = {
		"CardDraw1": "res://Magic-Castle/assets/sound/soundeffects/CardDraw1.wav",
		"CardDraw2": "res://Magic-Castle/assets/sound/soundeffects/CardDraw2.wav", 
		"CardDraw3": "res://Magic-Castle/assets/sound/soundeffects/CardDraw3.wav",
		"Connect": "res://Magic-Castle/assets/sound/soundeffects/Connect.wav",
		"Error1": "res://Magic-Castle/assets/sound/soundeffects/Error1.wav",
		"Error2": "res://Magic-Castle/assets/sound/soundeffects/Error2.wav",
		"Error3": "res://Magic-Castle/assets/sound/soundeffects/Error3.wav",
		"PeakClear1": "res://Magic-Castle/assets/sound/soundeffects/PeakClear1.wav",
		"PeakClear2": "res://Magic-Castle/assets/sound/soundeffects/PeakClear2.wav",
		"SadTrombone": "res://Magic-Castle/assets/sound/soundeffects/SadTrombone.wav",
		"Success": "res://Magic-Castle/assets/sound/soundeffects/Success.wav",
		"WinScreen1": "res://Magic-Castle/assets/sound/soundeffects/WinScreen1.wav",
		"WinScreen2": "res://Magic-Castle/assets/sound/soundeffects/WinScreen2.wav"
	}
	
	for sound_name in sound_files:
		var sound_path = sound_files[sound_name]
		var audio_stream = load(sound_path)
		if audio_stream:
			sound_effects[sound_name] = audio_stream
			print("Loaded sound: %s" % sound_name)
		else:
			print("Failed to load sound: %s at %s" % [sound_name, sound_path])

func _connect_signals() -> void:
	# Connect to game events
	SignalBus.card_selected.connect(_on_card_selected)
	SignalBus.card_invalid_selected.connect(_on_card_invalid_selected)
	SignalBus.draw_pile_clicked.connect(_on_draw_pile_clicked)
	SignalBus.round_started.connect(_on_round_started)
	SignalBus.round_completed.connect(_on_round_completed)
	SignalBus.sound_setting_changed.connect(_on_sound_setting_changed)

# === SOUND PLAYING ===
func play_sound(sound_name: String, volume_db: float = 0.0) -> void:
	if not SettingsSystem.is_sound_enabled():
		return
		
	if not sound_effects.has(sound_name):
		print("Sound not found: %s" % sound_name)
		return
	
	var player = _get_available_player()
	if player:
		player.stream = sound_effects[sound_name]
		player.volume_db = volume_db
		player.play()

func play_random_from_group(group_name: String, volume_db: float = 0.0) -> void:
	if not sound_groups.has(group_name):
		print("Sound group not found: %s" % group_name)
		return
	
	var sounds = sound_groups[group_name]
	var random_sound = sounds[randi() % sounds.size()]
	play_sound(random_sound, volume_db)

func _get_available_player() -> AudioStreamPlayer:
	# Find the next available player (round-robin)
	for i in range(MAX_CONCURRENT_SOUNDS):
		var player_index = (current_player_index + i) % MAX_CONCURRENT_SOUNDS
		var player = sfx_players[player_index]
		
		if not player.playing:
			current_player_index = (player_index + 1) % MAX_CONCURRENT_SOUNDS
			return player
	
	# All players busy, use the current one (will cut off existing sound)
	var player = sfx_players[current_player_index]
	current_player_index = (current_player_index + 1) % MAX_CONCURRENT_SOUNDS
	return player

# === SIGNAL HANDLERS ===
func _on_card_selected(_card: Control) -> void:
	play_sound("Success", -5.0)  # Quieter as mentioned

func _on_card_invalid_selected(_card: Control) -> void:
	play_random_from_group("error")

func _on_draw_pile_clicked() -> void:
	play_random_from_group("card_draw")

func _on_round_started(_round: int) -> void:
	play_sound("WinScreen1")

func _on_round_completed(_score: int) -> void:
	# Check if board was cleared for win/lose sound
	if GameState.board_cleared:
		play_sound("WinScreen2")
	else:
		play_sound("SadTrombone")

func _on_sound_setting_changed(enabled: bool) -> void:
	print("Sound %s" % ("enabled" if enabled else "disabled"))

# === SPECIAL SOUNDS ===
func play_peak_clear_sound(peak_number: int) -> void:
	if peak_number == 1:
		play_sound("PeakClear1")
	elif peak_number == 2:
		play_sound("PeakClear2")
	# Peak 3 uses win sound instead

func play_lobby_connect_sound() -> void:
	play_sound("Connect")
