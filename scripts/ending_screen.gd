extends Control
## Final colour ending.

@onready var backdrop: ColorRect = $Backdrop
@onready var story: Label = $Story
@onready var restart: Button = $Restart


func _ready() -> void:
	var state := get_node_or_null("/root/GameState")
	var background := ShaderMaterial.new()
	background.shader = preload("res://shaders/level_backdrop.gdshader")
	background.set_shader_parameter("top_color", Color("#07140f"))
	background.set_shader_parameter("bottom_color", Color("#16382b"))
	background.set_shader_parameter("accent_color", Color("#a5dfb4"))
	background.set_shader_parameter("glow_strength", 1.6)
	backdrop.material = background


	var name_text := "少女"
	if state != null:
		name_text = str(state.get("player_name"))
	var count: int = state.collected_count() if state != null else 0
	$Subtitle.text = "色彩仍然属于你" if count == 3 else "旅程结束 · 收集了 %d / 3 种颜色" % count
	story.text = "巨镜碎裂，追逐你的倒影也消失了。\n%s 带着找回的颜色，走出了教堂。\n\n她曾与你同行，也曾想夺走这一切。\n最后留下的，只有她的名字：darksky。" % name_text
	restart.pressed.connect(_restart)


func _restart() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
