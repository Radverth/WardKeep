extends Node
## Music and SFX playback. Pipeline/Integration Spec §2.6 fixes which track
## and which one-shot belongs to which moment; volumes come from the save's
## settings dictionary (Technical Architecture §5).

const MUSIC_GAMEPLAY: String = "res://assets/audio/music/Infinite Descent.ogg"
const MUSIC_BOSS: String = "res://assets/audio/music/Mission Plausible.ogg"
const STINGER_MENU: String = "res://assets/audio/music/Serious ident.ogg"

const SFX_UI_CLICK: String = "res://assets/audio/sfx_ui/click2.ogg"
const SFX_UI_SELECT: String = "res://assets/audio/sfx_ui/switch1.ogg"
const SFX_WARD_STONE_HIT: String = "res://assets/audio/sfx_impact/impactBell_heavy_000.ogg"
const SFX_TOWER_HITS: Array[String] = [
	"res://assets/audio/sfx_impact/impactMetal_light_000.ogg",
	"res://assets/audio/sfx_impact/impactMetal_light_002.ogg",
	"res://assets/audio/sfx_impact/impactMetal_light_003.ogg",
	"res://assets/audio/sfx_impact/impactMetal_medium_002.ogg",
]
const SFX_ENEMY_DEATH: Array[String] = [
	"res://assets/audio/sfx_impact/impactMetal_heavy_002.ogg",
	"res://assets/audio/sfx_impact/impactMetal_heavy_003.ogg",
]
const SFX_BOSS_DEATH: String = "res://assets/audio/sfx_impact/impactBell_heavy_002.ogg"

## Enough voices for the busiest wave without cutting the Ward Stone cue.
const SFX_VOICES: int = 12
## Impact SFX are high-frequency; one every this many seconds at most.
const SFX_MIN_INTERVAL: float = 0.04

var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_sfx_time: float = 0.0
var _current_music: String = ""
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = "Master"
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	for index: int in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % index
		add_child(voice)
		_voices.append(voice)
	apply_settings()

func apply_settings() -> void:
	var music_volume: float = float(SaveManager.get_setting("music_volume", 0.8))
	var sfx_volume: float = float(SaveManager.get_setting("sfx_volume", 1.0))
	_music.volume_db = _linear_to_db(music_volume)
	for voice: AudioStreamPlayer in _voices:
		voice.volume_db = _linear_to_db(sfx_volume)

func _linear_to_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)

func play_music(path: String) -> void:
	if _current_music == path and _music.playing:
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_current_music = path
	_music.stream = stream
	_music.play()

## The Main Menu ident is a one-shot, so it is played unlooped and left alone.
func play_stinger(path: String) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_current_music = path
	_music.stream = stream
	_music.play()

func current_music() -> String:
	return _current_music

func stop_music() -> void:
	_current_music = ""
	_music.stop()

func play_sfx(path: String, pitch_variation: float = 0.08) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_sfx_time < SFX_MIN_INTERVAL:
		return
	_last_sfx_time = now
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = 1.0 + _rng.randf_range(-pitch_variation, pitch_variation)
	voice.play()

func play_random_sfx(paths: Array[String]) -> void:
	if paths.is_empty():
		return
	play_sfx(paths[_rng.randi_range(0, paths.size() - 1)])

func click() -> void:
	play_sfx(SFX_UI_CLICK, 0.0)

func select() -> void:
	play_sfx(SFX_UI_SELECT, 0.0)

## Gameplay music loops; the menu ident deliberately does not.
func _on_music_finished() -> void:
	if _current_music == MUSIC_GAMEPLAY or _current_music == MUSIC_BOSS:
		_music.play()
