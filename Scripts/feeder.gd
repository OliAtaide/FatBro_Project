class_name Feeder
extends Node3D

## Pokémon GO style feeding. Once a snack is picked (see [method hold]) it floats at the
## bottom of the screen: drag it onto him and let go to feed him.

@export var character: Judson
## Longest side of a snack, in metres.
@export var food_size := 0.18
## Where the snack rests, in pixels up from the bottom edge of the screen.
@export var rest_height := 150.0
## How far from the camera the snack is held, in metres.
@export var hold_distance := 2.2
@export var spin_speed := 0.8

var _held: FoodData
var _shown: FoodData
var _food: Node3D
var _dragging := false
var _busy := false

@onready var _camera := get_viewport().get_camera_3d()


## Puts [param food] at the bottom of the screen, ready to feed him.
func hold(food: FoodData) -> void:
	_held = food
	if not _busy:
		_show_food()


## Takes the snack off the screen until the next [method hold]. One already on its way
## to his mouth still gets eaten.
func put_away() -> void:
	_held = null
	_dragging = false
	if not _busy:
		_hide_food()


## Whether a touch at [param screen_position] is the feeder's business: on the snack (or
## dragging it), or on him.
func claims(screen_position: Vector2) -> bool:
	if _food and (_dragging or _is_on_food(screen_position)):
		return true
	return _is_on_character(screen_position)


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
			_dragging = true
			get_viewport().set_input_as_handled()
		elif not button.pressed and _dragging:
			_dragging = false
			get_viewport().set_input_as_handled()
			_release(button.position)
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_food.global_position = _camera.project_position(motion.position, hold_distance)
		get_viewport().set_input_as_handled()


func _show_food() -> void:
	if not _held:
		_hide_food()
		return
	if _food:
		_food.queue_free()
	_shown = _held
	_food = _held.instantiate_fitted(food_size)
	add_child(_food)
	_food.global_position = _rest_position()
	_food.scale = Vector3.ZERO
	create_tween().tween_property(_food, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_food() -> void:
	_shown = null
	if not _food:
		return
	var food := _food
	_food = null
	var tween := create_tween()
	tween.tween_property(food, "scale", Vector3.ZERO, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(food.queue_free)


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
			_show_food())
	else:
		# missed him (or he's on the floor): float back down to the rest spot
		var tween := create_tween()
		tween.tween_property(food, "global_position", _rest_position(), 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void:
			_busy = false
			# a different snack was picked while this one was in the air
			if _shown != _held:
				_show_food())


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
