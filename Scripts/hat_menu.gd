class_name HatMenu
extends BottomSheet

## The wardrobe: a card for every hat, plus one to take it off. Like the snack bag, each
## card's picture is a little render of the hat's model.

## [param hat] is null for "no hat".
signal hat_chosen(hat: HatData)

@export var hats: Array[HatData] = []
## Shown on the card that takes the hat off. Optional.
@export var no_hat_icon: Texture2D

## Each hat's card picture, for the HUD's hat button.
var icons := {}


func _ready() -> void:
	super()
	_add_card("No Hat", no_hat_icon, hat_chosen.emit.bind(null))
	for hat in hats:
		icons[hat] = _render_icon(hat)
		_add_card(hat.title, icons[hat], hat_chosen.emit.bind(hat))


func _render_icon(hat: HatData) -> Texture2D:
	var holder := Node3D.new()
	var model := hat.instantiate_fitted(0.2)
	# no fit tweaks in the picture: it's the hat on show, not how it sits on him
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	holder.add_child(model)
	holder.rotation.y = deg_to_rad(-25.0)
	return _snapshot(holder, Vector3(0.0, 0.2, 0.45), Vector3(0.0, 0.05, 0.0))
