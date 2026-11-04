extends Area2D
## Hidden area: a foreground layer that looks like solid ground but fades away
## when the player walks into it.

var cover: CanvasItem  # the foreground tiles that hide the secret
var rects: Array[Rect2] = []
var _found := false
var _inside := 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	for r in rects:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		add_child(shape)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if not body is Player:
		return
	_inside += 1
	create_tween().tween_property(cover, "modulate:a", 0.12, 0.35)
	if not _found:
		_found = true
		Game.show_banner.emit("Secret found", "")
		FX.burst(get_parent(), body.global_position + Vector2(0, -21), Color(1.6, 1.5, 0.9), 20, 220.0, 0.6)


func _on_exit(body: Node) -> void:
	if not body is Player:
		return
	_inside -= 1
	if _inside <= 0:
		create_tween().tween_property(cover, "modulate:a", 1.0, 0.5)
