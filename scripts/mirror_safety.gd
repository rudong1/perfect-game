class_name MirrorSafety
extends RefCounted
## Query the actual body shape, never a point, before moving a mirror actor.

static func is_clear(body: CharacterBody2D, point: Vector2) -> bool:
	var collider := body.get_node("Collision") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	# Clearance ignores the 0.1px contact skin at a supporting floor/ceiling.
	# Otherwise a perfectly grounded portal destination is reported embedded.
	var capsule := collider.shape.duplicate() as CapsuleShape2D
	capsule.radius -= 0.1
	capsule.height -= 0.2
	query.shape = capsule
	query.transform = Transform2D(body.global_rotation, point) * collider.transform
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.margin = 0.0
	return body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

static func relocate(body: CharacterBody2D, axis_y: float) -> bool:
	if is_clear(body, body.global_position):
		return true
	var origin := body.global_position
	# Search in distance order along the vertical axis, including mirrored feet.
	for distance in range(2, 1082, 2):
		for sign_y in [-1.0, 1.0]:
			var candidate := origin + Vector2(0, distance * sign_y)
			if candidate.y < 160.0 or candidate.y > 920.0:
				continue
			if is_clear(body, candidate):
				body.global_position = candidate
				body.velocity.y = 0.0
				return true
	var reflected := Vector2(origin.x, 2.0 * axis_y - origin.y)
	if is_clear(body, reflected):
		body.global_position = reflected
		body.velocity.y = 0.0
		return true
	# A closed gate can cover the whole vertical column. Search a nearby column.
	for distance in range(8, 201, 8):
		for sign_x in [-1.0, 1.0]:
			var candidate := origin + Vector2(distance * sign_x, 0)
			if is_clear(body, candidate):
				body.global_position = candidate
				body.velocity = Vector2.ZERO
				return true
	return false
