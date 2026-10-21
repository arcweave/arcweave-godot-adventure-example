extends Node2D

# Attention: the following enums must have same names as in the StateHandler resource:
enum {EXPLORING, WALKING_TO_ACTION, TRANSITIONING, DIALOGUE} # GAME states
enum {IDLE, MENU_OPEN, HOLDING_ITEM} # UI states
enum {OFF, RENDERING_ELEMENT, RENDERING_OPTIONS, WAITING_CHOICE, PAUSING} # DIALOGUE states
enum {IN, OUT} # For the fade functions.

const MAX_NUMBER_VISIBLE_OPTIONS = 3 # Max responses before arrows appear.
const MIN_X = 120 # MIN_X & MAX_X for dialogue bubble placement
const MAX_X = 200
const MIN_Y = 73 # Y for speaker position, for dialogue bubble placement
const MAX_Y = 100 # (The room window lower end.)
const PAUSE_TIME = 1.5 # The time kept when dialogue reaches a "pause" component.
const FADE_TIME = 1.0 # Duration of the room and music fades.
# Mouse Cursors:
const IDLE_CURSOR : Texture2D = preload("res://assets/assets_ui/cursor_idle.png")
const HOVER_CURSOR : Texture2D = preload("res://assets/assets_ui/cursor_hover.png")
const EXIT_CURSOR : Texture2D = preload("res://assets/assets_ui/cursor_walk_out.png")
# Starting room and position:
const FIRST_ROOM : String = "res://scenes_rooms/Bedroom.tscn"
const PLAYER_STARTING_POSITION : Vector2 = Vector2(138, 92)
const SAVED_SETTINGS_PATH = "user://settings.dat"
const DialogueOptionButton : PackedScene = preload("res://scenes_ui/DialogueOptionButton.tscn")

# The game's state machines (not the story state) and the inventory are stored in
# separate resource files, for access by various scripts. They are vars, not consts:
# Godot 4 would bake the values of a const resource into the script.
var Inventory : InventoryHandler = preload("res://resources/Inventory.tres")
var State : StateHandler = preload("res://resources/state_handler.tres")

# The Arcweave story (Arcweave.Story, from the C# plugin), created by the ArcweaveNode:
var story : Object = null
# The Arcweave board with the starting elements of all player actions:
var player_actions_aw_board : Object = null
# The following 3 vars get their values from the current room:
var current_room : Location = null
var nav_region : NavigationRegion2D = null
var line2D : Line2D = null
# The following vars get values from player actions:
var inventory_item_selected : Item = null
var current_object_clicked : ClickableObject = null
var current_target_id : String = ""
# Flags related to dialogue flow:
var dialogue_speed_factor : int = 3 # For faster dialogue go higher.
var dialogue_pause : bool = false
var dialogue_end : bool = false
var line_is_title : bool = false
var overlap_current_line_with_next : bool = false
var just_exit_after_walk : bool = false
var overlapping_data : Dictionary = {}
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
var registered_settings : Dictionary = { # Volumes in linear values (from 0 to 1)
	"music_volume": 0.65,
	"sfx_volume": 0.85,
	"dialogue_speed": 3,
	"walk_speed": 18.0
}
var number_of_visible_options : int = 0
var option_buttons : Array[Button] = []

@onready var player : Node2D = $Player
@onready var optionsUI : HBoxContainer = $UI/MarginContainer/OptionsUI
@onready var optionsContainer : VBoxContainer = $UI/MarginContainer/OptionsUI/OptionsContainer
@onready var optionsArrows : VBoxContainer = $UI/MarginContainer/OptionsUI/OptionsArrows
@onready var arrowButtonUp : TextureButton = $UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonUp
@onready var arrowButtonDn : TextureButton = $UI/MarginContainer/OptionsUI/OptionsArrows/ArrowButtonDn
@onready var objectsContainer: VBoxContainer = $UI/MarginContainer/ObjectsContainer
@onready var objectLabel: Label = $UI/MarginContainer/ObjectsContainer/ObjectName
@onready var titleLabel : Label = $UI/Title/Label
@onready var mouseMenu : Node2D = $UI/MouseMenu
@onready var fader : ColorRect = $UI/Fader
@onready var dialogueTimer: Timer = $DialogueTimer
@onready var cursorSprite : Sprite2D = $UI/MouseCursor/Cursor
@onready var cursorArea : Area2D = $UI/MouseCursor/Cursor/MouseCursorArea2D
@onready var cursorCollision : CollisionShape2D = $UI/MouseCursor/Cursor/MouseCursorArea2D/MouseCursorCollision
@onready var musicPlayer : AudioStreamPlayer = $UI/MusicPlayer
@onready var sfxPlayer : AudioStreamPlayer = $UI/SFXPlayer
@onready var inventoryGrid : HBoxContainer = $UI/MarginContainer/ObjectsContainer/InventoryContainer
@onready var settingsRows : VBoxContainer = $UI/SettingsMenu/Popup/MarginContainer/VBoxContainer
@onready var musicSlider : HSlider = settingsRows.get_node("MusicRow/MusicSlider")
@onready var sfxSlider : HSlider = settingsRows.get_node("SFXRow/SFXSlider")
@onready var dialogueSpeedSlider : HSlider = settingsRows.get_node("DialogueSpeedRow/DialogueSpeedSlider")
@onready var walkSpeedSlider : HSlider = settingsRows.get_node("WalkSpeedRow/WalkSpeedSlider")


func push_writer_error(error_text : String) -> void:
	push_error("ARCWEAVE WRITER ERROR: " + error_text)

func push_writer_warning(warning_text : String) -> void:
	push_warning("ARCWEAVE WRITER WARNING: " + warning_text)

# Returns the value of a component's attribute as a String, e.g. its "objectName":
func attr(component: Object, attribute_name: String) -> String:
	var attribute : Object = component.GetAttribute(attribute_name)
	if attribute == null:
		push_writer_error("Component '" + component.Name + "' has no attribute '" + attribute_name + "'.")
		return ""
	return str(attribute.data)


func _ready() -> void:
	# The ArcweaveNode creates the Story from its ArcweaveAsset in its own _ready(),
	# which runs before ours, since it is our child.
	story = $ArcweaveNode.Story
	load_player_actions_board()
	load_settings()
	check_load_start_game()


# This loads the board where all starting elements are for player commands.
# The get_id_from_* functions only search this board, instead of the whole project.
func load_player_actions_board()-> void:
	for board in story.GetProject().Boards.values():
		if board.CustomId == "PLAYER_ACTIONS":
			player_actions_aw_board = board
			return
	push_writer_error("Board with starting elements for all player actions"
		+ " not found. Please, create board with custom Board ID: PLAYER_ACTIONS")


# The elements to search for the starting element of a player action:
func get_player_action_elements() -> Array:
	if player_actions_aw_board == null:
		return story.GetProject().Elements.values() # Fallback: the whole project.
	return player_actions_aw_board.Elements


func check_load_start_game()-> void:
	# If there is no command to Load, start a new game:
	if not LoadGame.load_game:
		start_new_game()
		return
	# Else, load the data:
	LoadGame.load_game = false # Reset the load_game var
	load_saved_game()


	
func load_saved_game() -> void:
	# Read the saved game, if there is one this version can load:
	var data : Dictionary = LoadGame.read_saved_game()
	if data.is_empty():
		print("No saved game found that this version can load.")
		start_new_game()
		return # Again, start new game.
	# Load saved data. The plugin's save also restores the current element:
	story.LoadSave(data.story_variables)
	dangling_dialogue = data.has_dangling_dialogue
	# Load room and place the player sprite:
	player.sprite.flip_h = data.player_looking_left
	load_room_from_path(data.room_path, data.player_position)
	# Load inventory:
	Inventory.set_inventory_from_paths(data.inventory)
	inventoryGrid.update_inventory_display()


func start_new_game()->void:
	# The inventory is a shared resource, so it outlives a restart:
	Inventory.clear_inventory()
	inventoryGrid.update_inventory_display()
	load_room_from_path(FIRST_ROOM, PLAYER_STARTING_POSITION)


func save_state()-> void:
	var current_element_id : String = story.GetCurrentElement().Id
	# The story save holds the current element, the variables and the element visits:
	var current_story_variables : Dictionary = story.GetSave()
	var current_room_path : String = current_room.scene_file_path
	var current_player_position: Vector2 = player.global_position
	var current_player_looking_left: bool = player.sprite.flip_h
	var current_inventory : Array = Inventory.get_inventory_paths()
	var current_dangling_dialogue : bool = dangling_dialogue
	
	if State.game == DIALOGUE:
		current_dangling_dialogue = true
		
	var saved_state : Dictionary = {
		"version": LoadGame.SAVE_VERSION,
		"element_id": current_element_id,
		"has_dangling_dialogue": current_dangling_dialogue, # saves the global var
		"story_variables": current_story_variables,
		"room_path": current_room_path,
		"player_position": current_player_position,
		"player_looking_left": current_player_looking_left,
		"inventory": current_inventory,
	}
	
	var file := FileAccess.open(LoadGame.SAVED_GAME_PATH, FileAccess.WRITE)
	file.store_var(saved_state)
	file.close()
	print("Game saved in room " + current_room_path + ".")


func _unhandled_input(event : InputEvent) -> void:
	match State.game:
		
		EXPLORING:
			if event.is_action_pressed("click"):
				
				# If UI state is not IDLE, we switch to IDLE and return:
				if State.ui == MENU_OPEN or State.ui == HOLDING_ITEM:
					return_ui_to_idle()
					return
					
				# Else (if UI is already IDLE), we walk to mouse position:
				walk_player_to(get_global_mouse_position())
				
			if event.is_action_pressed("ui_skip"):
				set_ui_state(IDLE)
			
		WALKING_TO_ACTION:
			if event.is_action_pressed("click"):
				
				# If UI state is not IDLE, we switch to IDLE and return:
				if State.ui == MENU_OPEN or State.ui == HOLDING_ITEM:
					return_ui_to_idle()
					return
					
				# Else (if UI is already IDLE), we switch to EXPLORING
				# (thus interrupting the walking with intent and
				# forgetting the object clicked).
				# We walk to the new mouse position:
				walk_player_to(get_global_mouse_position())
				set_game_state(EXPLORING)
				
			if event.is_action_pressed("ui_skip"):
				# If UI state is not IDLE, we switch to IDLE:
				if State.ui == MENU_OPEN or State.ui == HOLDING_ITEM:
					set_ui_state(IDLE)
					
				# Contrary to the left click, though, the WALKING_TO_ACTION remains.
				return
		
		TRANSITIONING:
			
			if event.is_action_pressed("click") or event.is_action_pressed("ui_skip"):
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
	var file := FileAccess.open(SAVED_SETTINGS_PATH, FileAccess.WRITE)
	file.store_line(JSON.stringify(registered_settings))
	file.close()


func load_settings() -> void:
	# The defaults are the values in registered_settings. Saved values override them,
	# so a settings file with missing (or extra) keys still works:
	var settings : Dictionary = registered_settings.duplicate()
	if FileAccess.file_exists(SAVED_SETTINGS_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVED_SETTINGS_PATH))
		if saved is Dictionary:
			settings.merge(saved, true)
		else:
			push_warning("Ignoring invalid settings file: " + SAVED_SETTINGS_PATH)
	
	set_volumes_from_linear(settings.music_volume, settings.sfx_volume)
	set_dialogue_speed(int(settings.dialogue_speed))
	set_walk_speed(settings.walk_speed)


func set_walk_speed(value : float)-> void:
	registered_settings.walk_speed = value
	walkSpeedSlider.value = value
	player.animationPlayer.speed_scale = value * 1.0/10.0
	player.speed = value * 14.0/10.0


func set_dialogue_speed(value: int)-> void:
	registered_settings.dialogue_speed = value
	dialogueSpeedSlider.value = value
	dialogue_speed_factor = value


func set_volumes_from_linear(music_volume : float, sfx_volume : float) -> void:
	# Takes linear values (from 0 to 1) and converts them to dB for the players:
	registered_settings.music_volume = music_volume
	registered_settings.sfx_volume = sfx_volume
	musicSlider.value = music_volume
	sfxSlider.value = sfx_volume
	musicPlayer.volume_db = linear_to_db(music_volume)
	sfxPlayer.volume_db = linear_to_db(sfx_volume)


func music_fade(towards : int) -> void:
	var end : float = 0.0
	match towards:
		IN:
			end = linear_to_db(registered_settings.music_volume)
		OUT:
			end = -80.0
		_:
			push_error("Invalid argument for music_fade function: " + str(towards))
	
	if towards == IN:
		musicPlayer.play()
	
	create_tween().tween_property(musicPlayer, "volume_db", end, FADE_TIME)


# Fades the room window from or to black. Await the returned tween's "finished" signal
# to wait for the fade.
func room_fade(towards : int) -> Tween:
	var end : Color = Color.BLACK
	match towards:
		IN:
			end = Color(0, 0, 0, 0)
		OUT:
			end = Color.BLACK
		_:
			push_error("Invalid argument for room_fade function: " + str(towards))
	
	var tween : Tween = create_tween()
	tween.tween_property(fader, "color", end, FADE_TIME)
	return tween


func load_room_from_path(room_path : String, player_position : Vector2)-> void:
	set_game_state(TRANSITIONING)
	set_cursor_and_selected_item(null)
	var next_room : Location = load(room_path).instantiate()
	
	if current_room != null:
		var fade_out : Tween = room_fade(OUT)
		if musicPlayer.playing and musicPlayer.get_stream() != next_room.music:
			music_fade(OUT)
		await fade_out.finished
		current_room.queue_free()
		await get_tree().process_frame
	
	dress_up_room(next_room)
	for obj in next_room.get_node("Objects").get_children():
		if obj is ClickableObject:
			obj.object_clicked.connect(_on_ClickableObject_clicked)
	place_player(player_position)
	
	# Rooms go under the Rooms node, which is drawn before (below) the player:
	next_room.name = "Location"
	$Rooms.add_child(next_room)
	current_room = next_room
	nav_region = next_room.get_node("NavigationRegion2D")
	line2D = next_room.get_node("Line2D")
	
	var fade_in : Tween = room_fade(IN)
	if musicPlayer.get_stream() != next_room.music:
		musicPlayer.set_stream(next_room.music)
		music_fade(IN)
	await fade_in.finished
	
	if dangling_dialogue:
		dangling_dialogue = false
		set_game_state(DIALOGUE)
		render_options()
		return
		
	set_game_state(EXPLORING)


func dress_up_room(room_node : Node2D) -> void:
	var project : Object = story.GetProject()
	
	for obj in room_node.get_node("Objects").get_children():
		if not obj is ClickableObject:
			continue
		if obj.state_variable == "":
			continue
		
		# We first switch them off, then check their state.
		obj.visible = false
		obj.monitorable = false
		
		# Then check if object is present (our convention: if its var == 1):
		var variable : Object = project.GetVariable(obj.state_variable)
		if variable == null:
			push_writer_error("Variable '" + obj.state_variable + "' of object '" + obj.name + "' not found.")
			continue
		if variable.Value == 1:
			obj.visible = true
			obj.monitorable = true


func place_player(new_player_position : Vector2) -> void:
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
func set_cursor(item : Object) -> void:
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


func set_game_state(new_state : int) -> void:
	# Leaving the dialogue cancels any pending line timer:
	if new_state != DIALOGUE and not dialogueTimer.is_stopped():
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
	cursorCollision.disabled = yes


# Changing the UI state also sets the selected inventory item (and the cursor):
# it is the given item when HOLDING_ITEM, and null otherwise.
func set_ui_state(new_state : int, inventory_item : Item = null) -> void:
	
	match new_state:
		
		IDLE:
			open_mouse_menu(false)
			if not State.game == WALKING_TO_ACTION:
				erase_command_line()
		
		MENU_OPEN:
			if current_object_clicked == null and inventory_item_selected == null:
				push_error("SET UI STATE(MENU_OPEN): object/item clicked is NULL.")
				return
			open_mouse_menu(true)
			command_line.object_1 = current_object_clicked.object_name
			update_command_line()
		
		HOLDING_ITEM:
			open_mouse_menu(false)
		
		_:
			push_error("Attempt to assign invalid ui state.")
			return
	
	set_cursor_and_selected_item(inventory_item)
	if State.ui != new_state:
		State.ui = new_state


# Closes the verb menu or drops the held item. The room reacts to the mouse again,
# so if the cursor is already over an object, we show it as hovered:
func return_ui_to_idle() -> void:
	set_ui_state(IDLE)
	for area in cursorArea.get_overlapping_areas():
		if area is ClickableObject:
			_on_MouseCursorArea2D_area_entered(area)
			return


func set_dialogue_state(new_state : int) -> void:
	if State.game != DIALOGUE:
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
func set_cursor_and_selected_item(item : Item) -> void:
	inventory_item_selected = item
	set_cursor(item)


func open_mouse_menu(true_false : bool) -> void:
	mouseMenu.position = get_global_mouse_position()
	mouseMenu.visible = true_false


func erase_command_line() -> void:
	objectLabel.text = ""
	command_line.verb = ""
	command_line.object_1 = ""
	command_line.preposition = ""
	command_line.object_2 = ""


func update_command_line() -> void:
	# For later improvements: make "Walk to" as the default.
	objectLabel.text = ""
	objectLabel.text +=       command_line.verb
	objectLabel.text += " " + command_line.object_1
	objectLabel.text += " " + command_line.preposition
	objectLabel.text += " " + command_line.object_2


func walk_player_to(a_position: Vector2) -> void:
	var source_position : Vector2 = player.global_position
	var target_position : Vector2 = a_position
	
	orient_player_towards(target_position)
	
	# The path runs through the current room's navigation polygon. If the target
	# is outside it, the path ends at the closest walkable point.
	var nav_map : RID = nav_region.get_navigation_map()
	var new_path : PackedVector2Array = NavigationServer2D.map_get_path(nav_map, source_position, target_position, true)
	line2D.points = new_path
	player.walk_along(new_path)


func skip_dialogue_line() -> void:
	dialogueTimer.stop()
	after_timer_do()


func orient_player_towards(position_of_interest: Vector2) -> void:
	if position_of_interest.x < player.global_position.x:
		player.sprite.flip_h = true
	else:
		player.sprite.flip_h = false


func start_dialogue(element_id: String) -> void:
	if element_id == "":
		# The writer error has already been pushed by the get_id_* functions.
		_end_dialogue()
		return
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
	# Function _on_Player_arrived checks the WALKING_TO_ACTION state
	# and must get it right, regardless.
	set_game_state(WALKING_TO_ACTION)
	walk_player_to(player.global_position)


func render_element(element_id : String) -> void:
	set_dialogue_state(RENDERING_ELEMENT)
	story.SetCurrentElementById(element_id)
	render_current_element()

func render_path(path : Object) -> void:
	set_dialogue_state(RENDERING_ELEMENT)
	story.SelectPath(path)   # also runs the connection scripts
	render_current_element()

func render_current_element() -> void:
	var current_element : Object = story.GetCurrentElement()
	var current_content : String = story.GetCurrentRuntimeContent().strip_edges()
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
	
	# An activity like END GAME starts a transition, which ends the dialogue:
	if State.game == TRANSITIONING:
		return
	
	if dialogueTimer.is_stopped():
		dialogueTimer.wait_time = 0.001
		dialogueTimer.start()


func run_activities(activities : Array, items : Array, exits : Array) -> void:
	
	for activity in activities:
		var activityName : String = attr(activity, "objectName")
		
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
			+ str(exits.size()) + " instead. (Element ID: " + story.GetCurrentElement().Id + ")")
		return

	var exit : ClickableExit = get_exit_node_from_component(exits[0])
	
	dangling_exit = exit
	dangling_dialogue = true


func exit_room_from(exitNode : ClickableExit) -> void:
	# Note: the WALKING_TO_ACTION game state must be set outside this function:
	var next_room_path : String = exitNode.target_room
	var next_player_position : Vector2 = exitNode.target_position
	current_object_clicked = null
	load_room_from_path(next_room_path, next_player_position)


func end_game() -> void:
	set_game_state(TRANSITIONING)
	music_fade(OUT)
	await room_fade(OUT).finished
	get_tree().change_scene_to_file("res://scenes_main/IntroCredits.tscn")


# Each item component's objectName matches an Item resource in res://resources/:
func load_item_from_component(item_component : Object) -> Item:
	var path : String = "res://resources/" + attr(item_component, "objectName").strip_edges() + ".tres"
	if not ResourceLoader.exists(path):
		push_writer_error("No inventory item resource found at " + path)
		return null
	return load(path)


func activity_inventory_add(items_components : Array) -> void:
	for item_component in items_components:
		var new_item : Item = load_item_from_component(item_component)
		if new_item != null and not Inventory.add_item(new_item):
			push_error("Inventory full, can't add " + new_item.object_name)
	
	# The taken items now have a different state, so they leave the room:
	dress_up_room(current_room)
	inventoryGrid.update_inventory_display()


func activity_inventory_remove(items_components : Array) -> void:
	for item_component in items_components:
		var item_to_remove : Item = load_item_from_component(item_component)
		if item_to_remove != null:
			Inventory.remove_item(item_to_remove)
	
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
	
	if not overlapping_data.is_empty():
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
		var objectName : String = attr(speaker_component, "objectName")
		var colour : String = attr(speaker_component, "hexColour")

		var speaker_node : Node = get_speaker_node_by_name(objectName)
		speaker_node.bubble.characterLines.modulate = Color(colour)
		speakers_nodes.append(speaker_node)
		
	return speakers_nodes


func get_exit_node_from_component(exit_component : Object)-> ClickableExit:
	for exit_node in current_room.get_node("Objects").get_children():
		if not exit_node is ClickableExit:
			continue
		if exit_node.get("reply_id") == null:
			continue
		var exit_objectName : String = attr(exit_component, "objectName")
		if exit_node.get("reply_id") == exit_objectName:
			return exit_node
	
	push_writer_error("Can't find tree node for exit " + exit_component.Name)
	return null


func get_speaker_node_by_name(component_objectName : String) -> Node:
	# First check if it's the player:
	if component_objectName == player.objectName:
		return player
	
	for n in current_room.get_node("Objects").get_children():
		if not n is Area2D:
			continue
		if n.get("reply_id") == null:
			continue
		if n.get("reply_id") == component_objectName:
			return n
			
	push_writer_error("Can't find tree node for speaker component with objectName: " + component_objectName)
	return null


func render_title(text : String) -> void:
	titleLabel.text = text
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
		speaker.bubble.characterLines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # Default alignment: CENTER
		await get_tree().process_frame
		# The yielding is needed because Godot needs to draw the label with the current text,
		# for at least 1 frame, to return data like get_line_count() etc.
		# Assignment happens in every iteration, but how many speakers are you gonna get anyway?
		number_of_lines = speaker.bubble.characterLines.get_line_count()
	
		# Positioning the talking bubble, depending on the position of its speaker.
		speaker.bubble.global_position.x = clamp(speaker.global_position.x, MIN_X, MAX_X)
		if speaker.global_position.x < MIN_X - 35:
			speaker.bubble.characterLines.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT # Aligning LEFT
		elif speaker.global_position.x > MAX_X + 35:
			speaker.bubble.characterLines.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT # Aligning RIGHT
	
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

func define_option_txt(path : Object) -> String:
	# This function returns the text that will appear as option for the player.
	# The plugin sets the path's label from the connection labels along the way,
	# or else from the target element's title:
	var text : String = path.label.strip_edges()
	if text == "":
		# If no label or title exists, we gotta throw a writer error,
		# while the game renders "PLACEHOLDER TEXT" as option text.
		push_writer_error("PLACEHOLDER TEXT used for option. Consider adding labels along the way or a title to target element with ID: " + path.TargetElement.Id)
		return "PLACEHOLDER TEXT"
	return text


func render_options() -> void:
	if State.game != DIALOGUE:
		set_game_state(DIALOGUE)
	set_dialogue_state(RENDERING_OPTIONS)

	# The plugin returns null Paths when the element has no valid outputs:
	var paths : Array = []
	var options : Object = story.GenerateCurrentOptions()
	if options != null and options.Paths != null:
		paths = options.Paths

	# If the element has no valid outputs, end the dialogue:
	if paths.is_empty() or dialogue_end:
		_end_dialogue()
		return

	# If the element has only one valid output, follow it immediately:
	if paths.size() == 1:
		render_path(paths[0])
		return

	# If a "follow random" component exists, follow a random output:
	if follow_random_output:
		follow_random_output = false
		render_path(paths.pick_random())
		return

	# Otherwise, we create a button for each option:
	for path in paths:
		create_option_button(define_option_txt(path), path)
	
	# More than MAX_NUMBER_VISIBLE_OPTIONS require arrow buttons, to scroll:
	number_of_visible_options = paths.size()
	var needs_arrows : bool = number_of_visible_options > MAX_NUMBER_VISIBLE_OPTIONS
	optionsArrows.visible = needs_arrows
	arrowButtonDn.disabled = not needs_arrows

	set_dialogue_state(WAITING_CHOICE)


func create_option_button(option_txt : String, path : Object) -> void:
	var option_button : Button = DialogueOptionButton.instantiate()
	option_button.text = option_txt
	option_button.target_id = path.TargetElement.Id
	option_button.pressed.connect(_on_option_button_pressed.bind(path))
	optionsContainer.add_child(option_button)
	option_buttons.append(option_button)


func classify_components(element : Object) -> Dictionary:
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
	
	# Iterate through the element's attached components:
	for component in element.Components:
		if component.Attributes.is_empty():
			push_writer_error("No attributes found in component: " + component.Name)
			continue # go to the next component.
		
		# Finding the component's "type". 
		# "Type" is a custom attribute the Arcweave writer has assigned to components.
		# The following array is to eventually check the component has only one type:
		var component_types : Array = [] # It must have only one member eventually.
		
		for attribute in component.Attributes:
			if attribute.Name != "type":
				continue
			
			var type_name : String = str(attribute.data)
			match type_name:
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
					push_writer_error("Unknown type found for component: " + component.Name)
			
			component_types.append(type_name)

		if component_types.size() == 0:
			push_writer_error("No 'type' attribute in component: " + component.Name)

		if component_types.size() > 1:
			push_writer_error("More than 1 'type' attributes :" + str(component_types) + " in component: " + component.Name)
		# Attention: after the error, we still have the problematic component classified in multiple types.
		
	return components_classified


func run_dialogue_commands(commands : Array) -> void:
	for command in commands:
		var objectName : String = attr(command, "objectName").strip_edges()
		match objectName:
			"pause":
				# This makes a pause AFTER the rendering of the current element.
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

	# Removing tracks from the playlist in a queue fashion, until one plays.
	# The SFXPlayer "finished" signal calls this function again, for the next track.
	while current_playlist.size() > 0:
		var track : Object = current_playlist.pop_front()
		var file_name : String = attr(track, "fileName")
		var path : String = "res://assets/assets_audio/" + file_name
		
		if not ResourceLoader.exists(path):
			push_writer_error("Can't find audio file " + file_name + " in project's assets.")
			continue
		
		sfxPlayer.set_stream(load(path))
		sfxPlayer.play()
		return


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


func _on_Player_arrived() -> void:
	if State.game == EXPLORING:
		return

	if State.game == DIALOGUE:
		push_error("GAME state leak: invalid DIALOGUE state" 
			+ " after player walk finished.")
		return
	if State.game == TRANSITIONING:
		push_error("GAME state leak: invalid TRANSITIONING state " 
			+ " after player walk finished.")
		return

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
	current_target_id = ""


# This is for the dialogue option button (fix the nomenclature at some point):
func _on_option_button_pressed(path : Object) -> void:
	for option_button in optionsContainer.get_children():
		option_button.queue_free()
	arrowButtonDn.disabled = true
	arrowButtonUp.disabled = true
	number_of_visible_options = 0
	option_buttons.clear()
	render_path(path)



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
	
	# While the verb menu is open, the room doesn't react to the mouse:
	# clicking anywhere outside the menu only closes it.
	# (ClickableObjects ignore clicks then, so this is just in case.)
	if State.ui == MENU_OPEN:
		return_ui_to_idle()
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


func after_timer_do() -> void:
	if State.game == TRANSITIONING:
		return
	
	if State.game == DIALOGUE and State.dialogue == PAUSING:
		render_options()
		return
		
	if State.game == DIALOGUE and State.dialogue == RENDERING_ELEMENT:
		reset_dialogue_bubbles()
		if dialogue_pause:
			dialogue_pause = false
			set_dialogue_state(PAUSING)
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


func _end_dialogue() -> void:
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
	
	titleLabel.text = ""
	
	for sb in speakerBubbles:
		sb.global_position = Vector2.ZERO # Getting it out of the screen
		sb.characterLines.text = ""


func check_and_get_main_attributes(component: Object) -> Dictionary:
	var main_attributes : Dictionary = {"error": false}
	if component.GetAttribute("type") == null:
		push_writer_error("No type attribute for component: " + component.Name)
		main_attributes.error = true
	if component.GetAttribute("objectName") == null:
		push_writer_error("No objectName for component: " + component.Name)
		main_attributes.error = true
	if main_attributes.error:
		return main_attributes
	main_attributes.type = str(component.GetAttribute("type").data)
	main_attributes.objectName = str(component.GetAttribute("objectName").data)
	return main_attributes


func check_contains_1(my_array : Array)-> bool:
	if my_array.size() > 1:
		var error_ids : Array = []
		for element in my_array:
			error_ids.append(element.Id)
		push_writer_error("More than 1 element found for specific action: " 
			+ str(error_ids))
		return false

	if my_array.size() == 0:
		return false
		
	return true


# Reads the components of a possible starting element of a player action.
# Starting elements have exactly 2 components: VERB + OBJECT or OBJECT + OBJECT.
# Returns the objectNames of its "actions" (actionVerb components) and "objects"
# (item, character and exit components), or an empty Dictionary if it isn't one.
func get_action_components(element : Object) -> Dictionary:
	if element.Components.size() != 2:
		return {}
	
	var actions : Array = [] # Stores objectNames of actions: examine, handle, etc.
	var objects : Array = [] # Stores objectNames of items, characters, exits.
	for component in element.Components:
		var main_attributes : Dictionary = check_and_get_main_attributes(component)
		if main_attributes.error:
			# Errors thrown already in check_and_get_main_attributes.
			return {}
		
		match main_attributes.type:
			"actionVerb":
				actions.append(main_attributes.objectName)
			"item", "character", "exit":
				objects.append(main_attributes.objectName)
	
	return {"actions": actions, "objects": objects}


func get_id_from_verb_object_reply(verb: String, obj_reply : String)-> String:
	var compatible_elements : Array = [] # Must eventually have exactly 1 member.
	var generic_replies : Array = [] # Must also have 1 member.
	
	for element in get_player_action_elements():
		var components : Dictionary = get_action_components(element)
		if components.is_empty() or components.actions.is_empty():
			continue
		
		if components.actions.size() > 1:
			push_writer_error("Cannot have more than 1 actionVerb components in element " 
				+ element.Id)
			continue
		
		if components.actions[0] != verb:
			# Not the action we are looking for. Continue to next element iteration.
			continue
		
		if components.objects.size() != 1:
			push_writer_error("No object found for action " + verb + " in element " + element.Id)
			continue
		
		if components.objects[0] == obj_reply:
			compatible_elements.append(element)
		elif components.objects[0] == "generic":
			# Not the noun we are looking for, but a generic reply for the verb:
			generic_replies.append(element)
	
	# If we have a specific reply, we return the target element ID:
	if check_contains_1(compatible_elements):
		return compatible_elements[0].Id

	# If we have a generic reply for the verb, we return the target ID:
	if check_contains_1(generic_replies):
		return generic_replies[0].Id
	
	if verb != "walk":
		push_writer_error("Failed to get Target ID for verb " + verb + " and noun " + obj_reply)
	return ""


func get_id_from_objects_replies(obj_reply_1 : String, obj_reply_2 : String) -> String:
	var compatible_elements : Array = [] # Must eventually have exactly 1 member.
	var generic_replies : Array = [] # Ordered from the most specific to the most general case.

	for element in get_player_action_elements():
		var components : Dictionary = get_action_components(element)
		if components.is_empty() or components.objects.size() != 2:
			continue
		var objects : Array = components.objects
		
		# Cases of "generic" use:
		
		if objects[0] == objects[1]:
			# No point using an object to itself.
			# Inventory functions (should) block that.
			# Unless encountered reply for USE GENERIC ON GENERIC.
			if objects[0] == "generic":
				generic_replies.push_back(element) # The most general case goes last.
			continue
		# GENERIC + one of our objects is more specific, so it goes first:
		if objects[0] == "generic":
			if objects[1] == obj_reply_1 or objects[1] == obj_reply_2:
				generic_replies.push_front(element)
			continue
		if objects[1] == "generic":
			if objects[0] == obj_reply_1 or objects[0] == obj_reply_2:
				generic_replies.push_front(element)
			continue

		# Cases of specific objects use, in either order:
		if (objects[0] == obj_reply_1 and objects[1] == obj_reply_2) \
				or (objects[0] == obj_reply_2 and objects[1] == obj_reply_1):
			compatible_elements.append(element)
	
	# If we have a specific reply, we return the target element ID:
	if check_contains_1(compatible_elements):
		return compatible_elements[0].Id

	# Else we return the target ID of the first (most specific) of the generic cases:
	if generic_replies.size() > 0:
		return generic_replies[0].Id
	
	push_writer_error("Failed to get Target ID for nouns " + obj_reply_1 + " and " + obj_reply_2)
	return ""


func _on_inventory_container_mouse_in_slot(item : Item) -> void:
	
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

		IDLE:
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
		
		IDLE:
			erase_command_line()


func _on_inventory_container_item_selected(item : Item) -> void:
	current_object_clicked = null
	# This is called when the inventory container's signal "item_selected" is received:
	match State.ui:
		
		MENU_OPEN:
			# While the verb menu is open, clicking anywhere outside it only closes it:
			return_ui_to_idle()
		
		IDLE:
			if inventory_item_selected is Item:
				push_error("Upon clicking inventory item: UI not in HOLDING_ITEM state, "
					+ " but inventory_item_selected not NULL.")
				return
			
			set_ui_state(HOLDING_ITEM, item)
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


func _on_inventory_container_item_examined(item : Item) -> void:
	current_object_clicked = null
	# This is called when the inventory container's signal "item_examined" is received
	# In other words, when you right click an inventory item.
	match State.ui:
		
		MENU_OPEN:
			# While the verb menu is open, clicking anywhere outside it only closes it:
			return_ui_to_idle()
		
		IDLE:
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


func set_cursor_hovering_over(aNode : Area2D) -> void:
	set_cursor(aNode)



func _on_OptionArrowButtonUp_pressed() -> void:
	arrowButtonDn.disabled = false
	for i in range(option_buttons.size(), 0, -1):
		if not option_buttons[i - 1].visible:
			option_buttons[i - 1].visible = true
			number_of_visible_options += 1
			if number_of_visible_options == option_buttons.size():
				arrowButtonUp.disabled = true
			break


func _on_OptionArrowButtonDn_pressed() -> void:
	arrowButtonUp.disabled = false
	for ob in option_buttons:
		if ob.visible:
			ob.visible = false
			number_of_visible_options -= 1
			if number_of_visible_options <= MAX_NUMBER_VISIBLE_OPTIONS:
				arrowButtonDn.disabled = true
			break


func _on_MusicSlider_value_changed(value: float) -> void:
	set_volumes_from_linear(value, registered_settings.sfx_volume)


func _on_SFXSlider_value_changed(value: float) -> void:
	set_volumes_from_linear(registered_settings.music_volume, value)


func _on_DialogueSpeedSlider_value_changed(value: float) -> void:
	set_dialogue_speed(int(value))


func _on_WalkSpeedSlider_value_changed(value: float) -> void:
	set_walk_speed(value)


func _on_SettingsMenu_opened() -> void:
	show_cursor(false)


func _on_SFXPlayer_finished() -> void:
	play_next_from_playlist()


func _on_SettingsMenu_closed() -> void:
	save_settings()
	show_cursor(true) # Without resetting it.


func _on_Save_pressed() -> void:
	save_state()


func _on_SettingsMenu_restart() -> void:
	set_game_state(TRANSITIONING)
	music_fade(OUT)
	await room_fade(OUT).finished
	get_tree().reload_current_scene()



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
			pass # While the verb menu is open, the room doesn't react to the mouse.
		
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
			pass # While the verb menu is open, the room doesn't react to the mouse.
			
		IDLE:
			erase_command_line()
			set_cursor_hovering_over(null)

