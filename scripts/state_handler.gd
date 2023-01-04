class_name StateHandler
extends Resource

enum {EXPLORING, WALKING_TO_ACTION, TRANSITIONING, DIALOGUE} # GAME states
enum {IDLE, MENU_OPEN, HOLDING_ITEM} # UI states
enum {OFF, RENDERING_ELEMENT, RENDERING_OPTIONS, WAITING_CHOICE, PAUSING} # DIALOGUE states

var game : int = TRANSITIONING
var ui : int = IDLE
var dialogue : int = OFF



func get_game_state_name_from_enum(state : int) -> String:
	# A function to help debugging:
	match state:
		EXPLORING:
			return "EXPLORING"
		WALKING_TO_ACTION:
			return "WALKING_TO_ACTION"
		TRANSITIONING:
			return "TRANSITIONING"
		DIALOGUE:
			return "DIALOGUE"
		_:
			push_error("Undefined game state.")
			return "UNDEFINED"


func get_ui_state_name_from_enum(state : int) -> String:
	# A function to help debugging:
	match state:
		IDLE:
			return "IDLE"
		MENU_OPEN:
			return "MENU_OPEN"
		HOLDING_ITEM:
			return "HOLDING_ITEM"
		_:
			push_error("Undefined game state.")
			return "UNDEFINED"


func get_dialogue_state_name_from_enum(state : int) -> String:
	# A function to help debugging:
	match state:
		OFF:
			return "OFF"
		RENDERING_ELEMENT:
			return "RENDERING_ELEMENT"
		RENDERING_OPTIONS:
			return "RENDERING_OPTIONS"
		WAITING_CHOICE:
			return "WAITING_CHOICE"
		_:
			push_error("Undefined dialogue state: " + str(state))
			return "UNDEFINED"
