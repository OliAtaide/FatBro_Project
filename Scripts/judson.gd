class_name Judson
extends Node3D

## Tap him and he squeaks and clutches his gut. Keep tapping and he keels over, lies
## there a moment, then gets back up. Feed him (see [Feeder]) and he chomps happily.

signal down_changed(down: bool)
## He started or stopped an emote that has a sound of its own (the music fades out for it).
signal performing_changed(performing: bool)

const IDLE := &"idle/mixamo_com"
const GUT_REACT := &"gut_react/mixamo_com"
const FALL := &"fall/mixamo_com"
const GET_UP := &"get_up/mixamo_com"

# Mixamo clips, retargeted onto Judson's skeleton by their import settings
const LIBRARIES := {
	&"idle": preload("res://Mixamo/Idle.fbx"),
	&"gut_react": preload("res://Mixamo/Standing React Large Gut.fbx"),
	&"fall": preload("res://Mixamo/Touch/Falling Back Death.fbx"),
	&"get_up": preload("res://Mixamo/Touch/Getting Up.fbx"),
}
# (emotes aren't listed here: each [EmoteData] brings its own clip, see [method emote])
## Clips recorded with the body turned to one side, squared up to face the same way as idle.
const SQUARE_UP := [GUT_REACT]
## One-shot clips a new tap or press restarts. Each also gets registered under a twin name,
## so a restart crossfades from the clip into its twin instead of snapping to frame 0.
const RESTARTABLE := [GUT_REACT]
const TWIN_SUFFIX := "_again"
## Clips his head follows on its own, instead of looking at the camera (emotes do too).
const NO_LOOK_AT := [GUT_REACT]
const HIPS_TRACK := ^"%GeneralSkeleton:Hips"
## His body mesh (shirt and all) and hair, in every costume model.
const BODY_MESH := ^"Armature/GeneralSkeleton/Body"
const HAIR_MESHES := [^"Armature/GeneralSkeleton/Head_2/Hair", ^"Armature/GeneralSkeleton/Head_2/Hair_001"]
## His face: the texture on it is swapped for the chewing and smiling faces.
const FACE_MESH := ^"Armature/GeneralSkeleton/Head_2/Head"
## White where the body texture is his shirt (the same spot in every costume's texture).
const SHIRT_MASK := preload("res://Textures/judson/judson_shirt_mask.png")

@export var squeak: AudioStream = preload("res://Audio/squeak.ogg")
## Played on each bite when he's fed. Optional.
@export var chomp: AudioStream
@export var heart: Texture2D = preload("res://UI/heart.svg")
## Bone the mouth is placed relative to.
@export var head_bone := &"Head"
## Fallback head height (metres) if [member head_bone] isn't on his skeleton.
@export var head_height := 0.72
## Where food goes in, relative to his head bone (metres, in his own space; +Z is forward).
@export var mouth_offset := Vector3(0.0, 0.03, 0.3)
@export var bites := 3
## Faces he chews with: one bite per time through its "default" animation, at its own speed.
@export var chew_face: SpriteFrames = preload("res://Textures/judson/chew.tres")
## The face he pulls once he's swallowed.
@export var happy_face: Texture2D = preload("res://Textures/judson/judson_face_happy.png")
## How long he keeps smiling (seconds).
@export var happy_time := 1.5
@export_group("Hats")
## Where a hat's brim sits, relative to his head bone (metres, in the bone's space).
@export var hat_spot := Vector3(0.0, 0.25, 0.0)
## How wide a hat comes out (metres), before its own [member HatData.scale_tweak].
@export var hat_width := 0.5
@export_group("")
## What he's wearing (see [method dress]). Null means whatever his model came with.
@export var costume: CostumeData
## Dyes his shirt (white leaves it as it is). Any print stays its own colours.
@export var shirt_color := Color.WHITE:
	set(value):
		shirt_color = value
		if is_node_ready():
			apply_colors(self, shirt_color, hair_color)
@export var hair_color := Color.BLACK:
	set(value):
		hair_color = value
		if is_node_ready():
			apply_colors(self, shirt_color, hair_color)
## How many taps within [member spam_window] seconds knock him over.
@export var taps_to_fall := 6
@export var spam_window := 2.0
## Seconds he lies on the floor before getting up.
@export var stay_down_time := 1.0
@export var blend_time := 0.2
## The hop he does when [method place]d somewhere new.
@export var hop_height := 0.25
@export var hop_time := 0.4
## Size of the capsule you tap to poke him, at full size (metres).
@export var tap_radius := 0.4
@export var tap_height := 1.1

var _down := false
var _tap_times: Array[float] = []
var _home: Vector3
var _modifier_influence := {}
var _modifier_tweens := {}
var _look_at: LookAtModifier3D
var _arm_spread: ArmSpreadModifier3D
var _arm_tween: Tween
var _chew_tween: Tween
var _face_tween: Tween
var _warned_no_head := false
## Emotes played so far: animation name -> its [EmoteData].
var _emotes := {}
## The emote whose sound is playing, if any.
var _performing := &""
var _emote_sound_tween: Tween
## Follows his head bone; the hat being worn (if any) is its only child.
var _hat_mount: BoneAttachment3D
var _hat: Node3D
var _place_tween: Tween
var _dress_tween: Tween
# what you tap to poke him (touches arrive as emulated clicks, picked up by physics picking)
var _tap_area := Area3D.new()
var _tap_shape := CollisionShape3D.new()
## His scale the tap shape was last sized for.
var _tap_size := 0.0

@onready var _anim := animation_player(self)
@onready var _skeleton := find_children("*", "Skeleton3D").front() as Skeleton3D
@onready var _squeak_player := AudioStreamPlayer.new()
@onready var _chomp_player := AudioStreamPlayer.new()
@onready var _emote_player := AudioStreamPlayer.new()
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
	if costume:
		costume.dress(self)
	apply_colors(self, shirt_color, hair_color)

	# look-at, arm spread, etc. get faded out while he's on the floor
	for modifier in _skeleton.find_children("*", "SkeletonModifier3D", false):
		_modifier_influence[modifier] = modifier.influence
	# and the look-at alone while he emotes, so his head follows the emote instead
	var look_ats := _skeleton.find_children("*", "LookAtModifier3D", false)
	_look_at = look_ats.front() if look_ats else null
	# and the arm spread gets steered by each emote's arm settings
	for modifier in _skeleton.get_children():
		if modifier is ArmSpreadModifier3D:
			_arm_spread = modifier
	_anim.current_animation_changed.connect(_on_current_animation_changed)

	_squeak_player.stream = squeak
	_squeak_player.max_polyphony = 4
	add_child(_squeak_player)
	_chomp_player.stream = chomp
	add_child(_chomp_player)
	add_child(_emote_player)
	_emote_player.finished.connect(_on_emote_sound_finished)

	# touches arrive as emulated mouse clicks, which this picks up through the physics picking
	_tap_shape.shape = CapsuleShape3D.new()
	_tap_area.add_child(_tap_shape)
	_tap_area.input_event.connect(_on_tap_area_input_event)
	add_child(_tap_area)
	_fit_tap_shape()
	# (sized to match whenever he's scaled, see _fit_tap_shape)
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _tap_area.is_inside_tree():
		_fit_tap_shape()


## Sizes his tap shape to him. Physics (Jolt) doesn't follow a scaled parent properly, so
## the shape's area cancels out his scale and the capsule itself is resized instead.
func _fit_tap_shape() -> void:
	var size := global_basis.get_scale().y
	if is_equal_approx(size, _tap_size):
		return
	_tap_size = size
	_tap_area.scale = Vector3.ONE / scale
	var capsule := _tap_shape.shape as CapsuleShape3D
	capsule.radius = tap_radius * size
	capsule.height = tap_height * size
	_tap_shape.position.y = capsule.height / 2.0


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


## Plays [param data]. Ignored while he's down or already doing it. One with a sound
## loops until the sound has played out.
func emote(data: EmoteData) -> void:
	if _down or not data or not data.animation:
		return
	var animation := _add_emote(data)
	if _anim.current_animation != animation:
		_anim.play(animation)


## Loads [param data]'s clip into his AnimationPlayer the first time it's played, under
## the resource's file name (e.g. "emote_wave"), and returns the animation name to play it by.
func _add_emote(data: EmoteData) -> StringName:
	# (prefixed, so an emote called "idle" can't clash with his own clips)
	var file := data.resource_path.get_file().get_basename().validate_node_name().replace(",", "_")
	var library := StringName("emote_" + (file if file else str(data.get_instance_id())))
	var animation := StringName("%s/%s" % [library, data.clip_name()])
	if not _anim.has_animation_library(library):
		_anim.add_animation_library(library, data.animation)
		if data.audio:
			_anim.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	_emotes[animation] = data
	return animation


## Moves him to [param spot], turned to face [param look_toward] (ignored if INF), with a
## little hop unless [param hop] is off. That's where he gets back up to after a fall, too.
## A hop is ignored while he's on the floor; returns whether he moved.
func place(spot: Vector3, look_toward := Vector3.INF, hop := true) -> bool:
	if _down and hop:
		return false
	_home = spot
	var turn_to := global_rotation.y
	if look_toward != Vector3.INF:
		var facing := look_toward - spot
		if Vector2(facing.x, facing.z).length() > 0.001:
			# he faces his own +Z
			turn_to = atan2(facing.x, facing.z)
	if _place_tween:
		_place_tween.kill()
	if not hop:
		global_position = spot
		global_rotation.y = turn_to
		return true
	var from := global_position
	var turn_from := global_rotation.y
	var turn := wrapf(turn_to - turn_from, -PI, PI)
	# (a hop as high for him at any size)
	var height := hop_height * global_basis.get_scale().y
	var step := func(t: float) -> void:
		global_position = from.lerp(spot, t) + Vector3.UP * height * sin(t * PI)
		global_rotation.y = turn_from + turn * t
	_place_tween = create_tween()
	_place_tween.tween_method(step, 0.0, 1.0, hop_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return true


## Pops [param hat] onto his head, swapping out any he had on. Null takes it off.
func wear(hat: HatData) -> void:
	if not _hat_mount:
		_hat_mount = BoneAttachment3D.new()
		_hat_mount.bone_name = head_bone
		_skeleton.add_child(_hat_mount)
	if _hat:
		var old := _hat
		var tween := create_tween()
		tween.tween_property(old, "scale", Vector3.ZERO, 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(old.queue_free)
	_hat = null
	if not hat or not hat.model:
		return
	var spot := Node3D.new()
	spot.position = hat_spot
	spot.add_child(hat.instantiate_fitted(hat_width))
	_hat_mount.add_child(spot)
	_hat = spot
	spot.scale = Vector3.ZERO
	create_tween().tween_property(spot, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Changes him into [param new_costume], with a little squash-and-pop as it goes on (or
## straight away, if not [param animate]d).
func dress(new_costume: CostumeData, animate := true) -> void:
	if not new_costume or new_costume == costume:
		return
	costume = new_costume
	if not animate:
		_put_on(costume)
		return
	if _dress_tween:
		_dress_tween.kill()
	_dress_tween = create_tween()
	_dress_tween.tween_property(_body, "scale", _body_scale * Vector3(1.12, 0.85, 1.12), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dress_tween.tween_callback(_put_on.bind(costume))
	_dress_tween.tween_property(_body, "scale", _body_scale, 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _put_on(outfit: CostumeData) -> void:
	outfit.dress(self)
	# (new meshes come without his colours)
	apply_colors(self, shirt_color, hair_color)


## Dyes [param model]'s shirt and hair (a Judson, or any instance of a costume model).
static func apply_colors(model: Node, shirt: Color, hair: Color) -> void:
	var body := own_material(model, BODY_MESH)
	if body:
		body.set_shader_parameter(&"tint_mask", SHIRT_MASK)
		body.set_shader_parameter(&"tint_color", shirt)
	for path: NodePath in HAIR_MESHES:
		var material := own_material(model, path)
		if material:
			material.set_shader_parameter(&"color", hair)


## [param model]'s own copy of the material on a surface of the mesh at [param path], made
## (as a surface override) the first time it's asked for, so changing it only changes him.
## Null if there's no such mesh, or its material isn't a shader one.
static func own_material(model: Node, path: NodePath, surface := 0) -> ShaderMaterial:
	var mesh_instance := model.get_node_or_null(path) as MeshInstance3D
	if not mesh_instance or not mesh_instance.mesh:
		return null
	var material := mesh_instance.get_surface_override_material(surface) as ShaderMaterial
	if not material:
		material = mesh_instance.mesh.surface_get_material(surface).duplicate() as ShaderMaterial
		mesh_instance.set_surface_override_material(surface, material)
	return material


## [param model]'s AnimationPlayer. The importer only makes one if the .blend has an
## action of its own, so if it didn't, one's added here for the Mixamo clips to go in.
static func animation_player(model: Node) -> AnimationPlayer:
	var players := model.find_children("*", "AnimationPlayer")
	if players:
		return players.front()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	return player


func can_eat() -> bool:
	return not _down


func mouth_position() -> Vector3:
	# looked up here rather than in _ready, in case the skeleton's bones aren't named yet then
	var bone := _skeleton.find_bone(head_bone)
	var head := global_position + global_basis * Vector3.UP * head_height
	if bone != -1:
		head = _skeleton.global_transform * _skeleton.get_bone_global_pose(bone).origin
	elif not _warned_no_head:
		_warned_no_head = true
		var names := PackedStringArray()
		for i in _skeleton.get_bone_count():
			names.append(_skeleton.get_bone_name(i))
		push_warning("No '%s' bone on %s, so the mouth is a guess. Bones: %s"
				% [head_bone, _skeleton.get_path(), ", ".join(names)])
	return head + global_basis * mouth_offset


## Purely for show: a few squashy chomps, chewing all the while, some hearts, then a smile.
func eat() -> void:
	if _down:
		return
	if _chew_tween:
		_chew_tween.kill()
	if _face_tween:
		_face_tween.kill()
	_chew_tween = create_tween()
	_face_tween = create_tween()
	var chew_time := _chew_cycle_time()
	for bite in bites:
		# each bite: a chomp and a squash as his mouth starts a chew, then the rest of the chew
		_chew_tween.tween_callback(_play_chomp)
		_chew_tween.tween_property(_body, "scale", _body_scale * Vector3(1.06, 0.94, 1.06), 0.08) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_chew_tween.tween_property(_body, "scale", _body_scale, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_chew_tween.tween_interval(maxf(chew_time - 0.22, 0.0))
		_chew_once(_face_tween)
	_face_tween.tween_callback(_set_face.bind(happy_face))
	_face_tween.tween_interval(happy_time)
	_face_tween.tween_callback(_set_face.bind(null))
	for i in 3:
		get_tree().create_timer(0.15 * i).timeout.connect(_float_heart)


## How long one chew (once through [member chew_face]) takes, in seconds.
func _chew_cycle_time() -> float:
	if not chew_face or not chew_face.has_animation(&"default"):
		return 0.22
	var speed := chew_face.get_animation_speed(&"default")
	var time := 0.0
	for frame in chew_face.get_frame_count(&"default"):
		time += chew_face.get_frame_duration(&"default", frame) / speed
	return time


## Adds one chew to [param tween]: each of [member chew_face]'s frames for as long as it says.
func _chew_once(tween: Tween) -> void:
	if not chew_face or not chew_face.has_animation(&"default"):
		tween.tween_interval(0.22)
		return
	var speed := chew_face.get_animation_speed(&"default")
	for frame in chew_face.get_frame_count(&"default"):
		tween.tween_callback(_set_face.bind(chew_face.get_frame_texture(&"default", frame)))
		tween.tween_interval(chew_face.get_frame_duration(&"default", frame) / speed)


## Puts [param face] on him, or his own face back when it's null.
func _set_face(face: Texture2D) -> void:
	var head := get_node_or_null(FACE_MESH) as MeshInstance3D
	if not head:
		return
	var material := own_material(self, FACE_MESH)
	if not material:
		return
	if not face:
		# (his own face is whatever his current model's face material has)
		face = head.mesh.surface_get_material(0).get_shader_parameter(&"tex")
	material.set_shader_parameter(&"tex", face)


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
		_fade(modifier, influence, blend_time * 2.0)
	down_changed.emit(down)


## Eases [param modifier] to [param influence], taking over from any fade already running.
## Eases his arms into [param emote]'s arm settings, or back to normal when it's null,
## alongside the crossfade into the new clip.
func _steer_arms(emote: EmoteData) -> void:
	if not _arm_spread:
		return
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween().set_parallel()
	_arm_tween.tween_property(_arm_spread, "extra_spread_degrees", emote.arm_spread if emote else 0.0, blend_time)
	_arm_tween.tween_property(_arm_spread, "inward_degrees", emote.arm_inward if emote else 0.0, blend_time)
	_arm_tween.tween_property(_arm_spread, "forward_degrees", emote.arm_forward if emote else 0.0, blend_time)
	_arm_tween.tween_property(_arm_spread, "forearm_forward_degrees", emote.forearm_forward if emote else 0.0, blend_time)


func _fade(modifier: SkeletonModifier3D, influence: float, time: float) -> void:
	if _modifier_tweens.has(modifier):
		(_modifier_tweens[modifier] as Tween).kill()
	var tween := create_tween()
	tween.tween_property(modifier, "influence", influence, time)
	_modifier_tweens[modifier] = tween


func _on_current_animation_changed(animation: StringName) -> void:
	_set_emote_sound(animation)
	_steer_arms(_emotes.get(animation) as EmoteData)
	# while he's down every modifier is already off, and getting up turns them back on
	if _down or not _look_at:
		return
	# (a restart plays the clip's twin, which counts as the clip)
	var clip := StringName(animation.trim_suffix(TWIN_SUFFIX))
	var looks_away := animation in _emotes or clip in NO_LOOK_AT
	var influence: float = 0.0 if looks_away else _modifier_influence[_look_at]
	_fade(_look_at, influence, blend_time)


## Starts [param animation]'s emote sound if it has one; fades out any other that's playing
## (he got poked, knocked over or picked something else).
func _set_emote_sound(animation: StringName) -> void:
	var performing: StringName = &""
	if animation in _emotes and (_emotes[animation] as EmoteData).audio:
		performing = animation
	if performing == _performing:
		return
	var was_performing := _performing != &""
	_performing = performing
	if _emote_sound_tween:
		_emote_sound_tween.kill()
	if _performing:
		_emote_player.stream = (_emotes[_performing] as EmoteData).audio
		_emote_player.volume_db = 0.0
		_emote_player.play()
	elif _emote_player.playing:
		_emote_sound_tween = create_tween()
		_emote_sound_tween.tween_property(_emote_player, "volume_db", -40.0, 0.3)
		_emote_sound_tween.tween_callback(_emote_player.stop)
	if was_performing != (_performing != &""):
		performing_changed.emit(not was_performing)


func _on_emote_sound_finished() -> void:
	# the emote has been looping along with its sound; the sound's done, so is he
	if _performing and _anim.current_animation == _performing:
		_anim.play(IDLE)


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
