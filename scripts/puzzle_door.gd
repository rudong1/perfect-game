extends StaticBody2D
## A permanently locked door that opens when the reflection plate is pressed.

var is_open := false

var _collision: CollisionShape2D
var _tween: Tween


func _ready() -> void:
	_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func() -> void: visible = false)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _tween != null:
		_tween.kill()
	visible = true
	modulate.a = 1.0
	if _collision != null:
		_collision.set_deferred("disabled", false)
