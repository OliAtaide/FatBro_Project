extends CanvasLayer

## On-screen controls. Keeps the wave and food buttons on either side of the
## character, whatever the phone's aspect ratio.

@export var character: Judson
@export var feeder: Feeder
## Where the wave button sits, in the character's own space (metres; +X is his left,
## which is the right of the screen). The food button mirrors it on his other side.
@export var button_spot := Vector3(0.8, 0.55, 0.0)

@onready var _wave_button: Button = $WaveButton
@onready var _food_button: Button = $FoodButton
@onready var _food_menu: FoodMenu = $FoodMenu
@onready var _emote_menu: EmoteMenu = $EmoteMenu


func _ready() -> void:
	_wave_button.pressed.connect(_emote_menu.open)
	_emote_menu.emote_chosen.connect(character.emote)
	character.down_changed.connect(func(down: bool) -> void: _wave_button.disabled = down)
	_food_button.pressed.connect(_food_menu.open)
	_food_menu.food_chosen.connect(feeder.hold)


func _process(_delta: float) -> void:
	_place(_wave_button, button_spot)
	_place(_food_button, button_spot * Vector3(-1.0, 1.0, 1.0))


## Centres [param button] on [param spot] (in the character's space), kept on screen.
func _place(button: Control, spot: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	var screen := get_viewport().get_visible_rect().size
	var center := camera.unproject_position(character.to_global(spot))
	var top_left := center - button.size / 2.0
	var margin := 8.0
	button.position = top_left.clamp(Vector2.ONE * margin, screen - button.size - Vector2.ONE * margin)
