extends Area2D
## Ability shrine: a glowing crystal on a pedestal. Touching it grants an ability
## with a little ceremony (slow-mo, light burst, banner).

@export_enum("double_jump", "dash", "bash", "glide") var ability := "double_jump"

const TILE := 64.0
const CRYSTALS := {
	"double_jump": ["res://assets/PNG/Items/blueCrystal.png", Color(0.6, 0.9, 1.8)],
	"dash": ["res://assets/PNG/Items/greenCrystal.png", Color(0.6, 1.8, 0.9)],
	"bash": ["res://assets/PNG/Items/yellowCrystal.png", Color(1.8, 1.4, 0.6)],
	"glide": ["res://assets/PNG/Items/redCrystal.png", Color(1.8, 0.7, 0.9)],
}

var _taken := false
var _crystal: Node2D
var _t := 0.0
var _light: PointLight2D
var _motes: CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var info: Array = CRYSTALS[ability]
	var color: Color = info[1]
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 110)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, 10)
	add_child(shape)
	# pedestal
	var ped := Sprite2D.new()
	ped.texture = load("res://assets/PNG/Other/buttonGreen.png")
	ped.position = Vector2(TILE / 2.0, TILE - 14.0)
	ped.modulate = Color(0.85, 0.85, 1.0)
	add_child(ped)
	# crystal + glow
	_crystal = Node2D.new()
	_crystal.position = Vector2(TILE / 2.0, -10.0)
	add_child(_crystal)
	_crystal.add_child(FX.make_glow_sprite(170.0, Color(color, 0.55)))
	var s := Sprite2D.new()
	s.texture = load(info[0])
	s.scale = Vector2(1.4, 1.4)
	_crystal.add_child(s)
	_light = FX.make_light(320.0, Color(color.r / 2.0, color.g / 2.0, color.b / 2.0), 1.2)
	_light.position = _crystal.position
	add_child(_light)
	# rising motes
	_motes = CPUParticles2D.new()
	_motes.texture = FX.dot_texture()
	_motes.material = FX.additive_material()
	_motes.amount = 24
	_motes.lifetime = 2.0
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(30, 6)
	_motes.position = Vector2(TILE / 2.0, TILE - 20.0)
	_motes.direction = Vector2.UP
	_motes.spread = 10.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 20.0
	_motes.initial_velocity_max = 60.0
	_motes.scale_amount_min = 0.3
	_motes.scale_amount_max = 0.8
	_motes.color = Color(color, 0.7)
	add_child(_motes)
	body_entered.connect(_on_body_entered)
	if Game.has(ability):
		_taken = true
		_crystal.visible = false
		_motes.emitting = false
		_light.energy = 0.25


func _process(delta: float) -> void:
	_t += delta
	if not _taken:
		_crystal.position.y = -10.0 + sin(_t * 2.0) * 7.0
		_crystal.rotation = sin(_t * 1.1) * 0.12


func _on_body_entered(body: Node) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	var color: Color = CRYSTALS[ability][1]
	var p := body as Player
	p.freeze(0.9)
	Game.set_time_scale(0.25)
	Game.ease_time_scale(1.0, 1.2)
	Game.flash(Color(color, 0.5), 0.6)
	Game.shake(6.0, 0.6)
	Game.rumble(0.3, 0.3, 0.6)
	Sfx.play("shrine", 1.0, 0.0, 0.0)
	var pos := _crystal.global_position
	FX.ring(get_parent(), pos, color, 260.0, 0.8, 10.0)
	FX.ring(get_parent(), pos, Color(1.6, 1.8, 2.0), 160.0, 0.6, 4.0)
	FX.burst(get_parent(), pos, color, 60, 500.0, 1.0, 1.5)
	var t := create_tween().set_parallel(true)
	t.tween_property(_crystal, "global_position", p.global_position + Vector2(0, -21), 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_crystal, "scale", Vector2(0.2, 0.2), 0.35)
	t.tween_property(_light, "energy", 0.25, 1.0)
	t.chain().tween_callback(func() -> void:
		_crystal.visible = false
		FX.burst(get_parent(), p.global_position + Vector2(0, -21), color, 30, 300.0, 0.6)
		Game.unlock(ability)
		Game.save_game())
	_motes.emitting = false
