extends Control


# ── 子节点引用 ──

@onready var _rows_container: VBoxContainer = $VBox/RowsContainer
@onready var _back_btn: Button = $VBox/BackBtn


# ── 生命周期 ──

func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_build_rows()


# ── 设置行 ──

## 为每个练习生成一行：显示名 + [-][数值][+] 步进器
func _build_rows() -> void:
	for type in ExerciseFactory.get_available_types():
		var config: Dictionary = Settings.get_rating_config(type)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_rows_container.add_child(row)

		var name_label := Label.new()
		name_label.text = ExerciseFactory.get_display_name(type)
		name_label.custom_minimum_size = Vector2(200, 0)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var minus_btn := Button.new()
		minus_btn.text = "−"
		minus_btn.custom_minimum_size = Vector2(40, 36)
		row.add_child(minus_btn)

		var value_label := Label.new()
		value_label.text = "%d%s" % [int(config["pass"]), config["unit"]]
		value_label.custom_minimum_size = Vector2(72, 36)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 20)
		row.add_child(value_label)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(40, 36)
		row.add_child(plus_btn)

		minus_btn.pressed.connect(_on_step.bind(type, -1.0, value_label))
		plus_btn.pressed.connect(_on_step.bind(type, 1.0, value_label))


## 步进器点击：按该练习步长调整过关阈值并更新显示
func _on_step(type: String, delta: float, value_label: Label) -> void:
	var config: Dictionary = Settings.get_rating_config(type)
	var new_value: float = config["pass"] + delta * config["step"]
	Settings.set_pass_threshold(type, new_value)
	value_label.text = "%d%s" % [int(Settings.get_pass_threshold(type)), config["unit"]]


# ── 信号回调 ──

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/menu.tscn")
