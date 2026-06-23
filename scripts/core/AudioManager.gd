extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var current_music: String = ""
var master_volume_percent: float = 100.0

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
	"snd_hit_ice": "snd_mfdjx"
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

	apply_master_volume_to_bus()


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


func play_character_sfx(character_id: String, sound_id: String, volume_db: float = -2.0) -> void:
	# Step118：角色私有音效增强查找。
	# 原版 XFL 时间轴使用 soundName="声音/sound_0016"；
	# FFDec/本地导出可能保存成 sound_0016.mp3、0016.mp3、16.mp3，或带 linkage 前缀如 1_snd_hurt1.mp3。
	# 这里只在角色自己的 assets/sfx/<character_id>/ 下查找，不回退到 Aizen，避免混用角色音效。
	if character_id == "" or sound_id == "":
		return

	var id: String = character_id.to_lower()
	var bases: Array[String] = [sound_id]

	if sound_id.begins_with("sound_"):
		var suffix: String = sound_id.substr(6)
		bases.append(suffix)
		var numeric_value: int = int(suffix)
		if numeric_value > 0:
			bases.append(str(numeric_value))
			bases.append("sound_" + str(numeric_value))

	var exts: Array[String] = [".ogg", ".mp3", ".wav"]
	for base in bases:
		for ext in exts:
			var path: String = "res://assets/sfx/" + id + "/" + base + ext
			if ResourceLoader.exists(path) or FileAccess.file_exists(path):
				play_sfx(path, volume_db)
				return

	# 最后扫描目录：用于兼容 1_snd_hurt1.mp3、xxx_sound_0016.mp3 这类 FFDec 导出名。
	var dir_path: String = "res://assets/sfx/" + id
	var dir := DirAccess.open(dir_path)
	if dir != null:
		dir.list_dir_begin()
		while true:
			var file_name: String = dir.get_next()
			if file_name == "":
				break
			if dir.current_is_dir():
				continue
			var lower_name: String = file_name.to_lower()
			if lower_name.ends_with(".import"):
				continue
			var matched: bool = false
			for base in bases:
				var b: String = str(base).to_lower()
				if lower_name.get_basename() == b or lower_name.contains(b):
					matched = true
					break
			if matched:
				play_sfx(dir_path + "/" + file_name, volume_db)
				dir.list_dir_end()
				return
		dir.list_dir_end()

	print("Character SFX missing:", id, "/", sound_id)




func snd_select() -> void:
	play_sfx("res://assets/sfx/snd_menu1.mp3")


func snd_confirm() -> void:
	play_sfx("res://assets/sfx/snd_menu2.mp3")


func snd_menu_open() -> void:
	play_sfx("res://assets/sfx/snd_menu5.mp3")



func set_master_volume_percent(percent: float) -> void:
	master_volume_percent = clampf(percent, 0.0, 100.0)
	apply_master_volume_to_bus()


func get_master_volume_percent() -> float:
	return master_volume_percent


func apply_master_volume_to_bus() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		bus_idx = 0
	if master_volume_percent <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume_percent / 100.0))


func stop_music() -> void:
	current_music = ""
	music_player.stop()
