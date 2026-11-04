extends Area2D
## A row of floor spikes covering `length` tiles. Touching it sends the player
## back to the last checkpoint.

var length := 1
const TILE := 64.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE * length - 12.0, 20.0)
	shape.shape = rect
	shape.position = Vector2(TILE * length / 2.0, TILE - 10.0)
	add_child(shape)
	var tex: Texture2D = load("res://assets/PNG/Other/spikesHigh.png")
	for i in length:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(i * TILE, TILE - tex.get_height())
		add_child(s)
	body_entered.connect(func(b: Node) -> void:
		if b is Player:
			b.die())
