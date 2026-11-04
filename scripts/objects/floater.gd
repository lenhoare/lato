extends Area2D
## Floating spiky enemy. Hurts on touch, drifts in a lazy loop, and can be
## Bashed (which flings it away in the opposite direction).

var _t := randf() * TAU
var _home: Vector2
var _knock := Vector2.ZERO
var _sprite: Sprite2D
var _stunned := 0.0
var _hp := 2
var _dead := false
const MAX_HP := 2
const RESPAWN_TIME := 10.0


func _ready() -> void:
	add_to_group("bashable")
	add_to_group("enemy")
	collision_layer = 4
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
	if body is Player and _stunned <= 0.0 and not _dead:
		var p := body as Player
		if p.state != Player.State.BASH_AIM and p.bash_launch_timer <= 0.0:
			p.die()


## Hit by a Light Burst.
func hit(dir: Vector2) -> void:
	if _dead:
		return
	_hp -= 1
	_knock += dir * 180.0
	_stunned = 0.4
	_sprite.modulate = Color(3, 3, 3)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	if _hp <= 0:
		_die()
	else:
		Sfx.play("enemy_hit")


func _die() -> void:
	_dead = true
	visible = false
	set_deferred("monitoring", false)
	remove_from_group("bashable")
	Sfx.play("enemy_die")
	Game.hitstop(0.05, 0.08)
	FX.burst(get_parent(), global_position, Color(1.6, 0.5, 0.5), 26, 360.0, 0.7, 1.3)
	FX.burst(get_parent(), global_position, Color(1.6, 1.4, 0.9), 14, 200.0, 1.0, 0.8, Vector2.UP, 60.0, -40.0)
	await get_tree().create_timer(RESPAWN_TIME, false).timeout
	_hp = MAX_HP
	_dead = false
	_knock = Vector2.ZERO
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
	_stunned = 1.0  # harmless while fading back in
	set_deferred("monitoring", true)
	add_to_group("bashable")


func on_bashed(push_dir: Vector2) -> void:
	_knock += push_dir * 260.0
	_stunned = 0.6
	FX.burst(get_parent(), global_position, Color(1.6, 0.5, 0.5), 14, 260.0, 0.5)
