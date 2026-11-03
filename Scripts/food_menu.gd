class_name FoodMenu
extends BottomSheet

## The snack bag: a card for every food. Each card's picture is a little render of the
## food's model, so new foods need no art.

signal food_chosen(food: FoodData)

@export var foods: Array[FoodData] = []


func _ready() -> void:
	super()
	for food in foods:
		_add_card(food.title, _render_icon(food), food_chosen.emit.bind(food))


func _render_icon(food: FoodData) -> Texture2D:
	var model := food.instantiate_fitted(0.2)
	model.rotation.y = deg_to_rad(-25.0)
	return _snapshot(model, Vector3(0.0, 0.12, 0.45), Vector3.ZERO)
