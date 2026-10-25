extends Control
## Two real girls leave together after the colours have become a life.

@onready var backdrop: TextureRect = $Backdrop
@onready var story: Label = $Story
@onready var restart: Button = $Restart


func _ready() -> void:
	var state := get_node_or_null("/root/GameState")
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/restricted_art.gdshader")
	backdrop.material = palette
	var name_text := "少女"
	if state != null:
		name_text = str(state.get("player_name"))
	$Subtitle.text = "这一次，两个人一起离开"
	story.text = "%s 交出了红、蓝、绿。\n它们汇成完整的光，让镜中的女孩重获生命。\n\n失去的颜色，没有让这段旅程变得空白。\n因为这一次，darksky 真正握住了她的手。" % name_text
	restart.pressed.connect(_restart)


func _restart() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
