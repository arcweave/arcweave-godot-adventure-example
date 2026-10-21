extends Resource
class_name Item

# Items are the items in the inventory slots.
# Not to be confused with ClickableObject > ClickableItems,
# which are the objects / items (and characters) in a room.

# The object's name, as shown in the command line:
@export var object_name: String = ""
# The objectName, as in the Arcweave component:
@export var reply_id: String = ""
# The texture of the inventory item:
@export var texture: Texture2D
