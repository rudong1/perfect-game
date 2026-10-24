extends Node
## Run state for the four-world color journey.
##
## Black/white -> red -> blue -> green. Only three pickups fill the HUD prism.

signal changed
signal checkpoint_saved(position: Vector2)

const MAX_LEVELS := 4
const COLOR_COUNT := 3
const SAVE_PATH := "user://mirror_save.cfg"

const LEVELS := [
	{
		"title": "无色 · 双生门廊",
		"objective": "按 M 换面，与晚一步的分身同时压住上下踏板，找到红色。",
		"story_before": "世界还只有黑白。她向前走，影子晚一步才跟上。",
		"color_name": "红色",
		"collect_color": Color("#FF637E"),
		"bg_top": Color("#07080A"),
		"bg_bottom": Color("#15171C"),
		"accent": Color("#C8CDD6"),
		"platform": Color("#2C2F36"),
		"edge": Color("#9AA0AC"),
	},
	{
		"title": "赤 · 推镜廊",
		"objective": "推动立镜改变反射轴，按 E 穿过镜面，找到蓝色。",
		"story_before": "红色回到了房间的边缘。蓝色还藏在她们的回声里。",
		"color_name": "蓝色",
		"collect_color": Color("#59CFFF"),
		"bg_top": Color("#100609"),
		"bg_bottom": Color("#2A1018"),
		"accent": Color("#D97C8C"),
		"platform": Color("#3A1E26"),
		"edge": Color("#C46A80"),
	},
	{
		"title": "青 · 三色回响",
		"objective": "按 M 调整最近的反射镜，并移动立镜避开光路，让三色同时抵达。",
		"story_before": "蓝色像夜雨一样漫进镜面。绿色在下一次翻转之后。",
		"color_name": "绿色",
		"collect_color": Color("#73E2A5"),
		"bg_top": Color("#050B14"),
		"bg_bottom": Color("#0F2A42"),
		"accent": Color("#8CB8DA"),
		"platform": Color("#1E3145"),
		"edge": Color("#7BA8D0"),
	},
	{
		"title": "翠 · 最后的同行",
		"objective": "完成分身配合、推镜传送与三色光路，走出绿色教堂。",
		"story_before": "最后一种颜色已经回来。她和影子沿着绿色的光继续向前。",
		"color_name": "",
		"collect_color": Color("#C9E8A0"),
		"bg_top": Color("#060F0B"),
		"bg_bottom": Color("#123024"),
		"accent": Color("#A3C9B0"),
		"platform": Color("#20402F"),
		"edge": Color("#8FBBA1"),
	},
]

var player_name := "无名"
var current_level := 0
var completed_levels := 0
var collected_mask := 0
var checkpoint_level := -1
var checkpoint_stage := 0
var checkpoint_position := Vector2.ZERO
var has_checkpoint := false
var light_puzzle_active := false
var light_channels := 0

func begin_game(name: String) -> void:
	end_light_puzzle()
	player_name = name.strip_edges() if not name.strip_edges().is_empty() else "无名"
	current_level = 0
	completed_levels = 0
	collected_mask = 0
	clear_save()
	changed.emit()

func get_level(index: int = -1) -> Dictionary:
	return LEVELS[clampi(index if index >= 0 else current_level, 0, MAX_LEVELS - 1)]

func format_story(text: String) -> String:
	return text.replace("{name}", player_name)

func has_color(index: int) -> bool:
	return index >= 0 and index < COLOR_COUNT and bool(collected_mask & (1 << index))

func collected_count() -> int:
	var count := 0
	for i in COLOR_COUNT:
		count += int(has_color(i))
	return count

func collect_current_color() -> bool:
	if current_level >= COLOR_COUNT or has_color(current_level):
		return false
	collected_mask |= 1 << current_level
	_save_game()
	changed.emit()
	return true

func advance_level(skipped: bool = false) -> void:
	if current_level >= MAX_LEVELS or (not skipped and current_level < COLOR_COUNT and not has_color(current_level)):
		return
	current_level += 1
	completed_levels = current_level
	has_checkpoint = false
	checkpoint_level = -1
	checkpoint_stage = 0
	checkpoint_position = Vector2.ZERO
	_save_game()
	changed.emit()

func save_checkpoint(level_index: int, position: Vector2, stage: int = 0) -> void:
	checkpoint_stage = stage
	checkpoint_level = level_index
	checkpoint_position = position
	has_checkpoint = true
	_save_game()
	checkpoint_saved.emit(position)

func is_game_complete() -> bool:
	return current_level >= MAX_LEVELS

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_from_disk() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	player_name = str(config.get_value("game", "player_name", "无名"))
	current_level = clampi(int(config.get_value("game", "current_level", 0)), 0, MAX_LEVELS)
	completed_levels = current_level
	# Old room layouts had different checkpoints. Retain journey progress but
	# place the player at the new room's entrance when migrating an old save.
	var version := int(config.get_value("game", "version", 1))
	collected_mask = int(config.get_value("game", "collected_mask", (1 << mini(current_level, COLOR_COUNT)) - 1)) & 7
	checkpoint_level = int(config.get_value("game", "checkpoint_level", -1)) if version >= 4 else -1
	checkpoint_position = config.get_value("game", "checkpoint_position", Vector2.ZERO) if version >= 4 else Vector2.ZERO
	checkpoint_stage = int(config.get_value("game", "checkpoint_stage", 0)) if version >= 4 else 0
	has_checkpoint = bool(config.get_value("game", "has_checkpoint", false)) if version >= 4 else false
	end_light_puzzle()
	changed.emit()
	return true

func _save_game() -> void:
	var config := ConfigFile.new()
	for key in ["player_name", "current_level", "completed_levels", "collected_mask", "checkpoint_stage", "checkpoint_level", "checkpoint_position", "has_checkpoint"]:
		config.set_value("game", key, get(key))
	config.set_value("game", "version", 4)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not write save file (error %d)" % err)

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	checkpoint_level = -1
	checkpoint_stage = 0
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false

func begin_light_puzzle() -> void:
	light_puzzle_active = true
	light_channels = 0

func end_light_puzzle() -> void:
	light_puzzle_active = false
	light_channels = 0

func set_light_channels(mask: int) -> void:
	light_channels = mask & 7

func has_rainbow() -> bool:
	return light_puzzle_active and light_channels == 7

func restored_channel_count() -> int:
	return int(bool(light_channels & 1)) + int(bool(light_channels & 2)) + int(bool(light_channels & 4))

func colored_rays() -> Array[Color]:
	var rays: Array[Color] = []
	var rgb := [Color("#FF637E"), Color("#73E2A5"), Color("#59CFFF")]
	for i in 3:
		if light_channels & (1 << i):
			rays.append(rgb[i])
	return rays
