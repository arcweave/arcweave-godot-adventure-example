extends Resource
class_name InventoryHandler

# This inventory system is stol-- em... BORROWED from
# a YouTube tutorial by HeartBeast.

# The inventory slots. Empty slots are null:
@export var items : Array[Item] = [
	null, null, null, null, null, null, null, null
]


func select_item(item_index : int) -> Item:
	return items[item_index]


# Puts the item in the first empty slot. Returns false if the inventory is full.
func add_item(item : Item) -> bool:
	var empty_slot : int = items.find(null)
	if empty_slot == -1:
		return false
	items[empty_slot] = item
	return true


# Removes the item and moves the next ones one slot towards the start,
# so the empty slots stay at the end.
func remove_item(item : Item) -> void:
	var index : int = items.find(item)
	if index == -1:
		return
	items.remove_at(index)
	items.append(null)


func get_inventory_paths() -> Array:
	var result : Array = []
	for item in items:
		if item != null:
			result.append(item.resource_path)
	return result


func set_inventory_from_paths(resource_paths : Array) -> void:
	clear_inventory()
	for path in resource_paths:
		add_item(load(path))


func clear_inventory() -> void:
	items.fill(null)
