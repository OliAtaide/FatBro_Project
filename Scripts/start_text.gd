class_name StartText
extends CanvasLayer

## The welcome card shown when the app opens. The rest of the HUD waits for it: closing
## the card fades it away and then emits [signal closed].

signal closed

@export var fade_time := 0.3

@onready var _dim: Control = $Dim
@onready var _card: Control = $MarginContainer


func _ready() -> void:
	%CloseButton.pressed.connect(close)
	_fade(1.0)


func close() -> void:
	%CloseButton.disabled = true
	_fade(0.0).tween_callback(func() -> void:
		closed.emit()
		queue_free())


func _fade(alpha: float) -> Tween:
	var tween := create_tween().set_parallel()
	for node in [_dim, _card]:
		node.modulate.a = 1.0 - alpha
		tween.tween_property(node, "modulate:a", alpha, fade_time)
	return tween.chain()
