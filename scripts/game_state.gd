extends Node
## Global run state for the five-mirror journey.
##
## Each level is a single 1920x1080 room. Completing a room adds one band to
## the prism progress screen; after the fifth room the ending unlocks.

signal changed
signal checkpoint_saved(position: Vector2)

const MAX_LEVELS := 5
const SAVE_PATH := "user://mirror_save.cfg"

const LEVELS := [
	{
		"title": "第一镜 · 无色",
		"objective": "在倒影里找到桥，踩亮倒影踏板。",
		"story_before": "{name}在无色的房间里醒来。镜面里没有她的影子，只有一束白光。",
		"story_after": "她第一次看见：桥不在现实里，而在倒影里。",
		"bg_top": Color("#05070c"),
		"bg_bottom": Color("#1a1e25"),
		"accent": Color("#e8eef8"),
		"platform": Color("#252a33"),
		"edge": Color("#cbd5e5"),
		"hazard": Color("#f4f7fb"),
		"ray": Color("#ffffff"),
	},
	{
		"title": "第二镜 · 赤",
		"objective": "两扇门在两种倒影里换边，找到通过的时机。",
		"story_before": "赤色的房间像一颗缓慢跳动的心。门在现实与倒影之间换边。",
		"story_after": "她拾起第一片暖色：赤。",
		"bg_top": Color("#130406"),
		"bg_bottom": Color("#3a0d16"),
		"accent": Color("#ff5c71"),
		"platform": Color("#2a1015"),
		"edge": Color("#ff9aa7"),
		"hazard": Color("#ffd9df"),
		"ray": Color("#ff5c71"),
	},
	{
		"title": "第三镜 · 青",
		"objective": "倒影桥只在镜中实体；穿过镜雨，踩亮对岸的倒影踏板。",
		"story_before": "倒悬的雨从天花板落下。她学会了在倒影里前行。",
		"story_after": "青色的雨停在她掌心。",
		"bg_top": Color("#030b16"),
		"bg_bottom": Color("#0a2438"),
		"accent": Color("#51c8ff"),
		"platform": Color("#0b2232"),
		"edge": Color("#9be8ff"),
		"hazard": Color("#d7f6ff"),
		"ray": Color("#51c8ff"),
	},
	{
		"title": "第四镜 · 翠",
		"objective": "现实与倒影各有一块踏板；让两片颜色同时亮起。",
		"story_before": "镜中的森林开始生长。两扇门都记得她来过的方向。",
		"story_after": "翠色从裂缝里发芽。",
		"bg_top": Color("#04120a"),
		"bg_bottom": Color("#0d2d18"),
		"accent": Color("#69e39d"),
		"platform": Color("#0f2417"),
		"edge": Color("#a7ffca"),
		"hazard": Color("#d9ffe6"),
		"ray": Color("#69e39d"),
	},
	{
		"title": "终镜 · 虹",
		"objective": "穿过最后一重镜面，走向棱镜。",
		"story_before": "所有颜色都在这里等她。三棱镜的白光第一次有了方向。",
		"story_after": "她伸手，把光抱进怀里。",
		"bg_top": Color("#07141b"),
		"bg_bottom": Color("#123746"),
		"accent": Color("#f4fbff"),
		"platform": Color("#1a2b35"),
		"edge": Color("#f3fbff"),
		"hazard": Color("#ffffff"),
		"ray": Color("#ffffff"),
	},
]

var player_name := "无名"
var current_level := 0
var completed_levels := 0
var checkpoint_level := -1
var checkpoint_position := Vector2.ZERO
var has_checkpoint := false


func begin_game(name: String) -> void:
	player_name = name.strip_edges()
	if player_name.is_empty():
		player_name = "无名"
	current_level = 0
	completed_levels = 0
	checkpoint_level = -1
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
	_delete_save()
	changed.emit()


func get_level(index: int = -1) -> Dictionary:
	return LEVELS[clampi(index if index >= 0 else current_level, 0, MAX_LEVELS - 1)]


func format_story(text: String) -> String:
	return text.replace("{name}", player_name)


func level_completed() -> void:
	completed_levels = mini(completed_levels + 1, MAX_LEVELS)
	current_level = mini(current_level + 1, MAX_LEVELS)
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


func colored_rays() -> Array[Color]:
	# Level 0 is the white beam. Red/blue/green are added by levels 1-3.
	var rays: Array[Color] = []
	for level_index in range(1, mini(completed_levels, 4)):
		rays.append(LEVELS[level_index].ray)
	return rays


func has_rainbow() -> bool:
	return completed_levels >= MAX_LEVELS


func restored_channel_count() -> int:
	return clampi(completed_levels - 1, 0, 3)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_from_disk() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	player_name = str(config.get_value("game", "player_name", "无名"))
	current_level = int(config.get_value("game", "current_level", 0))
	completed_levels = int(config.get_value("game", "completed_levels", 0))
	checkpoint_level = int(config.get_value("game", "checkpoint_level", -1))
	checkpoint_position = config.get_value("game", "checkpoint_position", Vector2.ZERO)
	has_checkpoint = bool(config.get_value("game", "has_checkpoint", false))
	changed.emit()
	return true


func _save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "player_name", player_name)
	config.set_value("game", "current_level", current_level)
	config.set_value("game", "completed_levels", completed_levels)
	config.set_value("game", "checkpoint_level", checkpoint_level)
	config.set_value("game", "checkpoint_position", checkpoint_position)
	config.set_value("game", "has_checkpoint", has_checkpoint)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not write save file %s (error %d)" % [SAVE_PATH, err])


func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func clear_save() -> void:
	_delete_save()
	checkpoint_level = -1
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
