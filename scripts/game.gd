extends Node
## Global game state (autoload "Game"): abilities, collectibles, checkpoints,
## input map setup and time effects (hit-stop / slow motion).

signal ability_unlocked(id: String)
signal orbs_changed(count: int, total: int)
signal keys_changed(count: int)
signal show_banner(title: String, subtitle: String)
signal show_hint(text: String)
signal hide_hint
signal camera_shake(strength: float, duration: float)
signal screen_flash(color: Color, duration: float)
signal saved
## Something pushed the air (dash, bash, landing...): plants and vines react.
signal world_impulse(pos: Vector2, radius: float, strength: float)

const SAVE_PATH := "user://save.json"

const ABILITIES := {
	"double_jump": {"name": "Double Jump", "hint": "Press Jump again in mid-air."},
	"dash": {"name": "Spirit Dash", "hint": "Press Shift / X to dash.  Dash through cracked stone."},
	"bash": {"name": "Bash", "hint": "Near a lantern or enemy, hold C to aim, release to launch."},
	"glide": {"name": "Glide", "hint": "Press Jump in mid-air and keep holding it to glide."},
}

var abilities := {"double_jump": false, "dash": false, "bash": false, "glide": false}
var orbs := 0
var orbs_total := 0
var keys := 0
var checkpoint := Vector2.ZERO
var play_time := 0.0
var deaths := 0
var finished := false
## ids ("orb_12_30", "door_100_22", ...) of things collected / opened / found
var collected := {}
var has_save := false
## Map fog of war: one byte per level tile, 1 = seen.
var explored := PackedByteArray()
var map_size := Vector2i.ZERO
## set by test tools to skip the title screen
var skip_title := false
var player: Node2D

var _slowmo_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_game()


# --- Saving -------------------------------------------------------------------

func impulse(pos: Vector2, radius: float, strength: float) -> void:
	world_impulse.emit(pos, radius, strength)


func init_map(size: Vector2i) -> void:
	if map_size != size or explored.size() != size.x * size.y:
		map_size = size
		explored = PackedByteArray()
		explored.resize(size.x * size.y)


## Mark tiles around `cell` as seen (elliptical, wider than tall like the screen).
func reveal(cell: Vector2i, rx: int = 12, ry: int = 8) -> void:
	if map_size == Vector2i.ZERO:
		return
	for y in range(maxi(0, cell.y - ry), mini(map_size.y, cell.y + ry + 1)):
		var dy := float(y - cell.y) / ry
		var half := int(rx * sqrt(maxf(0.0, 1.0 - dy * dy)))
		for x in range(maxi(0, cell.x - half), mini(map_size.x, cell.x + half + 1)):
			explored[y * map_size.x + x] = 1


func is_explored(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < map_size.x and y < map_size.y and explored[y * map_size.x + x] == 1


func mark(id: String) -> void:
	collected[id] = true


func is_marked(id: String) -> bool:
	return collected.has(id)


func save_game() -> void:
	var data := {
		"abilities": abilities,
		"orbs": orbs,
		"keys": keys,
		"checkpoint": [checkpoint.x, checkpoint.y],
		"play_time": play_time,
		"deaths": deaths,
		"collected": collected.keys(),
		"map_w": map_size.x,
		"map_h": map_size.y,
		"explored": Marshalls.raw_to_base64(explored),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		has_save = true
		saved.emit()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	for k in abilities.keys():
		abilities[k] = bool(data.get("abilities", {}).get(k, false))
	orbs = int(data.get("orbs", 0))
	keys = int(data.get("keys", 0))
	var cp: Array = data.get("checkpoint", [0, 0])
	checkpoint = Vector2(cp[0], cp[1])
	play_time = float(data.get("play_time", 0.0))
	deaths = int(data.get("deaths", 0))
	collected.clear()
	for id in data.get("collected", []):
		collected[id] = true
	map_size = Vector2i(int(data.get("map_w", 0)), int(data.get("map_h", 0)))
	explored = Marshalls.base64_to_raw(str(data.get("explored", "")))
	has_save = true
	return true


func new_game() -> void:
	abilities = {"double_jump": false, "dash": false, "bash": false, "glide": false}
	orbs = 0
	keys = 0
	checkpoint = Vector2.ZERO
	play_time = 0.0
	deaths = 0
	finished = false
	collected.clear()
	explored = PackedByteArray()
	map_size = Vector2i.ZERO
	has_save = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _process(delta: float) -> void:
	if not get_tree().paused and not finished and is_instance_valid(player):
		play_time += delta / maxf(Engine.time_scale, 0.001)


func format_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func has(ability: String) -> bool:
	return abilities.get(ability, false)


func unlock(ability: String) -> void:
	abilities[ability] = true
	ability_unlocked.emit(ability)
	var info: Dictionary = ABILITIES[ability]
	show_banner.emit(info.name, info.hint)


func add_orb() -> void:
	orbs += 1
	orbs_changed.emit(orbs, orbs_total)


func set_orb_total(total: int) -> void:
	orbs_total = total
	orbs_changed.emit(orbs, orbs_total)


func add_key() -> void:
	keys += 1
	keys_changed.emit(keys)


func use_key() -> bool:
	if keys <= 0:
		return false
	keys -= 1
	keys_changed.emit(keys)
	return true


func shake(strength: float, duration: float = 0.25) -> void:
	camera_shake.emit(strength, duration)


## Gamepad vibration (does nothing without a controller).
func rumble(weak: float, strong: float, duration: float) -> void:
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, weak, strong, duration)


func flash(color: Color, duration: float = 0.3) -> void:
	screen_flash.emit(color, duration)


## Freeze the game for a moment (impact feel).
func hitstop(duration: float = 0.05, scale: float = 0.05) -> void:
	set_time_scale(scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	ease_time_scale(1.0, 0.08)


func set_time_scale(value: float) -> void:
	if _slowmo_tween:
		_slowmo_tween.kill()
	Engine.time_scale = value


func ease_time_scale(target: float, duration: float) -> void:
	if _slowmo_tween:
		_slowmo_tween.kill()
	_slowmo_tween = create_tween().set_ignore_time_scale(true)
	_slowmo_tween.tween_property(Engine, "time_scale", target, duration)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("restart"):
		restart(true)


## Reload the level. `fresh` wipes the save and starts a new game.
func restart(fresh: bool) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if fresh:
		new_game()
	else:
		load_game()
	get_tree().reload_current_scene()


# --- Input map --------------------------------------------------------------
# Defined in code so it is easy to read and change in one place.

func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("jump", [KEY_SPACE, KEY_Z, KEY_K], [JOY_BUTTON_A], [])
	_action("dash", [KEY_SHIFT, KEY_X, KEY_L], [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_action("bash", [KEY_C, KEY_J, KEY_E], [JOY_BUTTON_Y, JOY_BUTTON_B], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_action("restart", [KEY_R], [], [])
	_action("map", [KEY_M, KEY_TAB], [JOY_BUTTON_BACK], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_action("toggle_fullscreen", [KEY_F11], [], [])


func _action(action: String, keys_list: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.35)
	for k in keys_list:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
