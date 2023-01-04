extends Object
class_name StateExport

var t_andreasThanks: bool
var t_miniGame: int
var i_key: int
var andreasRoll: int
var i_magazines: int
var regrets: int
var t_andreasPlace: int
var t_magazines: int
var t_give_gameScripts: int
var i_gameScripts: int
var t_key: int
var t_andreasWho: int
var t_andreasBottleneck: int
var t_therapy: int
var t_amstrad: int
var i_amstrad: int
var counter: int
var playerRoll: int
var t_hateLocked: bool
var t_andreasBlessing: bool
var t_gameScripts: int

var defaults = {
	"t_andreasThanks": false,
	"t_miniGame": 0,
	"i_key": 0,
	"andreasRoll": 0,
	"i_magazines": 1,
	"regrets": 0,
	"t_andreasPlace": 0,
	"t_magazines": 0,
	"t_give_gameScripts": 0,
	"i_gameScripts": 1,
	"t_key": 0,
	"t_andreasWho": 0,
	"t_andreasBottleneck": 0,
	"t_therapy": 0,
	"t_amstrad": 0,
	"i_amstrad": 1,
	"counter": 0,
	"playerRoll": 0,
	"t_hateLocked": false,
	"t_andreasBlessing": false,
	"t_gameScripts": 0
}

func _init():
	for variable in self.defaults:
		self[variable] = self.defaults[variable]

func reset_all_vars(except_vars: Array):
	for variable in self.defaults:
		if not(variable in except_vars):
			self[variable] = self.defaults[variable]

func reset_vars(vars: Array):
	for variable in vars:
		self[variable] = self.defaults[variable]

func get_var(name):
	return self[name]

func set_var(name, value):
	self[name] = value

func get_current_state() -> Dictionary:
	var result = {}
	for variable in self.defaults:
		result[variable] = self[variable]
	return result

func set_state(state: Dictionary):
	for variable in state:
		self[variable] = state[variable]
