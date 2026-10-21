extends Control

@onready var cursorSprite : Sprite2D = $Cursor

var mouse_over_game : bool = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_ENTER:
		mouse_over_game = true
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		mouse_over_game = false


func _process(_delta: float) -> void:
	# The game draws its own cursor sprite, so it hides the system cursor
	# while the mouse is over the game window:
	var mouse_mode := Input.MOUSE_MODE_HIDDEN if mouse_over_game else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mouse_mode:
		Input.mouse_mode = mouse_mode
	if mouse_over_game:
		# Global, so the cursor follows the mouse wherever this node is placed.
		# (In the settings popup, "global" means within the popup's own window.)
		cursorSprite.global_position = get_global_mouse_position()
