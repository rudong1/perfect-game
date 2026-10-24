extends Control
## Final colour ending.

@onready var backdrop: ColorRect = $Backdrop
@onready var prism_art: Control = $PrismArt
@onready var story: Label = $Story
@onready var restart: Button = $Restart


func _ready() -> void:
	var state := get_node_or_null("/root/GameState")
	var background := ShaderMaterial.new()
	background.shader = preload("res://shaders/level_backdrop.gdshader")
	background.set_shader_parameter("top_color", Color("#071019"))
	background.set_shader_parameter("bottom_color", Color("#1d4e55"))
	background.set_shader_parameter("accent_color", Color("#f6fbff"))
	background.set_shader_parameter("glow_strength", 1.6)
	backdrop.material = background

	var rays: Array[Color] = [Color("#ff5c71"), Color("#51c8ff"), Color("#69e39d")]
	prism_art.call("set_state", 5, rays, true)

	var name_text := "少女"
	if state != null:
		name_text = str(state.get("player_name"))
	story.text = "雨停了。%s 走出最后一重镜面。\n无色的大厅第一次有了颜色。" % name_text
	restart.pressed.connect(_restart)


func _restart() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
