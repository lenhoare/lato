extends Node2D
## Spirit lantern: a floating light the player can Bash off.

const COLOR := Color(1.8, 1.3, 0.6)

var _t := randf() * TAU
var _home: Vector2
var _offset := Vector2.ZERO
var _vel := Vector2.ZERO
var _core: Sprite2D
var _halo: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	add_to_group("bashable")
	_home = position
	_light = FX.make_light(260.0, Color(1.0, 0.8, 0.5), 0.9)
	add_child(_light)
	_halo = FX.make_glow_sprite(130.0, Color(COLOR, 0.4))
	add_child(_halo)
	var cage := Sprite2D.new()
	cage.texture = load("res://assets/PNG/Items/outlineDisc.png")
	cage.modulate = Color(1.4, 1.2, 0.9)
	add_child(cage)
	_core = FX.make_glow_sprite(40.0, Color(2.0, 1.6, 0.9))
	add_child(_core)


func _process(delta: float) -> void:
	_t += delta
	# spring back after being bashed
	_vel += (-_offset * 90.0 - _vel * 9.0) * delta
	_offset += _vel * delta
	position = _home + _offset + Vector2(0, sin(_t * 1.6) * 6.0)
	var p := Game.player as Player
	var near := p != null and Game.has("bash") and \
			global_position.distance_to(p.global_position + Vector2(0, -21)) < p.bash_radius
	var target_scale := 1.35 if near else 1.0
	_halo.scale = _halo.scale.lerp(Vector2.ONE * (130.0 / 128.0) * target_scale, 1.0 - exp(-8.0 * delta))
	_light.energy = lerpf(_light.energy, 1.4 if near else 0.9, 1.0 - exp(-8.0 * delta))


func on_bash_grab() -> void:
	_core.scale *= 1.4


func on_bashed(push_dir: Vector2) -> void:
	_vel += push_dir * 700.0
	FX.burst(get_parent(), global_position, COLOR, 16, 260.0, 0.5)
