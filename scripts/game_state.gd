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
		"title": "无色 · 在镜像中等一等",
		"objective": "M 翻转到另一面，让影子踩住「影子踏板」，找到第一片红色。",
		"story_before": "世界还只有黑白。她向前走，影子晚一步才跟上。",
		"color_name": "红色",
		"collect_color": Color("#ff637e"),
		"bg_top": Color("#090909"),
		"bg_bottom": Color("#1b1b1b"),
		"accent": Color("#d5d5d5"),
		"platform": Color("#232323"),
		"edge": Color("#d5d5d5"),
	},
	{
		"title": "赤 · 与影子回头",
		"objective": "先向右越过踏板，再回头；你踩「本体」，影子晚一步踩「影子」，找到蓝色。",
		"story_before": "红色回到了房间的边缘。蓝色还藏在她们的回声里。",
		"color_name": "蓝色",
		"collect_color": Color("#59cfff"),
		"bg_top": Color("#16090f"),
		"bg_bottom": Color("#371722"),
		"accent": Color("#f19aa8"),
		"platform": Color("#20242b"),
		"edge": Color("#f19aa8"),
	},
	{
		"title": "青 · 换一面同行",
		"objective": "影子先踩第一块踏板，再按 M 换面踩亮第二块，找到绿色。",
		"story_before": "蓝色像夜雨一样漫进镜面。绿色在下一次翻转之后。",
		"color_name": "绿色",
		"collect_color": Color("#73e2a5"),
		"bg_top": Color("#06111c"),
		"bg_bottom": Color("#102e45"),
		"accent": Color("#8cc6e0"),
		"platform": Color("#20242b"),
		"edge": Color("#8cc6e0"),
	},
	{
		"title": "翠 · 走出镜面",
		"objective": "和影子完成上下两次配合，穿过绿色世界的出口。",
		"story_before": "最后一种颜色已经回来。她和影子沿着绿色的光继续向前。",
		"color_name": "",
		"collect_color": Color("#a5dfb4"),
		"bg_top": Color("#07140f"),
		"bg_bottom": Color("#16382b"),
		"accent": Color("#9ac4aa"),
		"platform": Color("#20242b"),
		"edge": Color("#9ac4aa"),
	},
]

var player_name := "无名"
var current_level := 0
var completed_levels := 0
var collected_mask := 0
var checkpoint_level := -1
var checkpoint_position := Vector2.ZERO
var has_checkpoint := false

func begin_game(name: String) -> void:
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
	checkpoint_position = Vector2.ZERO
	_save_game()
	changed.emit()

func save_checkpoint(level_index: int, position: Vector2) -> void:
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
	checkpoint_level = int(config.get_value("game", "checkpoint_level", -1)) if version >= 2 else -1
	checkpoint_position = config.get_value("game", "checkpoint_position", Vector2.ZERO) if version >= 2 else Vector2.ZERO
	has_checkpoint = bool(config.get_value("game", "has_checkpoint", false)) if version >= 2 else false
	changed.emit()
	return true

func _save_game() -> void:
	var config := ConfigFile.new()
	for key in ["player_name", "current_level", "completed_levels", "collected_mask", "checkpoint_level", "checkpoint_position", "has_checkpoint"]:
		config.set_value("game", key, get(key))
	config.set_value("game", "version", 2)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not write save file (error %d)" % err)

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	checkpoint_level = -1
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
