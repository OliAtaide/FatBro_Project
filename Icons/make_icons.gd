extends SceneTree
## Renders Judson's bust and builds the Android launcher icons into res://Icons/.
## Run from the project folder: godot --path . -s res://Icons/make_icons.gd
##
## The render is framed as the 108dp adaptive-icon canvas: the head sits inside the central
## 66dp safe circle, the shoulders run off the bottom edge.

const OUT_DIR := "res://Icons/"
const RENDER := 1024
const CANVAS := 432
const BG_INNER := Color("#1fa8a0")
const BG_OUTER := Color("#006b6b")

var _vp: SubViewport
var _judson: Node3D
var _cam: Camera3D
var _frames := 0


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(RENDER, RENDER)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	for l: Array in [[Vector3(1.0, 1.6, 2.5), 1.1], [Vector3(-1.5, 1.2, 2.0), 0.6]]:
		var light := OmniLight3D.new()
		light.position = l[0]
		light.light_energy = l[1]
		light.omni_range = 10.0
		_vp.add_child(light)

	_judson = load("res://Blender/Chars/judson.tscn").instantiate()
	_vp.add_child(_judson)

	_cam = Camera3D.new()
	_cam.fov = 16.8
	_vp.add_child(_cam)
	_cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	var skel := _judson.find_children("*", "Skeleton3D").front() as Skeleton3D
	var head := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Head")).origin
	var target := head + Vector3(0, 0.10, 0)
	_cam.look_at_from_position(target + Vector3(0, 0.04, 3.2), target)
	if _frames < 30:
		return false

	var render := _vp.get_texture().get_image()
	render.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var fg := render.duplicate() as Image
	fg.resize(CANVAS, CANVAS, Image.INTERPOLATE_LANCZOS)
	_save(fg, "adaptive_foreground_432x432.png")

	var bg := _background(CANVAS)
	_save(bg, "adaptive_background_432x432.png")

	_save(_monochrome(fg), "adaptive_monochrome_432x432.png")

	# legacy icon: what a launcher shows of the adaptive one (the central 72dp of 108dp),
	# as a rounded square
	var full := _background(RENDER)
	full.blend_rect(render, Rect2i(0, 0, RENDER, RENDER), Vector2i.ZERO)
	var visible := RENDER * 72 / 108
	var legacy := full.get_region(Rect2i((RENDER - visible) / 2, (RENDER - visible) / 2, visible, visible))
	_round_corners(legacy, 0.22)
	var main := legacy.duplicate() as Image
	main.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	_save(main, "main_192x192.png")
	var big := legacy.duplicate() as Image
	big.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	_save(big, "icon_512x512.png")
	return true


func _save(img: Image, file: String) -> void:
	var err := img.save_png(OUT_DIR + file)
	print("saved ", OUT_DIR + file, " err=", err)


func _background(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.42)
	var r := size * 0.75
	for y in size:
		for x in size:
			var t := clampf(Vector2(x, y).distance_to(c) / r, 0.0, 1.0)
			img.set_pixel(x, y, BG_INNER.lerp(BG_OUTER, t * t))
	return img


## White where he's dark (hair, glasses, brows, mouth): his features, as a stencil.
func _monochrome(fg: Image) -> Image:
	var img := Image.create_empty(fg.get_width(), fg.get_height(), false, Image.FORMAT_RGBA8)
	for y in fg.get_height():
		for x in fg.get_width():
			var p := fg.get_pixel(x, y)
			var ink := smoothstep(0.42, 0.22, p.get_luminance())
			# solid pixels only (edges fade dark against the clear background), and nothing below his chin
			var keep := smoothstep(0.8, 1.0, p.a) * smoothstep(0.72, 0.68, float(y) / fg.get_height())
			img.set_pixel(x, y, Color(1, 1, 1, ink * keep))
	return img


func _round_corners(img: Image, radius_frac: float) -> void:
	var s := img.get_width()
	var r := s * radius_frac
	for y in s:
		for x in s:
			var px := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(clampf(px.x, r, s - r), clampf(px.y, r, s - r))
			var d := px.distance_to(q) - r
			var cover := clampf(0.5 - d, 0.0, 1.0)
			if cover < 1.0:
				var p := img.get_pixel(x, y)
				p.a *= cover
				img.set_pixel(x, y, p)
