extends Control

signal restart

enum {REPLAY, QUIT}
enum {EXPLORING, WALKING_TO_ACTION, TRANSITIONING, DIALOGUE} # GAME states

# The game's state machines. Not the story state.
# A var, not a const: Godot 4 would bake the values of a const resource into the script.
var State : StateHandler = preload("res://resources/state_handler.tres")

var command : int = REPLAY

@onready var popup_menu : Popup = $Popup
@onready var load_button : Button = $Popup/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/Load
@onready var command_timer : Timer = $CommandTimer


func _ready() -> void:
	# The popup is its own window, so while it is open it receives the input:
	popup_menu.window_input.connect(_on_popup_window_input)
	# The popup can also close itself (e.g. on ui_cancel), so we always unpause here:
	popup_menu.popup_hide.connect(func(): get_tree().paused = false)


func _on_popup_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_menu"):
		hide_popup()
		popup_menu.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if State.game == TRANSITIONING:
		# Sorry, no menu popping up while transitioning rooms.
		return

	if event.is_action_pressed("ui_menu"):
		if popup_menu.visible:
			hide_popup()
			return

		update_load_button()
		popup_menu.popup()
		get_tree().paused = true


func update_load_button() -> void:
	load_button.disabled = not LoadGame.save_file_exists()


func hide_popup() -> void:
	popup_menu.visible = false
	get_tree().paused = false


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
