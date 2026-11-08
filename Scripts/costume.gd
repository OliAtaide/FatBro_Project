extends Resource
class_name CostumeData

## An outfit for Judson: the model his meshes are taken from, plus an optional print on
## the front of his shirt. Every costume model must share his skeleton (same bones and
## node paths), since only the meshes are swapped; see [method dress].

@export var title : String = ''
@export var model : PackedScene = null
## Laid over the chest. Needs a model whose shirt front is unwrapped flat (judson2.blend).
@export var print : Texture2D = null

@export_group("Print placement")
## Middle of the print, in the model's texture (UV).
@export var print_center := Vector2(0.5, 0.66)
## The box the print is fitted into (keeping its shape), in UV.
@export var print_box := Vector2(0.22, 0.16)
## How much UV a metre of chest covers, across and down (the unwrap isn't square, so the
## print is stretched to match and comes out the right shape on him).
@export var uv_per_metre := Vector2(0.625, 0.964)
@export_group("")

## Puts this costume on [param character] (a Judson, or any instance of a costume model):
## each of its meshes is replaced by the one at the same path in [member model], and the
## print is applied.
func dress(character: Node3D) -> void:
	if model:
		var source := model.instantiate() as Node3D
		for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
			var target := character.get_node_or_null(source.get_path_to(mesh)) as MeshInstance3D
			if target:
				target.mesh = mesh.mesh
				target.skin = mesh.skin
				# his own material copies were made from the old mesh's materials
				for surface in target.get_surface_override_material_count():
					target.set_surface_override_material(surface, null)
		source.free()
	apply_print(character)


## Sets just the print, for a character that already has [member model]'s meshes.
func apply_print(character: Node3D) -> void:
	var material := Judson.own_material(character, Judson.BODY_MESH)
	if not material:
		if print:
			push_warning("Costume %s: the body's material can't take a print" % title)
		return
	material.set_shader_parameter(&"print_tex", print)
	material.set_shader_parameter(&"print_rect", print_rect() if print else Vector4.ZERO)


## Where the print lands in UV: as big as fits in [member print_box] at its own shape.
func print_rect() -> Vector4:
	var aspect := print.get_size().aspect()
	# its shape in UV terms: a print w wide (metres) is w*uv.x across and w/aspect*uv.y down
	var uv_aspect := aspect * uv_per_metre.x / uv_per_metre.y
	var size := Vector2(print_box.x, print_box.x / uv_aspect)
	if size.y > print_box.y:
		size = Vector2(print_box.y * uv_aspect, print_box.y)
	var corner := print_center - size / 2.0
	return Vector4(corner.x, corner.y, size.x, size.y)
