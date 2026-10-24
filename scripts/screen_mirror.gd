extends CanvasLayer
## Full-screen vertical mirror renderer.
##
## MirrorState owns the world axis and on/off state; this node only presents it. The world,
## sprites and lower CanvasLayers are copied by BackBufferCopy and re-drawn
## upside down by a screen-texture shader. The shared world axis is projected through the camera every frame.

@onready var overlay: ColorRect = $Overlay
@onready var back_buffer: BackBufferCopy = $BackBufferCopy

var _mirror_material: ShaderMaterial
var _mirror_state: Node


func _ready() -> void:
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mirror_material = ShaderMaterial.new()
	_mirror_material.shader = preload("res://shaders/screen_mirror.gdshader")
	_mirror_material.set_shader_parameter("mirrored", 1.0)
	overlay.material = _mirror_material

	_mirror_state = get_node_or_null("/root/MirrorState")
	if _mirror_state == null:
		push_error("MirrorState autoload not found")
		return
	_mirror_state.connect("mirror_changed", _on_mirror_changed)
	_on_mirror_changed(bool(_mirror_state.get("mirrored")))


func _on_mirror_changed(is_mirrored: bool) -> void:
	overlay.visible = is_mirrored
	back_buffer.copy_mode = (
		BackBufferCopy.COPY_MODE_VIEWPORT if is_mirrored
		else BackBufferCopy.COPY_MODE_DISABLED
	)


func toggle() -> void:
	if _mirror_state != null:
		_mirror_state.call("toggle")


func _process(_delta: float) -> void:
	if _mirror_state == null:
		return
	# Convert the shared world axis through the camera and viewport stretch.
	var screen_axis := get_viewport().get_canvas_transform() * Vector2(0, _mirror_state.axis_y)
	_mirror_material.set_shader_parameter("axis_y", screen_axis.y / get_viewport().get_visible_rect().size.y)
