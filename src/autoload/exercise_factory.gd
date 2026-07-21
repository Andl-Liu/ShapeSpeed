extends Node

## ExerciseFactory — Autoload 单例
##
## 唯一职责：根据类型字符串创建对应的 Exercise 实例，
## 注入难度参数，调用 generate()，返回就绪的练习。


# ── 类型映射表 ──
# 每加一种新练习，在这里加一行即可。

const _TYPE_MAP := {
	"angle_fixed_center": preload("res://src/exercises/angle_fixed_center_exercise.gd"),
}

## 类型 → 显示名称
const DISPLAY_NAMES := {
	"angle_fixed_center": "固定中心角度练习",
}


# ── 公开方法 ──

## 创建并返回一个已生成（generate 完毕）的练习实例。
## options 可传入练习特有的参数，如 { "is_fixed_angle_mode": true, "fixed_angle_value_deg": 45.0 }
func create_exercise(type: String, difficulty: int, options: Dictionary = {}) -> BaseExercise:
	assert(_TYPE_MAP.has(type), "Unknown exercise type: %s" % type)

	var exercise: BaseExercise = _TYPE_MAP[type].new()

	# 注入练习特有参数（如果 exercise 有这个属性的话）
	for key in options:
		if key in exercise:
			exercise.set(key, options[key])

	exercise.generate(difficulty)
	return exercise


## 返回所有可用练习类型的名称列表
func get_available_types() -> Array:
	return _TYPE_MAP.keys()


## 返回某个类型的显示名称
func get_display_name(type: String) -> String:
	return DISPLAY_NAMES.get(type, type)
