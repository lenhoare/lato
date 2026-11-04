extends CanvasLayer
## Pause screen (Esc / Start): shows progress, skills and controls.

var _root: Control
var _stats: Label
var _skills: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.08, 0.72)
	_root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_root.add_child(box)
	box.add_child(_label("Paused", 56))
	_stats = _label("", 26)
	box.add_child(_stats)
	_skills = _label("", 22)
	box.add_child(_skills)
	var controls := _label("Move  A/D   ·   Jump  Space   ·   Dash  Shift   ·   Bash  C (hold, aim, release)", 18)
	controls.modulate = Color(0.75, 0.8, 0.95)
	box.add_child(controls)
	var keys := _label("Esc  resume      R  restart      Q  quit", 20)
	keys.modulate = Color(0.7, 0.9, 1.0)
	box.add_child(keys)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = maxi(4, size / 6)
	ls.outline_color = Color(0.03, 0.02, 0.1)
	l.label_settings = ls
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif get_tree().paused and event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
		get_tree().quit()


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	_root.visible = p
	if p:
		_stats.text = "Spirit orbs  %d / %d        Time  %s        Falls  %d" % [
				Game.orbs, Game.orbs_total, Game.format_time(Game.play_time), Game.deaths]
		var owned := []
		for id in Game.ABILITIES.keys():
			owned.append(Game.ABILITIES[id].name if Game.has(id) else "???")
		_skills.text = "Skills:   " + "   ·   ".join(owned)
