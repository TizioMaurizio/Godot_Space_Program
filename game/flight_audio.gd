class_name FlightAudio
extends AudioStreamPlayer
## Original procedural audio; independent of the physics RNG/state.
var playback: AudioStreamGeneratorPlayback
var phase: float = 0
var noise := RandomNumberGenerator.new()
var burst: float = 0

func _ready() -> void:
	# A dummy/headless display has no interactive audio consumer.
	if AudioServer.get_driver_name() == "Dummy": return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.12
	stream = generator
	noise.seed = 23817
	play()
	playback = get_stream_playback()

func _exit_tree() -> void:
	stop()
	playback = null
	stream = null

func update_audio(craft: RocketState, active: bool) -> void:
	if playback == null: return
	var power: float = clampf(craft.thrust/540000.0,0,1)
	var air: float = clampf(craft.density/0.3,0,1)
	var wind: float = clampf(craft.dynamic_pressure/50000.0,0,1)*air
	var stress: float = clampf(craft.structure.maximum_utilization-0.6,0,0.5)
	for i in range(mini(playback.get_frames_available(),4096)):
		phase += TAU*(45+70*power)/22050
		burst *= 0.9995
		var value: float = (sin(phase)+noise.randf_range(-1,1)*0.7)*power*(0.02+0.06*air)+noise.randf_range(-1,1)*(wind*0.025+burst*0.15)+sin(phase*0.21)*stress*0.03
		playback.push_frame(Vector2.ONE*(value if active else 0.0))
