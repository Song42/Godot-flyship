extends Node
## Original timber, brass machinery, and night wind. No external audio dependency.

var player = null
var master_gain: float = 0.72
var _engine: AudioStreamPlayer
var _air: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _step: AudioStreamPlayer
var _door: AudioStreamPlayer
var _creak: AudioStreamPlayer3D
var _steps: Array[AudioStreamWAV] = []
var _metal_steps: Array[AudioStreamWAV] = []
var _timer: float = 9.0
var _engine_target: float = -26.0
var _wind_target: float = -48.0
var _air_target: float = -34.0
var _metal_floor: bool = false
var _outdoors: bool = false
var _zone: String = ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 710231
	_engine = AudioStreamPlayer.new()
	_engine.name = "EngineResonance"
	_engine.stream = _make_engine()
	_engine.volume_db = -28.0
	add_child(_engine)
	_engine.play()
	_air = AudioStreamPlayer.new()
	_air.name = "DistantSteam"
	_air.stream = _make_air()
	_air.volume_db = -36.0
	add_child(_air)
	_air.play()
	_wind = AudioStreamPlayer.new()
	_wind.name = "OpenDeckWind"
	_wind.stream = _make_wind()
	_wind.volume_db = -60.0
	add_child(_wind)
	_wind.play()
	_step = AudioStreamPlayer.new()
	_step.name = "TimberFootsteps"
	_step.volume_db = -17.0
	add_child(_step)
	for i in 4:
		_steps.append(_make_step(i))
		_metal_steps.append(_make_metal_step(i))
	_door = AudioStreamPlayer.new()
	_door.name = "BrassHinges"
	_door.stream = _make_door()
	_door.volume_db = -14.0
	add_child(_door)
	_creak = AudioStreamPlayer3D.new()
	_creak.name = "TimberSettling"
	_creak.stream = _make_creak()
	_creak.unit_size = 4.5
	_creak.max_distance = 20.0
	_creak.volume_db = -19.0
	add_child(_creak)
	if is_instance_valid(player):
		player.footstep.connect(_on_footstep)


func _exit_tree() -> void:
	for sound in [_engine, _air, _wind, _step, _door, _creak]:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
	_steps.clear()
	_metal_steps.clear()


func set_zone(zone_name: String) -> void:
	_zone = zone_name
	var title: String = zone_name.to_lower()
	_outdoors = "deck" in title or "balcony" in title or "walkway" in title or "promenade" in title
	_metal_floor = "engine" in title or "workshop" in title or "boiler" in title
	_engine_target = -19.5 if _metal_floor else -27.0
	_air_target = -31.0 if _metal_floor else -38.0
	_wind_target = -19.0 if _outdoors else -48.0
	if "cabin" in title or "quarters" in title or "wheelhouse" in title:
		_engine_target = -31.0
	if _outdoors:
		_engine_target = -32.0
		_air_target = -42.0


func set_volume(value: float) -> void:
	master_gain = clampf(value, 0.0, 1.0)


func play_door() -> void:
	_door.volume_db = -16.0 + linear_to_db(maxf(master_gain, 0.00001))
	_door.pitch_scale = _rng.randf_range(0.96, 1.03)
	_door.play()


func _process(delta: float) -> void:
	var gain_db: float = linear_to_db(maxf(master_gain, 0.00001))
	_engine.volume_db = lerpf(_engine.volume_db, _engine_target + gain_db, 1.0 - exp(-delta * 1.4))
	_air.volume_db = lerpf(_air.volume_db, _air_target + gain_db, 1.0 - exp(-delta * 1.2))
	_wind.volume_db = lerpf(_wind.volume_db, _wind_target + gain_db, 1.0 - exp(-delta * 1.6))
	_timer -= delta
	if _timer <= 0.0 and is_instance_valid(player) and player.active:
		_creak.global_position = player.global_position + Vector3(_rng.randf_range(-3.0, 3.0), 1.8, _rng.randf_range(-4.0, 4.0))
		_creak.pitch_scale = _rng.randf_range(0.82, 1.2)
		_creak.volume_db = (-25.0 if _outdoors else -19.0) + gain_db
		_creak.play()
		_timer = _rng.randf_range(12.0, 25.0)


func _on_footstep(speed: float) -> void:
	var collection: Array[AudioStreamWAV] = _metal_steps if _metal_floor else _steps
	_step.stream = collection[_rng.randi_range(0, collection.size() - 1)]
	_step.pitch_scale = _rng.randf_range(0.92, 1.08)
	_step.volume_db = (-21.0 if speed < 2.0 else -17.5) + linear_to_db(maxf(master_gain, 0.00001))
	_step.play()


func _wav(data: PackedByteArray, looped: bool = false) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	wave.stereo = false
	wave.data = data
	if looped:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = data.size() / 2
	return wave


func _make_engine() -> AudioStreamWAV:
	var length: int = 22050 * 6
	var data := PackedByteArray()
	data.resize(length * 2)
	var noise: float = 0.0
	for i in length:
		var t: float = float(i) / 22050.0
		noise = lerpf(noise, _rng.randf_range(-1.0, 1.0), 0.035)
		var pulse: float = 0.75 + 0.25 * sin(TAU * t * 1.5)
		var sample: float = (sin(TAU * 42.0 * t) * 0.34 + sin(TAU * 63.0 * t) * 0.12 + sin(TAU * 84.0 * t) * 0.10 + sin(TAU * 126.0 * t) * 0.035) * pulse
		sample += noise * 0.16
		var seam: float = minf(1.0, minf(float(i), float(length - i - 1)) / 550.0)
		data.encode_s16(i * 2, int(clampf(sample * seam, -1.0, 1.0) * 32767.0))
	return _wav(data, true)


func _make_air() -> AudioStreamWAV:
	var length: int = 22050 * 4
	var data := PackedByteArray()
	data.resize(length * 2)
	var low: float = 0.0
	var smoother: float = 0.0
	for i in length:
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.045)
		smoother = lerpf(smoother, noise - low, 0.19)
		var t: float = float(i) / 22050.0
		var sample: float = smoother * (0.28 + 0.04 * sin(TAU * t * 0.5))
		var seam: float = minf(1.0, minf(float(i), float(length - i - 1)) / 500.0)
		data.encode_s16(i * 2, int(sample * seam * 32767.0))
	return _wav(data, true)


func _make_step(variant: int) -> AudioStreamWAV:
	var length: int = 6200
	var data := PackedByteArray()
	data.resize(length * 2)
	var low: float = 0.0
	for i in length:
		var t: float = float(i) / 22050.0
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.18)
		var sample: float = sin(TAU * (116.0 + variant * 7.0) * t) * exp(-t * 32.0) * 0.32
		sample += sin(TAU * (223.0 + variant * 11.0) * t) * exp(-t * 39.0) * 0.13
		sample += sin(TAU * 451.0 * t) * exp(-t * 47.0) * 0.04
		sample += low * exp(-t * 48.0) * 0.42
		sample *= minf(t * 600.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_metal_step(variant: int) -> AudioStreamWAV:
	var length: int = 5800
	var data := PackedByteArray()
	data.resize(length * 2)
	var low: float = 0.0
	for i in length:
		var t: float = float(i) / 22050.0
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.3)
		var sample: float = sin(TAU * (78.0 + variant * 5.0) * t) * exp(-t * 29.0) * 0.42
		sample += sin(TAU * (349.0 + variant * 17.0) * t) * exp(-t * 26.0) * 0.12
		sample += sin(TAU * 970.0 * t) * exp(-t * 47.0) * 0.06
		sample += low * exp(-t * 62.0) * 0.5
		sample *= minf(t * 800.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_creak() -> AudioStreamWAV:
	var length: int = 22050 * 2
	var data := PackedByteArray()
	data.resize(length * 2)
	var noise: float = 0.0
	for i in length:
		var t: float = float(i) / 22050.0
		var envelope: float = sin(PI * t / 2.0) * exp(-t * 1.1)
		noise = lerpf(noise, _rng.randf_range(-1.0, 1.0), 0.06)
		var friction: float = 0.65 + 0.35 * sin(TAU * 9.0 * t + sin(t * 7.0))
		var sample: float = sin(TAU * (152.0 * t + 10.0 * sin(t * 2.1))) * 0.11 * friction
		sample += sin(TAU * (291.0 * t + 4.0 * sin(t * 3.2))) * 0.035 + noise * 0.11
		data.encode_s16(i * 2, int(sample * envelope * 32767.0))
	return _wav(data)


func _make_door() -> AudioStreamWAV:
	var length: int = 33075
	var data := PackedByteArray()
	data.resize(length * 2)
	var air: float = 0.0
	var low: float = 0.0
	for i in length:
		var t: float = float(i) / 22050.0
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.04)
		air = lerpf(air, noise - low, 0.22)
		var motor_envelope: float = smoothstep(0.0, 0.16, t) * (1.0 - smoothstep(1.0, 1.29, t))
		var motor: float = sin(TAU * (126.0 * t + 5.0 * sin(t * 4.0))) * 0.07 + sin(TAU * (242.0 * t + 3.0 * sin(t * 3.0))) * 0.025
		var hiss: float = air * 0.10 * motor_envelope
		var latch: float = (sin(TAU * 98.0 * t) * 0.35 + noise * 0.12) * exp(-t * 31.0)
		var end_time: float = maxf(0.0, t - 1.21)
		var stop: float = (sin(TAU * 67.0 * end_time) * 0.27 + air * 0.25) * exp(-end_time * 32.0) if t > 1.21 else 0.0
		var sample: float = (motor * motor_envelope + hiss + latch + stop) * minf(t * 800.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_wind() -> AudioStreamWAV:
	var length: int = 22050 * 8
	var data := PackedByteArray()
	data.resize(length * 2)
	var low: float = 0.0
	var air: float = 0.0
	for i in length:
		var t: float = float(i) / 22050.0
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.012)
		air = lerpf(air, noise - low, 0.11)
		var gust: float = 0.65 + sin(TAU * t * 0.125) * 0.18 + sin(TAU * t * 0.375) * 0.08
		var sample: float = (low * 2.3 + air * 0.25) * gust
		var seam: float = minf(1.0, minf(float(i), float(length - i - 1)) / 800.0)
		data.encode_s16(i * 2, int(clampf(sample * seam, -1.0, 1.0) * 32767.0))
	return _wav(data, true)
