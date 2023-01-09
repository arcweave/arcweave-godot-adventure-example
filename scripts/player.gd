extends Node2D

enum{IDLE, WALK}

export var speed : float = 14.0
export var objectName: String = "you"

var path : = PoolVector2Array() setget set_path
var state = IDLE

onready var animationPlayer = $AnimationPlayer
onready var sprite = $Sprite
onready var bubble : Node2D = $Bubble
onready var characterLines : Label = $Bubble/CharacterLines


func _ready() -> void:
	set_process(false)


func _process(delta):
	var distance_in_one_frame : float = speed * delta
	move_along_path(distance_in_one_frame)


func move_along_path(distance_in_one_frame: float) -> void:
	var start_point : Vector2 = position
	while path.size() > 0:
		var distance_to_next : = start_point.distance_to(path[0])
		if distance_in_one_frame <= distance_to_next:
			position = start_point.linear_interpolate(path[0], distance_in_one_frame / distance_to_next)
			return
		distance_in_one_frame -= distance_to_next
		start_point = path[0]
		# we remove the path[0], so that the next path point becomes the new path[0]
		path.remove(0)
	change_state(IDLE)


func change_state(newState):
#	print("Player state changed from " + str(state) + " to " + str(newState))
	match newState:
		IDLE:
			animationPlayer.play("Idle")
			set_process(false)
		WALK:
			animationPlayer.play("Walk")
			set_process(true)
		
	state = newState


func set_path(value: PoolVector2Array) -> void:
	if value.size() == 0:
		return
	path = value
	path.remove(0) # Removing the first point = the player's starting position.
	
