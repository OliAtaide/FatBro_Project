class_name ArView
extends Node

## Pokémon GO style "AR": swaps the room for the phone's back camera and turns the 3D
## camera as the phone turns (gyroscope, with gravity keeping the horizon level), so he
## seems to stand out there in the real world.
##
## There's no surface tracking, so the floor is a guess: [member phone_height] below the
## phone, levelled by gravity. A soft shadow grounds him on it, and tapping the floor in
## the camera view sends him hopping over to that spot. Turning and tilting the phone keeps
## him in place; walking around doesn't (he moves with you).

signal active_changed(active: bool)
## Couldn't switch AR on (no permission, no camera...). [param reason] is for showing.
signal failed(reason: String)

const CAMERA_PERMISSION := "android.permission.CAMERA"

@export var camera: Camera3D
@export var world_environment: WorldEnvironment
@export var character: Judson
## Taps it claims (on the snack, on him) don't move him. Optional.
@export var feeder: Feeder
## Hidden while AR is on (the room, its furniture...).
@export var hide_in_ar: Array[Node3D] = []

@export_group("View")
## How far above the floor the phone is held (metres). Most people hold it at about
## chest height; if he looks sunk into the floor, lower this, and raise it if he floats.
@export_range(0.3, 2.5, 0.05) var phone_height := 1.35
## How far in front of the phone he stands when AR switches on (metres).
@export var start_distance := 2.0
## Taps further away than this (metres) don't move him: too far to judge on a guessed floor.
@export var max_place_distance := 6.0
## Vertical field of view of a typical phone's back camera, held upright (degrees).
@export_range(20.0, 100.0) var fov := 65.0
## How quickly gravity pulls the horizon back level against gyroscope drift (per second).
@export var level_correction := 4.0
## Radius of the shadow under him (metres).
@export var shadow_radius := 0.45

@export_group("Camera image")
## Quarter turns (clockwise) applied to the camera image; -1 uses the turn the camera
## itself reports (Android works it out from how the sensor is mounted). Set 0 to 3 by hand
## if it still shows up sideways or upside down.
@export_range(-1, 3) var image_quarter_turns := -1
@export var mirror_image := false
## Lets AR switch on without a camera (a plain dark background), to try it on a desktop.
@export var allow_without_camera := false

var active := false

var _starting := false
var _feed: CameraFeed
var _main_texture := CameraTexture.new()
var _cbcr_texture := CameraTexture.new()
var _layer := CanvasLayer.new()
var _background := ColorRect.new()
var _material := ShaderMaterial.new()
## The world as seen from the phone (maps world directions into the phone's own axes).
var _world_in_phone := Basis.IDENTITY
## Turns the phone's heading so that it starts out facing him.
var _heading := Basis.IDENTITY
## What AR mode changed, put back by [method stop].
var _saved := {}
var _shadow := MeshInstance3D.new()
## Where and when the current touch went down, and whether something else claimed it.
var _press_position := Vector2.ZERO
var _press_time := 0
var _press_claimed := true


func _ready() -> void:
	_material.shader = preload("res://shaders/camera_feed.gdshader")
	_background.color = Color(0.08, 0.08, 0.1)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# drawn behind the 3D world: the environment shows layers up to -1 as its background
	_layer.layer = -10
	_layer.add_child(_background)
	_layer.hide()
	add_child(_layer)
	_cbcr_texture.which_feed = CameraServer.FEED_CBCR_IMAGE

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * shadow_radius * 2.0
	quad.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = quad
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://shaders/blob_shadow.gdshader")
	_shadow.material_override = shadow_material
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(false)
	set_process_unhandled_input(false)


## Whether the AR button is worth showing: phones, or anywhere if [member allow_without_camera].
func is_supported() -> bool:
	return OS.has_feature("mobile") or allow_without_camera


func toggle() -> void:
	if active:
		stop()
	else:
		start()


func start() -> void:
	if active or _starting:
		return
	_starting = true
	if not await _has_camera_permission():
		_starting = false
		# Android stops asking once it's been refused, so say where to turn it back on
		failed.emit("AR needs the camera. Allow it in Settings > Apps > %s > Permissions > Camera, then try again."
				% ProjectSettings.get_setting("application/config/name"))
		return
	_feed = await _find_back_camera()
	_starting = false
	if not _feed and not allow_without_camera:
		failed.emit("No camera found")
		return

	if _feed:
		_pick_format(_feed)
		_main_texture.camera_feed_id = _feed.get_id()
		_cbcr_texture.camera_feed_id = _feed.get_id()
		_feed.feed_is_active = true
		_material.set_shader_parameter("mode", 0)
		_material.set_shader_parameter("feed_main", _main_texture)
		_material.set_shader_parameter("feed_cbcr", _cbcr_texture)
	# without a camera, just the plain background colour
	_background.material = _material if _feed else null
	_layer.show()

	var environment := world_environment.environment
	_saved = {
		camera_transform = camera.global_transform,
		camera_fov = camera.fov,
		character_transform = character.global_transform,
		background_mode = environment.background_mode,
		canvas_max_layer = environment.background_canvas_max_layer,
		hidden = hide_in_ar.filter(func(node: Node3D) -> bool: return node.visible),
	}
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = -1
	for node: Node3D in _saved.hidden:
		node.hide()

	camera.fov = fov
	# the floor's where his feet are; the phone's held phone_height above it, a few steps back
	camera.global_position = character.global_position \
			+ character.global_basis.z.normalized() * start_distance + Vector3.UP * phone_height
	_start_orientation()
	_update_camera_basis()
	character.add_child(_shadow)
	active = true
	set_process(true)
	set_process_unhandled_input(true)
	active_changed.emit(true)


func stop() -> void:
	if not active:
		return
	active = false
	set_process(false)
	set_process_unhandled_input(false)
	character.remove_child(_shadow)
	# back to his spot in the room
	var home: Transform3D = _saved.character_transform
	character.place(home.origin, home.origin + home.basis.z, false)
	if _feed:
		_feed.feed_is_active = false
	CameraServer.monitoring_feeds = false
	_layer.hide()
	var environment := world_environment.environment
	environment.background_mode = _saved.background_mode
	environment.background_canvas_max_layer = _saved.canvas_max_layer
	for node: Node3D in _saved.hidden:
		node.show()
	camera.global_transform = _saved.camera_transform
	camera.fov = _saved.camera_fov
	active_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	# touches arrive as emulated mouse clicks; a quick tap on the floor (not a drag, not on
	# the snack or him) sends him there
	var click := event as InputEventMouseButton
	if not click or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_press_position = click.position
		_press_time = Time.get_ticks_msec()
		_press_claimed = feeder != null and feeder.claims(click.position)
		return
	var tap := not _press_claimed and click.position.distance_to(_press_position) < 24.0 \
			and Time.get_ticks_msec() - _press_time < 400
	_press_claimed = true
	if tap:
		var spot = floor_point(click.position)
		if spot != null:
			character.place(spot, camera.global_position)


## Where the screen point [param screen_position] lands on the guessed floor, or null if
## it's above the horizon or too far off to trust.
func floor_point(screen_position: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var floor_height: float = (_saved.character_transform as Transform3D).origin.y
	if direction.y > -0.02:
		return null
	var spot := from + direction * ((floor_height - from.y) / direction.y)
	var to_spot := spot - camera.global_position
	to_spot.y = 0.0
	if to_spot.length() > max_place_distance:
		return null
	return spot


func _process(delta: float) -> void:
	step_sensors(Input.get_gyroscope(), Input.get_gravity(), delta)
	_update_camera_basis()
	if _feed:
		_update_image()
	# the shadow stays on the floor when he hops, shrinking a little the higher he gets
	var floor_height: float = (_saved.character_transform as Transform3D).origin.y
	var lift := character.global_position.y - floor_height
	_shadow.global_position = Vector3(character.global_position.x, floor_height + 0.005,
			character.global_position.z)
	_shadow.scale = Vector3.ONE * clampf(1.0 - lift * 1.2, 0.6, 1.0)


## Advances the phone's orientation by one frame of sensor readings (both in the phone's
## own axes: x right, y up, z out of the screen). Public so it can be tried without a phone.
func step_sensors(gyro: Vector3, gravity: Vector3, delta: float) -> void:
	# the phone turned by gyro*delta, so the world turned the other way, as seen from it
	if gyro.length() > 0.0:
		_world_in_phone = Basis(gyro.normalized(), -gyro.length() * delta) * _world_in_phone
	# gyroscopes drift: nudge "up" back toward the real up that gravity gives
	if gravity.length() > 0.1:
		var up := _world_in_phone.y.normalized()
		var real_up := -gravity.normalized()
		var axis := up.cross(real_up)
		if axis.length() > 0.0001:
			var angle := up.angle_to(real_up) * minf(1.0, level_correction * delta)
			_world_in_phone = Basis(axis.normalized(), angle) * _world_in_phone
	_world_in_phone = _world_in_phone.orthonormalized()


## Levels the view with gravity (if there's a sensor) and faces it toward him.
func _start_orientation() -> void:
	var gravity := Input.get_gravity()
	var real_up := -gravity.normalized() if gravity.length() > 0.1 else Vector3.UP
	_world_in_phone = Basis(Quaternion(Vector3.UP, real_up))
	_heading = Basis.IDENTITY
	var phone := _world_in_phone.transposed()
	# which way the back camera points, flattened; if the phone's lying flat, its top edge
	var facing := -phone.z
	if Vector2(facing.x, facing.z).length() < 0.2:
		facing = phone.y
	facing.y = 0.0
	var to_him := character.global_position - camera.global_position
	to_him.y = 0.0
	if facing.length() > 0.0001 and to_him.length() > 0.0001:
		_heading = Basis(Vector3.UP, facing.signed_angle_to(to_him, Vector3.UP))


func _update_camera_basis() -> void:
	# the phone in the world is the inverse of the world in the phone; the back camera looks
	# out along the phone's -Z, which is where a Camera3D looks too
	camera.global_basis = _heading * _world_in_phone.transposed()


func _update_image() -> void:
	var datatype := _feed.get_datatype()
	var mode := 0
	match datatype:
		CameraFeed.FEED_YCBCR:
			mode = 1
		CameraFeed.FEED_YCBCR_SEP:
			mode = 2
	_main_texture.which_feed = CameraServer.FEED_Y_IMAGE if mode == 2 else CameraServer.FEED_RGBA_IMAGE
	_material.set_shader_parameter("mode", mode)

	var image_size := _main_texture.get_size()
	var screen := _background.get_viewport_rect().size
	if image_size.x <= 0.0 or image_size.y <= 0.0 or screen.y <= 0.0:
		return
	var turns := image_quarter_turns
	if turns < 0:
		# Android reports the turn as a bare rotation in the feed's transform (about the
		# image's corner, so it can't be used as is: that samples off the edge of the image)
		turns = posmod(roundi(_feed.feed_transform.get_rotation() / (PI / 2.0)), 4)
	var shown_size := image_size if turns % 2 == 0 else Vector2(image_size.y, image_size.x)
	# crop whichever way the image overhangs the screen, so it fills it without stretching
	var image_aspect := shown_size.x / shown_size.y
	var screen_aspect := screen.x / screen.y
	var crop := Vector2.ONE
	if image_aspect > screen_aspect:
		crop.x = screen_aspect / image_aspect
	else:
		crop.y = image_aspect / screen_aspect
	if mirror_image:
		crop.x = -crop.x
	# screen UV -> centred -> cropped -> turned (a clockwise turn on screen samples the image
	# turned the other way) -> back to 0..1. UVs run top to bottom, like the image's rows.
	var uv := Transform2D(0.0, Vector2(0.5, 0.5)) * Transform2D(-turns * PI / 2.0, Vector2.ZERO) \
			* Transform2D(0.0, crop, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(-0.5, -0.5))
	_material.set_shader_parameter("uv_x", uv.x)
	_material.set_shader_parameter("uv_y", uv.y)
	_material.set_shader_parameter("uv_origin", uv.origin)


func _has_camera_permission() -> bool:
	if OS.get_name() != "Android" or CAMERA_PERMISSION in OS.get_granted_permissions():
		return true
	if OS.request_permission(CAMERA_PERMISSION):
		return true
	while true:
		var result: Array = await get_tree().on_request_permissions_result
		if result[0] == CAMERA_PERMISSION:
			return result[1]
	return false


## The back camera (or any camera, failing that). Feeds can take a moment to show up once
## monitoring starts, so this waits up to a couple of seconds for one.
func _find_back_camera() -> CameraFeed:
	CameraServer.monitoring_feeds = true
	var give_up := Time.get_ticks_msec() + 2000
	while true:
		var feeds := CameraServer.feeds()
		for feed in feeds:
			if feed.get_position() == CameraFeed.FEED_BACK:
				return feed
		if feeds and Time.get_ticks_msec() > give_up - 1500:
			return feeds[0]
		if Time.get_ticks_msec() > give_up:
			CameraServer.monitoring_feeds = false
			return null
		await get_tree().process_frame
	return null


## Picks the largest format up to 1920 pixels wide (sharp enough, without the cost of 4K),
## preferring YUV: Godot's Android camera handles that one's row padding, but not the RGB
## ones', which can come out garbled.
func _pick_format(feed: CameraFeed) -> void:
	var formats := feed.get_formats()
	var best := -1
	var best_score := -1
	for i in formats.size():
		var format := formats[i] as Dictionary
		var width: int = format.get("width", 0)
		if width > 1920:
			continue
		var score := width + (100000 if format.get("format", "") == "YUV_420_888" else 0)
		if score > best_score:
			best = i
			best_score = score
	if best == -1 and formats:
		best = 0
	if best != -1:
		feed.set_format(best, {})
