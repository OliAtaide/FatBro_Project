class_name Judson
extends Node3D

## Tap him and he squeaks and clutches his gut. Keep tapping and he keels over, lies
## there a moment, then gets back up. Feed him (see [Feeder]) and he chomps happily.

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
## Clips recorded with the body turned to one side, squared up to face the same way as idle.
const SQUARE_UP := [GUT_REACT]
## One-shot clips a new tap or press restarts. Each also gets registered under a twin name,
## so a restart crossfades from the clip into its twin instead of snapping to frame 0.
const RESTARTABLE := [GUT_REACT]
const TWIN_SUFFIX := "_again"
const HIPS_TRACK := ^"%GeneralSkeleton:Hips"

@export var squeak: AudioStream = preload("res://Audio/squeak.ogg")
## Played on each bite when he's fed. Optional.
@export var chomp: AudioStream
@export var heart: Texture2D = preload("res://UI/heart.svg")
## Where food goes in, relative to his head bone (metres, in his own space; +Z is forward).
@export var mouth_offset := Vector3(0.0, 0.05, 0.12)
@export var bites := 3
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
var _chew_tween: Tween

@onready var _anim := find_children("*", "AnimationPlayer").front() as AnimationPlayer
@onready var _skeleton := find_children("*", "Skeleton3D").front() as Skeleton3D
@onready var _squeak_player := AudioStreamPlayer.new()
@onready var _chomp_player := AudioStreamPlayer.new()
@onready var _head_bone := _skeleton.find_bone("Head")
# squashed while he chews (not the root: that would squash his tap shape too, which Jolt rejects)
@onready var _body := get_node("Armature") as Node3D
@onready var _body_scale := _body.scale


func _ready() -> void:
	_home = global_position
	for library: StringName in LIBRARIES:
		_anim.add_animation_library(library, LIBRARIES[library])
	for animation: StringName in SQUARE_UP:
		_turn_to_match(_anim.get_animation(animation), _anim.get_animation(IDLE))
	for animation: StringName in RESTARTABLE:
		var library := _anim.get_animation_library(animation.get_slice("/", 0))
		library.add_animation(animation.get_slice("/", 1) + TWIN_SUFFIX, _anim.get_animation(animation))
	_anim.playback_default_blend_time = blend_time
	_anim.animation_finished.connect(_on_animation_finished)
	_anim.play(IDLE)
	# pose him right away, so the first frame isn't a T-pose
	_anim.advance(0.0)

	# look-at, arm spread, etc. get faded out while he's on the floor
	for modifier in _skeleton.find_children("*", "SkeletonModifier3D", false):
		_modifier_influence[modifier] = modifier.influence

	_squeak_player.stream = squeak
	_squeak_player.max_polyphony = 4
	add_child(_squeak_player)
	_chomp_player.stream = chomp
	add_child(_chomp_player)

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
		# a little longer than usual: the fall starts with his body turned aside
		_anim.play(FALL, blend_time * 2.0)
	else:
		_play_from_start(GUT_REACT)


func wave() -> void:
	if not _down and _anim.current_animation != WAVE:
		_anim.play(WAVE)


func can_eat() -> bool:
	return not _down


func mouth_position() -> Vector3:
	var head := _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone).origin
	return head + global_basis * mouth_offset


## Purely for show: a few squashy chomps and some hearts.
func eat() -> void:
	if _down:
		return
	if _chew_tween:
		_chew_tween.kill()
	_chew_tween = create_tween()
	for bite in bites:
		_chew_tween.tween_callback(_play_chomp)
		_chew_tween.tween_property(_body, "scale", _body_scale * Vector3(1.06, 0.94, 1.06), 0.08) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_chew_tween.tween_property(_body, "scale", _body_scale, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 3:
		get_tree().create_timer(0.15 * i).timeout.connect(_float_heart)


func _play_chomp() -> void:
	if chomp:
		_chomp_player.pitch_scale = randf_range(0.9, 1.1)
		_chomp_player.play()


func _float_heart() -> void:
	var sprite := Sprite3D.new()
	sprite.texture = heart
	sprite.pixel_size = 0.15 / heart.get_width()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	add_child(sprite)
	var start := mouth_position() + global_basis * Vector3(randf_range(-0.15, 0.15), 0.15, 0.0)
	sprite.global_position = start
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "global_position", start + Vector3.UP * 0.4, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(sprite.queue_free)


func _play_from_start(animation: StringName) -> void:
	# (an AnimationPlayer can't crossfade a clip into itself, hence the twin)
	if _anim.current_animation == animation:
		animation = StringName(animation + TWIN_SUFFIX)
	_anim.play(animation)


func _get_up() -> void:
	# The fall carries his hips backward, but Getting Up starts with them right under
	# where he stood. Shift him back by that drift in step with the crossfade, so his
	# hips stay put while the two poses blend, then ease him home as he rises.
	# (hips tracks are stored normalized by the retarget, so scale them back to metres)
	var drift := (_hips_position(FALL, INF) - _hips_position(GET_UP, 0.0)) * _skeleton.motion_scale
	drift.y = 0.0
	var get_up_blend := blend_time * 2.0
	_anim.play(GET_UP, get_up_blend)
	var tween := create_tween()
	tween.tween_property(self, "global_position", _home + _skeleton.global_basis * drift, get_up_blend)
	tween.tween_property(self, "global_position", _home, _anim.current_animation_length - get_up_blend) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hips_position(animation: StringName, time: float) -> Vector3:
	var clip := _anim.get_animation(animation)
	var track := clip.find_track(HIPS_TRACK, Animation.TYPE_POSITION_3D)
	if track == -1:
		return Vector3.ZERO
	return clip.position_track_interpolate(track, minf(time, clip.length))


## Turns [param clip] about the vertical axis so his hips start out facing the same way
## as in [param reference]. Edits the imported clip in place; running it again is a no-op.
static func _turn_to_match(clip: Animation, reference: Animation) -> void:
	var turn := Quaternion(Vector3.UP, _hips_heading(reference) - _hips_heading(clip))
	for type in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
		var track := clip.find_track(HIPS_TRACK, type)
		for key in clip.track_get_key_count(track):
			clip.track_set_key_value(track, key, turn * clip.track_get_key_value(track, key))


static func _hips_heading(clip: Animation) -> float:
	var track := clip.find_track(HIPS_TRACK, Animation.TYPE_ROTATION_3D)
	var forward := Basis(clip.rotation_track_interpolate(track, 0.0)).z
	return atan2(forward.x, forward.z)


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
