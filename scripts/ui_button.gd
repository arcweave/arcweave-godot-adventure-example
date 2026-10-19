extends Button

@onready var clickPlayer : AudioStreamPlayer = $ClickPlayer
@onready var hoverPlayer : AudioStreamPlayer = $HoverPlayer


func _on_UIButton_pressed() -> void:
	clickPlayer.play()


func _on_UIButton_mouse_entered() -> void:
	if disabled:
		return
	hoverPlayer.play()
