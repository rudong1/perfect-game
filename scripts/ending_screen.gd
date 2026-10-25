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
	story.text = "%s 松开了掌心的三色。\n镜中的女孩恢复了容貌，第一次有了温度。\n\n她们拥抱、握紧彼此的手。\n这一次，darksky 不必再留在镜子的另一边。" % name_text
	restart.pressed.connect(_restart)


func _restart() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
