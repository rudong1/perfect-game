extends Control
## The two girls touch one palm through the mirror; the farewell recalls it.

const NEXT_SCENE := "res://scenes/gameplay/gameplay.tscn"
const STORY_LINES := [
	"镜面会慢半拍。你抬手，镜中的人也跟着抬手；你向前，它也向前。",
	"只有一件事对不上：偶尔，它会先停下来，回头看你一眼。",
	"「{name}。」\n有人在镜子里叫出了你的名字，用的却是你自己的声音。\n「别怕，跟着我。走不出去的地方，我陪你试。」",
	"她把手贴上镜面，镜光渐渐遮住了她原来的模样。\n「从今天起，我就是你的倒影。」",
]

@onready var gate: Sprite2D = $Gate
@onready var caption: Label = $Caption
@onready var fade: ColorRect = $Fade

var _gate_material: ShaderMaterial
var _entering := false
var _armed := false
var _clock := 0.0
var story_index := 0
var _prompt: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_material = gate.material as ShaderMaterial
	var photo := $Photo as Sprite2D
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/restricted_art.gdshader")
	photo.material = palette
	var source_size := photo.texture.get_size()
	var cover := maxf(1920.0 / source_size.x, 1080.0 / source_size.y)
	photo.scale = Vector2.ONE * cover
	gate.scale = photo.scale
	# This is not the mirror world yet; keep M from flipping the frame.
	var mirror := get_node_or_null("/root/MirrorState")
	if mirror != null:
		mirror.set("input_enabled", false)
		mirror.call("set_mirrored", false)
	caption.modulate.a = 1.0
	fade.color = Color(0, 0, 0, 0)
	var shade := ColorRect.new()
	shade.position = Vector2(0, 790)
	shade.size = Vector2(1920, 290)
	shade.color = Color(0.02, 0.025, 0.035, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_child(shade, caption.get_index())
	caption.position = Vector2(200, 822)
	caption.size = Vector2(1520, 150)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.add_theme_font_size_override("font_size", 28)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt = Label.new()
	_prompt.position = Vector2(1340, 1005)
	_prompt.size = Vector2(380, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.modulate = Color("#B6B7BD")
	add_child(_prompt)
	_show_story_line()
	# Swallow any stray input from the scene handover before listening.
	await get_tree().create_timer(0.7).timeout
	_armed = true


func _process(delta: float) -> void:
	if _entering:
		return
	_clock += delta
	# The glass breathes so the mirror reads as alive rather than a still frame.
	_gate_material.set_shader_parameter("ripple", 0.30 + 0.12 * sin(_clock * 1.3))

	if not _armed:
		return
	# Nothing polled here on purpose: a polled action picks up stray input from
	# the scene handover and skips the prologue. Input arrives via _unhandled_input.


func _unhandled_input(event: InputEvent) -> void:
	if not _armed or _entering:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_advance_story()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_story()


func _show_story_line() -> void:
	caption.text = get_node("/root/GameState").format_story(STORY_LINES[story_index])
	_prompt.text = "Enter / 点击继续  %d / %d" % [story_index + 1, STORY_LINES.size()]

func _advance_story() -> void:
	if story_index + 1 < STORY_LINES.size():
		story_index += 1
		_show_story_line()
	else:
		_enter()


func _enter() -> void:
	if _entering:
		return
	_entering = true
	caption.text = ""
	_prompt.visible = false
	_gate_material.set_shader_parameter("ripple", 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(gate, "modulate:a", 1.0, 0.7)
	tween.tween_property(fade, "color:a", 1.0, 0.9).set_delay(0.45)
	await get_tree().create_timer(1.4).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)
