extends CharacterBody2D
## A physical echo: axis-symmetric spawn, opposite gravity, delayed horizontal
## momentum. It never consumes jump input and is not a player/goal/save actor.

const HERO_FRAMES = preload("res://assets/characters/hero/hero_frames.tres")
const CAPSULE = preload("res://assets/characters/hero/hero_capsule.tres")
const FOLLOW_ACCEL := 420.0
const FOLLOW_DRAG := 240.0
var source: CharacterBody2D
var gravity_sign := -1.0
var _mirror: Node
var sprite: AnimatedSprite2D
var _collision: CollisionShape2D
var _reset_pending := false

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
	sprite.modulate = Color(0.40, 0.82, 1.0, 0.72)
	add_child(sprite)
	_mirror = get_node("/root/MirrorState")
	_mirror.mirror_changed.connect(_on_mirror_changed)
	_mirror.axis_changed.connect(func(_axis: float) -> void: reset_echo.call_deferred())
	source.respawned.connect(func() -> void: reset_echo.call_deferred())
	reset_echo()

func reset_echo() -> void:
	_reset_pending = false
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
	var acceleration := FOLLOW_ACCEL if absf(source.velocity.x) > 5 else FOLLOW_DRAG
	velocity.x = move_toward(velocity.x, source.velocity.x, acceleration * delta)
	velocity.y = clampf(velocity.y + 1600.0 * gravity_sign * delta, -950, 950)
	move_and_slide()
	sprite.flip_h = source.facing < 0
	sprite.play("run" if absf(velocity.x) > 10 else "idle")
	if global_position.y < -120 or global_position.y > 1200:
		if not _reset_pending:
			_reset_pending = true
			reset_echo.call_deferred()

func resolve_overlap() -> bool:
	return MirrorSafety.relocate(self, _mirror.axis_y)
