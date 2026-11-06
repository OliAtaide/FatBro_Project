extends Resource
class_name HatData

@export var title : String = ''
@export var model : PackedScene = null
@export_group("Fit tweaks")
## Multiplies the automatic fit (1 = as wide as his head allows).
@export var scale_tweak := 1.0
## Nudge from the top of his head, in metres (+Y up, +Z forward).
@export var offset := Vector3.ZERO
## Extra turn, in degrees (tilt it rakishly with Z).
@export var rotation_tweak := Vector3.ZERO


## An instance of [member model] scaled so its widest side is [param width] metres, with
## the middle of its brim at the origin so it sits on whatever it's added to.
func instantiate_fitted(width: float) -> Node3D:
	var holder := Node3D.new()
	var instance := model.instantiate() as Node3D
	holder.add_child(instance)
	var bounds := FoodData._bounds(instance)
	var widest := maxf(bounds.size.x, bounds.size.z)
	var fit := width * scale_tweak / widest if widest > 0.0 else 1.0
	var bottom_center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	instance.scale = Vector3.ONE * fit
	instance.position = -bottom_center * fit
	holder.position = offset
	holder.rotation_degrees = rotation_tweak
	return holder
