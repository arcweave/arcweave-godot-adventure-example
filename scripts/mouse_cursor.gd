extends Control

onready var cursorSprite : Sprite = $Cursor

var mouse_over_game : bool = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		mouse_over_game = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		mouse_over_game = false


func _process(_delta: float) -> void:
	if mouse_over_game:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		cursorSprite.position = get_global_mouse_position()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
