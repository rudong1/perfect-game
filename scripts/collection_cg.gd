extends CanvasLayer
## A modal memory after each real pickup, above the mirrored world and HUD.
signal finished

const ART := [
	preload("res://assets/backgrounds/collect_red.png"),
	preload("res://assets/backgrounds/collect_blue.png"),
	preload("res://assets/backgrounds/collect_green.png"),
]
const CAPTIONS := [
	"红色在你掌心苏醒。\n她站在身后，没有笑。",
	"蓝光越过指尖，落进水里。\n你望着光，她望着你。",
	"你把最后一枚颜色护在胸前。\n回廊深处，她的目光久久没有移开。",
]
const MIN_VIEW_SECONDS := 1.8
const FADE_IN_SECONDS := 0.55

var active := false
var armed := false
var art_index := -1
var _clock := 0.0
var _closing := false
var _owns_pause := false
var _surface: Control
var _art: TextureRect
var _heading: Label
var _caption: Label
var _continue: Button
var _rule: ColorRect

func _ready() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(black)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/restricted_art.gdshader")
	_art.material = palette
	_surface.add_child(_art)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -230
	shade.color = Color(0.018, 0.022, 0.03, 0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(shade)
	_rule = ColorRect.new()
	_rule.position = Vector2(100, 880)
	_rule.size = Vector2(72, 2)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_rule)
	_heading = _label(Vector2(100, 895), Vector2(1400, 48), 30)
	_caption = _label(Vector2(100, 950), Vector2(1390, 90), 24)
	_continue = Button.new()
	_continue.text = "Enter / 点击继续"
	_continue.position = Vector2(1560, 966)
	_continue.size = Vector2(260, 60)
	_continue.add_theme_font_size_override("font_size", 21)
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.pressed.connect(_dismiss)
	_surface.add_child(_continue)
	_surface.hide()
	set_process(false)
	set_process_input(false)

func _label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color("#E8E3D3")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(label)
	return label

func show_color(index: int) -> void:
	if active or index < 0 or index >= ART.size():
		return
	art_index = index
	var data: Dictionary = get_node("/root/GameState").get_level(index)
	_art.texture = ART[index]
	_heading.text = "拾得 · " + data.color_name
	_heading.modulate = data.collect_color
	_caption.text = CAPTIONS[index]
	_rule.color = data.collect_color
	_clock = 0.0
	_closing = false
	armed = false
	active = true
	_continue.hide()
	_surface.modulate.a = 0.0
	_surface.show()
	# Stop the whole room, including collisions, echo trails and readable hints.
	# This layer alone keeps processing and accepts a fresh Enter / left click.
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	set_process(true)
	set_process_input(true)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_surface, "modulate:a", 1.0, FADE_IN_SECONDS)

func _process(delta: float) -> void:
	if _closing:
		return
	_clock += delta
	if not armed and _clock >= MIN_VIEW_SECONDS:
		armed = true
		_continue.show()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed:
		if not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dismiss()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	if not active or not armed or _closing:
		return
	_closing = true
	_continue.hide()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_surface, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_finish)

func _finish() -> void:
	active = false
	armed = false
	_surface.hide()
	set_process(false)
	set_process_input(false)
	_release_pause()
	finished.emit()

func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false

func _exit_tree() -> void:
	_release_pause()
