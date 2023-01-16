extends HBoxContainer

# This inventory system is stol-- em... BORROWED from
# a YouTube tutorial by HeartBeast.

const Inventory = preload("res://resources/Inventory.tres")
const NewSlot = preload("res://scenes_inventory/InventorySlot.tscn")

signal item_selected(item)
signal item_examined(item)
signal mouse_in(item)
signal mouse_out

func _ready():
	var _con : int = 0
	create_empty_slots()
	update_inventory_display()
	_con = self.connect("item_selected", get_tree().current_scene, "_on_inventory_container_item_selected")
	_con = self.connect("item_examined", get_tree().current_scene, "_on_inventory_container_item_examined")
	_con = self.connect("mouse_in", get_tree().current_scene, "_on_inventory_container_mouse_in_slot")
	_con = self.connect("mouse_out", get_tree().current_scene, "_on_inventory_container_mouse_out_of_slot")


func create_empty_slots():
	# We create 8 empty inventory slots and
	# connect their signals with this script.
	for _i in range(8):
		var newSlot = NewSlot.instance()
		add_child(newSlot)
		newSlot.connect("item_selected", self, "_on_slot_item_selected")
		newSlot.connect("item_examined", self, "_on_slot_item_examined")
		newSlot.connect("mouse_in_slot", self, "_on_slot_mouse_in_slot")
		newSlot.connect("mouse_out_of_slot", self, "_on_slot_mouse_out_of_slot")


func update_inventory_display():
	for i in Inventory.items.size():
		update_inventory_slot(i)

func update_inventory_slot(item_index):
	var inventorySlotDisplay = get_child(item_index)
	var item = Inventory.items[item_index]
	inventorySlotDisplay.display_item(item)


func _on_slot_item_examined(item):
	# The container receives the signal from the slot and emits its own to Main:
	emit_signal("item_examined", item)


func _on_slot_item_selected(item):
	# The container receives the signal from the slot and emits its own to Main:
	emit_signal("item_selected", item)


func _on_slot_mouse_in_slot(item):
	emit_signal("mouse_in", item)

func _on_slot_mouse_out_of_slot():
	emit_signal("mouse_out")
