extends Node3D

# Stops this scene's meshes from casting real-time shadows. Runs only in game,
# so the shadows already baked into the lightmap stay. Meant for heavy props
# that would otherwise be redrawn into the omni light's shadow map every frame.


func _ready() -> void:
	for mesh in find_children("*", "GeometryInstance3D"):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
