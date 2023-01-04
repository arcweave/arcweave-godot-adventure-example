extends CenterContainer

signal item_selected(item)
signal item_examined(item)
signal mouse_in_slot(item)
signal mouse_out_of_slot()

var inventory = preload("res://resources/Inventory.tres")
var state_handler = preload("res://resources/state_handler.tres")
onready var itemTextureRect = $ItemTextureRect


func display_item(item):
	if item is Item:
		itemTextureRect.texture = item.texture
	else:
		itemTextureRect.texture = null

func what_item():
	var item_index = get_index() # The slot's index as to its parent container.
	var item = inventory.select_item(item_index)
	return item
	

func _on_InventorySlot_gui_input(event: InputEvent) -> void:
	if state_handler.game == state_handler.DIALOGUE:
		return
	
	if event.is_action_pressed("click"):
		var item = what_item()
		
		if item == null:
			return
		
		emit_signal("item_selected", item)
		
	if event.is_action_pressed("right_click"):
		var item = what_item()
		
		if item == null:
			return
			
		emit_signal("item_examined", item)


func _on_InventorySlot_mouse_entered() -> void:
	var item = what_item()
	emit_signal("mouse_in_slot", item)


func _on_InventorySlot_mouse_exited() -> void:
	emit_signal("mouse_out_of_slot")
