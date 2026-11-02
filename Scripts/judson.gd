class_name Judson
extends Node3D

## Tap him and he squeaks and clutches his gut. Keep tapping and he keels over, lies
## there a moment, then gets back up.

signal down_changed(down: bool)

const IDLE := &"idle/mixamo_com"
const GUT_REACT := &"gut_react/mixamo_com"
const FALL := &"fall/mixamo_com"
const GET_UP := &"get_up/mixamo_com"
const WAVE := &"wave/mixamo_com"

# Mixamo clips, retargeted onto Judson's skeleton by their import settings
const LIBRARIES := {
	&"idle": preload("res://Mixamo/Idle.fbx"),
	&"gut_react": preload("res://Mixamo/Standing React Large Gut.fbx"),
	&"fall": preload("res://Mixamo/Falling Back Death.fbx"),
	&"get_up": preload("res://Mixamo/Getting Up.fbx"),
	&"wave": preload("res://Mixamo/Waving.fbx"),
}

@export var squeak: AudioStream = preload("res://Audio/squeak.ogg")
## How many taps within [member spam_window] seconds knock him over.
@export var taps_to_fall := 6
@export var spam_window := 2.0
## Seconds he lies on the floor before getting up.
@export var stay_down_time := 1.0
@export var blend_time := 0.2

var _down := false
var _tap_times: Array[float] = []
var _home: Vector3
var _modifier_influence := {}

@onready var _anim := find_children("*", "AnimationPlayer").front() as AnimationPlayer
@onready var _skeleton := find_children("*", "Skeleton3D").front() as Skeleton3D
@onready var _squeak_player := AudioStreamPlayer.new()


func _ready() -> void:
	_home = global_position
	for library: StringName in LIBRARIES:
		_anim.add_animation_library(library, LIBRARIES[library])
	_anim.playback_default_blend_time = blend_time
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play(IDLE)

	# look-at, arm spread, etc. get faded out while he's on the floor
	for modifier in _skeleton.find_children("*", "SkeletonModifier3D", false):
		_modifier_influence[modifier] = modifier.influence

	_squeak_player.stream = squeak
	_squeak_player.max_polyphony = 4
	add_child(_squeak_player)

	# touches arrive as emulated mouse clicks, which this picks up through the physics picking
	var tap_area := Area3D.new()
	var tap_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.1
	tap_shape.shape = capsule
	tap_shape.position.y = capsule.height / 2.0
	tap_area.add_child(tap_shape)
	tap_area.input_event.connect(_on_tap_area_input_event)
	add_child(tap_area)


func poke() -> void:
	if _down:
		return
	_squeak_player.pitch_scale = randf_range(0.9, 1.2)
	_squeak_player.play()

	var now := Time.get_ticks_msec() / 1000.0
	_tap_times.append(now)
	while now - _tap_times[0] > spam_window:
		_tap_times.pop_front()
	if _tap_times.size() >= taps_to_fall:
		_tap_times.clear()
		_set_down(true)
		_anim.play(FALL)
	else:
		_play_from_start(GUT_REACT)


func wave() -> void:
	if not _down:
		_play_from_start(WAVE)


func _play_from_start(animation: StringName) -> void:
	if _anim.current_animation == animation:
		_anim.seek(0.0, true)
	else:
		_anim.play(animation)


func _get_up() -> void:
	# The fall carries his hips backward, but Getting Up starts with them right under
	# where he stood. Move him to where he landed, then ease him home as he rises.
	var drift := _hips_position(FALL, INF) - _hips_position(GET_UP, 0.0)
	drift.y = 0.0
	global_position = _home + _skeleton.global_basis * drift
	_anim.play(GET_UP, 0.0)
	create_tween().tween_property(self, "global_position", _home, _anim.current_animation_length) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hips_position(animation: StringName, time: float) -> Vector3:
	var clip := _anim.get_animation(animation)
	var track := clip.find_track(^"%GeneralSkeleton:Hips", Animation.TYPE_POSITION_3D)
	if track == -1:
		return Vector3.ZERO
	return clip.position_track_interpolate(track, minf(time, clip.length))


func _set_down(down: bool) -> void:
	_down = down
	for modifier: SkeletonModifier3D in _modifier_influence:
		var influence: float = 0.0 if down else _modifier_influence[modifier]
		create_tween().tween_property(modifier, "influence", influence, blend_time * 2.0)
	down_changed.emit(down)


func _on_animation_finished(animation: StringName) -> void:
	match animation:
		FALL:
			await get_tree().create_timer(stay_down_time).timeout
			_get_up()
		GET_UP:
			_set_down(false)
			_anim.play(IDLE)
		_:
			_anim.play(IDLE)


func _on_tap_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3,
		_normal: Vector3, _shape_idx: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		poke()
