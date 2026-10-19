extends CenterContainer

# This inventory system is stol-- em... BORROWED from
# a YouTube tutorial by HeartBeast.

signal item_selected(item : Item)
signal item_examined(item : Item)
signal mouse_in_slot(item : Item)
signal mouse_out_of_slot

var inventory : InventoryHandler = preload("res://resources/Inventory.tres")
var state_handler : StateHandler = preload("res://resources/state_handler.tres")
@onready var itemTextureRect : TextureRect = $ItemTextureRect


func display_item(item : Item) -> void:
	itemTextureRect.texture = item.texture if item != null else null


func what_item() -> Item:
	# The slot's index in its parent container is the item's index in the inventory:
	return inventory.select_item(get_index())


func _on_InventorySlot_gui_input(event: InputEvent) -> void:
	if state_handler.game == state_handler.DIALOGUE:
		return

	var item : Item = what_item()
	if item == null:
		return

	if event.is_action_pressed("click"):
		item_selected.emit(item)

	if event.is_action_pressed("right_click"):
		item_examined.emit(item)


func _on_InventorySlot_mouse_entered() -> void:
	mouse_in_slot.emit(what_item())


func _on_InventorySlot_mouse_exited() -> void:
	mouse_out_of_slot.emit()
