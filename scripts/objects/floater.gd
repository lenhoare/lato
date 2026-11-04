extends Area2D
## Floating spiky enemy. Hurts on touch, drifts in a lazy loop, and can be
## Bashed (which flings it away in the opposite direction).

var _t := randf() * TAU
var _home: Vector2
var _knock := Vector2.ZERO
var _sprite: Sprite2D
var _stunned := 0.0


func _ready() -> void:
	add_to_group("bashable")
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 17.0
	shape.shape = c
	add_child(shape)
	add_child(FX.make_glow_sprite(80.0, Color(1.6, 0.4, 0.4, 0.35)))
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/PNG/Enemies/enemyFloating_1.png")
	add_child(_sprite)
	_home = global_position
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	_stunned -= delta
	_knock = _knock.lerp(Vector2.ZERO, 1.0 - exp(-2.5 * delta))
	var loop := Vector2(cos(_t * 0.9) * 48.0, sin(_t * 1.8) * 22.0)
	global_position = _home + loop + _knock
	_sprite.rotation += delta * (1.2 + _knock.length() * 0.02)


func _on_body_entered(body: Node) -> void:
	if body is Player and _stunned <= 0.0:
		var p := body as Player
		if p.state != Player.State.BASH_AIM and p.bash_launch_timer <= 0.0:
			p.die()


func on_bashed(push_dir: Vector2) -> void:
	_knock += push_dir * 260.0
	_stunned = 0.6
	FX.burst(get_parent(), global_position, Color(1.6, 0.5, 0.5), 14, 260.0, 0.5)
