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
var player: Node2D

var _slowmo_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


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


func register_orb() -> void:
	orbs_total += 1
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
		Engine.time_scale = 1.0
		abilities = {"double_jump": false, "dash": false, "bash": false, "glide": false}
		orbs = 0
		orbs_total = 0
		keys = 0
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
	_action("restart", [KEY_R], [JOY_BUTTON_BACK], [])
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
