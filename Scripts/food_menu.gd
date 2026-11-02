class_name FoodMenu
extends Control

## The snack bag: a sheet that slides up from the bottom with a card for every food.
## Each card's picture is a little render of the food's model, so new foods need no art.

signal food_chosen(food: FoodData)

@export var foods: Array[FoodData] = []
@export var icon_size := 256
@export var slide_time := 0.25

## 0 = tucked below the screen, 1 = all the way up.
var _slide := 0.0:
	set(value):
		_slide = value
		_sheet.position.y = size.y - _sheet.size.y * value
		_dim.modulate.a = value
var _tween: Tween

@onready var _dim: ColorRect = $Dim
@onready var _sheet: Control = $Sheet
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	hide()
	_dim.gui_input.connect(_on_dim_gui_input)
	%CloseButton.pressed.connect(close)
	for food in foods:
		var card := Button.new()
		card.text = food.title
		card.icon = _render_icon(food)
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		card.custom_minimum_size = Vector2(140, 170)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_choose.bind(food))
		_grid.add_child(card)


func open() -> void:
	show()
	_slide_to(1.0)


func close() -> void:
	_slide_to(0.0).tween_callback(hide)


func _choose(food: FoodData) -> void:
	food_chosen.emit(food)
	close()


func _slide_to(target: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_slide", target, slide_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _tween


## Renders [param food] once into a small transparent picture.
func _render_icon(food: FoodData) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE * icon_size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)

	var model := food.instantiate_fitted(0.2)
	model.rotation.y = deg_to_rad(-25.0)
	viewport.add_child(model)

	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.12, 0.45), Vector3.ZERO)

	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.look_at_from_position(Vector3(1.0, 1.5, 2.0), Vector3.ZERO)
	return viewport.get_texture()


func _on_dim_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()
