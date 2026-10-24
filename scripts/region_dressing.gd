extends Node2D
## Cosmetic differences between the same church's four colour regions.
var region := 0
var stone := Color("#363A42")
var edge := Color("#A8AEB8")
var _time := 0.0

func _ready() -> void:
	add_to_group("gothic_visuals")
	add_to_group("region_dressing")
	set_meta("draw_calls", [8, 26, 17, 21][clampi(region, 0, 3)])
	set_meta("bounds", Rect2(0, 180, 1920, 720))
	if region == 2:
		var mist := ColorRect.new()
		mist.size = Vector2(1920, 1080)
		mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mist.z_index = -1
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/aisle_mist.gdshader")
		mist.material = material
		add_child(mist)

func _process(delta: float) -> void:
	_time += delta
	if region == 2:
		queue_redraw()

func _draw() -> void:
	match region:
		0: _empty_chains()
		1: _rose_drapes()
		2: _rain_and_puddles()
		3: _moss_and_memorials()

func _empty_chains() -> void:
	for side in [92.0, 1828.0]:
		for i in 3:
			var y := 215.0 + i * 60
			draw_line(Vector2(side, y), Vector2(side + 5, y + 42), Color(edge, 0.30), 2)
		draw_line(Vector2(side + 5, 400), Vector2(side + 19, 414), Color(edge, 0.3), 2)

func _rose_drapes() -> void:
	for x in [65.0, 1730.0]:
		var cloth := PackedVector2Array([Vector2(x, 185), Vector2(x + 125, 185), Vector2(x + 108, 390), Vector2(x + 64, 440), Vector2(x + 17, 404)])
		draw_colored_polygon(cloth, Color("#2F111A"))
		draw_polyline(cloth, Color("#8D5962", 0.65), 2, true)
		draw_line(Vector2(x + 16, 185), Vector2(x + 108, 185), Color("#C9A227"), 3)
		draw_line(Vector2(x + 34, 188), Vector2(x + 46, 408), Color("#81515E", 0.28), 2)
		draw_line(Vector2(x + 90, 188), Vector2(x + 81, 416), Color("#81515E", 0.20), 3)
	for x in [350.0, 1550.0]:
		draw_line(Vector2(x, 900), Vector2(x, 724), Color("#625434"), 4)
		draw_line(Vector2(x - 30, 762), Vector2(x + 30, 762), Color("#625434"), 3)
		for j in [-1, 0, 1]:
			var flame := Vector2(x + j * 30, 718 + abs(j) * 24)
			draw_line(flame + Vector2(0, 8), Vector2(flame.x, 765), Color("#BEB39B"), 4)
			draw_circle(flame, 3, Color("#E8D8AB"))

func _rain_and_puddles() -> void:
	for i in 12:
		var x := 310.0 + fmod(i * 113.0, 1360.0)
		var y := 220.0 + fmod(i * 71.0 + _time * 125, 540.0)
		draw_line(Vector2(x, y), Vector2(x - 5, y + 29), Color("#B2C6D6", 0.12), 1)
	for i in 4:
		draw_arc(Vector2(390 + i * 330, 891), 42, PI * 0.07, PI * 0.93, 20, Color("#9EC1DC", 0.24), 2, true)

func _moss_and_memorials() -> void:
	for i in 5:
		var x := 40.0 + i * 440
		var points := PackedVector2Array([Vector2(x, 430), Vector2(x + 10, 530), Vector2(x - 7, 650), Vector2(x + 8, 790), Vector2(x, 900)])
		draw_polyline(points, Color("#2E4C36", 0.70), 4, true)
		for j in 2:
			var root := Vector2(x + (8 if j == 0 else -4), 615 + j * 145)
			draw_colored_polygon(PackedVector2Array([root, root + Vector2(21, -16), root + Vector2(28, 3), root + Vector2(8, 10)]), Color("#375D40", 0.70))
	for x in [118.0, 1820.0]:
		var slab := PackedVector2Array([Vector2(x - 24, 900), Vector2(x - 24, 835), Vector2(x - 18, 820), Vector2(x, 811), Vector2(x + 18, 820), Vector2(x + 24, 835), Vector2(x + 24, 900)])
		draw_colored_polygon(slab, Color(stone * 0.65, 1))
		slab.append(slab[0])
		draw_polyline(slab, Color(edge, 0.25), 2, true)
		draw_multiline(PackedVector2Array([Vector2(x, 838), Vector2(x, 876), Vector2(x - 10, 852), Vector2(x + 10, 852)]), Color(edge, 0.25), 2, true)
