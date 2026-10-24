extends CharacterBody2D
## Side-scrolling heroine controller.
##
## Movement: A/D or Left/Right. Jump: W/Up. Crouch: S/Down. Sprint: Shift.
## Mirror the whole frame: M (handled globally by MirrorState).
## The character art is laid out with the node origin at the soles, so the
## sprite can simply flip_h for the opposite facing direction.

const STAND_SHAPE: CapsuleShape2D = preload("res://assets/characters/hero/hero_capsule.tres")
const CROUCH_SHAPE: CapsuleShape2D = preload("res://assets/characters/hero/hero_capsule_crouch.tres")
const STAND_CENTER := Vector2(0.0, -75.0)
const CROUCH_CENTER := Vector2(0.0, -50.0)
const STAND_SPRITE_OFFSET := Vector2(-160.0, -342.0)
const CROUCH_SPRITE_OFFSET := Vector2(-160.0, -327.0)

const PUSH_SPEED := 120.0
const RUN_SPEED := 220.0
const SPRINT_SPEED := 340.0
const CROUCH_SPEED := 80.0
const GROUND_ACCEL := 1900.0
const AIR_ACCEL := 1350.0
const GROUND_FRICTION := 2400.0
const AIR_FRICTION := 650.0
const GRAVITY := 1600.0
const MAX_FALL_SPEED := 950.0
const JUMP_VELOCITY := -620.0
const JUMP_CUT_VELOCITY := -220.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER_TIME := 0.12
const LAND_RECOVERY := 0.12
const MIN_AIR_TIME := 0.08

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

signal respawned

var gravity_sign := 1.0
var _mirror_state: Node

var facing := 1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var air_time := 0.0
var land_timer := 0.0
var stop_timer := 0.0
var _previous_speed := 0.0
var current_animation := ""
var is_crouching := false
var is_pushing := false
var respawn_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("mirror_actors")
	collision_layer = 2
	collision_mask = 1
	_mirror_state = get_node("/root/MirrorState")
	_mirror_state.mirror_changed.connect(_on_mirror_changed)
	floor_snap_length = 8.0
	collision.shape = STAND_SHAPE
	collision.position = STAND_CENTER
	sprite.offset = STAND_SPRITE_OFFSET
	respawn_position = global_position
	_play("idle")
	_on_mirror_changed(_mirror_state.mirrored)


func set_respawn_position(point: Vector2) -> void:
	respawn_position = point


func respawn() -> void:
	# Reset mechanisms as well as actors; no stale latched plate or light state.
	_mirror_state.restart_room()
	global_position = respawn_position
	velocity = Vector2.ZERO
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_set_crouching(false)
	is_pushing = false
	_play("idle")
	respawned.emit()
	resolve_overlap.call_deferred()


func _on_mirror_changed(value: bool) -> void:
	gravity_sign = -1.0 if value else 1.0
	up_direction = Vector2(0, -gravity_sign)
	collision.position.y = (CROUCH_CENTER.y if is_crouching else STAND_CENTER.y) * gravity_sign
	sprite.scale.y = absf(sprite.scale.y) * gravity_sign
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	# Preserve momentum: the flip changes gravity, not the actor's velocity.


func resolve_overlap() -> bool:
	return MirrorSafety.relocate(self, _mirror_state.axis_y)


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()

	if was_on_floor:
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var input_axis := Input.get_axis("move_left", "move_right")
	if absf(input_axis) > 0.01:
		facing = 1 if input_axis > 0.0 else -1

	# Crouching lowers the capsule on either side of gravity.
	_set_crouching(Input.is_action_pressed("crouch") and was_on_floor)

	is_pushing = false
	for slab in get_tree().get_nodes_in_group("mirror_slabs"):
		if slab.is_being_pushed_by(self, input_axis):
			is_pushing = true
			break
	var sprinting := not is_pushing and Input.is_action_pressed("sprint") and absf(input_axis) > 0.01 and not is_crouching
	if is_crouching:
		var crawl_target := CROUCH_SPEED * input_axis
		velocity.x = move_toward(velocity.x, crawl_target, GROUND_ACCEL * 0.6 * delta)
	elif absf(input_axis) > 0.01:
		var target_speed := (PUSH_SPEED if is_pushing else (SPRINT_SPEED if sprinting else RUN_SPEED)) * input_axis
		var acceleration := GROUND_ACCEL if was_on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		var friction := GROUND_FRICTION if was_on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_set_crouching(false)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not is_crouching:
		velocity.y = JUMP_VELOCITY * gravity_sign
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		land_timer = 0.0
		stop_timer = 0.0
		_play("jump")

	if Input.is_action_just_released("jump") and velocity.y * gravity_sign < JUMP_CUT_VELOCITY:
		velocity.y = JUMP_CUT_VELOCITY * gravity_sign

	if not is_on_floor():
		velocity.y = clampf(velocity.y + GRAVITY * gravity_sign * delta, -MAX_FALL_SPEED, MAX_FALL_SPEED)

	move_and_slide()
	if global_position.y < -120.0 or global_position.y > 1200.0:
		respawn()
		return

	var landed := is_on_floor()
	if not landed and is_crouching:
		_set_crouching(false)

	if landed and not was_on_floor and air_time > MIN_AIR_TIME:
		if Input.is_action_pressed("crouch"):
			_set_crouching(true)
		else:
			land_timer = LAND_RECOVERY
			_play("land")

	if landed:
		air_time = 0.0
		coyote_timer = COYOTE_TIME
		if Input.is_action_pressed("crouch"):
			_set_crouching(true)
			land_timer = 0.0
	else:
		air_time += delta

	_update_animation(delta, landed, sprinting)
	sprite.flip_h = facing < 0


func _set_crouching(value: bool) -> void:
	if is_crouching == value:
		return
	if not value:
		collision.shape = STAND_SHAPE
		collision.position = STAND_CENTER * Vector2(1, gravity_sign)
		if not MirrorSafety.is_clear(self, global_position):
			collision.shape = CROUCH_SHAPE
			collision.position = CROUCH_CENTER * Vector2(1, gravity_sign)
			return
	is_crouching = value
	collision.shape = CROUCH_SHAPE if value else STAND_SHAPE
	collision.position = (CROUCH_CENTER if value else STAND_CENTER) * Vector2(1, gravity_sign)
	sprite.offset = CROUCH_SPRITE_OFFSET if value else STAND_SPRITE_OFFSET
	if value:
		land_timer = 0.0


func _update_animation(delta: float, grounded: bool, sprinting: bool) -> void:
	var speed := absf(velocity.x)
	if grounded and _previous_speed > 45 and speed <= 12:
		stop_timer = 0.15
	_previous_speed = speed
	stop_timer = maxf(0, stop_timer - delta)
	if grounded:
		if is_pushing:
			_play("push")
		elif is_crouching:
			_play("crouch")
		elif speed > 12:
			# Running can flow straight out of a landing without a crouched slide.
			land_timer = 0
			_play("sprint" if sprinting else "run")
		elif land_timer > 0:
			land_timer -= delta
			_play("land")
		elif stop_timer > 0:
			_play("stop")
		else:
			_play("idle")
	else:
		var rise_speed := velocity.y * gravity_sign
		_play("apex" if absf(rise_speed) < 85 else ("jump" if rise_speed < 0 else "fall"))
	sprite.speed_scale = HeroAnimation.cadence(current_animation, speed)

func _play(animation_name: String) -> void:
	current_animation = animation_name
	HeroAnimation.play(sprite, animation_name)
