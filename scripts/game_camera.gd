extends Camera2D
## Smooth follow camera with look-ahead in the direction of travel and
## a little extra look-down when falling fast. Also handles screen shake.

@export var look_ahead := 170.0
@export var look_ahead_speed := 2.2
@export var vertical_bias := -130.0
@export var follow_speed := 7.0

var _look := Vector2.ZERO
var _shake := 0.0
var _shake_time := 0.0
var _shake_duration := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	Game.camera_shake.connect(_on_shake)
	_noise.frequency = 2.5
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	await get_tree().process_frame
	snap()


func snap() -> void:
	var p := Game.player
	if p:
		global_position = p.global_position + Vector2(0, vertical_bias)
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var p := Game.player as Player
	if p == null:
		return
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_t += rd
	var vel := p.velocity
	var want := Vector2.ZERO
	if absf(vel.x) > 60.0:
		want.x = signf(vel.x) * look_ahead * clampf(absf(vel.x) / p.max_speed, 0.0, 1.3)
	else:
		want.x = p.facing * look_ahead * 0.35
	if vel.y > 700.0:
		want.y = clampf((vel.y - 700.0) * 0.35, 0.0, 160.0)
	_look = _look.lerp(want, 1.0 - exp(-look_ahead_speed * rd))

	var target := p.global_position + Vector2(0, vertical_bias) + _look
	# follow faster vertically when the player moves far away from centre
	var diff := target - global_position
	var k := Vector2(follow_speed, follow_speed * (0.8 if absf(diff.y) < 120.0 else 1.6))
	global_position.x += diff.x * (1.0 - exp(-k.x * rd))
	global_position.y += diff.y * (1.0 - exp(-k.y * rd))

	if _shake_time > 0.0:
		_shake_time -= rd
		var s := _shake * clampf(_shake_time / _shake_duration, 0.0, 1.0)
		offset = Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * s * 2.0
	else:
		offset = Vector2.ZERO


func _on_shake(strength: float, duration: float) -> void:
	if strength >= _shake * clampf(_shake_time / maxf(_shake_duration, 0.001), 0.0, 1.0):
		_shake = strength
		_shake_time = duration
		_shake_duration = duration
