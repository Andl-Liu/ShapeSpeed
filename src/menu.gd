extends Control


# ── 子节点引用 ──

@onready var _button_container: VBoxContainer = $VBox/ButtonContainer


# ── 生命周期 ──

func _ready() -> void:
	for type in ExerciseFactory.get_available_types():
		var btn := Button.new()
		btn.text = ExerciseFactory.get_display_name(type)
		btn.custom_minimum_size = Vector2(300, 50)
		btn.pressed.connect(_on_exercise_selected.bind(type))
		_button_container.add_child(btn)


# ── 信号回调 ──

func _on_exercise_selected(type: String) -> void:
	GameManager.session_type = type
	get_tree().change_scene_to_file("res://main.tscn")
