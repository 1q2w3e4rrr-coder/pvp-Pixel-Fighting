extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var current_music: String = ""

# 原版 effect.xfl / EffectModel 里的 sound id 仍然保留，
# 但文件统一转成 Godot 更稳定的 OGG，避免 Godot 4.6 读取 SWF 导出的 wav/mp3 时触发 FileAccessMemory 越界。
const EFFECT_SFX_DIR: String = "res://assets/sfx/effect/"
const EFFECT_SFX_EXT: String = ".ogg"
const EFFECT_SFX_FALLBACK := {
	"snd_kan2": "snd_kan1",
	"snd_hit_heavy": "snd_hit2",
	"snd_fykanx": "snd_fykan",
	"snd_defx": "snd_def",
	"snd_hit_fire": "snd_mfdjx",
	"snd_hit_ice": "snd_mfdjx",
	"snd_hit_dian": "snd_mfdjx"
}


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	for i: int in range(8):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)


func play_music(path: String, volume_db: float = -6.0) -> void:
	if current_music == path:
		return

	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("Music not found: " + path)
		return

	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	current_music = path
	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()


func play_sfx(path: String, volume_db: float = -2.0) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("SFX not found: " + path)
		return

	var player: AudioStreamPlayer = get_free_sfx_player()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func get_free_sfx_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in sfx_pool:
		if not p.playing:
			return p
	return sfx_player


func play_effect_sfx(sound_id: String, volume_db: float = -2.0) -> void:
	if sound_id == "":
		return

	var candidates: Array[String] = [
		EFFECT_SFX_DIR + sound_id + EFFECT_SFX_EXT
	]
	if EFFECT_SFX_FALLBACK.has(sound_id):
		var fb: String = String(EFFECT_SFX_FALLBACK[sound_id])
		candidates.append(EFFECT_SFX_DIR + fb + EFFECT_SFX_EXT)

	for path: String in candidates:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			play_sfx(path, volume_db)
			return

	print("Effect SFX missing:", sound_id, "（需要继续从原版 effect.xfl 的 soundDataHRef 导出/转码）")


func snd_select() -> void:
	play_sfx("res://assets/sfx/snd_menu1.mp3")


func snd_confirm() -> void:
	play_sfx("res://assets/sfx/snd_menu2.mp3")


func snd_menu_open() -> void:
	play_sfx("res://assets/sfx/snd_menu5.mp3")


func stop_music() -> void:
	current_music = ""
	music_player.stop()
