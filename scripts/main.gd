extends Node2D

# Attention: the following enums must have same names as in the StateHandler resource:
enum {EXPLORING, WALKING_TO_ACTION, TRANSITIONING, DIALOGUE} # GAME states
enum {IDLE, MENU_OPEN, HOLDING_ITEM} # UI states
enum {OFF, RENDERING_ELEMENT, RENDERING_OPTIONS, WAITING_CHOICE, PAUSING} # DIALOGUE states
enum {IN, OUT} # For tween fade() function.

const MAX_NUMBER_VISIBLE_OPTIONS = 3 # Max responses before arrows appear.
const MIN_X = 120 # MIN_X & MAX_X for dialogue bubble placement
const MAX_X = 200
const MIN_Y = 73 # Y for speaker position, for dialogue bubble placement
const MAX_Y = 100 # (The room window lower end.)
const PAUSE_TIME = 1.5 # The time kept when dialogue reaches a "pause" component.
# Mouse Cursors:
const IDLE_CURSOR : Texture = preload("res://assets/assets_ui/cursor_idle.png")
const HOVER_CURSOR : Texture = preload("res://assets/assets_ui/cursor_hover.png")
const EXIT_CURSOR : Texture = preload("res://assets/assets_ui/cursor_walk_out.png")
# Starting room and position:
const FIRST_ROOM : String = "res://scenes_rooms/Bedroom.tscn"
const PLAYER_STARTING_POSITION : Vector2 = Vector2(138, 92)

const DialogueOptionButton : PackedScene = preload("res://scenes_ui/DialogueOptionButton.tscn")
const Inventory : InventoryHandler = preload("res://resources/Inventory.tres")
# The states are stored in a separate resource file, for access by various scripts:
const State : StateHandler = preload("res://resources/state_handler.tres") # The game's state machines. Not the story state.
const SAVED_SETTINGS_PATH = "user://settings.dat"
const SAVED_GAME_PATH = "user://save.dat"
# The following 2 vars get their values from the current room:
var nav2D : Navigation2D = null
var line2D : Line2D = null
# The following vars get values from player actions:
var inventory_item_selected : Item = null
var current_object_hovered : Area2D = null
var current_object_clicked : Area2D = null

var current_target_id : String = "RESET"
var current_line_bubble: Label = null
var player_actions_aw_board : Board = null
# Flags related to dialogue flow:
var dialogue_speed_factor : int = 3 # For faster dialogue go higher.
var dialogue_pause : bool = false
var dialogue_end : bool = false
var line_is_title : bool = false
var overlap_current_line_with_next : bool = false
var just_exit_after_walk : bool = false
var overlapping_data = {}
var follow_random_output : bool = false
var dangling_dialogue : bool = true
var dangling_exit : ClickableExit = null
var current_playlist : Array = []
var command_line : Dictionary = {
	"verb": "",
	"object_1": "",
	"preposition": "",
	"object_2": ""
}
var registered_settings = { # Volumes in linear values (from 0 to 1)
	"music_volume": -80.0,
	"sfx_volume": -80.0,
	"dialogue_speed": 3,
	"walk_speed": 10
}
var number_of_visible_options : int = 0
var option_buttons : Array = []
var story = Story.new() # From Arcweave's plugin.


onready var optionsUI : HBoxContainer = $UI/MarginContainer/OptionsUI
onready var objectsContainer: VBoxContainer = $UI/MarginContainer/ObjectsContainer
onready var objectLabel: Label = $UI/MarginContainer/ObjectsContainer/ObjectName
onready var dialogueTimer: Timer = $DialogueTimer
onready var mouseCursor : Control = $UI/MouseCursor
onready var cursorSprite : Sprite = $UI/MouseCursor/Cursor
onready var player : Node2D = $Player
onready var musicPlayer : AudioStreamPlayer = $UI/MusicPlayer
onready var sfxPlayer : AudioStreamPlayer = $UI/SFXPlayer
onready var tween_room : Tween = $UI/TweenImage
onready var tween_music : Tween = $UI/TweenMusic
onready var inventoryGrid : HBoxContainer = $UI/MarginContainer/ObjectsContainer/InventoryContainer


func push_writer_error(error_text : String):
	push_error("ARCWEAVE WRITER ERROR: " + error_text)

func push_writer_warning(warning_text : String):
	push_warning("ARCWEAVE WRITER WARNING: " + warning_text)


func _ready() -> void:
	load_player_actions_board()
	load_settings()
	check_load_start_game()


# This loads the board where all starting elements are for player commands.
# But I am not currently using it; the game currently iterates through EVERY element.
# For larger games, use for optimisation.
func load_player_actions_board()-> void:
	for board_id in story.boards:
		var board : Board = story.boards[board_id]
		if board.customId == "PLAYER_ACTIONS":
			player_actions_aw_board = board
			return
	push_writer_error("Board with starting elements for all player actions"
		+ " not found. Please, create board with custom Board ID: PLAYER_ACTIONS")


func check_load_start_game()-> void:
	# If there is no command to Load, start a new game:
	if not LoadGame.load_game:
		start_new_game()
		return
	# Else, load the data:
	LoadGame.load_game = false # Reset the load_game var
	load_saved_game()


func load_saved_game() -> void:
	var file = File.new()
	if not file.file_exists(SAVED_GAME_PATH):
		print("Saved game file not found.")
		start_new_game()
		return # Again, start new game.
		
	file.open(SAVED_GAME_PATH, File.READ)
	var data = file.get_var()
	file.close()
	
	story.set_state(data.story_state) # This must go before setCurrentElement
	story.set_current_element(data.element_id)
	dangling_dialogue = data.has_dangling_dialogue
	# Load room and place the player sprite:
	player.sprite.flip_h = data.player_looking_left
	load_room_from_path(data.room_path, data.player_position)
	# Load inventory:
	Inventory.set_inventory_from_paths(data.inventory)
	inventoryGrid.update_inventory_display()
	


func start_new_game()->void:
	load_room_from_path(FIRST_ROOM, PLAYER_STARTING_POSITION)


func save_state()-> void:
	var current_element_id : String = story.get_current_element().id
	var current_story_state : Dictionary = story.get_state()
	var current_room_path : String = get_node_or_null("Location").filename
	var current_player_position: Vector2 = player.global_position
	var current_player_looking_left: bool = player.sprite.flip_h
	var current_inventory : Array = Inventory.get_inventory_paths()
	var current_dangling_dialogue : bool = dangling_dialogue
	
	if State.game == DIALOGUE:
		current_dangling_dialogue = true
		
	var saved_state = {
		"element_id": current_element_id,
		"has_dangling_dialogue": current_dangling_dialogue, # saves the global var
		"story_state": current_story_state,
		"room_path": current_room_path,
		"player_position": current_player_position,
		"player_looking_left": current_player_looking_left,
		"inventory": current_inventory,
	}
	
	print("Saving state: " + str(saved_state))
	
	var file = File.new()
	file.open(SAVED_GAME_PATH, File.WRITE)
	file.store_var(saved_state)
	file.close()


func _unhandled_input(event) -> void:
	match State.game:
		
		EXPLORING:
			if event.is_action_pressed("click"):
				
				# If UI state is not IDLE, we switch to IDLE and return:
				if State.ui == MENU_OPEN or State.ui == HOLDING_ITEM:
					set_ui_state(IDLE)
					return
					
				# Else (if UI is already IDLE), we walk to mouse position:
				walk_player_to(get_global_mouse_position())
				
			if event.is_action_pressed("ui_skip"):
				set_ui_state(IDLE)
			
		WALKING_TO_ACTION:
			if event.is_action_pressed("click"):
				
				# If UI state is not IDLE, we switch to IDLE and return:
				if State.ui == MENU_OPEN or State.ui == HOLDING_ITEM:
					set_ui_state(IDLE)
					return
					
				# Else (if UI is already IDLE), we switch to EXPLORING
				# (thus interrupting the walking with intent and
				# forgetting the object clicked).
				# We walk to the new mouse position:
				walk_player_to(get_global_mouse_position())
#				print("_unhandled_input function, right after walking the player to.")
				set_game_state(EXPLORING)
				
			if event.is_action_pressed("ui_skip"):
				# If UI state is not IDLE, we switch to IDLE:
				if State.ui == MENU_OPEN or State.ui == HOLDING_ITEM:
					set_ui_state(IDLE)
					
				# Contrary to the left click, though, the WALKING_TO_ACTION remains.
				return
		
		TRANSITIONING:
			
			if event.is_action_pressed("click") or event.is_action_pressed("ui_skip"):
#				print("Unhandled click/cancel blocked in TRANSITIONING state.")
				return
				# No mouse events are allowed during the TRANSITIONING state.

		
		DIALOGUE:
			# Here, unhandled click is used as "esc," to skip line of dialogue:
			if State.dialogue == RENDERING_ELEMENT:
				
				if event.is_action_pressed("click") or event.is_action_pressed("ui_skip"):
					skip_dialogue_line()
		
		_:
			push_error("Unhandled input while game in invalid state.")


func save_settings() -> void:
	var file = File.new()
	file.open(SAVED_SETTINGS_PATH, File.WRITE)
#	print("Saving registered settings : " + str(registered_settings))
	file.store_line(to_json(registered_settings))
	file.close()


func load_settings() -> void:
	var file = File.new()
	
	if not file.file_exists(SAVED_SETTINGS_PATH):
		print("Settings file not found.")
		set_volumes_from_linear() # The default values.
		set_dialogue_speed()
		set_walk_speed()
		return
		
	file.open(SAVED_SETTINGS_PATH, File.READ)
	var settings = parse_json(file.get_as_text())
	file.close()
	
	set_volumes_from_linear(settings.music_volume, settings.sfx_volume)
	set_dialogue_speed(settings.dialogue_speed)
	set_walk_speed(settings.walk_speed)


func set_walk_speed(value : float = 18.0)-> void:
	registered_settings.walk_speed = value
	$UI/SettingsMenu/Popup/MarginContainer/VBoxContainer/WalkSpeedRow/WalkSpeedSlider.value = value
	$Player/AnimationPlayer.playback_speed = value * 1.0/10.0
	player.speed = value * 14.0/10.0


func set_dialogue_speed(value: int = 3)-> void:
	registered_settings.dialogue_speed = value
	$UI/SettingsMenu/Popup/MarginContainer/VBoxContainer/DialogueSpeedRow/DialogueSpeedSlider.value = value
	dialogue_speed_factor = value


func set_volumes_from_linear(music_volume : float = 0.65, sfx_volume : float = 0.85):
	# Takes values in dB, so arguments must be already converted with linear2db()
	registered_settings.music_volume = music_volume
	registered_settings.sfx_volume = sfx_volume
	$UI/SettingsMenu/Popup/MarginContainer/VBoxContainer/MusicRow/MusicSlider.value = music_volume
	$UI/SettingsMenu/Popup/MarginContainer/VBoxContainer/SFXRow/SFXSlider.value = sfx_volume
	musicPlayer.volume_db = linear2db(music_volume)
	sfxPlayer.volume_db = linear2db(sfx_volume)


func music_fade(towards : int) -> void:
	var start : float = 0.0
	var end : float = 0.0
	match towards:
		IN:
			start = -80.0
			end = linear2db(registered_settings.music_volume)
		OUT:
			start = linear2db(registered_settings.music_volume)
			end = -80.0
		_:
			push_error("Invalid argument for music_fade function: " + str(towards))
	
	if towards == IN:
		musicPlayer.play()
		
	var _temp = tween_music.interpolate_property (musicPlayer, "volume_db", start, end, 1.0)
	var _temp2 = tween_music.start()


func room_fade(towards : int) -> void:
	var start : Color
	var end : Color
	match towards:
		IN:
			start = Color(0, 0, 0, 1)
			end = Color(0, 0, 0, 0)
		OUT:
			start = Color(0, 0, 0, 0)
			end = Color(0, 0, 0, 1)
		_:
			push_error("Invalid argument for room_fade function: " + str(towards))

	var _temp = tween_room.interpolate_property($UI/Fader, "color", start, end, 1.0)
	var _temp2 = tween_room.start()


func load_room_from_path(room_path : String, player_position : Vector2)-> void:
	set_game_state(TRANSITIONING)
	set_cursor_and_selected_item(null)
	var current_room : Node2D = get_node_or_null("Location")
	var next_room : Node2D = load(room_path).instance()

	if current_room != null:
		room_fade(OUT)
		if musicPlayer.playing and musicPlayer.get_stream() != next_room.music:
			music_fade(OUT)
		yield(tween_room, "tween_completed")
		current_room.queue_free()
		yield(get_tree(), "idle_frame")
		
	dress_up_room(next_room)
	place_player(player_position)
		
	next_room.name = "Location"
	get_tree().current_scene.add_child_below_node($UI, next_room)

	room_fade(IN)
	if musicPlayer.get_stream() != next_room.music:
		musicPlayer.set_stream(next_room.music)
		music_fade(IN)
#	yield(get_tree(), "idle_frame")
	yield(tween_room, "tween_completed")

	nav2D = $Location/Navigation2D
	line2D = $Location/Line2D
	if dangling_dialogue:
		dangling_dialogue = false
		set_game_state(DIALOGUE)
		render_options()
		return
		
	set_game_state(EXPLORING)


func dress_up_room(room_node : Node2D) -> void:
	for obj in room_node.get_node("Objects").get_children():
		if not obj is ClickableObject:
			continue
		if obj.state_variable == "":
			continue
		
		# We first switch them off, then check their state.
		obj.visible = false
		obj.monitorable = false
		
		# We check if the object's var is in the story state:
		if obj.state_variable in story.state.variables:
			# Then check if object is present (our convention: if its var == 1):
			if story.state.get_var(obj.state_variable) == 1:
				obj.visible = true
				obj.monitorable = true


func place_player(new_player_position : Vector2):
	player.global_position = new_player_position


func reset_and_show_cursor() -> void:
	set_cursor(null)
	show_cursor(true)


func show_cursor(yes : bool) -> void:
	if yes:
		cursorSprite.visible = true
	else:
		cursorSprite.visible = false


# Attention: the following function only sets the cursor texture.
# It doesn't check state nor sets the inventory_item_selected:
func set_cursor(item):
	if item is Item:
		# This should happen when clicking on inventory items:
		cursorSprite.texture = item.texture
		return
	if item is ClickableExit:
		# This should happen when hovering over an Clickable Exit:
		cursorSprite.texture = EXIT_CURSOR
		return
	if item is ClickableObject:
		# This should happen when hovering over a ClickableObject
		# other than Clickable Exit:
		cursorSprite.texture = HOVER_CURSOR
		return
	if item == null:
		# This resets the cursor:
		cursorSprite.texture = IDLE_CURSOR
		return
	push_error("Unknown argument for set_cursor function.")


func set_game_state(new_state):
	if not dialogueTimer.is_stopped():
		print("dialogueTimer is currently running due to previous dialogue actions.")
		if new_state != DIALOGUE:
			print("Ubruptly stopping dialogueTimer, due to game state changing to other than DIALOGUE.")
			dialogueTimer.stop()
		
	match new_state:
		EXPLORING:
			disable_cursor_collisions(false)
			optionsUI.visible = false
			objectsContainer.visible = true
			reset_and_show_cursor()
		
		WALKING_TO_ACTION:
			reset_and_show_cursor()
			if State.ui == MENU_OPEN:
				set_ui_state(IDLE)
		
		TRANSITIONING:
			show_cursor(false)
			if State.ui == MENU_OPEN:
				set_ui_state(IDLE)
			optionsUI.visible = false
			objectsContainer.visible = false
		
		DIALOGUE:
			set_ui_state(IDLE)
			disable_cursor_collisions()
			objectsContainer.visible = false
			
		_:
			push_error("Attempt to assign invalid game state.")
			return
		
	if State.game != new_state:
		State.game = new_state


func disable_cursor_collisions(yes: bool = true)->void:
	$UI/MouseCursor/Cursor/MouseCursorArea2D/MouseCursorCollision.disabled = yes


func set_ui_state(new_state):
	
	match new_state:
		
		IDLE:
			open_mouse_menu(false)
			if not State.game == WALKING_TO_ACTION:
				erase_command_line()
#			current_object_clicked = null
		
		MENU_OPEN:
			if current_object_clicked == null and inventory_item_selected == null:
				push_error("SET UI STATE(MENU_OPEN): object/item clicked is NULL.")
				return
			open_mouse_menu(true)
			command_line.object_1 = current_object_clicked.object_name
			update_command_line()
		
		HOLDING_ITEM:
			open_mouse_menu(false)
#			current_object_clicked = null
		
		_:
			push_error("Attempt to assign invalid ui state.")
			return
	
	if State.ui != new_state:
		State.ui = new_state


func set_dialogue_state(new_state):
	if State.game != DIALOGUE:
#		print("Set Dialogue State forcing game state from " 
#			+ state.get_game_state_name_from_enum(state.game) + " to DIALOGUE.")
		set_game_state(DIALOGUE)
	
	match new_state:
		
		OFF:
			reset_and_show_cursor()
		
		RENDERING_ELEMENT:
			show_cursor(false)
			optionsUI.visible = false
		
		RENDERING_OPTIONS:
			show_cursor(false)
			optionsUI.visible = false
		
		WAITING_CHOICE:
			reset_and_show_cursor()
			optionsUI.visible = true
			
		PAUSING:
			show_cursor(false)
			optionsUI.visible = false
			
		_:
			push_error("Attempt to assign invalid dialogue state: " + str(new_state))
			return

	if State.dialogue != new_state:
		State.dialogue = new_state


# This function sets the cursor and the inventory_item_selected
# or nulls both if item == null:
func set_cursor_and_selected_item(item) -> void:
	inventory_item_selected = item
	set_cursor(item)


func open_mouse_menu(true_false : bool) -> void:
	var mouse_menu : Node2D = $UI/MouseMenu
	mouse_menu.position = get_global_mouse_position()
	mouse_menu.visible = true_false


func erase_command_line():
	objectLabel.text = ""
	command_line.verb = ""
	command_line.object_1 = ""
	command_line.preposition = ""
	command_line.object_2 = ""


func update_command_line():
	# For later improvements: make "Walk to" as the default.
	objectLabel.text = ""
	objectLabel.text +=       command_line.verb
	objectLabel.text += " " + command_line.object_1
	objectLabel.text += " " + command_line.preposition
	objectLabel.text += " " + command_line.object_2


func walk_player_to(a_position: Vector2):
	var source_position = player.global_position
	var target_position = a_position
	
	orient_player_towards(target_position)
	
	var new_path = nav2D.get_simple_path(source_position, target_position)
	line2D.points = new_path
	player.path = new_path
	player.change_state(1) # WALK


func skip_dialogue_line():
	dialogueTimer.stop()
	after_timer_do()


func orient_player_towards(position_of_interest: Vector2):
	if position_of_interest.x < player.global_position.x:
		player.sprite.flip_h = true
	else:
		player.sprite.flip_h = false


func start_dialogue(element_id: String) -> void:
	set_game_state(DIALOGUE)
	set_cursor_and_selected_item(null)
	render_element(element_id)


func act(target_id : String) -> void:
	current_target_id = target_id

	if State.game == WALKING_TO_ACTION:
		walk_player_to(current_object_clicked.approachPosition.global_position)
		return
	# The following stops the player if walking, eg. to examine a character.
	# As a convention, we still set state to WALKING_TO_ACTION,
	# although we stop the player on the spot.
	# Function _on_Player_animation_finished checks the WALKING_TO_ACTION state
	# and must get it right, regardless.
	set_game_state(WALKING_TO_ACTION)
	walk_player_to(player.global_position)


func render_element(element_id : String) -> void:
	set_dialogue_state(RENDERING_ELEMENT)
	
	var _current_element : Element = story.set_current_element(element_id)
	render_current_element()

func select_option(option: Dictionary) -> void:
	set_dialogue_state(RENDERING_ELEMENT)
	story.select_option(option)
	
	render_current_element()

func render_current_element() -> void:
	var current_element : Element = story.get_current_element()
	var current_content : String = story.get_current_content().strip_edges()
	var components_classified : Dictionary = classify_components(current_element)
	
	if components_classified.dialogue_commands.size() > 0:
		run_dialogue_commands(components_classified.dialogue_commands)

	if current_content != "":
		if current_object_clicked is ClickableObject:
			# We have included a wildcard for repeating the clicked object's name
			# within the dialogue: "$##$" therefore, we replace this with the name:
			current_content = current_content.replace("$##$", current_object_clicked.object_name)
		run_content(components_classified.speakers, current_content)
	
	if components_classified.animations.size() > 0:
		play_dialogue_animation(components_classified.animations)

	if components_classified.audios.size() > 0:
		current_playlist = components_classified.audios
		play_next_from_playlist()

	# Note: activities come after content rendering, so they take into consideration
	# any value changes in arcscript.
	if components_classified.activities.size() > 0:
		# Some activities (like ADD TO INVENTORY) need items, others (like END GAME don't).
		run_activities(components_classified.activities, components_classified.items, components_classified.exits)
	
	if dialogueTimer.is_stopped():
		dialogueTimer.wait_time = 0.001
		dialogueTimer.start()


func run_activities(activities : Array, items : Array, exits : Array) -> void:
	
	for activity in activities:
		var activityName : String = activity.get_attribute_by_name("objectName").value.data
		
		match activityName:
			"endGame":
				end_game()
				break
				
			"inventoryAdd":
				activity_inventory_add(items)
				
			"inventoryRemove":
				activity_inventory_remove(items)
				
			"exitThrough":
				activity_exit_through(exits)
				
			_:
				push_writer_error("Unknown activity component objectName: " + activityName)


func activity_exit_through(exits : Array) -> void:
	
	if exits.size() != 1:
		push_writer_error("Exactly 1 exit should be paired with exitThrough component. Found " 
			+ str(exits.size()) + " instead. (Element ID: " + story.get_current_element().id + ")")
		return

	var exit : ClickableExit = get_exit_node_from_component(exits[0])
	
	dangling_exit = exit
	dangling_dialogue = true


func exit_room_from(exitNode : ClickableExit):
	# Note: the WALKING_TO_ACTION game state must be set outside this function:
	var next_room_path : String = exitNode.target_room
	var next_player_position : Vector2 = exitNode.target_position
	current_object_clicked = null
	load_room_from_path(next_room_path, next_player_position)


func end_game():
	set_game_state(TRANSITIONING)
	music_fade(OUT)
	room_fade(OUT)
	yield(tween_room, "tween_completed")
	var _change = get_tree().change_scene("res://scenes_main/IntroCredits.tscn")


func activity_inventory_add(items_components : Array) -> void:
	for item in items_components:
		var item_objectName : String = item.get_attribute_by_name("objectName").value.data.strip_edges()
		var new_item : Resource = load("res://resources/" + item_objectName + ".tres")
		
		for i in Inventory.items.size():
			if Inventory.items[i] == null:
				Inventory.items[i] = new_item
				break
		
		dress_up_room(get_node("Location"))
		inventoryGrid.update_inventory_display()


func activity_inventory_remove(items_components : Array) -> void:
	for item in items_components:
		var item_objectName : String = item.get_attribute_by_name("objectName").value.data.strip_edges()
		var item_to_remove : Resource = load("res://resources/" + item_objectName + ".tres")
		
		for i in Inventory.items.size():
			if Inventory.items[i] == item_to_remove:
				Inventory.items.pop_at(i) # Pops the item, moving the next ones one slot to start of array.
				Inventory.items.append(null) # Adds an empty slot at end, so there is a "null" value.
				break
		
		inventoryGrid.update_inventory_display()


func run_content(speakers : Array, content: String) -> void:
	if overlap_current_line_with_next:
		overlapping_data.speakers = speakers
		overlapping_data.content = content
		overlap_current_line_with_next = false
		return
		
	# Assigns content to speakers or title.
	set_dialogue_state(RENDERING_ELEMENT)
	
	# Title bypasses speakers.
	if line_is_title:
		line_is_title = false
		render_title(content)
		return
	
	var speakers_nodes : Array = get_speakers_nodes(speakers)
	render_speech(speakers_nodes, content)
	
	if not overlapping_data.empty():
		var overlapping_speakers_nodes : Array = get_speakers_nodes(overlapping_data.speakers)
		if not overlapping_data.speakers is Array or not overlapping_data.content is String:
			push_writer_error("Check overlapping error with content: " + content)
			return
		render_speech(overlapping_speakers_nodes, overlapping_data.content)
		overlapping_data.clear()


func get_speakers_nodes(speakers_components : Array) -> Array:
	var speakers_nodes : Array = []
	for speaker_component in speakers_components:
		# We store the speaker's 'objectName' and hexColour.
		var objectName : String = speaker_component.get_attribute_by_name("objectName").value.data
		var colour : String = speaker_component.get_attribute_by_name("hexColour").value.data

		var speaker_node : Node = get_speaker_node_by_name(objectName)
		speaker_node.bubble.characterLines.modulate = Color(colour)
		speakers_nodes.append(speaker_node)
		
	return speakers_nodes


func get_exit_node_from_component(exit_component : Component)-> ClickableExit:
	for exit_node in get_node("Location/Objects").get_children():
		if not exit_node is ClickableExit:
			continue
		if exit_node.get("reply_id") == null:
			continue
		var exit_objectName : String = exit_component.get_attribute_by_name("objectName").value.data
		if exit_node.get("reply_id") == exit_objectName:
			return exit_node
	
	push_writer_error("Can't find tree node for exit " + exit_component.name)
	return null


func get_speaker_node_by_name(component_objectName : String) -> Node:
	# First check if it's the player:
	if component_objectName == player.objectName:
		return player
	
	for n in get_node("Location/Objects").get_children():
		if not n is Area2D:
			continue
		if n.get("reply_id") == null:
			continue
		if n.get("reply_id") == component_objectName:
			return n
			
	push_writer_error("Can't find tree node for speaker component with objectName: " + component_objectName)
	return null


func render_title(text : String):
	$UI/Title/Label.text = text
	dialogueTimer.wait_time = get_line_reading_time(text)
	dialogueTimer.start()


func get_line_reading_time(text : String) -> float:
	var number_of_characters : int = text.length()
	var line_reading_time : float = 1.0
	
	if number_of_characters > 0:
		line_reading_time = 10.0/dialogue_speed_factor * max((number_of_characters * 0.03), 0.8)
		
	return line_reading_time


func render_speech(speakers_nodes : Array, content: String) -> void:
	var number_of_lines : int = 0
	
	for speaker in speakers_nodes:
		speaker.bubble.characterLines.text = content
		speaker.bubble.characterLines.align = 1 # Default alignment: CENTER
		yield(get_tree(), "idle_frame")
		# The yielding is needed because Godot needs to draw the label with the current text,
		# for at least 1 frame, to return data like get_line_count() etc.
		# Assignment happens in every iteration, but how many speakers are you gonna get anyway?
		number_of_lines = speaker.bubble.characterLines.get_line_count()
	
		# Positioning the talking bubble, depending on the position of its speaker.
		speaker.bubble.global_position.x = clamp(speaker.global_position.x, MIN_X, MAX_X)
		if speaker.global_position.x < MIN_X - 35:
			speaker.bubble.characterLines.align = 0 # Aligning LEFT
		elif speaker.global_position.x > MAX_X + 35:
			speaker.bubble.characterLines.align = 2 # Aligning RIGHT
	
		if number_of_lines >= 3:
			speaker.bubble.global_position.y = max(speaker.global_position.y, 95)
			if number_of_lines > 3:
				push_writer_error("Dialogue with more than 3 lines does not fit in the screen: " + content)
		elif number_of_lines == 2:
			speaker.bubble.global_position.y = max(speaker.global_position.y, 84)
		else:
			speaker.bubble.global_position.y = speaker.global_position.y
			if number_of_lines < 1:
				push_writer_error("This dialogue has no lines.")
				# Given that we've already checked content != "" in render_element(),
				# we won't reach this error.
	
#		1 line : normal (from MIN_Y to MAX_Y)
#		2 lines: min_y >= 84
#		3 lines: min_y >= 95
	
	var line_reading_time : float = get_line_reading_time(content)
	dialogueTimer.wait_time = line_reading_time
	dialogueTimer.start()


func define_option_txt(option : Dictionary) -> String:
	# This function returns the text that will appear as option for the player:
	var final_option_text : String = "PLACEHOLDER TEXT"
	var target_element : Element = story.elements[option.targetid]
	
	# Just in case no label gets found, we start by using the target's title:
	if target_element.title.strip_edges() != "":
		final_option_text = target_element.title
	# We now check for labels along the way--the connectionPath:
	for connection in option.connectionPath:
		if connection.label:
			final_option_text = connection.label
	# If no label or title exists, we gotta throw a writer error,
	# while the game renders "PLACEHOLDER TEXT" as option text.
	if final_option_text == "PLACEHOLDER TEXT":
		push_writer_error("PLACEHOLDER TEXT used for option. Consider adding labels along the way or a title to target element with ID: " + option.targetId)
	
	return final_option_text


func render_options() -> void:
	if State.game != DIALOGUE:
		set_game_state(DIALOGUE)
	set_dialogue_state(RENDERING_OPTIONS)

	var options : Array = story.get_current_options()
	# If the element has no valid outputs, end the dialogue:
	if options.empty() or dialogue_end:
		_end_dialogue()
		return
	
	# If the element has only one valid output, follow it immediately:
	if options.size() == 1:
		select_option(options[0])
		return
		
	# If a "follow random" component exists, follow a random output:
	if follow_random_output:
		follow_random_output = false
		var random_index : int = randi() % options.size()
		select_option(options[random_index])
		return
		
	# Otherwise, we create a button for each option:
	for option in options:
		var option_text : String = define_option_txt(option)
		create_option_button(option_text, option)
	
	# More than MAX_NUMBER_VISIBLE_OPTIONS require arrow buttons, to scroll:
	var option_arrows : VBoxContainer = $UI/MarginContainer/OptionsUI/OptionsArrows
	number_of_visible_options = options.size()
	if number_of_visible_options > MAX_NUMBER_VISIBLE_OPTIONS:
		option_arrows.visible = true
		$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonDn.disabled = false
	else:
		option_arrows.visible = false
		$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonDn.disabled = true

	set_dialogue_state(WAITING_CHOICE)


func create_option_button(option_txt, option):
	var option_button : Button = DialogueOptionButton.instance()
	option_button.text = option_txt
	option_button.target_id = option.targetid
	var _temp : int = option_button.connect("pressed", self, "_on_option_button_pressed", [option])
	$UI/MarginContainer/OptionsUI/OptionsContainer.add_child(option_button)
	option_buttons.append(option_button)


func classify_components(element : Element) -> Dictionary:
	# The attached components will be classified as follows:
	var speakers : Array = []
	var items : Array = []
	var exits : Array = []
	var activities : Array = [] # Activities like "add something to inventory" or "End game."
	var animations : Array = []
	var audios : Array = []
	var dialogue_commands : Array = []

	# ... and then this function will return this Dictionary:
	var components_classified : Dictionary = {
		"speakers": speakers,
		"items": items,
		"exits": exits,
		"activities": activities,
		"animations": animations,
		"audios": audios,
		"dialogue_commands": dialogue_commands
	}
	
	# We get an array of all the attached components (Dictionaries):
	var components : Array = element.components
	# Iterate through the element's attached components:
	for component in components:
		if component.attributes.empty():
			push_writer_error("No attributes found in component: " + component.name)
			continue # go to the next component.
		
		# Finding the component's "type". 
		# "Type" is a custom attribute the Arcweave writer has assigned to components.
		# The following array is to eventually check the component has only one type:
		var component_types : Array = [] # It must have only one member eventually.
		
		# Iterate through the component's attributes:
		for attribute_id in component.attributes:
			var attribute : Dictionary = component.attributes[attribute_id]
			
			if attribute.name == "type":
				
				match attribute.value.data:
					
					"character":
						speakers.append(component)
			
					"item":
						items.append(component)
				
					"activity":
						activities.append(component)
				
					"animation":
						animations.append(component)
					
					"audio":
						audios.append(component)
						
					"dialogueFlow":
						dialogue_commands.append(component)
						
					"exit":
						exits.append(component)
						
					"actionVerb":
						pass
						
					_:
						push_writer_error("Unknown type found for component: " + component.name)
				
				component_types.append(attribute.value.data)

		if component_types.size() == 0:
			push_writer_error("No 'type' attribute in component: " + component.name)

		if component_types.size() > 1:
			push_writer_error("More than 1 'type' attributes :" + str(component_types) + " in component: " + component.name)
		# Attention: after the error, we still have the problematic component classified in multiple types.
		
	return components_classified


func run_dialogue_commands(commands : Array) -> void:
	for command in commands:
		var objectName : String = command.get_attribute_by_name("objectName").value.data.strip_edges()
		match objectName:
			"pause":
				# This makes a pause AFTER the rendering of the current element.
				print("Found PAUSE component.")
				dialogue_pause = true
			
			"stop":
				# This ends the dialogue after rendering current component.
				dialogue_end = true
			
			"title":
				# Renders current content as a title (instead of speech).
				line_is_title = true
				
			"randomOut":
				# Tells render_options to follow a random option.
				follow_random_output = true
				
			"overlapNext":
				# Instead of rendering content, it saves it, so that it appears
				# with the next element's content.
				overlap_current_line_with_next = true
			
			_:
				push_writer_error("Unknown Dialogue Flow Command: " + str(command))


func play_dialogue_animation(_animations : Array) -> void:
	# Not implemented in current demo.
	pass


func play_next_from_playlist() -> void:
	if current_playlist.size() == 0:
		return

	for track in current_playlist:
		var file_name : String = track.get_attribute_by_name("fileName").value.data
		var path : String = "res://assets/assets_audio/" + file_name
		
		if not ResourceLoader.exists(path):
			push_writer_error("Can't find audio file " + file_name + " in project's assets.")
			continue
		
		var audio_stream : AudioStream = load(path)
		# Removing current track from playlist in a queue fashion:
		var _popped : Component = current_playlist.pop_front()
		sfxPlayer.set_stream(audio_stream)
		sfxPlayer.play()


func check_exit_for_logic(exit_node : ClickableExit) -> void:
	just_exit_after_walk = false
	var target_id : String = ""
	
	# If the exit node has no reply_id, it's for straight exiting:
	if exit_node.reply_id.strip_edges() == "":
		just_exit_after_walk = true
	else:
		target_id = get_id_from_verb_object_reply("walk", exit_node.reply_id)
	
	if target_id.strip_edges() == "":
		just_exit_after_walk = true
	
	current_target_id = target_id
	set_game_state(WALKING_TO_ACTION)
	walk_player_to(exit_node.approachPosition.global_position)


func _on_Player_animation_finished(_anim_name: String) -> void:
	if State.game == EXPLORING:
		return

	if State.game == DIALOGUE:
		push_error("GAME state leak: invalid DIALOGUE state" 
			+ " after player walk animation finished.")
	if State.game == TRANSITIONING:
		push_error("GAME state leak: invalid TRANSITIONING state " 
			+ " after player walk animation finished.")

	# Else, if game state is WALKING_TO_ACTION...
	if current_object_clicked is ClickableExit:
		if just_exit_after_walk:
			# There is no logic, so just exit.
			just_exit_after_walk = false
			exit_room_from(current_object_clicked)
			return
	
	# Else, we start a dialogue:
	if current_object_clicked is ClickableObject:
		orient_player_towards(current_object_clicked.global_position)
	start_dialogue(current_target_id)
	current_target_id = "RESET"


func enable_mouse(yes : bool) -> void:
	if yes:
		cursorSprite.texture = IDLE_CURSOR
	else:
		cursorSprite.texture = null


# This is for the dialogue option button (fix the nomenclature at some point):
func _on_option_button_pressed(option):
	for i in $UI/MarginContainer/OptionsUI/OptionsContainer.get_children():
		i.queue_free()
	$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonDn.disabled = true
	$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonUp.disabled = true
	number_of_visible_options = 0
	option_buttons.clear()
	select_option(option)


func _on_ButtonMouth_mouse_entered() -> void:
	command_line.verb = "Talk to"
	update_command_line()


func _on_ButtonMouth_mouse_exited() -> void:
	command_line.verb = "Walk to"
	update_command_line()


func _on_ButtonEye_mouse_entered() -> void:
	command_line.verb = "Examine"
	update_command_line()


func _on_ButtonEye_mouse_exited() -> void:
	command_line.verb = "Walk to"
	update_command_line()


func _on_ButtonHand_mouse_entered() -> void:
	if current_object_clicked is ClickableItem:
		if current_object_clicked.portable:
			command_line.verb = "Take"
		else:
			command_line.verb = "Fiddle with"
	if current_object_clicked is ClickableCharacter:
		command_line.verb = "Push"
	update_command_line()


func _on_ButtonHand_mouse_exited() -> void:
	command_line.verb = "Walk to"
	update_command_line()


func _on_ButtonMouth_pressed() -> void:
	var target_id : String = get_id_from_verb_object_reply("talk", current_object_clicked.reply_id)
	
	set_game_state(WALKING_TO_ACTION)
	set_cursor_and_selected_item(null)
	act(target_id)


func _on_ButtonEye_pressed() -> void:
	var target_id : String = get_id_from_verb_object_reply("examine", current_object_clicked.reply_id)
	
	set_ui_state(IDLE)
	set_cursor_and_selected_item(null)
	set_game_state(EXPLORING) # It probably already is in EXPLORING.
	
	# When examining items, player first approaches them and then replies.
	# When examining characters, player replies from original position.
	if current_object_clicked is ClickableItem:
		set_game_state(WALKING_TO_ACTION) # This gets checked in act()
		set_cursor_and_selected_item(null)
	act(target_id)


func _on_ButtonHand_pressed() -> void:
	var target_id : String = get_id_from_verb_object_reply("handle", current_object_clicked.reply_id)
	set_game_state(WALKING_TO_ACTION)
	set_ui_state(IDLE)
	set_cursor_and_selected_item(null)
	act(target_id)


func _on_ClickableObject_clicked(node_clicked : ClickableObject) -> void:
	# This is called when a ClickableObject's "object_clicked" signal gets received,
	# that is when the player clicks on any item/character/exit in the room.
	# We don't want anything to happen while TRANSITIONING or DIALOGUE:
	if State.game == TRANSITIONING or State.game == DIALOGUE:
		return
	
	# If WALKING_TO_ACTION, we forget the previous intent:
	if State.game == WALKING_TO_ACTION:
		set_game_state(EXPLORING)
	
	current_object_clicked = node_clicked
	
	match State.ui:
		
		IDLE:
			if current_object_clicked is ClickableExit:
				check_exit_for_logic(current_object_clicked)
				return
		
		MENU_OPEN:
			set_ui_state(IDLE)
			set_cursor_and_selected_item(null)
			
			if current_object_clicked is ClickableExit:
				check_exit_for_logic(current_object_clicked)
		
		HOLDING_ITEM:
			if inventory_item_selected == null:
				push_error("State leak: (clicking on ClickableObject) "
					+ " UI state is HOLDING_ITEM,"
					+ "but inventory_item_selected is NULL.")
				return
			
			if current_object_clicked is ClickableObject:
				var target_id = get_id_from_objects_replies(inventory_item_selected.reply_id, current_object_clicked.reply_id)
				set_game_state(WALKING_TO_ACTION)
				set_ui_state(IDLE)
				set_cursor_and_selected_item(null)
				act(target_id)
				return
	
			push_error("Current object clicked not of known type.")
			set_cursor_and_selected_item(null)
			set_ui_state(IDLE)
			return
		
		_:
			push_error("Upon clicking ClickableObject: UI in invalid state.")
			set_cursor_and_selected_item(null)
			set_ui_state(IDLE)
			return
	
	set_ui_state(MENU_OPEN)
	set_cursor_and_selected_item(null)


func _on_DialogueTimer_timeout() -> void:
	after_timer_do()


func after_timer_do():
	if State.game == DIALOGUE and State.dialogue == PAUSING:
		print("Rendering options after pause.")
		render_options()
		return
		
	if State.game == DIALOGUE and State.dialogue == RENDERING_ELEMENT:
		reset_dialogue_bubbles()
		if dialogue_pause:
			dialogue_pause = false
			set_dialogue_state(PAUSING)
			print("Setting PAUSING as dialogue state.")
			dialogueTimer.wait_time = PAUSE_TIME
			dialogueTimer.start()
			return
	
	if dangling_exit != null:
		exit_room_from(dangling_exit)
		dangling_exit = null
		return

	if dialogue_end:
		_end_dialogue()
		return

	render_options()


func _end_dialogue():
	dialogue_end = false
	dangling_dialogue = false
	# No practical point in turning this OFF, but it makes us look good:
	set_dialogue_state(OFF)
	set_game_state(EXPLORING)
	set_ui_state(IDLE)
	set_cursor_and_selected_item(null)
	current_object_clicked = null


func reset_dialogue_bubbles() -> void:
	var speakerBubbles : Array = get_tree().get_nodes_in_group("allBubbles")
	
	$UI/Title/Label.text = ""
	
	for sb in speakerBubbles:
		sb.global_position = Vector2.ZERO # Getting it out of the screen
		sb.characterLines.text = ""


func check_and_get_main_attributes(component: Component) -> Dictionary:
	var main_attributes : Dictionary = {"error": false}
	
	var type_attribute: Dictionary = component.get_attribute_by_name("type")
	if type_attribute.empty():
		push_writer_error("No type attribute for component: " + component.name)
		# Moving on to next element.
		main_attributes.error = true
		
	var objectName_attribute : Dictionary = component.get_attribute_by_name("objectName")
	if objectName_attribute.empty():
		push_writer_error("No objectName for component: " + component.name)
		main_attributes.error = true
		
	if main_attributes.error:
		return main_attributes # Without type and/or objectName
	
	main_attributes.type = type_attribute.value.data
	main_attributes.objectName = objectName_attribute.value.data
	
	return main_attributes


func check_contains_1(my_array : Array)-> bool:
	if my_array.size() > 1:
		var error_ids : Array = []
		for element in my_array:
			error_ids.append(element.id)
		push_writer_error("More than 1 element found for specific action or cutScene: " 
			+ str(error_ids))
		return false

	if my_array.size() == 0:
		return false
		
	return true


func get_id_from_cut_scene(cut_scene_name: String) -> String:
	var compatible_elements : Array = []
	var element_counter : int = 0 # Just stats.
	
	# Use next commented line to optimise the iteration only to the board of player actions:
#	for element_id in player_actions_aw_board.elements:
	for element_id in story.elements:
		element_counter += 1
		var element : Element = story.elements[element_id]
		
		# Elements with events must have only 1 component--the cutScene.
		if element.components.size() != 1:
			continue
			
		var component : Component = element.components[0]
		var main_attributes : Dictionary = check_and_get_main_attributes(component)
		
		if main_attributes.error:
			# Errors thrown already in check_and_get_attributes
			continue

		if main_attributes.type != "cutScene":
			continue
		
		if main_attributes.objectName != cut_scene_name:
			continue

		compatible_elements.append(element)
	print("Iterated through " + str(element_counter) + " elements.")
	
	if check_contains_1(compatible_elements):
		# In our case, there is no "generic" substitution.
		return compatible_elements[0].id

	push_writer_error("Failed to get Target ID for cutScene " + cut_scene_name)
	return ""


func get_id_from_verb_object_reply(verb: String, obj_reply : String)-> String:
	var compatible_elements : Array = [] # Must eventually have exactly 1 member.
	var generic_replies : Array = [] # Must also have 1 member.
	var element_counter : int = 0 # Just stats.
	
#	for element_id in player_actions_aw_board.elements: # For optimisation.
	for element_id in story.elements:
		element_counter += 1
		var element : Element = story.elements[element_id]
		
		# Elements with events must have only 1 component--the cutScene.
		if element.components.size() != 2:
			continue
		
		var actions : Array = [] # Stores objectNames of actions: examine, handle, etc.
		var objects : Array = [] # Stores objectNames of items, characters, exits.
			
		for component in element.components:

			var main_attributes : Dictionary = check_and_get_main_attributes(component)
			
			if main_attributes.error:
				# Errors thrown already in check_and_get_attributes
				# Moving on to next element. (Not next component.)
				break

			match main_attributes.type:
				"actionVerb":
					actions.append(main_attributes.objectName)
					
				"item", "character", "exit":
					objects.append(main_attributes.objectName)
		
		if actions.size() < 1:
			continue
		
		if actions.size() > 1:
			push_writer_error("Cannot have more than 1 actionVerb components in element " 
				+ element.id)
			continue
		
		if actions[0] != verb:
			# Not the action we are looking for. Continue to next element iteration.
			continue
		
		if objects.size() != 1:
			push_writer_error("No object found for action " + verb)

		if objects[0] != obj_reply:
			# Not the noun we are looking for.
			# Check first if it's generic reply for the verb:
			if objects[0] == "generic":
				# We store it:
				generic_replies.append(element)
			continue

		compatible_elements.append(element)
	print("Iterated through " + str(element_counter) + " elements.")
	
	# If we have a specific reply, we return the target element ID:
	if check_contains_1(compatible_elements):
		return compatible_elements[0].id

	# If we have a generic reply for the verb, we return the target ID:
	if check_contains_1(generic_replies):
		return generic_replies[0].id
	
	if verb != "walk":
		push_writer_error("Failed to get Target ID for verb " + verb + " and noun " + obj_reply)
	return ""


func get_id_from_objects_replies(obj_reply_1 : String, obj_reply_2 : String) -> String:
	var compatible_elements : Array = [] # Must eventually have exactly 1 member.
	var generic_replies : Array = [] # Must also have 1 member.
	var element_counter : int = 0 # Just stats.
	
#	for element_id in player_actions_aw_board.elements: # For optimisation.
	for element_id in story.elements:
		element_counter += 1
		var element : Element = story.elements[element_id]
		
		# Elements with events must have only 1 component--the cutScene.
		if element.components.size() != 2:
			continue
		
		var objects : Array = [] # Stores objectNames of items, characters, exits.
			
		for component in element.components:

			var main_attributes : Dictionary = check_and_get_main_attributes(component)
			
			if main_attributes.error:
				# Errors thrown already in check_and_get_attributes
				# Moving on to next element. (Not next component.)
				break

			match main_attributes.type:
				"item", "character", "exit":
					objects.append(main_attributes.objectName)
		
		if objects.size() != 2:
			continue
			
		###### EXHAUSTIVE CHECKING ENSUES... ######
		
		# Cases of "generic" use:
		
		if objects[0] == objects[1]:
			# No point using an object to itself.
			# Inventory functions (should) block that.
			# Unless encountered reply for USE GENERIC ON GENERIC.
			if objects[0] == "generic":
				generic_replies.push_front(element) # Pushing the most general case first.
			continue
		if objects[0] == "generic":
			if objects[1] == obj_reply_1 or objects[1] == obj_reply_2:
				generic_replies.push_front(element)
			continue
		if objects[1] == "generic":
			if objects[0] == obj_reply_1 or objects[0] == obj_reply_2:
				generic_replies.push_front(element)
			continue

		# Cases of specific objects use:
		
		if objects[0] != obj_reply_1 and objects[0] != obj_reply_2:
			continue

		if objects[1] != obj_reply_1 and objects[1] != obj_reply_2:
			continue

		if objects[0] == obj_reply_1:
			if objects[1] != obj_reply_2:
				continue
			compatible_elements.append(element)
		
		if objects[1] == obj_reply_1:
			if objects[0] != obj_reply_2:
				continue
			compatible_elements.append(element)
	print("Iterated through " + str(element_counter) + " elements.")
	
	# If we have a specific reply, we return the target element ID:
	if check_contains_1(compatible_elements):
		return compatible_elements[0].id

	# Else we return the target ID of the first (most specific) of the generic cases:
	if generic_replies.size() > 0:
		return generic_replies[0].id
	
	push_writer_error("Failed to get Target ID for nouns " + obj_reply_1 + " and " + obj_reply_2)
	return ""


func _on_inventory_container_mouse_in_slot(item) -> void:
	
	# We don't want anything to happen while TRANSITIONING or DIALOGUE:
	if State.game == TRANSITIONING or State.game == DIALOGUE:
		return
		
	if item == null:
		return

	match State.ui:
	
		HOLDING_ITEM:
			if inventory_item_selected == null:
				push_error("While hovering: UI in HOLDING_ITEM state, but inventory_item_selected is NULL.")
				return
			
			if inventory_item_selected == item:
				return

			command_line.verb = "Use"
			command_line.object_1 = inventory_item_selected.object_name
			command_line.preposition = "with"
			command_line.object_2 = item.object_name
			update_command_line()

		IDLE, MENU_OPEN:
			
			if item == null:
				return
			command_line.object_1 = item.object_name
			update_command_line()


func _on_inventory_container_mouse_out_of_slot() -> void:
	
	# We don't want anything to happen while TRANSITIONING or DIALOGUE:
	if State.game == TRANSITIONING or State.game == DIALOGUE:
		return
	
	match State.ui:
		
		HOLDING_ITEM:
			command_line.object_2 = ""
			update_command_line()
		
		MENU_OPEN, IDLE:
			erase_command_line()


func _on_inventory_container_item_selected(item : Item) -> void:
	current_object_clicked = null
	# This is called when the inventory container's signal "item_selected" is received:
	match State.ui:
		
		IDLE, MENU_OPEN:
			if inventory_item_selected is Item:
				push_error("Upon clicking inventory item: UI not in HOLDING_ITEM state, "
					+ " but inventory_item_selected not NULL.")
				return
			
			set_ui_state(HOLDING_ITEM)
			set_cursor_and_selected_item(item)
			command_line.verb = "Use"
			command_line.object_1 = item.object_name
			command_line.preposition = "with"
			update_command_line()
		
		HOLDING_ITEM:
			if inventory_item_selected == null:
				push_error("Upon clicking inventory item: UI is in HOLDING_ITEM state, "
					+ " but inventory_item_selected is NULL.")
				return
			
			if inventory_item_selected == item:
				set_ui_state(IDLE)
				set_cursor_and_selected_item(null)
				if State.game != EXPLORING:
					set_game_state(EXPLORING)
				return
			
			var target_id : String = get_id_from_objects_replies(inventory_item_selected.reply_id, item.reply_id)
			
			set_ui_state(IDLE)
			set_cursor_and_selected_item(null)
			set_game_state(EXPLORING) # It probably already is in EXPLORING.
			act(target_id)
			
			objectLabel.text = item.object_name


func _on_inventory_container_item_examined(item)-> void:
	current_object_clicked = null
	# This is called when the inventory container's signal "item_examined" is received
	# In other words, when you right click an inventory item.
	match State.ui:
		
		IDLE, MENU_OPEN:
			if inventory_item_selected is Item:
				push_error("Upon clicking inventory item: UI not in HOLDING_ITEM state, "
					+ " but inventory_item_selected not NULL.")
				return
			
			set_ui_state(IDLE) # We need to fix "Examine / Use" functionality for inventory items.
			set_cursor_and_selected_item(null)
			command_line.verb = "Examine"
			command_line.object_1 = item.object_name
#			command_line.preposition = "with"
			update_command_line()
			
			var target_id : String = get_id_from_verb_object_reply("examine", item.reply_id)
			set_game_state(EXPLORING) # It probably already is in EXPLORING.
			act(target_id)
			
		
		HOLDING_ITEM:
			if inventory_item_selected == null:
				push_error("Upon clicking inventory item: UI is in HOLDING_ITEM state, "
					+ " but inventory_item_selected is NULL.")
				return
			
			if inventory_item_selected == item:
				set_ui_state(IDLE)
				set_cursor_and_selected_item(null)
				if State.game != EXPLORING:
					set_game_state(EXPLORING)
				return
			
			var target_id : String = get_id_from_objects_replies(inventory_item_selected.reply_id, item.reply_id)
			
			set_ui_state(IDLE)
			set_cursor_and_selected_item(null)
			set_game_state(EXPLORING) # It probably already is in EXPLORING.
			act(target_id)
			
			objectLabel.text = item.object_name


func set_cursor_hovering_over(aNode):
	set_cursor(aNode)
	current_object_hovered = aNode # This isn't currently used somewhere.



func _on_OptionArrowButtonUp_pressed() -> void:
	$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonDn.disabled = false
	for i in range(option_buttons.size(), 0, -1):
		if not option_buttons[i - 1].visible:
			option_buttons[i - 1].visible = true
			number_of_visible_options += 1
			if number_of_visible_options == option_buttons.size():
				$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonUp.disabled = true
			break


func _on_OptionArrowButtonDn_pressed() -> void:
	$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonUp.disabled = false
	for ob in option_buttons:
		if ob.visible:
			ob.visible = false
			number_of_visible_options -= 1
			if number_of_visible_options <= MAX_NUMBER_VISIBLE_OPTIONS:
				$UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonDn.disabled = true
			break


func _on_MusicSlider_value_changed(value: float) -> void:
	set_volumes_from_linear(value, registered_settings.sfx_volume)


func _on_SFXSlider_value_changed(value: float) -> void:
	set_volumes_from_linear(registered_settings.music_volume, value)


func _on_DialogueSpeedSlider_value_changed(value: float) -> void:
	set_dialogue_speed(int(value))


func _on_WalkSpeedSlider_value_changed(value: float) -> void:
	set_walk_speed(value)


func _on_Popup_about_to_show() -> void:
	show_cursor(false)


func _on_SFXPlayer_finished() -> void:
	play_next_from_playlist()


func _on_Popup_popup_hide() -> void:
	save_settings()
	show_cursor(true) # Without resetting it.


func _on_Save_pressed() -> void:
	save_state()


func _on_SettingsMenu_restart() -> void:
	set_game_state(TRANSITIONING)
	music_fade(OUT)
	room_fade(OUT)
	yield(tween_room, "tween_completed")
	var _reload = get_tree().reload_current_scene()



func _on_MouseCursorArea2D_area_entered(area: Area2D) -> void:
	# Player hovers over a ClickableObject.
	# We don't want anything to happen while TRANSITIONING or DIALOGUE:
	if State.game == TRANSITIONING or State.game == DIALOGUE:
		return

	match State.ui:
	
		HOLDING_ITEM:
			if inventory_item_selected == null:
				push_error("While hovering: UI in HOLDING_ITEM state, but inventory_item_selected is NULL.")
				return
			
			command_line.object_1 = inventory_item_selected.object_name
			command_line.object_2 = area.object_name
			
			if area is ClickableCharacter:
				command_line.verb = "Give"
				command_line.preposition = "to"
			else:
				command_line.verb = "Use"
				command_line.preposition = "with"
			update_command_line()

		MENU_OPEN:
			set_cursor_hovering_over(area)
		
		IDLE:
			set_cursor_hovering_over(area)
			command_line.object_1 = area.object_name
			update_command_line()


func _on_MouseCursorArea2D_area_exited(_area: Area2D) -> void:
		# We don't want anything to happen while TRANSITIONING or DIALOGUE:
	if State.game == TRANSITIONING or State.game == DIALOGUE:
		return
	
	match State.ui:
		
		HOLDING_ITEM:
			command_line.verb = "Use"
			command_line.object_2 = ""
			command_line.preposition = "with"
			update_command_line()
		
		MENU_OPEN:
			set_cursor_hovering_over(null)
			
		IDLE:
			erase_command_line()
			set_cursor_hovering_over(null)
