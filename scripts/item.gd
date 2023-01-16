extends Resource
class_name Item

# Items are the items in the inventory slots.
# Not to be confused with ClickableObject > ClickableItems,
# which are the objects / items (and characters) in a room.

# The object's name, as shown in the command line:
export(String) var object_name = ""
# The objectName, as in the Arcweave component:
export(String) var reply_id = ""
# The texture of the inventory item:
export(Texture) var texture
