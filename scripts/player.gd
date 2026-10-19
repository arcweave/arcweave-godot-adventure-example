extends Node2D

# Emitted when the player reaches the end of the path set by walk_along().
signal arrived

enum {IDLE, WALK}

@export var speed : float = 14.0
@export var objectName: String = "you"

var path := PackedVector2Array()
var state = IDLE

@onready var animationPlayer : AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = $Sprite2D
@onready var bubble : Node2D = $Bubble
@onready var characterLines : Label = $Bubble/CharacterLines


func _ready() -> void:
	set_process(false)
	animationPlayer.play("Idle")


func _process(delta: float) -> void:
	var distance_in_one_frame : float = speed * delta
	move_along_path(distance_in_one_frame)


func walk_along(new_path: PackedVector2Array) -> void:
	path = new_path
	if path.size() > 0:
		path.remove_at(0) # Removing the first point = the player's starting position.
	# Even with an empty path we switch to WALK, so that _process() emits
	# "arrived" on the next frame.
	change_state(WALK)


func move_along_path(distance_in_one_frame: float) -> void:
	var start_point : Vector2 = global_position
	while path.size() > 0:
		var distance_to_next : float = start_point.distance_to(path[0])
		if distance_in_one_frame <= distance_to_next:
			global_position = start_point.lerp(path[0], distance_in_one_frame / distance_to_next)
			return
		distance_in_one_frame -= distance_to_next
		start_point = path[0]
		# we remove the path[0], so that the next path point becomes the new path[0]
		path.remove_at(0)
	global_position = start_point
	change_state(IDLE)
	arrived.emit()


func change_state(newState):
	match newState:
		IDLE:
			animationPlayer.play("Idle")
			set_process(false)
		WALK:
			animationPlayer.play("Walk")
			set_process(true)

	state = newState
