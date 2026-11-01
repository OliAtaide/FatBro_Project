extends Node3D

# Mixamo idle, retargeted onto Judson's skeleton by the import settings
const IDLE_LIBRARY := preload("res://Mixamo/Idle.fbx")
const IDLE := &"mixamo/mixamo_com"


func _ready() -> void:
	var anim := find_children("*", "AnimationPlayer").front() as AnimationPlayer
	anim.add_animation_library(&"mixamo", IDLE_LIBRARY)
	anim.play(IDLE)
