extends CanvasLayer

## On-screen controls: a pair of buttons on either side of the character, kept there
## whatever the phone's aspect ratio. Normally they're emote and food, with the hat
## button over the food one (and the costume button over that) and the AR button (phones
## only) over the emote one; once a snack is picked they become back (put it away) and
## swap snack, until back is pressed.
## In AR the buttons stay put on screen, since the view turns with the phone. The photo
## button sits at the bottom of the screen and saves what's on screen (minus the buttons)
## to the phone's Pictures, so it shows up in the gallery.

@export var character: Judson
@export var feeder: Feeder
## Welcome card shown on launch. The buttons stay hidden until it's closed. Optional.
@export var start_text: StartText
## Switches the camera view on and off. Optional; without it there's no AR button.
@export var ar_view: ArView
## Where the right-hand button sits, in the character's own space (metres; +X is his
## left, which is the right of the screen). The left-hand button mirrors it.
@export var button_spot := Vector3(0.8, 0.55, 0.0)
## Where the hat button sits, in the character's space.
@export var hat_button_spot := Vector3(-0.8, 1.0, 0.0)
## Where the AR button sits, in the character's space.
@export var ar_button_spot := Vector3(0.8, 1.0, 0.0)
## Where the costume button sits, in the character's space.
@export var costume_button_spot := Vector3(-0.8, 1.45, 0.0)
@export var swap_time := 0.15
## Gap between the photo button and the bottom of the screen (pixels).
@export var photo_button_margin := 36.0
## Where photos go. Empty means the system's Pictures folder (on Android 11+ that lands in
## the gallery; older versions would need a storage permission, so it falls back to the
## app's own folder there).
@export var photo_folder := ""

## Remembers the player's choices (his costume, colours and hat) between launches.
const SETTINGS_PATH := "user://settings.cfg"

var _swap_tween: Tween
## Frames left before the buttons stop following him (in AR), or -1 while they follow.
var _freeze_in := -1
var _taking_photo := false
var _flash := ColorRect.new()
var _toast := PanelContainer.new()
var _toast_label := Label.new()
var _toast_tween: Tween

@onready var _wave_button: Button = $WaveButton
@onready var _food_button: Button = $FoodButton
@onready var _back_button: Button = $BackButton
@onready var _swap_food_button: Button = $SwapFoodButton
@onready var _food_menu: FoodMenu = $FoodMenu
@onready var _emote_menu: EmoteMenu = $EmoteMenu
@onready var _hat_button: Button = $HatButton
@onready var _hat_menu: HatMenu = $HatMenu
@onready var _costume_button: Button = $CostumeButton
@onready var _costume_menu: CostumeMenu = $CostumeMenu
@onready var _ar_button: Button = $ARButton
@onready var _photo_button: Button = $PhotoButton
## Left-hand button, right-hand button (then the hat, costume, photo and AR buttons, for the
## main ones).
@onready var _main_buttons: Array[Button] = [_food_button, _wave_button, _hat_button,
		_costume_button, _photo_button]
@onready var _feeding_buttons: Array[Button] = [_back_button, _swap_food_button]


func _ready() -> void:
	_wave_button.pressed.connect(_emote_menu.open)
	_emote_menu.emote_chosen.connect(character.emote)
	character.down_changed.connect(func(down: bool) -> void: _wave_button.disabled = down)
	_food_button.pressed.connect(_food_menu.open)
	_swap_food_button.pressed.connect(_food_menu.open)
	_food_menu.food_chosen.connect(_on_food_chosen)
	_back_button.pressed.connect(_on_back_pressed)
	_hat_button.pressed.connect(_hat_menu.open)
	_hat_menu.hat_chosen.connect(_on_hat_chosen)
	_show_hat_on_button(null)
	_costume_button.pressed.connect(_costume_menu.open)
	_costume_menu.costume_chosen.connect(_on_costume_chosen)
	_costume_menu.shirt_color_chosen.connect(_on_shirt_color_chosen)
	_costume_menu.hair_color_chosen.connect(_on_hair_color_chosen)
	_load_wardrobe()
	_show_costume_on_button(character.costume)
	_costume_menu.show_colors(character.shirt_color, character.hair_color)
	_photo_button.pressed.connect(take_photo)
	_make_flash_and_toast()
	if ar_view and ar_view.is_supported():
		_main_buttons.append(_ar_button)
		_ar_button.pressed.connect(ar_view.toggle)
		ar_view.active_changed.connect(_on_ar_active_changed)
		ar_view.failed.connect(_on_ar_failed)
	else:
		_ar_button.hide()
	for button in _feeding_buttons:
		button.hide()
	# nothing to press until the welcome card's been closed
	if start_text:
		for button in _main_buttons:
			button.hide()
		start_text.closed.connect(_swap_buttons.bind([] as Array[Button], _main_buttons))


func _process(_delta: float) -> void:
	# (fixed on screen, so it's placed even while the others are frozen in AR)
	var screen := get_viewport().get_visible_rect().size
	_photo_button.position = Vector2((screen.x - _photo_button.size.x) / 2.0,
			screen.y - _photo_button.size.y - photo_button_margin)
	if _freeze_in == 0:
		return
	_freeze_in = maxi(_freeze_in - 1, -1)
	for buttons in [_main_buttons, _feeding_buttons]:
		_place(buttons[0], button_spot * Vector3(-1.0, 1.0, 1.0))
		_place(buttons[1], button_spot)
	_place(_hat_button, hat_button_spot)
	_place(_costume_button, costume_button_spot)
	_place(_ar_button, ar_button_spot)


## Saves what's on screen, without the buttons, as a PNG in [member photo_folder].
func take_photo() -> void:
	if _taking_photo:
		return
	_taking_photo = true
	# hide the HUD for one frame and grab that frame
	visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	visible = true
	_flash.modulate.a = 0.85
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.35)
	var saved_to := _save_photo(image)
	_show_toast("Photo saved to Pictures" if saved_to == "pictures"
			else "Photo saved" if saved_to else "Couldn't save the photo")
	_taking_photo = false


## Returns "pictures" if it went to the Pictures folder, another non-empty string if it went
## somewhere else, or "" if it couldn't be saved at all.
func _save_photo(image: Image) -> String:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var file := "Judson_%s.png" % stamp
	var folder := photo_folder if photo_folder else OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if folder and image.save_png(folder.path_join(file)) == OK:
		return "pictures" if not photo_folder else folder
	# no shared Pictures (or not allowed to write there): keep it in the app's own folder
	var fallback := "user://photos"
	DirAccess.make_dir_recursive_absolute(fallback)
	var error := image.save_png(fallback.path_join(file))
	if error != OK:
		push_warning("Couldn't save the photo: %s" % error_string(error))
		return ""
	return fallback


func _make_flash_and_toast() -> void:
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(18)
	style.content_margin_left = 30
	style.content_margin_right = 30
	_toast.add_theme_stylebox_override("panel", style)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_font_size_override("font_size", 30)
	_toast_label.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_toast.position = Vector2((screen.x - _toast.size.x) / 2.0, screen.y * 0.12)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _on_ar_active_changed(active: bool) -> void:
	_ar_button.text = "3D" if active else "AR"
	# in AR they stay where they were in the room view (the AR view turns with the phone)
	_freeze_in = 0 if active else -1


func _on_ar_failed(reason: String) -> void:
	push_warning("AR: " + reason)
	OS.alert(reason, "AR")


func _on_food_chosen(food: FoodData) -> void:
	feeder.hold(food)
	_swap_buttons(_main_buttons, _feeding_buttons)


func _on_hat_chosen(hat: HatData) -> void:
	character.wear(hat)
	_show_hat_on_button(hat)
	_save_wardrobe("hat", hat.resource_path if hat else "")


## The hat button shows the hat he's wearing, or the first one on offer if he's bare-headed.
func _show_hat_on_button(hat: HatData) -> void:
	if not hat and _hat_menu.hats:
		hat = _hat_menu.hats[0]
	_hat_button.icon = _hat_menu.icons.get(hat)


func _on_costume_chosen(costume: CostumeData) -> void:
	character.dress(costume)
	_show_costume_on_button(costume)
	_save_wardrobe("costume", costume.resource_path)


func _on_shirt_color_chosen(color: Color) -> void:
	character.shirt_color = color
	_save_wardrobe("shirt_color", color)


func _on_hair_color_chosen(color: Color) -> void:
	character.hair_color = color
	_save_wardrobe("hair_color", color)


func _save_wardrobe(key: String, value: Variant) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)  # (keeps whatever else is in there; fine if it's not there yet)
	settings.set_value("wardrobe", key, value)
	var error := settings.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Couldn't save the %s: %s" % [key, error_string(error)])


## Dresses him as he was last time: costume, hat (each if still in the game) and colours.
func _load_wardrobe() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	var path: String = settings.get_value("wardrobe", "costume", "")
	if path and ResourceLoader.exists(path):
		character.dress(load(path) as CostumeData, false)
	var shirt: Variant = settings.get_value("wardrobe", "shirt_color", character.shirt_color)
	if shirt is Color:
		character.shirt_color = shirt
	var hair: Variant = settings.get_value("wardrobe", "hair_color", character.hair_color)
	if hair is Color:
		character.hair_color = hair
	var hat_path: String = settings.get_value("wardrobe", "hat", "")
	if hat_path and ResourceLoader.exists(hat_path):
		var hat := load(hat_path) as HatData
		character.wear(hat)
		_show_hat_on_button(hat)


## The costume button shows him in what he's wearing (the first costume if he's in his own
## clothes).
func _show_costume_on_button(costume: CostumeData) -> void:
	if not costume and _costume_menu.costumes:
		costume = _costume_menu.costumes[0]
	_costume_button.icon = _costume_menu.icons.get(costume)


func _on_back_pressed() -> void:
	feeder.put_away()
	_swap_buttons(_feeding_buttons, _main_buttons)


## Shrinks [param from] away and pops [param to] in where they were.
func _swap_buttons(from: Array[Button], to: Array[Button]) -> void:
	if to[0].visible:
		return
	if _swap_tween:
		_swap_tween.kill()
	_swap_tween = create_tween().set_parallel()
	for button in from:
		button.pivot_offset = button.size / 2.0
		_swap_tween.tween_property(button, "scale", Vector2.ZERO, swap_time) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_swap_tween.chain().tween_callback(func() -> void:
		for button in from:
			button.hide()
		for button in to:
			button.scale = Vector2.ZERO
			button.show())
	_swap_tween.chain()
	for button in to:
		button.pivot_offset = button.size / 2.0
		_swap_tween.tween_property(button, "scale", Vector2.ONE, swap_time) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Centres [param button] on [param spot] (in the character's space), kept on screen.
func _place(button: Control, spot: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var screen := get_viewport().get_visible_rect().size
	var center := camera.unproject_position(character.to_global(spot))
	var top_left := center - button.size / 2.0
	var margin := 8.0
	button.position = top_left.clamp(Vector2.ONE * margin, screen - button.size - Vector2.ONE * margin)
