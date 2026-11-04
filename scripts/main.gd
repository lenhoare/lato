extends Node2D
## Builds the world from a plain-text level file, sets up lighting, the
## parallax background, camera and HUD.
##
## Level legend (see levels/level1.txt):
##   #  ground                      =  one-way platform
##   ^  spikes                      P  player start
##   o  spirit orb                  k  key
##   D  locked door (stack 2)       B  breakable (dash) block
##   L  bash lantern                E  floating enemy (bashable)
##   C  checkpoint                  S  sign (texts after the --- line, in left-to-right order)
##   1  double jump shrine          2  dash shrine
##   3  bash shrine                 4  glide shrine
##   s  secret: looks solid but you can walk through it
##   W  updraft (rising wind)       G  goal

@export_file("*.txt") var level_path := "res://levels/level1.txt"
@export_enum("Green", "Blue", "Brown", "Yellow") var tile_color := "Green"
## Darkness of the world; lights (spirit, orbs, lanterns...) cut through it.
@export var ambient := Color(0.46, 0.45, 0.72)
## Tint for the ground tiles (darker foreground reads better against lights).
@export var ground_tint := Color(0.78, 0.84, 0.9)
@export var decoration_density := 0.22

const TILE := 64
const PlayerScene := preload("res://scenes/player.tscn")
const Pickup := preload("res://scripts/objects/pickup.gd")
const Door := preload("res://scripts/objects/door.gd")
const Breakable := preload("res://scripts/objects/breakable.gd")
const Lantern := preload("res://scripts/objects/lantern.gd")
const Floater := preload("res://scripts/objects/floater.gd")
const Hazard := preload("res://scripts/objects/hazard.gd")
const Checkpoint := preload("res://scripts/objects/checkpoint.gd")
const Shrine := preload("res://scripts/objects/shrine.gd")
const SignPost := preload("res://scripts/objects/sign.gd")
const SecretArea := preload("res://scripts/objects/secret_area.gd")
const Updraft := preload("res://scripts/objects/updraft.gd")
const Goal := preload("res://scripts/objects/goal.gd")
const Spirit := preload("res://scripts/spirit.gd")
const GameCamera := preload("res://scripts/game_camera.gd")
const Hud := preload("res://scripts/hud.gd")
const Background := preload("res://scripts/background.gd")
const Plants := preload("res://scripts/plants.gd")
const Foreground := preload("res://scripts/foreground.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Title := preload("res://scripts/title.gd")
const MapScreen := preload("res://scripts/map_screen.gd")
const Vine := preload("res://scripts/vine.gd")

const SHRINES := {"1": "double_jump", "2": "dash", "3": "bash", "4": "glide"}

var rows: PackedStringArray
var sign_texts: PackedStringArray
var width := 0
var height := 0

var tileset: TileSet
var tile_sources := {}  # tile number -> source id
var world: Node2D
var player: Player
var _secret_cells := {}  # Vector2i -> secret id


func _ready() -> void:
	_load_level()
	Game.init_map(Vector2i(width, height))
	_build_environment()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_tileset()
	_build_terrain()
	_build_objects()
	_build_decorations()
	_build_vines()
	_spawn_player_and_camera()
	add_child(Hud.new())
	add_child(PauseMenu.new())
	var map := MapScreen.new()
	map.level = self
	add_child(map)
	add_child(Title.new())


# ---------------------------------------------------------------------------

func _load_level() -> void:
	var text := FileAccess.get_file_as_string(level_path).replace("\r", "")
	var parts := text.split("\n---\n", true, 1)
	rows = parts[0].split("\n")
	sign_texts = PackedStringArray()
	if parts.size() > 1:
		for line in parts[1].split("\n"):
			if line.strip_edges() != "":
				sign_texts.append(line.strip_edges())
	height = rows.size()
	for r in rows:
		width = maxi(width, r.length())


func cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0:
		return "#" if y >= 0 else " "
	var r := rows[y]
	return r[x] if x < r.length() else (" " if x < width else "#")


## `cover` = true when tiling the secret-area covers, which should blend with
## the ground; the real ground treats secret areas as open space (caves).
func _ground(x: int, y: int, cover := false) -> bool:
	var c := cell(x, y)
	if cover:
		return c == "#" or c == "s" or _hidden_item(Vector2i(x, y))
	return c == "#"


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func _tile_texture(n: int) -> Texture2D:
	var path := "res://assets/PNG/Tiles/%s tiles/tile%s_%02d.png" % [tile_color, tile_color, n]
	var tex: Texture2D = load(path)
	if tex.get_height() >= TILE:
		return tex
	# thin platform pieces are 64x50: pad them to a full tile, aligned to the top
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return ImageTexture.create_from_image(out)


func _build_tileset() -> void:
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	var h := TILE / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var thin := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 20), Vector2(-h, -h + 20)])
	for n in [1, 2, 3, 4, 5, 6, 7, 8, 17, 26, 27]:
		var src := TileSetAtlasSource.new()
		src.texture = _tile_texture(n)
		src.texture_region_size = Vector2i(TILE, TILE)
		src.create_tile(Vector2i.ZERO)
		var id := tileset.add_source(src)
		tile_sources[n] = id
		var td := src.get_tile_data(Vector2i.ZERO, 0)
		td.add_collision_polygon(0)
		var one_way: bool = n in [1, 2, 26, 27]
		td.set_collision_polygon_points(0, 0, thin if one_way else full)
		td.set_collision_polygon_one_way(0, 0, one_way)


func _ground_tile(x: int, y: int, cover := false) -> int:
	var up := _ground(x, y - 1, cover)
	var left := _ground(x - 1, y, cover)
	var right := _ground(x + 1, y, cover)
	if not up:
		if not left and not right:
			return 7
		if not left:
			return 4
		if not right:
			return 6
		return 5
	# deep inside the ground: sprinkle the square motif tiles
	if _ground(x, y - 2, cover) and left and right and _ground(x, y + 1, cover):
		var hsh := (x * 73856093) ^ (y * 19349663)
		if hsh % 23 == 0:
			return 8
		if hsh % 29 == 0:
			return 17
	return 3


func _platform_tile(x: int, y: int) -> int:
	var l := cell(x - 1, y) == "="
	var r := cell(x + 1, y) == "="
	if l and r:
		return 27
	if r:
		return 26
	if l:
		return 1
	return 2


func _new_layer(layer_name: String, collide: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.collision_enabled = collide
	return layer


func _build_terrain() -> void:
	var ground := _new_layer("Ground", true)
	ground.modulate = ground_tint
	world.add_child(ground)
	for y in height:
		for x in width:
			var c := cell(x, y)
			if c == "#":
				ground.set_cell(Vector2i(x, y), tile_sources[_ground_tile(x, y)], Vector2i.ZERO)
			elif c == "=":
				ground.set_cell(Vector2i(x, y), tile_sources[_platform_tile(x, y)], Vector2i.ZERO)

	# Secret areas: each connected group of 's' gets its own fading cover layer.
	for group in _groups("s"):
		var cover := _new_layer("SecretCover", false)
		cover.z_index = 20
		cover.modulate = ground_tint
		world.add_child(cover)
		var rects: Array[Rect2] = []
		for p in group:
			cover.set_cell(p, tile_sources[_ground_tile(p.x, p.y, true)], Vector2i.ZERO)
			rects.append(Rect2(Vector2(p) * TILE, Vector2(TILE, TILE)))
		var area := SecretArea.new()
		var secret_id := "secret_%d_%d" % [group[0].x, group[0].y]
		area.set_meta("id", secret_id)
		for p in group:
			_secret_cells[p] = secret_id
		area.cover = cover
		area.rects = rects
		world.add_child(area)


## Flood-fill connected cells of one character. Returns Array of Array[Vector2i].
func _groups(ch: String) -> Array:
	var seen := {}
	var result := []
	for y in height:
		for x in width:
			var start := Vector2i(x, y)
			if cell(x, y) != ch or seen.has(start):
				continue
			var group: Array[Vector2i] = []
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				group.append(p)
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var q: Vector2i = p + d
					if not seen.has(q) and (cell(q.x, q.y) == ch or (ch == "s" and _hidden_item(q))):
						seen[q] = true
						stack.append(q)
			result.append(group)
	return result


## Items tucked inside a secret area (mostly surrounded by cover) are hidden too.
func _hidden_item(p: Vector2i) -> bool:
	if not cell(p.x, p.y) in ["o", "k"]:
		return false
	var n := 0
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if cell(p.x + d.x, p.y + d.y) in ["s", "o", "k", "#"]:
			n += 1
	return n >= 3


func secret_at(p: Vector2i) -> String:
	return _secret_cells.get(p, "")


func _marker(node: Node, kind: String) -> void:
	node.add_to_group("map_marker")
	node.set_meta("map_kind", kind)


func _bounds(group: Array) -> Rect2i:
	var r := Rect2i(group[0], Vector2i.ONE)
	for p in group:
		r = r.expand(p).expand(p + Vector2i.ONE)
	return r


# ---------------------------------------------------------------------------
# Objects
# ---------------------------------------------------------------------------

func _build_objects() -> void:
	var sign_cells: Array[Vector2i] = []
	var orb_count := 0
	for y in height:
		var x := 0
		while x < width:
			var c := cell(x, y)
			var top_left := Vector2(x * TILE, y * TILE)
			var center := top_left + Vector2(TILE, TILE) / 2.0
			match c:
				"o", "k":
					var id := "%s_%d_%d" % [c, x, y]
					if c == "o":
						orb_count += 1
					if not Game.is_marked(id):
						var pk := Pickup.new()
						pk.set_meta("id", id)
						pk.kind = "orb" if c == "o" else "key"
						pk.position = center
						_marker(pk, pk.kind)
						world.add_child(pk)
				"L":
					var l := Lantern.new()
					l.position = center
					world.add_child(l)
				"E":
					var e := Floater.new()
					e.position = center
					world.add_child(e)
				"C":
					var cp := Checkpoint.new()
					cp.position = top_left
					_marker(cp, "checkpoint")
					world.add_child(cp)
				"1", "2", "3", "4":
					var sh := Shrine.new()
					sh.ability = SHRINES[c]
					sh.position = top_left
					_marker(sh, "shrine")
					world.add_child(sh)
				"S":
					sign_cells.append(Vector2i(x, y))
				"G":
					var g := Goal.new()
					g.position = top_left
					_marker(g, "goal")
					world.add_child(g)
				"^":
					var run := 1
					while cell(x + run, y) == "^":
						run += 1
					var hz := Hazard.new()
					hz.length = run
					hz.position = top_left
					world.add_child(hz)
					x += run - 1
			x += 1

	# sign texts are assigned left to right
	sign_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for i in sign_cells.size():
		var sg := SignPost.new()
		sg.text = sign_texts[i] if i < sign_texts.size() else "..."
		sg.position = Vector2(sign_cells[i] * TILE)
		world.add_child(sg)

	Game.set_orb_total(orb_count)

	for group in _groups("D"):
		var r := _bounds(group)
		var door_id := "door_%d_%d" % [r.position.x, r.position.y]
		if Game.is_marked(door_id):
			continue
		var door := Door.new()
		door.set_meta("id", door_id)
		door.height = r.size.y
		door.position = Vector2(r.position * TILE)
		_marker(door, "door")
		world.add_child(door)

	for group in _groups("B"):
		var r := _bounds(group)
		var brk_id := "brk_%d_%d" % [r.position.x, r.position.y]
		if Game.is_marked(brk_id):
			continue
		var br := Breakable.new()
		br.set_meta("id", brk_id)
		for p in group:
			br.cells.append(p - r.position)
		br.position = Vector2(r.position * TILE)
		world.add_child(br)

	for group in _groups("W"):
		var r := _bounds(group)
		var up := Updraft.new()
		up.size = Vector2(r.size * TILE)
		up.position = Vector2(r.position * TILE)
		world.add_child(up)


func _build_decorations() -> void:
	var plants: Array[Texture2D] = []
	for n in [1, 2, 3, 4, 5, 6]:
		plants.append(load("res://assets/PNG/Other/plantGreen_%d.png" % n))
	for n in [1, 2, 3, 4, 5, 6]:
		plants.append(load("res://assets/PNG/Other/plantBlue_%d.png" % n))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var deco := Plants.new()
	deco.name = "Decorations"
	deco.z_index = -1
	world.add_child(deco)
	var fg := Foreground.new()
	fg.name = "Foreground"
	world.add_child(fg)
	var dark: Array[Texture2D] = []
	for n in [1, 2, 3, 5, 6]:
		dark.append(load("res://assets/PNG/Other/plantDark_%d.png" % n))
	var last_fg := -100
	for y in range(1, height):
		for x in width:
			if cell(x, y) != "#" or cell(x, y - 1) != " ":
				rng.randf()
				continue
			# occasional big dark silhouette in the foreground
			if absi(x - last_fg) > 6 and _ground(x, y + 2) and rng.randf() < 0.1:
				last_fg = x
				for k in rng.randi_range(1, 3):
					fg.add_silhouette(dark[rng.randi() % dark.size()],
							Vector2(x * TILE + k * rng.randf_range(50, 110), y * TILE + 40),
							rng.randf_range(4.5, 7.0), rng.randf() < 0.5)
			if rng.randf() > decoration_density:
				continue
			var tex := plants[rng.randi() % plants.size()]
			var base := Vector2(x * TILE + tex.get_width() / 2.0 + rng.randf_range(0, TILE - tex.get_width()), y * TILE + 4)
			deco.add_plant(tex, base, rng.randf() < 0.5)


func _build_vines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var last := Vector2i(-10, -10)
	for y in range(1, height - 1):
		for x in width:
			var c := cell(x, y)
			var under_ground := c == "#" and cell(x, y - 1) == "#"
			if not (under_ground or c == "=") or cell(x, y + 1) != " ":
				continue
			if y == last.y and x - last.x < 2:
				continue
			if rng.randf() > (0.45 if under_ground else 0.3):
				continue
			last = Vector2i(x, y)
			var v := Vine.new()
			v.segments = rng.randi_range(4, 9)
			v.segment_length = rng.randf_range(16.0, 22.0)
			v.position = Vector2(x * TILE + rng.randf_range(10, TILE - 10), (y + 1) * TILE - (14 if c == "=" else 2))
			world.add_child(v)


# ---------------------------------------------------------------------------
# Player, camera, lighting
# ---------------------------------------------------------------------------

func _spawn_player_and_camera() -> void:
	var start := Vector2(3 * TILE, 3 * TILE)
	for y in height:
		var x := rows[y].find("P")
		if x >= 0:
			start = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	if Game.has_save and Game.checkpoint != Vector2.ZERO:
		start = Game.checkpoint
	player = PlayerScene.instantiate()
	player.position = start
	world.add_child(player)

	var spirit := Spirit.new()
	world.add_child(spirit)

	var cam := GameCamera.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = width * TILE
	cam.limit_bottom = height * TILE
	world.add_child(cam)
	cam.make_current()

	# drifting motes of light around the camera
	var motes := CPUParticles2D.new()
	motes.texture = FX.dot_texture()
	motes.material = FX.additive_material()
	motes.amount = 70
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.local_coords = false
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(1100, 650)
	motes.direction = Vector2(0.3, -1)
	motes.spread = 40.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 26.0
	motes.scale_amount_min = 0.2
	motes.scale_amount_max = 0.7
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 1))
	curve.add_point(Vector2(1, 0))
	motes.scale_amount_curve = curve
	motes.color = Color(0.8, 1.2, 1.6, 0.6)
	motes.z_index = 25
	cam.add_child(motes)

	# leaves drifting down through the air
	var leaves := CPUParticles2D.new()
	leaves.texture = FX.leaf_texture()
	leaves.amount = 26
	leaves.lifetime = 9.0
	leaves.preprocess = 9.0
	leaves.local_coords = false
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(1200, 40)
	leaves.position = Vector2(200, -520)
	leaves.direction = Vector2(-0.4, 1)
	leaves.spread = 25.0
	leaves.gravity = Vector2(-10, 18)
	leaves.initial_velocity_min = 30.0
	leaves.initial_velocity_max = 70.0
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.angular_velocity_min = -120.0
	leaves.angular_velocity_max = 120.0
	leaves.orbit_velocity_min = 0.0
	leaves.scale_amount_min = 0.5
	leaves.scale_amount_max = 1.0
	leaves.color = Color(0.45, 0.85, 0.65, 0.85)
	leaves.hue_variation_min = -0.08
	leaves.hue_variation_max = 0.08
	leaves.z_index = 24
	cam.add_child(leaves)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cm := CanvasModulate.new()
	cm.color = ambient
	add_child(cm)

	add_child(Background.new())
