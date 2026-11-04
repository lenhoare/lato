extends CanvasLayer
## Title overlay shown over the live world at startup.

var _box: VBoxContainer
var _prompt: Label
var _t := 0.0
var _closing := false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.skip_title:
		queue_free()
		return
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.06, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var title := _label("L A T O", 112, Color(0.85, 0.95, 1.0))
	_box.add_child(title)
	_box.add_child(_label("a small light in a dark forest", 26, Color(0.7, 0.8, 1.0)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	_box.add_child(spacer)
	var text := "Press Jump to begin"
	if Game.has_save:
		text = "Jump  continue          N  new game"
	_prompt = _label(text, 26, Color(1, 1, 1))
	_box.add_child(_prompt)
	var dimmed := [dim, _box]
	for d in dimmed:
		d.modulate.a = 0.0
		create_tween().tween_property(d, "modulate:a", 1.0, 1.2)
	await get_tree().process_frame
	if Game.player:
		Game.player.state = Player.State.FROZEN


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(6, size / 8)
	ls.outline_color = Color(0.05, 0.03, 0.15, 0.8)
	ls.shadow_color = Color(0.4, 0.7, 1.0, 0.25)
	ls.shadow_size = size / 4
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	_t += delta
	if _prompt:
		_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("jump"):
		_start()
		get_viewport().set_input_as_handled()
	elif Game.has_save and event is InputEventKey and event.pressed and event.physical_keycode == KEY_N:
		Game.restart(true)


func _start() -> void:
	_closing = true
	Sfx.play("respawn", 1.0, 0.0, 0.0)
	var t := create_tween().set_parallel(true)
	for c in get_children():
		t.tween_property(c, "modulate:a", 0.0, 0.6)
	t.chain().tween_callback(queue_free)
	if Game.player and Game.player.state == Player.State.FROZEN:
		Game.player.state = Player.State.NORMAL
