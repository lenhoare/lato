extends Node
## Dev helper: reports level stats for every generated sound and saves them as WAVs.
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://sfx"
	DirAccess.make_dir_recursive_absolute(out_dir)
	for k in Sfx.sounds.keys():
		var s: AudioStreamWAV = Sfx.sounds[k]
		var d := s.data
		var peak := 0.0
		var sum := 0.0
		for i in range(0, d.size(), 2):
			var v: float = abs(d.decode_s16(i)) / 32000.0
			peak = maxf(peak, v)
			sum += v * v
		print("%-12s len=%.2fs peak=%.2f rms=%.3f" % [k, d.size() / 2.0 / 22050.0, peak, sqrt(sum / (d.size() / 2.0))])
		s.save_to_wav(out_dir + "/" + k + ".wav")
	while Sfx._music.stream == null:
		await get_tree().process_frame
	print("music ready after ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	Sfx._music.stream.save_to_wav(out_dir + "/music.wav")
	get_tree().quit()
