class_name CostumeMenu
extends BottomSheet

## The closet: a card for every costume in [member costumes], each a little render of him
## wearing it, so a new costume only needs its resource adding to the list.

signal costume_chosen(costume: CostumeData)

@export var costumes: Array[CostumeData] = []
## Dressed and rendered for each card's picture.
@export var character_scene: PackedScene = preload("res://Blender/Chars/judson.tscn")
## Where the card camera looks from and at, in his space (metres; +Z is in front of him).
@export var camera_eye := Vector3(0.0, 0.6, 2.4)
@export var camera_target := Vector3(0.0, 0.45, 0.0)

## Each costume's card picture, for the HUD's costume button.
var icons := {}


func _ready() -> void:
	super()
	for costume in costumes:
		if costume and costume.model:
			icons[costume] = _render(costume)
			_add_card(costume.title, icons[costume], costume_chosen.emit.bind(costume))


func _render(costume: CostumeData) -> Texture2D:
	var model := character_scene.instantiate() as Node3D
	# just the body: his script would add taps, sounds and an idle loop
	model.set_script(null)
	costume.dress(model)
	# turned a touch, so the print reads but he isn't flat-on
	model.rotation.y = deg_to_rad(-15.0)
	var texture := _snapshot(model, camera_eye, camera_target)
	# idle's first frame, so he isn't in a T-pose
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", Judson.LIBRARIES[&"idle"].get_animation(&"mixamo_com"))
	var player := Judson.animation_player(model)
	player.add_animation_library(&"preview", library)
	player.play(&"preview/idle")
	player.seek(0.0, true)
	player.pause()
	return texture
