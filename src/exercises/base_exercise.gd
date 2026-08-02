class_name BaseExercise extends Node

enum InteractionMode {
	ROTATION,
	LINE_CONSTAINED,
	FREE_MOVE
}

## 练习评价等级——每个练习类自行判定，main 负责展示文字
enum Rating {
	FLAWLESS,   # 无暇
	PERFECT,    # 完美
	PASS,       # 过关
	PRACTICE,   # 继续练习
}

@export var difficulty: int = 1
@export var is_generated = false

# 子类必须覆盖的核心方法

func generate(_difficulty: int) -> void:
	pass # 随机生成目标几何体，存储内部状态

func validate() -> Dictionary:
	assert(false, "This abstract method must be overridden in a subclass!")
	return {} # 返回得分等数据

func get_target_draw_date() -> Array:
	assert(false, "This abstract method must be overridden in a subclass!")
	return [] # 返回原图区需要绘制的元素列表（含控制点）

func get_copy_draw_date() -> Array:
	assert(false, "This abstract method must be overridden in a subclass!")
	return [] # 返回临摹区需要绘制的元素列表（含控制点）

func get_hint_text() -> String:
	assert(false, "This abstract method must be overridden in a subclass!")
	return "" # 返回提示文本,如几等分点、几倍的线

# 子类可选覆盖的方法

## 是否有固定数值模式（如固定角度、固定长度等）
func has_fixed_value_mode() -> bool:
	return false

## 返回固定数值模式下的预设选项列表
func get_fixed_value_options() -> Array:
	return []

## 返回固定数值模式预设选项的显示文本（不含"自定义..."）
func get_fixed_value_display_options() -> Array:
	var labels: Array = []
	for value in get_fixed_value_options():
		labels.append("%d°" % int(value))
	return labels

## 将下拉/自定义输入文本解析为数值；无法解析返回 -1.0
func parse_fixed_value_text(text: String) -> float:
	var cleaned: String = text.replace("°", "").strip_edges()
	if cleaned.is_valid_float():
		return cleaned.to_float()
	return -1.0

## 校验固定数值是否合法（自定义输入时使用）
func is_valid_fixed_value(value: float) -> bool:
	return value > 0.0

## 自定义输入框的占位提示文本
func get_fixed_value_custom_placeholder() -> String:
	return "输入自定义数值..."

## 生成固定数值模式下的会话参数（供 GameManager.session_options 注入）
func build_fixed_value_session_options(fixed_value: float, _display_text: String = "") -> Dictionary:
	return {
		"is_fixed_angle_mode": true,
		"fixed_angle_value_deg": fixed_value,
	}

## 生成普通（随机）模式下的会话参数
func build_random_session_options() -> Dictionary:
	return { "is_fixed_angle_mode": false }

## 提交后叠加显示在临摹区的正确答案数据（默认=原图数据）
func get_answer_draw_date() -> Array:
	return get_target_draw_date()

## 提交后展示偏差的提示文字（main 调用）
func get_error_display_text(result: Dictionary) -> String:
	return "偏差 %.1f°" % result.get("angle_error", 0.0)

func get_interaction_mode() -> InteractionMode:
	return InteractionMode.ROTATION

## 返回旋转操作的圆心（逻辑坐标，临摹区坐标系）
func get_rotation_center() -> Vector2:
	return Settings.CANVAS.default_center

func on_point_dragged(_point_id: int, _proposed_position: Vector2) -> Vector2:
	return _proposed_position # 默认不约束拖拽点的最终位置

func on_rotation_input(_delta_angle_deg: float) -> void:
	pass # 仅旋转模式需要覆盖

func cleanup() -> void:
	pass # 练习切换时调用，子类可按需覆盖

# 基类提供的信号
signal geometry_changed() # 用户操作导致集合体变化，渲染层连接此信号
signal exercise_completed() # 用户提交校验后发出，GameManager连接此信号
