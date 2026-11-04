extends Node2D
## Dark plant silhouettes in front of the action that scroll faster than the
## world, giving depth (as in Ori). Add with add_silhouette().

@export var parallax := 0.3

var _anchors := PackedVector2Array()


func _ready() -> void:
	z_index = 40


func add_silhouette(tex: Texture2D, anchor: Vector2, scale_: float, flip: bool) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	s.scale = Vector2(scale_, scale_)
	s.flip_h = flip
	s.light_mask = 0
	s.modulate = Color(0.02, 0.02, 0.06, 0.95)
	add_child(s)
	_anchors.append(anchor)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var children := get_children()
	for i in children.size():
		var a := _anchors[i]
		var s: Sprite2D = children[i]
		s.position = a + (a - c) * parallax
		s.visible = absf(s.position.x - c.x) < 1300.0
