class_name ClickableObject
extends Area2D

# The object's name, as it appears in the command line:
export(String) var object_name = ""
# The objectName as it appears in the Arcweave component:
export(String) var reply_id = ""
# The Arcweave variable associated with the object's state (it begins with "i_")
export(String) var state_variable = ""

# The UI & dialogue states are stored in a separate resource file, for global access:
var state_handler = preload("res://resources/state_handler.tres")

# Every clickable object has a position where the player stands to interact with it:
onready var approachPosition = $ApproachPosition

signal object_clicked(aNode)

var mouse_over : bool = false


func _ready() -> void:
	var _con : int = 0
	_con = self.connect("object_clicked", get_tree().current_scene, "_on_ClickableObject_clicked")
	

func _on_mouse_entered() -> void:
	mouse_over = true


func _on_mouse_exited() -> void:
	mouse_over = false


func _input(event: InputEvent) -> void:
	# If in dialogue state, we don't want the ClickableObject to pick up events:
	if state_handler.game == state_handler.DIALOGUE:
		return
		
	if event.is_action_pressed("click") and mouse_over:
		get_tree().set_input_as_handled()
		# ... otherwise, the click gets also caught by unhandled input.
		emit_signal("object_clicked", self)
