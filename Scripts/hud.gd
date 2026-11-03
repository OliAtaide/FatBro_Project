extends CanvasLayer

## On-screen controls: a pair of buttons on either side of the character, kept there
## whatever the phone's aspect ratio. Normally they're emote and food; once a snack is
## picked they become back (put it away) and swap snack, until back is pressed.

@export var character: Judson
@export var feeder: Feeder
## Welcome card shown on launch. The buttons stay hidden until it's closed. Optional.
@export var start_text: StartText
## Where the right-hand button sits, in the character's own space (metres; +X is his
## left, which is the right of the screen). The left-hand button mirrors it.
@export var button_spot := Vector3(0.8, 0.55, 0.0)
@export var swap_time := 0.15

var _swap_tween: Tween

@onready var _wave_button: Button = $WaveButton
@onready var _food_button: Button = $FoodButton
@onready var _back_button: Button = $BackButton
@onready var _swap_food_button: Button = $SwapFoodButton
@onready var _food_menu: FoodMenu = $FoodMenu
@onready var _emote_menu: EmoteMenu = $EmoteMenu
## Left-hand button, right-hand button.
@onready var _main_buttons: Array[Button] = [_food_button, _wave_button]
@onready var _feeding_buttons: Array[Button] = [_back_button, _swap_food_button]


func _ready() -> void:
	_wave_button.pressed.connect(_emote_menu.open)
	_emote_menu.emote_chosen.connect(character.emote)
	character.down_changed.connect(func(down: bool) -> void: _wave_button.disabled = down)
	_food_button.pressed.connect(_food_menu.open)
	_swap_food_button.pressed.connect(_food_menu.open)
	_food_menu.food_chosen.connect(_on_food_chosen)
	_back_button.pressed.connect(_on_back_pressed)
	for button in _feeding_buttons:
		button.hide()
	# nothing to press until the welcome card's been closed
	if start_text:
		for button in _main_buttons:
			button.hide()
		start_text.closed.connect(_swap_buttons.bind([] as Array[Button], _main_buttons))


func _process(_delta: float) -> void:
	for buttons in [_main_buttons, _feeding_buttons]:
		_place(buttons[0], button_spot * Vector3(-1.0, 1.0, 1.0))
		_place(buttons[1], button_spot)


func _on_food_chosen(food: FoodData) -> void:
	feeder.hold(food)
	_swap_buttons(_main_buttons, _feeding_buttons)


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
