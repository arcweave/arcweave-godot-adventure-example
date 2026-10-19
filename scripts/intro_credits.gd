extends Control

enum {PLAY, QUIT}
@onready var timer : Timer = $ButtonTimer
@onready var load_button : Button = $Buttons/Load
var command : int = PLAY


func _ready() -> void:
	load_button.disabled = not LoadGame.save_file_exists()


func go(new_command : int = PLAY) -> void:
	command = new_command
	# Instead of instantly GOing, we set a short timer,
	# so we get time to hear the sound effect of the button click:
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
			get_tree().change_scene_to_file("res://scenes_main/Main.tscn")
		QUIT:
			get_tree().quit()
	


func _on_Credits_pressed() -> void:
	$FlipSide.visible = !$FlipSide.visible
	$FrontSide.visible = !$FrontSide.visible
	$Buttons/Main.visible = !$Buttons/Main.visible
	$Buttons/Credits.visible = !$Buttons/Credits.visible
