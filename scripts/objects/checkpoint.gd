extends Area2D
## Checkpoint flag. Touch it to set your respawn point.

var _active := false
var _flag: Sprite2D
var _light: PointLight2D

const TILE := 64.0


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 128)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, 0)
	add_child(shape)
	_flag = Sprite2D.new()
	_flag.centered = false
	_flag.texture = load("res://assets/PNG/Other/flagGreen_down.png")
	_flag.position = Vector2(24, TILE - 61)
	add_child(_flag)
	_light = FX.make_light(200.0, Color(0.6, 1.0, 0.7), 0.0)
	_light.position = Vector2(TILE / 2.0, 20)
	add_child(_light)
	body_entered.connect(_on_body_entered)
	# light up the flag we restored from a save
	if Game.has_save and Game.checkpoint.distance_to(global_position + Vector2(TILE / 2.0, TILE)) < 1.0:
		_active = true
		_flag.texture = load("res://assets/PNG/Other/flagGreen_up.png")
		_light.energy = 1.0


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	Game.checkpoint = global_position + Vector2(TILE / 2.0, TILE)
	Game.save_game()
	if _active:
		return
	for c in get_tree().get_nodes_in_group("checkpoint"):
		if c != self:
			c.deactivate()
	_active = true
	Sfx.play("checkpoint", 1.0, -3.0, 0.0)
	_flag.texture = load("res://assets/PNG/Other/flagGreen_up.png")
	_flag.scale = Vector2(0.5, 1.3)
	create_tween().tween_property(_flag, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(_light, "energy", 1.0, 0.5)
	FX.burst(get_parent(), global_position + Vector2(40, 10), Color(0.7, 1.7, 0.9), 18, 240.0, 0.6)


func deactivate() -> void:
	if _active:
		_active = false
		_flag.texture = load("res://assets/PNG/Other/flagGreen_down.png")
		create_tween().tween_property(_light, "energy", 0.0, 0.5)
