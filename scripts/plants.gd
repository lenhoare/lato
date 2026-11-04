extends Node2D
## Decorative plants that sway in the wind and get brushed aside when the
## player runs or lands near them. Children are Sprite2Ds whose origin is at
## the plant's base.

var _angle := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _t := 0.0


func add_plant(tex: Texture2D, base: Vector2, flip: bool) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	s.flip_h = flip
	s.position = base
	add_child(s)
	_angle.append(0.0)
	_vel.append(0.0)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var p := Game.player as Player
	var pvel := p.velocity if p else Vector2.ZERO
	var ppos := p.global_position if p else Vector2(-99999, 0)
	var children := get_children()
	for i in children.size():
		var s: Sprite2D = children[i]
		var pos := s.position
		if absf(pos.x - c.x) > 1100.0 or absf(pos.y - c.y) > 700.0:
			continue
		# player brushing through
		var dx := ppos.x - pos.x
		if absf(dx) < 34.0 and absf(ppos.y - pos.y) < 50.0:
			if absf(pvel.x) > 40.0:
				_vel[i] += pvel.x * 0.0009
			if pvel.y > 300.0:
				_vel[i] += -signf(dx) * 0.35
		var wind := sin(_t * 1.4 + pos.x * 0.004) * 0.06 + sin(_t * 3.1 + pos.x * 0.02) * 0.02
		var acc := (wind - _angle[i]) * 70.0 - _vel[i] * 5.0
		_vel[i] += acc * delta
		_angle[i] = clampf(_angle[i] + _vel[i] * delta * 4.0, -0.9, 0.9)
		s.rotation = _angle[i]
