extends AudioStreamPlayer

## The background music. Fades out and pauses while he plays one of his own tunes
## (see [signal Judson.performing_changed]), then picks up again where it left off.

@export var character: Judson
@export var fade_time := 0.5

var _volume: float
var _tween: Tween


func _ready() -> void:
	_volume = volume_db
	if character:
		character.performing_changed.connect(_on_performing_changed)
	play()


func _on_performing_changed(performing: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if performing:
		_tween.tween_property(self, "volume_db", -40.0, fade_time)
		_tween.tween_callback(set.bind("stream_paused", true))
	else:
		stream_paused = false
		_tween.tween_property(self, "volume_db", _volume, fade_time)
