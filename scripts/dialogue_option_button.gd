extends Button

# Each option button sends the flow to a target element, with the ID of:
onready var target_id = ""

# Along with the "pressed" signal, we pass the target_id as argument.
func _on_pressed():
	emit_signal("pressed", target_id)
