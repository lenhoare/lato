extends Node
## Procedural audio (autoload "Sfx"). Every sound is synthesised in code at
## startup, so there are no audio files to manage. To use your own sounds later,
## put an AudioStream into `sounds[name]` (e.g. load("res://audio/jump.ogg")).
##
##   Sfx.play("jump")                 one-shot
##   Sfx.play("orb", 1.5)             with a pitch multiplier
##   Sfx.set_loop_volume("glide", 0.7)

const RATE := 22050

var sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loops := {}
var _music: AudioStreamPlayer
var _orb_combo := 0
var _orb_time := 0.0
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_build_sounds()
	for loop_name in ["glide", "wall"]:
		var lp := AudioStreamPlayer.new()
		lp.bus = "SFX"
		lp.stream = sounds[loop_name]
		lp.volume_db = -80.0
		add_child(lp)
		lp.play()
		_loops[loop_name] = lp
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -80.0
	add_child(_music)
	# the music pad takes a moment to synthesise: do it on a thread
	_thread = Thread.new()
	_thread.start(_make_music)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _process(delta: float) -> void:
	_orb_time -= delta / maxf(Engine.time_scale, 0.001)
	if _orb_time <= 0.0:
		_orb_combo = 0


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0, random_pitch: float = 0.06) -> void:
	if not sounds.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = sounds[sound]
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-random_pitch, random_pitch)))
	p.volume_db = volume_db
	p.play()


## Orb pickups climb a pentatonic scale when collected in quick succession.
func play_orb() -> void:
	var scale := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
	var semis: int = scale[mini(_orb_combo, scale.size() - 1)]
	play("orb", pow(2.0, semis / 12.0), -2.0, 0.0)
	_orb_combo += 1
	_orb_time = 1.4


func set_loop_volume(loop_name: String, amount: float) -> void:
	var lp: AudioStreamPlayer = _loops.get(loop_name)
	if lp:
		var target := linear_to_db(clampf(amount, 0.0001, 1.0))
		lp.volume_db = lerpf(lp.volume_db, target, 0.15)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.75 if bus_name == "SFX" else 0.9
		reverb.damping = 0.5
		reverb.wet = 0.22 if bus_name == "SFX" else 0.35
		reverb.dry = 1.0
		AudioServer.add_bus_effect(idx, reverb)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -6.0)
	# muffled sound underwater: a low-pass on both buses, toggled by Game.underwater
	for bus_name in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 700.0
		AudioServer.add_bus_effect(idx, lp)
		AudioServer.set_bus_effect_enabled(idx, AudioServer.get_bus_effect_count(idx) - 1, false)
	Game.underwater_changed.connect(_on_underwater)


func _on_underwater(value: bool) -> void:
	for bus_name in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_effect_enabled(idx, AudioServer.get_bus_effect_count(idx) - 1, value)


# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

static func _to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


## Tone with pitch sweep, harmonics and an attack/decay envelope.
static func _tone(dur: float, f0: float, f1: float, attack: float, decay_pow: float,
		harmonics: Array = [1.0], vol: float = 0.5, wave := "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var v := 0.0
		for h in harmonics.size():
			var hp: float = phase * (h + 1)
			if wave == "tri":
				v += harmonics[h] * (abs(fposmod(hp, 1.0) * 4.0 - 2.0) - 1.0)
			else:
				v += harmonics[h] * sin(TAU * hp)
		var env := minf(1.0, i / maxf(1.0, attack * RATE)) * pow(1.0 - t, decay_pow)
		out[i] = v * env * vol
	return out


## Filtered noise burst. `cut0` -> `cut1` sweeps a one-pole low-pass (0..1).
static func _noise(dur: float, cut0: float, cut1: float, attack: float, decay_pow: float,
		vol: float = 0.5, highpass := false) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var a := lerpf(cut0, cut1, t)
		var w := randf_range(-1.0, 1.0)
		lp += (w - lp) * a
		var v := (w - lp) if highpass else lp
		var env := minf(1.0, i / maxf(1.0, attack * RATE)) * pow(1.0 - t, decay_pow)
		out[i] = v * env * vol
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset_s := 0.0) -> PackedFloat32Array:
	var off := int(offset_s * RATE)
	var n := maxi(a.size(), b.size() + off)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in a.size():
		out[i] = a[i]
	for i in b.size():
		out[i + off] += b[i]
	return out


static func _bell(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	# inharmonic partials give a glassy, chime-like tone
	var a := _tone(dur, freq, freq, 0.002, 3.0, [1.0], vol)
	var b := _tone(dur * 0.6, freq * 2.76, freq * 2.76, 0.002, 4.0, [1.0], vol * 0.35)
	var c := _tone(dur * 0.4, freq * 5.4, freq * 5.4, 0.001, 5.0, [1.0], vol * 0.15)
	return _mix(_mix(a, b), c)


func _build_sounds() -> void:
	sounds["jump"] = _mix(_tone(0.14, 260, 520, 0.005, 2.0, [1.0, 0.3], 0.28),
			_noise(0.1, 0.5, 0.1, 0.002, 2.0, 0.25))
	sounds["double_jump"] = _mix(_mix(_tone(0.2, 520, 880, 0.004, 2.0, [1.0, 0.25], 0.22),
			_bell(1320, 0.4, 0.14), 0.03), _noise(0.18, 0.7, 0.2, 0.002, 2.0, 0.2, true))
	sounds["wall_jump"] = _mix(_tone(0.12, 300, 560, 0.003, 2.0, [1.0, 0.3], 0.25),
			_noise(0.06, 0.8, 0.3, 0.001, 3.0, 0.35))
	sounds["land"] = _mix(_noise(0.14, 0.12, 0.02, 0.002, 2.5, 0.9),
			_tone(0.1, 120, 60, 0.002, 2.0, [1.0], 0.35))
	sounds["step"] = _noise(0.05, 0.25, 0.05, 0.001, 3.0, 0.45)
	sounds["dash"] = _mix(_noise(0.32, 0.05, 0.6, 0.02, 1.6, 0.7),
			_tone(0.25, 900, 300, 0.005, 2.0, [1.0], 0.08))
	sounds["bash_grab"] = _mix(_tone(0.5, 180, 220, 0.05, 1.0, [1.0, 0.4, 0.2], 0.2),
			_bell(880, 0.6, 0.1))
	sounds["bash"] = _mix(_mix(_noise(0.4, 0.8, 0.05, 0.002, 2.0, 0.6),
			_tone(0.3, 220, 880, 0.003, 1.5, [1.0, 0.4], 0.22)), _bell(1760, 0.5, 0.1), 0.02)
	sounds["orb"] = _bell(1046.5, 0.7, 0.32)
	sounds["key"] = _mix(_bell(784, 0.8, 0.3), _bell(1175, 0.9, 0.3), 0.12)
	sounds["door"] = _mix(_noise(1.0, 0.04, 0.01, 0.05, 1.2, 0.9),
			_tone(0.9, 70, 50, 0.05, 1.5, [1.0, 0.5], 0.4))
	sounds["break"] = _mix(_noise(0.5, 0.6, 0.03, 0.001, 2.5, 0.6),
			_tone(0.2, 140, 50, 0.001, 2.0, [1.0], 0.5))
	sounds["death"] = _mix(_tone(0.6, 600, 90, 0.003, 1.5, [1.0, 0.5, 0.25], 0.25, "tri"),
			_noise(0.4, 0.4, 0.02, 0.002, 2.0, 0.4))
	sounds["respawn"] = _mix(_tone(0.5, 300, 900, 0.1, 1.0, [1.0, 0.3], 0.15), _bell(1320, 0.6, 0.12), 0.25)
	sounds["checkpoint"] = _mix(_mix(_bell(523, 1.2, 0.18), _bell(659, 1.2, 0.18), 0.08), _bell(784, 1.4, 0.2), 0.16)
	var shrine := _tone(2.5, 130.8, 130.8, 0.4, 1.2, [1.0, 0.5, 0.3, 0.2], 0.18)
	var notes := [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0]
	for i in notes.size():
		shrine = _mix(shrine, _bell(notes[i], 1.6, 0.16), 0.1 + i * 0.09)
	sounds["shrine"] = shrine
	sounds["secret"] = _mix(_mix(_bell(880, 1.0, 0.18), _bell(1109, 1.0, 0.16), 0.1), _bell(1319, 1.4, 0.18), 0.2)
	sounds["goal"] = sounds["shrine"]
	sounds["locked"] = _mix(_tone(0.12, 200, 180, 0.002, 2.0, [1.0, 0.5], 0.3, "tri"),
			_tone(0.12, 160, 150, 0.002, 2.0, [1.0, 0.5], 0.3, "tri"), 0.13)
	sounds["splash"] = _mix(_noise(0.55, 0.5, 0.03, 0.003, 1.8, 0.75),
			_tone(0.18, 500, 180, 0.002, 2.0, [1.0], 0.12))
	sounds["swim"] = _mix(_noise(0.3, 0.06, 0.02, 0.03, 1.5, 0.6),
			_tone(0.2, 380, 620, 0.01, 2.0, [1.0], 0.1))
	sounds["glide"] = _make_wind()
	sounds["wall"] = _make_scrape()
	for k in sounds.keys():
		if sounds[k] is PackedFloat32Array:
			sounds[k] = _to_stream(sounds[k], k in ["glide", "wall"])


## Seamless looping wind: band-limited noise with slow swells.
static func _make_wind() -> PackedFloat32Array:
	var n := RATE * 3
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.3
		var swell := 0.6 + 0.4 * sin(TAU * t * 2.0)
		out[i] = (lp - lp2 * 0.5) * swell * 1.4
	# crossfade the ends so the loop is seamless
	var fade := RATE / 4
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	out.resize(n - fade)
	return out


static func _make_scrape() -> PackedFloat32Array:
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		out[i] = lp * 0.35 * (0.8 + 0.2 * sin(TAU * i * 23.0 / n))
	var fade := RATE / 8
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	out.resize(n - fade)
	return out


# ---------------------------------------------------------------------------
# Ambient music: slow, soft chord pad with a sparse twinkling melody.
# ---------------------------------------------------------------------------

func _make_music() -> void:
	var bar := 4.0
	# Am - F - C - G (as frequencies), voiced low and soft
	var chords := [
		[110.0, 164.8, 220.0, 261.6, 329.6],
		[87.3, 174.6, 220.0, 261.6, 349.2],
		[65.4, 130.8, 196.0, 261.6, 329.6],
		[98.0, 146.8, 196.0, 246.9, 293.7],
	]
	var melody_notes := [659.3, 784.0, 880.0, 1046.5, 987.8, 784.0, 659.3, 587.3]
	var total := int(bar * chords.size() * 2 * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for c in chords.size() * 2:
		var chord: Array = chords[c % chords.size()]
		var start := int(c * bar * RATE)
		var len_ := int(bar * 1.5 * RATE)  # overlap into next bar for smoothness
		for f in chord:
			var freq: float = f
			for detune: float in [-0.6, 0.6]:
				var ph := rng.randf()
				var inc: float = (freq + detune) / RATE
				for i in len_:
					var idx := (start + i) % total
					var t := float(i) / len_
					var env := sin(PI * t)  # slow swell in and out
					ph += inc
					out[idx] += sin(TAU * ph) * env * 0.034
	# twinkles
	for k in 14:
		var when := rng.randf_range(0.0, total / float(RATE) - 2.0)
		var note: float = melody_notes[rng.randi() % melody_notes.size()]
		var b := _bell(note, 2.0, 0.05)
		var off := int(when * RATE)
		for i in b.size():
			out[(off + i) % total] += b[i]
	call_deferred("_music_ready", _to_stream(out, true))


func _music_ready(stream: AudioStreamWAV) -> void:
	_thread.wait_to_finish()
	_music.stream = stream
	_music.play()
	var t := create_tween()
	t.tween_property(_music, "volume_db", -4.0, 4.0)
