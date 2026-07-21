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

func get_interaction_mode() -> InteractionMode:
	return InteractionMode.ROTATION

func on_point_dragged(_point_id: int, _proposed_position: Vector2) -> Vector2:
	return _proposed_position # 默认不约束拖拽点的最终位置

func on_rotation_input(_delta_angle_deg: float) -> void:
	pass # 仅旋转模式需要覆盖

func cleanup() -> void:
	pass # 练习切换时调用，子类可按需覆盖

# 基类提供的信号
signal geometry_changed() # 用户操作导致集合体变化，渲染层连接此信号
signal exercise_completed() # 用户提交校验后发出，GameManager连接此信号
