extends Area2D
## Light Burst: a glowing orb thrown by the spirit. Homes in on enemies, and
## explodes on impact or after a short flight, damaging enemies, breaking
## cracked stone and pushing plants. It's bashable while in flight.

const COLOR := Color(1.7, 1.5, 0.9)

var velocity := Vector2.ZERO
var target: Node2D
var radius := 120.0
var life := 0.85
var _exploded := false
var _held := false
var _core: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	add_to_group("bashable")
	collision_layer = 0
	collision_mask = 1 | 4  # world + enemies
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 12.0
	shape.shape = c
	add_child(shape)
	add_child(FX.make_glow_sprite(90.0, Color(COLOR, 0.6)))
	_core = FX.make_glow_sprite(30.0, Color(2.2, 2.0, 1.4))
	add_child(_core)
	_light = FX.make_light(260.0, Color(1.0, 0.9, 0.6), 1.2)
	add_child(_light)
	var trail := CPUParticles2D.new()
	trail.texture = FX.dot_texture()
	trail.material = FX.additive_material()
	trail.amount = 30
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_max = 20.0
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 0.9
	trail.color = Color(COLOR, 0.8)
	add_child(trail)
	body_entered.connect(func(_b: Node) -> void: explode())
	area_entered.connect(func(a: Area2D) -> void:
		if a.is_in_group("enemy"):
			explode())


func _physics_process(delta: float) -> void:
	if _exploded or _held:
		return
	life -= delta
	if is_instance_valid(target) and target.is_in_group("enemy"):
		var want := (target.global_position - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, 1.0 - exp(-9.0 * delta))
	global_position += velocity * delta
	_core.scale = Vector2.ONE * (30.0 / 128.0) * (1.0 + sin(life * 40.0) * 0.15)
	if life <= 0.0:
		explode()


func on_bash_grab() -> void:
	_held = true


func on_bashed(push_dir: Vector2) -> void:
	# bashing your own light burst flings it the other way
	_held = false
	target = null
	velocity = push_dir * 1000.0
	life = 0.35


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	remove_from_group("bashable")
	set_deferred("monitoring", false)
	var pos := global_position
	Sfx.play("burst", 1.0, -1.0)
	Game.shake(5.0, 0.18)
	Game.rumble(0.3, 0.3, 0.12)
	Game.impulse(pos, radius * 2.2, 3.0)
	FX.ring(get_parent(), pos, COLOR, radius, 0.35, 7.0)
	FX.burst(get_parent(), pos, COLOR, 28, 380.0, 0.5, 1.2)
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en and en.global_position.distance_to(pos) < radius + 20.0 and en.has_method("hit"):
			en.hit((en.global_position - pos).normalized())
	for b in get_tree().get_nodes_in_group("breakable"):
		var br := b as Node2D
		if br and br.has_method("shatter") and br.has_method("touches"):
			if br.touches(pos, radius * 0.6):
				br.shatter(1 if br.global_position.x >= pos.x else -1)
	# brief flash of light, then gone
	for child in get_children():
		if child is Sprite2D or child is CPUParticles2D:
			child.visible = false
	_light.texture_scale *= 2.0
	var t := create_tween()
	t.tween_property(_light, "energy", 0.0, 0.45)
	t.tween_callback(queue_free)
