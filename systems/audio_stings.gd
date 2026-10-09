extends Node
## Short procedural stings. No imported audio files required.

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_players.append(player)
	var wind := AudioStreamPlayer.new()
	wind.stream = _noise(1.6, 0.08)
	wind.volume_db = -22.0
	wind.autoplay = true
	add_child(wind)
	if wind.stream is AudioStreamWAV:
		(wind.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	EventBus.manna_spoiled.connect(func() -> void: _play(_tone(140.0, 0.28, 0.35), -6.0))
	EventBus.water_purified.connect(func(_amount: int) -> void: _play(_tone(520.0, 0.18, 0.3), -8.0))
	EventBus.miracle_channeled.connect(func(_who: StringName, _site: StringName) -> void: _play(_tone(660.0, 0.32, 0.4), -4.0))
	EventBus.riot_triggered.connect(func(_at: Vector3) -> void: _play(_tone(90.0, 0.4, 0.45), -4.0))
	EventBus.mission_completed.connect(func(_id: StringName) -> void: _play(_tone(440.0, 0.16, 0.25), -10.0))


func _play(stream: AudioStream, volume_db: float) -> void:
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return


func _tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var mix := 22050
	var count := int(float(mix) * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(mix)
		var env := 1.0 - (t / duration)
		var sample := sin(TAU * freq * t) * env * volume
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix
	stream.stereo = false
	stream.data = data
	return stream


func _noise(duration: float, volume: float) -> AudioStreamWAV:
	var mix := 11025
	var count := int(float(mix) * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hold := 0.0
	for i in count:
		if i % 40 == 0:
			hold = rng.randf_range(-1.0, 1.0) * volume
		var value := int(clampf(hold, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream
