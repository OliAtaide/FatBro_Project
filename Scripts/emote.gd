extends Resource
class_name EmoteData

@export var title : String = ''
## A Mixamo clip, retargeted onto his skeleton by its import settings.
@export var animation : AnimationLibrary = null
## Optional. With one, the emote loops until the sound has played out (and the music
## fades out for it).
@export var audio : AudioStream = null

@export_group("Arms")
## Mixamo moves are made for slim people; these steer his arms while the emote plays (see
## [ArmSpreadModifier3D]), in degrees. More spread swings them out, clear of his big head.
@export_range(-60.0, 60.0, 0.5) var arm_spread := 0.0
## Swings his arms forward and up, out in front of his belly.
@export_range(-60.0, 60.0, 0.5) var arm_forward := 0.0
## Tips his forearms forward at the elbows, so his hands reach out past his belly.
@export_range(-90.0, 90.0, 0.5) var forearm_forward := 0.0
## Then swings his arms toward his middle, so his hands can meet in front of his belly.
@export_range(-90.0, 90.0, 0.5) var arm_inward := 0.0
@export_group("")


## Name of the clip in [member animation]. (Mixamo files hold just the one, "mixamo_com".)
func clip_name() -> StringName:
	return animation.get_animation_list()[0]


func clip() -> Animation:
	return animation.get_animation(clip_name())
