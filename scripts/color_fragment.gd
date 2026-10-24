extends Area2D
signal collected
var is_exit := false
var enabled := false
var used := false
var color := Color.WHITE
var color_name := ""
var hint: CanvasLayer
var _age := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	get_node("/root/MirrorState").reset_requested.connect(reset)

func reset() -> void:
	used = false
	enabled = false
	visible = true

func _on_body_entered(body: Node2D) -> void:
	if enabled and not used and body.is_in_group("player"):
		used = true
		visible = false
		collected.emit()

func _physics_process(_delta: float) -> void:
	if enabled and not used:
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _process(delta: float) -> void:
	_age += delta
	if is_exit and has_node("ExitVisual"):
		$ExitVisual.modulate.a = 1.0 if enabled else 0.3
	if hint != null:
		hint.text = ("出口" if is_exit else color_name + "碎片") + ("" if enabled else " · 先解开教堂机关")
		hint.tint = color if enabled else Color("#9eaabc")
	queue_redraw()

func _draw() -> void:
	if is_exit:
		return
	var pulse := 1.0 + 0.06 * sin(_age * 3.0)
	var points := PackedVector2Array([Vector2(0, -48), Vector2(28, 0), Vector2(0, 48), Vector2(-28, 0)])
	var glow := PackedVector2Array()
	for point in points:
		glow.append(point * 1.7 * pulse)
	draw_colored_polygon(glow, Color(color, 0.12) if enabled else Color(0.65, 0.67, 0.7, 0.02))
	draw_colored_polygon(points, color if enabled else Color(0.65, 0.67, 0.7, 0.2))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), (Color(color, 0.9) if enabled else Color("#84898f")), 2, true)
