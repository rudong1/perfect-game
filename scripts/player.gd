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
const LAND_RECOVERY := 0.14
const MIN_AIR_TIME := 0.08

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

var facing := 1
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var air_time := 0.0
var land_timer := 0.0
var current_animation := ""
var is_crouching := false
var respawn_position := Vector2.ZERO


func _ready() -> void:
	floor_snap_length = 8.0
	collision.shape = STAND_SHAPE
	collision.position = STAND_CENTER
	sprite.offset = STAND_SPRITE_OFFSET
	respawn_position = global_position
	_play("idle")


func set_respawn_position(point: Vector2) -> void:
	respawn_position = point


func respawn() -> void:
	global_position = respawn_position
	velocity = Vector2.ZERO
	_set_crouching(false)
	_play("idle")
	var mirror_state := get_node_or_null("/root/MirrorState")
	if mirror_state != null:
		mirror_state.call("reset")


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

	# Crouching is a grounded stance: it lowers the capsule and stops movement.
	_set_crouching(Input.is_action_pressed("crouch") and was_on_floor)

	var sprinting := Input.is_action_pressed("sprint") and absf(input_axis) > 0.01 and not is_crouching
	if is_crouching:
		var crawl_target := CROUCH_SPEED * input_axis
		velocity.x = move_toward(velocity.x, crawl_target, GROUND_ACCEL * 0.6 * delta)
	elif absf(input_axis) > 0.01:
		var target_speed := (SPRINT_SPEED if sprinting else RUN_SPEED) * input_axis
		var acceleration := GROUND_ACCEL if was_on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		var friction := GROUND_FRICTION if was_on_floor else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		_set_crouching(false)
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		land_timer = 0.0
		_play("jump")

	if Input.is_action_just_released("jump") and velocity.y < JUMP_CUT_VELOCITY:
		velocity.y = JUMP_CUT_VELOCITY

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	move_and_slide()

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
	is_crouching = value
	collision.shape = CROUCH_SHAPE if value else STAND_SHAPE
	collision.position = CROUCH_CENTER if value else STAND_CENTER
	sprite.offset = CROUCH_SPRITE_OFFSET if value else STAND_SPRITE_OFFSET
	if value:
		land_timer = 0.0


func _update_animation(delta: float, grounded: bool, sprinting: bool) -> void:
	if grounded:
		if is_crouching:
			_play("crouch")
			sprite.speed_scale = 1.0
		elif land_timer > 0.0:
			land_timer -= delta
			_play("land")
			sprite.speed_scale = 1.0
		elif absf(velocity.x) > 12.0:
			var anim := "sprint" if sprinting else "run"
			_play(anim)
			var base_speed := SPRINT_SPEED if sprinting else RUN_SPEED
			sprite.speed_scale = clampf(absf(velocity.x) / base_speed, 0.75, 1.3)
		else:
			_play("idle")
			sprite.speed_scale = 1.0
	else:
		_play("jump" if velocity.y < 0.0 else "fall")
		sprite.speed_scale = 1.0


func _play(animation_name: String) -> void:
	if current_animation == animation_name:
		return
	current_animation = animation_name
	sprite.play(animation_name)
