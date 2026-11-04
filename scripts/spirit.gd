extends Node2D
## A little glowing spirit that follows the player around (a companion light).
## It lags behind with spring motion and lights up the world around it.

@export var color := Color(0.6, 0.9, 1.7)
@export var light_radius := 420.0

var _vel := Vector2.ZERO
var _t := 0.0
var _core: Sprite2D
var _halo: Sprite2D
var _particles: CPUParticles2D


func _ready() -> void:
	add_to_group("spirit")
	z_index = 15
	var light := FX.make_light(light_radius, Color(0.75, 0.9, 1.0), 1.15)
	add_child(light)
	_halo = FX.make_glow_sprite(150.0, Color(color, 0.35))
	add_child(_halo)
	_core = FX.make_glow_sprite(34.0, Color(1.6, 1.9, 2.2))
	add_child(_core)

	_particles = CPUParticles2D.new()
	_particles.texture = FX.dot_texture()
	_particles.material = FX.additive_material()
	_particles.amount = 40
	_particles.lifetime = 0.9
	_particles.local_coords = false
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 5.0
	_particles.gravity = Vector2(0, -15)
	_particles.initial_velocity_min = 2.0
	_particles.initial_velocity_max = 14.0
	_particles.spread = 180.0
	_particles.scale_amount_min = 0.3
	_particles.scale_amount_max = 0.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_particles.scale_amount_curve = curve
	_particles.color = Color(color, 0.8)
	add_child(_particles)
	await get_tree().process_frame
	if Game.player:
		global_position = Game.player.global_position + Vector2(-40, -80)


func _process(delta: float) -> void:
	var p := Game.player as Player
	if p == null:
		return
	var rd := delta / maxf(Engine.time_scale, 0.001)
	_t += rd
	var bob := Vector2(sin(_t * 1.7) * 10.0, sin(_t * 2.9) * 8.0)
	var target := p.global_position + Vector2(-p.facing * 38.0, -82.0) + bob
	if p.state == Player.State.BASH_AIM and is_instance_valid(p.bash_target):
		target = p.bash_target.global_position + Vector2(0, -60) + bob
	# critically-damped-ish spring
	var stiffness := 38.0
	var damping := 9.0
	var acc := (target - global_position) * stiffness - _vel * damping
	_vel += acc * delta
	global_position += _vel * delta
	if global_position.distance_to(target) > 900.0:
		global_position = target
		_vel = Vector2.ZERO
	var pulse := 1.0 + sin(_t * 4.0) * 0.08
	_core.scale = Vector2.ONE * (34.0 / 128.0) * pulse
	_halo.scale = Vector2.ONE * (150.0 / 128.0) * (2.0 - pulse)
