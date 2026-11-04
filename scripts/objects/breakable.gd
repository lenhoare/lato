extends StaticBody2D
## Cracked stone made of one or more tiles. Shatters when the player dashes into it.

const TILE := 64.0
var cells: Array[Vector2i] = []  # local cell offsets, set before adding to tree
var _broken := false


func _ready() -> void:
	add_to_group("breakable")
	collision_layer = 1
	for c in cells:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE, TILE)
		shape.shape = rect
		shape.position = Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0
		add_child(shape)
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(c) * TILE
		s.texture = load("res://assets/PNG/Other/blockBrown_broken.png")
		add_child(s)


## True if any of this wall's tiles is within `r` of `pos`.
func touches(pos: Vector2, r: float) -> bool:
	for c in cells:
		var rect := Rect2(global_position + Vector2(c) * TILE, Vector2(TILE, TILE)).grow(r)
		if rect.has_point(pos):
			return true
	return false


func shatter(dir: int) -> void:
	if _broken:
		return
	_broken = true
	Game.mark(get_meta("id", ""))
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	Game.shake(8.0, 0.25)
	Game.rumble(0.5, 0.5, 0.2)
	Sfx.play("break")
	Game.hitstop(0.04, 0.1)
	for c in cells:
		var center := global_position + Vector2(c) * TILE + Vector2(TILE, TILE) / 2.0
		FX.burst(get_parent(), center, Color(0.75, 0.55, 0.4), 12, 420.0, 0.8, 2.2,
				Vector2(dir, -0.3), 60.0, 900.0)
		FX.burst(get_parent(), center, Color(0.6, 0.9, 1.6), 8, 260.0, 0.5, 1.0)
	queue_free()
