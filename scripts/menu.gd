extends Control

signal restart
# Main hides its own cursor while the menu is open, and saves the settings when it closes:
signal opened
signal closed

enum {REPLAY, QUIT}
enum {EXPLORING, WALKING_TO_ACTION, TRANSITIONING, DIALOGUE} # GAME states

# The game's state machines. Not the story state.
# A var, not a const: Godot 4 would bake the values of a const resource into the script.
var State : StateHandler = preload("res://resources/state_handler.tres")

var command : int = REPLAY

# A full-screen Control, not a Popup window: a window would get its own viewport,
# which draws blurry (it doesn't use the project's Nearest texture filter) and
# keeps the menu cursor inside it. It covers the whole screen, so clicks outside
# the menu panel don't reach the game's UI (which keeps processing while paused).
@onready var popup_menu : Control = $Popup
@onready var load_button : Button = $Popup/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/Load
@onready var command_timer : Timer = $CommandTimer


func _unhandled_input(event: InputEvent) -> void:
	if State.game == TRANSITIONING:
		# Sorry, no menu popping up while transitioning rooms.
		return

	if event.is_action_pressed("ui_menu"):
		get_viewport().set_input_as_handled()
		if popup_menu.visible:
			hide_popup()
		else:
			show_popup()


func show_popup() -> void:
	update_load_button()
	popup_menu.visible = true
	get_tree().paused = true
	opened.emit()


func update_load_button() -> void:
	load_button.disabled = not LoadGame.save_file_exists()


func hide_popup() -> void:
	popup_menu.visible = false
	get_tree().paused = false
	closed.emit()


func go(new_command : int = REPLAY) -> void:
	command = new_command
	# Instead of instantly GOing, we set a short timer,
	# so we get time to hear the sound effect of the button click:
	command_timer.start()


func _on_Load_pressed() -> void:
	LoadGame.load_game = true
	go()


func _on_Quit_pressed() -> void:
	go(QUIT)


func _on_CommandTimer_timeout() -> void:
	hide_popup()
	match command:
		REPLAY:
			restart.emit()
		QUIT:
			get_tree().change_scene_to_file("res://scenes_main/IntroCredits.tscn")


func _on_Save_pressed() -> void:
	# Main also handles this button and writes the save file. We check
	# after all the handlers have run, so the file exists by then:
	update_load_button.call_deferred()
