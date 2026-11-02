extends Resource
class_name FoodData

@export var title : String = ''
@export var model : PackedScene = null


## An instance of [member model], centred on its own origin and scaled so its longest
## side is [param size] metres. (The models come in at all sorts of scales.)
func instantiate_fitted(size: float) -> Node3D:
	var holder := Node3D.new()
	var instance := model.instantiate() as Node3D
	holder.add_child(instance)
	var bounds := _bounds(instance)
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit := size / longest if longest > 0.0 else 1.0
	instance.scale = Vector3.ONE * fit
	instance.position = -bounds.get_center() * fit
	return holder


## The model's bounding box, in its own space. Works before it's in the tree.
static func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var to_model := Transform3D.IDENTITY
		var node: Node = mesh
		while node != model:
			to_model = (node as Node3D).transform * to_model
			node = node.get_parent()
		var box := to_model * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
