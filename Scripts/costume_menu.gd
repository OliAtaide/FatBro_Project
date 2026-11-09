class_name CostumeMenu
extends BottomSheet

## The closet: a card for every costume in [member costumes], each a little render of him
## wearing it, so a new costume only needs its resource adding to the list. Under them,
## rows of swatches dye his shirt and hair; those apply straight away and leave it open.

signal costume_chosen(costume: CostumeData)
signal shirt_color_chosen(color: Color)
signal hair_color_chosen(color: Color)

@export var costumes: Array[CostumeData] = []
## Swatches for his shirt (white is undyed) and hair.
@export var shirt_colors: Array[Color] = [Color.WHITE, Color("e63946"), Color("f4a261"),
		Color("ffd23f"), Color("52b788"), Color("4895ef"), Color("9b5de5"), Color("f15bb5"),
		Color("6c757d"), Color("2b2d42")]
@export var hair_colors: Array[Color] = [Color.BLACK, Color("4a2c17"), Color("8b5a2b"),
		Color("e8c872"), Color("c1440e"), Color("b8b8b8"), Color("3a86ff"), Color("ff5fa2"),
		Color("38b000")]
@export var swatch_size := 56.0
## Dressed and rendered for each card's picture.
@export var character_scene: PackedScene = preload("res://Blender/Chars/judson.tscn")
## Where the card camera looks from and at, in his space (metres; +Z is in front of him).
@export var camera_eye := Vector3(0.0, 0.6, 2.4)
@export var camera_target := Vector3(0.0, 0.45, 0.0)

## Each costume's card picture, for the HUD's costume button.
var icons := {}

var _shirt_swatches := {}
var _hair_swatches := {}


func _ready() -> void:
	super()
	for costume in costumes:
		if costume and costume.model:
			icons[costume] = _render(costume)
			_add_card(costume.title, icons[costume], costume_chosen.emit.bind(costume))
	_shirt_swatches = _add_swatches("Cor da Camisa", shirt_colors, shirt_color_chosen)
	_hair_swatches = _add_swatches("Cor do Cabelo", hair_colors, hair_color_chosen)


## Rings the swatches matching [param shirt] and [param hair], as the current picks.
func show_colors(shirt: Color, hair: Color) -> void:
	_select(_shirt_swatches, shirt)
	_select(_hair_swatches, hair)


## A labelled row of colour buttons under the cards. Returns the buttons, keyed by colour.
func _add_swatches(label: String, colors: Array[Color], chosen: Signal) -> Dictionary:
	var heading := Label.new()
	heading.text = label
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 10)
	row.add_theme_constant_override(&"v_separation", 10)
	var swatches := {}
	for color in colors:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2.ONE * swatch_size
		swatch.focus_mode = Control.FOCUS_NONE
		for state in [&"normal", &"hover", &"pressed", &"disabled"]:
			swatch.add_theme_stylebox_override(state, _swatch_style(color, false))
		swatch.pressed.connect(func() -> void:
			_select(swatches, color)
			chosen.emit(color))
		row.add_child(swatch)
		swatches[color] = swatch
	var box := _grid.get_parent()
	box.add_child(heading)
	box.add_child(row)
	return swatches


func _select(swatches: Dictionary, picked: Color) -> void:
	for color: Color in swatches:
		var selected := color.is_equal_approx(picked)
		for state in [&"normal", &"hover", &"pressed", &"disabled"]:
			swatches[color].add_theme_stylebox_override(state, _swatch_style(color, selected))


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(swatch_size / 2.0))
	# the current pick gets a thick teal ring; the rest a thin grey one (so white shows up)
	style.set_border_width_all(5 if selected else 2)
	style.border_color = Color(0.1, 0.55, 0.55) if selected else Color(0.0, 0.0, 0.0, 0.25)
	return style


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
