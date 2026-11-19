extends Node

# SoundManager - Autoload Singleton
# Reproduce música ambiental del video y efectos sonoros de física, motor y propulsores.

var music_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer
var thruster_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var brake_player: AudioStreamPlayer
var burnout_player: AudioStreamPlayer

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 12

var sounds: Dictionary = {}
var music_enabled: bool = true
var sfx_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_load_sound_assets()
	play_music()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if music_enabled:
		play_music()
	else:
		stop_music()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not sfx_enabled:
		stop_engine()

func _setup_audio_players() -> void:
	# Música de fondo
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = -6.0
	add_child(music_player)

	# Sonido continuo de motor
	engine_player = AudioStreamPlayer.new()
	engine_player.bus = "Master"
	engine_player.volume_db = -12.0
	add_child(engine_player)

	# Sonido continuo de propulsor
	thruster_player = AudioStreamPlayer.new()
	thruster_player.bus = "Master"
	thruster_player.volume_db = -4.0
	add_child(thruster_player)

	# Sonido continuo de viento a alta velocidad
	wind_player = AudioStreamPlayer.new()
	wind_player.bus = "Master"
	wind_player.volume_db = -12.0
	add_child(wind_player)

	# Sonido continuo de frenado (derrape)
	brake_player = AudioStreamPlayer.new()
	brake_player.bus = "Master"
	brake_player.volume_db = -10.0
	add_child(brake_player)

	# Sonido continuo de quemado de llanta (burnout)
	burnout_player = AudioStreamPlayer.new()
	burnout_player.bus = "Master"
	burnout_player.volume_db = -8.0
	add_child(burnout_player)

	# Pool para efectos sonoros simultáneos
	for i in range(MAX_SFX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

func _load_wav_safe(path: String, loop: bool = false) -> AudioStream:
	if FileAccess.file_exists(path + ".import") and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStreamWAV:
			var wav: AudioStreamWAV = (res as AudioStreamWAV).duplicate() as AudioStreamWAV
			if loop:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				if wav.loop_end <= 0 and wav.data.size() > 0:
					wav.loop_end = int(wav.data.size() / 2)
			else:
				wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return wav
		elif res is AudioStream:
			return res as AudioStream

	if FileAccess.file_exists(path):
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file != null:
			var bytes: PackedByteArray = file.get_buffer(file.get_length())
			file.close()
			if bytes.size() > 44:
				var stream: AudioStreamWAV = AudioStreamWAV.new()
				stream.format = AudioStreamWAV.FORMAT_16_BITS
				var rate: int = bytes.decode_u32(24)
				stream.mix_rate = rate if (rate >= 8000 and rate <= 96000) else 22050
				stream.stereo = false
				stream.data = bytes.slice(44)
				if loop:
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
					stream.loop_begin = 0
					stream.loop_end = int(stream.data.size() / 2)
				return stream
	return null

func _load_sound_assets() -> void:
	if ResourceLoader.exists("res://assets/audio/music_theme.ogg"):
		music_player.stream = load("res://assets/audio/music_theme.ogg")

	engine_player.stream = _load_wav_safe("res://assets/audio/snd_engine.wav", true)
	thruster_player.stream = _load_wav_safe("res://assets/audio/snd_thruster.wav", true)
	wind_player.stream = _load_wav_safe("res://assets/audio/snd_wind.wav", true)
	brake_player.stream = _load_wav_safe("res://assets/audio/snd_brake.wav", true)
	burnout_player.stream = _load_wav_safe("res://assets/audio/snd_burnout.wav", true)

	var sfx_files: Dictionary = {
		"coin": "res://assets/audio/snd_coin.wav",
		"fuel": "res://assets/audio/snd_fuel.wav",
		"crash": "res://assets/audio/snd_crash.wav",
		"click": "res://assets/audio/snd_click.wav",
		"boost_burst": "res://assets/audio/snd_thruster.wav",
		"brake": "res://assets/audio/snd_brake.wav",
		"landing": "res://assets/audio/snd_landing.wav",
		"burnout": "res://assets/audio/snd_burnout.wav",
		"flip": "res://assets/audio/snd_flip.wav",
		"ruby": "res://assets/audio/snd_ruby.wav",
		"accel": "res://assets/audio/snd_accel.wav",
		"rollover": "res://assets/audio/snd_rollover.wav"
	}
	for key: String in sfx_files:
		var st: AudioStream = _load_wav_safe(sfx_files[key], false)
		if st != null:
			sounds[key] = st


func play_music() -> void:
	if not music_enabled:
		return
	if music_player.stream and not music_player.playing:
		music_player.play()

func stop_music() -> void:
	if music_player.playing:
		music_player.stop()

func start_engine() -> void:
	if not sfx_enabled:
		return
	if engine_player.stream and not engine_player.playing:
		engine_player.pitch_scale = 0.8
		engine_player.volume_db = -10.0
		engine_player.play()

func update_engine_pitch(speed_ratio: float, throttle_active: bool) -> void:
	if not engine_player.playing:
		return
	var target_pitch = 0.7 + clamp(speed_ratio, 0.0, 2.0) * 0.7
	if throttle_active:
		target_pitch += 0.38
		engine_player.volume_db = -7.0
	else:
		engine_player.volume_db = -14.0
	engine_player.pitch_scale = lerp(engine_player.pitch_scale, target_pitch, 0.15)

func stop_engine() -> void:
	if engine_player and engine_player.playing:
		engine_player.stop()
	if brake_player and brake_player.playing:
		brake_player.stop()
	if burnout_player and burnout_player.playing:
		burnout_player.stop()
	if wind_player and wind_player.playing:
		wind_player.stop()

func set_thruster_active(_active: bool = false) -> void:
	if thruster_player and thruster_player.playing:
		thruster_player.stop()

func play_sfx(name: String, pitch: float = 1.0) -> void:
	if not sfx_enabled or not sounds.has(name):
		return
	var stream = sounds[name]
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = 0.0
			p.play()
			return
	# Si todos están ocupados, usar el primero
	sfx_players[0].stream = stream
	sfx_players[0].pitch_scale = pitch
	sfx_players[0].play()

func set_brake_active(active: bool, speed_ratio: float = 1.0) -> void:
	if not sfx_enabled or not active:
		if brake_player and brake_player.playing:
			brake_player.stop()
		return
	if brake_player and brake_player.stream:
		if not brake_player.playing:
			brake_player.play()
		var clamped_s: float = clampf(speed_ratio, 0.0, 1.0)
		brake_player.pitch_scale = 0.88 + clamped_s * 0.35
		brake_player.volume_db = lerpf(-16.0, -4.0, clamped_s)

func play_brake(speed_ratio: float = 1.0) -> void:
	set_brake_active(true, speed_ratio)

func set_burnout_active(active: bool, intensity: float = 1.0) -> void:
	if not sfx_enabled or not active or intensity <= 0.12:
		if burnout_player and burnout_player.playing:
			burnout_player.stop()
		return
	if burnout_player and burnout_player.stream:
		if not burnout_player.playing:
			burnout_player.play()
		var clamped_i: float = clampf(intensity, 0.0, 1.0)
		burnout_player.pitch_scale = 0.90 + clamped_i * 0.32
		burnout_player.volume_db = lerpf(-15.0, -3.5, clamped_i)

func play_burnout(intensity: float) -> void:
	set_burnout_active(intensity > 0.12, intensity)

func play_accel(pitch: float = 1.0) -> void:
	play_sfx("accel", pitch)

func play_landing(impact_strength: float) -> void:
	play_sfx("landing", clampf(1.15 - impact_strength * 0.3, 0.75, 1.2))

func play_flip() -> void:
	play_sfx("flip", randf_range(0.95, 1.12))

func play_rollover() -> void:
	play_sfx("rollover", randf_range(0.92, 1.08))

func play_ruby() -> void:
	play_sfx("ruby", 1.05)

func play_wind(speed_ratio: float) -> void:
	if not sfx_enabled:
		if wind_player and wind_player.playing:
			wind_player.stop()
		return
	if speed_ratio > 0.28:
		if wind_player and not wind_player.playing and wind_player.stream:
			wind_player.play()
		if wind_player:
			var clamped_w: float = clampf(speed_ratio, 0.0, 1.0)
			wind_player.pitch_scale = 0.65 + clamped_w * 0.55
			wind_player.volume_db = lerpf(-22.0, -5.0, clamped_w)
	else:
		if wind_player and wind_player.playing:
			wind_player.stop()

