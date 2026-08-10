extends Control


# ── 子节点引用 ──

@onready var _button_container: VBoxContainer = $VBox/ButtonContainer
@onready var _timed_checkbox: CheckBox = $VBox/TimedModeCheckBox
@onready var _timed_input: LineEdit = $VBox/TimedSecondsInput


# ── 生命周期 ──

func _ready() -> void:
	for type in ExerciseFactory.get_available_types():
		var btn := Button.new()
		btn.text = ExerciseFactory.get_display_name(type)
		btn.custom_minimum_size = Vector2(300, 50)
		btn.pressed.connect(_on_exercise_selected.bind(type))
		_button_container.add_child(btn)

	# 计时模式 UI：先从 GameManager 同步，再连接信号（避免初始化触发回调）
	_timed_checkbox.button_pressed = GameManager.timed_mode_enabled
	_timed_input.visible = GameManager.timed_mode_enabled
	_timed_input.text = str(int(GameManager.timed_mode_seconds))
	_timed_checkbox.toggled.connect(_on_timed_mode_toggled)
	_timed_input.text_submitted.connect(_on_timed_seconds_submitted)


# ── 信号回调 ──

func _on_exercise_selected(type: String) -> void:
	GameManager.session_type = type
	get_tree().change_scene_to_file("res://src/scenes/main.tscn")


## 计时模式开关：切换 GameManager 配置并显示/隐藏秒数输入框
func _on_timed_mode_toggled(checked: bool) -> void:
	GameManager.timed_mode_enabled = checked
	_timed_input.visible = checked
	if checked:
		_timed_input.grab_focus()


## 秒数输入回车提交：正整数 1~600 生效（>600 截为 600），非法输入恢复当前值
func _on_timed_seconds_submitted(text: String) -> void:
	var value: int = 0
	var cleaned: String = text.strip_edges()
	if cleaned.is_valid_int():
		value = cleaned.to_int()
	if value < 1:
		_timed_input.text = str(int(GameManager.timed_mode_seconds))
		return
	value = min(value, 600)
	GameManager.timed_mode_seconds = float(value)
	_timed_input.text = str(value)
