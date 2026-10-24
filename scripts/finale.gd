extends Node2D
## The reflection leaves the opposite side. Escape, break the mirror, say goodbye.
enum Phase { BETRAYAL, CHASE, SHATTER, FAREWELL }
const HERO = preload("res://scenes/player/player.tscn")
const FRAMES = preload("res://assets/characters/hero/hero_frames.tres")
const GIANT_MIRROR = preload("res://scripts/final_mirror.gd")
const CORRIDOR_WIDTH := 3600.0
const MIRROR_X := 3120.0
const PURSUIT_SPEED := 205.0
const PLAYER_START := Vector2(350, 900)
const SHADOW_START := Vector2(130, 900)
const FAREWELL_LINES := ["也许，这也算是不错的告别吧。", "……对了，我叫 darksky。"]
var phase := Phase.BETRAYAL
var player: CharacterBody2D
var shadow: Node2D
var mirror_body: Node2D
var camera: Camera2D
var attempts := 0
var farewell_index := 0
var _state: Node
var _clock := 0.0
var _pursuit_speed := PURSUIT_SPEED
var _sprite: AnimatedSprite2D
var _ghosts: Array[Sprite2D] = []
var _dialogue: Panel
var _caption: Label
var _speaker: Label
var _objective: Label
var _next: Button
var _flash: ColorRect

func _ready() -> void:
	_state = get_node("/root/GameState")
	var mirror := get_node("/root/MirrorState")
	mirror.input_enabled = false
	mirror.set_mirrored(false)
	_state.end_light_puzzle()
	_build_world()
	_build_actors()
	_build_ui()
	_caption.text = "「对不起。我等得太久了。」\n「把那些颜色给我。这一次，该轮到我出去了。」"
	_objective.text = "她站到了你的身后。按 D / → 向右逃跑，Shift 可以冲刺。"

func _build_world() -> void:
	var background_layer := CanvasLayer.new()
	background_layer.layer = -10
	add_child(background_layer)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/level_backdrop.gdshader")
	material.set_shader_parameter("scene_texture", preload("res://assets/backgrounds/church_green.png"))
	material.set_shader_parameter("use_scene_texture", true)
	material.set_shader_parameter("light_color", Color("#C8CDD6"))
	material.set_shader_parameter("fog_amount", 0.25)
	background.material = material
	background_layer.add_child(background)
	for y in [0.0, 900.0]:
		var body := StaticBody2D.new()
		body.position = Vector2(0, y)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(CORRIDOR_WIDTH, 180)
		collision.shape = shape
		collision.position = shape.size * 0.5
		body.add_child(collision)
		add_child(body)
	mirror_body = Node2D.new()
	mirror_body.name = "FinalMirror"
	mirror_body.set_script(GIANT_MIRROR)
	mirror_body.position = Vector2(MIRROR_X, 900)
	add_child(mirror_body)
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)

func _build_actors() -> void:
	player = HERO.instantiate()
	player.position = PLAYER_START
	add_child(player)
	player.set_respawn_position(player.position)
	player.set_physics_process(false)
	shadow = Node2D.new()
	shadow.name = "PursuingReflection"
	shadow.position = SHADOW_START
	shadow.z_index = 1
	add_child(shadow)
	for i in 2:
		var ghost := Sprite2D.new()
		ghost.centered = false
		ghost.offset = Vector2(-160, -342)
		ghost.scale = Vector2(0.62, 0.62)
		ghost.position.x = -30.0 * (i + 1)
		ghost.modulate = Color(0.55, 0.65, 0.72, 0.20 - i * 0.06)
		shadow.add_child(ghost)
		_ghosts.append(ghost)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.centered = false
	_sprite.offset = Vector2(-160, -342)
	_sprite.scale = Vector2(0.62, 0.62)
	var tint := ShaderMaterial.new()
	tint.shader = preload("res://shaders/shadow_tint.gdshader")
	_sprite.material = tint
	_sprite.modulate = Color(0.7, 0.8, 0.9, 0.95)
	_sprite.play("idle")
	shadow.add_child(_sprite)

func _label(parent: Node, point: Vector2, size: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.size = size
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var top := ColorRect.new()
	top.size = Vector2(1920, 155)
	top.color = Color(0.025, 0.03, 0.035, 0.9)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var progress := Control.new()
	progress.position = Vector2(48, 26)
	progress.set_script(preload("res://scripts/color_progress.gd"))
	layer.add_child(progress)
	_label(layer, Vector2(380, 24), Vector2(1400, 50), "终幕 · 倒影越界", 34)
	_objective = _label(layer, Vector2(70, 96), Vector2(1770, 45), "", 23)
	_dialogue = Panel.new()
	_dialogue.position = Vector2(320, 190)
	_dialogue.size = Vector2(1280, 205)
	layer.add_child(_dialogue)
	_speaker = _label(_dialogue, Vector2(32, 16), Vector2(1150, 35), "那个与你同行的女孩", 20)
	_speaker.modulate = Color("#B8C8D5")
	_caption = _label(_dialogue, Vector2(32, 64), Vector2(1200, 100), "", 28)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next = Button.new()
	_next.position = Vector2(1050, 150)
	_next.size = Vector2(190, 42)
	_next.text = "继续"
	_next.visible = false
	_next.pressed.connect(_advance_farewell)
	_dialogue.add_child(_next)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.8, 0.9, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

func _physics_process(delta: float) -> void:
	_clock += delta
	match phase:
		Phase.BETRAYAL:
			if _clock > 0.65 and Input.is_action_pressed("move_right"):
				_start_chase()
		Phase.CHASE:
			_pursuit_speed = maxf(PURSUIT_SPEED, player.velocity.x * 0.90)
			shadow.position.x += _pursuit_speed * delta
			if shadow.position.x >= player.position.x - 58 and absf(player.position.y - 900) < 165:
				_retry()
			elif player.position.x >= MIRROR_X - 170 and Input.get_axis("move_left", "move_right") > 0:
				_break_mirror()
		Phase.SHATTER:
			shadow.modulate.a = maxf(0, 1.0 - _clock / 0.8)
			_flash.color.a = maxf(0, 0.55 - _clock * 2.4)
			camera.offset = Vector2(sin(_clock * 90) * 9, cos(_clock * 74) * 5) * maxf(0, 1 - _clock * 3)
			if _clock > 1.0:
				_show_farewell()
	camera.position.x = clampf(player.position.x, 960, CORRIDOR_WIDTH - 960)

func _process(_delta: float) -> void:
	if phase == Phase.CHASE:
		var animation := "sprint" if _pursuit_speed > 265 else "run"
		HeroAnimation.play(_sprite, animation)
		_sprite.speed_scale = HeroAnimation.cadence(animation, _pursuit_speed)
	for ghost in _ghosts:
		ghost.texture = FRAMES.get_frame_texture(_sprite.animation, _sprite.frame)

func _start_chase() -> void:
	phase = Phase.CHASE
	_clock = 0
	_dialogue.visible = false
	player.set_physics_process(true)
	_objective.text = "向右跑！前方的巨大镜面，挡住了唯一的出口。"

func _retry() -> void:
	attempts += 1
	phase = Phase.BETRAYAL
	_clock = 0
	player.respawn()
	player.set_physics_process(false)
	shadow.position = SHADOW_START
	shadow.visible = true
	shadow.modulate.a = 1
	camera.offset = Vector2.ZERO
	_flash.color.a = 0
	mirror_body.reset()
	_sprite.play("idle")
	_dialogue.visible = true
	_speaker.text = "镜面把这一刻重新交还给你"
	_caption.text = "她差一点夺走了颜色。\n这一次，别停下脚步。"
	_next.visible = false
	_objective.text = "按 D / → 向右重试，Shift 冲刺。已经找到的颜色会保留。"

func _break_mirror() -> void:
	if phase != Phase.CHASE and phase != Phase.BETRAYAL:
		return
	phase = Phase.SHATTER
	_clock = 0
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player._play("push")
	mirror_body.shatter()
	_dialogue.visible = false
	_objective.text = "巨镜碎裂。身后的倒影，也随着裂纹消失了。"

func _show_farewell() -> void:
	phase = Phase.FAREWELL
	camera.offset = Vector2.ZERO
	shadow.visible = false
	player._play("idle")
	_dialogue.visible = true
	_speaker.text = "碎镜中传来的声音"
	farewell_index = 0
	_caption.text = FAREWELL_LINES[0]
	_next.text = "继续"
	_next.visible = true
	_objective.text = "你保住了颜色。镜面后，只剩最后一句话。"

func _advance_farewell() -> void:
	if phase != Phase.FAREWELL:
		return
	if farewell_index + 1 < FAREWELL_LINES.size():
		farewell_index += 1
		_caption.text = FAREWELL_LINES[farewell_index]
		_speaker.text = "她终于说出了自己的名字"
		_next.text = "离开镜面"
	else:
		_state.complete_journey()
		get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if OS.is_debug_build() and event.is_action_pressed("developer_skip"):
		_break_mirror()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_room") and phase != Phase.FAREWELL:
		_retry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and phase == Phase.FAREWELL:
		_advance_farewell()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 900, CORRIDOR_WIDTH, 180), Color("#293933"))
	draw_rect(Rect2(0, 0, CORRIDOR_WIDTH, 180), Color("#222B29"))
	draw_line(Vector2(0, 900), Vector2(CORRIDOR_WIDTH, 900), Color("#B7C5BD"), 4)
	for i in 12:
		draw_line(Vector2(i * 300, 920), Vector2(i * 300, 1080), Color(0.7, 0.8, 0.75, 0.13), 1)
