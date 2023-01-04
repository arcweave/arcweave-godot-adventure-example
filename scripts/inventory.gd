extends Resource
class_name InventoryHandler

#signal items_changed(indexes)
#signal item_selected(item)


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


#
#func activity_inventory_add(items_components : Array) -> void:
#	for item in items_components:
#		var item_objectName : String = item.getAttributeByName("objectName").value.data.strip_edges()
#		var new_item : Resource = load("res://InventoryItems/" + item_objectName + ".tres")
#
#		for i in Inventory.items.size():
#			if Inventory.items[i] == null:
#				Inventory.items[i] = new_item
#				break
#
#		dress_up_room(get_node("Location"))
#		inventoryGrid.update_inventory_display()




	

#func set_item(item_index, item):
#	var previousItem = items[item_index]
#	items[item_index] = item
#	emit_signal("items_changed", [item_index])
#	return previousItem


#func remove_item(item_index):
#	var previousItem = items[item_index]
#	items[item_index] = null
#	emit_signal("items_changed", [item_index])
#	return previousItem
