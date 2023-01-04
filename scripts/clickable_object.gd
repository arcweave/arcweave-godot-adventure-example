class_name ClickableObject
extends Area2D

export(String) var object_name = ""
export(String) var reply_id = ""
export(String) var state_variable = ""

# The UI & dialogue states are stored in a separate resource file, for global access:
var state_handler = preload("res://resources/state_handler.tres")

onready var approachPosition = $ApproachPosition

#signal mouse_in(aNode)
signal object_clicked(aNode)

var mouse_over : bool = false


func _ready() -> void:
	var _con : int = 0
	yield(get_tree(), "idle_frame") # Needing this for signalling.
#	_con = self.connect("mouse_in", get_tree().current_scene, "_on_object_mouse_in")
#	_con = self.connect("mouse_exited", get_tree().current_scene, "_on_object_mouse_exited")
	_con = self.connect("object_clicked", get_tree().current_scene, "_on_ClickableObject_clicked")
	

func _on_mouse_entered() -> void:
	mouse_over = true
#	emit_signal("mouse_in", self)


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
