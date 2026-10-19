extends HBoxContainer

# This inventory system is stol-- em... BORROWED from
# a YouTube tutorial by HeartBeast.

const NewSlot : PackedScene = preload("res://scenes_inventory/InventorySlot.tscn")

# The container passes on its slots' signals. Main connects to them (see Main.tscn):
signal item_selected(item : Item)
signal item_examined(item : Item)
signal mouse_in(item : Item)
signal mouse_out

var Inventory : InventoryHandler = preload("res://resources/Inventory.tres")


func _ready() -> void:
	create_empty_slots()
	update_inventory_display()


func create_empty_slots() -> void:
	# We create an empty inventory slot for each inventory item
	# and pass their signals on.
	for _i in Inventory.items.size():
		var newSlot : Node = NewSlot.instantiate()
		add_child(newSlot)
		newSlot.item_selected.connect(item_selected.emit)
		newSlot.item_examined.connect(item_examined.emit)
		newSlot.mouse_in_slot.connect(mouse_in.emit)
		newSlot.mouse_out_of_slot.connect(mouse_out.emit)


func update_inventory_display() -> void:
	for i in Inventory.items.size():
		get_child(i).display_item(Inventory.items[i])
