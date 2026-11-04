class_name FX
extends RefCounted
## Small library of procedural visual effects (glows, bursts, afterimages).
## Everything is generated in code so there are no extra assets to manage.

static var _glow_cache: Dictionary = {}


## Soft round glow texture (white, fades to transparent). Tint with modulate.
static func glow_texture(size: int = 128, falloff: float = 1.0) -> Texture2D:
	var key := "%d_%f" % [size, falloff]
	if _glow_cache.has(key):
		return _glow_cache[key]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.25 * falloff, Color(1, 1, 1, 0.55))
	grad.add_point(0.6, Color(1, 1, 1, 0.12))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	_glow_cache[key] = tex
	return tex


## Small hard-ish dot used for particles.
static func dot_texture() -> Texture2D:
	if _glow_cache.has("dot"):
		return _glow_cache["dot"]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(1, 1, 1, 0.9))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
	_glow_cache["dot"] = tex
	return tex


static func make_light(radius: float, color: Color, energy: float = 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = glow_texture(256)
	light.texture_scale = radius / 128.0
	light.color = color
	light.energy = energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	return light


static func make_glow_sprite(size: float, color: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_texture(128)
	s.scale = Vector2.ONE * (size / 128.0)
	s.modulate = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	return s


static func additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return mat


## One-shot radial burst of glowing particles.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 24,
		speed: float = 260.0, lifetime: float = 0.6, size: float = 1.0,
		direction: Vector2 = Vector2.ZERO, spread: float = 180.0, gravity: float = 0.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.material = additive_material()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = direction if direction != Vector2.ZERO else Vector2.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.6
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.3 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	p.z_index = 20
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Dust puff (non-glowing) for landings and footsteps.
static func dust(parent: Node, pos: Vector2, amount: int = 8, dir: Vector2 = Vector2.UP,
		speed: float = 140.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.45
	p.direction = dir
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed
	p.damping_max = speed * 2.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = Color(0.85, 0.9, 1.0, 0.55)
	p.z_index = 5
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Fading copy of a sprite (used for dash / bash trails).
static func afterimage(parent: Node, sprite: Sprite2D, color: Color, life: float = 0.25) -> void:
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.centered = sprite.centered
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.global_transform = sprite.global_transform
	g.modulate = color
	g.material = additive_material()
	g.z_index = sprite.z_index - 1
	parent.add_child(g)
	g.global_transform = sprite.global_transform
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, life)
	t.tween_callback(g.queue_free)


## Expanding ring (shockwave) drawn with a Line2D circle.
static func ring(parent: Node, pos: Vector2, color: Color, radius: float = 80.0,
		life: float = 0.35, width: float = 6.0) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.material = additive_material()
	line.z_index = 20
	parent.add_child(line)
	line.global_position = pos
	var set_radius := func(r: float) -> void:
		var pts := PackedVector2Array()
		for i in 41:
			var a := TAU * i / 40.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		line.points = pts
	set_radius.call(4.0)
	var t := line.create_tween().set_parallel(true)
	t.tween_method(set_radius, 4.0, radius, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(line, "width", 0.5, life)
	t.tween_property(line, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(line.queue_free)
