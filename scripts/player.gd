class_name Player
extends CharacterBody2D
## Ori-inspired character controller.
##
## Everything that affects "feel" is exported so it can be tuned live in the
## inspector (select the Player node while the game runs from the editor).
## Origin of the body is at the feet.

enum State { NORMAL, DASH, BASH_AIM, DEAD, FROZEN }

@export_enum("Grey", "Blue", "Green", "Red") var skin := "Grey"

@export_group("Run")
@export var max_speed := 400.0
@export var ground_accel := 3400.0
@export var ground_decel := 4200.0
@export var turn_accel := 7000.0
@export var air_accel := 2600.0
@export var air_decel := 1100.0
## Speed above max_speed (from dash / bash) bleeds off at this rate in the air.
@export var overspeed_drag := 700.0

@export_group("Jump")
@export var jump_height := 215.0
@export var jump_time_to_apex := 0.40
@export var fall_gravity_mult := 1.55
## Multiplier applied to upward speed when jump is released early.
@export var jump_cut_mult := 0.42
## Near the top of a jump (|vy| below this) gravity is reduced while jump is held.
@export var apex_threshold := 150.0
@export var apex_gravity_mult := 0.45
@export var max_fall_speed := 980.0
@export var fast_fall_speed := 1300.0
@export var coyote_time := 0.11
@export var jump_buffer_time := 0.14
@export var double_jump_height := 165.0
@export var corner_correction_px := 12

@export_group("Wall")
@export var wall_slide_speed := 150.0
@export var wall_jump_velocity := Vector2(340.0, -1000.0)
## Wall jump while holding toward the wall: mostly upward, so you can climb a single wall.
@export var wall_climb_velocity := Vector2(190.0, -1060.0)
## After a wall jump, air control is reduced for this long.
@export var wall_jump_lock := 0.13
@export var wall_coyote_time := 0.1

@export_group("Dash")
@export var dash_speed := 1050.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.22

@export_group("Glide")
@export var glide_fall_speed := 115.0
@export var glide_speed := 460.0
@export var updraft_speed := 560.0

@export_group("Swim")
@export var swim_speed := 300.0
@export var swim_accel := 1500.0
## Jump underwater kicks you forward in the direction you're holding.
@export var swim_kick_speed := 620.0
@export var swim_kick_cooldown := 0.35
## Jump at the surface leaps out (fraction of a normal jump).
@export var water_jump_mult := 0.95

@export_group("Bash")
@export var bash_radius := 210.0
@export var bash_speed := 1200.0
@export var bash_launch_time := 0.24
@export var bash_max_hold := 1.6
@export var bash_time_scale := 0.04

const BODY_HALF_HEIGHT := 21.0
const SPIRIT_BLUE := Color(0.55, 0.85, 1.6)

var state: State = State.NORMAL
var facing := 1
var gravity: float
var jump_velocity: float

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_coyote_timer := 0.0
var control_lock_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var bash_launch_timer := 0.0
var land_timer := 0.0
var jump_anim_timer := 0.0

var air_jumps_left := 1
var dash_available := true
var can_jump_cut := false
var glide_armed := false
var gliding := false
var wall_dir := 0
var last_wall_dir := 0
var wall_sliding := false
var dash_dir := 1
var in_updraft := 0
var bash_target: Node2D
var bash_aim := Vector2.UP
var bash_start_ms := 0
var trail_timer := 0.0
var anim_time := 0.0
var spin := 0.0
var _last_step := -1
var _spark_timer := 0.0
var _whoosh_timer := 0.0
var swimming := false
var _swim_kick_timer := 0.0

var frames := {}

@onready var visual: Node2D = $Visual
@onready var pivot: Node2D = $Visual/Pivot
@onready var sprite: Sprite2D = $Visual/Pivot/Sprite
@onready var trail: CPUParticles2D = $Trail
@onready var glow: Sprite2D = $Visual/Pivot/Glow

var arrow: BashArrow


func _ready() -> void:
	_recalc_jump()
	_load_frames()
	_set_frame("stand")
	Game.player = self
	if Game.checkpoint == Vector2.ZERO:
		Game.checkpoint = global_position
	arrow = BashArrow.new()
	arrow.visible = false
	arrow.top_level = true
	arrow.z_index = 30
	add_child(arrow)
	trail.texture = FX.dot_texture()
	trail.material = FX.additive_material()
	glow.texture = FX.glow_texture(128)
	glow.material = FX.additive_material()


func _recalc_jump() -> void:
	gravity = 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)
	jump_velocity = -2.0 * jump_height / jump_time_to_apex


func _load_frames() -> void:
	for n in ["stand", "walk1", "walk2", "walk3", "walk4", "walk5", "up1", "up2", "up3",
			"fall", "roll", "duck", "hit", "switch1", "switch2", "dead", "swim1", "swim2"]:
		var path := "res://assets/PNG/Players/Player %s/player%s_%s.png" % [skin, skin, n]
		frames[n] = load(path)


func _set_frame(n: String) -> void:
	var tex: Texture2D = frames[n]
	if sprite.texture == tex:
		return
	sprite.texture = tex
	var s := tex.get_size()
	if n == "roll":
		sprite.offset = -s / 2.0
	else:
		# bottom of the image sits on the feet (pivot is at body centre)
		sprite.offset = Vector2(-s.x / 2.0, BODY_HALF_HEIGHT - s.y)


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	match state:
		State.DEAD, State.FROZEN:
			return
		State.BASH_AIM:
			return  # handled in _process (real time, so aiming stays responsive)
		State.DASH:
			_process_dash(delta)
		State.NORMAL:
			_process_normal(delta)

	_corner_correction(delta)
	var was_on_floor := is_on_floor()
	var pre_velocity := velocity
	move_and_slide()
	_after_move(was_on_floor, pre_velocity)


func _tick_timers(delta: float) -> void:
	coyote_timer -= delta
	jump_buffer_timer -= delta
	wall_coyote_timer -= delta
	control_lock_timer -= delta
	dash_cooldown_timer -= delta
	bash_launch_timer -= delta
	land_timer -= delta
	jump_anim_timer -= delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		if not is_on_floor():
			glide_armed = true


func _process_normal(delta: float) -> void:
	var center := global_position + Vector2(0, -BODY_HALF_HEIGHT)
	var in_water := Game.is_water_at(center)
	if in_water != swimming:
		_water_transition(in_water)
	swimming = in_water
	Game.set_underwater(in_water and Game.is_water_at(center + Vector2(0, -26)))
	if swimming:
		_process_swim(delta)
		return

	var input_x := Input.get_axis("move_left", "move_right")
	var jump_held := Input.is_action_pressed("jump")
	var on_floor := is_on_floor()

	# --- walls ---------------------------------------------------------------
	wall_dir = 0 if on_floor else _wall_contact()
	if wall_dir != 0:
		wall_coyote_timer = wall_coyote_time
		last_wall_dir = wall_dir
		air_jumps_left = 1
		dash_available = true
	wall_sliding = wall_dir != 0 and velocity.y > 0.0 and signf(input_x) == wall_dir

	# --- horizontal ---------------------------------------------------------
	var top_speed := glide_speed if gliding else max_speed
	var target := input_x * top_speed
	var accel: float
	if on_floor:
		if input_x == 0.0:
			accel = ground_decel
		elif velocity.x != 0.0 and signf(input_x) != signf(velocity.x):
			accel = turn_accel
		else:
			accel = ground_accel
	else:
		accel = air_accel if input_x != 0.0 else air_decel
		if control_lock_timer > 0.0:
			accel *= 0.12
		if bash_launch_timer > 0.0:
			accel *= 0.15
		# keep momentum from dash / bash rather than snapping to max_speed
		if absf(velocity.x) > top_speed and (input_x == 0.0 or signf(input_x) == signf(velocity.x)):
			accel = overspeed_drag
	velocity.x = move_toward(velocity.x, target, accel * delta)
	if input_x != 0.0 and control_lock_timer <= 0.0:
		facing = int(signf(input_x))

	# --- jumping ------------------------------------------------------------
	if jump_buffer_timer > 0.0:
		if on_floor or coyote_timer > 0.0:
			_jump()
		elif wall_dir != 0 or wall_coyote_timer > 0.0:
			_wall_jump(wall_dir if wall_dir != 0 else last_wall_dir)
		elif air_jumps_left > 0 and Game.has("double_jump"):
			_double_jump()

	if not jump_held and can_jump_cut and velocity.y < 0.0:
		velocity.y *= jump_cut_mult
		can_jump_cut = false

	# --- gliding ------------------------------------------------------------
	gliding = Game.has("glide") and not on_floor and glide_armed and jump_held \
			and (velocity.y > -40.0 or in_updraft > 0) and wall_dir == 0 and bash_launch_timer <= 0.0

	# --- gravity ------------------------------------------------------------
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	if not on_floor and absf(velocity.y) < apex_threshold and jump_held:
		g *= apex_gravity_mult
	if bash_launch_timer > 0.0:
		g *= 0.35
	if in_updraft > 0 and not gliding:
		g *= 0.55

	if gliding:
		if in_updraft > 0:
			velocity.y = move_toward(velocity.y, -updraft_speed, 2800.0 * delta)
		elif velocity.y > glide_fall_speed:
			velocity.y = move_toward(velocity.y, glide_fall_speed, 3200.0 * delta)
		else:
			velocity.y = minf(velocity.y + g * 0.3 * delta, glide_fall_speed)
	else:
		velocity.y += g * delta
		var max_fall := max_fall_speed
		if Input.is_action_pressed("move_down"):
			max_fall = fast_fall_speed
		if wall_sliding:
			# ease into the slide instead of stopping dead
			velocity.y = move_toward(velocity.y, minf(velocity.y, wall_slide_speed), 2600.0 * delta)
		velocity.y = minf(velocity.y, max_fall)

	# --- abilities ----------------------------------------------------------
	if Input.is_action_just_pressed("dash") and Game.has("dash") and dash_cooldown_timer <= 0.0 \
			and (dash_available or on_floor):
		_start_dash(input_x)
	elif Input.is_action_just_pressed("bash") and Game.has("bash"):
		_try_bash()


func _process_swim(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var center := global_position + Vector2(0, -BODY_HALF_HEIGHT)
	var at_surface := not Game.is_water_at(center + Vector2(0, -28))
	air_jumps_left = 1
	dash_available = true
	glide_armed = false
	gliding = false
	wall_sliding = false
	wall_dir = 0
	_swim_kick_timer -= delta

	var accel := swim_accel if input != Vector2.ZERO else swim_accel * 0.5
	if velocity.length() > swim_speed * 1.05:
		accel = 1100.0  # water drag after a kick or a dive
	velocity = velocity.move_toward(input * swim_speed, accel * delta)
	if input.y == 0.0 and not at_surface:
		velocity.y = move_toward(velocity.y, -70.0, 380.0 * delta)  # gentle buoyancy
	if at_surface and input.y <= 0.0 and velocity.y < 0.0:
		velocity.y = move_toward(velocity.y, 0.0, 3200.0 * delta)  # float at the top
	if input.x != 0.0:
		facing = int(signf(input.x))

	if jump_buffer_timer > 0.0:
		if at_surface:
			jump_buffer_timer = 0.0
			velocity.y = jump_velocity * water_jump_mult
			can_jump_cut = true
			_squash(Vector2(0.72, 1.32))
			Sfx.play("jump")
		elif _swim_kick_timer <= 0.0:
			jump_buffer_timer = 0.0
			_swim_kick_timer = swim_kick_cooldown
			var dir := input.normalized() if input != Vector2.ZERO else Vector2(facing, 0)
			velocity = dir * swim_kick_speed
			_squash(Vector2(0.8, 1.2))
			Sfx.play("swim", 1.0, -3.0, 0.12)
			FX.burst(get_parent(), center - dir * 20.0, Color(0.7, 0.95, 1.3, 0.7), 8, 120.0, 0.7, 0.6,
					-dir, 40.0, -60.0)
			Game.impulse(center, 120.0, 1.0)

	if Input.is_action_just_pressed("dash") and Game.has("dash") and dash_cooldown_timer <= 0.0:
		_start_dash(input.x)
	elif Input.is_action_just_pressed("bash") and Game.has("bash"):
		_try_bash()


func _water_transition(entering: bool) -> void:
	var speed := absf(velocity.y)
	var surface_y := floorf((global_position.y - BODY_HALF_HEIGHT) / 64.0) * 64.0
	if not entering:
		surface_y += 64.0
	var at := Vector2(global_position.x, surface_y)
	if entering:
		velocity *= 0.45
		can_jump_cut = false
		if speed > 150.0:
			Sfx.play("splash", 1.0, linear_to_db(clampf(speed / 900.0, 0.3, 1.0)))
			FX.burst(get_parent(), at, Color(0.75, 0.95, 1.4, 0.9), int(10 + speed / 60.0), 200.0 + speed * 0.3,
					0.6, 0.9, Vector2.UP, 35.0, 900.0)
			FX.ring(get_parent(), at, Color(0.7, 0.9, 1.4, 0.6), 50.0 + speed * 0.04, 0.35, 3.0)
			Game.impulse(at, 160.0, 1.5)
	elif speed > 150.0:
		Sfx.play("splash", 1.3, -6.0)
		FX.burst(get_parent(), at, Color(0.75, 0.95, 1.4, 0.8), 10, 220.0, 0.5, 0.8, Vector2.UP, 30.0, 900.0)


func _after_move(was_on_floor: bool, pre_velocity: Vector2) -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		_land(pre_velocity.y)
	elif was_on_floor and not on_floor and velocity.y >= 0.0:
		coyote_timer = coyote_time  # walked off a ledge
	if on_floor:
		air_jumps_left = 1
		dash_available = true
		glide_armed = false
	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0
		can_jump_cut = false


# ---------------------------------------------------------------------------
# Moves
# ---------------------------------------------------------------------------

func _jump() -> void:
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	can_jump_cut = true
	glide_armed = false
	jump_anim_timer = 0.08
	if not Input.is_action_pressed("jump"):
		velocity.y *= 0.6  # buffered tap: small hop
	_squash(Vector2(0.72, 1.32))
	FX.dust(get_parent(), global_position, 6, Vector2.UP, 120.0)
	Sfx.play("jump")


func _double_jump() -> void:
	velocity.y = -sqrt(2.0 * gravity * double_jump_height)
	air_jumps_left -= 1
	jump_buffer_timer = 0.0
	can_jump_cut = true
	spin = TAU * facing
	_squash(Vector2(0.8, 1.25))
	Sfx.play("double_jump")
	Game.impulse(global_position + Vector2(0, 40), 170.0, 2.2)
	FX.burst(get_parent(), global_position, SPIRIT_BLUE, 14, 220.0, 0.45, 1.0, Vector2.DOWN, 50.0)
	FX.ring(get_parent(), global_position + Vector2(0, -4), Color(0.6, 0.9, 1.5, 0.8), 46.0, 0.3, 4.0)


func _wall_jump(dir: int) -> void:
	var toward := signf(Input.get_axis("move_left", "move_right")) == dir
	if toward:
		velocity = Vector2(-dir * wall_climb_velocity.x, wall_climb_velocity.y)
		control_lock_timer = wall_jump_lock * 0.5
	else:
		velocity = Vector2(-dir * wall_jump_velocity.x, wall_jump_velocity.y)
		control_lock_timer = wall_jump_lock
	jump_buffer_timer = 0.0
	wall_coyote_timer = 0.0
	can_jump_cut = true
	facing = -dir
	_squash(Vector2(0.75, 1.3))
	FX.dust(get_parent(), global_position + Vector2(dir * 14, -20), 6, Vector2(-dir, -0.3), 160.0)
	Sfx.play("wall_jump")


func _start_dash(input_x: float) -> void:
	state = State.DASH
	dash_dir = int(signf(input_x)) if input_x != 0.0 else facing
	facing = dash_dir
	dash_timer = dash_time
	if not is_on_floor():
		dash_available = false
	velocity = Vector2(dash_dir * dash_speed, 0.0)
	_squash(Vector2(1.35, 0.75))
	FX.burst(get_parent(), global_position + Vector2(0, -BODY_HALF_HEIGHT), SPIRIT_BLUE, 16, 300.0,
			0.35, 1.0, Vector2(-dash_dir, 0), 35.0)
	Game.shake(3.0, 0.12)
	Game.rumble(0.3, 0.0, 0.12)
	Sfx.play("dash")
	Game.impulse(global_position + Vector2(-dash_dir * 30, -10), 260.0, 2.5)


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = Vector2(dash_dir * dash_speed, 0.0)
	# break things / slip over small ledges
	var col := move_and_collide(velocity * delta, true)
	if col:
		var other := col.get_collider()
		if other and other.has_method("shatter"):
			other.shatter(dash_dir)
		else:
			for up in range(2, 20, 2):
				var t := global_transform.translated(Vector2(0, -up))
				if not test_move(global_transform, Vector2(0, -up)) and not test_move(t, velocity * delta):
					global_position.y -= up
					break
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.02
		FX.afterimage(get_parent(), sprite, Color(0.5, 0.85, 1.6, 0.7), 0.22)
		Game.impulse(global_position + Vector2(0, -10), 110.0, 1.2)
	# dash-jump: keep a chunk of the speed
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		state = State.NORMAL
		velocity.x = dash_dir * maxf(max_speed * 1.25, dash_speed * 0.6)
		_jump()
		return
	if dash_timer <= 0.0:
		state = State.NORMAL
		velocity.x = dash_dir * max_speed * 1.15
		dash_cooldown_timer = dash_cooldown


func _try_bash() -> void:
	var best: Node2D = null
	var best_d := bash_radius
	var center := global_position + Vector2(0, -BODY_HALF_HEIGHT)
	for n in get_tree().get_nodes_in_group("bashable"):
		var node := n as Node2D
		if node == null or not node.is_visible_in_tree():
			continue
		var d := center.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	if best == null:
		return
	bash_target = best
	state = State.BASH_AIM
	bash_start_ms = Time.get_ticks_msec()
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	bash_aim = input.normalized() if input.length() > 0.3 else Vector2(facing * 0.45, -1.0).normalized()
	velocity = Vector2.ZERO
	gliding = false
	Game.set_time_scale(bash_time_scale)
	arrow.visible = true
	arrow.global_position = bash_target.global_position
	arrow.aim = bash_aim
	if bash_target.has_method("on_bash_grab"):
		bash_target.on_bash_grab()
	Sfx.play("bash_grab", 1.0, -2.0, 0.0)


func _process_bash_aim(real_delta: float) -> void:
	if not is_instance_valid(bash_target):
		_end_bash_aim()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.3:
		bash_aim = bash_aim.slerp(input.normalized(), 1.0 - exp(-25.0 * real_delta)).normalized()
	arrow.global_position = bash_target.global_position
	arrow.aim = bash_aim
	# drift toward the target while aiming
	var hold_pos := bash_target.global_position + Vector2(0, BODY_HALF_HEIGHT) - bash_aim * 34.0
	global_position = global_position.lerp(hold_pos, 1.0 - exp(-12.0 * real_delta))
	facing = 1 if bash_aim.x >= 0.0 else -1
	var held := (Time.get_ticks_msec() - bash_start_ms) / 1000.0
	if not Input.is_action_pressed("bash") or held > bash_max_hold:
		_bash_launch()


func _bash_launch() -> void:
	var target_pos := bash_target.global_position
	global_position = target_pos + Vector2(0, BODY_HALF_HEIGHT) + bash_aim * 20.0
	reset_physics_interpolation()
	velocity = bash_aim * bash_speed
	bash_launch_timer = bash_launch_time
	air_jumps_left = 1
	dash_available = true
	glide_armed = false
	can_jump_cut = false
	spin = TAU * 2.0 * facing
	if bash_target.has_method("on_bashed"):
		bash_target.on_bashed(-bash_aim)
	_end_bash_aim()
	Game.ease_time_scale(1.0, 0.12)
	_squash(Vector2(0.7, 1.35))
	FX.ring(get_parent(), target_pos, Color(0.7, 0.95, 1.8), 120.0, 0.4, 8.0)
	FX.burst(get_parent(), target_pos, SPIRIT_BLUE, 30, 420.0, 0.5, 1.2, -bash_aim, 40.0)
	Game.shake(9.0, 0.25)
	Game.rumble(0.4, 0.6, 0.2)
	Sfx.play("bash")
	Game.impulse(target_pos, 360.0, 3.5)


func _end_bash_aim() -> void:
	arrow.visible = false
	if state == State.BASH_AIM:
		state = State.NORMAL
	if Engine.time_scale < 1.0 and bash_launch_timer <= 0.0:
		Game.ease_time_scale(1.0, 0.1)


func _land(impact: float) -> void:
	var t := clampf(impact / fast_fall_speed, 0.0, 1.0)
	_squash(Vector2(1.0 + 0.4 * t, 1.0 - 0.35 * t))
	land_timer = 0.06 + 0.06 * t
	if impact > 300.0:
		FX.dust(get_parent(), global_position + Vector2(-10, 0), int(4 + 6 * t), Vector2(-1, -0.4), 90.0 + 120.0 * t)
		FX.dust(get_parent(), global_position + Vector2(10, 0), int(4 + 6 * t), Vector2(1, -0.4), 90.0 + 120.0 * t)
	if impact > 1100.0:
		Game.shake(5.0, 0.15)
		Game.rumble(0.2, 0.4, 0.12)
	if impact > 150.0:
		Sfx.play("land", 1.0, linear_to_db(0.35 + 0.65 * t))
	if impact > 400.0:
		Game.impulse(global_position + Vector2(0, 10), 90.0 + 140.0 * t, 0.8 + 2.2 * t)


func _corner_correction(delta: float) -> void:
	# Nudge around ceiling corners so near-miss jumps still go through.
	if velocity.y >= 0.0:
		return
	var motion := Vector2(0, velocity.y * delta)
	if not test_move(global_transform, motion):
		return
	for i in range(1, corner_correction_px + 1):
		for d in [-1, 1]:
			var off := Vector2(i * d, 0)
			if not test_move(global_transform, off) and not test_move(global_transform.translated(off), motion):
				global_position += off
				return


func _wall_contact() -> int:
	if test_move(global_transform, Vector2(3, 0)):
		return 1
	if test_move(global_transform, Vector2(-3, 0)):
		return -1
	return 0


# ---------------------------------------------------------------------------
# Death / respawn / misc
# ---------------------------------------------------------------------------

func die() -> void:
	if state == State.DEAD:
		return
	if state == State.BASH_AIM:
		_end_bash_aim()
	state = State.DEAD
	Game.deaths += 1
	velocity = Vector2.ZERO
	_set_frame("dead")
	Game.shake(12.0, 0.3)
	Game.rumble(0.6, 0.8, 0.35)
	Sfx.play("death")
	Game.impulse(global_position, 240.0, 3.0)
	FX.burst(get_parent(), global_position + Vector2(0, -BODY_HALF_HEIGHT), Color(1.6, 0.9, 0.9), 30, 380.0, 0.7)
	Game.hitstop(0.08, 0.05)
	var t := create_tween()
	t.tween_property(visual, "modulate:a", 0.0, 0.35).set_delay(0.15)
	await get_tree().create_timer(0.75).timeout
	respawn()


func respawn() -> void:
	global_position = Game.checkpoint
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	state = State.NORMAL
	in_updraft = 0
	swimming = false
	Game.set_underwater(false)
	air_jumps_left = 1
	dash_available = true
	visual.modulate.a = 1.0
	_squash(Vector2(0.6, 1.4))
	Sfx.play("respawn")
	FX.ring(get_parent(), global_position + Vector2(0, -BODY_HALF_HEIGHT), Color(0.7, 0.95, 1.8), 70.0, 0.4, 5.0)
	FX.burst(get_parent(), global_position + Vector2(0, -BODY_HALF_HEIGHT), SPIRIT_BLUE, 20, 200.0, 0.5)


## Briefly freeze the player (used for ability shrines).
func freeze(duration: float) -> void:
	state = State.FROZEN
	velocity = Vector2.ZERO
	await get_tree().create_timer(duration).timeout
	if state == State.FROZEN:
		state = State.NORMAL


func bounce(strength: float) -> void:
	velocity.y = -strength
	air_jumps_left = 1
	dash_available = true


func _squash(s: Vector2) -> void:
	visual.scale = s


# ---------------------------------------------------------------------------
# Animation (runs every rendered frame)
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.001)  # real time, for bash slow-mo
	var alive := state == State.NORMAL
	Sfx.set_loop_volume("glide", 0.55 if (alive and gliding) else 0.0)
	var sliding := alive and wall_sliding and velocity.y > 60.0
	Sfx.set_loop_volume("wall", 0.4 if sliding else 0.0)
	if sliding:
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = 0.05
			FX.burst(get_parent(), global_position + Vector2(wall_dir * 14, -30), Color(0.9, 1.1, 1.4),
					2, 90.0, 0.35, 0.6, Vector2(-wall_dir, -1.5), 30.0, 300.0)
	visual.scale = visual.scale.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	sprite.flip_h = facing < 0
	var target_rot := 0.0
	var speed_ratio := absf(velocity.x) / max_speed
	var on_floor := is_on_floor()

	match state:
		State.DEAD:
			return
		State.BASH_AIM:
			_process_bash_aim(rd)
			_set_frame("roll")
			pivot.rotation += 10.0 * rd * facing
			glow.modulate.a = lerpf(glow.modulate.a, 1.0, 1.0 - exp(-10.0 * rd))
			return
		State.DASH:
			_set_frame("roll")
			pivot.rotation += 30.0 * delta * dash_dir
			trail.emitting = true
			return

	if swimming and state == State.NORMAL:
		var sp := velocity.length()
		anim_time += delta * (3.0 + sp / 60.0)
		_set_frame("swim1" if int(anim_time) % 2 == 0 else "swim2")
		if sp > 40.0:
			target_rot = clampf(Vector2(absf(velocity.x), velocity.y).angle(), -1.3, 1.3) * facing
		pivot.rotation = lerp_angle(pivot.rotation, target_rot, 1.0 - exp(-8.0 * delta))
		trail.emitting = false
		glow.modulate.a = lerpf(glow.modulate.a, 0.5, 1.0 - exp(-6.0 * delta))
		return
	if spin != 0.0:
		var step := signf(spin) * minf(absf(spin), 22.0 * delta)
		pivot.rotation += step
		spin -= step
		_set_frame("roll" if bash_launch_timer > 0.0 else "up3")
	else:
		if on_floor:
			if land_timer > 0.0:
				_set_frame("duck")
			elif absf(velocity.x) > 20.0:
				anim_time += delta * (6.0 + 8.0 * speed_ratio)
				var cycle := ["walk1", "walk2", "walk3", "walk2"]
				var step_i := int(anim_time) % cycle.size()
				if step_i != _last_step and step_i % 2 == 0:
					Sfx.play("step", 1.0, -6.0, 0.15)
					if speed_ratio > 0.8:
						FX.dust(get_parent(), global_position - Vector2(facing * 8, 0), 2, Vector2(-facing, -0.6), 60.0)
				_last_step = step_i
				_set_frame(cycle[step_i])
				target_rot = clampf(velocity.x / max_speed, -1.0, 1.0) * 0.12
			else:
				anim_time = 0.0
				_set_frame("stand")
		elif wall_sliding:
			_set_frame("switch1")
			sprite.flip_h = wall_dir < 0
		elif gliding:
			_set_frame("walk5")
			target_rot = clampf(velocity.x / glide_speed, -1.0, 1.0) * 0.18
		elif jump_anim_timer > 0.0:
			_set_frame("up1")
		elif velocity.y < -320.0:
			_set_frame("up2")
		elif velocity.y < 260.0:
			_set_frame("up3")
		else:
			_set_frame("fall")
		if not on_floor and not wall_sliding and not gliding:
			target_rot = clampf(velocity.x / max_speed, -1.2, 1.2) * 0.1
		pivot.rotation = lerp_angle(pivot.rotation, target_rot, 1.0 - exp(-14.0 * delta))

	# idle "breathing"
	if on_floor and absf(velocity.x) < 20.0 and land_timer <= 0.0:
		var b := sin(Time.get_ticks_msec() / 1000.0 * 2.6) * 0.025
		visual.scale *= Vector2(1.0 - b * 0.5, 1.0 + b)

	var fast := velocity.length() > max_speed * 1.2 or gliding or bash_launch_timer > 0.0
	trail.emitting = fast or (not on_floor and absf(velocity.y) > 700.0)
	glow.modulate.a = lerpf(glow.modulate.a, 0.9 if (fast or gliding) else 0.35, 1.0 - exp(-6.0 * delta))
	if gliding or bash_launch_timer > 0.0 or velocity.length() > max_speed * 1.3:
		_whoosh_timer -= delta
		if _whoosh_timer <= 0.0:
			_whoosh_timer = 0.08
			Game.impulse(global_position + Vector2(0, 30), 120.0, 0.7)
	if bash_launch_timer > 0.0:
		trail_timer -= delta
		if trail_timer <= 0.0:
			trail_timer = 0.025
			FX.afterimage(get_parent(), sprite, Color(0.6, 0.9, 1.7, 0.6), 0.25)


# ---------------------------------------------------------------------------

class BashArrow extends Node2D:
	var aim := Vector2.UP:
		set(v):
			aim = v
			queue_redraw()

	func _draw() -> void:
		var c := Color(0.75, 0.95, 1.8)
		draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 48, Color(c, 0.5), 3.0, true)
		var a := aim * 60.0
		var b := aim * 150.0
		draw_line(a, b, c, 5.0, true)
		var side := aim.orthogonal() * 16.0
		draw_colored_polygon(PackedVector2Array([b + aim * 26.0, b + side, b - side]), c)
