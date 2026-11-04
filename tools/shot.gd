extends Node
## Dev helper: loads the main scene, optionally teleports the player and
## unlocks abilities, runs scripted input, and saves screenshots.
## Usage: godot res://tools/shot.tscn -- x=<px> y=<px> out=<file> frames=<n> all=1 script=<name>

var args := {}
var main: Node
var frame := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.get("all", "0") == "1":
		for k in Game.abilities.keys():
			Game.abilities[k] = true
	if args.has("no"):
		Game.abilities[args.no] = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)

func _physics_process(_d: float) -> void:
	frame += 1
	var p: Player = Game.player
	if frame == 2 and args.has("x"):
		p.global_position = Vector2(float(args.x), float(args.y))
		p.reset_physics_interpolation()
		var cam := get_viewport().get_camera_2d()
		cam.snap()
	var sc: String = args.get("script", "")
	if sc != "":
		call("_script_" + sc, frame, p)
	var shots: Array = args.get("shots", "").split(",", false)
	if str(frame) in shots:
		_save("%s_%d.png" % [args.get("out", "shot"), frame])
	if frame >= int(args.get("frames", "60")):
		_save(args.get("out", "shot") + ".png")
		get_tree().quit()

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.get("dir", "/tmp") + "/" + path)
	print("saved ", path, " player=", Game.player.global_position, " vel=", Game.player.velocity)

func _log(p: Player) -> void:
	print("f=%d pos=(%.0f,%.0f) vel=(%.0f,%.0f) floor=%s wall=%d state=%d" % [frame, p.global_position.x, p.global_position.y, p.velocity.x, p.velocity.y, p.is_on_floor(), p.wall_dir, p.state])

# hold right, jump at frame 30 (full hold)
func _script_jump(f: int, p: Player) -> void:
	if f == 10: Input.action_press("move_right")
	if f == 40: Input.action_press("jump")
	if f % 6 == 0: _log(p)

func _script_tap(f: int, p: Player) -> void:
	if f == 40: Input.action_press("jump")
	if f == 43: Input.action_release("jump")
	if f % 6 == 0: _log(p)

var _y0 := 0.0
var _x0 := 0.0
var _done := false
func _measure(f: int, p: Player, start: int) -> void:
	if f == start:
		_y0 = p.global_position.y
		_x0 = p.global_position.x
	if f > start + 5 and not _done and p.global_position.y >= _y0:
		_done = true
		print("RESULT dx=%.0f tiles=%.2f peak?" % [p.global_position.x - _x0, (p.global_position.x - _x0) / 64.0])
	if f > start and f % 8 == 0 and not _done: _log(p)

# in open air: run speed, jump, then double jump at apex
func _script_dj(f: int, p: Player) -> void:
	if f < 30: p.velocity = Vector2(400, 0); p.global_position.y = 900.0; p.coyote_timer = 0.1
	if f == 10: Input.action_press("move_right")
	if f == 30: Input.action_press("jump")
	if f == 80: Input.action_release("jump")
	if f == 81: Input.action_press("jump")
	var dash_at := int(args.get("dash", "0"))
	if dash_at > 0 and f == dash_at: Input.action_press("dash")
	_measure(f, p, 30)

# hold toward the right wall and keep wall-jumping
func _script_climb(f: int, p: Player) -> void:
	if f == 5: Input.action_press("move_right")
	if f > 20 and f % 40 == 0: Input.action_press("jump")
	if f > 20 and f % 40 == 30: Input.action_release("jump")
	if f % 20 == 0: _log(p)

var _bf := 0
func _process(_d: float) -> void:
	_bf += 1

# start near a lantern, bash up-right, release after a moment
func _script_bash(f: int, p: Player) -> void:
	if f == 4:
		Input.action_press("move_right"); Input.action_press("move_up"); Input.action_press("bash")
		_bf = 0
	if f >= 4 and _bf > int(args.get("hold", "30")) and Input.is_action_pressed("bash"):
		Input.action_release("bash"); Input.action_release("move_up")
		print("released at render frame ", _bf, " ts=", Engine.time_scale)
	if f % 8 == 0: _log(p)

func _script_dash(f: int, p: Player) -> void:
	if f == 10: Input.action_press("move_right")
	if f == 14: Input.action_press("dash")
	if f == 16: Input.action_release("dash")
	if f % 6 == 0 and f < 60: _log(p)

func _script_glide(f: int, p: Player) -> void:
	if f == 5: Input.action_press("move_right"); Input.action_press("jump")
	if f == 30: Input.action_release("jump")
	if f == 70: Input.action_press("jump")
	if f % 30 == 0: _log(p)

func _script_door(f: int, p: Player) -> void:
	if f == 3: Game.add_key()
	if f == 10: Input.action_press("move_right")
	if f % 20 == 0: _log(p)
