extends CanvasLayer
## On-screen UI: orb / key counters, ability banners, sign hints, screen flash.

var _orb_label: Label
var _key_box: HBoxContainer
var _key_label: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _hint: PanelContainer
var _hint_label: Label
var _flash: ColorRect
var _banner_tween: Tween
var _hint_tween: Tween
var _toast: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.1, 0.35, 0.75, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)
	Game.underwater_changed.connect(func(v: bool) -> void:
		create_tween().tween_property(tint, "color:a", 0.22 if v else 0.0, 0.3))

	# counters (top-left)
	var top := VBoxContainer.new()
	top.position = Vector2(28, 22)
	add_child(top)
	var orb_box := HBoxContainer.new()
	orb_box.add_theme_constant_override("separation", 10)
	top.add_child(orb_box)
	var orb_icon := TextureRect.new()
	orb_icon.texture = load("res://assets/PNG/Items/blueGem.png")
	orb_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	orb_icon.custom_minimum_size = Vector2(30, 30)
	orb_box.add_child(orb_icon)
	_orb_label = _make_label(24)
	orb_box.add_child(_orb_label)
	_key_box = HBoxContainer.new()
	_key_box.add_theme_constant_override("separation", 10)
	_key_box.visible = false
	top.add_child(_key_box)
	var key_icon := TextureRect.new()
	key_icon.texture = load("res://assets/PNG/Items/keyGreen.png")
	key_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	key_icon.custom_minimum_size = Vector2(30, 30)
	_key_box.add_child(key_icon)
	_key_label = _make_label(24)
	_key_box.add_child(_key_label)

	# banner (upper middle)
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 120
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_banner_title = _make_label(54)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = _make_label(24)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.modulate = Color(0.85, 0.95, 1.0)
	_banner.add_child(_banner_sub)

	# hint panel (bottom middle)
	_hint = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.12, 0.72)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.border_color = Color(0.6, 0.85, 1.0, 0.35)
	sb.set_border_width_all(2)
	_hint.add_theme_stylebox_override("panel", sb)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -50
	_hint.modulate.a = 0.0
	add_child(_hint)
	_hint_label = _make_label(22)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_child(_hint_label)

	_toast = _make_label(20)
	_toast.text = "Progress saved"
	_toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.offset_right = -28
	_toast.offset_top = 22
	_toast.modulate = Color(0.75, 1.0, 0.85, 0.0)
	add_child(_toast)
	Game.saved.connect(func() -> void:
		var t := create_tween()
		t.tween_property(_toast, "modulate:a", 1.0, 0.3)
		t.tween_interval(1.5)
		t.tween_property(_toast, "modulate:a", 0.0, 0.8))
	Game.orbs_changed.connect(_on_orbs)
	Game.keys_changed.connect(_on_keys)
	Game.show_banner.connect(_on_banner)
	Game.show_hint.connect(_on_hint)
	Game.hide_hint.connect(_on_hide_hint)
	Game.screen_flash.connect(_on_flash)
	_on_orbs(Game.orbs, Game.orbs_total)


func _make_label(size: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = maxi(4, size / 5)
	ls.outline_color = Color(0.05, 0.04, 0.12, 0.9)
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_orbs(count: int, total: int) -> void:
	_orb_label.text = "%d / %d" % [count, total]
	_orb_label.pivot_offset = _orb_label.size / 2.0
	_orb_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_orb_label, "scale", Vector2.ONE, 0.25)


func _on_keys(count: int) -> void:
	_key_box.visible = count > 0
	_key_label.text = "x %d" % count


func _on_banner(title: String, subtitle: String) -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_sub.visible = subtitle != ""
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween().set_ignore_time_scale(true)
	_banner.modulate.a = 0.0
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	if not Game.finished:  # the end screen stays up
		_banner_tween.tween_interval(3.2)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _on_hint(text: String) -> void:
	_hint_label.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_ignore_time_scale(true)
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.25)


func _on_hide_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_ignore_time_scale(true)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)


func _on_flash(color: Color, duration: float) -> void:
	_flash.color = color
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_flash, "color:a", 0.0, duration)
