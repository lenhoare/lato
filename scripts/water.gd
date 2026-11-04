extends Node2D
## Water body drawn over the player (so you look submerged), with a gently
## bobbing surface, rising bubbles and a soft glow. Physics lives in the player
## (it asks Game.level.is_water_at()).

const TILE := 64.0
var cells: Array[Vector2i] = []
var surface: Dictionary = {}  # Vector2i -> true for top cells

var _tops: Array[Sprite2D] = []
var _t := 0.0


func _ready() -> void:
	z_index = 15
	var fill: Texture2D = load("res://assets/PNG/Other/fluidBlue.png")
	var top: Texture2D = load("res://assets/PNG/Other/fluidBlue_top.png")
	var bounds := Rect2(Vector2(cells[0]) * TILE, Vector2.ZERO)
	for c in cells:
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(c) * TILE
		s.texture = top if surface.has(c) else fill
		s.modulate = Color(0.55, 0.8, 1.15, 0.5)
		add_child(s)
		if surface.has(c):
			_tops.append(s)
		bounds = bounds.expand(Vector2(c) * TILE).expand(Vector2(c + Vector2i.ONE) * TILE)
	var bubbles := CPUParticles2D.new()
	bubbles.texture = FX.dot_texture()
	bubbles.material = FX.additive_material()
	bubbles.amount = int(clampf(bounds.size.x * bounds.size.y / 9000.0, 8, 90))
	bubbles.lifetime = 3.5
	bubbles.preprocess = 3.5
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bubbles.emission_rect_extents = Vector2(bounds.size.x / 2.0, 10)
	bubbles.position = Vector2(bounds.get_center().x, bounds.end.y - 20)
	bubbles.direction = Vector2.UP
	bubbles.spread = 8.0
	bubbles.gravity = Vector2(0, -30)
	bubbles.initial_velocity_min = 30.0
	bubbles.initial_velocity_max = 80.0
	bubbles.scale_amount_min = 0.3
	bubbles.scale_amount_max = 0.8
	bubbles.color = Color(0.7, 0.95, 1.3, 0.45)
	add_child(bubbles)
	# faint glow through the water
	var light := FX.make_light(maxf(bounds.size.x, bounds.size.y) * 0.6, Color(0.3, 0.6, 1.0), 0.35)
	light.position = bounds.get_center()
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	for s in _tops:
		s.offset.y = sin(_t * 2.2 + s.position.x * 0.03) * 2.5
