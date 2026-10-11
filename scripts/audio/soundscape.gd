extends Node

var _streams: Dictionary = {}
var _world_players: Array[AudioStreamPlayer3D] = []
var _ui_player: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _pool_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 901773
	for bus: String in ["Ambience", "Effects", "Interface"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "Interface"
	add_child(_ui_player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	for i: int in range(10):
		var player := AudioStreamPlayer3D.new()
		player.bus = "Effects"
		player.max_distance = 32.0
		player.unit_size = 3.0
		add_child(player)
		_world_players.append(player)
	for id: String in ["click", "evidence", "error", "scanner", "travel", "stone_step", "sand_step", "cloth"]:
		_streams[id] = _synthesize(id)
	_streams["wind"] = _ambient(true)
	_streams["hum"] = _ambient(false)
	Preferences.updated.connect(apply_preferences)
	apply_preferences()


func apply_preferences() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Preferences.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(Preferences.ambience_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effects"), linear_to_db(maxf(Preferences.effects_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Interface"), linear_to_db(maxf(Preferences.effects_volume, 0.0001)) - 6.0)


func set_zone(zone: String) -> void:
	_ambience.stop()
	_ambience.stream = _streams["wind" if zone == "egypt" else "hum"]
	_ambience.volume_db = -17.0 if zone == "egypt" else -21.0
	_ambience.play()


func play_ui(id: String) -> void:
	assert(_streams.has(id), "Sonido desconocido: %s." % id)
	_ui_player.stream = _streams[id]
	_ui_player.pitch_scale = 1.0
	_ui_player.play()


func play_world(id: String, point: Vector3, volume: float = -8.0) -> void:
	assert(_streams.has(id), "Sonido desconocido: %s." % id)
	var player := _world_players[_pool_index]
	_pool_index = (_pool_index + 1) % _world_players.size()
	player.global_position = point
	player.stream = _streams[id]
	player.volume_db = volume
	player.pitch_scale = _rng.randf_range(0.94, 1.06)
	player.play()


func footstep(point: Vector3, sand: bool, quiet: bool, extra_volume: float = 0.0) -> void:
	play_world("sand_step" if sand else "stone_step", point, (-18.0 if quiet else -8.0) + extra_volume)


func stop_all() -> void:
	if is_instance_valid(_ui_player):
		_ui_player.stop()
		_ui_player.stream = null
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
	for player: AudioStreamPlayer3D in _world_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_all()


func _synthesize(id: String) -> AudioStreamWAV:
	var duration := 0.16
	if id == "travel":
		duration = 2.2
	elif id == "scanner":
		duration = 0.9
	elif id in ["sand_step", "stone_step", "cloth"]:
		duration = 0.23
	var sample_rate := 22050
	var samples := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var filtered := 0.0
	for i: int in range(samples):
		var t := float(i) / sample_rate
		var envelope := minf(1.0, t * 150.0) * exp(-t * (8.0 if id == "travel" else 22.0))
		var noise := _rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.17)
		var value := 0.0
		match id:
			"click":
				value = sin(t * TAU * 720.0) * 0.18
			"evidence":
				value = (sin(t * TAU * 660.0) + sin(t * TAU * 990.0)) * 0.15
			"error":
				value = sin(t * TAU * 180.0) * 0.25
			"scanner":
				value = sin(t * TAU * (520.0 + t * 350.0)) * 0.22
				envelope = sin(PI * t / duration) * 0.6
			"travel":
				value = filtered * 0.5 + sin(t * TAU * (55.0 + t * 16.0)) * 0.16
				envelope = sin(PI * t / duration)
			"sand_step":
				value = filtered * 0.9 + noise * 0.16
			"stone_step":
				value = filtered * 0.5 + sin(t * TAU * 95.0) * exp(-t * 50.0) * 0.5
			"cloth":
				value = filtered * 0.4
		bytes.encode_s16(i * 2, int(clampf(value * envelope, -0.95, 0.95) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream


func _ambient(wind: bool) -> AudioStreamWAV:
	var rate := 22050
	var samples := rate * 8
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var low := 0.0
	var very_low := 0.0
	for i: int in range(samples):
		var t := float(i) / rate
		low = lerpf(low, _rng.randf_range(-1.0, 1.0), 0.03)
		very_low = lerpf(very_low, low, 0.007)
		var value := (low * 0.35 + very_low * 0.8) * (0.7 + 0.3 * sin(t * TAU / 8.0))
		if not wind:
			value = sin(t * TAU * 50.0) * 0.12 + sin(t * TAU * 75.0) * 0.08 + low * 0.04
		var seam_envelope := minf(1.0, minf(t, 8.0 - t) * 12.0)
		bytes.encode_s16(i * 2, int(clampf(value * seam_envelope, -0.9, 0.9) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	return stream
