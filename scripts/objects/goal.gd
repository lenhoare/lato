extends Area2D
## End of the level: a big spirit light.

const TILE := 64.0
var _done := false
var _t := 0.0
var _core: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 160)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, -10)
	add_child(shape)
	add_child(FX.make_light(520.0, Color(0.8, 1.0, 1.0), 1.4))
	var halo := FX.make_glow_sprite(320.0, Color(0.7, 1.0, 1.6, 0.5))
	halo.position = Vector2(TILE / 2.0, -20)
	add_child(halo)
	_core = FX.make_glow_sprite(90.0, Color(2.0, 2.0, 2.2))
	_core.position = halo.position
	add_child(_core)
	body_entered.connect(_on_enter)


func _process(delta: float) -> void:
	_t += delta
	_core.scale = Vector2.ONE * (90.0 / 128.0) * (1.0 + sin(_t * 3.0) * 0.12)


func _on_enter(body: Node) -> void:
	if _done or not body is Player:
		return
	_done = true
	Game.flash(Color(1, 1, 1, 0.8), 1.2)
	Game.set_time_scale(0.3)
	Game.ease_time_scale(1.0, 1.5)
	FX.ring(get_parent(), _core.global_position, Color(1.5, 1.8, 2.0), 420.0, 1.2, 12.0)
	FX.burst(get_parent(), _core.global_position, Color(0.8, 1.2, 2.0), 80, 600.0, 1.4, 1.8)
	Game.show_banner.emit("The light is restored",
			"Spirit orbs: %d / %d      (R to play again)" % [Game.orbs, Game.orbs_total])
