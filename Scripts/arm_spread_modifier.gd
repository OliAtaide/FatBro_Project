@tool
extends SkeletonModifier3D
class_name ArmSpreadModifier3D

## Swings the upper arms outward after the animation is applied, around each shoulder.
## Animations made for slim bodies (e.g. Mixamo) keep the arms close in, which pushes them
## through a wide torso; this keeps their motion but moves it clear of the body.
## Make it a child of the Skeleton3D. Expects the skeleton's forward axis to be +Z.
##
## On top of that, an emote can steer his arms for its own moves (see [EmoteData]): more
## spread to clear his big head, or swung forward and in so his short arms reach round
## his belly. Those are the extra_*, inward and forward values, all 0 when he's not emoting.

@export_range(0.0, 60.0, 0.5, "degrees") var spread_degrees := 22.0
@export var upper_arm_bones: Array[StringName] = [&"LeftUpperArm", &"RightUpperArm"]
## Added to [member spread_degrees] (negative brings the arms back in).
@export_range(-60.0, 60.0, 0.5, "degrees") var extra_spread_degrees := 0.0
## Swings the arms forward and up at the shoulders (around the side-to-side axis).
## Negative swings them back.
@export_range(-60.0, 60.0, 0.5, "degrees") var forward_degrees := 0.0
## Tips the forearms forward at the elbows (a raised forearm leans out in front of him), so
## his hands get out past his belly. Negative tips them back.
@export_range(-90.0, 90.0, 0.5, "degrees") var forearm_forward_degrees := 0.0
## Then swings the arms round toward his middle at the shoulders (around the vertical), so
## arms swung forward bring his hands together in front of him. Negative swings them apart.
@export_range(-90.0, 90.0, 0.5, "degrees") var inward_degrees := 0.0
@export var lower_arm_bones: Array[StringName] = [&"LeftLowerArm", &"RightLowerArm"]


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
		var side := signf(pose.origin.x)
		var spread := Basis(Vector3.BACK, deg_to_rad(spread_degrees + extra_spread_degrees) * side)
		var forward := Basis(Vector3.RIGHT, -deg_to_rad(forward_degrees))
		# (last, so it turns the arms as swung forward: hanging straight down, it'd do nothing)
		var inward := Basis(Vector3.UP, -deg_to_rad(inward_degrees) * side)
		# (rotating the basis only, so each arm pivots at its shoulder)
		pose.basis = inward * forward * spread * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
	if is_zero_approx(forearm_forward_degrees):
		return
	for bone_name in lower_arm_bones:
		var bone := skeleton.find_bone(bone_name)
		if bone == -1:
			continue
		# (read after the upper arms moved, so it pivots at the elbow where it is now)
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(Vector3.RIGHT, deg_to_rad(forearm_forward_degrees)) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
