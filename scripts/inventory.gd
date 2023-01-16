extends Resource
class_name InventoryHandler

# This inventory system is stol-- em... BORROWED from
# a YouTube tutorial by HeartBeast.

export(Array, Resource) var items = [
	null, null, null, null, null, null, null, null
]


func select_item(item_index):
	var selected_item = items[item_index]
	return selected_item


func get_inventory_paths() -> Array:
	var result = []
	for item in items:
		if item is Item:
			result.append(item.resource_path)
	return result


func set_inventory_from_paths(resource_paths : Array) -> void:
	clear_inventory()
	for path in resource_paths:
		print("Setting " + path + "...")
		var new_item : Resource = load(path)
		
		for i in items.size():
			if items[i] != null:
				continue
				
			items[i] = new_item
			print("Slot is now" + str(items[i]))
			break
	print(items)
	

func clear_inventory()->void:
	print("Clearing up inventory...")
	for i in items.size():
		items[i] = null
