extends CanvasLayer
## Accessible attribution on the title and ending screens.
var is_open := false
var _button: Button
var _modal: Control

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Button.new()
	_button.text = "音乐鸣谢"
	_button.position = Vector2(1680, 1000)
	_button.size = Vector2(180, 44)
	_button.add_theme_font_size_override("font_size", 18)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: set_open(true))
	add_child(_button)
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.02, 0.03, 0.94)
	_modal.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(400, 180)
	panel.size = Vector2(1120, 720)
	_modal.add_child(panel)
	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_left", 48)
	content.add_theme_constant_override("margin_top", 38)
	content.add_theme_constant_override("margin_right", 48)
	content.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(content)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	content.add_child(rows)
	var heading := Label.new()
	heading.text = "音乐鸣谢"
	heading.add_theme_font_size_override("font_size", 34)
	rows.add_child(heading)
	var credit := RichTextLabel.new()
	credit.bbcode_enabled = true
	credit.custom_minimum_size = Vector2(1000, 500)
	credit.add_theme_font_size_override("normal_font_size", 23)
	credit.text = "[b]作曲：Kevin MacLeod[/b]  ·  [url=https://incompetech.com/]incompetech.com[/url]\n\n" + \
		"《Ghost Story》  —  镜中回廊与解谜\n" + \
		"《The Descent》  —  追逐\n" + \
		"《Teller of the Tales》  —  赠色、重逢与离开\n\n" + \
		"三首音乐均依据 [url=https://creativecommons.org/licenses/by/4.0/]Creative Commons Attribution 4.0（CC BY 4.0）[/url] 使用。\n\n" + \
		"为配合游戏，做了响度调整、静音边缘裁切、Ogg 转码，\n并在播放时进行循环与交叉淡化。\n\n" + \
		"感谢作曲者让这些旋律与她们同行。"
	credit.meta_clicked.connect(func(url: Variant) -> void: OS.shell_open(str(url)))
	rows.add_child(credit)
	var close := Button.new()
	close.text = "返回"
	close.custom_minimum_size = Vector2(220, 46)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: set_open(false))
	rows.add_child(close)
	set_open(false)
	visible = false

func set_available(available: bool) -> void:
	visible = available
	if not available:
		set_open(false)

func set_open(value: bool) -> void:
	is_open = value
	_modal.visible = value
	set_process_input(value)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
			set_open(false)
		get_viewport().set_input_as_handled()
