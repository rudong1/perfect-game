extends Node2D
## The reflection leaves the opposite side. Escape, break the mirror, say goodbye.
enum Phase { THRESHOLD, CROSSOVER, BETRAYAL, CHASE, SHATTER, FAREWELL, DEPARTURE }
const HERO = preload("res://scenes/player/player.tscn")
const FRAMES = preload("res://assets/characters/hero/hero_frames.tres")
const GIANT_MIRROR = preload("res://scripts/final_mirror.gd")
const BACKDROP = preload("res://scripts/chase_backdrop.gd")
const CORRIDOR_WIDTH := 3600.0
const MIRROR_X := 3120.0
const PURSUIT_SPEED := 205.0
const PLAYER_START := Vector2(350, 900)
const SHADOW_START := Vector2(130, 900)
const FAREWELL_BEATS := [
	{"speaker": "hero", "text": "「刚才……你是真的想把我的颜色夺走吗？」"},
	{"speaker": "reflection", "text": "「是。门亮起来的时候，我以为终于轮到我了。\n可光穿过我的手，我忽然什么都听不见，只剩下害怕。」"},
	{"speaker": "hero", "text": "「我也害怕。可我一直以为，\n身后那个晚半步的脚步声，是在陪着我。」"},
	{"speaker": "reflection", "text": "「那是真的。第一次等到你，第一次有人回头找我……\n那些时候，我真的想和你一起出去。」"},
	{"speaker": "reflection", "text": "「后来，我只顾着不想再被留下，\n竟然想把你也留在这里。……对不起。」"},
	{"speaker": "hero", "text": "「我现在还没办法说没关系。\n但一起走过的那些路，我也不会当作没有发生。」"},
	{"speaker": "reflection", "text": "「嗯。把颜色带走吧。\n别为了等我，错过外面的天亮。」", "opacity": 0.32},
	{"speaker": "hero", "text": "你再次抬起手，贴向那片尚未落下的镜面。\n「那至少告诉我……你的名字。」", "gesture": true, "opacity": 0.24},
	{"speaker": "reflection", "text": "也许，这也算是不错的告别吧。", "gesture": true, "opacity": 0.16},
	{"speaker": "reflection", "text": "……对了，我叫 darksky。", "gesture": true, "opacity": 0.0},
]
const REVELATION_BEATS := [
	{"speaker": "门前", "text": "镜门终于回应了{name}。\n她也伸出手，光却穿过了她的掌心。"},
	{"speaker": "与你同行的女孩", "text": "「原来，回来的只是教堂的颜色。\n我被留在这里太久了……已经不算活着的人。」"},
	{"speaker": "与你同行的女孩", "text": "「门认得你身上的颜色，却认不出我。\n我只剩一道影子了。那面镜子一碎，我也会消失。」"},
	{"speaker": "hero", "text": "「那我们再找一条路。说好一起走的——」"},
	{"speaker": "与你同行的女孩", "text": "「你的颜色，也许能让我重新成为活人。\n我已经等过太多次了……这次，借给我吧。」"},
]
var phase := Phase.THRESHOLD
var player: CharacterBody2D
var shadow: Node2D
var mirror_body: Node2D
var camera: Camera2D
var attempts := 0
var revelation_index := 0
var backdrop: Node2D
var _scene_time := 0.0
var _passage_shown := false
var _veil: ColorRect
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
var _memory: AnimatedSprite2D
var _memory_glass: Polygon2D
var _memory_tween: Tween

func _ready() -> void:
	_state = get_node("/root/GameState")
	var mirror := get_node("/root/MirrorState")
	mirror.input_enabled = false
	mirror.set_mirrored(false)
	_state.end_light_puzzle()
	_build_world()
	_build_actors()
	_build_ui()
	shadow.position = Vector2(PLAYER_START.x - 90, 180)
	shadow.scale.y = -1
	_show_revelation()

func _build_world() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	backdrop = Node2D.new()
	backdrop.name = "ExitAmbulatory"
	backdrop.set_script(BACKDROP)
	backdrop.camera = camera
	backdrop.corridor_width = CORRIDOR_WIDTH
	add_child(backdrop)
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
	# A final image held in a shard, separate from the pursuing actor.
	_memory_glass = Polygon2D.new()
	_memory_glass.position = Vector2(MIRROR_X - 30, 900)
	_memory_glass.polygon = PackedVector2Array([Vector2(-88, 0), Vector2(-84, -187), Vector2(24, -229), Vector2(86, -72), Vector2(56, 0)])
	_memory_glass.color = Color(0.55, 0.66, 0.73, 0.14)
	_memory_glass.visible = false
	add_child(_memory_glass)
	var shard_edge := Line2D.new()
	shard_edge.points = _memory_glass.polygon
	shard_edge.add_point(_memory_glass.polygon[0])
	shard_edge.width = 1.5
	shard_edge.default_color = Color(0.78, 0.85, 0.92, 0.26)
	shard_edge.antialiased = true
	_memory_glass.add_child(shard_edge)
	_memory = AnimatedSprite2D.new()
	_memory.sprite_frames = FRAMES
	_memory.centered = false
	_memory.offset = _sprite.offset
	_memory.scale = _sprite.scale
	_memory.flip_h = true
	_memory.material = tint
	_memory.modulate = Color(0.7, 0.8, 0.9, 0)
	_memory.play("idle")
	_memory_glass.add_child(_memory)

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
	_next.pressed.connect(_advance_dialogue)
	_dialogue.add_child(_next)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.8, 0.9, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0, 0, 0, 1)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)

func _physics_process(delta: float) -> void:
	_clock += delta
	_scene_time += delta
	if phase != Phase.DEPARTURE:
		_veil.color.a = maxf(0, 1.0 - _scene_time / 0.7)
	match phase:
		Phase.CROSSOVER:
			var t := clampf(_clock / 1.3, 0, 1)
			var ease_t := t * t * (3.0 - 2.0 * t)
			shadow.position = Vector2(PLAYER_START.x - 90, 180).lerp(SHADOW_START, ease_t)
			shadow.scale.y = -1 if t < 0.5 else 1
			shadow.modulate.a = 0.12 + absf(2.0 * t - 1.0) * 0.88
			if t >= 1:
				phase = Phase.BETRAYAL
				_clock = 0
				_speaker.text = "她第一次站到了你的身后"
				_caption.text = "「这一次，我不想再做留下的那个人。」"
				_objective.text = "倒影伸向了你的颜色。按 D / → 向右逃跑，Shift 可以冲刺。"
		Phase.BETRAYAL:
			if _clock > 0.65 and Input.is_action_pressed("move_right"):
				_start_chase()
		Phase.CHASE:
			_pursuit_speed = maxf(PURSUIT_SPEED, player.velocity.x * 0.90)
			shadow.position.x += _pursuit_speed * delta
			if shadow.position.x >= player.position.x - 58 and absf(player.position.y - 900) < 165:
				_retry()
			elif player.position.x >= MIRROR_X - mirror_body.impact_distance and Input.get_axis("move_left", "move_right") > 0:
				_break_mirror()
		Phase.SHATTER:
			shadow.modulate.a = maxf(0, 1.0 - _clock / 0.8)
			_flash.color.a = maxf(0, 0.55 - _clock * 2.4)
			camera.offset = Vector2(sin(_clock * 90) * 9, cos(_clock * 74) * 5) * maxf(0, 1 - _clock * 3)
			if _clock > 1.0:
				_show_farewell()
	var focus := clampf(player.position.x, 960, CORRIDOR_WIDTH - 960)
	if phase == Phase.THRESHOLD and revelation_index in [1, 2]:
		focus = CORRIDOR_WIDTH - 960
	if phase in [Phase.THRESHOLD, Phase.CROSSOVER]:
		camera.position.x = move_toward(camera.position.x, focus, 1400 * delta)
	else:
		camera.position.x = focus
	if phase == Phase.THRESHOLD and revelation_index in [1, 2] and not _passage_shown and absf(camera.position.x - focus) < 5:
		_passage_shown = true
		mirror_body.attempt_passage()

func _process(_delta: float) -> void:
	if phase == Phase.CHASE:
		var animation := "sprint" if _pursuit_speed > 265 else "run"
		HeroAnimation.play(_sprite, animation)
		_sprite.speed_scale = HeroAnimation.cadence(animation, _pursuit_speed)
	for ghost in _ghosts:
		ghost.texture = FRAMES.get_frame_texture(_sprite.animation, _sprite.frame)
	queue_redraw()

func _show_revelation() -> void:
	var beat: Dictionary = REVELATION_BEATS[revelation_index]
	_speaker.text = _state.player_name if beat.speaker == "hero" else beat.speaker
	_caption.text = _state.format_story(beat.text)
	_objective.text = "她以为找回颜色，就能和你一起离开。镜门却给出了另一个答案。"
	_next.text = "继续"
	_next.visible = true
	if revelation_index == 1:
		HeroAnimation.play(_sprite, "push")
	if beat.speaker == "hero":
		player.sprite.flip_h = true

func _advance_dialogue() -> void:
	if phase == Phase.THRESHOLD and _clock >= 0.3:
		_clock = 0
		if revelation_index + 1 < REVELATION_BEATS.size():
			revelation_index += 1
			_show_revelation()
		else:
			phase = Phase.CROSSOVER
			_next.visible = false
			_speaker.text = "镜面泛起最后一次涟漪"
			_caption.text = "她松开了镜中的门环，向你走来。\n那条始终隔在你们之间的边界，正在消失。"
			_objective.text = "那个一直与你同行的倒影，走出了镜面。"
	elif phase == Phase.FAREWELL:
		_advance_farewell()

func _start_chase() -> void:
	phase = Phase.CHASE
	_clock = 0
	_dialogue.visible = false
	player.facing = 1
	player.sprite.flip_h = false
	player.set_physics_process(true)
	_objective.text = "向右跑！前方的巨大镜面，挡住了唯一的出口。"

func _retry() -> void:
	attempts += 1
	phase = Phase.BETRAYAL
	_clock = 0
	player.respawn()
	player.set_physics_process(false)
	shadow.position = SHADOW_START
	shadow.scale.y = 1
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
	if phase in [Phase.SHATTER, Phase.FAREWELL, Phase.DEPARTURE]:
		return
	phase = Phase.SHATTER
	_clock = 0
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player._play("push")
	mirror_body.shatter()
	_dialogue.visible = false
	_objective.text = "巨镜碎裂。追赶你的脚步停了，碎片里却还留着她的轮廓。"

func _show_farewell() -> void:
	phase = Phase.FAREWELL
	camera.offset = Vector2.ZERO
	shadow.visible = false
	player._play("idle")
	_dialogue.visible = true
	farewell_index = 0
	_next.visible = true
	_clock = 0
	_memory_glass.visible = true
	_memory_glass.modulate.a = 0.5
	_memory.modulate.a = 1.0
	_show_farewell_beat()
	_objective.text = "最后一片镜子映着她。你们之间，再也没有追赶的脚步声。"

func _show_farewell_beat() -> void:
	var beat: Dictionary = FAREWELL_BEATS[farewell_index]
	_speaker.text = _state.player_name if beat.speaker == "hero" else "最后一片镜中的女孩"
	_caption.text = beat.text
	_next.text = "走向天亮" if farewell_index == FAREWELL_BEATS.size() - 1 else "继续"
	if beat.get("gesture", false):
		player._play("reach")
		HeroAnimation.play(_memory, "reach")
	if beat.has("opacity"):
		if _memory_tween != null and _memory_tween.is_running():
			_memory_tween.kill()
		_memory_tween = create_tween().set_parallel(true)
		_memory_tween.tween_property(_memory_glass, "modulate:a", beat.opacity, 1.1)
		if beat.get("gesture", false):
			_memory_tween.tween_property(_memory_glass, "position:x", player.position.x + 84, 0.7)
	if farewell_index == FAREWELL_BEATS.size() - 1:
		_speaker.text = "消散前，她把名字留给了你"

func _advance_farewell() -> void:
	if phase != Phase.FAREWELL or _clock < 0.35:
		return
	_clock = 0
	if farewell_index + 1 < FAREWELL_BEATS.size():
		farewell_index += 1
		_show_farewell_beat()
	else:
		_leave_mirror()

func _leave_mirror() -> void:
	phase = Phase.DEPARTURE
	_next.disabled = true
	_dialogue.visible = false
	_objective.text = "你带着颜色，也带着那个名字，走向天亮。"
	player.facing = 1
	player.sprite.flip_h = false
	player._play("run")
	player.sprite.speed_scale = HeroAnimation.cadence("run", 80)
	var departure := create_tween().set_parallel(true)
	departure.tween_property(player, "position:x", player.position.x + 100, 1.25)
	departure.tween_property(_veil, "color:a", 1.0, 0.85).set_delay(0.4)
	await departure.finished
	_state.complete_journey()
	get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if OS.is_debug_build() and event.is_action_pressed("developer_skip"):
		_break_mirror()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_room") and phase not in [Phase.FAREWELL, Phase.DEPARTURE]:
		_retry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and phase in [Phase.THRESHOLD, Phase.FAREWELL]:
		_advance_dialogue()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var colors := [Color("#FF637E"), Color("#59CFFF"), Color("#73E2A5")]
	for i in 3:
		if not _state.has_color(i):
			continue
		var point := player.position + Vector2(-37 + i * 37, -210 - sin(_scene_time * 1.6 + i * 1.7) * 5)
		draw_circle(point, 11, Color(colors[i], 0.12))
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -6), point + Vector2(4, 0), point + Vector2(0, 6), point + Vector2(-4, 0)]), Color(colors[i], 0.8))
