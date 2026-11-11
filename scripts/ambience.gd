extends Node
## Original synthesized machinery and metal footsteps. No external audio dependency.

var player = null
var master_gain: float = 0.72
var _engine: AudioStreamPlayer
var _air: AudioStreamPlayer
var _step: AudioStreamPlayer
var _door: AudioStreamPlayer
var _creak: AudioStreamPlayer3D
var _steps: Array[AudioStreamWAV] = []
var _timer: float = 9.0
var _engine_target: float = -20.0
var _zone: String = ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 710231
	_engine = AudioStreamPlayer.new()
	_engine.name = "EngineResonance"
	_engine.stream = _make_engine()
	_engine.volume_db = -24.0
	add_child(_engine)
	_engine.play()
	_air = AudioStreamPlayer.new()
	_air.name = "Ventilation"
	_air.stream = _make_air()
	_air.volume_db = -31.0
	add_child(_air)
	_air.play()
	_step = AudioStreamPlayer.new()
	_step.name = "MetalFootsteps"
	_step.volume_db = -17.0
	add_child(_step)
	for i in 4:
		_steps.append(_make_step(i))
	_door = AudioStreamPlayer.new()
	_door.name = "BulkheadActuator"
	_door.stream = _make_door()
	_door.volume_db = -14.0
	add_child(_door)
	_creak = AudioStreamPlayer3D.new()
	_creak.name = "HullStress"
	_creak.stream = _make_creak()
	_creak.unit_size = 8.0
	_creak.max_distance = 35.0
	_creak.volume_db = -19.0
	add_child(_creak)
	if is_instance_valid(player):
		player.footstep.connect(_on_footstep)


func set_zone(zone_name: String) -> void:
	_zone = zone_name
	var title: String = zone_name.to_lower()
	_engine_target = -15.0 if ("engine" in title or "reactor" in title or "boiler" in title) else -23.0
	if "bridge" in title or "cockpit" in title:
		_engine_target = -27.0


func set_volume(value: float) -> void:
	master_gain = clampf(value, 0.0, 1.0)


func play_door() -> void:
	_door.volume_db = -13.0 + linear_to_db(maxf(master_gain, 0.00001))
	_door.pitch_scale = _rng.randf_range(0.96, 1.03)
	_door.play()


func _process(delta: float) -> void:
	var gain_db: float = linear_to_db(maxf(master_gain, 0.00001))
	_engine.volume_db = lerpf(_engine.volume_db, _engine_target + gain_db, 1.0 - exp(-delta * 1.4))
	_air.volume_db = -29.0 + gain_db
	_timer -= delta
	if _timer <= 0.0 and is_instance_valid(player) and player.active:
		_creak.global_position = player.global_position + Vector3(_rng.randf_range(-8.0, 8.0), 3.0, _rng.randf_range(-10.0, 10.0))
		_creak.pitch_scale = _rng.randf_range(0.7, 1.15)
		_creak.volume_db = -21.0 + gain_db
		_creak.play()
		_timer = _rng.randf_range(18.0, 32.0)


func _on_footstep(speed: float) -> void:
	_step.stream = _steps[_rng.randi_range(0, _steps.size() - 1)]
	_step.pitch_scale = _rng.randf_range(0.92, 1.08)
	_step.volume_db = (-19.0 if speed < 2.0 else -15.5) + linear_to_db(maxf(master_gain, 0.00001))
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
		var envelope: float = sin(PI * t / 2.0) * exp(-t * 1.4)
		noise = lerpf(noise, _rng.randf_range(-1.0, 1.0), 0.09)
		var sample: float = sin(TAU * (110.0 * t + 12.0 * sin(t * 2.7))) * 0.12
		sample += sin(TAU * 207.0 * t) * 0.04 + noise * 0.13
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
		var motor: float = sin(TAU * (74.0 * t + 7.0 * t * t)) * 0.12 + sin(TAU * 148.0 * t) * 0.05
		var hiss: float = air * 0.35 * motor_envelope
		var latch: float = (sin(TAU * 98.0 * t) * 0.35 + noise * 0.12) * exp(-t * 31.0)
		var end_time: float = maxf(0.0, t - 1.21)
		var stop: float = (sin(TAU * 67.0 * end_time) * 0.27 + air * 0.25) * exp(-end_time * 32.0) if t > 1.21 else 0.0
		var sample: float = (motor * motor_envelope + hiss + latch + stop) * minf(t * 800.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	return _wav(data)
