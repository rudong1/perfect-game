extends Node2D
## Fear leads to a chase; freely giving the three colours restores a life.
enum Phase { THRESHOLD, CROSSOVER, BETRAYAL, CHASE, SHATTER, CONFESSION, FUSION, REUNION, EMBRACE, DEPARTURE }
const HERO = preload("res://scenes/player/player.tscn")
const FRAMES = preload("res://assets/characters/hero/hero_frames.tres")
const GIANT_MIRROR = preload("res://scripts/final_mirror.gd")
const BACKDROP = preload("res://scripts/chase_backdrop.gd")
const CORRIDOR_WIDTH := 3600.0
const MIRROR_X := 3120.0
const PURSUIT_SPEED := 205.0
const PLAYER_START := Vector2(350, 900)
const SHADOW_START := Vector2(130, 900)
const REVIVAL_CG = preload("res://assets/backgrounds/ending_revival.png")
const EMBRACE_CG = preload("res://assets/backgrounds/ending_embrace.png")
const DARKSKY_FRAMES = preload("res://assets/characters/darksky/darksky_frames.tres")
const PALETTE = preload("res://scripts/palette.gd")
const PAUSE_MENU = preload("res://scripts/pause_menu.gd")
const FUSION_DURATION := 4.2
const EMBRACE_DURATION := 2.2
const CONFESSION_BEATS := [
	{"speaker": "镜背的刻痕", "text": "碎裂的镜框背后，露出一行旧字：\n「夺来的色彩只能造出倒影，赠予的色彩才能唤回生命。」"},
	{"speaker": "reflection", "text": "「我也曾和你一样，是个掉进来的女孩。\n可我始终解不开出口，等到最后，连自己的身体都褪去了。」"},
	{"speaker": "reflection", "text": "「你会回头找我，会等我跟上……\n我真的想和你一起走。可看见门只回应你，我又只剩下害怕。」"},
	{"speaker": "reflection", "text": "「我把陪伴变成了追赶，竟然想夺走属于你的东西。\n……对不起。我不该让你也尝到被留下的滋味。」"},
	{"speaker": "hero", "text": "「我还在生气。\n可我不愿用你的消失，换我一个人的离开。」"},
	{"speaker": "hero", "text": "你看向掌心的红、蓝、绿，再看向镜背的旧字。\n「如果不能夺走，那就由我亲手给你。」"},
	{"speaker": "reflection", "text": "「可那是你一路找回的颜色。给了我，\n它们就不会再属于你了……你真的愿意？」"},
	{"speaker": "hero", "text": "「这些颜色，是我们一起找回来的。\n这一次，换我把你带回来。」", "gesture": true},
]
const REUNION_BEATS := [
	{"speaker": "不再是倒影", "text": "镜光褪去，她终于恢复了自己的容貌。\n墨蓝短发垂在颊边，含泪的蓝眼睛小心地望向你。"},
	{"speaker": "reflection", "text": "「我不是你的倒影了……你还会认得我吗？\n能不能，再让我靠近一点？」"},
	{"speaker": "终于触碰到的温度", "text": "你张开双臂，她终于在你怀里卸下了颤抖。\n这一次，没有镜面，也没有谁再晚半拍。", "embrace": true},
	{"speaker": "reflection", "text": "「原来，被人抱住是这样的感觉。\n我以为……自己再也等不到了。」"},
	{"speaker": "hero", "text": "「以后不用一个人等了。我们一起走。\n还有……这次，我想知道你真正的名字。」"},
	{"speaker": "reflection", "text": "……对了，我叫 darksky。"},
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
var confession_index := 0
var reunion_index := 0
var _state: Node
var _clock := 0.0
var _pursuit_speed := PURSUIT_SPEED
var _sprite: AnimatedSprite2D
var _ghosts: Array[Sprite2D] = []
var _dialogue: Panel
var _caption: Label
var _speaker: Label
var _objective: Label
var _chapter: Label
var _next: Button
var _flash: ColorRect
var _memory: AnimatedSprite2D
var _memory_glass: Polygon2D
var _memory_tween: Tween
var _cg: TextureRect
var _cg_transition: Tween
var _topshade: ColorRect

func _ready() -> void:
	_state = get_node("/root/GameState")
	var mirror := get_node("/root/MirrorState")
	mirror.input_enabled = false
	mirror.set_mirrored(false)
	_state.end_light_puzzle()
	_build_world()
	_build_actors()
	_build_ui()
	var pause := CanvasLayer.new()
	pause.name = "PauseMenu"
	pause.set_script(PAUSE_MENU)
	add_child(pause)
	if _state.has_offered_colors():
		player.position = Vector2(MIRROR_X - mirror_body.impact_distance + 2, 900)
		mirror_body.shatter()
		shadow.visible = false
		if _state.darksky_revived:
			_show_reunion()
		else:
			_begin_fusion()
		return
	if _state.mirror_sealed:
		# The revelation closed the mirror; only the start screen may reopen it.
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/title_screen.tscn")
		return
	shadow.position = Vector2(PLAYER_START.x - 90, 180)
	shadow.scale.y = -1
	if _state.revelation_done:
		_begin_crossover()
		return
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
	var art_layer := CanvasLayer.new()
	art_layer.layer = 115
	add_child(art_layer)
	_cg = TextureRect.new()
	_cg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cg.texture = REVIVAL_CG
	_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cg.modulate.a = 0
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/restricted_art.gdshader")
	_cg.material = palette
	art_layer.add_child(_cg)
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var top := ColorRect.new()
	_topshade = top
	top.size = Vector2(1920, 155)
	top.color = Color(0.025, 0.03, 0.035, 0.9)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var progress := Control.new()
	progress.position = Vector2(48, 26)
	progress.set_script(preload("res://scripts/color_progress.gd"))
	layer.add_child(progress)
	_chapter = _label(layer, Vector2(380, 24), Vector2(1400, 50), "终幕 · 倒影越界", 34)
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
				_show_confession()
		Phase.FUSION:
			var t := clampf(_clock / FUSION_DURATION, 0, 1)
			backdrop.set_desaturation(t)
			_memory_glass.modulate.a = lerpf(0.4, 1.0, t)
			_cg.modulate.a = smoothstep(0.62, 1.0, t)
			_topshade.modulate.a = 1.0 - _cg.modulate.a
			if _clock >= FUSION_DURATION:
				_state.revive_darksky()
				_show_reunion()
		Phase.EMBRACE:
			if _clock >= EMBRACE_DURATION:
				phase = Phase.REUNION
				_clock = 0
				_next.visible = true
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
			_seal_mirror_to_title()
	elif phase == Phase.CONFESSION:
		_advance_confession()
	elif phase == Phase.REUNION and _clock >= 0.35:
		_clock = 0
		if reunion_index + 1 < REUNION_BEATS.size():
			reunion_index += 1
			_show_reunion_beat()
		else:
			_leave_mirror()

func _seal_mirror_to_title() -> void:
	# The revelation ends by shutting the mirror: the player is sent home and
	# must find a way back in from the locked start screen.
	_next.visible = false
	_dialogue.visible = false
	_objective.text = "镜门在你面前合上。你需要想办法，再次进入镜面。"
	_state.call("seal_mirror")
	_veil.color.a = 0.0
	var fade := create_tween()
	fade.tween_property(_veil, "color:a", 1.0, 0.55)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _begin_crossover() -> void:
	phase = Phase.CROSSOVER
	_next.visible = false
	_speaker.text = "镜面泛起最后一次涟漪"
	_caption.text = "她松开了镜中的门环，向你走来。\n那条始终隔在你们之间的边界，正在消失。"
	_objective.text = "那个一直与你同行的倒影，走出了镜面。"

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
	if phase in [Phase.SHATTER, Phase.CONFESSION, Phase.FUSION, Phase.REUNION, Phase.EMBRACE, Phase.DEPARTURE]:
		return
	phase = Phase.SHATTER
	_clock = 0
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player._play("push")
	mirror_body.shatter()
	_dialogue.visible = false
	_objective.text = "巨镜碎裂。追赶你的脚步停了，碎片里却还留着她的轮廓。"

func _show_confession() -> void:
	phase = Phase.CONFESSION
	_chapter.text = "终幕 · 镜背之言"
	camera.offset = Vector2.ZERO
	shadow.visible = false
	player._play("idle")
	_dialogue.visible = true
	confession_index = 0
	_next.visible = true
	_clock = 0
	_memory_glass.visible = true
	_memory_glass.modulate.a = 0.5
	_memory.modulate.a = 1.0
	_show_confession_beat()
	_objective.text = "镜背的旧字，藏着另一种把她带回来的办法。"

func _show_confession_beat() -> void:
	var beat: Dictionary = CONFESSION_BEATS[confession_index]
	_speaker.text = _state.player_name if beat.speaker == "hero" else ("最后一片镜中的女孩" if beat.speaker == "reflection" else beat.speaker)
	_caption.text = beat.text
	_next.text = "将三色交给她" if confession_index == CONFESSION_BEATS.size() - 1 else "继续"
	if beat.get("gesture", false):
		player._play("reach")
		HeroAnimation.play(_memory, "reach")
		if _memory_tween != null and _memory_tween.is_running():
			_memory_tween.kill()
		_memory_tween = create_tween().set_parallel(true)
		_memory_tween.tween_property(_memory_glass, "position:x", player.position.x + 84, 0.7)

func _advance_confession() -> void:
	if phase != Phase.CONFESSION or _clock < 0.35:
		return
	_clock = 0
	if confession_index + 1 < CONFESSION_BEATS.size():
		confession_index += 1
		_show_confession_beat()
	else:
		_begin_fusion()

func _cg_dialogue_layout() -> void:
	_dialogue.position = Vector2(60, 185)
	_dialogue.size = Vector2(760, 360)
	_speaker.size = Vector2(690, 35)
	_caption.size = Vector2(690, 230)
	_caption.add_theme_font_size_override("font_size", 26)
	_next.position = Vector2(490, 300)
	_next.size = Vector2(230, 42)

func _begin_fusion() -> void:
	if not _state.has_offered_colors() and not _state.offer_colors():
		_objective.text = "三种色彩尚未找齐。她的生命需要完整的红、蓝、绿。"
		return
	phase = Phase.FUSION
	_chapter.text = "终幕 · 赠予的色彩"
	_clock = 0
	if _memory_tween != null and _memory_tween.is_running():
		_memory_tween.kill()
	shadow.visible = false
	_memory_glass.visible = true
	_memory_glass.position.x = player.position.x + 84
	player._play("reach")
	HeroAnimation.play(_memory, "reach")
	_next.visible = false
	_dialogue.visible = true
	_cg_dialogue_layout()
	_speaker.text = _state.player_name
	_caption.text = "红、蓝、绿离开了你的掌心。\n你放开它们，也握住了镜中的那只手。"
	_objective.text = "色彩已赠予。三束光正汇成她的生命。"

func _show_reunion() -> void:
	phase = Phase.REUNION
	_chapter.text = "终幕 · 余色成光"
	_clock = 0
	reunion_index = 0
	shadow.visible = false
	_memory_glass.visible = true
	_memory_glass.modulate = Color.WHITE
	_memory_glass.color.a = 0
	_memory_glass.get_child(0).visible = false
	_memory_glass.position.x = player.position.x + 84
	_memory.material = null
	_memory.modulate = Color.WHITE
	_memory.flip_h = true
	# The mirror had borrowed the heroine's face. Life returns her own identity.
	_memory.stop()
	_memory.sprite_frames = DARKSKY_FRAMES
	_memory.offset = -Vector2(DARKSKY_FRAMES.get_meta("foot_origin"))
	_memory.scale = Vector2.ONE * (174.0 / float(DARKSKY_FRAMES.get_meta("stand_height")))
	for key in ["hero_pose_scale", "hero_pose_offset"]:
		if _memory.has_meta(key):
			_memory.remove_meta(key)
	_memory.play("idle")
	player._play("idle")
	backdrop.set_desaturation(1)
	_cg.modulate.a = 1
	_cg.texture = REVIVAL_CG
	_topshade.modulate.a = 0
	_cg_dialogue_layout()
	_dialogue.visible = true
	_next.visible = true
	_objective.text = "色彩不再属于你，却让她真正回到了你的身边。"
	_show_reunion_beat()

func _show_reunion_beat() -> void:
	var beat: Dictionary = REUNION_BEATS[reunion_index]
	_speaker.text = _state.player_name if beat.speaker == "hero" else ("重获身体的女孩" if beat.speaker == "reflection" else beat.speaker)
	_caption.text = beat.text
	_next.text = "一起走出镜面" if reunion_index == REUNION_BEATS.size() - 1 else "继续"
	if beat.get("embrace", false):
		_start_embrace()

func _start_embrace() -> void:
	phase = Phase.EMBRACE
	_clock = 0
	_next.visible = false
	_chapter.text = "终幕 · 不再隔着镜面"
	_objective.text = "她终于能够拥抱你，而不再只是映出你的模样。"
	player._play("reach")
	_memory.play("hug")
	var approach := create_tween()
	approach.tween_property(_memory_glass, "position:x", player.position.x + 35, 0.8).set_trans(Tween.TRANS_SINE)
	if _cg_transition != null and _cg_transition.is_running():
		_cg_transition.kill()
	_cg_transition = create_tween()
	_cg_transition.tween_property(_cg, "modulate:a", 0.0, 0.3)
	_cg_transition.tween_callback(func() -> void: _cg.texture = EMBRACE_CG)
	_cg_transition.tween_property(_cg, "modulate:a", 1.0, 0.55)

func _leave_mirror() -> void:
	phase = Phase.DEPARTURE
	_next.disabled = true
	_dialogue.visible = false
	_objective.text = "你不再拥有那些颜色，却终于能够和她一起离开。"
	player.facing = 1
	player.sprite.flip_h = false
	player._play("run")
	player.sprite.speed_scale = HeroAnimation.cadence("run", 80)
	_memory.flip_h = false
	_memory.play("run")
	_memory.speed_scale = HeroAnimation.cadence("run", 80)
	var departure := create_tween().set_parallel(true)
	departure.tween_property(player, "position:x", player.position.x + 100, 1.25)
	departure.tween_property(_memory_glass, "position:x", player.position.x + 184, 1.25)
	departure.tween_property(_cg, "modulate:a", 0.0, 0.35)
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
	elif event.is_action_pressed("restart_room") and phase not in [Phase.CONFESSION, Phase.FUSION, Phase.REUNION, Phase.EMBRACE, Phase.DEPARTURE]:
		_retry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and phase in [Phase.THRESHOLD, Phase.CONFESSION, Phase.REUNION]:
		_advance_dialogue()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	var colors := PALETTE.JOURNEY_COLORS
	if phase == Phase.FUSION:
		var t := clampf(_clock / FUSION_DURATION, 0, 1)
		var destination := _memory_glass.position + Vector2(0, -125)
		for i in 3:
			var start := player.position + Vector2(-37 + i * 37, -210)
			var bend := (start + destination) * 0.5 + Vector2(-50 + i * 50, -120)
			var curve := PackedVector2Array()
			for sample in 17:
				var progress := maxf(0, t - 0.28) + (t - maxf(0, t - 0.28)) * sample / 16.0
				curve.append(start.lerp(bend, progress).lerp(bend.lerp(destination, progress), progress))
			draw_polyline(curve, colors[i], 3, true)
			draw_circle(curve[-1], 6, colors[i])
		draw_circle(destination, 5 + t * 17, Color(1, 1, 1, t * 0.32))
		return
	if _state.darksky_revived:
		draw_set_transform(_memory_glass.position + Vector2(0, -2), 0, Vector2(1, 0.15))
		draw_circle(Vector2.ZERO, 31, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
	for i in 3:
		if not _state.has_color(i):
			continue
		var point := player.position + Vector2(-37 + i * 37, -210 - sin(_scene_time * 1.6 + i * 1.7) * 5)
		draw_circle(point, 11, Color(colors[i], 0.12))
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -6), point + Vector2(4, 0), point + Vector2(0, 6), point + Vector2(-4, 0)]), Color(colors[i], 0.8))
