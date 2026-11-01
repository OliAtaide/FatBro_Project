@tool
extends SkeletonModifier3D
class_name ArmSpreadModifier3D

## Swings the upper arms outward after the animation is applied, around each shoulder.
## Animations made for slim bodies (e.g. Mixamo) keep the arms close in, which pushes them
## through a wide torso; this keeps their motion but moves it clear of the body.
## Make it a child of the Skeleton3D. Expects the skeleton's forward axis to be +Z.

@export_range(0.0, 60.0, 0.5, "degrees") var spread_degrees := 22.0
@export var upper_arm_bones: Array[StringName] = [&"LeftUpperArm", &"RightUpperArm"]

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if not skeleton:
		return
	for bone_name in upper_arm_bones:
		var bone := skeleton.find_bone(bone_name)
		if bone == -1:
			continue
		var pose := skeleton.get_bone_global_pose(bone)
		# Outward is toward the arm's own side of the body: +X for the left arm, -X for the right
		var angle := deg_to_rad(spread_degrees) * signf(pose.origin.x)
		pose.basis = Basis(Vector3.FORWARD.abs(), angle) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
