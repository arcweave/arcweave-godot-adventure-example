extends Node

# This is the game's only singleton (yay!).
# The path of the saved game, used by every scene that saves or loads:
const SAVED_GAME_PATH = "user://save.dat"
# Increase this when the save format changes. The Godot 3 version of the game
# wrote saves without a version, in a format this version can't load.
const SAVE_VERSION = 2

# Set to true when the game is about to load.
# See intro_credits.gd
var load_game : bool = false


# Returns the saved game data, or an empty Dictionary if there is no
# saved game this version can load.
func read_saved_game() -> Dictionary:
	if not FileAccess.file_exists(SAVED_GAME_PATH):
		return {}
	var file := FileAccess.open(SAVED_GAME_PATH, FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var()
	file.close()
	if not data is Dictionary or data.get("version") != SAVE_VERSION:
		return {}
	return data


func save_file_exists() -> bool:
	return not read_saved_game().is_empty()
