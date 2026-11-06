extends CanvasLayer

## On-screen controls: a pair of buttons on either side of the character, kept there
## whatever the phone's aspect ratio. Normally they're emote and food, with the hat
## button over the food one and the AR button (phones only) over the emote one; once a
## snack is picked they become back (put it away) and swap snack, until back is pressed.
## In AR the buttons stay put on screen, since the view turns with the phone.

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
@export var swap_time := 0.15

var _swap_tween: Tween
## Frames left before the buttons stop following him (in AR), or -1 while they follow.
var _freeze_in := -1

@onready var _wave_button: Button = $WaveButton
@onready var _food_button: Button = $FoodButton
@onready var _back_button: Button = $BackButton
@onready var _swap_food_button: Button = $SwapFoodButton
@onready var _food_menu: FoodMenu = $FoodMenu
@onready var _emote_menu: EmoteMenu = $EmoteMenu
@onready var _hat_button: Button = $HatButton
@onready var _hat_menu: HatMenu = $HatMenu
@onready var _ar_button: Button = $ARButton
## Left-hand button, right-hand button (then the hat and AR buttons, for the main ones).
@onready var _main_buttons: Array[Button] = [_food_button, _wave_button, _hat_button]
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
	if _freeze_in == 0:
		return
	_freeze_in = maxi(_freeze_in - 1, -1)
	for buttons in [_main_buttons, _feeding_buttons]:
		_place(buttons[0], button_spot * Vector3(-1.0, 1.0, 1.0))
		_place(buttons[1], button_spot)
	_place(_hat_button, hat_button_spot)
	_place(_ar_button, ar_button_spot)


func _on_ar_active_changed(active: bool) -> void:
	_ar_button.text = "3D" if active else "AR"
	# in AR: one more placement from the starting view, then they stay there
	_freeze_in = 1 if active else -1


func _on_ar_failed(reason: String) -> void:
	push_warning("AR: " + reason)
	OS.alert(reason, "AR")


func _on_food_chosen(food: FoodData) -> void:
	feeder.hold(food)
	_swap_buttons(_main_buttons, _feeding_buttons)


func _on_hat_chosen(hat: HatData) -> void:
	character.wear(hat)
	_show_hat_on_button(hat)


## The hat button shows the hat he's wearing, or the first one on offer if he's bare-headed.
func _show_hat_on_button(hat: HatData) -> void:
	if not hat and _hat_menu.hats:
		hat = _hat_menu.hats[0]
	_hat_button.icon = _hat_menu.icons.get(hat)


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
