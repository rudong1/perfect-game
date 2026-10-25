extends Node
## Run state for the four-world color journey.
##
## Black/white -> red -> blue -> green. Only three pickups fill the HUD prism.

signal changed
signal checkpoint_saved(position: Vector2)

const MAX_LEVELS := 4
const COLOR_COUNT := 3
const SAVE_VERSION := 7
const SAVE_PATH := "user://mirror_save.cfg"
const GAME_TITLE := "镜尽余色"

const LEVELS := [
	{
		"title": "无色 · 双生门廊",
		"objective": "折返、换面、再折返，完成三段双板接力，找到红色。",
		"story_before": "「跟着我，{name}。从今天起，我就是你的倒影。」",
		"color_name": "红色",
		"collect_color": Color("#FF637E"),
		"bg_top": Color("#08090C"),
		"bg_bottom": Color("#1C1F26"),
		"accent": Color("#C8CDD6"),
		"platform": Color("#363A42"),
		"edge": Color("#A8AEB8"),
		"light_color": Color("#DCE4F2"),
		"light_dir": -1.0,
		"saturation": 0.18,
		"fog": 0.0,
	},
	{
		"title": "赤 · 推镜廊",
		"objective": "先解双板栅门，再校准两次镜印，完成去程与回程的穿镜。",
		"story_before": "红光照暖了石墙，却仍穿过她的掌心。「也许，等颜色全部回来就好了。」",
		"color_name": "蓝色",
		"collect_color": Color("#59CFFF"),
		"bg_top": Color("#1A070D"),
		"bg_bottom": Color("#451824"),
		"accent": Color("#E8556D"),
		"platform": Color("#562430"),
		"edge": Color("#E08CA0"),
		"light_color": Color("#FF6E86"),
		"light_dir": -1.0,
		"saturation": 1.15,
		"fog": 0.0,
	},
	{
		"title": "青 · 三色回响",
		"objective": "让影子开启三枚封印，带她穿镜接通三色，再以双板接力打开出口。",
		"story_before": "「听说镜门只记得活人的颜色。」她低下头，又说：「我们先把它们找回来。」",
		"color_name": "绿色",
		"collect_color": Color("#73E2A5"),
		"bg_top": Color("#04101F"),
		"bg_bottom": Color("#103B5C"),
		"accent": Color("#8CC8F5"),
		"platform": Color("#1E4566"),
		"edge": Color("#7FB6E8"),
		"light_color": Color("#6FB4FF"),
		"light_dir": -1.0,
		"saturation": 1.05,
		"fog": 0.10,
	},
	{
		"title": "翠 · 最后的同行",
		"objective": "从双板同行，到影印光闸与共同穿镜，最后再次和她一起打开出口。",
		"story_before": "门后的光照亮了你。她也伸出手，掌心却仍旧是空白。",
		"color_name": "",
		"collect_color": Color("#73E2A5"),
		"bg_top": Color("#0A1811"),
		"bg_bottom": Color("#174C34"),
		"accent": Color("#A8E8BE"),
		"platform": Color("#215439"),
		"edge": Color("#8CD4A4"),
		"light_color": Color("#7CFFB0"),
		"light_dir": 1.0,
		"saturation": 1.0,
		"fog": 0.22,
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
var ending_reached := false
var offered_mask := 0
var darksky_revived := false

func _ready() -> void:
	# Keep the internal project/save identity stable while renaming the game.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(GAME_TITLE)

func begin_game(name: String) -> void:
	end_light_puzzle()
	player_name = name.strip_edges() if not name.strip_edges().is_empty() else "无名"
	current_level = 0
	completed_levels = 0
	collected_mask = 0
	ending_reached = false
	offered_mask = 0
	darksky_revived = false
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
	return current_level >= MAX_LEVELS and ending_reached

func is_finale_pending() -> bool:
	return current_level >= MAX_LEVELS and not ending_reached

func has_offered_colors() -> bool:
	return offered_mask == 7

func offer_colors() -> bool:
	if current_level < MAX_LEVELS or collected_mask != 7 or has_offered_colors():
		return false
	# Spend the collected colours once. Keep a separate record so a save made
	# during the transformation resumes it without granting or spending twice.
	offered_mask = collected_mask
	collected_mask = 0
	_save_game()
	changed.emit()
	return true

func revive_darksky() -> bool:
	if not has_offered_colors() or darksky_revived:
		return false
	darksky_revived = true
	_save_game()
	changed.emit()
	return true

func complete_journey() -> void:
	if current_level < MAX_LEVELS or not darksky_revived:
		return
	ending_reached = true
	_save_game()
	changed.emit()

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
	# The new reunion restores her own face and includes the embrace. Older
	# completed rescues resume there, retaining the gift instead of spending twice.
	ending_reached = bool(config.get_value("game", "ending_reached", false)) if version >= SAVE_VERSION else false
	collected_mask = int(config.get_value("game", "collected_mask", (1 << mini(current_level, COLOR_COUNT)) - 1)) & 7
	offered_mask = int(config.get_value("game", "offered_mask", 0)) & 7 if version >= 6 else 0
	darksky_revived = bool(config.get_value("game", "darksky_revived", false)) and has_offered_colors() if version >= 6 else false
	if has_offered_colors():
		collected_mask = 0
	ending_reached = ending_reached and darksky_revived
	checkpoint_level = int(config.get_value("game", "checkpoint_level", -1)) if version >= 4 else -1
	checkpoint_position = config.get_value("game", "checkpoint_position", Vector2.ZERO) if version >= 4 else Vector2.ZERO
	checkpoint_stage = int(config.get_value("game", "checkpoint_stage", 0)) if version >= 4 else 0
	has_checkpoint = bool(config.get_value("game", "has_checkpoint", false)) if version >= 4 else false
	if version < 6 and current_level < 2:
		has_checkpoint = false
		checkpoint_stage = 0
	if version < SAVE_VERSION and current_level in [2, 3]:
		has_checkpoint = false
		checkpoint_stage = 0
	end_light_puzzle()
	changed.emit()
	return true

func _save_game() -> void:
	var config := ConfigFile.new()
	for key in ["player_name", "current_level", "completed_levels", "collected_mask", "checkpoint_stage", "checkpoint_level", "checkpoint_position", "has_checkpoint", "ending_reached", "offered_mask", "darksky_revived"]:
		config.set_value("game", key, get(key))
	config.set_value("game", "version", SAVE_VERSION)
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
