extends CanvasLayer
## Parallax backdrop built from the Kenney background layers, tinted for a
## night-time mood. Each layer scrolls at a fraction of the camera speed.

@export var set_index := 2

var _layers: Array[Dictionary] = []


func _ready() -> void:
	layer = -10
	follow_viewport_enabled = false

	var sky := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.04, 0.13))
	grad.set_color(1, Color(0.24, 0.16, 0.36))
	grad.add_point(0.6, Color(0.14, 0.09, 0.27))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	# big soft moon glow
	var moon := FX.make_glow_sprite(900.0, Color(0.55, 0.5, 0.9, 0.35))
	moon.material = null
	moon.name = "Moon"
	add_child(moon)
	_layers.append({"node": moon, "fx": 0.02, "fy": 0.02, "base": Vector2(900, 170), "tile": 0.0})

	var path := "res://assets/PNG/Backgrounds/set%d_%s.png"
	_add_layer(load(path % [set_index, "tiles"]), Color(0.32, 0.25, 0.55, 0.55), 2.0, 0.08, 0.05, -60.0, 0.0, false)
	_add_layer(load(path % [set_index, "hills"]), Color(0.2, 0.15, 0.38), 2.2, 0.2, 0.12, 120.0)
	_add_layer(load(path % [set_index, "hills"]), Color(0.13, 0.1, 0.27), 1.6, 0.38, 0.22, 330.0, 400.0)


func _add_layer(tex: Texture2D, tint: Color, scale_: float, fx: float, fy: float, y: float,
		x_shift: float = 0.0, fill_below: bool = true) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.modulate = tint
	tr.scale = Vector2(scale_, scale_)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	# solid fill below the image so the layer never shows a gap at the bottom
	var fill := ColorRect.new()
	fill.color = tint * _bottom_color(tex)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.visible = fill_below
	holder.add_child(fill)
	_layers.append({"node": holder, "rect": tr, "fill": fill, "fx": fx, "fy": fy,
			"base": Vector2(x_shift, y), "tile": tex.get_width() * scale_, "h": tex.get_height() * scale_})


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport().get_visible_rect().size
	var c := cam.get_screen_center_position()
	var ref := Vector2(0, 2200)  # camera height at which layers sit at their base
	for l in _layers:
		var node: CanvasItem = l.node
		var base: Vector2 = l.base
		var tile: float = l.tile
		var fx: float = l.fx
		var fy: float = l.fy
		var y := base.y - (c.y - ref.y) * fy
		if tile <= 0.0:
			(node as Node2D).position = Vector2(base.x - c.x * fx, y)
			continue
		var x := -fposmod(c.x * fx + base.x, tile) - tile
		var holder := node as Control
		holder.position = Vector2(x, y)
		var tr: TextureRect = l.rect
		tr.size = Vector2((view.x + tile * 2.0) / tr.scale.x + tex_w(tr), tr.texture.get_height())
		var fill: ColorRect = l.fill
		var lh: float = l.h
		fill.position = Vector2(0, lh - 2.0)
		fill.size = Vector2(view.x + tile * 3.0, view.y + 3000.0)


func _bottom_color(tex: Texture2D) -> Color:
	var img := tex.get_image()
	if img == null:
		return Color.WHITE
	if img.is_compressed():
		img.decompress()
	var y := img.get_height() - 1
	for x in img.get_width():
		var c := img.get_pixel(x, y)
		if c.a > 0.9:
			return c
	return Color.WHITE


func tex_w(tr: TextureRect) -> float:
	return tr.texture.get_width()
