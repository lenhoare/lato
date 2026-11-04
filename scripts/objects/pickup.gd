extends Area2D
## Collectible: a spirit orb (gem) or a key. Bobs, glows and gets pulled toward
## the player when close, Ori style.

@export_enum("orb", "key") var kind := "orb"

const TEX := {
	"orb": "res://assets/PNG/Items/blueGem.png",
	"key": "res://assets/PNG/Items/keyGreen.png",
}
const COLORS := {
	"orb": Color(0.6, 0.9, 1.8),
	"key": Color(0.7, 1.7, 0.8),
}

var _home: Vector2
var _t := randf() * TAU
var _collected := false
var _sprite: Sprite2D
var _magnet := false
var _vel := Vector2.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	add_child(FX.make_glow_sprite(90.0, Color(COLORS[kind], 0.5)))
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX[kind])
	add_child(_sprite)
	var light := FX.make_light(120.0, COLORS[kind], 0.6)
	add_child(light)
	_home = global_position
	body_entered.connect(_on_body_entered)
	if kind == "orb":
		Game.register_orb()


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	var p := Game.player
	if p and not _magnet and global_position.distance_to(p.global_position + Vector2(0, -21)) < 110.0:
		_magnet = true
	if _magnet and p:
		var to := (p.global_position + Vector2(0, -21)) - global_position
		_vel = _vel.lerp(to.normalized() * 900.0, 1.0 - exp(-10.0 * delta))
		global_position += _vel * delta
	else:
		global_position = _home + Vector2(0, sin(_t * 2.4) * 5.0)
		_sprite.rotation = sin(_t * 1.3) * 0.15


func _on_body_entered(body: Node) -> void:
	if _collected or not body is Player:
		return
	_collected = true
	if kind == "orb":
		Game.add_orb()
		Sfx.play_orb()
	else:
		Sfx.play("key")
		Game.add_key()
		Game.show_banner.emit("Key", "It opens a locked door.")
	FX.burst(get_parent(), global_position, COLORS[kind], 14, 220.0, 0.45, 0.8)
	FX.ring(get_parent(), global_position, Color(COLORS[kind], 0.8), 40.0, 0.25, 3.0)
	queue_free()
