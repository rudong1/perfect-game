extends CanvasLayer
## HUD that intentionally stays above the mirror CanvasLayer, so instructions
## stay readable while the world is upside down.

@onready var status: Label = $Status

var _mirror_state: Node


func _ready() -> void:
	_mirror_state = get_node_or_null("/root/MirrorState")
	if _mirror_state == null:
		push_error("MirrorState autoload not found")
		return
	_mirror_state.connect("mirror_changed", _on_mirror_changed)
	_on_mirror_changed(bool(_mirror_state.get("mirrored")))


func _on_mirror_changed(is_mirrored: bool) -> void:
	status.text = "镜像：开" if is_mirrored else "镜像：关"
	status.modulate = Color.WHITE if is_mirrored else Color("#bfbfbf")
