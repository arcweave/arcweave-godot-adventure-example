class_name ClickableObject
extends Area2D

# Emitted when the player clicks on the object. Main connects to it when loading the room.
signal object_clicked(clicked_object : ClickableObject)

# The object's name, as it appears in the command line:
@export var object_name: String = ""
# The objectName as it appears in the Arcweave component:
@export var reply_id: String = ""
# The Arcweave variable associated with the object's state (it begins with "i_")
@export var state_variable: String = ""

# The UI & dialogue states are stored in a separate resource file, for global access:
var state_handler : StateHandler = preload("res://resources/state_handler.tres")

# Every clickable object has a position where the player stands to interact with it:
@onready var approachPosition : Marker2D = $ApproachPosition

var mouse_over : bool = false


func _on_mouse_entered() -> void:
	mouse_over = true


func _on_mouse_exited() -> void:
	mouse_over = false


func _input(event: InputEvent) -> void:
	# If in dialogue state, we don't want the ClickableObject to pick up events:
	if state_handler.game == state_handler.DIALOGUE:
		return

	if event.is_action_pressed("click") and mouse_over:
		get_viewport().set_input_as_handled()
		# ... otherwise, the click gets also caught by unhandled input.
		object_clicked.emit(self)
