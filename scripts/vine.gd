extends Node2D
## A hanging vine simulated as a little rope (verlet integration).
## Sways in the wind, swings when the player brushes through it, and gets
## whooshed by dashes / bashes / landings (Game.world_impulse). The tip glows.

@export var segments := 5
@export var segment_length := 20.0
@export var color := Color(0.16, 0.42, 0.34)
@export var tip_color := Color(0.6, 1.4, 1.1)

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _t := randf() * 10.0
var _awake := true
var _bulb: Sprite2D


func _ready() -> void:
	z_index = -1
	for i in segments + 1:
		_pts.append(Vector2(0, i * segment_length))
		_prev.append(Vector2(0, i * segment_length))
	_bulb = FX.make_glow_sprite(70.0, Color(tip_color, 0.7))
	add_child(_bulb)
	Game.world_impulse.connect(_on_impulse)


func _on_impulse(pos: Vector2, radius: float, strength: float) -> void:
	for i in range(1, _pts.size()):
		var world := global_position + _pts[i]
		var d := world.distance_to(pos)
		if d < radius:
			var push := (world - pos).normalized() * strength * 9.0 * (1.0 - d / radius)
			_prev[i] -= push


func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		var c := cam.get_screen_center_position()
		_awake = absf(global_position.x - c.x) < 1000.0 and absf(global_position.y - c.y) < 650.0
	if not _awake:
		return
	_t += delta
	var wind := Vector2(sin(_t * 1.3 + global_position.x * 0.01) * 60.0 + sin(_t * 3.7) * 20.0, 0)
	var g := Vector2(0, 900.0)
	var player := Game.player as Player
	var pc := Vector2(-99999, 0)
	var pv := Vector2.ZERO
	if player:
		pc = player.global_position + Vector2(0, -21) - global_position
		pv = player.velocity
	for i in range(1, _pts.size()):
		var p := _pts[i]
		var v := (p - _prev[i]) * 0.985
		_prev[i] = p
		p += v + (g + wind) * delta * delta
		# brushed by the player
		var to := p - pc
		var dist := to.length()
		if dist < 24.0:
			p += to.normalized() * (24.0 - dist) * 0.5
			p += pv * delta * 0.35
		_pts[i] = p
	for _k in 4:
		_pts[0] = Vector2.ZERO
		for i in _pts.size() - 1:
			var a := _pts[i]
			var b := _pts[i + 1]
			var diff := b - a
			var l := diff.length()
			if l < 0.001:
				continue
			var corr := diff * (1.0 - segment_length / l)
			if i == 0:
				_pts[i + 1] = b - corr
			else:
				_pts[i] = a + corr * 0.5
				_pts[i + 1] = b - corr * 0.5
	_bulb.position = _pts[_pts.size() - 1]
	queue_redraw()


func _draw() -> void:
	draw_polyline(_pts, color, 6.0, true)
	# leaves alternate sides along the vine
	for i in range(1, _pts.size()):
		var dir := (_pts[i] - _pts[i - 1]).normalized()
		var side := dir.orthogonal() * (1.0 if i % 2 == 0 else -1.0)
		var base := _pts[i - 1].lerp(_pts[i], 0.6)
		var tip := base + side * 16.0 + dir * 8.0
		draw_colored_polygon(PackedVector2Array([base, base + side * 7.0 - dir * 4.0, tip,
				base + dir * 7.0]), Color(color.r * 1.3, color.g * 1.3, color.b * 1.2))
	draw_circle(_pts[_pts.size() - 1], 6.0, tip_color)
