extends CanvasLayer
## Ori-style map (M / Tab / Select). Areas are revealed as you explore them.
## Shows the terrain you've seen, checkpoints, shrines, doors, orbs still to find,
## the goal and where you are. Press Dash to zoom, and move to pan while zoomed.

const BG := Color(0.04, 0.03, 0.1, 0.985)
const C_AIR := Color(0.16, 0.13, 0.32, 0.9)
const C_GROUND := Color(0.24, 0.42, 0.36)
const C_EDGE := Color(0.55, 0.9, 0.7)
const C_PLATFORM := Color(0.55, 0.9, 0.7)
const C_SPIKE := Color(0.95, 0.35, 0.45)
const C_WIND := Color(0.35, 0.55, 0.95, 0.9)
const C_CRACK := Color(0.7, 0.5, 0.35)
const C_DOOR := Color(0.4, 1.0, 0.75)
const C_WATER := Color(0.2, 0.45, 0.85, 0.95)

var level: Node  # main.gd (provides cell(), width, height, secret_at())
var _open := false
var _root: Control
var _map_rect: TextureRect
var _overlay: MapOverlay
var _title: Label
var _info: Label
var _zoomed := false
var _fit_scale := 4.0
var _scale := 4.0
var _center := Vector2.ZERO  # map coords at screen centre
var _reveal_timer := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.clip_contents = true
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	_root.add_child(bg)
	_map_rect = TextureRect.new()
	_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_map_rect)
	_overlay = MapOverlay.new()
	_overlay.screen = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)
	_title = _label(40)
	_title.text = "Map"
	_title.position = Vector2(40, 24)
	_root.add_child(_title)
	_info = _label(20)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_top = -56
	_info.offset_bottom = -20
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_info)


func _label(size: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = maxi(4, size / 6)
	ls.outline_color = Color(0.02, 0.01, 0.08)
	l.label_settings = ls
	return l


# --- exploring -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(Game.player):
		return
	_reveal_timer -= delta
	if _reveal_timer <= 0.0:
		_reveal_timer = 0.15
		var p := Game.player.global_position
		Game.reveal(Vector2i(int(p.x / 64.0), int((p.y - 21.0) / 64.0)))


# --- open / close ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _open:
		if event.is_action_pressed("map") or event.is_action_pressed("pause") or event.is_action_pressed("bash"):
			_close()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("dash") or event.is_action_pressed("jump"):
			_zoomed = not _zoomed
			_layout()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and not get_tree().paused and is_instance_valid(Game.player) \
			and Game.player.state != Player.State.FROZEN:
		_open_map()
		get_viewport().set_input_as_handled()


func _open_map() -> void:
	_open = true
	get_tree().paused = true
	_build_texture()
	_zoomed = false
	_center = _player_cell()
	_layout()
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)
	Sfx.play("bash_grab", 1.6, -8.0, 0.0)
	var seen := 0
	for b in Game.explored:
		seen += b
	var pct := 100.0 * seen / maxf(1.0, Game.explored.size())
	_info.text = "Explored %d%%      Spirit orbs %d / %d      Skills %d / %d\n" % [
			pct, Game.orbs, Game.orbs_total, Game.abilities.values().count(true), Game.abilities.size()] + \
			"M / Esc  close      Jump / Dash  zoom      move  pan"


func _close() -> void:
	_open = false
	_root.visible = false
	get_tree().paused = false


func _player_cell() -> Vector2:
	if is_instance_valid(Game.player):
		return Game.player.global_position / 64.0 - Vector2(0, 0.4)
	return Vector2(level.width, level.height) / 2.0


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var avail := view - Vector2(80, 200)
	_fit_scale = minf(avail.x / level.width, avail.y / level.height)
	_scale = _fit_scale * (3.0 if _zoomed else 1.0)
	if not _zoomed:
		_center = Vector2(level.width, level.height) / 2.0
	_apply()


func _apply() -> void:
	var view := get_viewport().get_visible_rect().size
	var screen_center := view / 2.0 + Vector2(0, 10)
	_map_rect.size = Vector2(level.width, level.height) * _scale
	_map_rect.position = screen_center - _center * _scale
	_overlay.queue_redraw()


func map_to_screen(p: Vector2) -> Vector2:
	return _map_rect.position + p * _scale


func _process(delta: float) -> void:
	if not _open:
		return
	_t += delta
	if _zoomed:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v != Vector2.ZERO:
			_center += v * delta * 40.0
			_center = _center.clamp(Vector2.ZERO, Vector2(level.width, level.height))
			_apply()
	_overlay.queue_redraw()


# --- drawing ---------------------------------------------------------------------

func _build_texture() -> void:
	var w: int = level.width
	var h: int = level.height
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if not Game.is_explored(x, y):
				continue
			img.set_pixel(x, y, _cell_color(x, y))
	_map_rect.texture = ImageTexture.create_from_image(img)


func _solid_for_map(x: int, y: int) -> bool:
	var c: String = level.cell(x, y)
	if c == "#":
		return true
	if c == "s":
		var id: String = level.secret_at(Vector2i(x, y))
		return not Game.is_marked(id)
	if c == "B":
		return true
	return false


func _cell_color(x: int, y: int) -> Color:
	var c: String = level.cell(x, y)
	if _solid_for_map(x, y):
		if c == "B":
			return C_CRACK
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not _solid_for_map(x + d.x, y + d.y) and level.cell(x + d.x, y + d.y) != "#":
				return C_EDGE
		return C_GROUND
	if level.water.has(Vector2i(x, y)):
		return C_WATER
	match c:
		"=":
			return C_PLATFORM
		"^":
			return C_SPIKE
		"W":
			return C_WIND
	return C_AIR


class MapOverlay extends Control:
	var screen: Node

	func _draw() -> void:
		var s = screen
		var sc: float = s._scale
		var r := maxf(2.5, sc * 0.45)
		for n in get_tree().get_nodes_in_group("map_marker"):
			var node := n as Node2D
			if node == null or not is_instance_valid(node):
				continue
			var cell: Vector2 = node.global_position / 64.0
			if not Game.is_explored(int(cell.x), int(cell.y)):
				continue
			var p: Vector2 = s.map_to_screen(cell)
			var kind: String = node.get_meta("map_kind", "")
			match kind:
				"orb":
					draw_circle(p, r * 0.55, Color(0.55, 0.85, 1.0))
				"key":
					draw_circle(p, r, Color(0.5, 1.0, 0.6))
					draw_arc(p, r * 1.6, 0, TAU, 16, Color(0.5, 1.0, 0.6, 0.6), 2.0)
				"checkpoint":
					var q := p + Vector2(0.5, 1.0) * sc
					draw_line(q, q - Vector2(0, r * 3.0), Color(0.8, 1.0, 0.85), 2.0)
					draw_colored_polygon(PackedVector2Array([q - Vector2(0, r * 3.0),
							q - Vector2(-r * 2.0, r * 2.4), q - Vector2(0, r * 1.8)]), Color(0.45, 1.0, 0.6))
				"shrine":
					if not node.get("_taken"):
						var col: Color = node.CRYSTALS[node.ability][1]
						var q := p + Vector2(0.5, 0.0) * sc
						var k := r * (1.6 + 0.3 * sin(s._t * 4.0))
						draw_colored_polygon(PackedVector2Array([q + Vector2(0, -k), q + Vector2(k * 0.7, 0),
								q + Vector2(0, k), q + Vector2(-k * 0.7, 0)]), Color(col.r / 2.0, col.g / 2.0, col.b / 2.0))
				"door":
					var h: int = node.height
					draw_rect(Rect2(p, Vector2(1, h) * sc), Color(0.4, 1.0, 0.75))
				"goal":
					var q := p + Vector2(0.5, -0.3) * sc
					draw_circle(q, r * (2.0 + 0.4 * sin(s._t * 3.0)), Color(1, 1, 1, 0.35))
					draw_circle(q, r * 1.1, Color(1, 1, 1))
		# player
		if is_instance_valid(Game.player):
			var pp: Vector2 = s.map_to_screen(s._player_cell())
			var pulse := 0.5 + 0.5 * sin(s._t * 5.0)
			draw_circle(pp, r * (2.6 + pulse * 1.4), Color(0.6, 0.9, 1.0, 0.25 * (1.0 - pulse) + 0.1))
			draw_circle(pp, r * 1.3, Color(1, 1, 1))
			draw_arc(pp, r * 1.9, 0, TAU, 20, Color(0.6, 0.9, 1.0), 2.0)
