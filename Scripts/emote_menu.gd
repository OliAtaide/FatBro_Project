class_name EmoteMenu
extends BottomSheet

## The emote roster: a card for every emote in [member emotes], each showing him partway
## through the move, so a new emote only needs its resource adding to the list.

signal emote_chosen(emote: EmoteData)

@export var emotes: Array[EmoteData] = []
## Posed and rendered for each card's picture.
@export var character_scene: PackedScene = preload("res://Blender/Chars/judson.tscn")
## How far through each emote (0 to 1) its card's pose is taken from.
@export_range(0.0, 1.0) var pose_at := 0.5
## Where the card camera looks from and at, in his space (metres; +Z is in front of him).
@export var camera_eye := Vector3(0.0, 0.55, 2.6)
@export var camera_target := Vector3(0.0, 0.45, 0.0)


func _ready() -> void:
	super()
	for emote in emotes:
		if emote and emote.animation:
			_add_card(emote.title, _render_pose(emote), emote_chosen.emit.bind(emote))


func _render_pose(emote: EmoteData) -> Texture2D:
	var clip := emote.clip()
	var model := character_scene.instantiate() as Node3D
	# just the body: his script would add taps, sounds and an idle loop
	model.set_script(null)
	# (so the arms get steered for this emote as they will be when he does it)
	for modifier in model.find_children("*", "SkeletonModifier3D", true, false):
		if modifier is ArmSpreadModifier3D:
			modifier.extra_spread_degrees = emote.arm_spread
			modifier.inward_degrees = emote.arm_inward
			modifier.forward_degrees = emote.arm_forward
			modifier.forearm_forward_degrees = emote.forearm_forward
	var texture := _snapshot(model, camera_eye, camera_target)
	var library := AnimationLibrary.new()
	library.add_animation(&"pose", clip)
	var player := Judson.animation_player(model)
	player.add_animation_library(&"preview", library)
	player.play(&"preview/pose")
	player.seek(clip.length * pose_at, true)
	player.pause()
	return texture
