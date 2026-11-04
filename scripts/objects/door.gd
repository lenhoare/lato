extends StaticBody2D
## Locked door spanning `height` tiles. Opens (slides up and fades) when the
## player touches it while carrying a key.

@export var height := 2

const TILE := 64.0
var _open := false
var _sprites: Array[Sprite2D] = []


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE * height)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, TILE * height / 2.0)
	add_child(shape)
	for i in height:
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(0, i * TILE)
		var name_ := "doorGreen_top" if i < height - 1 else "doorGreen_lock"
		s.texture = load("res://assets/PNG/Other/%s.png" % name_)
		add_child(s)
		_sprites.append(s)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var sshape := CollisionShape2D.new()
	var srect := RectangleShape2D.new()
	srect.size = Vector2(TILE + 24.0, TILE * height)
	sshape.shape = srect
	sshape.position = shape.position
	sensor.add_child(sshape)
	add_child(sensor)
	sensor.body_entered.connect(_on_touch)
	sensor.body_exited.connect(func(_b: Node) -> void: Game.hide_hint.emit())


func _on_touch(body: Node) -> void:
	if _open or not body is Player:
		return
	if Game.use_key():
		_open = true
		Game.hide_hint.emit()
		Game.shake(6.0, 0.5)
		var center := global_position + Vector2(TILE / 2.0, TILE * height / 2.0)
		FX.burst(get_parent(), center, Color(0.7, 1.7, 0.8), 30, 300.0, 0.7, 1.2)
		FX.ring(get_parent(), center, Color(0.7, 1.7, 0.8), 140.0, 0.5, 6.0)
		collision_layer = 0
		var t := create_tween().set_parallel(true)
		for s in _sprites:
			t.tween_property(s, "position:y", s.position.y - TILE * height, 0.7) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_property(s, "modulate:a", 0.0, 0.7)
	else:
		Game.show_hint.emit("Locked.  You need a key.")
