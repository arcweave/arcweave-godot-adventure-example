extends Button


func _on_UIButton_pressed() -> void:
	$ClickPlayer.play()


func _on_UIButton_mouse_entered() -> void:
	if disabled:
		return
	$HoverPlayer.play()


func _on_UIButton_mouse_exited() -> void:
	if disabled:
		return
	$HoverOutPlayer.play()
