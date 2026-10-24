extends StaticBody2D
## A real ceiling obstruction: park the shadow, then flip her around its end.
var stalled := false
var released := false
var _shadow: CharacterBody2D
func _ready() -> void:
	add_to_group("shadow_barriers")
	_shadow = get_tree().get_first_node_in_group("mirror_self")
	get_node("/root/MirrorState").reset_requested.connect(reset)
func reset() -> void:
	stalled = false
	released = false
func _physics_process(_delta: float) -> void:
	if _shadow.is_on_wall() and absf(_shadow.position.x - position.x) < 70 and _shadow.position.y < 450:
		stalled = true
	if stalled and _shadow.position.x > position.x + 100 and _shadow.position.y > 500:
		released = true
