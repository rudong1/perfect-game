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
		"title": "第一星 · 双生门廊",
		"objective": "M 翻转重力；先向右再回头，借分身惯性同时压住上下两板。",
		"story_before": "五颗星沉进镜面。{name}的回声不再只是一道影子。",
		"story_after": "第一颗星醒来。她学会等另一个自己慢半拍。",
		"bg_top": Color("#05070c"),
		"bg_bottom": Color("#1a1e25"),
		"accent": Color("#e8eef8"),
		"platform": Color("#252a33"),
		"edge": Color("#cbd5e5"),
		"hazard": Color("#f4f7fb"),
		"ray": Color("#ffffff"),
	},
	{
		"title": "第二星 · 推镜廊",
		"objective": "A/D 推立镜到绿色刻度（1040–1120），E 穿镜；跨过缺口到高台。",
		"story_before": "镜面在哪里，出口就在哪里；光也会被镜面挡住。",
		"story_after": "第二颗星醒来，赤色沿着镜面的边缘流动。",
		"bg_top": Color("#130406"),
		"bg_bottom": Color("#3a0d16"),
		"accent": Color("#ff5c71"),
		"platform": Color("#2a1015"),
		"edge": Color("#ff9aa7"),
		"hazard": Color("#ffd9df"),
		"ray": Color("#ff5c71"),
	},
	{
		"title": "第三星 · 三色回响",
		"objective": "靠近红镜按 M → 推立镜越过绿镜 → M → E 穿镜、走到蓝镜 → M。",
		"story_before": "一次翻转只转动近处的一面光镜。三束光必须同时抵达接收器。",
		"story_after": "第三颗星醒来。两色曾经接近答案，三色终于共鸣。",
		"bg_top": Color("#030b16"),
		"bg_bottom": Color("#0a2438"),
		"accent": Color("#51c8ff"),
		"platform": Color("#0b2232"),
		"edge": Color("#9be8ff"),
		"hazard": Color("#d7f6ff"),
		"ray": Color("#51c8ff"),
	},
	{
		"title": "第四星 · 双生回响",
		"objective": "先借分身同时压双板，再将红绿蓝三束光全部送达。",
		"story_before": "回声留住门的记忆，光却必须此刻仍然亮着。",
		"story_after": "第四颗星醒来，翠色从她和回声之间生长。",
		"bg_top": Color("#04120a"),
		"bg_bottom": Color("#0d2d18"),
		"accent": Color("#69e39d"),
		"platform": Color("#0f2417"),
		"edge": Color("#a7ffca"),
		"hazard": Color("#d9ffe6"),
		"ray": Color("#69e39d"),
	},
	{
		"title": "第五星 · 沉星归途",
		"objective": "完成一次 E 镜像传送，并保持三色光路畅通，走向最后的星。",
		"story_before": "五颗沉星的名字，只在镜中读得清。",
		"story_after": "最后一颗星浮出镜面。她和另一个自己，把光带回家。",
		"bg_top": Color("#07141b"),
		"bg_bottom": Color("#123746"),
		"accent": Color("#f4fbff"),
		"platform": Color("#1a2b35"),
		"edge": Color("#f3fbff"),
		"hazard": Color("#ffffff"),
		"ray": Color("#ffffff"),
	},
]

var light_puzzle_active := false
var light_channels := 0

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
	end_light_puzzle()
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


func begin_light_puzzle() -> void:
	light_puzzle_active = true
	light_channels = 0


func set_light_channels(mask: int) -> void:
	light_channels = mask & 7


func end_light_puzzle() -> void:
	light_puzzle_active = false
	light_channels = 0


func colored_rays() -> Array[Color]:
	if light_puzzle_active:
		var active: Array[Color] = []
		var rgb := [Color("#ff5c71"), Color("#69e39d"), Color("#51c8ff")]
		for i in 3:
			if light_channels & (1 << i):
				active.append(rgb[i])
		return active
	# Level 0 is the white beam. Red/blue/green are added by levels 1-3.
	var rays: Array[Color] = []
	for level_index in range(1, mini(completed_levels, 4)):
		rays.append(LEVELS[level_index].ray)
	return rays


func has_rainbow() -> bool:
	return light_channels == 7 if light_puzzle_active else completed_levels >= MAX_LEVELS


func restored_channel_count() -> int:
	if light_puzzle_active:
		return int(bool(light_channels & 1)) + int(bool(light_channels & 2)) + int(bool(light_channels & 4))
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
