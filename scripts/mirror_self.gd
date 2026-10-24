extends CharacterBody2D
## A physical echo: axis-symmetric spawn, opposite gravity, delayed horizontal
## momentum. It never consumes jump input and is not a player/goal/save actor.

const HERO_FRAMES = preload("res://assets/characters/hero/hero_frames.tres")
const CAPSULE = preload("res://assets/characters/hero/hero_capsule.tres")
const FOLLOW_DELAY := 0.42
const FOLLOW_ACCEL := 1000.0
const FOLLOW_DRAG := 1100.0
var source: CharacterBody2D
var gravity_sign := -1.0
var _mirror: Node
var sprite: AnimatedSprite2D
var _collision: CollisionShape2D
var _reset_pending := false
var _clock := 0.0
var _delayed_velocity := 0.0
var _history: Array = []
var _trail: Array[Vector2] = []
var _ghosts: Array[Sprite2D] = []
var _trail_time := 0.0
var hint: CanvasLayer

func _ready() -> void:
	add_to_group("mirror_actors")
	add_to_group("mirror_self")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 8.0
	_collision = CollisionShape2D.new()
	_collision.name = "Collision"
	_collision.shape = CAPSULE
	add_child(_collision)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = HERO_FRAMES
	sprite.centered = false
	sprite.scale = Vector2(0.62, 0.62)
	sprite.offset = Vector2(-160, -342)
	sprite.modulate = Color(1, 1, 1, 0.92)
	var tint := ShaderMaterial.new()
	tint.shader = preload("res://shaders/shadow_tint.gdshader")
	sprite.material = tint
	for i in 2:
		var ghost := Sprite2D.new()
		ghost.centered = false
		ghost.scale = sprite.scale
		ghost.offset = sprite.offset
		ghost.modulate = Color(0.85, 0.85, 0.85, 0.14 - i * 0.05)
		ghost.z_index = -1
		add_child(ghost)
		_ghosts.append(ghost)
	add_child(sprite)
	_mirror = get_node("/root/MirrorState")
	_mirror.mirror_changed.connect(_on_mirror_changed)
	_mirror.axis_changed.connect(func(_axis: float) -> void: reset_echo.call_deferred())
	source.respawned.connect(func() -> void: reset_echo.call_deferred())
	hint = CanvasLayer.new()
	hint.set_script(preload("res://scripts/readable_hint.gd"))
	hint.target = self
	hint.text = "影子 · 晚一步跟随"
	hint.tint = Color("#e4e4e4")
	add_child(hint)
	reset_echo()

func reset_echo() -> void:
	_reset_pending = false
	_history.clear()
	_trail.clear()
	_delayed_velocity = 0.0
	_clock = 0.0
	for ghost in _ghosts:
		ghost.visible = false
	global_position = _mirror.reflect_point(source.global_position)
	velocity = Vector2(source.velocity.x, -source.velocity.y)
	_on_mirror_changed(_mirror.mirrored)
	resolve_overlap()

func _on_mirror_changed(value: bool) -> void:
	gravity_sign = 1.0 if value else -1.0
	up_direction = Vector2(0, -gravity_sign)
	_collision.position = Vector2(0, -75 * gravity_sign)
	# flip_v keeps the hero atlas upright relative to its opposite gravity.
	sprite.flip_v = gravity_sign < 0
	sprite.position.y = 0.0 if gravity_sign > 0 else 188.48

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.is_physics_processing():
		return
	_clock += delta
	_history.append({"time": _clock, "velocity": source.velocity.x})
	while not _history.is_empty() and _history[0].time <= _clock - FOLLOW_DELAY:
		_delayed_velocity = _history.pop_front().velocity
	var acceleration := FOLLOW_ACCEL if absf(_delayed_velocity) > 5 else FOLLOW_DRAG
	velocity.x = move_toward(velocity.x, _delayed_velocity, acceleration * delta)
	velocity.y = clampf(velocity.y + 1600.0 * gravity_sign * delta, -950, 950)
	move_and_slide()
	if absf(velocity.x) > 5:
		sprite.flip_h = velocity.x < 0
	var animation := "idle"
	if is_on_floor():
		if absf(velocity.x) > 12:
			animation = "sprint" if absf(velocity.x) > 265 else "run"
	else:
		animation = "apex" if absf(velocity.y) < 85 else ("jump" if velocity.y * gravity_sign < 0 else "fall")
	HeroAnimation.play(sprite, animation)
	sprite.speed_scale = HeroAnimation.cadence(animation, absf(velocity.x))
	hint.world_offset = Vector2(0, -232 * gravity_sign)
	_trail_time += delta
	if _trail_time >= 0.1:
		_trail_time = 0.0
		_trail.push_front(global_position)
		if _trail.size() > 4:
			_trail.pop_back()
	for i in _ghosts.size():
		var ghost := _ghosts[i]
		ghost.visible = _trail.size() > i + 1 and absf(velocity.x) > 25
		if ghost.visible:
			ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			ghost.position = to_local(_trail[i + 1]) + sprite.position
			ghost.flip_h = sprite.flip_h
			ghost.flip_v = sprite.flip_v
	if global_position.y < -120 or global_position.y > 1200:
		if not _reset_pending:
			_reset_pending = true
			source.respawn.call_deferred()

func resolve_overlap() -> bool:
	return MirrorSafety.relocate(self, _mirror.axis_y)
