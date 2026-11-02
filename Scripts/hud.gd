extends CanvasLayer

## On-screen controls. Keeps the wave button beside the character, whatever the
## phone's aspect ratio.

@export var character: Judson
## Where the button sits, in the character's own space (metres; +X is his left,
## which is the right of the screen).
@export var button_spot := Vector3(0.8, 0.55, 0.0)

@onready var _wave_button: Button = $WaveButton


func _ready() -> void:
	_wave_button.pressed.connect(character.wave)
	character.down_changed.connect(func(down: bool) -> void: _wave_button.disabled = down)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var screen := get_viewport().get_visible_rect().size
	var center := camera.unproject_position(character.to_global(button_spot))
	var top_left := center - _wave_button.size / 2.0
	var margin := 8.0
	_wave_button.position = top_left.clamp(Vector2.ONE * margin, screen - _wave_button.size - Vector2.ONE * margin)
