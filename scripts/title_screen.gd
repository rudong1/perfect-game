extends Control
## Gothic start screen: the naming step appears only after choosing to step through,
## then a new journey, continuing a save, or quitting. After the revelation the
## mirror seals itself: both entries stay locked until the player holds M.

const MENU_HINT := "按 Enter 踏入镜中"
const NAMING_HINT := "留空则名为「无名」 · Enter 确认 · Esc 返回"
const NAME_LABEL := "为第一位坠落的少女命名"
const EGG_LABEL := "为你自己命名"
const EGG_NAME := "darksky"
const SEALED_HINT := "你需要按键进入镜面"
const SEALED_HOLD_SECONDS := 1.5
const SEALED_BEGIN := "🔒 踏入镜中"
const SEALED_CONTINUE := "🔒 继续旅程"
const SEALED_HINT_COLOR := Color("#E89595")
const ANOMALY_SHADER := preload("res://shaders/mirror_hollow.gdshader")

@onready var backdrop: TextureRect = $Backdrop
@onready var heading: Label = $MenuPanel/Heading
@onready var name_label: Label = $MenuPanel/NameLabel
@onready var name_edit: LineEdit = $MenuPanel/NameEdit
@onready var begin_button: Button = $MenuPanel/Begin
@onready var confirm_button: Button = $MenuPanel/Confirm
@onready var continue_button: Button = $MenuPanel/Continue
@onready var quit_button: Button = $MenuPanel/Quit
@onready var hint: Label = $MenuPanel/Hint

var _naming := false
var _sealed := false
var _holding := false
var _hold := 0.0
var _anomaly_mat: ShaderMaterial


func _ready() -> void:
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/restricted_art.gdshader")
	backdrop.material = palette
	begin_button.pressed.connect(_open_naming)
	confirm_button.pressed.connect(_commit_name)
	continue_button.pressed.connect(_continue)
	quit_button.pressed.connect(_quit)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.text_changed.connect(_on_name_changed)
	# M is not a mirror toggle while the title is up; the sealed state reuses it.
	var mirror := get_node_or_null("/root/MirrorState")
	if mirror != null:
		mirror.set("input_enabled", false)
	var state := get_node_or_null("/root/GameState")
	if state != null and bool(state.call("has_save")):
		continue_button.visible = true
	_set_naming(false)
	# The seal lives in the save, but honour the live flag too so a failed disk
	# write can never silently drop the player back onto an unlocked menu.
	if state != null and (bool(state.get("mirror_sealed")) or bool(state.call("is_sealed_save"))):
		if bool(state.call("is_sealed_save")):
			# Refresh the HUD progress from the sealed save before locking the menu.
			state.call("load_from_disk")
		_enter_sealed()


func _input(event: InputEvent) -> void:
	if not _sealed:
		return
	if event.is_action_pressed("mirror") and not event.is_echo():
		_holding = true
	elif event.is_action_released("mirror"):
		_holding = false


func _process(delta: float) -> void:
	if not _sealed or _anomaly_mat == null:
		return
	if _holding:
		_hold += delta
	else:
		_hold = maxf(0.0, _hold - delta * 2.2)
	var charge := clampf(_hold / SEALED_HOLD_SECONDS, 0.0, 1.0)
	_anomaly_mat.set_shader_parameter("amount", charge * 0.85)
	if _holding and _hold >= SEALED_HOLD_SECONDS:
		_open_mirror()


func _enter_sealed() -> void:
	_sealed = true
	_naming = false
	heading.text = "镜面紧闭"
	name_label.visible = false
	name_edit.visible = false
	confirm_button.visible = false
	begin_button.visible = true
	begin_button.disabled = true
	begin_button.text = SEALED_BEGIN
	continue_button.visible = true
	continue_button.disabled = true
	continue_button.text = SEALED_CONTINUE
	quit_button.visible = true
	hint.text = SEALED_HINT
	hint.modulate = SEALED_HINT_COLOR
	hint.add_theme_font_size_override("font_size", 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_anomaly()


func _build_anomaly() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MirrorHollow"
	layer.layer = 60
	add_child(layer)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anomaly_mat = ShaderMaterial.new()
	_anomaly_mat.shader = ANOMALY_SHADER
	_anomaly_mat.set_shader_parameter("amount", 0.0)
	rect.material = _anomaly_mat
	layer.add_child(rect)


func _open_mirror() -> void:
	if not _sealed:
		return
	_sealed = false
	_holding = false
	_anomaly_mat.set_shader_parameter("amount", 1.0)
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.call("open_mirror")
	await get_tree().create_timer(0.35).timeout
	get_tree().change_scene_to_file.call_deferred("res://scenes/finale/finale.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _sealed:
		return
	if event.is_action_pressed("ui_accept") and not _naming:
		_open_naming()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if _naming:
		_set_naming(false)
	else:
		_quit()
	get_viewport().set_input_as_handled()


func _open_naming() -> void:
	if _sealed:
		return
	_set_naming(true)
	name_edit.grab_focus()


func _set_naming(value: bool) -> void:
	_naming = value
	heading.text = "镜中姓名" if value else "开始旅程"
	name_label.text = NAME_LABEL
	name_label.visible = value
	name_edit.visible = value
	confirm_button.visible = value
	begin_button.visible = not value
	var state := get_node_or_null("/root/GameState")
	continue_button.visible = not value and state != null and bool(state.call("has_save"))
	quit_button.visible = not value
	hint.text = NAMING_HINT if value else MENU_HINT


func _on_name_submitted(_text: String) -> void:
	if _naming:
		_commit_name()


func _on_name_changed(text: String) -> void:
	if not _naming:
		return
	# Hidden easter egg: typing her true name flips the prompt to "为你自己命名".
	name_label.text = EGG_LABEL if text.strip_edges().to_lower() == EGG_NAME else NAME_LABEL


func _commit_name() -> void:
	if not _naming or _sealed:
		return
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.call("begin_game", name_edit.text)
	# A new journey opens with the prologue, not the first room.
	get_tree().change_scene_to_file("res://scenes/opening/opening.tscn")


func _continue() -> void:
	if _sealed:
		return
	var state := get_node_or_null("/root/GameState")
	if state == null or not bool(state.call("load_from_disk")):
		return
	if state.is_finale_pending():
		get_tree().change_scene_to_file("res://scenes/finale/finale.tscn")
		return
	if state.is_game_complete():
		get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")


func _quit() -> void:
	get_tree().quit()
