extends Resource
class_name EmoteData

@export var title : String = ''
## A Mixamo clip, retargeted onto his skeleton by its import settings.
@export var animation : AnimationLibrary = null
## Optional. With one, the emote loops until the sound has played out (and the music
## fades out for it).
@export var audio : AudioStream = null


## Name of the clip in [member animation]. (Mixamo files hold just the one, "mixamo_com".)
func clip_name() -> StringName:
	return animation.get_animation_list()[0]


func clip() -> Animation:
	return animation.get_animation(clip_name())
