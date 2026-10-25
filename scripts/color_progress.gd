extends Control
## A small cosmetic prism and three swatches; it never controls gameplay.
var _state: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state = get_node("/root/GameState")
	_state.changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if _state == null:
		return
	var triangle := PackedVector2Array([Vector2(0, 46), Vector2(25, 0), Vector2(50, 46)])
	draw_colored_polygon(triangle, Color("#303030"))
	for i in _state.COLOR_COUNT:
		var color: Color = _state.LEVELS[i].collect_color
		var found: bool = _state.has_color(i)
		var strip := PackedVector2Array([Vector2(i * (50.0 / 3.0), 0), Vector2(i * (50.0 / 3.0) + (50.0 / 3.0), 0), Vector2(i * (50.0 / 3.0) + (50.0 / 3.0), 46), Vector2(i * (50.0 / 3.0), 46)])
		if found:
			for polygon in Geometry2D.intersect_polygons(triangle, strip):
				draw_colored_polygon(polygon, color)
		draw_rect(Rect2(72 + i * 36, 5, 28, 15), color if found else Color("#343434"))
	draw_polyline(PackedVector2Array([Vector2(0, 46), Vector2(25, 0), Vector2(50, 46), Vector2(0, 46)]), Color("#d3d3d3"), 1.5, true)
	var caption := "色彩  已赠予" if _state.has_offered_colors() else "色彩  %d / 3" % _state.collected_count()
	draw_string(ThemeDB.fallback_font, Vector2(72, 46), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#e3e3e3"))
