class_name Feeder
extends Node3D

## Pokémon GO style feeding. A snack floats at the bottom of the screen: drag it onto
## him and let go to feed him, or just tap it to switch to the next one.

@export var character: Judson
@export var foods: Array[FoodData] = []
## Longest side of a snack, in metres. The models come in at all sorts of scales, so
## each one is resized to this.
@export var food_size := 0.18
## Where the snack rests, in pixels up from the bottom edge of the screen.
@export var rest_height := 150.0
## How far from the camera the snack is held, in metres.
@export var hold_distance := 2.2
## A press that moves less than this many pixels is a tap, not a drag.
@export var drag_threshold := 12.0
@export var spin_speed := 0.8

var _index := 0
var _food: Node3D
var _pressed := false
var _dragging := false
var _busy := false
var _press_position: Vector2

@onready var _camera := get_viewport().get_camera_3d()


func _ready() -> void:
	if foods.is_empty():
		return
	_show_food(0)


func _process(delta: float) -> void:
	if not _food or _busy:
		return
	_food.rotate_y(spin_speed * delta)
	if not _dragging:
		_food.global_position = _rest_position()


func _unhandled_input(event: InputEvent) -> void:
	if not _food or _busy:
		return
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and _is_on_food(button.position):
			_pressed = true
			_press_position = button.position
			get_viewport().set_input_as_handled()
		elif not button.pressed and _pressed:
			_pressed = false
			get_viewport().set_input_as_handled()
			if _dragging:
				_dragging = false
				_release(button.position)
			else:
				_show_food(_index + 1)
	var motion := event as InputEventMouseMotion
	if motion and _pressed:
		if not _dragging and motion.position.distance_to(_press_position) > drag_threshold:
			_dragging = true
		if _dragging:
			_food.global_position = _camera.project_position(motion.position, hold_distance)
		get_viewport().set_input_as_handled()


func _show_food(index: int) -> void:
	if _food:
		_food.queue_free()
	_index = wrapi(index, 0, foods.size())
	_food = Node3D.new()
	add_child(_food)
	var model := foods[_index].model.instantiate() as Node3D
	_food.add_child(model)
	# centre the model on the holder and scale it so every snack ends up the same size
	var bounds := _bounds(model)
	var size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit := food_size / size if size > 0.0 else 1.0
	model.scale = Vector3.ONE * fit
	model.position = -bounds.get_center() * fit
	_food.global_position = _rest_position()
	_food.scale = Vector3.ZERO
	create_tween().tween_property(_food, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _release(screen_position: Vector2) -> void:
	_busy = true
	var food := _food
	if _is_on_character(screen_position) and character.can_eat():
		_food = null
		var tween := create_tween()
		tween.tween_property(food, "global_position", character.mouth_position(), 0.25) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(character.eat)
		tween.tween_property(food, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(food.queue_free)
		tween.tween_interval(0.4)
		tween.tween_callback(func() -> void:
			_busy = false
			_show_food(_index))
	else:
		# missed him (or he's on the floor): float back down to the rest spot
		var tween := create_tween()
		tween.tween_property(food, "global_position", _rest_position(), 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: _busy = false)


func _rest_position() -> Vector3:
	var screen := get_viewport().get_visible_rect().size
	return _camera.project_position(Vector2(screen.x / 2.0, screen.y - rest_height), hold_distance)


func _is_on_food(screen_position: Vector2) -> bool:
	# generous touch target: a circle a bit wider than the snack itself
	var center := _camera.unproject_position(_food.global_position)
	var edge := _camera.unproject_position(_food.global_position + _camera.global_basis.x * food_size)
	return screen_position.distance_to(center) < center.distance_to(edge)


func _is_on_character(screen_position: Vector2) -> bool:
	var feet := _camera.unproject_position(character.global_position)
	var head := _camera.unproject_position(character.mouth_position() + Vector3.UP * 0.2)
	var half_width := feet.distance_to(_camera.unproject_position(
			character.global_position + _camera.global_basis.x * 0.45))
	var area := Rect2(head.x - half_width, head.y, half_width * 2.0, feet.y - head.y)
	return area.has_point(screen_position)


## The model's bounding box, in its own space.
static func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
