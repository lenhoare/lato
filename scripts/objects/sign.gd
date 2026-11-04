extends Area2D
## A sign post that shows a hint while the player stands near it.

var text := ""
const TILE := 64.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(170, 128)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, 0)
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = load("res://assets/PNG/Other/signSmall.png")
	s.centered = false
	s.position = Vector2(10, TILE - 55)
	add_child(s)
	var light := FX.make_light(110.0, Color(0.9, 0.9, 0.7), 0.5)
	light.position = Vector2(TILE / 2.0, 30)
	add_child(light)
	body_entered.connect(func(b: Node) -> void:
		if b is Player:
			Game.show_hint.emit(text))
	body_exited.connect(func(b: Node) -> void:
		if b is Player:
			Game.hide_hint.emit())
