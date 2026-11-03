class_name BottomSheet
extends Control

## A sheet that slides up from the bottom of the screen with a grid of cards. Picking a
## card, tapping the dimmed backdrop or pressing the close button puts it away again.

## Heading shown at the top of the sheet.
@export var title := ""
@export var slide_time := 0.25
## Size (pixels) of the pictures rendered by [method _snapshot].
@export var icon_size := 256

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
	%Title.text = title
	_dim.gui_input.connect(_on_dim_gui_input)
	%CloseButton.pressed.connect(close)


func open() -> void:
	show()
	_slide_to(1.0)


func close() -> void:
	_slide_to(0.0).tween_callback(hide)


## Adds a card that calls [param on_pressed] and then closes the sheet.
func _add_card(text: String, icon: Texture2D, on_pressed: Callable) -> Button:
	var card := Button.new()
	card.text = text
	card.icon = icon
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.custom_minimum_size = Vector2(140, 170)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.pressed.connect(func() -> void:
		on_pressed.call()
		close())
	_grid.add_child(card)
	return card


## Renders [param subject] once into a small transparent picture, seen from [param eye].
func _snapshot(subject: Node3D, eye: Vector3, target: Vector3, fov := 30.0) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE * icon_size
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	viewport.add_child(subject)

	var camera := Camera3D.new()
	camera.fov = fov
	viewport.add_child(camera)
	camera.look_at_from_position(eye, target)

	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.look_at_from_position(Vector3(1.0, 1.5, 2.0), Vector3.ZERO)
	return viewport.get_texture()


func _slide_to(target: float) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_slide", target, slide_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _tween


func _on_dim_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()
