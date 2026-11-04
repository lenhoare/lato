extends Area2D
## Column of rising wind. Lifts the player while gliding.

var size := Vector2(192, 640)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)

	var p := CPUParticles2D.new()
	p.texture = FX.dot_texture()
	p.material = FX.additive_material()
	p.amount = int(size.y / 12.0)
	p.lifetime = size.y / 420.0
	p.preprocess = p.lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(size.x / 2.0 - 8.0, 4.0)
	p.position = Vector2(size.x / 2.0, size.y)
	p.direction = Vector2.UP
	p.spread = 3.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 380.0
	p.initial_velocity_max = 460.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.9
	p.scale_amount_curve = Curve.new()
	p.scale_amount_curve.add_point(Vector2(0, 0.2))
	p.scale_amount_curve.add_point(Vector2(0.2, 1))
	p.scale_amount_curve.add_point(Vector2(1, 0))
	p.color = Color(0.8, 1.0, 1.4, 0.35)
	add_child(p)

	# soft column of light
	var col := ColorRect.new()
	col.size = size
	col.color = Color(0.6, 0.85, 1.0, 0.06)
	col.material = FX.additive_material()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	body_entered.connect(func(b: Node) -> void:
		if b is Player:
			b.in_updraft += 1)
	body_exited.connect(func(b: Node) -> void:
		if b is Player:
			b.in_updraft = maxi(0, b.in_updraft - 1))
