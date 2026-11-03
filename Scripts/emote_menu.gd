class_name EmoteMenu
extends BottomSheet

## The emote roster: a card for every emote in [constant Judson.EMOTES], each showing
## him partway through the move, so a new emote only needs adding there.

signal emote_chosen(animation: StringName)

## Posed and rendered for each card's picture.
@export var character_scene: PackedScene = preload("res://Blender/judson.tscn")
## How far through each emote (0 to 1) its card's pose is taken from.
@export_range(0.0, 1.0) var pose_at := 0.5
## Where the card camera looks from and at, in his space (metres; +Z is in front of him).
@export var camera_eye := Vector3(0.0, 0.55, 2.6)
@export var camera_target := Vector3(0.0, 0.45, 0.0)


func _ready() -> void:
	super()
	for animation: StringName in Judson.EMOTES:
		_add_card(Judson.EMOTES[animation], _render_pose(Judson.clip(animation)),
				emote_chosen.emit.bind(animation))


func _render_pose(clip: Animation) -> Texture2D:
	var model := character_scene.instantiate() as Node3D
	# just the body: his script would add taps, sounds and an idle loop
	model.set_script(null)
	var texture := _snapshot(model, camera_eye, camera_target)
	var library := AnimationLibrary.new()
	library.add_animation(&"pose", clip)
	var player := model.find_children("*", "AnimationPlayer").front() as AnimationPlayer
	player.add_animation_library(&"preview", library)
	player.play(&"preview/pose")
	player.seek(clip.length * pose_at, true)
	player.pause()
	return texture
