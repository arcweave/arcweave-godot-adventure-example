extends Control

signal restart

enum {REPLAY, QUIT}
enum {EXPLORING, WALKING_TO_ACTION, TRANSITIONING, DIALOGUE} # GAME states

const State : Resource = preload("res://resources/state_handler.tres") # The game's state machines. Not the story state.
const SAVED_GAME_PATH = "user://save.dat"

var command : int = REPLAY

onready var popup_menu : Popup = $Popup
onready var music_slider : HSlider = $Popup/MarginContainer/VBoxContainer/MusicRow/MusicSlider
onready var sfx_slider : HSlider = $Popup/MarginContainer/VBoxContainer/SFXRow/SFXSlider
onready var load_button : Button = $Popup/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/Load

func _unhandled_input(event: InputEvent) -> void:
	if State.game == TRANSITIONING:
		# Sorry, no menu popping up while transitioning rooms.
		return
		
	if event.is_action_pressed("ui_menu"):
		if popup_menu.visible:
			hide_popup()
			return
		
		enable_load(check_save_file())
		popup_menu.popup()
		get_tree().paused = true



func check_save_file()->bool:
	var file = File.new()
	if file.file_exists(SAVED_GAME_PATH):
		return true
	return false


func enable_load(yes: bool)->void:
	if yes:
		load_button.disabled = false
		return
	load_button.disabled = true


func hide_popup() -> void:
	popup_menu.visible = false
	get_tree().paused = false


func go(new_command : int = REPLAY):
	command = new_command
	$CommandTimer.start()


func _on_Load_pressed() -> void:
	LoadGame.load_game = true
	go()


func _on_Quit_pressed() -> void:
	go(QUIT)


func _on_CommandTimer_timeout() -> void:
	hide_popup()
	match command:
		REPLAY:
			emit_signal("restart")
		QUIT:
			var _change = get_tree().change_scene("res://scenes_main/IntroCredits.tscn")


func _on_Save_pressed() -> void:
	enable_load(check_save_file())
