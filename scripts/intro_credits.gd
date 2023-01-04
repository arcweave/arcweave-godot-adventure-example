extends Control

enum {PLAY, QUIT}
const SAVED_GAME_PATH = "user://save.dat"
onready var timer : Timer = $ButtonTimer
onready var load_button : Button = $Buttons/Load
var command : int = PLAY


func _ready() -> void:
	enable_load(check_save_file())


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


func go(new_command : int = PLAY) -> void:
	command = new_command
	timer.start()

func _on_NewGame_pressed() -> void:
	go()
	

func _on_Load_pressed() -> void:
	LoadGame.load_game = true
	go()


func _on_Quit_pressed() -> void:
	go(QUIT)


func _on_ButtonTimer_timeout() -> void:
	match command:
		PLAY:
			var _change = get_tree().change_scene("res://scenes_main/Main.tscn")
		QUIT:
			get_tree().quit()
	


func _on_Credits_pressed() -> void:
	$FlipSide.visible = !$FlipSide.visible
	$FrontSide.visible = !$FrontSide.visible
	$Buttons/Main.visible = !$Buttons/Main.visible
	$Buttons/Credits.visible = !$Buttons/Credits.visible
